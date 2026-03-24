using UdonSharp;
using UnityEngine;
using VRC.SDKBase;
using VRC.Udon;

/// <summary>
/// Master-managed player object pool.
///
/// The instance master maintains the canonical assignment table (_assignments)
/// and syncs it to all clients. Non-master clients react in OnDeserialization.
///
/// Pool objects must be pre-placed in the scene and assigned in the Inspector.
/// They should expose an AssignToPlayer(VRCPlayerApi) and Unassign() API.
/// </summary>
[UdonBehaviourSyncMode(BehaviourSyncMode.Manual)]
public class MasterManagedPlayerPool : UdonSharpBehaviour
{
    // -------------------------------------------------------------------------
    // Inspector fields
    // -------------------------------------------------------------------------

    [Header("Pool Objects (assign in Inspector, one per expected player slot)")]
    [SerializeField] private UdonSharpBehaviour[] _poolObjects;

    // -------------------------------------------------------------------------
    // Synced state  (master writes, all clients read)
    // -------------------------------------------------------------------------

    /// <summary>
    /// _assignments[i] == player ID of the player assigned to slot i.
    /// 0 means the slot is free (VRC player IDs are always >= 1).
    /// </summary>
    [UdonSynced]
    private int[] _assignments;

    // -------------------------------------------------------------------------
    // Local state  (not synced)
    // -------------------------------------------------------------------------

    /// <summary>FIFO ring buffer holding free slot indices (master only).</summary>
    private int[] _freeQueue;

    /// <summary>Ring-buffer read pointer (dequeue from here).</summary>
    private int _freeHead;

    /// <summary>Ring-buffer write pointer (enqueue here).</summary>
    private int _freeTail;

    /// <summary>Number of entries currently in _freeQueue.</summary>
    private int _freeCount;

    /// <summary>
    /// Previous snapshot of _assignments, used in OnDeserialization to detect
    /// which slots changed so we can activate / deactivate pool objects.
    /// </summary>
    private int[] _previousAssignments;

    // =========================================================================
    // Lifecycle
    // =========================================================================

    void Start()
    {
        int poolSize = _poolObjects.Length;

        // Allocate synced array (all slots start unassigned)
        _assignments = new int[poolSize];

        // Allocate local change-detection snapshot
        _previousAssignments = new int[poolSize];

        // Allocate the free-slot ring buffer (master only, but harmless on all clients)
        _freeQueue = new int[poolSize];
        _freeHead = 0;
        _freeTail = 0;
        _freeCount = 0;

        // Only the master initialises the free queue; all slots start free
        if (Networking.IsMaster)
        {
            for (int i = 0; i < poolSize; i++)
            {
                _EnqueueFree(i);
            }
        }
    }

    // =========================================================================
    // VRC Player Events  (master-only assignment logic)
    // =========================================================================

    public override void OnPlayerJoined(VRCPlayerApi player)
    {
        // Only the master manages assignments
        if (!Networking.IsMaster) return;
        if (!Utilities.IsValid(player)) return;

        if (_freeCount == 0)
        {
            Debug.LogWarning($"[PlayerPool] No free slot for player {player.playerId} ({player.displayName}). Pool is full.");
            return;
        }

        int slot = _DequeueFree();
        _assignments[slot] = player.playerId;

        // Push the updated table to all clients
        RequestSerialization();
    }

    public override void OnPlayerLeft(VRCPlayerApi player)
    {
        // Only the master manages assignments
        if (!Networking.IsMaster) return;
        if (!Utilities.IsValid(player)) return;

        // Find the slot held by this player
        int slot = _FindSlotForPlayer(player.playerId);
        if (slot < 0)
        {
            // Player had no assigned slot (e.g. pool was full when they joined)
            return;
        }

        _assignments[slot] = 0;   // mark as free in the synced array
        _EnqueueFree(slot);       // return to the local free queue

        RequestSerialization();
    }

    // =========================================================================
    // Serialization  (all clients apply incoming state)
    // =========================================================================

    public override void OnDeserialization()
    {
        // Compare the newly received _assignments against our previous snapshot
        // and activate / deactivate pool objects accordingly.
        for (int i = 0; i < _assignments.Length; i++)
        {
            int newId = _assignments[i];
            int oldId = _previousAssignments[i];

            if (newId == oldId) continue;  // no change for this slot

            if (newId != 0)
            {
                // Slot was just assigned — find the player and notify the pool object
                VRCPlayerApi player = VRCPlayerApi.GetPlayerById(newId);
                if (Utilities.IsValid(player))
                {
                    _ActivateSlot(i, player);
                }
            }
            else
            {
                // Slot was just freed
                _DeactivateSlot(i);
            }
        }

        // Update snapshot
        System.Array.Copy(_assignments, _previousAssignments, _assignments.Length);
    }

