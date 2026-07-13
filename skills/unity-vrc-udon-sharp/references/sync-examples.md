# Sync Pattern Examples

Practical pattern collection for synced gimmicks.
Refer to the Decision Tree in `../rules/udonsharp-sync-selection.md` for pattern selection criteria.

---

## Pattern 1: No Sync (Local Only)

**Criteria**: Operations that do not affect other players. No `[UdonSynced]` required.

```csharp
using UdonSharp;
using UnityEngine;
using UnityEngine.UI;

// LocalCounter: Local counter (0 synced variables, 0 bytes)
[UdonBehaviourSyncMode(BehaviourSyncMode.NoVariableSync)]
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
using UdonSharp;
using UnityEngine;
using VRC.SDK3.UdonNetworkCalling;
using VRC.SDKBase;
using VRC.Udon.Common.Interfaces;

// HitTarget: Target hit (0 synced variables, 0 bytes)
// Uses SendCustomNetworkEvent(All) to execute a temporary action for everyone
[UdonBehaviourSyncMode(BehaviourSyncMode.NoVariableSync)]
public class HitTarget : UdonSharpBehaviour
{
    [SerializeField] private GameObject trustedProjectile;

    public void OnParticleCollision(GameObject other)
    {
        if (!Utilities.IsValid(other)) return;
        if (other != trustedProjectile) return;
        if (Networking.LocalPlayer != Networking.GetOwner(other)) return;

        SendCustomNetworkEvent(NetworkEventTarget.All, nameof(_Hit));
    }

    [NetworkCallable(2)]
    public void _Hit()
    {
        if (!NetworkCalling.InNetworkCall) return;

        VRCPlayerApi caller = NetworkCalling.CallingPlayer;
        if (caller == null || !caller.IsValid()) return;

        // Open cosmetic policy: any valid caller may hide the target once.
        if (!gameObject.activeSelf) return;
        gameObject.SetActive(false);
        SendCustomEventDelayedSeconds(nameof(_Respawn), 5.0f);
    }

    public void _Respawn()
    {
        gameObject.SetActive(true);
    }
}
```

**Policy**: Any valid caller may trigger this temporary cosmetic effect. The
active-state guard and fixed five-second duration bound receiver work; the
two-call-per-second attribute only paces each sender. Late joiners do not
receive the event.

### 2b. Owner Delegation Pattern

```csharp
using UdonSharp;
using UnityEngine;
using VRC.Udon.Common.Interfaces;

// VoteYesButton: Non-owner sends event to owner
// The button side has no synced variables
[UdonBehaviourSyncMode(BehaviourSyncMode.NoVariableSync)]
public class VoteYesButton : UdonSharpBehaviour
{
    [SerializeField] UdonSharpBehaviour voteSystemCore;
    [SerializeField] AudioSource audioSource;

    public override void Interact()
    {
        voteSystemCore.SendCustomNetworkEvent(
            NetworkEventTarget.Owner, "_VoteToYes");
        audioSource.PlayOneShot(audioSource.clip);
    }
}
```

The button only routes the request. `VoteSystemCore` validates and deduplicates
the active caller on the authoritative owner; local button state cannot enforce
the vote policy.

### 2c. Owner-Only State Management + Broadcast to All

```csharp
using UdonSharp;
using UnityEngine;
using VRC.SDK3.UdonNetworkCalling;
using VRC.SDKBase;
using VRC.Udon.Common.Interfaces;

// EventOnlyLock: Owner decides -> broadcasts to all (0 synced variables, 0 bytes)
// Late joiners will not know the unlock state (suitable for temporary gimmicks)
[UdonBehaviourSyncMode(BehaviourSyncMode.NoVariableSync)]
public class EventOnlyLock : UdonSharpBehaviour
{
    [SerializeField] GameObject KeyObject;

    public void OnTriggerEnter(Collider other)
    {
        if (Networking.LocalPlayer != Networking.GetOwner(gameObject)) return;
        if (other.gameObject != KeyObject) return;

        SendCustomNetworkEvent(NetworkEventTarget.All, nameof(_Unlock));
    }

    [NetworkCallable(1)]
    public void _Unlock()
    {
        if (!NetworkCalling.InNetworkCall) return;

        VRCPlayerApi caller = NetworkCalling.CallingPlayer;
        if (caller == null || !caller.IsValid()) return;

        VRCPlayerApi owner = Networking.GetOwner(gameObject);
        if (owner == null || !owner.IsValid()) return;
        if (caller.playerId != owner.playerId) return;

        // The owner-only caller policy protects this one-way local effect.
        if (!gameObject.activeSelf) return;
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
using UdonSharp;
using UnityEngine;
using UnityEngine.UI;
using VRC.SDK3.UdonNetworkCalling;
using VRC.SDKBase;
using VRC.Udon.Common.Interfaces;

// SyncedCounter: 1 synced int (4 bytes)
// Non-owner sends event to owner -> owner updates synced variable
[UdonBehaviourSyncMode(BehaviourSyncMode.Manual)]
public class SyncedCounter : UdonSharpBehaviour
{
    private const int MaxCount = 1000000;

    [SerializeField] Text CounterText;
    [UdonSynced] int SyncedButtonCount; // Only synced variable

    void Start() => ShowCount();

    public override void Interact()
    {
        SendCustomNetworkEvent(NetworkEventTarget.Owner, nameof(_AddCount));
    }

    [NetworkCallable(2)]
    public void _AddCount()
    {
        if (!NetworkCalling.InNetworkCall) return;

        VRCPlayerApi caller = NetworkCalling.CallingPlayer;
        if (caller == null || !caller.IsValid()) return;

        // Open counter policy: any valid caller may request an increment.
        if (!Networking.IsOwner(gameObject)) return;
        if (SyncedButtonCount >= MaxCount) return;

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
using UdonSharp;
using UnityEngine;

// SyncedLock: 1 synced bool (1 byte)
// Same lock gimmick as EventOnlyLock, but with late joiner support
[UdonBehaviourSyncMode(BehaviourSyncMode.Manual)]
public class SyncedLock : UdonSharpBehaviour
{
    [SerializeField] GameObject KeyObject;
    [SerializeField] GameObject DoorObject;
    [UdonSynced] bool SyncedIsUnlocked; // Only synced variable

    public override void OnDeserialization()
    {
        _RefreshDoor();
    }

    public void _RefreshDoor()
    {
        if (SyncedIsUnlocked) _UnlockDoor();
    }

    public void OnTriggerEnter(Collider other)
    {
        if (SyncedIsUnlocked) return;
        if (Networking.LocalPlayer != Networking.GetOwner(gameObject)) return;
        if (other.gameObject != KeyObject) return;

        SyncedIsUnlocked = true;
        RequestSerialization();
        _UnlockDoor();
    }

    public void _UnlockDoor()
    {
        DoorObject.SetActive(false);
    }
}
```

