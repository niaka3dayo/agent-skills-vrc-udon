# UdonSharp Networking Reference

Comprehensive guide to networking and synchronization in UdonSharp.

**Supported SDK Versions**: 3.7.1 - 3.10.2 (as of March 2026)

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
- Data limit: **65KB -> 280KB** (see release notes for details)
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
| Manual | 280KB | On-demand | Game state, scores, settings |
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
// Request ownership for local player
Networking.SetOwner(Networking.LocalPlayer, gameObject);

// Note: Ownership transfer is not instant!
// The previous owner must acknowledge the transfer
```

**Important timing issue**: After `SetOwner`, the new owner cannot immediately modify synced variables. It must wait for the previous owner's acknowledgment:

```csharp
// WRONG - May fail due to timing
Networking.SetOwner(Networking.LocalPlayer, gameObject);
syncedValue = 10; // Might not sync!
RequestSerialization();

// CORRECT - Wait for ownership confirmation
public void RequestOwnershipAndUpdate(int newValue)
{
    pendingValue = newValue;
    Networking.SetOwner(Networking.LocalPlayer, gameObject);
    // Value will be set in OnOwnershipTransferred
}

public override void OnOwnershipTransferred(VRCPlayerApi player)
{
    if (player.isLocal)
    {
        syncedValue = pendingValue;
        RequestSerialization();
    }
}
```

### Ownership Transfer Timing Diagram

```text
Player A (current owner) | Player B (requesting)
-------------------------|------------------------
                        | SetOwner(B, obj)
                        | [Cannot sync yet!]
Receives request         |
Acknowledges transfer   |
                        | OnOwnershipTransferred(B)
                        | [Now safe to sync]
                        | RequestSerialization()
```

**Race condition warning**: If multiple players call `SetOwner` simultaneously, the last one processed wins. There is no built-in conflict resolution.

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

> **Important**: `OnOwnershipRequest` runs locally on **both the requester and the current owner**. The logic must be consistent on both sides to avoid desync. If the owner has disconnected, the callback is not invoked — VRChat auto-assigns directly.

## Synced Variables

### Basic Synchronization

Use the `[UdonSynced]` attribute to synchronize fields:

```csharp
[UdonSynced] private int score;
[UdonSynced] private float health;
[UdonSynced] private bool isActive;
[UdonSynced] private Vector3 position;
[UdonSynced] private string playerName; // Max ~50 characters!
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
        Networking.SetOwner(Networking.LocalPlayer, gameObject);
        return; // Wait for OnOwnershipTransferred
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
| `string` | variable | ~50 char limit |
| `Vector2/3/4` | 8/12/16 bytes | |
| `Quaternion` | 16 bytes | |
| `Color`, `Color32` | 16/4 bytes | |
| Arrays of above | variable | |

**Not usable**: `GameObject`, `Transform`, `VRCPlayerApi`, custom classes

### Practical Pattern: Damage System

```csharp
[UdonBehaviourSyncMode(BehaviourSyncMode.Manual)]
public class DamageSystem : UdonSharpBehaviour
{
    [UdonSynced] private int health = 100;

    [NetworkCallable]
    public void ApplyDamage(int damage, Vector3 hitPosition, int attackerId)
    {
        if (!Networking.IsOwner(gameObject))
        {
            // Not owner, forward to owner
            SendCustomNetworkEvent(
                NetworkEventTarget.Owner,
                nameof(ApplyDamage),
                damage, hitPosition, attackerId
            );
            return;
        }

        // Only owner processes actual damage
        health -= damage;
        RequestSerialization();

        // Show effect to all players
        SendCustomNetworkEvent(
            NetworkEventTarget.All,
            nameof(ShowDamageEffect),
            hitPosition
        );
    }

    [NetworkCallable]
    public void ShowDamageEffect(Vector3 position)
    {
        // Play particles and sounds
        SpawnDamageParticle(position);
    }
}
```

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
- **Continuous**: ~200 bytes per serialization
- **Manual**: ~280KB per serialization

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

Dynamic instantiation is not network-supported. Use object pooling:

```csharp
public class ObjectPool : UdonSharpBehaviour
{
    public GameObject[] pooledObjects;
    [UdonSynced] private int[] objectStates; // 0 = inactive, 1 = active

    void Start()
    {
        objectStates = new int[pooledObjects.Length];
    }

    public GameObject GetObject()
    {
        if (!Networking.IsOwner(gameObject))
        {
            Networking.SetOwner(Networking.LocalPlayer, gameObject);
        }

        for (int i = 0; i < pooledObjects.Length; i++)
        {
            if (objectStates[i] == 0)
            {
                objectStates[i] = 1;
                pooledObjects[i].SetActive(true);
                RequestSerialization();
                return pooledObjects[i];
            }
        }
        return null; // Pool exhausted
    }

    public void ReturnObject(GameObject obj)
    {
        if (!Networking.IsOwner(gameObject))
        {
            Networking.SetOwner(Networking.LocalPlayer, gameObject);
        }

        for (int i = 0; i < pooledObjects.Length; i++)
        {
            if (pooledObjects[i] == obj)
            {
                objectStates[i] = 0;
                pooledObjects[i].SetActive(false);
                RequestSerialization();
                return;
            }
        }
    }

    public override void OnDeserialization()
    {
        // Sync object states for late joiners
        for (int i = 0; i < pooledObjects.Length; i++)
        {
            pooledObjects[i].SetActive(objectStates[i] == 1);
        }
    }
}
```

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

## Network Bandwidth and Throttling

### Bandwidth Limits