    // =========================================================================
    // Master Handoff
    // =========================================================================

    public override void OnMasterClientSwitched(VRCPlayerApi newMaster)
    {
        // Only the incoming master needs to rebuild the local free queue
        if (!Networking.IsMaster) return;

        _RebuildFreeQueue();

        // Schedule a deferred verification pass to catch any assignments that may
        // have been written just before the previous master left (race condition).
        SendCustomEventDelayedSeconds(nameof(VerifyAssignments), 2f);
    }

    /// <summary>
    /// Deferred assignment verification called 2 s after a master handoff.
    /// Assigns slots to any current players who lack one and frees slots whose
    /// player is no longer in the instance.
    /// </summary>
    public void VerifyAssignments()
    {
        if (!Networking.IsMaster) return;

        int playerCount = VRCPlayerApi.GetPlayerCount();
        VRCPlayerApi[] players = new VRCPlayerApi[playerCount];
        VRCPlayerApi.GetPlayers(players);

        bool changed = false;

        // --- Free slots whose player is gone ---
        for (int i = 0; i < _assignments.Length; i++)
        {
            if (_assignments[i] == 0) continue;

            VRCPlayerApi assigned = VRCPlayerApi.GetPlayerById(_assignments[i]);
            if (!Utilities.IsValid(assigned))
            {
                _assignments[i] = 0;
                _EnqueueFree(i);
                changed = true;
            }
        }

        // --- Assign slots to players who have none ---
        for (int p = 0; p < players.Length; p++)
        {
            if (!Utilities.IsValid(players[p])) continue;

            int existingSlot = _FindSlotForPlayer(players[p].playerId);
            if (existingSlot >= 0) continue;  // already assigned

            if (_freeCount == 0)
            {
                Debug.LogWarning($"[PlayerPool] VerifyAssignments: no free slot for {players[p].displayName}.");
                continue;
            }

            int slot = _DequeueFree();
            _assignments[slot] = players[p].playerId;
            changed = true;
        }

        if (changed)
        {
            RequestSerialization();
        }
    }

    // =========================================================================
    // Pool Object Activation  (override or replace with your own API)
    // =========================================================================

    /// <summary>
    /// Called when a slot is assigned to a player.
    /// Forward the event to the pool object at that slot.
    /// </summary>
    private void _ActivateSlot(int slot, VRCPlayerApi player)
    {
        if (_poolObjects[slot] == null) return;

        // Pool objects are expected to implement SetAssignedPlayer(VRCPlayerApi).
        // Adapt this call to match your actual pool object API.
        _poolObjects[slot].SetProgramVariable("assignedPlayer", player);
        _poolObjects[slot].gameObject.SetActive(true);
    }

    /// <summary>
    /// Called when a slot is freed.
    /// </summary>
    private void _DeactivateSlot(int slot)
    {
        if (_poolObjects[slot] == null) return;

        _poolObjects[slot].gameObject.SetActive(false);
    }

    // =========================================================================
    // Free-Queue Helpers  (FIFO ring buffer, master-local)
    // =========================================================================

    /// <summary>Add a slot index to the tail of the free queue.</summary>
    private void _EnqueueFree(int slot)
    {
        _freeQueue[_freeTail] = slot;
        _freeTail = (_freeTail + 1) % _freeQueue.Length;
        _freeCount++;
    }

    /// <summary>Remove and return the slot index at the head of the free queue.</summary>
    private int _DequeueFree()
    {
        int slot = _freeQueue[_freeHead];
        _freeHead = (_freeHead + 1) % _freeQueue.Length;
        _freeCount--;
        return slot;
    }

    /// <summary>
    /// Rebuild the free queue from the current _assignments array.
    /// Called by the new master after a master-handoff.
    /// </summary>
    private void _RebuildFreeQueue()
    {
        _freeHead = 0;
        _freeTail = 0;
        _freeCount = 0;

        for (int i = 0; i < _assignments.Length; i++)
        {
            if (_assignments[i] == 0)
            {
                _EnqueueFree(i);
            }
        }
    }

    // =========================================================================
    // Utility Helpers
    // =========================================================================

    /// <summary>
    /// Return the index of the slot assigned to the given player ID, or -1.
    /// </summary>
    private int _FindSlotForPlayer(int playerId)
    {
        for (int i = 0; i < _assignments.Length; i++)
        {
            if (_assignments[i] == playerId) return i;
        }
        return -1;
    }
}