### 3b. Game State Machine

```csharp
using UdonSharp;

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
using UdonSharp;
using UnityEngine;
using UnityEngine.UI;
using VRC.SDK3.UdonNetworkCalling;
using VRC.SDKBase;

// VoteSystemCore: bounded vote aggregation (~333 bytes with 80 voter IDs)
[UdonBehaviourSyncMode(BehaviourSyncMode.Manual)]
public class VoteSystemCore : UdonSharpBehaviour
{
    // --- Synced vote state and owner-controlled deduplication data ---
    [UdonSynced] int SyncedYesCount;    // 4B
    [UdonSynced] int SyncedNoCount;     // 4B
    [UdonSynced] bool SyncedOpenResult; // 1B
    [UdonSynced] int[] SyncedVoterPlayerIds = new int[80];
    [UdonSynced] int SyncedVoterCount;

    [SerializeField] private Text yesCountText;
    [SerializeField] private Text noCountText;

    [NetworkCallable(1)]
    public void _VoteToYes()
    {
        if (!NetworkCalling.InNetworkCall) return;

        VRCPlayerApi caller = NetworkCalling.CallingPlayer;
        if (caller == null || !caller.IsValid()) return;

        // Ownership routing chooses the receiver; it does not authorize the caller.
        if (!Networking.IsOwner(gameObject)) return;
        if (SyncedVoterPlayerIds == null || SyncedVoterPlayerIds.Length != 80) return;
        if (SyncedVoterCount < 0 || SyncedVoterCount > SyncedVoterPlayerIds.Length) return;

        for (int i = 0; i < SyncedVoterCount; i++)
        {
            if (SyncedVoterPlayerIds[i] == caller.playerId) return;
        }
        if (SyncedVoterCount >= SyncedVoterPlayerIds.Length) return;

        SyncedVoterPlayerIds[SyncedVoterCount] = caller.playerId;
        SyncedVoterCount++;
        ++SyncedYesCount;
        RequestSerialization();
        RefreshCount();
    }

    public override void OnDeserialization()
    {
        RefreshCount(); // All clients: reflect received state in display
    }

    private void RefreshCount()
    {
        if (yesCountText != null) yesCountText.text = SyncedYesCount.ToString();
        if (noCountText != null) noCountText.text = SyncedNoCount.ToString();
    }
}
```

The owner stores accepted caller IDs with the synced vote state, so direct
network calls cannot bypass deduplication and an owner handoff retains the
record. The fixed array caps memory and accepted votes, and caller-ID
deduplication permits at most one accepted vote per player. Configure a smaller
array when the world capacity is lower.

`[NetworkCallable(N)]` paces remote sends for one event on one behaviour and queues excess sends on the sender. It is not an aggregate receiver or resource bound across callers. Here, the fixed array, input checks, and authoritative deduplication provide the receiver resource bound; the attribute only paces each sender's requests.

---

## Pattern 4: Managing Multiple Values with FieldChangeCallback

```csharp
using UdonSharp;
using UnityEngine;
using UnityEngine.UI;

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

    private void ShowInteractCount()
    {
        if (InteractCountText != null) InteractCountText.text = _interactCount.ToString();
    }

    private void ShowTriggerEnterCount()
    {
        if (TriggerEnterCountText != null) TriggerEnterCountText.text = _triggerEnterCount.ToString();
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
| 3c. Aggregation | 5 | ~333 | Supported | Voting with owner-side caller deduplication |
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
| Aggregation (Pattern 3c) | Voting system | 5 | int x2 + bool + int[80] + int | ~333 |
| Game state (Pattern 3b) | Shooting management | 4 | bool x2 + string + int | ~38 |

> **Guideline**: For small to medium worlds, the total across all behaviours typically stays **under 100 bytes**.

## See Also

- [networking.md](networking.md) - Sync mode selection, ownership rules, and bandwidth limits explained
- [networking-bandwidth.md](networking-bandwidth.md) - Bandwidth throttling, bit packing, and data size optimization
- [persistence.md](persistence.md) - Persisting player data across sessions with PlayerData and PlayerObject
