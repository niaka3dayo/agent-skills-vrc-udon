# UdonSharp Networking Reference

Comprehensive guide to networking and synchronization in UdonSharp.

**Supported SDK Versions**: 3.7.1 - 3.10.3

> **Warning**: Networking in Udon is a work in progress and can be fragile. Keep implementations simple and test thoroughly with multiple players.
>
> **Best Practice**: "The key to sync is NOT to sync." Minimize synced data and use local calculation where possible.
>
> **SDK 3.8.1+ New Feature**: The `[NetworkCallable]` attribute enables **network events with parameters**. See [Network Events with Parameters](#network-events-with-parameters-sdk-381) for details.

## Sync Methods (BehaviourSyncMode)

Three sync modes provided by VRChat. Specified using the `UdonBehaviourSyncMode` attribute:

```csharp
using UdonSharp;
using UnityEngine;
using VRC.SDKBase;

[UdonBehaviourSyncMode(BehaviourSyncMode.Manual)] // Specify sync mode
public class MySyncedScript : UdonSharpBehaviour
{
    // ...
}
```

### Continuous

Automatic synchronization at approximately **10Hz** (10 times per second).

**Characteristics:**
- Auto-transmits synced variables without calling `RequestSerialization()`
- Data limit: approximately **200 bytes** per UdonBehaviour
- Best for: Positions, rotations, continuously changing values

```csharp
[UdonBehaviourSyncMode(BehaviourSyncMode.Continuous)]
public class ContinuousSyncExample : UdonSharpBehaviour
{
    [UdonSynced] public Vector3 position;    // 12 bytes
    [UdonSynced] public Quaternion rotation; // 16 bytes
    [UdonSynced] public float speed;         // 4 bytes
    // Total: 32 bytes (within 200 byte limit)

    void Update()
    {
        if (Networking.IsOwner(gameObject))
        {
            position = transform.position;
            rotation = transform.rotation;
            // No RequestSerialization() needed!
        }
        else
        {
            // Apply synced values
            transform.position = position;
            transform.rotation = rotation;
        }
    }
}
```

**Limitations:**
- Limited data capacity (~200 bytes)
- High network overhead due to constant transmission
- Not suitable for large data or infrequent updates

### Manual

Explicit synchronization via `RequestSerialization()` calls.

**Characteristics:**
- Only syncs when `RequestSerialization()` is called
- Data limit: **280,496 bytes (~280KB)** per serialization (increased from 65,024 bytes in an earlier release)
- Best for: Game state, scores, settings, infrequent updates

```csharp
[UdonBehaviourSyncMode(BehaviourSyncMode.Manual)]
public class ManualSyncExample : UdonSharpBehaviour
{
    [UdonSynced] public int score;
    [UdonSynced] public int gameState; // Use int/enum for multiple flags
    [UdonSynced] public string playerName;

    public void UpdateScore(int newScore)
    {
        if (!Networking.IsOwner(gameObject))
        {
            Networking.SetOwner(Networking.LocalPlayer, gameObject);
        }

        score = newScore;
        RequestSerialization(); // Explicit sync required!
    }
}
```

**Advantages:**
- Full control over sync timing
- Much larger data capacity
- Low network overhead for infrequent updates

### None (No Variable Sync)

Completely disables variable synchronization. Uses network events for communication.

**Characteristics:**
- No synced variables supported (`[UdonSynced]` will error)
- Must use `SendCustomNetworkEvent()` for communication
- Best for: Local-only logic, event-driven communication, reducing network overhead

```csharp
[UdonBehaviourSyncMode(BehaviourSyncMode.NoVariableSync)]
public class NoSyncExample : UdonSharpBehaviour
{
    // Cannot use [UdonSynced] with NoVariableSync mode!
    // [UdonSynced] private int score; // ERROR!

    public void TriggerGlobalEvent()
    {
        SendCustomNetworkEvent(
            VRC.Udon.Common.Interfaces.NetworkEventTarget.All,
            nameof(OnGlobalEvent)
        );
    }

    public void OnGlobalEvent()
    {
        // All players execute this
        Debug.Log("Event received!");
    }
}
```

**When to use NoVariableSync:**
- Purely event-based systems (buttons, triggers)
- Objects that only need notifications, not state synchronization
- Reducing network overhead in complex worlds

### Mode Selection Guide

| Mode | Data size | Frequency | Use case |
|--------|-------------|------|-------------|
| Continuous | ~200 bytes | High (10Hz) | Position/rotation tracking |
| Manual | ~280KB (280,496 bytes) | On-demand | Game state, scores, settings |
| None | N/A | N/A | Event-only communication |

## VRC_ObjectSync Warning

> **Critical**: When using `VRC_ObjectSync` component alongside `UdonBehaviour`, be aware of sync freezing!

When a physics object with `VRC_ObjectSync` stops moving (becomes stationary), the sync system stops transmitting. **This also affects coexisting UdonBehaviour synced variables!**

```csharp
// PROBLEM: Object stops -> Udon sync also freezes
public class ProblematicPickup : UdonSharpBehaviour
{
    [UdonSynced] public int useCount; // May stop syncing when object is stationary!

    public override void OnPickupUseDown()
    {
        useCount++;
        RequestSerialization(); // Might not transmit if object is still!
    }
}
```

**Workarounds:**
1. **Separate UdonBehaviour**: Place sync logic on a separate GameObject without VRC_ObjectSync
2. **Use network events**: Use `SendCustomNetworkEvent()` for critical updates
3. **Force movement**: Apply minimal velocity to maintain sync (not recommended)

```csharp
// SOLUTION: Separate synced logic from physics object
public class SeparatedSyncLogic : UdonSharpBehaviour
{
    // This script is on a SEPARATE GameObject without VRC_ObjectSync
    [UdonSynced] public int useCount;

    public void IncrementUse()
    {
        if (!Networking.IsOwner(gameObject))
        {
            Networking.SetOwner(Networking.LocalPlayer, gameObject);
        }
        useCount++;
        RequestSerialization(); // Now works reliably
    }
}
```

## Late Joiner Considerations

When a player joins mid-session, synced data behaves differently:

### Synced Variables (Automatic)

Synced variables are **automatically sent** to late joiners:

```csharp
[UdonSynced] private int gameScore;     // Auto-synced to late joiners
[UdonSynced] private bool isGameActive; // Auto-synced to late joiners

// Late joiners receive current values via OnDeserialization
public override void OnDeserialization()
{
    UpdateGameDisplay();
}
```

### Network Events (Manual Handling Required)

Network events are **not re-sent** to late joiners:

```csharp
// PROBLEM: Late joiners miss this event
public void StartGame()
{
    SendCustomNetworkEvent(NetworkEventTarget.All, "OnGameStarted");
}

public void OnGameStarted()
{
    // Late joiners never receive this!
    ShowGameUI();
}
```

**Solution: Use synced variables for state**

```csharp
[UdonSynced, FieldChangeCallback(nameof(GamePhase))]
private int _gamePhase = 0;

public int GamePhase
{
    get => _gamePhase;
    set
    {
        _gamePhase = value;
        OnGamePhaseChanged(); // Called for late joiners via OnDeserialization
    }
}

private void OnGamePhaseChanged()
{
    switch (_gamePhase)
    {
        case 0: ShowLobbyUI(); break;
        case 1: ShowGameUI(); break;
        case 2: ShowResultsUI(); break;
    }
}

public void StartGame()
{
    if (!Networking.IsOwner(gameObject)) return;
    GamePhase = 1;
    RequestSerialization();
}
```

### Side-Effect Guard for Late Joiners

When a late joiner enters a world, `OnDeserialization` fires for all synced variables. If side effects (audio, animations, particles) are triggered directly in `OnDeserialization`, they will play unintentionally on join.

#### The `_isInitialized` Flag Pattern

Use an initialization flag to skip side effects on the first `OnDeserialization` call:

```csharp
[UdonBehaviourSyncMode(BehaviourSyncMode.Manual)]
public class SafeSyncedObject : UdonSharpBehaviour
{
    [UdonSynced, FieldChangeCallback(nameof(GameState))]
    private int _gameState;

    public AudioSource sfx;
    public Animator animator;

    private bool _isInitialized = false;

    public int GameState
    {
        get => _gameState;
        set
        {
            int previousState = _gameState;
            _gameState = value;
            ApplyState(previousState);
        }
    }

    public override void OnDeserialization()
    {
        if (!_isInitialized)
        {
            _isInitialized = true;
            // First deserialization (late joiner): apply state silently
            ApplyStateWithoutSideEffects();
            return;
        }
        // Subsequent deserializations: side effects are handled by
        // FieldChangeCallback (GameState property setter), not here
    }

    private void ApplyState(int previousState)
    {
        // Update visuals (always safe)
        UpdateDisplay();

        // Side effects only after initialization
        if (_isInitialized && previousState != _gameState)
        {
            sfx.Play();
            animator.SetTrigger("StateChange");
        }
    }

    private void ApplyStateWithoutSideEffects()
    {
        UpdateDisplay();
    }

    private void UpdateDisplay() { /* Update UI/visuals */ }
}
```

#### Using `OnDeserialization(DeserializationResult)` Overload

The overloaded `OnDeserialization(DeserializationResult)` provides timing context (`sendTime`, `receiveTime`) and storage origin (`isFromStorage`). These fields are useful for latency analysis and storage-restored data detection, but **do not directly identify late-joiner initial sync**. Use the `_isInitialized` flag pattern for late-joiner guards:

##### DeserializationResult Properties

| Property | Type | Description |
|----------|------|-------------|
| `sendTime` | `float` | Time (in seconds, server clock) when the owner sent this update |
| `receiveTime` | `float` | Time (in seconds, server clock) when this client received the update |
| `isFromStorage` | `bool` | True if the data was restored from persistent storage rather than sent live |

```csharp
public override void OnDeserialization(DeserializationResult result)
{
    // Update visuals (always safe)
    UpdateDisplay();

    // Calculate network latency when valid timing data is available
    if (result.receiveTime > result.sendTime)
    {
        float latencySeconds = result.receiveTime - result.sendTime;
        Debug.Log($"Network latency: {latencySeconds * 1000f:F1} ms");
    }

    // Guard side effects: skip on initial sync for late joiners
    // Note: DeserializationResult does not provide a late-joiner flag;
    // use _isInitialized for this purpose
    if (!_isInitialized)
    {
        _isInitialized = true;
        return;
    }

    // Runtime update: play effects
    PlayTransitionEffects();
}
```

> **Guard**: Always check `receiveTime > sendTime` before computing latency. In edge cases (storage restore, clock skew), `sendTime` may be zero or greater than `receiveTime`.

> **Common pitfall**: Without this guard, a late joiner entering a multiplayer game will hear all audio cues and see all animations replay simultaneously. This was a reported issue in real-world VRChat game development.

## Optimization Tips

### Use Integers/Enums for Multiple Flags

Instead of syncing multiple bools, pack them into a single integer:

```csharp
// BAD: Multiple synced bools
[UdonSynced] private bool hasKey;
[UdonSynced] private bool hasSword;
[UdonSynced] private bool hasShield;
[UdonSynced] private bool hasPotion;

// GOOD: Single synced integer with bit flags
[UdonSynced] private int inventory;

private const int FLAG_KEY = 1;
private const int FLAG_SWORD = 2;
private const int FLAG_SHIELD = 4;
private const int FLAG_POTION = 8;

public bool HasKey => (inventory & FLAG_KEY) != 0;
public bool HasSword => (inventory & FLAG_SWORD) != 0;

public void AddItem(int flag)
{
    inventory |= flag;
    RequestSerialization();
}
```

### Prefer Local Calculation Over Sync

Calculate locally when possible:

```csharp
// BAD: Syncing calculated value
[UdonSynced] private float elapsedTime;

void Update()
{
    if (Networking.IsOwner(gameObject))
    {
        elapsedTime += Time.deltaTime;
        RequestSerialization(); // Too frequent!
    }
}

// GOOD: Sync start time, calculate locally
[UdonSynced] private double startServerTime;

void Update()
{
    if (startServerTime > 0)
    {
        float elapsed = (float)(Networking.GetServerTimeInSeconds() - startServerTime);
        timerDisplay.text = elapsed.ToString("F1");
    }
}
```

## Core Concepts

### Ownership Model

Every GameObject with an UdonBehaviour has a network owner:

- **Default owner**: Instance master (first player to join)
- **One owner per object**: Ownership is per-GameObject, not per-component
- **Only owner can modify**: Only the owner can change synced variables

```csharp
// Check if local player is owner
if (Networking.IsOwner(gameObject))
{
    // Safe to modify synced variables
}

// Get current owner
VRCPlayerApi owner = Networking.GetOwner(gameObject);
Debug.Log($"Owner: {owner.displayName}");
```

### Ownership Transfer

```csharp
// Request ownership for the local player.
// Locally immediate — IsOwner(gameObject) returns true after this call.
Networking.SetOwner(Networking.LocalPlayer, gameObject);
```

**Set owner if needed and update synced state in one call:**

```csharp
public void RequestOwnershipAndUpdate(int newValue)
{
    if (!Networking.IsOwner(gameObject))
    {
        Networking.SetOwner(Networking.LocalPlayer, gameObject);
    }

    syncedValue = newValue;
    RequestSerialization();
}

// OnOwnershipTransferred remains useful for inheritance scenarios
// (e.g., the previous owner left and you became owner without a
// SetOwner call of your own). For SetOwner-initiated transfers, the
// callback fires synchronously inside SetOwner — usually you do not
// need to write code in it for the calling-side path.
public override void OnOwnershipTransferred(VRCPlayerApi player)
{
    if (player.isLocal)
    {
        // Re-broadcast state so non-owner clients converge.
        RequestSerialization();
    }
}
```

### Ownership Transfer Timing Semantics

- **On the calling client:** `Networking.SetOwner` takes effect immediately. `Networking.IsOwner(gameObject)` returns `true` synchronously after the call. `OnOwnershipTransferred` fires synchronously within the `SetOwner` stack on the calling client.
- **On remote clients:** the new ownership becomes visible after VRChat propagates the change. Each remote client's `OnOwnershipTransferred` fires when the propagation arrives.
- **No client-side arbitration:** when two clients call `SetOwner` simultaneously, both succeed locally and may write synced variables; VRChat resolves the durable owner by network arrival order. The loser's write is overwritten when the winner's serialization arrives. This is by design — see [networking-antipatterns.md §1](networking-antipatterns.md#1-ownership-race-condition) for the recommended `IsOwner`-guarded pattern, and [§"Ownership Arbitration with OnOwnershipRequest"](#ownership-arbitration-with-onownershiprequest) below for owner-side protection during critical actions.

> *Footnote: Pre-2021.2.2 SDKs treated `SetOwner` as asynchronous on the calling client; current SDKs (3.7.1+, this skill's coverage range) are locally immediate. Source: [Ownership Transfer Events](https://creators.vrchat.com/worlds/udon/networking/ownership/#transfer-events-diagram).*

### Owner Leave and Ownership Cascade

When the owner of a networked GameObject disconnects:

1. **VRChat automatically assigns a new owner** — the exact selection rule is not publicly documented; do not assume a specific player will be chosen
2. **`OnOwnershipTransferred` fires** on all clients with the new owner
3. **Synced variables are preserved** — they are not reset when ownership transfers

```csharp
public override void OnOwnershipTransferred(VRCPlayerApi player)
{
    if (player == null || !player.IsValid()) return;

    if (player.isLocal)
    {
        // We became the new owner (e.g., previous owner left)
        // Resume game logic that only the owner should run
        Debug.Log("Inherited ownership — resuming owner duties");
        RequestSerialization(); // Re-broadcast current state
    }
}

public override void OnPlayerLeft(VRCPlayerApi player)
{
    if (player == null || !player.IsValid()) return;

    // Clean up player-specific data
    // Note: If this player was the owner, OnOwnershipTransferred
    // will fire separately with the new owner
    RemovePlayerFromGame(player.playerId);
}
```

**Best practices for ownership transitions:**
- Do **not** assume the local player will become the new owner — VRChat decides
- Always re-broadcast state via `RequestSerialization()` when inheriting ownership
- Clean up departing player data in `OnPlayerLeft`, not in `OnOwnershipTransferred`
- If your game logic runs in `Update()` with an owner check, it will automatically resume on the new owner

### Ownership Arbitration with OnOwnershipRequest

`OnOwnershipRequest` allows the current owner to **accept or reject** ownership transfer requests:

```csharp
private bool _isProcessingCriticalAction = false;

public override bool OnOwnershipRequest(
    VRCPlayerApi requestingPlayer,
    VRCPlayerApi requestedOwner)
{
    // Reject ownership transfers during critical game logic
    if (_isProcessingCriticalAction)
    {
        Debug.Log($"Rejected ownership request from {requestingPlayer.displayName} " +
                  $"— critical action in progress");
        return false;
    }

    // Accept the transfer
    return true;
}
```

**When to use `OnOwnershipRequest`:**

| Scenario | Return |
|----------|--------|
| Default (no override) | Always accepts (`true`) |
| During critical game state transitions | Reject (`false`) until complete |
| Turn-based game during active turn | Reject (`false`) until turn ends |
| Free-for-all interaction | Accept (`true`) |

> **Important**: `OnOwnershipRequest` runs locally on **both the requester and the current owner** (per the official [Network Components page](https://creators.vrchat.com/worlds/udon/networking/network-components/): "This logic runs locally on both the requester and the owner"). The logic must return the same result on both sides to avoid desync. If the current owner has disconnected, the callback is not invoked — VRChat auto-assigns directly.
>
> The two parameters are `VRCPlayerApi requestingPlayer` (the player calling `SetOwner`) and `VRCPlayerApi requestedOwner` (the player being assigned ownership — typically the same as `requestingPlayer` for self-promotion, but can differ when one client transfers ownership to another).

## Synced Variables

### Basic Synchronization

Use the `[UdonSynced]` attribute to synchronize fields:

```csharp
[UdonSynced] private int score;
[UdonSynced] private float health;
[UdonSynced] private bool isActive;
[UdonSynced] private Vector3 position;
[UdonSynced] private string playerName; // 2 bytes/char; keep short in Continuous mode (~200 byte shared budget)
```

### Sync Modes

```csharp
// Default: Sync when changed (no interpolation)
[UdonSynced]
private int normalSync;

// Linear interpolation for continuous values
[UdonSynced(UdonSyncMode.Linear)]
private Vector3 linearPosition; // Interpolates between updates

// Smooth damped interpolation
[UdonSynced(UdonSyncMode.Smooth)]
private Quaternion smoothRotation; // Smoothly interpolates

// With FieldChangeCallback (called on value change)
[UdonSynced, FieldChangeCallback(nameof(SmoothPosition))]
private Vector3 _smoothPosition;
public Vector3 SmoothPosition
{
    get => _smoothPosition;
    set
    {
        _smoothPosition = value;
        // Handle smooth interpolation here
    }
}
```

**UdonSyncMode values:**

| Mode | Description | Best for |
|--------|------|-----------|
| `UdonSyncMode.None` | No interpolation (default) | Discrete values, flags, state |
| `UdonSyncMode.Linear` | Linear interpolation between updates | Position, rotation, continuous values |
| `UdonSyncMode.Smooth` | Smooth damped interpolation | Cameras, slow movement, UI elements |

**Important:** Interpolation modes only affect how the receiving client applies values between network updates. Sync frequency is determined by BehaviourSyncMode (Continuous ~10Hz, Manual on-demand).

### Requesting Serialization

After changing synced variables, call `RequestSerialization()`:

```csharp
public void IncrementScore()
{
    if (!Networking.IsOwner(gameObject))
    {
        // SetOwner is locally immediate — IsOwner is true after this returns.
        Networking.SetOwner(Networking.LocalPlayer, gameObject);
    }

    score += 10;
    RequestSerialization(); // Broadcast to all players
}
```

### Detecting Changes

Use `OnDeserialization` or `FieldChangeCallback`:

```csharp
// Method 1: OnDeserialization
[UdonSynced] private int score;

public override void OnDeserialization()
{
    // Called when synced data is received
    UpdateScoreDisplay();
}

// Method 2: FieldChangeCallback (more granular)
[UdonSynced, FieldChangeCallback(nameof(Health))]
private float _health;

public float Health
{
    get => _health;
    set
    {
        _health = value;
        OnHealthChanged();
    }
}

private void OnHealthChanged()
{
    healthBar.value = _health;
}
```

## Network Events

### SendCustomNetworkEvent (Legacy)

Send events to all players or owner only (no parameters):

```csharp
// Send to ALL players (including self)
SendCustomNetworkEvent(VRC.Udon.Common.Interfaces.NetworkEventTarget.All, "OnButtonPressed");

// Send to OWNER only
SendCustomNetworkEvent(VRC.Udon.Common.Interfaces.NetworkEventTarget.Owner, "ProcessOwnerAction");

// The receiving method (must be public)
public void OnButtonPressed()
{
    Debug.Log("Button pressed!");
}
```

**NetworkEventTarget options**:

| Target | SDK | Description |
|-----------|-----|------|
| `NetworkEventTarget.All` | All versions | All players including self |
| `NetworkEventTarget.Owner` | All versions | Object owner only |
| `NetworkEventTarget.Others` | **3.8.1+** | All players except self |
| `NetworkEventTarget.Self` | **3.8.1+** | Self only (equivalent to local execution) |

> **SDK 3.8.1+ new targets**: `NetworkEventTarget.Others` sends to "everyone except the sender", preventing duplicate effect/sound playback. `NetworkEventTarget.Self` can be used for local-only processing.

**Limitations (Legacy)**:
- Cannot send parameters with network events
- Cannot directly target specific players (Others/Self added in SDK 3.8.1+)
- Events may arrive before synced variable updates (race condition!)
- Events are not queued and arrival order is not guaranteed

---

## Network Events with Parameters (SDK 3.8.1+)

The `[NetworkCallable]` attribute added in **SDK 3.8.1** enables sending **up to 8 parameters** with network events.

### [NetworkCallable] Attribute

Methods callable over the network require the `[NetworkCallable]` attribute:

```csharp
using UdonSharp;
using UnityEngine;
using VRC.SDKBase;
using VRC.Udon.Common.Interfaces;

[UdonBehaviourSyncMode(BehaviourSyncMode.Manual)]
public class NetworkCallableExample : UdonSharpBehaviour
{
    [NetworkCallable]
    public void TakeDamage(int damage, int attackerId)
    {
        Debug.Log($"Received {damage} damage from player {attackerId}");
    }

    public void Attack(VRCPlayerApi target, int damage)
    {
        // Send network event with parameters
        SendCustomNetworkEvent(
            NetworkEventTarget.All,
            nameof(TakeDamage),
            damage,
            Networking.LocalPlayer.playerId
        );
    }
}
```

### [NetworkCallable] Constraints

| Constraint | Details |
|------|------|
| `public` required | Method must be public |
| `[NetworkCallable]` required | Without the attribute, parameters cannot be received |
| `static` not allowed | Static methods cannot be used |
| `virtual`/`override` not allowed | Virtual methods cannot be used |
| No overloading | Multiple methods with the same name not allowed |
| Maximum 8 parameters | More than 8 parameters not allowed |
| Syncable types only | Parameters limited to syncable types |

### Rate Limiting

`[NetworkCallable]` accepts an optional integer parameter that controls the maximum call rate (in calls per second) allowed for that method per behaviour instance. This value also acts as the network cost/priority indicator — higher values consume more network budget and are scheduled at higher priority.

```csharp
// Default: 5 calls/sec per behaviour (no argument)
[NetworkCallable]
public void NormalEvent(int value) { }

// Custom rate: 100 calls/sec (maximum allowed)
[NetworkCallable(100)]
public void HighFrequencyEvent(float value) { }

// Low rate: 1 call/sec (minimal network cost)
[NetworkCallable(1)]
public void RareBroadcast(string message) { }
```

**Note**: Events exceeding the rate limit are dropped. Rate limiting is applied **per event per behaviour**. Default is **5 calls/sec**, configurable up to **100 calls/sec** per behaviour.

### Types Usable as Parameters

Only types syncable with `[UdonSynced]` can be used as parameters:

| Type | Size | Notes |
|------|------|-------|
| `bool` | 1 byte | |
| `byte`, `sbyte` | 1 byte | |
| `short`, `ushort` | 2 bytes | |
| `int`, `uint` | 4 bytes | |
| `long`, `ulong` | 8 bytes | |
| `float` | 4 bytes | |
| `double` | 8 bytes | |
| `string` | 2 bytes/char | No fixed per-string limit; bounded by NetworkCallable event payload (16 KB/event max, ~18 KB/s throughput). Events >1024 bytes are split into multiple internal packets. Independent of `[UdonSynced]` sync mode budgets. |
| `Vector2/3/4` | 8/12/16 bytes | |
| `Quaternion` | 16 bytes | |
| `Color`, `Color32` | 16/4 bytes | |
| Arrays of above | variable | |

**Not usable**: `GameObject`, `Transform`, `VRCPlayerApi`, custom classes

### Practical Pattern: Damage System

For a full `[NetworkCallable]`-based damage system with ownership forwarding, hit effects, and death handling, see the `DamageReceiver` example in [patterns-networking.md](patterns-networking.md#networkcallable-patterns-sdk-381).

### Legacy vs NetworkCallable Comparison

| Feature | Legacy | NetworkCallable (3.8.1+) |
|------|--------|--------------------------|
| Sending parameters | Not possible | Up to 8 |
| Attribute | Not required | `[NetworkCallable]` required |
| Rate limiting | None | Configurable (1-100/sec) |
| Backward compatibility | All versions | SDK 3.8.1+ only |

### Migration Guide

**Before (Legacy):**

```csharp
[UdonSynced] private int pendingDamage;
[UdonSynced] private int pendingAttackerId;

public void Attack(int damage, int attackerId)
{
    Networking.SetOwner(Networking.LocalPlayer, gameObject);
    pendingDamage = damage;
    pendingAttackerId = attackerId;
    RequestSerialization();
    SendCustomNetworkEvent(NetworkEventTarget.All, "OnAttack");
}

public void OnAttack()
{
    // pendingDamage may still be the old value (race condition)
    ProcessDamage(pendingDamage, pendingAttackerId);
}
```

**After (NetworkCallable):**

```csharp
[NetworkCallable]
public void Attack(int damage, int attackerId)
{
    // Parameters are reliably delivered (no race condition)
    ProcessDamage(damage, attackerId);
}

public void TriggerAttack(int damage)
{
    SendCustomNetworkEvent(
        NetworkEventTarget.All,
        nameof(Attack),
        damage,
        Networking.LocalPlayer.playerId
    );
}
```

### Race Condition Between Network Events and Synced Variables

**Critical issue**: When sending a network event and updating synced variables simultaneously, the event may arrive before the synced variable update on remote clients:

```csharp
// PROBLEM: Event may arrive before syncedData is updated on remote clients
public void SendDataWithEvent()
{
    syncedData = "important data";
    RequestSerialization();
    SendCustomNetworkEvent(NetworkEventTarget.All, "ProcessData");
}

public void ProcessData()
{
    // syncedData might still be the OLD value here!
    Debug.Log(syncedData); // Might print old data!
}
```

**Solution: Use FieldChangeCallback instead of events**

```csharp
[UdonSynced, FieldChangeCallback(nameof(SyncedData))]
private string _syncedData;

public string SyncedData
{
    get => _syncedData;
    set
    {
        _syncedData = value;
        ProcessData(); // Called after data is actually updated
    }
}

public void SendData()
{
    SyncedData = "important data";
    RequestSerialization();
    // No need for network event - FieldChangeCallback handles it
}

private void ProcessData()
{
    // syncedData is guaranteed to be the new value here
    Debug.Log(_syncedData);
}
```

### Workaround: Targeting Specific Players

Since direct player targeting is not available, use synced variables:

```csharp
[UdonSynced] private int targetPlayerId;
[UdonSynced] private string message;

public void SendMessageToPlayer(VRCPlayerApi player, string msg)
{
    if (!Networking.IsOwner(gameObject))
    {
        Networking.SetOwner(Networking.LocalPlayer, gameObject);
    }

    targetPlayerId = player.playerId;
    message = msg;
    RequestSerialization();

    SendCustomNetworkEvent(NetworkEventTarget.All, "CheckMessage");
}

public void CheckMessage()
{
    if (Networking.LocalPlayer.playerId == targetPlayerId)
    {
        ProcessMessage(message);
    }
}
```

## Data Limits

### String Length

Synced strings have no fixed character limit. The practical limit depends on sync buffer size and UTF-16 encoding (2 bytes per character):
- **Continuous**: ~200 bytes per serialization (shared across all synced fields on the behaviour)
- **Manual**: 280,496 bytes (~280KB) per serialization

```csharp
// Keep synced strings short to conserve sync buffer
[UdonSynced] private string status; // "ready", "waiting", etc.

// For longer data, split across multiple variables
[UdonSynced] private string data1;
[UdonSynced] private string data2;
[UdonSynced] private string data3;
```

### Bandwidth Limits

VRChat limits network data rate. Excessive synchronization causes "Death Runs" (data loss):

```csharp
// WRONG - Too frequent updates
void Update()
{
    position = transform.position;
    RequestSerialization(); // Every frame = bad!
}

// CORRECT - Throttle updates
private float lastSyncTime;
private const float SYNC_INTERVAL = 0.1f; // 10 times per second max

void Update()
{
    if (Time.time - lastSyncTime > SYNC_INTERVAL)
    {
        if (HasPositionChanged())
        {
            position = transform.position;
            RequestSerialization();
            lastSyncTime = Time.time;
        }
    }
}
```

## Object Pooling

Dynamic instantiation is not network-supported in VRChat. Use object pooling with pre-placed GameObjects.

For full implementations, see:
- Simple pool: [patterns-networking.md](patterns-networking.md#object-pooling)
- Master-managed player pool: [assets/templates/MasterManagedPlayerPool.cs](../assets/templates/MasterManagedPlayerPool.cs)

## Player Events

```csharp
public override void OnPlayerJoined(VRCPlayerApi player)
{
    if (player == null || !player.IsValid()) return;

    Debug.Log($"{player.displayName} joined");

    // Sync state for new player if we're owner
    if (Networking.IsOwner(gameObject))
    {
        RequestSerialization();
    }
}

public override void OnPlayerLeft(VRCPlayerApi player)
{
    if (player == null || !player.IsValid()) return;

    Debug.Log($"{player.displayName} left");

    // Handle ownership transfer if the owner left
    // VRChat automatically assigns a new owner
}

public override void OnOwnershipTransferred(VRCPlayerApi player)
{
    if (player == null || !player.IsValid()) return;

    Debug.Log($"New owner: {player.displayName}");

    if (player.isLocal)
    {
        // We are now the owner, can modify synced variables
    }
}
```

## Common Patterns

### Master-Only Actions

> **Warning**: `Networking.IsMaster` is not deprecated, but it is fragile in practice. The instance master is the first player to join. If that player leaves, the master role transfers to another player, creating a brief window where no action runs, or two clients race to act simultaneously. Prefer owner-centric patterns for any logic that must run reliably. See [Owner-Centric Architecture Migration](#owner-centric-architecture-migration) below.

```csharp
public void DoMasterAction()
{
    if (Networking.IsMaster)
    {
        // Only instance master executes this
        PerformAction();
        SendCustomNetworkEvent(NetworkEventTarget.All, "OnActionPerformed");
    }
}
```

### Local Player Detection

```csharp
public void OnInteract()
{
    VRCPlayerApi localPlayer = Networking.LocalPlayer;

    if (localPlayer != null)
    {
        interactingPlayerId = localPlayer.playerId;
        interactingPlayerName = localPlayer.displayName;
        RequestSerialization();
    }
}
```

### Synced Timer

```csharp
[UdonSynced] private float gameStartTime;
[UdonSynced] private bool gameRunning;

public void StartGame()
{
    if (!Networking.IsMaster) return;

    gameStartTime = (float)Networking.GetServerTimeInSeconds();
    gameRunning = true;
    RequestSerialization();
}

void Update()
{
    if (!gameRunning) return;

    float elapsed = (float)Networking.GetServerTimeInSeconds() - gameStartTime;
    timerDisplay.text = elapsed.ToString("F1");
}
```

---

## Owner-Centric Architecture Migration

`Networking.IsMaster` checks which player is the **instance master** (the first player to join).
Using it to gate critical logic creates two failure modes:

1. **Master-leave gap**: When the master disconnects, VRChat transfers the master role to
   another player. During the brief transition, `Networking.IsMaster` returns `false` on all
   clients simultaneously — timed events or game-state updates can be silently dropped.

2. **Concurrent master race**: If two clients check `Networking.IsMaster` in the same frame
   during a handoff, both may act, causing duplicate state mutations.

The **owner-centric** pattern reduces both risks: a specific `GameObject` has exactly one
owner at all times, so `Networking.IsOwner(gameObject)` typically returns the same result
across all clients. Note that during ownership transfers (e.g., the current owner leaves),
there is a brief transient window where clients may briefly disagree on who the owner is
until VRChat propagates the new ownership to other clients. The `OnOwnershipTransferred` callback is the correct
place to handle this case — re-initialize owner-only state and call `RequestSerialization()`
so all clients converge to the new owner's authoritative state.

### Refactoring Pattern: IsMaster → IsOwner

**Before (IsMaster)**

```csharp
public void StartGame()
{
    if (!Networking.IsMaster) return;  // Fragile: master may leave mid-check

    gameStartTime = (float)Networking.GetServerTimeInSeconds();
    gameRunning = true;
    RequestSerialization();
}
```

**After (owner-centric)**

```csharp
// Assign one dedicated GameObject as the "game manager" object.
// Its owner is the authoritative game controller.

public void StartGame()
{
    if (!Networking.IsOwner(gameObject)) return;  // Stable: exactly one owner

    gameStartTime = (float)Networking.GetServerTimeInSeconds();
    gameRunning = true;
    RequestSerialization();
}
```

### Handling Owner Leave

When the owner of the manager object leaves, VRChat automatically transfers ownership.
Resume game-manager duties in `OnOwnershipTransferred`:

```csharp
public override void OnOwnershipTransferred(VRCPlayerApi player)
{
    if (player == null || !player.IsValid()) return;

    if (player.isLocal)
    {
        // Inherited ownership — re-broadcast current state so late joiners are covered
        RequestSerialization();

        // Resume any periodic owner duties here
        if (gameRunning)
        {
            SendCustomEventDelayedSeconds(nameof(OwnerHeartbeat), 1.0f);
        }
    }
}
```

### Migration Decision Table

| Scenario | Use `IsMaster`? | Use `IsOwner`? |
|---|---|---|
| One-off world init (fires once at world launch) | Acceptable | Preferred |
| Ongoing game logic (timers, spawning, scoring) | No — fragile | Yes |
| Responding to player join/leave events | No — may double-fire | Yes |
| Approving ownership transfers (`OnOwnershipRequest`) | No — wrong API | Neither — the callback fires on both the requester and the current owner; logic must agree on both clients to avoid desync. See [Ownership Arbitration with OnOwnershipRequest](#ownership-arbitration-with-onownershiprequest) above. |
| Checking if a specific player is the master | `player.isMaster` on `VRCPlayerApi` | N/A |

> **Reference**: VRChat networking documentation — https://creators.vrchat.com/worlds/udon/networking/

---

## See Also

- [networking-bandwidth.md](networking-bandwidth.md) - Bandwidth throttling, bit packing, owner-centric architecture, debugging
- [networking-antipatterns.md](networking-antipatterns.md) - 6 anti-patterns and 5 advanced patterns
- [patterns-networking.md](patterns-networking.md) - Object pooling, game state management, NetworkCallable patterns
- [persistence.md](persistence.md) - PlayerData/PlayerObject API for persisting data across sessions
- [sync-examples.md](sync-examples.md) - Concrete synced gimmick patterns with data budget reference
- [troubleshooting.md](troubleshooting.md) - Debugging networking issues, ownership race conditions
