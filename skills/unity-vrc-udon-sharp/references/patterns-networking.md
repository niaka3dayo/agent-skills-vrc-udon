# UdonSharp Networking Patterns

Object pooling, synced game state management, NetworkCallable patterns, persistence, dynamics interactions, and delayed event debouncing.

## Object Pooling

### Simple Object Pooling

```csharp
public class SimplePool : UdonSharpBehaviour
{
    public GameObject prefab;
    public int poolSize = 10;
    public Transform poolParent;

    private GameObject[] pool;
    private int nextIndex = 0;

    void Start()
    {
        pool = new GameObject[poolSize];
        for (int i = 0; i < poolSize; i++)
        {
            pool[i] = VRCInstantiate(prefab);
            pool[i].transform.SetParent(poolParent);
            pool[i].SetActive(false);
        }
    }

    public GameObject Get()
    {
        GameObject obj = pool[nextIndex];
        obj.SetActive(true);
        nextIndex = (nextIndex + 1) % poolSize;
        return obj;
    }

    public void Return(GameObject obj)
    {
        obj.SetActive(false);
    }
}
```

## Master-Managed Player Object Pool

A networked pattern that assigns a unique pool object to each player present in the world.
The instance master owns all assignment logic; other clients react to synced state via `OnDeserialization`.

**When to use this pattern:**
- Each player needs a dedicated, persistent object (nameplate, avatar attachment, scoreboard slot, etc.)
- Pool size is fixed and known at design time (set `_poolObjects` in the Inspector)
- Assignment authority must be centralised to avoid conflicts

### Architecture

| Member | Kind | Purpose |
|---|---|---|
| `_assignments` | `[UdonSynced] int[]` | Maps pool index → VRC player ID (0 = unassigned) |
| `_poolObjects` | `UdonSharpBehaviour[]` | Inspector-assigned pool object references |
| `_freeQueue` | `int[]` (local) | FIFO ring buffer of free slot indices (master only) |
| `_freeHead/Tail` | `int` (local) | Ring-buffer pointers for O(1) enqueue / dequeue |
| `_previousAssignments` | `int[]` (local) | Snapshot used in `OnDeserialization` for change detection |

**Template:** [assets/templates/MasterManagedPlayerPool.cs](../assets/templates/MasterManagedPlayerPool.cs)

The implementation uses `Manual` sync mode. On `Start`, it allocates `_assignments[]` (synced) and the local `_freeQueue` ring buffer. Only the master initialises the free queue. `OnPlayerJoined`/`OnPlayerLeft` (master only) dequeue/enqueue slots and call `RequestSerialization`. `OnDeserialization` diffs against `_previousAssignments` and calls `_ActivateSlot`/`_DeactivateSlot` only for changed entries. `OnMasterClientSwitched` rebuilds the free queue and schedules a deferred `VerifyAssignments` call to close the race-condition window.


### Key Design Decisions

**Why master-only assignment?**
Centralising writes to the master eliminates the need for distributed conflict resolution. Only one client ever calls `RequestSerialization`, so the synced array is always consistent.

**Why a FIFO queue instead of a linear scan?**
`OnPlayerJoined` runs on every join event. A ring-buffer dequeue is O(1) regardless of pool size, keeping join latency predictable.

**`_previousAssignments` change detection**
`OnDeserialization` fires whenever *any* synced variable changes. Diffing against the previous snapshot means only genuinely modified slots trigger `_ActivateSlot` / `_DeactivateSlot`, avoiding redundant work.

**Late-joiner initialisation**
When a late joiner receives their first `OnDeserialization`, `_previousAssignments` is all-zeros, so every occupied slot in `_assignments` is detected as a new assignment and the corresponding pool objects are activated automatically.

**Master handoff race condition**
There is a brief window between the old master leaving and the new master being elected where join/leave events may be dropped. The 2-second deferred `VerifyAssignments` call reconciles the assignment table against the live player list to close this gap.

### Usage Notes

- Set `_poolObjects` in the Inspector before entering Play mode. Pool size equals `_poolObjects.Length`.
- Pool objects should handle their own visual/audio state inside `SetActive`. The manager only toggles `gameObject.SetActive`.
- If your pool objects need the assigned player at enable time, store the player reference via `SetProgramVariable("assignedPlayer", player)` before calling `SetActive(true)`, as shown in `_ActivateSlot`.
- This pattern does not support runtime pool growth. Size the pool to the world's maximum player count.

### Array Helpers

