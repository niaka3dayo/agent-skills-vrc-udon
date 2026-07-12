# UdonSharp Networking Rules (Always Loaded)

Core networking rules and constraints. See `../references/networking.md` for detailed patterns.

**SDK Coverage**: 3.7.1 - 3.10.4

## Ownership Model

- Each GameObject has exactly one network owner
- **Only the owner can modify synced variables**
- Transfer ownership: `Networking.SetOwner(Networking.LocalPlayer, gameObject)`
- Check ownership: `Networking.IsOwner(gameObject)`

```csharp
// Standard pattern: Check -> Acquire -> Modify -> Send
if (!Networking.IsOwner(gameObject))
    Networking.SetOwner(Networking.LocalPlayer, gameObject);
syncedValue = newValue;
RequestSerialization();
```

## Sync Modes

| Mode | Attribute Value | Characteristics | Data Limit |
|------|----------------|-----------------|------------|
| **NoVariableSync** | `BehaviourSyncMode.NoVariableSync` | No variable sync, events only | - |
| **Continuous** | `BehaviourSyncMode.Continuous` | Automatic sync ~10Hz | ~200 bytes |
| **Manual** | `BehaviourSyncMode.Manual` | Explicit sync via `RequestSerialization()` | ~280KB (280,496 bytes) |

### Continuous

- `RequestSerialization()` not needed (sent automatically)
- Suitable for continuously changing values like position/rotation
- Be mindful of data size limit (~200 bytes)

### Manual

- `RequestSerialization()` required
- Suitable for infrequent updates like game state/score
- Supports large data payloads

```csharp
[UdonBehaviourSyncMode(BehaviourSyncMode.Manual)]
public class GameState : UdonSharpBehaviour
{
    [UdonSynced] private int score;

    public void AddScore(int points)
    {
        Networking.SetOwner(Networking.LocalPlayer, gameObject);
        score += points;
        RequestSerialization();
    }
}
```

## RequestSerialization Pattern

Manual sync procedure: Acquire ownership -> Update synced variables -> `RequestSerialization()` -> Receivers react in `OnDeserialization()`

## String Sync Limitations

Synced `string` fields are encoded at 2 bytes/char. There is no separate per-string character limit; the practical limit depends on the sync mode's serialization budget:

- **Continuous**: strings share the ~200-byte budget with all other synced fields on the behaviour. Keep synced strings short (a single short word or short code), as even a 20-character string consumes 40 bytes.
- **Manual**: strings can be much larger within the ~280KB (280,496 byte) per-serialization limit.

For longer data in Continuous mode, consider splitting across multiple fields or switching to Manual sync.

## NetworkCallable (SDK 3.8.1+)

Parameterized network events. Supports sending up to 8 parameters. `NetworkCallableAttribute` is in `VRC.SDK3.UdonNetworkCalling`; add `using VRC.SDK3.UdonNetworkCalling;` in scripts that declare `[NetworkCallable]` methods.

```csharp
using UdonSharp;
using VRC.SDK3.UdonNetworkCalling;
using VRC.SDKBase;
using VRC.Udon.Common.Interfaces;

[UdonBehaviourSyncMode(BehaviourSyncMode.Manual)]
public class OwnerControlledScore : UdonSharpBehaviour
{
    [UdonSynced] private int score;

    // Local-only event target: the underscore blocks legacy network calls.
    // Do not add [NetworkCallable].
    public void _RequestScoreReset()
    {
        SendCustomNetworkEvent(
            NetworkEventTarget.Owner,
            nameof(_OwnerResetScore)
        );
    }

    // The attribute explicitly exposes this underscore-prefixed method.
    [NetworkCallable(1)]
    public void _OwnerResetScore()
    {
        if (!NetworkCalling.InNetworkCall) return;

        VRCPlayerApi caller = NetworkCalling.CallingPlayer;
        if (caller == null || !caller.IsValid()) return;

        // Owner-only action policy: authorize the sender against the object
        // owner, then separately require local receiver ownership below.
        VRCPlayerApi owner = Networking.GetOwner(gameObject);
        if (owner == null || !owner.IsValid()) return;
        if (caller.playerId != owner.playerId) return;

        // This authorizes where synced state may be mutated; it does not
        // authenticate or authorize the caller.
        if (!Networking.IsOwner(gameObject)) return;

        score = 0;
        RequestSerialization();
    }
}
```

### Network Event Hardening

A parameterless public UdonSharp method whose name does not start with `_` remains exposed to legacy `SendCustomNetworkEvent` calls even without `[NetworkCallable]`.

A legacy parameterless public method may return a value, but remote dispatch discards that value; the method remains network attack surface and the audit includes it.

A leading underscore blocks legacy network calls to a public method.

`[NetworkCallable]` explicitly exposes an underscore-prefixed public method to network calls.

`NetworkCalling.InNetworkCall` remains true through nested methods and cross-behaviour calls until the network entry method returns.

`NetworkCalling.CallingPlayer` is null or invalid outside a network call.

Caller authorization and receiver ownership are separate checks: authorize `NetworkCalling.CallingPlayer`, then use `Networking.IsOwner(gameObject)` to guard synced mutation on the receiver.