> Udon scripts can send out about **11 kilobytes** per second.
> — [VRChat Creator Docs](https://creators.vrchat.com/worlds/udon/networking/network-details)

Exceeding this limit causes sync delays known as "Death Runs." This is particularly problematic when:
- Multiple UI elements are operated rapidly
- Many synced variables are updated simultaneously
- Players spam operations repeatedly

### Detecting Network Congestion

Use `Networking.IsClogged` to check for network queue backup:

```csharp
if (Networking.IsClogged)
{
    // Network is congested - defer synchronization
    SendCustomEventDelayedSeconds(nameof(RetrySync), 1.0f);
    return;
}
RequestSerialization();
```

### RequestSerialization Throttling Pattern

For high-frequency updates, wrap `RequestSerialization()` with interval control:

**Key principles:**
1. Enforce minimum interval between syncs (e.g., 1 second)
2. Auto-retry during network congestion
3. Prevent scheduling duplicate delayed events
4. Always sync the latest state (not intermediate states)

```csharp
private const float SyncInterval = 1.0f;
private const float RetryInterval = 1.0f;
private bool isPendingSync = false;
private double lastSyncTime = double.MinValue;

/// <summary>
/// Call this instead of RequestSerialization() for throttled sync.
/// </summary>
private void RequestSync()
{
    if (isPendingSync) return;
    if (!Networking.IsOwner(gameObject)) return;

    double now = Time.timeAsDouble;

    if (now >= lastSyncTime + SyncInterval)
    {
        ExecuteSync();
    }
    else
    {
        float delay = (float)(lastSyncTime + SyncInterval - now) + 0.001f;
        SendCustomEventDelayedSeconds(nameof(ExecuteSync), delay);
        isPendingSync = true;
    }
}

public void ExecuteSync()
{
    isPendingSync = false;
    if (!Networking.IsOwner(gameObject)) return;

    if (Networking.IsClogged)
    {
        SendCustomEventDelayedSeconds(nameof(ExecuteSync), RetryInterval);
        isPendingSync = true;
        return;
    }

    RequestSerialization();
    lastSyncTime = Time.timeAsDouble;
}
```

**Advantages:**
- Prevents network overload from rapid operations
- Auto-retries during congestion
- Always syncs the latest state
- No duplicate delayed events

**Trade-offs:**
- Up to `SyncInterval` seconds of latency
- Individual sync requests may be merged (syncing state, not events)

Reference template: `assets/templates/ThrottledSync.cs`

### Periodic Sync Pattern

Continuous synchronization at controlled intervals:

```csharp
private const float PeriodicSyncInterval = 10.0f;
private bool isPendingPeriodicSync = false;
private bool loopNeeded = false;

private void StartPeriodicSync()
{
    if (!Networking.IsOwner(gameObject)) return;
    loopNeeded = true;
    RequestPeriodicSync();
}

private void StopPeriodicSync()
{
    loopNeeded = false;
}

private void RequestPeriodicSync()
{
    if (isPendingPeriodicSync) return;
    if (!Networking.IsOwner(gameObject)) return;

    SendCustomEventDelayedSeconds(nameof(ExecutePeriodicSync), PeriodicSyncInterval);
    isPendingPeriodicSync = true;
}

public void ExecutePeriodicSync()
{
    isPendingPeriodicSync = false;
    if (!Networking.IsOwner(gameObject)) return;

    RequestSync(); // Uses throttled sync

    if (loopNeeded)
    {
        RequestPeriodicSync();
    }
}
```

## Data Size Optimization

### Sync Overhead

Each synced variable has header overhead (metadata to identify the variable). This means:

| Approach | Variable count | Sync data |
|-----------|--------|-----------|
| 8 separate `byte` | 8 | ~16 bytes (8 data + 8 overhead) |
| 1 packed `ulong` | 1 | ~9 bytes (8 data + 1 overhead) |

**Key point**: Reducing the number of variables is often more effective than reducing data size.

### Bit Packing

Pack multiple small values into fewer variables:

**Bit count and max value reference:**

| Bits | Max value | Common uses |
|---------|--------|-------------|
| 1 | 1 | Boolean flags |
| 2 | 3 | 4-state enum |
| 3 | 7 | Dice (d6), small indices |
| 4 | 15 | Hex digits, small counters |
| 5 | 31 | Days (of month) |
| 6 | 63 | Minutes, seconds |
| 7 | 127 | ASCII characters |
| 8 | 255 | Full byte |

**Example: Pack 8 bools into 1 byte (87.5% reduction)**

```csharp
// Pack
byte packed = 0;
if (flag0) packed |= 1;      // bit 0
if (flag1) packed |= 2;      // bit 1
if (flag2) packed |= 4;      // bit 2
if (flag3) packed |= 8;      // bit 3
if (flag4) packed |= 16;     // bit 4
if (flag5) packed |= 32;     // bit 5
if (flag6) packed |= 64;     // bit 6
if (flag7) packed |= 128;    // bit 7

// Unpack
bool flag0 = (packed & 1) != 0;
bool flag1 = (packed & 2) != 0;
bool flag2 = (packed & 4) != 0;
// ...
```

**Example: Pack array of 3-bit values into ulong**

```csharp
// Pack 20 values (0-7 each) into single ulong (60 bits used)
public void PackValues(byte[] values, out ulong packed)
{
    packed = 0;
    for (int i = 0; i < 20 && i < values.Length; i++)
    {
        ulong threeBits = (ulong)(values[i] & 0b111);
        packed |= threeBits << (i * 3);
    }
}

// Unpack
public void UnpackValues(ulong packed, byte[] values)
{
    for (int i = 0; i < 20 && i < values.Length; i++)
    {
        values[i] = (byte)((packed >> (i * 3)) & 0b111);
    }
}
```

Reference template: `assets/templates/BitPacking.cs`

### Range Shifting

For values with a limited range, shift to minimize bit count:

```csharp
// Value range: 200-210 (requires 8 bits as-is)
// Shifted range: 0-10 (requires only 4 bits)

// Pack
byte packed = (byte)(value - 200);

// Unpack
int value = packed + 200;
```

**Signed values**: Add an offset before packing to convert to unsigned:

```csharp
// Range: -50 to +50 (requires signed handling)
// Shifted: 0 to 100 (7 bits, unsigned)

byte packed = (byte)(signedValue + 50);
int signedValue = packed - 50;
```

### When to Use Bit Packing

| Scenario | Recommendation |
|---------|------|
| Few variables, full range used | No packing needed - not worth the overhead |
| Many bools | Pack into bytes/ints |
| Array of small integers | Pack into ulong arrays |
| Bandwidth is critical | Pack aggressively |
| Large state sync for late joiners | Consider packing |

**Caveats:**
- `FieldChangeCallback` doesn't work directly with packed variables
- Adds complexity - only use when bandwidth is a concern
- Call pack before `RequestSerialization()`, unpack in `OnDeserialization()`

## Debugging Network Issues

1. **Check Ownership**: `Debug.Log($"Owner: {Networking.GetOwner(gameObject).displayName}")`
2. **Verify Sync**: Log before and after `RequestSerialization()`
3. **Test Late Join**: Have player join mid-game to verify `OnDeserialization`
4. **Monitor Bandwidth**: Keep sync frequency low (max 10/sec per object)
5. **Test Edge Cases**: Player leaving while owning objects, rapid ownership transfers
6. **Check Congestion**: Log `Networking.IsClogged` to detect network issues
7. **Measure Data Size**: Use `OnPostSerialization(SerializationResult result)` to check `result.byteCount`

## Owner-Centric Architecture (Recommended Design)

For multiplayer games, the recommended design is **"only the owner modifies state, others receive the results."**

### Design Principles

1. **One GameManager** holds all game state synced variables (Manual sync)
2. **Only the owner** runs game logic in `Update()`
3. **Non-owners** only update display in `OnDeserialization()`
4. **UI operations** notify the owner via `SendCustomNetworkEvent(Owner)`

### Code Example: Owner-Centric GameManager

```csharp
[UdonBehaviourSyncMode(BehaviourSyncMode.Manual)]
public class GameManager : UdonSharpBehaviour
{
    [UdonSynced] private int[] boardState;
    [UdonSynced] private int currentTurn;
    [UdonSynced] private int gamePhase; // 0=Lobby, 1=Playing, 2=Result

    // --- Input from UI (fires on all clients) ---
    public void OnCellClicked(int cellIndex)
    {
        // Delegate to owner (works even if self is owner)
        SendCustomNetworkEvent(
            NetworkEventTarget.Owner,
            nameof(OwnerProcessMove),
            cellIndex,
            Networking.LocalPlayer.playerId
        );
    }

    // --- Owner only ---
    [NetworkCallable]
    public void OwnerProcessMove(int cellIndex, int playerId)
    {
        if (gamePhase != 1) return;           // Ignore if not in game
        if (playerId != GetCurrentPlayerId()) return; // Ignore if not their turn
        if (boardState[cellIndex] != 0) return;       // Already occupied

        boardState[cellIndex] = currentTurn;
        currentTurn = (currentTurn % 2) + 1;
        RequestSerialization();
    }

    // --- All clients: update display ---
    public override void OnDeserialization()
    {
        UpdateBoardDisplay();
        UpdateTurnIndicator();
    }

    private int GetCurrentPlayerId() { /* ... */ return 0; }
    private void UpdateBoardDisplay() { /* Reflect boardState in UI */ }
    private void UpdateTurnIndicator() { /* Display currentTurn */ }
}
```

**Key points:**
- UI callback -> `SendCustomNetworkEvent(Owner)` -> Owner validates and modifies -> `RequestSerialization()` -> Everyone receives via `OnDeserialization()`
- Non-owners can still press buttons (delegated to owner)
- Invalid operations can be rejected by the owner (design similar to server authority)

## Synced Data Size Optimization

VRChat's transmission bandwidth is approximately **11KB/sec**. Large synced data causes severe lag.

### Data Size Estimation

| Data | Size | Sync delay (11KB/sec) |
|--------|--------|---------------------|
| `int[40]` | 160 bytes | Instant |
| `int[400]` | 1,600 bytes | ~0.15 sec |
| `int[4000]` | 16,000 bytes | ~1.5 sec (NG) |
| `byte[100]` | 100 bytes | Instant |

### Optimization Techniques

#### 1. Use Smaller Types

```csharp
// NG: Using int (4 bytes) when values are 0-255
[UdonSynced] private int[] bottleColors; // 40 elements = 160 bytes

// OK: byte (1 byte) is sufficient
[UdonSynced] private byte[] bottleColors; // 40 elements = 40 bytes (75% reduction)
```

#### 2. Bit Packing (Many Small Values)

Color IDs (0-7) are 3 bits. 2 colors can be stored in 1 byte. See the Data Size Optimization section for details.

```csharp
// 40 colors x 3 bits = 120 bits = 15 bytes (160 bytes from int[40] -> 93% reduction)
[UdonSynced] private byte[] packedColors; // 15 bytes stores 40 colors

private byte GetColor(int index)
{
    int byteIdx = (index * 3) / 8;
    int bitOffset = (index * 3) % 8;
    int raw = packedColors[byteIdx] | (packedColors[byteIdx + 1] << 8);
    return (byte)((raw >> bitOffset) & 0x07);
}
```

#### 3. Delta Sync (Send Only Changes)

Sync only changes instead of the full state. Send full state initially, then only deltas.

```csharp
// Instead of syncing full state every time, sync only the latest operation
[UdonSynced] private int lastMoveFrom;
[UdonSynced] private int lastMoveTo;
[UdonSynced] private int moveCounter; // For change detection

public override void OnDeserialization()
{
    // Re-apply the operation locally on the receiving side
    ApplyMove(lastMoveFrom, lastMoveTo);
}
```

**Note:** Delta sync does not handle late joiners. If full state restoration is needed for initial connections, maintain full state in a synced array as well.

## Networking Anti-Patterns

Common mistakes in UdonSharp networking that cause silent failures, data loss, or undefined behavior. Each pattern includes the problem, a wrong implementation, and the correct fix.

---

### 1. Ownership Race Condition

**Problem**: Two clients call `Networking.SetOwner` simultaneously for the same object. There is no built-in conflict resolution — the last-processed `SetOwner` wins, which is non-deterministic. Whichever client "loses" the race will have its synced variable writes silently discarded because `RequestSerialization()` is called before ownership is confirmed.

**Wrong:**

```csharp
// Client A and Client B both execute this at the same time
public void TryCapture()
{
    Networking.SetOwner(Networking.LocalPlayer, gameObject);
    capturedBy = Networking.LocalPlayer.playerId; // May be overwritten by Client B
    RequestSerialization();                        // May be dropped — not owner yet
}
```

**Correct:**

```csharp
[UdonBehaviourSyncMode(BehaviourSyncMode.Manual)]
public class CapturePoint : UdonSharpBehaviour
{
    [UdonSynced] private int capturedBy = -1;
    private int _pendingCaptureId = -1;

    public void TryCapture()
    {
        // Store intent, then request ownership
        _pendingCaptureId = Networking.LocalPlayer.playerId;
        Networking.SetOwner(Networking.LocalPlayer, gameObject);
        // Do NOT write synced variables here — ownership is not confirmed yet
    }

    public override void OnOwnershipTransferred(VRCPlayerApi player)
    {
        if (!player.isLocal) return;

        // Only write + serialize after confirmed ownership
        capturedBy = _pendingCaptureId;
        RequestSerialization();
    }
}
```

**Explanation**: `Networking.SetOwner` is asynchronous. The previous owner must acknowledge the transfer before `OnOwnershipTransferred` fires on the new owner. Writing synced variables before that callback means the write may come from a non-owner and will be silently ignored by VRChat. Use `OnOwnershipTransferred` as the commit point.

---

### 2. Synced String Silent Truncation

**Problem**: A synced `string` in a `Continuous` sync behaviour is bounded by the ~200-byte serialization budget. UTF-16 encodes each character as 2 bytes, so a string exceeding ~100 characters will be silently truncated with no runtime error or warning. The receiving client sees a shorter, corrupted string.

**Wrong:**

```csharp
[UdonBehaviourSyncMode(BehaviourSyncMode.Continuous)]
public class PlayerTag : UdonSharpBehaviour
{
    // A user could enter a 200-character message — truncated silently
    [UdonSynced] public string displayMessage;

    public void SetMessage(string msg)
    {
        displayMessage = msg; // No length check
    }
}
```

**Correct:**

```csharp
[UdonBehaviourSyncMode(BehaviourSyncMode.Continuous)]
public class PlayerTag : UdonSharpBehaviour
{
    // UTF-16: 2 bytes/char. Budget ~200 bytes total for ALL synced vars.
    // Reserve headroom for other fields; keep strings short.
    private const int MaxMessageBytes = 80; // ~40 characters safe margin
    private const int BytesPerChar = 2;     // UTF-16
    private const int MaxMessageChars = MaxMessageBytes / BytesPerChar;

    [UdonSynced] public string displayMessage;

    public void SetMessage(string msg)
    {
        if (msg == null) msg = string.Empty;

        // Detect potential truncation before it happens
        if (msg.Length > MaxMessageChars)
        {
            Debug.LogWarning(
                $"[PlayerTag] Message too long ({msg.Length} chars, max {MaxMessageChars}). Truncating.");
            msg = msg.Substring(0, MaxMessageChars);
        }

        displayMessage = msg;
    }
}
```

**Explanation**: VRChat does not throw an error when a synced string exceeds the serialization budget — it simply stops writing at the byte limit. Always enforce a character budget before assigning to `[UdonSynced] string`, especially in `Continuous` mode where the per-behaviour budget is only ~200 bytes shared among all synced variables. Use `Manual` sync mode if you need longer strings (up to ~280KB).

---

### 3. Sync Buffer Overflow

**Problem**: `Manual` sync allows up to ~280KB per serialization, but it is still possible to exceed the buffer with large arrays. When the serialized payload exceeds the limit, VRChat silently drops the entire sync packet — no partial delivery, no error. Recipients see stale data.

**Wrong:**

```csharp
[UdonBehaviourSyncMode(BehaviourSyncMode.Manual)]
public class MapData : UdonSharpBehaviour
{
    // 512 x 512 grid as ints = 512 * 512 * 4 bytes = 1,048,576 bytes (~1MB) — exceeds limit!
    [UdonSynced] private int[] tiles = new int[512 * 512];

    public void SaveAndSync()
    {
        // Packet silently dropped — recipients never update
        RequestSerialization();
    }
}
```

**Correct:**

```csharp
[UdonBehaviourSyncMode(BehaviourSyncMode.Manual)]
public class MapData : UdonSharpBehaviour
{
    // Manual sync budget: ~280KB = 286,720 bytes
    // byte[] uses 1 byte/element vs int[] at 4 bytes/element
    // 256 x 256 as byte = 65,536 bytes — well within budget
    private const int MapSize = 256;
    private const int MaxSyncBytes = 280 * 1024; // 286,720 bytes

    [UdonSynced] private byte[] tiles = new byte[MapSize * MapSize];

    public void SaveAndSync()
    {
        // Check estimated size before serializing
        int estimatedBytes = tiles.Length; // 1 byte per element
        if (estimatedBytes > MaxSyncBytes)
        {
            Debug.LogError(
                $"[MapData] Sync payload too large: {estimatedBytes} bytes (max {MaxSyncBytes}). Aborting.");
            return;
        }

        RequestSerialization();
    }

    // For very large maps: chunk into multiple behaviours or use delta sync
    // See: Delta Sync section above
}
```

**Explanation**: Use `OnPostSerialization(SerializationResult result)` to measure actual byte usage in the editor, then enforce a budget at runtime. Prefer `byte` over `int` for tile data, and consider delta sync (send only changes) for maps larger than ~64KB. Never assume the packet was delivered — use a `moveCounter` or version field to detect missed updates.

---

### 4. Mixing Continuous and Manual Sync

**Problem**: Setting `BehaviourSyncMode` to both `Continuous` and `Manual` on the same behaviour is not valid — `BehaviourSyncMode` is a single enum value. However, a common mistake is adding `RequestSerialization()` calls inside a `Continuous` behaviour, or annotating a `Manual` behaviour with interpolation modes (`UdonSyncMode.Linear`/`Smooth`) expecting automatic 10Hz updates. Neither combination produces the intended result.

**Wrong:**

```csharp
// Attempting to get both automatic 10Hz sync AND explicit sync control
[UdonBehaviourSyncMode(BehaviourSyncMode.Continuous)]
public class BadSyncMix : UdonSharpBehaviour
{
    [UdonSynced(UdonSyncMode.Linear)] private Vector3 position;
    [UdonSynced] private int score; // Discrete value in Continuous mode — wastes bandwidth

    void Update()
    {
        if (Networking.IsOwner(gameObject))
        {
            position = transform.position;
            score = CalculateScore();
            RequestSerialization(); // Redundant in Continuous mode; called every frame
        }
    }
}
```

**Correct:**

```csharp
// Behaviour A: Continuous — position only, no RequestSerialization
[UdonBehaviourSyncMode(BehaviourSyncMode.Continuous)]
public class PositionSync : UdonSharpBehaviour
{
    [UdonSynced(UdonSyncMode.Linear)] private Vector3 position;

    void Update()
    {
        if (Networking.IsOwner(gameObject))
        {
            position = transform.position;
            // No RequestSerialization() — Continuous mode handles transmission automatically
        }
        else
        {
            transform.position = position;
        }
    }
}

// Behaviour B: Manual — score only, explicit sync on change
[UdonBehaviourSyncMode(BehaviourSyncMode.Manual)]
public class ScoreSync : UdonSharpBehaviour
{
    [UdonSynced] private int score;

    public void UpdateScore(int newScore)
    {
        if (!Networking.IsOwner(gameObject)) return;
        score = newScore;
        RequestSerialization(); // Explicit sync only when value changes
    }

    public override void OnDeserialization()
    {
        UpdateScoreDisplay();
    }

    private void UpdateScoreDisplay() { /* Update UI */ }
}
```

**Explanation**: Separate concerns by sync mode. `Continuous` is for values that change every frame (position, rotation); `Manual` is for discrete state changes (score, game phase). Mixing them on one behaviour wastes bandwidth (`Continuous` on score data) or loses features (`RequestSerialization()` is a no-op on `None` mode and has redundant effect on `Continuous`). Keep each behaviour focused on one sync mode.

---

### 5. Sync Without Ownership

**Problem**: Modifying a `[UdonSynced]` variable without being the owner causes the change to be silently reverted on the next deserialization. VRChat does not throw an error — the local variable appears to change, but the change is never broadcast and will be overwritten when the actual owner next serializes.

**Wrong:**

```csharp
[UdonBehaviourSyncMode(BehaviourSyncMode.Manual)]
public class GameFlag : UdonSharpBehaviour
{
    [UdonSynced] public bool isCaptured;

    public override void OnTriggerEnter(Collider other)
    {
        // Any player can run this, but only the owner's write will persist
        isCaptured = true;
        RequestSerialization(); // Silently fails if not owner — isCaptured reverts next sync
    }
}
```

**Correct:**

```csharp
[UdonBehaviourSyncMode(BehaviourSyncMode.Manual)]
public class GameFlag : UdonSharpBehaviour
{
    [UdonSynced] public bool isCaptured;

    public override void OnTriggerEnter(Collider other)
    {
        if (!Networking.IsOwner(gameObject))
        {
            // Become owner first, then write in OnOwnershipTransferred
            Networking.SetOwner(Networking.LocalPlayer, gameObject);
            return;
        }

        SetCaptured(true);
    }

    public override void OnOwnershipTransferred(VRCPlayerApi player)
    {
        if (!player.isLocal) return;

        // Ownership confirmed — safe to write and serialize
        SetCaptured(true);
    }

    private void SetCaptured(bool value)
    {
        isCaptured = value;
        RequestSerialization();
    }

    public override void OnDeserialization()
    {
        UpdateFlagVisual();
    }

    private void UpdateFlagVisual() { /* Update flag appearance */ }
}
```

**Explanation**: In UdonSharp, only the current owner's `RequestSerialization()` calls are transmitted. Non-owner writes to `[UdonSynced]` variables are purely local and will be overwritten by the next deserialization from the actual owner. Always guard synced writes with `Networking.IsOwner(gameObject)` and use the `SetOwner` + `OnOwnershipTransferred` pattern when ownership transfer is needed.

---

### 6. Excessive RequestSerialization

**Problem**: Calling `RequestSerialization()` every frame (or on every `Update` tick) floods the network. VRChat's Udon network budget is approximately **11KB/sec**. A 60Hz `Update` calling `RequestSerialization()` can consume that budget alone, causing "Death Run" congestion for all other network operations in the world.

**Wrong:**

```csharp
[UdonBehaviourSyncMode(BehaviourSyncMode.Manual)]
public class FrequentSync : UdonSharpBehaviour
{
    [UdonSynced] private Vector3 trackedPosition;

    void Update()
    {
        if (!Networking.IsOwner(gameObject)) return;

        trackedPosition = transform.position;
        RequestSerialization(); // Called ~60 times/sec — severe bandwidth waste
    }
}
```

**Correct:**

```csharp
[UdonBehaviourSyncMode(BehaviourSyncMode.Manual)]
public class ThrottledSync : UdonSharpBehaviour
{
    [UdonSynced] private Vector3 trackedPosition;

    private const float SyncInterval = 0.1f;       // Max 10 syncs/sec
    private const float PositionThreshold = 0.01f; // Skip if barely moved
    private const float RetryInterval = 1.0f;

    private float _lastSyncTime = float.MinValue;
    private bool _isPendingSync = false;

    void Update()
    {
        if (!Networking.IsOwner(gameObject)) return;

        Vector3 current = transform.position;

        // Skip if position has not changed meaningfully
        if (Vector3.Distance(current, trackedPosition) < PositionThreshold) return;

        trackedPosition = current;
        RequestSync();
    }

    private void RequestSync()
    {
        if (_isPendingSync) return;

        float now = Time.time;
        float remaining = (_lastSyncTime + SyncInterval) - now;

        if (remaining <= 0f)
        {
            ExecuteSync();
        }
        else
        {
            // Schedule a single deferred sync — coalesces rapid changes
            SendCustomEventDelayedSeconds(nameof(ExecuteSync), remaining + 0.001f);
            _isPendingSync = true;
        }
    }

    public void ExecuteSync()
    {
        _isPendingSync = false;
        if (!Networking.IsOwner(gameObject)) return;

        if (Networking.IsClogged)
        {
            // Back off and retry during congestion
            SendCustomEventDelayedSeconds(nameof(ExecuteSync), RetryInterval);
            _isPendingSync = true;
            return;
        }

        RequestSerialization();
        _lastSyncTime = Time.time;
    }
}
```

**Explanation**: Throttle `RequestSerialization()` to a maximum frequency appropriate for the data type (10Hz for position is generous; game state changes rarely need more than 1-2Hz). Combine throttling with a change threshold so unchanged values never trigger a sync. Check `Networking.IsClogged` before serializing and use `SendCustomEventDelayedSeconds` to retry rather than spinning in `Update`. See the [RequestSerialization Throttling Pattern](#requestserialization-throttling-pattern) section for a reusable implementation.

## Advanced Networking Patterns

Techniques for reducing sync variable count, controlling serialization timing, and surviving network congestion.

---

### 1. Packed Sync Data

**Problem**: Each `[UdonSynced]` variable consumes sync budget independently. A behaviour with many small values wastes budget on per-variable overhead.

**Solution**: Pack multiple independent values into a single variable using the natural layout of numeric types.

- `Vector3` stores 3 independent floats — use each component for a different purpose (e.g., `x` = question index, `y` = game type, `z` = category).
- `int` stores 32 bits — encode multiple small integers via bit shifting.
- A single `int` used as a bit field replaces a group of `bool` variables.

```csharp
using UdonSharp;
using UnityEngine;
using VRC.SDKBase;

/// <summary>
/// Demonstrates packing three independent game-state values into one Vector3
/// synced variable, reducing per-variable overhead.
/// </summary>
[UdonBehaviourSyncMode(BehaviourSyncMode.Manual)]
public class PackedStateSync : UdonSharpBehaviour
{
    // --- Three logically independent state values ---
    private int _questionIndex; // 0-255 range is safe as a float mantissa value
    private int _gameType;      // small enum (0-15)
    private int _category;      // small enum (0-31)

    /// <summary>Single synced variable carries all three values.</summary>
    [UdonSynced] private Vector3 _packedState;

    // -----------------------------------------------
    // Packing: owner writes local values into Vector3
    // -----------------------------------------------

    private void PackState()
    {
        // Each component holds one value; cast to float is exact for small integers
        _packedState = new Vector3(_questionIndex, _gameType, _category);
    }

    // -----------------------------------------------
    // Unpacking: non-owners read from Vector3
    // -----------------------------------------------

    private void UnpackState()
    {
        _questionIndex = Mathf.RoundToInt(_packedState.x);
        _gameType      = Mathf.RoundToInt(_packedState.y);
        _category      = Mathf.RoundToInt(_packedState.z);
    }

    // -----------------------------------------------
    // Serialization hooks
    // -----------------------------------------------

    public override void OnPreSerialization()
    {
        PackState();
    }

    public override void OnDeserialization()
    {
        UnpackState();
        ApplyStateLocally();
    }

    // -----------------------------------------------
    // Public API — owner calls these to change state
    // -----------------------------------------------

    public void SetQuestion(int index, int gameType, int category)
    {
        if (!Networking.IsOwner(gameObject)) return;

        _questionIndex = index;
        _gameType      = gameType;
        _category      = category;
        RequestSerialization();
    }

    private void ApplyStateLocally()
    {
        // React to the newly unpacked values (update UI, enable objects, etc.)
        Debug.Log($"[PackedStateSync] Q={_questionIndex} Type={_gameType} Cat={_category}");
    }
}
```

**Key constraints**:
- `float` has 24-bit mantissa precision — integers up to 16,777,216 round-trip exactly through `Vector3`.
- Use `Mathf.RoundToInt` on unpack to absorb any floating-point noise.
- Do not use this technique for values that need interpolation; use separate synced floats for those.

---

### 2. Rate-Limited Serialization

**Problem**: Rapid user interactions (dragging a slider, scrubbing a seek bar) can fire dozens of change events per second. Calling `RequestSerialization()` on every event floods the ~11 KB/s Udon network budget.

**Solution**: Use a `_syncLocked` flag and `SendCustomEventDelayedSeconds` to enforce a minimum cooldown between serializations. Only the value present at the end of the cooldown window is sent, so fast-moving values coalesce naturally.

```csharp
using UdonSharp;
using UnityEngine;
using VRC.SDKBase;

/// <summary>
/// Rate-limits serialization so that rapid changes (e.g., slider drag)
/// produce at most one sync per cooldown window. The last value written
/// during the window is always the one that gets sent.
/// </summary>
[UdonBehaviourSyncMode(BehaviourSyncMode.Manual)]
public class RateLimitedSync : UdonSharpBehaviour
{
    // How long to wait before allowing the next serialization (seconds).
    private const float SyncCooldown = 0.15f;

    [UdonSynced] private float _syncedValue;

    // Local working copy — always authoritative on the owner.
    private float _localValue;

    // True while a delayed sync is already scheduled.
    private bool _syncLocked;

    // Counts how many times _localValue changed during the current lock.
    // Used to detect whether a final sync is needed after unlock.
    private int _changeCounterAtLock;
    private int _changeCounter;

    // -----------------------------------------------
    // Public API — called by UI events, etc.
    // -----------------------------------------------

    /// <summary>Owner calls this whenever the controlled value changes.</summary>
    public void OnValueChanged(float newValue)
    {
        if (!Networking.IsOwner(gameObject)) return;

        _localValue = newValue;
        _changeCounter++;

        if (_syncLocked)
        {
            // A send is already scheduled; the updated _localValue will be
            // picked up when the lock expires.
            return;
        }

        // First change in a new window: lock immediately and schedule unlock.
        _syncLocked = true;
        _changeCounterAtLock = _changeCounter;
        SendCustomEventDelayedSeconds(nameof(_OnSyncUnlock), SyncCooldown);
    }

    // -----------------------------------------------
    // Delayed callback — called by SendCustomEventDelayedSeconds
    // -----------------------------------------------

    /// <summary>Invoked after the cooldown; serializes the latest value.</summary>
    public void _OnSyncUnlock()
    {
        _syncLocked = false;

        // Always serialize once on unlock to capture the final value.
        ExecuteSync();

        // If the value kept changing while we were locked, one more
        // delayed sync guarantees the very last write is transmitted.
        if (_changeCounter != _changeCounterAtLock)
        {
            _syncLocked = true;
            _changeCounterAtLock = _changeCounter;
            SendCustomEventDelayedSeconds(nameof(_OnSyncUnlock), SyncCooldown);
        }
    }

    // -----------------------------------------------
    // Serialization helpers
    // -----------------------------------------------

    private void ExecuteSync()
    {
        if (!Networking.IsOwner(gameObject)) return;
        _syncedValue = _localValue;
        RequestSerialization();
    }

    public override void OnDeserialization()
    {
        _localValue = _syncedValue;
        ApplyValue(_localValue);
    }

    private void ApplyValue(float value)
    {
        // Apply the synced value (e.g., set audio volume, seek position, etc.)
        Debug.Log($"[RateLimitedSync] Applied value: {value}");
    }
}
```

**How it works**:
1. The first change within a cooldown window locks further serializations and schedules `_OnSyncUnlock`.
2. Subsequent changes during the lock update `_localValue` but do not schedule additional events.
3. When the lock expires, `_OnSyncUnlock` serializes the current (latest) value.
4. The `_changeCounter` comparison ensures one extra window fires if the value was still moving at unlock time, guaranteeing the last write reaches the network.

---

### 3. Dual-Copy Sync Variables

**Problem**: Writing directly to `[UdonSynced]` variables from non-owner code is silently discarded at the next `OnDeserialization`. Code that freely mixes reads and writes to synced variables is error-prone and hard to reason about.

**Solution**: Maintain a *local working copy* alongside each synced variable. The local copy is the single source of truth for all in-world logic. `OnPreSerialization` copies local → synced; `OnDeserialization` copies synced → local. A dirty flag prevents unnecessary serializations.

```csharp
using UdonSharp;
using UnityEngine;
using VRC.SDKBase;

/// <summary>
/// Dual-copy pattern: a local working variable drives all in-world logic
/// while its synced counterpart handles network transport only.
/// </summary>
[UdonBehaviourSyncMode(BehaviourSyncMode.Manual)]
public class DualCopySync : UdonSharpBehaviour
{
    // ------------------------------------------------------------------
    // Local working copy — read/write freely from any in-world code.
    // Initialized to a sensible default; set by the owner at runtime.
    // ------------------------------------------------------------------
    public float volume = 0.5f;

    // ------------------------------------------------------------------
    // Synced copy — touched only in OnPreSerialization / OnDeserialization.
    // Never write to this directly outside of those two methods.
    // ------------------------------------------------------------------
    [UdonSynced] private float _syncedVolume;

    // True when the local copy differs from what was last serialized.
    private bool _dirty;

    // ------------------------------------------------------------------
    // Public API — any code (owner only) calls this to change volume.
    // ------------------------------------------------------------------

    public void SetVolume(float newVolume)
    {
        if (!Networking.IsOwner(gameObject)) return;

        if (Mathf.Approximately(newVolume, volume)) return; // No change — skip

        volume = newVolume;
        _dirty = true;
        RequestSerialization();
    }

    // ------------------------------------------------------------------
    // Serialization hooks
    // ------------------------------------------------------------------

    public override void OnPreSerialization()
    {
        if (!_dirty) return; // Nothing changed since last sync

        // Copy local → synced immediately before the packet is built.
        _syncedVolume = volume;
        _dirty = false;
    }

    public override void OnDeserialization()
    {
        // Copy synced → local so the rest of the world uses the new value.
        volume = _syncedVolume;
        ApplyVolume(volume);
    }

    // ------------------------------------------------------------------
    // Internal application of the value
    // ------------------------------------------------------------------

    private void ApplyVolume(float v)
    {
        // Drive audio sources, UI sliders, etc. from the local copy only.
        Debug.Log($"[DualCopySync] Volume applied: {v:F2}");
    }
}
```

**Benefits**:
- All game logic reads `volume` — no conditional owner checks scattered throughout the codebase.
- `_syncedVolume` is never written outside the two serialization hooks, making networking logic easy to audit.
- The dirty flag ensures `RequestSerialization()` produces a packet only when the value genuinely changed, avoiding spurious traffic.

---

### 4. Delayed Serialization Batching

**Problem**: Multiple rapid events (several players joining in quick succession, multi-field form submission) each call `RequestSerialization()` independently, producing redundant packets that carry nearly identical payloads.

**Solution**: Instead of serializing immediately, set a *pending* flag and schedule a single delayed serialization. All changes that arrive before the delay fires are batched into one packet.

```csharp
using UdonSharp;
using UnityEngine;
using VRC.SDKBase;

/// <summary>
/// Batches rapid state changes into a single serialization call by
/// deferring the actual RequestSerialization() by a short delay.
/// </summary>
[UdonBehaviourSyncMode(BehaviourSyncMode.Manual)]
public class BatchedSync : UdonSharpBehaviour
{
    // Delay before the batched serialization fires (seconds).
    private const float BatchDelay = 0.2f;

    [UdonSynced] private int  _playerCount;
    [UdonSynced] private int  _readyFlags;   // Bit field: one bit per player slot
    [UdonSynced] private int  _roundNumber;

    // True while a delayed serialization is already scheduled.
    private bool _syncPending;

    // ------------------------------------------------------------------
    // State mutation methods — each marks dirty and schedules one batch.
    // ------------------------------------------------------------------

    public void OnPlayerJoined(int slotIndex)
    {
        if (!Networking.IsOwner(gameObject)) return;

        _playerCount++;
        _readyFlags &= ~(1 << slotIndex); // New player is not ready yet
        ScheduleBatchedSync();
    }

    public void OnPlayerReady(int slotIndex)
    {
        if (!Networking.IsOwner(gameObject)) return;

        _readyFlags |= (1 << slotIndex);
        ScheduleBatchedSync();
    }

    public void AdvanceRound()
    {
        if (!Networking.IsOwner(gameObject)) return;

        _roundNumber++;
        _playerCount = 0;
        _readyFlags  = 0;
        ScheduleBatchedSync();
    }

    // ------------------------------------------------------------------
    // Batching logic
    // ------------------------------------------------------------------

    private void ScheduleBatchedSync()
    {
        if (_syncPending) return; // Batch already queued — do nothing

        _syncPending = true;
        SendCustomEventDelayedSeconds(nameof(_FlushBatch), BatchDelay);
    }

    /// <summary>Delayed callback: serialize all accumulated changes at once.</summary>
    public void _FlushBatch()
    {
        _syncPending = false;

        if (!Networking.IsOwner(gameObject)) return;

        RequestSerialization();
    }

    // ------------------------------------------------------------------
    // Deserialization
    // ------------------------------------------------------------------

    public override void OnDeserialization()
    {
        UpdateGameUI(_playerCount, _readyFlags, _roundNumber);
    }

    private void UpdateGameUI(int count, int flags, int round)
    {
        Debug.Log($"[BatchedSync] Round={round} Players={count} Ready=0b{System.Convert.ToString(flags, 2)}");
    }
}
```

**Key points**:
- `ScheduleBatchedSync` is idempotent: calling it multiple times before the delay fires has no effect beyond the first call.
- All three fields (`_playerCount`, `_readyFlags`, `_roundNumber`) are serialized together in one packet, regardless of how many mutation methods were called during the batch window.
- Tune `BatchDelay` to balance latency against packet reduction. 100–300 ms is typically invisible to players for non-positional state.

---

### 5. IsClogged Retry Pattern

**Problem**: When the Udon network is congested, `RequestSerialization()` calls may be silently dropped. There is no built-in retry or acknowledgement.

**Solution**: Check `Networking.IsClogged` before serializing. If the network is congested, skip the call and schedule a retry via `SendCustomEventDelayedSeconds`. Cap total retry attempts to prevent infinite retry storms during extended outages.

```csharp
using UdonSharp;
using UnityEngine;
using VRC.SDKBase;

/// <summary>
/// Wraps RequestSerialization() with a congestion-aware retry loop.
/// Retries up to MaxRetries times before giving up to avoid infinite loops
/// during sustained network outages.
/// </summary>
[UdonBehaviourSyncMode(BehaviourSyncMode.Manual)]
public class CloggedRetrySync : UdonSharpBehaviour
{
    // Seconds to wait between retry attempts when the network is clogged.
    private const float RetryDelay   = 1.5f;

    // Maximum number of consecutive retry attempts before abandoning the sync.
    private const int   MaxRetries   = 5;

    [UdonSynced] private int _gameScore;
    [UdonSynced] private int _gameState; // 0=Idle, 1=Playing, 2=Ended

    // Tracks how many retries have been attempted for the current pending sync.
    private int _retryCount;

    // True while a retry is scheduled so we don't double-schedule.
    private bool _retryPending;

    // ------------------------------------------------------------------
    // Public API
    // ------------------------------------------------------------------

    public void UpdateScore(int score)
    {
        if (!Networking.IsOwner(gameObject)) return;

        _gameScore = score;
        TrySerialize();
    }

    public void SetGameState(int state)
    {
        if (!Networking.IsOwner(gameObject)) return;

        _gameState = state;
        TrySerialize();
    }

    // ------------------------------------------------------------------
    // Serialization with IsClogged check
    // ------------------------------------------------------------------

    private void TrySerialize()
    {
        if (!Networking.IsOwner(gameObject)) return;

        if (Networking.IsClogged)
        {
            ScheduleRetry();
            return;
        }

        // Network is clear — reset retry state and serialize.
        _retryCount   = 0;
        _retryPending = false;
        RequestSerialization();
    }

    private void ScheduleRetry()
    {
        if (_retryPending) return; // Already waiting — do not stack retries

        if (_retryCount >= MaxRetries)
        {
            Debug.LogWarning(
                $"[CloggedRetrySync] Gave up after {MaxRetries} retries. " +
                "Network congestion is severe or persistent.");
            _retryCount   = 0;
            _retryPending = false;
            return;
        }

        _retryCount++;
        _retryPending = true;

        float delay = RetryDelay * _retryCount; // Back off linearly per attempt
        SendCustomEventDelayedSeconds(nameof(_RetrySerialize), delay);
    }

    /// <summary>Delayed retry callback.</summary>
    public void _RetrySerialize()
    {
        _retryPending = false;
        TrySerialize(); // Checks IsClogged again; may schedule another retry
    }

    // ------------------------------------------------------------------
    // Deserialization
    // ------------------------------------------------------------------

    public override void OnDeserialization()
    {
        ApplyState(_gameScore, _gameState);
    }

    private void ApplyState(int score, int state)
    {
        Debug.Log($"[CloggedRetrySync] Score={score} State={state}");
    }
}
```

**Design notes**:
- `_retryPending` prevents multiple overlapping `SendCustomEventDelayedSeconds` chains from accumulating if `TrySerialize` is called again while a retry is already queued.
- Linear back-off (`RetryDelay * _retryCount`) reduces pressure on an already-congested network rather than hammering it at a fixed interval.
- `MaxRetries` caps total attempts. In practice, VRChat network congestion resolves within a few seconds; five retries at 1.5 s increments covers ~22 s of congestion before giving up.
- After an abandonment, the next call to `UpdateScore` or `SetGameState` resets the counter and starts fresh.

---

## See Also

- [sync-examples.md](sync-examples.md) - Concrete synced gimmick patterns with data budget reference
- [troubleshooting.md](troubleshooting.md) - Debugging networking issues, ownership race conditions, and late-joiner problems
- [patterns.md](patterns.md) - Reusable ownership, initialization, and state-machine patterns
- [events.md](events.md) - Serialization and ownership event signatures (`OnDeserialization`, `OnOwnershipTransferred`)