```csharp
public class ArrayHelpers : UdonSharpBehaviour
{
    // Find index in array
    public int FindIndex(GameObject[] array, GameObject target)
    {
        for (int i = 0; i < array.Length; i++)
        {
            if (array[i] == target) return i;
        }
        return -1;
    }

    // Shuffle array (Fisher-Yates)
    public void ShuffleArray(int[] array)
    {
        for (int i = array.Length - 1; i > 0; i--)
        {
            int j = Random.Range(0, i + 1);
            int temp = array[i];
            array[i] = array[j];
            array[j] = temp;
        }
    }

    // Resize array (create new)
    public GameObject[] ResizeArray(GameObject[] original, int newSize)
    {
        GameObject[] newArray = new GameObject[newSize];
        int copyLength = Mathf.Min(original.Length, newSize);
        System.Array.Copy(original, newArray, copyLength);
        return newArray;
    }
}
```

## NetworkCallable Patterns (SDK 3.8.1+)

### Basic Parameterized RPC

```csharp
using UdonSharp;
using UnityEngine;
using VRC.SDKBase;
using VRC.Udon.Common.Interfaces;

[UdonBehaviourSyncMode(BehaviourSyncMode.Manual)]
public class NetworkCallableBasic : UdonSharpBehaviour
{
    public TextMeshProUGUI messageText;

    [NetworkCallable]
    public void ShowMessage(string message, int senderId)
    {
        VRCPlayerApi sender = VRCPlayerApi.GetPlayerById(senderId);
        string senderName = sender != null ? sender.displayName : "Unknown";
        messageText.text = $"{senderName}: {message}";
    }

    public void BroadcastMessage(string message)
    {
        SendCustomNetworkEvent(
            NetworkEventTarget.All,
            nameof(ShowMessage),
            message,
            Networking.LocalPlayer.playerId
        );
    }
}
```

### Damage System with NetworkCallable

```csharp
[UdonBehaviourSyncMode(BehaviourSyncMode.Manual)]
public class DamageReceiver : UdonSharpBehaviour
{
    [UdonSynced] private int health = 100;
    public TextMeshProUGUI healthText;

    [NetworkCallable]
    public void TakeDamage(int damage, Vector3 hitPosition, int attackerId)
    {
        // Only owner processes damage
        if (!Networking.IsOwner(gameObject))
        {
            // Forward to owner
            SendCustomNetworkEvent(
                NetworkEventTarget.Owner,
                nameof(TakeDamage),
                damage, hitPosition, attackerId
            );
            return;
        }

        health -= damage;
        RequestSerialization();

        // Notify all players of hit effect
        SendCustomNetworkEvent(
            NetworkEventTarget.All,
            nameof(ShowHitEffect),
            hitPosition
        );

        if (health <= 0)
        {
            SendCustomNetworkEvent(
                NetworkEventTarget.All,
                nameof(OnDeath)
            );
        }
    }

    [NetworkCallable]
    public void ShowHitEffect(Vector3 position)
    {
        // Spawn particle at hit position
        SpawnHitParticle(position);
    }

    [NetworkCallable]
    public void OnDeath()
    {
        // Play death animation/sound
        Debug.Log("Target destroyed!");
    }

    public override void OnDeserialization()
    {
        healthText.text = $"HP: {health}";
    }
}
```

### Chat System

```csharp
[UdonBehaviourSyncMode(BehaviourSyncMode.None)]
public class ChatSystem : UdonSharpBehaviour
{
    public TextMeshProUGUI chatLog;
    public UnityEngine.UI.InputField inputField;

    private string[] messages = new string[50];
    private int messageIndex = 0;

    [NetworkCallable(10)] // Allow 10 messages/sec
    public void ReceiveMessage(string message, string senderName)
    {
        messages[messageIndex] = $"[{senderName}] {message}";
        messageIndex = (messageIndex + 1) % messages.Length;
        UpdateChatDisplay();
    }

    public void SendMessage()
    {
        string msg = inputField.text;
        if (string.IsNullOrEmpty(msg)) return;

        inputField.text = "";

        SendCustomNetworkEvent(
            NetworkEventTarget.All,
            nameof(ReceiveMessage),
            msg,
            Networking.LocalPlayer.displayName
        );
    }

    private void UpdateChatDisplay()
    {
        System.Text.StringBuilder sb = new System.Text.StringBuilder();
        for (int i = 0; i < messages.Length; i++)
        {
            if (!string.IsNullOrEmpty(messages[i]))
            {
                sb.AppendLine(messages[i]);
            }
        }
        chatLog.text = sb.ToString();
    }
}
```

## Persistence Patterns (SDK 3.7.4+)

