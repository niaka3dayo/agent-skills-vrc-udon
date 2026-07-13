using UdonSharp;
using UnityEngine;
using VRC.SDKBase;
using VRC.SDK3.UdonNetworkCalling;
using VRC.Udon.Common.Interfaces;

/// <summary>
/// History/Undo sync pattern for multiplayer games.
///
/// History is shared among all players as synced variables.
/// The initial state is saved as history entry 0; resetting returns to history[0]
/// (no separate variable for initial state).
///
/// Rules:
/// - 1 logical operation = 1 history save (do not save twice on sender and receiver)
/// - Save the state AFTER the operation, not before
/// - History saving is done only within the owner's operation processing method
/// - Do NOT add to history in OnDeserialization (causes double-saving)
/// </summary>
[UdonBehaviourSyncMode(BehaviourSyncMode.Manual)]
public class UndoableGameManager : UdonSharpBehaviour
{
    private const int MaxMoves = 100;

    // --- Synced data ---
    [UdonSynced] private byte[] currentState;     // Current game state
    [UdonSynced] private byte[] stateHistory;     // All history (flat array)
    [UdonSynced] private int historyCount;        // Number of saved history entries
    private int stateSize;                        // Size per state

    void Start()
    {
        stateSize = 40; // Larger states increase sync payload size and may reduce sync frequency or add latency.
        currentState = new byte[stateSize];
        // One initial entry plus MaxMoves subsequent move entries.
        stateHistory = new byte[stateSize * (MaxMoves + 1)];
        _InitializeGame();
        _SaveStateToHistory(); // Initial state = history[0]
        _ApplyDisplayLocally();
    }

    // --- Owner-only input ---
    // Non-owners do nothing; input does not transfer ownership. This preserves
    // centralized authority and avoids conflicting state writes.
    public void _RequestMove(int from, int to)
    {
        if (!Networking.IsOwner(gameObject)) return;

        SendCustomNetworkEvent(
            NetworkEventTarget.Owner,
            nameof(_OwnerProcessMove),
            from,
            to
        );
    }

    // --- Owner only: process operations ---
    [NetworkCallable]
    public void _OwnerProcessMove(int from, int to)
    {
        if (!_IsAuthorizedNetworkCaller()) return;

        // Ownership authorizes where synced mutation happens. Caller
        // authorization is handled separately above.
        if (!Networking.IsOwner(gameObject)) return;
        if (!_IsValidMove(from, to)) return;
        // Reject before mutating currentState when all move slots are used.
        if (historyCount >= MaxMoves + 1) return;

        _ExecuteMove(from, to);
        _SaveStateToHistory(); // Save once after the operation
        _ApplyDisplayLocally();
        RequestSerialization();
    }

    // --- History management ---
    private void _SaveStateToHistory()
    {
        int offset = historyCount * stateSize;
        System.Array.Copy(currentState, 0, stateHistory, offset, stateSize);
        historyCount++;
    }

    public void _OnUndoClicked()
    {
        if (!Networking.IsOwner(gameObject)) return;

        SendCustomNetworkEvent(NetworkEventTarget.Owner, nameof(_OwnerUndo));
    }

    [NetworkCallable]
    public void _OwnerUndo()
    {
        if (!_IsAuthorizedNetworkCaller()) return;
        if (!Networking.IsOwner(gameObject)) return;
        if (historyCount <= 1) return; // Cannot go before initial state
        historyCount--;
        int offset = (historyCount - 1) * stateSize;
        System.Array.Copy(stateHistory, offset, currentState, 0, stateSize);
        _ApplyDisplayLocally();
        RequestSerialization();
    }

    public void _OnResetClicked()
    {
        if (!Networking.IsOwner(gameObject)) return;

        SendCustomNetworkEvent(NetworkEventTarget.Owner, nameof(_OwnerReset));
    }

    [NetworkCallable]
    public void _OwnerReset()
    {
        if (!_IsAuthorizedNetworkCaller()) return;
        if (!Networking.IsOwner(gameObject)) return;
        // Return to history[0] = initial state (no separate variable for initial state)
        System.Array.Copy(stateHistory, 0, currentState, 0, stateSize);
        historyCount = 1;
        _ApplyDisplayLocally();
        RequestSerialization();
    }

    // --- All clients: update display ---
    public override void OnDeserialization()
    {
        // Do NOT add to history in OnDeserialization! (causes double-saving)
        _ApplyDisplayLocally();
    }

    // Owner-only session policy: the sender must be the current object owner.
    private bool _IsAuthorizedNetworkCaller()
    {
        if (!NetworkCalling.InNetworkCall) return false;

        VRCPlayerApi caller = NetworkCalling.CallingPlayer;
        if (caller == null || !caller.IsValid()) return false;

        VRCPlayerApi owner = Networking.GetOwner(gameObject);
        if (owner == null || !owner.IsValid()) return false;

        return caller.playerId == owner.playerId;
    }

    // =========================================================================
    // Override these methods for your specific game logic
    // =========================================================================

    private void _InitializeGame()
    {
        // Initialize currentState to the starting game state
        // Example: fill with zeros or a specific starting arrangement
        for (int i = 0; i < currentState.Length; i++)
        {
            currentState[i] = 0;
        }
    }

    private bool _IsValidMove(int from, int to)
    {
        return from >= 0 && from < currentState.Length &&
               to >= 0 && to < currentState.Length;
    }

    private void _ExecuteMove(int from, int to)
    {
        // Apply the move to currentState
        // Example: move an element from index 'from' to index 'to'
        byte temp = currentState[from];
        currentState[from] = currentState[to];
        currentState[to] = temp;
    }

    private void _ApplyDisplayLocally()
    {
        // Reflect currentState in UI/visuals
        // Override this method to update your specific game's display
        Debug.Log($"[UndoableGameManager] State updated, history count: {historyCount}");
    }
}
