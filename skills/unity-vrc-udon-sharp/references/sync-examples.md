# Sync Pattern Examples

Practical pattern collection for synced gimmicks.
Refer to the Decision Tree in `../rules/udonsharp-sync-selection.md` for pattern selection criteria.

---

## Pattern 1: No Sync (Local Only)

**Criteria**: Operations that do not affect other players. No `[UdonSynced]` required.

```csharp
// LocalCounter: Local counter (0 synced variables, 0 bytes)
[UdonBehaviourSyncMode(BehaviourSyncMode.Manual)]
public class LocalCounter : UdonSharpBehaviour
{
    [SerializeField] Text CounterText;
    int buttonCount; // Local only, no sync needed

    public override void Interact()
    {
        ++buttonCount;
        CounterText.text = buttonCount.ToString();
    }
}
```

**Use cases**:
- Personal settings (volume, display toggles)
- Local effects (gun firing particles)
- Player-specific UI display

---

## Pattern 2: Events Only (No Synced Variables)

**Criteria**: Visible to other players, but no state sharing needed for late joiners.

### 2a. Play Effects for All Players

```csharp
// HitTarget: Target hit (0 synced variables, 0 bytes)
// Uses SendCustomNetworkEvent(All) to execute a temporary action for everyone
[UdonBehaviourSyncMode(BehaviourSyncMode.Manual)]
public class HitTarget : UdonSharpBehaviour
{
    public void OnParticleCollision(GameObject other)
    {
        if (!Utilities.IsValid(other)) return;
        if (!other.GetComponent<ShootGun>()) return;
        if (Networking.LocalPlayer != Networking.GetOwner(other)) return;

        // Notify all players of the hit
        SendCustomNetworkEvent(NetworkEventTarget.All, "Hit");
    }

    public void Hit()
    {
        if (!gameObject.activeSelf) return;
        gameObject.SetActive(false);
        SendCustomEventDelayedSeconds("Respawn", 5.0f);
    }

    public void Respawn()
    {
        gameObject.SetActive(true);
    }
}
```

**Note**: Late joiners will not know whether the target has been hit. Use only for temporary effects.

### 2b. Owner Delegation Pattern

```csharp
// VoteYesButton: Non-owner sends event to owner
// The button side has no synced variables
[UdonBehaviourSyncMode(BehaviourSyncMode.Manual)]
public class VoteYesButton : UdonSharpBehaviour
{
    [SerializeField] VoteSystemCore voteSystemCore;
    [SerializeField] AudioSource audioSource;

    public override void Interact()
    {
        if (voteSystemCore.voted) return;

        // Delegate vote to owner (only owner modifies synced variables)
        voteSystemCore.SendCustomNetworkEvent(
            NetworkEventTarget.Owner, "VoteToYes");
        voteSystemCore.voted = true;
        audioSource.PlayOneShot(audioSource.clip);
    }
}
```

**Key point**: `voted` is a local flag (prevents double voting). Synced data is consolidated in VoteSystemCore.

### 2c. Owner-Only State Management + Broadcast to All

```csharp
// EventOnlyLock: Owner decides -> broadcasts to all (0 synced variables, 0 bytes)
// Late joiners will not know the unlock state (suitable for temporary gimmicks)
[UdonBehaviourSyncMode(BehaviourSyncMode.Manual)]
public class EventOnlyLock : UdonSharpBehaviour
{
    [SerializeField] GameObject KeyObject;

    public void OnTriggerEnter(Collider other)
    {
        if (Networking.LocalPlayer != Networking.GetOwner(gameObject)) return;
        if (other.gameObject != KeyObject) return;

        SendCustomNetworkEvent(NetworkEventTarget.All, "Unlock");
    }

    public void Unlock()
    {
        gameObject.SetActive(false);
    }
}
```

**EventOnlyLock vs SyncedLock comparison**:

| | EventOnlyLock | SyncedLock |
|---|-----------|-------------|
| Synced variables | 0 (0B) | 1 `bool` (1B) |
| Late joiner | State unknown | Receives correct state |
| Use case | Temporary effects | Persistent gimmicks |

---

## Pattern 3: Synced Variables (Late Joiner Support)

**Criteria**: Late joiners need to receive the current state.

### 3a. Minimal State (1-2 Variables)

```csharp
// SyncedCounter: 1 synced int (4 bytes)
// Non-owner sends event to owner -> owner updates synced variable
[UdonBehaviourSyncMode(BehaviourSyncMode.Manual)]
public class SyncedCounter : UdonSharpBehaviour
{
    [SerializeField] Text CounterText;
    [UdonSynced] int SyncedButtonCount; // Only synced variable

    void Start() => ShowCount();

    public override void Interact()
    {
        // Non-owner delegates to owner
        SendCustomNetworkEvent(NetworkEventTarget.Owner, "AddCount");
    }

    public void AddCount() // Only executed by owner
    {
        ++SyncedButtonCount;
        RequestSerialization();
        ShowCount();
    }

    public override void OnDeserialization() => ShowCount();

    void ShowCount()
    {
        CounterText.text = SyncedButtonCount.ToString();
    }
}
```

```csharp
// SyncedLock: 1 synced bool (1 byte)
// Same lock gimmick as EventOnlyLock, but with late joiner support
[UdonBehaviourSyncMode(BehaviourSyncMode.Manual)]
public class SyncedLock : UdonSharpBehaviour
{
    [SerializeField] GameObject KeyObject;
    [SerializeField] GameObject DoorObject;
    [UdonSynced] bool SyncedIsUnlocked; // Only synced variable

    void Start()
    {
        // Late joiner support: wait briefly then apply synced state
        SendCustomEventDelayedSeconds("RefreshDoor", 5.0f);
    }

    public void RefreshDoor()
    {
        if (SyncedIsUnlocked) Unlock();
    }

    public void OnTriggerEnter(Collider other)
    {
        if (SyncedIsUnlocked) return;
        if (Networking.LocalPlayer != Networking.GetOwner(gameObject)) return;
        if (other.gameObject != KeyObject) return;

        SendCustomNetworkEvent(NetworkEventTarget.All, "Unlock");
        SyncedIsUnlocked = true;
        RequestSerialization();
    }

    public void Unlock()
    {
        DoorObject.SetActive(false);
    }
}
```