### Settings Manager

```csharp
using UdonSharp;
using UnityEngine;
using VRC.SDKBase;
using VRC.SDK3.Persistence;

public class SettingsManager : UdonSharpBehaviour
{
    [Header("UI References")]
    public UnityEngine.UI.Slider volumeSlider;
    public UnityEngine.UI.Toggle musicToggle;
    public UnityEngine.UI.Dropdown qualityDropdown;

    private bool initialized = false;

    public override void OnPlayerRestored(VRCPlayerApi player)
    {
        if (!player.isLocal) return;

        // Load all settings
        if (PlayerData.TryGetFloat(player, "volume", out float vol))
            volumeSlider.value = vol;

        if (PlayerData.TryGetBool(player, "musicEnabled", out bool music))
            musicToggle.isOn = music;

        if (PlayerData.TryGetInt(player, "quality", out int quality))
            qualityDropdown.value = quality;

        initialized = true;
    }

    public void OnVolumeChanged()
    {
        if (!initialized) return;
        PlayerData.SetFloat(Networking.LocalPlayer, "volume", volumeSlider.value);
        ApplyVolume(volumeSlider.value);
    }

    public void OnMusicToggled()
    {
        if (!initialized) return;
        PlayerData.SetBool(Networking.LocalPlayer, "musicEnabled", musicToggle.isOn);
        ApplyMusic(musicToggle.isOn);
    }

    public void OnQualityChanged()
    {
        if (!initialized) return;
        PlayerData.SetInt(Networking.LocalPlayer, "quality", qualityDropdown.value);
        ApplyQuality(qualityDropdown.value);
    }
}
```

### Unlock System

```csharp
public class UnlockSystem : UdonSharpBehaviour
{
    [Header("Unlock Objects")]
    public GameObject[] unlockableObjects;
    public string[] unlockKeys;

    private bool dataReady = false;

    public override void OnPlayerRestored(VRCPlayerApi player)
    {
        if (!player.isLocal) return;
        dataReady = true;

        // Check all unlocks
        for (int i = 0; i < unlockableObjects.Length; i++)
        {
            if (PlayerData.TryGetBool(player, unlockKeys[i], out bool unlocked))
            {
                unlockableObjects[i].SetActive(unlocked);
            }
        }
    }

    public void Unlock(int index)
    {
        if (!dataReady) return;
        if (index < 0 || index >= unlockKeys.Length) return;

        PlayerData.SetBool(Networking.LocalPlayer, unlockKeys[index], true);
        unlockableObjects[index].SetActive(true);

        Debug.Log($"Unlocked: {unlockKeys[index]}");
    }

    public void ResetAllUnlocks()
    {
        if (!dataReady) return;

        for (int i = 0; i < unlockKeys.Length; i++)
        {
            PlayerData.DeleteKey(Networking.LocalPlayer, unlockKeys[i]);
            unlockableObjects[i].SetActive(false);
        }
    }
}
```

## Dynamics Patterns (SDK 3.10.0+)

### Interactive Button

```csharp
public class ContactButton : UdonSharpBehaviour
{
    [Header("Visual Feedback")]
    public Transform buttonTop;
    public Material normalMaterial;
    public Material pressedMaterial;
    public Renderer buttonRenderer;

    [Header("Audio")]
    public AudioSource pressSound;
    public AudioSource releaseSound;

    [Header("Settings")]
    public float pressDepth = 0.02f;
    public float pressSpeed = 10f;
    public float cooldown = 0.5f;

    private bool isPressed = false;
    private float lastPressTime;
    private Vector3 originalPos;
    private Vector3 pressedPos;

    void Start()
    {
        originalPos = buttonTop.localPosition;
        pressedPos = originalPos - new Vector3(0, pressDepth, 0);
    }

    void Update()
    {
        Vector3 target = isPressed ? pressedPos : originalPos;
        buttonTop.localPosition = Vector3.Lerp(
            buttonTop.localPosition, target, Time.deltaTime * pressSpeed);
    }

    public override void OnContactEnter(ContactEnterInfo info)
    {
        if (isPressed) return;
        if (Time.time - lastPressTime < cooldown) return;

        isPressed = true;
        lastPressTime = Time.time;
        buttonRenderer.material = pressedMaterial;
        pressSound.Play();

        OnButtonPressed(info);
    }

    public override void OnContactExit(ContactExitInfo info)
    {
        isPressed = false;
        buttonRenderer.material = normalMaterial;
        releaseSound.Play();
    }

    private void OnButtonPressed(ContactEnterInfo info)
    {
        if (info.isAvatar && info.player != null)
        {
            Debug.Log($"Button pressed by: {info.player.displayName}");
        }
        // Add your button action here
    }
}
```