- Prefix local-only public event targets and helpers with an underscore and do not add `[NetworkCallable]`.
- Treat every network parameter, including a claimed `playerId` or display name, as caller-controlled data. Never use it for authorization.
- In a network entry point, require `NetworkCalling.InNetworkCall`, read `NetworkCalling.CallingPlayer`, validate it, and apply an explicit session policy owned by the world.

> **Official warning:** Instance master is for gameplay/session arbitration, not security or access control. Do not use `isMaster` as an authorization boundary. Prefer an object-owner policy or an owner-controlled synced role/turn field.

### NetworkCallable Constraints

| Constraint | Description |
|------------|-------------|
| Access modifier | `public` required |
| Attribute | `[NetworkCallable]` required |
| Return type | A `[NetworkCallable]` method must return `void`. |
| `static` / `virtual` / `override` | Not allowed |
| Overloading | Not allowed (UdonSharp-wide constraint) |
| Rate limit | Default 5 calls/sec/event (configurable up to 100 calls/sec) |
| Parameter count | Maximum 8 |

`[NetworkCallable(N)]` paces remote sends for one event on one behaviour and queues excess sends on the sender. It is not an aggregate receiver or resource bound across callers. Local/self execution bypasses this pacing, and one accepted call may still perform expensive work or fan out to many receivers. Add receiver-local cooldowns, idempotence, fixed capacity, deduplication, and input bounds according to the resource being protected.

## FieldChangeCallback Pattern

Pattern for detecting synced variable changes via property setter:

```csharp
[UdonSynced, FieldChangeCallback(nameof(Health))]
private float _health = 100f;

public float Health
{
    get => _health;
    set
    {
        _health = value;
        // Called for both local and remote changes
        OnHealthChanged();
    }
}

private void OnHealthChanged()
{
    healthBar.value = _health;
}
```

## Key Principles

1. **"The trick to syncing is not to sync"**: Sync only the minimum data and leverage local computation
2. **No dynamic instantiation**: Use object pooling
3. **Late joiner support**: Synced variables are automatically sent to late joiners
4. **Testing**: Early testing with multiple players is critical
5. **VRCPlayerApi validity**: Always check `player != null && player.IsValid()`

## Common Anti-Patterns (Important)

### Anti-Pattern 1: Owner Check in uGUI Callback -> Non-Owner Buttons Become Unresponsive

uGUI OnClick fires **locally on all clients**. Blocking with an owner check makes buttons non-functional for non-owners.

```csharp
// NG: Buttons do nothing for non-owners
public void _OnButtonClicked()
{
    if (!Networking.IsOwner(gameObject)) return; // Nothing happens for non-owners!
    score += 10;
    RequestSerialization();
}

// OK Pattern A: Delegate to owner (for infrequent operations).
// Example policy: any valid player may request one increment.
public void _OnButtonClicked()
{
    SendCustomNetworkEvent(NetworkEventTarget.Owner, nameof(_OwnerAddScore));
}

[NetworkCallable(1)]
public void _OwnerAddScore()
{
    if (!NetworkCalling.InNetworkCall) return;
    VRCPlayerApi caller = NetworkCalling.CallingPlayer;
    if (caller == null || !caller.IsValid()) return;
    if (!Networking.IsOwner(gameObject)) return;

    score += 10;
    RequestSerialization();
}

// OK Pattern B: Acquire ownership then execute (for immediate response)
public void _OnButtonClicked()
{
    Networking.SetOwner(Networking.LocalPlayer, gameObject);
    score += 10;
    RequestSerialization();
}
```

Pattern A deliberately authorizes every valid player to request one rate-limited increment. That is suitable only when the action is open to everyone. For a privileged action, replace that policy with a world-specific check against `caller`; the ownership guard alone is not authorization.

### Anti-Pattern 2: All Clients Running Game Logic in Update() -> Owner Conflict

When a condition evaluates to true simultaneously on all clients, everyone calls SetOwner + modifies the value, causing conflicts.

```csharp
// NG: All clients monitor and modify state -> Owner conflict
void Update()
{
    if (detectSomeCondition) // True on all clients
    {
        Networking.SetOwner(Networking.LocalPlayer, gameObject);
        syncedState = newState; // Everyone modifies simultaneously
        RequestSerialization();
    }
}

// OK: Only owner runs logic, others only update display
void Update()
{
    if (!Networking.IsOwner(gameObject)) return;

    if (detectSomeCondition)
    {
        syncedState = newState;
        RequestSerialization();
    }
}

public override void OnDeserialization()
{
    UpdateDisplay(); // All clients: Reflect received state in display
}
```

## Networking Checklist

- [ ] Ownership verified/acquired before modifying synced variables
- [ ] `RequestSerialization()` called for Manual sync
- [ ] Synced strings in Continuous sync are kept short (respect the ~200-byte shared budget; 2 bytes/char)
- [ ] VRCPlayerApi validity checked
- [ ] Works correctly for late joiners
- [ ] NetworkCallable sender/event pacing and separate receiver resource bounds considered
- [ ] Local-only public event targets start with `_` and omit `[NetworkCallable]`
- [ ] Authorization derives the sender from `NetworkCalling.CallingPlayer`, never a network parameter
- [ ] Caller authorization and receiver ownership are checked separately for privileged synced mutations
- [ ] OnDeserialization side effects guarded with `_hasReceivedState` flag for late-joiner safety