### 3b. Game State Machine

```csharp
// ShootingGameCore: Manages entire game with 4 synced variables
[UdonBehaviourSyncMode(BehaviourSyncMode.Manual)]
public class ShootingGameCore : UdonSharpBehaviour
{
    // --- Synced variables (total ~38 bytes) ---
    [UdonSynced] public bool SyncedInGame;              // 1B: Game in progress
    [UdonSynced] public bool SyncedInBattle;            // 1B: In battle
    [UdonSynced] public string SyncedHighScorePlayerName; // ~32B: High scorer name
    [UdonSynced] public int SyncedHighScore;            // 4B: High score

    // --- Local variables (not synced) ---
    int score;           // Each player's local score
    float GameLength;    // Constant (no sync needed)
    float startGameTime; // For local calculation
    bool lateJoined;     // Local flag
    // ...
}
```

**Design points**:
- `score` is local (per player) -> no sync needed
- `GameLength` is a constant -> no sync needed
- `startGameTime` is locally calculated from `Time.time` -> no sync needed
- Only the high score needs to be persistent shared state -> synced

### 3c. Aggregation/Voting Pattern

```csharp
// VoteSystemCore: Vote aggregation (9 bytes)
[UdonBehaviourSyncMode(BehaviourSyncMode.Manual)]
public class VoteSystemCore : UdonSharpBehaviour
{
    // --- Synced variables (total 9 bytes) ---
    [UdonSynced] int SyncedYesCount;    // 4B
    [UdonSynced] int SyncedNoCount;     // 4B
    [UdonSynced] bool SyncedOpenResult; // 1B

    // --- Local variables ---
    public bool voted; // Double-vote prevention (local, no sync needed)

    public void VoteToYes() // Only executed by owner
    {
        ++SyncedYesCount;
        RequestSerialization();
        RefreshCount();
    }

    public override void OnDeserialization()
    {
        RefreshCount(); // All clients: reflect received state in display
    }
}
```

---

## Pattern 4: Managing Multiple Values with FieldChangeCallback

```csharp
// DualCounterSync: Detect individual changes with FieldChangeCallback (8 bytes)
[UdonBehaviourSyncMode(BehaviourSyncMode.Manual)]
public class DualCounterSync : UdonSharpBehaviour
{
    [SerializeField] Text InteractCountText;
    [SerializeField] Text TriggerEnterCountText;

    [UdonSynced][FieldChangeCallback(nameof(InteractCount))]
    int _interactCount;     // 4B

    [UdonSynced][FieldChangeCallback(nameof(TriggerEnterCount))]
    int _triggerEnterCount; // 4B

    public int InteractCount
    {
        get => _interactCount;
        set { _interactCount = value; ShowInteractCount(); }
    }

    public int TriggerEnterCount
    {
        get => _triggerEnterCount;
        set { _triggerEnterCount = value; ShowTriggerEnterCount(); }
    }
}
```

**OnDeserialization vs FieldChangeCallback**:

| Approach | Pros | Cons |
|------|------|------|
| `OnDeserialization()` | Simple, full update | Cannot tell which variable changed |
| `FieldChangeCallback` | Detects individual variable changes | Requires property definitions |

**When to use**: 1-2 variables -> OnDeserialization is sufficient. 3+ variables needing individual responses -> FieldChangeCallback.

---

## Pattern Comparison Table

| Pattern | Synced vars | Bytes | Late Joiner | Use case |
|---------|------------|---------|-------------|---------|
| 1. No sync | 0 | 0 | N/A | Personal effects, local UI |
| 2. Events only | 0 | 0 | State unknown | Temporary actions, effects |
| 3a. Minimal state | 1-2 | 1-4 | Supported | Counters, toggles |
| 3b. Game state | 3-5 | ~38 | Supported | Game progression management |
| 3c. Aggregation | 2-3 | ~9 | Supported | Voting, score aggregation |
| 4. FieldChange | 2+ | 8+ | Supported | Individual detection of multiple values |

---

## Data Budget Reference (Per-Pattern Reference Values)

The following is a summary of synced data amounts for the patterns above. Use for data budget estimation when designing worlds.

| Pattern | Example use | Synced vars | Type | Bytes |
|---------|--------|------------|-----|-------|
| No Sync (Pattern 1) | Local counter | 0 | - | 0 |
| Events Only (Pattern 2a) | Play effects for all | 0 | - | 0 |
| Events Only (Pattern 2c) | Temporary unlock | 0 | - | 0 |
| Minimal state (Pattern 3a) | Counter | 1 | int | 4 |
| Minimal state (Pattern 3a) | Lock (late joiner support) | 1 | bool | 1 |
| FieldChange (Pattern 4) | Multiple value management | 2 | int x2 | 8 |
| Aggregation (Pattern 3c) | Voting system | 3 | int x2 + bool | 9 |
| Game state (Pattern 3b) | Shooting management | 4 | bool x2 + string + int | ~38 |

> **Guideline**: For small to medium worlds, the total across all behaviours typically stays **under 100 bytes**.

## See Also

- [networking.md](networking.md) - Sync mode selection, ownership rules, and bandwidth limits explained
- [persistence.md](persistence.md) - Persisting player data across sessions with PlayerData and PlayerObject