### Touch Piano

```csharp
public class TouchPiano : UdonSharpBehaviour
{
    public AudioSource[] noteAudioSources;
    public int noteIndex;

    private bool isPlaying = false;

    public override void OnContactEnter(ContactEnterInfo info)
    {
        if (isPlaying) return;
        isPlaying = true;

        if (noteIndex >= 0 && noteIndex < noteAudioSources.Length)
        {
            noteAudioSources[noteIndex].Play();
        }
    }

    public override void OnContactExit(ContactExitInfo info)
    {
        isPlaying = false;

        if (noteIndex >= 0 && noteIndex < noteAudioSources.Length)
        {
            noteAudioSources[noteIndex].Stop();
        }
    }
}
```

### Grabbable Rope (Physics)

```csharp
public class GrabbableRope : UdonSharpBehaviour
{
    [Header("Sync")]
    [UdonSynced] private bool isGrabbed = false;
    [UdonSynced] private int grabberId = -1;

    [Header("Audio")]
    public AudioSource grabSound;
    public AudioSource releaseSound;

    public override void OnPhysBoneGrab(PhysBoneGrabInfo info)
    {
        Networking.SetOwner(info.player, gameObject);
        isGrabbed = true;
        grabberId = info.player.playerId;
        RequestSerialization();

        grabSound.Play();
    }

    public override void OnPhysBoneRelease(PhysBoneReleaseInfo info)
    {
        isGrabbed = false;
        grabberId = -1;
        RequestSerialization();

        releaseSound.Play();
    }

    public bool IsGrabbed() => isGrabbed;

    public VRCPlayerApi GetGrabber()
    {
        if (grabberId < 0) return null;
        return VRCPlayerApi.GetPlayerById(grabberId);
    }
}
```

## Synced Game State Management

### History/Undo Sync Pattern

When implementing undo functionality in a game, **history is shared among all players as synced variables**.
The initial state is saved as history entry 0, and resetting returns to history 0 (no separate variable for initial state).

**Important notes:**
- **1 logical operation = 1 history save** (do not save twice on both sender and receiver)
- Save the state **after** the operation, not before
- History saving is done only within the owner's operation processing method

**Template:** [assets/templates/UndoableGameManager.cs](../assets/templates/UndoableGameManager.cs)

Syncs `currentState` (byte[]), `stateHistory` (flat byte[] of N×stateSize), and `historyCount` as `[UdonSynced]` variables. `OwnerProcessMove` (owner-only `[NetworkCallable]`) applies the move then calls `SaveStateToHistory`. `OwnerUndo` decrements `historyCount` and restores the previous snapshot. `OwnerReset` resets to `stateHistory[0]`. `OnDeserialization` only calls `UpdateDisplay` — never saves to history.

**Common mistakes:**

| Mistake | Problem | Correct approach |
|--------|------|-----------|
| Saving history in OnDeserialization | Double-saving on sender + receiver | Save only in owner's operation method |
| Managing initial state in a separate variable | Inconsistency on reset | history[0] = initial state |
| Saving state before the operation | Undo goes back 2 steps instead of 1 | Save state after the operation |
| Not making history synced | Undo results differ between players | Share history as synced variables |

## Distant-Room Pseudo-Multi-Room Pattern

Reuse a single local room model to render the illusion of multiple rooms by separating **synced room-assignment state** from **local presentation placement**, and teleporting same-`roomIndex` players to a shared distant origin on each client.

**When to use this pattern:**
- Multiple rooms with identical or near-identical interiors (escape rooms, hub-and-spoke lounges, voice-isolated breakout rooms)
- Authoring one Unity scene cost is acceptable, but authoring N parallel copies is not
- Some level of voice isolation between rooms is desired (a side effect of physical separation)
- Players in the same room must visibly share the same space; players in different rooms must not collide

Requires SDK >= 3.7.4 for the recommended `VRCPlayerObject` tier. The other tiers (fixed-size synced array, local-only) work on older SDKs.

### Architecture (state vs presentation split)

Two responsibilities, each on a separate UdonBehaviour with a different sync mode:

| Layer | Sync mode | What it holds | Where it lives |
|---|---|---|---|
| **State** — `RoomAssignment` | `[UdonBehaviourSyncMode(BehaviourSyncMode.Manual)]` | `[UdonSynced] int roomIndex` | On a `VRCPlayerObject` prefab — auto-spawned per player, auto-owned by that player |
| **Presentation** — `LocalRoomPresenter` | `[UdonBehaviourSyncMode(BehaviourSyncMode.NoVariableSync)]` | `Transform roomRoot`, `Transform[] roomOrigins` | One scene-level instance, per-client local view only |

