# UdonSharp Networking Rules (Always Loaded)

Core networking rules and constraints. See `../references/networking.md` for detailed patterns.

**SDK Coverage**: 3.7.1 - 3.10.3 (as of March 2026)

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

Parameterized network events. Supports sending up to 8 parameters.

```csharp
[NetworkCallable]
public void TakeDamage(int damage, int attackerId)
{
    health -= damage;
    Debug.Log($"Player {attackerId} dealt {damage} damage");
}

// Invocation
SendCustomNetworkEvent(NetworkEventTarget.All, nameof(TakeDamage), damage, attackerId);
```

### NetworkCallable Constraints

| Constraint | Description |
|------------|-------------|
| Access modifier | `public` required |
| Attribute | `[NetworkCallable]` required |
| `static` / `virtual` / `override` | Not allowed |
| Overloading | Not allowed (UdonSharp-wide constraint) |
| Rate limit | Default 5 calls/sec/event (configurable up to 100 calls/sec) |
| Parameter count | Maximum 8 |

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
public void OnButtonClicked()
{
    if (!Networking.IsOwner(gameObject)) return; // Nothing happens for non-owners!
    score += 10;
    RequestSerialization();
}

// OK Pattern A: Delegate to owner (for infrequent operations)
public void OnButtonClicked()
{
    SendCustomNetworkEvent(NetworkEventTarget.Owner, nameof(OwnerAddScore));
}
public void OwnerAddScore()
{
    score += 10;
    RequestSerialization();
}

// OK Pattern B: Acquire ownership then execute (for immediate response)
public void OnButtonClicked()
{
    Networking.SetOwner(Networking.LocalPlayer, gameObject);
    score += 10;
    RequestSerialization();
}
```

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
- [ ] NetworkCallable rate limits considered
- [ ] OnDeserialization side effects guarded with `_isInitialized` flag for late-joiner safety