Each client computes "where is **my** room?" from the local player's `RoomAssignment.roomIndex`, then locally moves `roomRoot` to `roomOrigins[roomIndex]` and `TeleportTo`s the local player to that same origin. **Two players who hold the same `roomIndex` independently run this on their own clients and therefore collocate at the same world coordinate** — they appear together because they were each sent there, not because the room object itself was synced.

### Why this works

`VRCPlayerApi.TeleportTo` only affects the local player; calling it on a remote player is a no-op (ClientSim emits *"Teleporting remote players will do nothing"*). Each client teleporting **its own** `Networking.LocalPlayer` to the world coordinate returned by `roomOrigins[myRoomIndex]` is what produces the shared-room illusion. The room `GameObject` itself never participates in network sync — only the integer room assignment does. Voice attenuation, avatar proximity audio, and pickup proximity all follow the new world position automatically because they operate on post-teleport world coordinates, not on `roomIndex`.

### Cost Tier 1: How is `roomIndex` synced?

| Choice | When to use | Trade-off |
|---|---|---|
| **`VRCPlayerObject` + per-player `RoomAssignment`** (recommended) | Open-world worlds, frequent joins/leaves, rooms come and go organically | Each player auto-owns their `RoomAssignment` — no master, no manager, no slot allocator. Late joiners receive existing assignments through PlayerObject's standard restoration. |
| **Fixed-size synced array on a manager** (`int[] roomIndexBySlot`) | Small lobby worlds with a hard player cap, room capacity limits, master-driven assignment | See [Master-Managed Player Object Pool](#master-managed-player-object-pool) — same shape, with `roomIndex` instead of `poolIndex`. Reuses its master-handoff and slot-recycling logic. |
| **Local-only (no sync)** | Single-player preview / debug only | Other players cannot tell which room you are in; late joiners cannot see existing assignments. Not viable as a main route for multi-player play. |

### Cost Tier 2: Who can write `roomIndex`?

| Choice | When to use | Implementation |
|---|---|---|
| **Self-owned** (recommended starting point) | No capacity limits, lottery is acceptable, players simply choose or randomise their own room | Each player writes only their own `RoomAssignment.roomIndex` under an `IsOwner` guard, then calls `RequestSerialization`. Interact buttons or a local random pick drive the write. |
| **Master-approved** | Capacity caps, fair lottery across all players, reservation systems, banlist-style exclusion | Player sends a request via `SendCustomNetworkEvent(NetworkEventTarget.Owner, ...)` to a Master-owned manager. The manager validates against the synced occupancy table, then writes the assignment (or rejects). See [Master-Managed Player Object Pool](#master-managed-player-object-pool) for the master-handoff race-condition mitigation. |

The self-owned tier avoids the master-handoff race entirely. Escalate to master-approved only when cross-player validation is actually required.

### Key Design Decisions

**Why `NoVariableSync` on the presenter?**
The presenter holds no shared state — only local view placement derived from the synced `roomIndex`. `NoVariableSync` makes the design intent explicit: *this object's fields must never participate in network sync, even by accident*. Editor warnings will flag attempts to add `[UdonSynced]` later.

**Why `Manual` sync mode on the assignment script?**
Room assignment changes are discrete user actions (Interact, button press, lottery roll), not continuous values. `Manual` + `RequestSerialization()` after each write minimises bandwidth and avoids per-frame churn. Discrete user-action state maps to Manual sync per the Sync Mode Quick Decision in [SKILL.md](../SKILL.md).

**Why `VRCPlayerObject` rather than a master-managed slot table by default?**
PlayerObject infrastructure already solves ownership-per-player, late-joiner restoration, and lifecycle cleanup on player leave. There is no need to reinvent slot allocation, and `Networking.SetOwner` is not required because VRChat auto-assigns ownership of each instance to its player (see [persistence.md](persistence.md#playerobject)). `VRCEnablePersistence` is optional — without it the prefab still instantiates per-player but `roomIndex` resets when the player rejoins, which is appropriate for volatile room state.

**Replication-lag window for self-owned assignment.**
When Player A switches rooms locally, their own client moves them immediately. A's avatar position then propagates to remote clients through the normal avatar transform channel — this is a separate, much faster sync than `[UdonSynced]` Manual sync — so voice attenuation and pickup proximity react to the new location within ~100 ms. What does lag is the *application-level* `roomIndex` value: B's client only sees A's new `roomIndex` when A's `RequestSerialization` arrives via `OnDeserialization`, typically sub-second under Manual sync. During that window any room-affiliation UI (room labels, occupant lists, room-scoped event routing) on B's client still reflects A's previous room. Do not build gameplay that requires *all* clients to agree on A's `roomIndex` value within the same frame; the physical-presence aspects of the move are already correct.

### Caveats

The pattern silently breaks if any of these are violated:

| Issue | Why it breaks | What to do |
|---|---|---|
| **`VRCObjectSync` on anything under `roomRoot`** | `VRCObjectSync` broadcasts world-space transforms. Since each client's `roomRoot` is at a different world position, a `VRCObjectSync` child appears at the owner's world coordinate on every client — inside the owner's room only, and in the empty void on everyone else | Keep all `VRCObjectSync` objects outside `roomRoot`, or replicate per-room without `VRCObjectSync` |
| **`roomOrigins` at inconsistent offsets across clients** | If a client's `roomOrigins[1]` differs from another client's `roomOrigins[1]`, same-`roomIndex` players land on different coordinates and stop seeing each other | `roomOrigins` must be Inspector-set Transforms baked into the scene. Never compute them at runtime — even seeded RNG is unsafe because Udon does not guarantee identical `UnityEngine.Random` sequences across clients, and `Time.time`-derived math is per-client by definition |
| **Cameras not anchored to the local player's room** — Drone (`VRCDroneApi`), Stream Camera, scene-fixed render textures aimed at remote-room coordinates | Players are physically at their teleported coordinates, but only the local client's `roomRoot` is positioned at the matching origin. A camera that pans toward another room's coordinates renders those players "in the void" — no walls, no room interior | Place visual occlusion at each `roomOrigin` (opaque box, light-fog volume, view-limiting geometry) so off-room cameras cannot reveal floating avatars |
| **Distant offsets that approach Unity's float-precision band** | Beyond roughly +/-5000 units, position jitter and physics drift become observable; beyond +/-100000, floats lose sub-meter precision | Keep `roomOrigins` within a few thousand units of the world origin. For very large room counts, prefer rotation around a central pivot over linear offset |

### Code Sketch (self-owned + `VRCPlayerObject` tier)

The two scripts together. UI plumbing — how an Interact button on the local client finds and calls into the local player's `RoomAssignment` instance — follows the standard PlayerObject-child to scene-controller registration idiom and is out of scope here.

```csharp
// On a VRCPlayerObject prefab.
// VRChat auto-spawns one per player and auto-assigns ownership to that player —
// Networking.SetOwner is not required for PlayerObject behaviours.
using UdonSharp;
using UnityEngine;
using VRC.SDKBase;

[UdonBehaviourSyncMode(BehaviourSyncMode.Manual)]
public class RoomAssignment : UdonSharpBehaviour
{
    // By convention, roomIndex = 0 is the lobby / default room.
    // If you need an explicit "unassigned" state, use -1 as a sentinel and
    // check for it in LocalRoomPresenter.ApplyLocalRoom().
    [UdonSynced] public int roomIndex = 0;

    [SerializeField] private LocalRoomPresenter presenter;

    // Called by your UI on the local client only.
    public void SetRoom(int newIndex)
    {
        if (!Networking.IsOwner(gameObject)) return; // Self-owned; guard anyway per Rule 12.
        roomIndex = newIndex;
        RequestSerialization();

        // Local apply happens immediately; OnDeserialization does not fire for the
        // writer's own client, so the local view will not update from sync alone.
        presenter.ApplyLocalRoom(newIndex);
    }
}
```

```csharp
// One instance in the scene. Holds the room model and the origin transforms.
// NoVariableSync makes it explicit: this object's state is per-client local.
using UdonSharp;
using UnityEngine;
using VRC.SDKBase;

[UdonBehaviourSyncMode(BehaviourSyncMode.NoVariableSync)]
public class LocalRoomPresenter : UdonSharpBehaviour
{
    [SerializeField] private Transform roomRoot;
    [SerializeField] private Transform[] roomOrigins;

    public void ApplyLocalRoom(int roomIndex)
    {
        if (roomIndex < 0 || roomIndex >= roomOrigins.Length) return;

        Transform origin = roomOrigins[roomIndex];
        if (origin == null) return; // Defensive null check (Inspector slot may be empty).

        // Local-only move of the room model. roomRoot has no VRCObjectSync.
        roomRoot.SetPositionAndRotation(origin.position, origin.rotation);

        // Per-client local teleport. Each player's client teleports its own
        // LocalPlayer to the same origin; same-roomIndex players collocate.
        Networking.LocalPlayer.TeleportTo(origin.position, origin.rotation);
    }
}
```

The wiring for capacity-limited or master-approved variants follows the [Master-Managed Player Object Pool](#master-managed-player-object-pool) pattern above — keep its `_assignments[]` synced array of player IDs and add a parallel `[UdonSynced] int[] _roomIndexBySlot` indexed by the same slot id, then route writes through a master-owned manager via `SendCustomNetworkEvent(NetworkEventTarget.Owner, ...)`.

### See Also

- [Master-Managed Player Object Pool](#master-managed-player-object-pool) — slot allocation pattern, reusable for master-approved room assignment
- [persistence.md PlayerObject section](persistence.md#playerobject) — PlayerObject lifecycle, auto-ownership, `OnPlayerRestored`
- [api.md VRCPlayerApi Movement Methods](api.md#movement-methods) — `TeleportTo` overloads and per-client local teleport semantics

## Delayed Event Debounce

### Problem

`SendCustomEventDelayedSeconds` schedules a future event, but there is no cancellation API. If the same event is scheduled multiple times in quick succession (e.g., a rapid button tap), all enqueued callbacks fire.

### Solution

Use an integer generation counter. Each new schedule increments the counter and captures the current value. The callback checks whether the counter has advanced; if so, a newer schedule exists and this invocation is a no-op.

```csharp
public class DebouncedSearch : UdonSharpBehaviour
{
    [SerializeField] private float debounceDelay = 0.5f;

    // Monotonically increasing; each new schedule captures the current value.
    private int _scheduleGeneration = 0;

    /// <summary>
    /// Call this whenever input changes. Only the callback scheduled after the
    /// last call within debounceDelay seconds will actually execute.
    /// </summary>
    public void OnInputChanged()
    {
        _scheduleGeneration++;
        // Pass the current generation as a serialized field so the callback can read it.
        // UdonSharp does not support lambda captures, so store in a member variable.
        _pendingGeneration = _scheduleGeneration;
        SendCustomEventDelayedSeconds(nameof(ExecuteSearch), debounceDelay);
    }

    // Captured generation for the most recently scheduled callback.
    private int _pendingGeneration = 0;

    public void ExecuteSearch()
    {
        // If _scheduleGeneration has moved past _pendingGeneration, a newer
        // schedule supersedes this one — bail out.
        if (_scheduleGeneration != _pendingGeneration) return;

        // Safe to execute: this is the most recent scheduled callback.
        PerformSearch();
    }

    private void PerformSearch()
    {
        Debug.Log("Executing debounced search");
        // ... actual search logic
    }
}
```

> **Note:** This pattern ensures only the *last* scheduled event executes. It does not prevent intermediate callbacks from running their guard check — it only makes them return immediately.

---

## String Join for Array Sync

### Problem

Syncing `string[]` via `[UdonSynced]` serialises each element individually with per-element overhead. For arrays that change together as a logical unit — playlist titles, display names, ordered slot labels — this wastes bandwidth and produces multiple `OnDeserialization` callbacks if the array is written element-by-element in a loop.

### Solution

Join the entire array into a single `[UdonSynced] string` using a separator character that virtually never appears in natural text or URLs, then split on deserialization. The recommended separator is **U+2029 PARAGRAPH SEPARATOR** (`\u2029`): it is invisible, not present on any keyboard, and absent from VRCUrl strings, display names, and common user text.

**Size consideration:** The joined string must fit within VRChat's synced-data limits. See [networking-bandwidth.md](networking-bandwidth.md) for per-variable and per-behaviour size caps. For large playlists, prefer pagination (sync a window of N entries at a time) over a single huge string.

**Alternative:** Declare a fixed number of separate `[UdonSynced] string` fields — one per playlist slot. Simpler but limited to a known maximum count and does not scale beyond ~10–20 slots without cluttering the behaviour.

**When to use:**
- Playlist titles where the full list changes on every shuffle or load
- User display names collected by the master and broadcast to late joiners
- Any variable-length `string[]` that logically changes as a unit

```csharp
using UdonSharp;
using UnityEngine;
using VRC.SDKBase;

[UdonBehaviourSyncMode(BehaviourSyncMode.Manual)]
public class SyncedPlaylist : UdonSharpBehaviour
{
    // U+2029 PARAGRAPH SEPARATOR — rare enough to be a safe delimiter.
    private const string Separator = "\u2029";

    [UdonSynced]
    private string _syncedTitles = "";

    // Local working copy — split from _syncedTitles on deserialization.
    private string[] _titles = new string[0];

    // ── Helper methods ────────────────────────────────────────────────────

    /// <summary>
    /// Joins a string array into a single sync-safe string.
    /// Empty or null items are preserved as empty strings so indices are stable.
    /// </summary>
    private string JoinForSync(string[] items)
    {
        if (items == null || items.Length == 0) return "";

        System.Text.StringBuilder sb = new System.Text.StringBuilder();
        for (int i = 0; i < items.Length; i++)
        {
            if (i > 0) sb.Append(Separator);

            string item = items[i];
            // Guard: strip any accidental separator characters from content.
            if (!string.IsNullOrEmpty(item) && item.Contains(Separator))
            {
                item = item.Replace(Separator, " ");
            }

            sb.Append(item ?? "");
        }

        return sb.ToString();
    }

    /// <summary>
    /// Splits a sync string back into a string array.
    /// Returns an empty array for an empty or null input.
    /// </summary>
    private string[] SplitFromSync(string joined)
    {
        if (string.IsNullOrEmpty(joined)) return new string[0];

        // UdonSharp does not support string.Split(string[], StringSplitOptions).
        // Manual split on the single-character separator.
        int separatorChar = Separator[0];
        int count = 1;
        for (int i = 0; i < joined.Length; i++)
        {
            if (joined[i] == separatorChar) count++;
        }

        string[] result = new string[count];
        int startIndex = 0;
        int resultIndex = 0;

        for (int i = 0; i <= joined.Length; i++)
        {
            bool atSeparator = (i < joined.Length && joined[i] == separatorChar);
            bool atEnd       = (i == joined.Length);

            if (atSeparator || atEnd)
            {
                result[resultIndex] = joined.Substring(startIndex, i - startIndex);
                resultIndex++;
                startIndex = i + 1;
            }
        }

        return result;
    }

    // ── Owner-side write ──────────────────────────────────────────────────

    /// <summary>
    /// Sets the playlist titles (owner only) and serializes.
    /// </summary>
    public void SetTitles(string[] titles)
    {
        if (!Networking.IsOwner(gameObject)) return;

        _titles       = titles ?? new string[0];
        _syncedTitles = JoinForSync(_titles);
        RequestSerialization();
    }

    // ── Late-joiner / deserialization ─────────────────────────────────────

    public override void OnDeserialization()
    {
        _titles = SplitFromSync(_syncedTitles);
        OnPlaylistUpdated();
    }

    // ── Consumer hook ─────────────────────────────────────────────────────

    private void OnPlaylistUpdated()
    {
        Debug.Log($"[SyncedPlaylist] Received {_titles.Length} title(s).");
        for (int i = 0; i < _titles.Length; i++)
        {
            Debug.Log($"  [{i}] {_titles[i]}");
        }
    }

    public string[] GetTitles() => _titles;
}
```

**Notes:**
- The manual split loop avoids `string.Split(char[])`, which is blocked in some UdonSharp SDK versions. If your SDK version supports `string.Split(new char[]{ '\u2029' })`, you may use it instead.
- The `Replace(Separator, " ")` guard in `JoinForSync` sanitises content that somehow contains the separator character. In practice U+2029 will never appear in VRCUrl strings or player display names, but the guard is cheap insurance.
- `_titles` is a local field only — it is not `[UdonSynced]` and is rebuilt from `_syncedTitles` on every `OnDeserialization`. Late joiners receive the correct full list without any extra synchronisation logic.

---


## See Also

- [networking-antipatterns.md](networking-antipatterns.md) - Anti-patterns to avoid and advanced sync patterns
- [networking-bandwidth.md](networking-bandwidth.md) - Bandwidth throttling, bit packing, and data size optimization
- [patterns-core.md](patterns-core.md) - Initialization, interaction, timer, audio, pickup, animation, UI
- [patterns-performance.md](patterns-performance.md) - Partial class, update handler, PostLateUpdate, spatial query
- [patterns-utilities.md](patterns-utilities.md) - Array helpers, event bus, relay communication
- [patterns-video.md](patterns-video.md) - Video player state machine, server-time playback sync, late joiner sync, synced playlist
- [networking.md](networking.md) - Sync modes, ownership, bandwidth throttling, anti-patterns
- [persistence.md](persistence.md) - PlayerData/PlayerObject full reference (SDK 3.7.4+)
- [dynamics.md](dynamics.md) - PhysBones, Contacts, VRC Constraints full reference (SDK 3.10.0+)
