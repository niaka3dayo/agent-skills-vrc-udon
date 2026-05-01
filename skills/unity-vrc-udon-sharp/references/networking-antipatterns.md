# UdonSharp Networking Anti-Patterns and Advanced Patterns

Common networking mistakes that cause silent failures or data loss, plus advanced techniques for packed sync, rate limiting, dual-copy variables, batching, and congestion retry.

## Networking Anti-Patterns

Common mistakes in UdonSharp networking that cause silent failures, data loss, or undefined behavior. Each pattern includes the problem, a wrong implementation, and the correct fix.

---

### 1. Ownership Race Condition

**Problem**: `Networking.SetOwner` is **locally immediate** on the calling client — `Networking.IsOwner(gameObject)` returns `true` synchronously after the call returns, and `OnOwnershipTransferred` fires synchronously inside the `SetOwner` stack on that client. When two clients call `SetOwner` for the same object at the same moment, **both succeed locally** and may write `[UdonSynced]` variables; VRChat's network resolves the durable owner by network arrival order, and the loser's write is overwritten when the winner's serialization arrives. There is no client-side arbitration. Treat "loser overwrite" as a property of the network, not a bug to engineer around with callback gating.

**Wrong:**

```csharp
// Mutating [UdonSynced] without an IsOwner guard — when SetOwner has not
// been called for the local client (e.g., owner is someone else), the
// write is purely local and is silently reverted on the next deserialization.
public void TryCapture()
{
    capturedBy = Networking.LocalPlayer.playerId; // No IsOwner guard — may be a non-owner write
    RequestSerialization();                        // No-op when called by a non-owner
}
```

**Correct:**

```csharp
[UdonBehaviourSyncMode(BehaviourSyncMode.Manual)]
public class CapturePoint : UdonSharpBehaviour
{
    [UdonSynced] private int capturedBy = -1;

    public void TryCapture()
    {
        // SetOwner is locally immediate. After it returns, IsOwner is true
        // for this client. Two clients racing to capture will both write
        // locally and serialize; the network resolves the durable owner by
        // arrival order, and the loser's write is overwritten when the
        // winner's serialization arrives. This is acceptable for capture-
        // point semantics.
        if (!Networking.IsOwner(gameObject))
        {
            Networking.SetOwner(Networking.LocalPlayer, gameObject);
        }

        capturedBy = Networking.LocalPlayer.playerId;
        RequestSerialization();
    }

    public override void OnDeserialization()
    {
        // Update visuals from synced state (runs on non-owner clients).
        UpdateVisualsFromCapturedBy();
    }

    private void UpdateVisualsFromCapturedBy() { /* ... */ }
}
```

**Explanation**: `Networking.SetOwner` is **locally immediate**. After the call returns, `Networking.IsOwner(gameObject)` is `true` and `OnOwnershipTransferred` has already fired synchronously inside the `SetOwner` stack on the calling client. Writing `[UdonSynced]` fields and calling `RequestSerialization()` immediately afterwards is safe under an `IsOwner` guard. Concurrent calls from multiple clients are *not* arbitrated client-side — VRChat's network resolves the durable owner by arrival order, and the loser's local write is overwritten when the winner's serialization arrives. See the [Transfer Events Diagram](https://creators.vrchat.com/worlds/udon/networking/ownership/#transfer-events-diagram) on creators.vrchat.com.

**When `OnOwnershipRequest` fits.** If the *current owner* needs to reject ownership transfers during a critical action (turn-based logic, mid-transaction state), use `OnOwnershipRequest`. That is a different problem class — owner-side protection — not arbitration among concurrent requesters. See [networking.md §"Ownership Arbitration with OnOwnershipRequest"](networking.md#ownership-arbitration-with-onownershiprequest).

> *Footnote: Pre-2021.2.2 SDKs were asynchronous; this skill targets SDK 3.7.1+ where the locally-immediate behavior is in effect.*

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
            // Locally immediate; we own the object after this returns.
            Networking.SetOwner(Networking.LocalPlayer, gameObject);
        }

        // SetOwner is locally immediate — safe to write under IsOwner.
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

**Explanation**: In UdonSharp, only the current owner's `RequestSerialization()` calls are transmitted. Non-owner writes to `[UdonSynced]` variables are purely local and will be overwritten by the next deserialization from the actual owner — that is the silent failure to guard against. Always guard synced writes with `Networking.IsOwner(gameObject)`; if you are not the owner, call `Networking.SetOwner` first — it is locally immediate, so once it returns `IsOwner` is `true` and you may write and serialize on the same frame.

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

**Explanation**: Throttle `RequestSerialization()` to a maximum frequency appropriate for the data type (10Hz for position is generous; game state changes rarely need more than 1-2Hz). Combine throttling with a change threshold so unchanged values never trigger a sync. Check `Networking.IsClogged` before serializing and use `SendCustomEventDelayedSeconds` to retry rather than spinning in `Update`. See [networking-bandwidth.md - RequestSerialization Throttling Pattern](networking-bandwidth.md#requestserialization-throttling-pattern) for a reusable implementation.

## Advanced Networking Patterns

Techniques for reducing sync variable count, controlling serialization timing, and surviving network congestion.

---

### 1. Packed Sync Data

**Problem**: Each `[UdonSynced]` variable consumes sync budget independently. A behaviour with many small values wastes budget on per-variable overhead.

**Solution**: Pack multiple independent values into a single variable using the natural layout of numeric types.

- `Vector3` stores 3 independent floats — use each component for a different purpose (e.g., `x` = question index, `y` = game type, `z` = category).
- `int` stores 32 bits — encode multiple small integers via bit shifting.
- A single `int` used as a bit field replaces a group of `bool` variables.

**Template:** [assets/templates/PackedStateSync.cs](../assets/templates/PackedStateSync.cs)

Stores three independent state values (`_questionIndex`, `_gameType`, `_category`) in a single `[UdonSynced] Vector3 _packedState`. `OnPreSerialization` calls `PackState()` which writes each int as a Vector3 component. `OnDeserialization` calls `UnpackState()` using `Mathf.RoundToInt` to recover the values. Integer precision is exact up to 16,777,216 (24-bit float mantissa). Do not use for values requiring interpolation.

**Key constraints**:
- `float` has 24-bit mantissa precision — integers up to 16,777,216 round-trip exactly through `Vector3`.
- Use `Mathf.RoundToInt` on unpack to absorb any floating-point noise.
- Do not use this technique for values that need interpolation; use separate synced floats for those.

---

### 2. Rate-Limited Serialization

**Problem**: Rapid user interactions (dragging a slider, scrubbing a seek bar) can fire dozens of change events per second. Calling `RequestSerialization()` on every event floods the ~11 KB/s Udon network budget.

**Solution**: Use a `_syncLocked` flag and `SendCustomEventDelayedSeconds` to enforce a minimum cooldown between serializations. Only the value present at the end of the cooldown window is sent, so fast-moving values coalesce naturally.

**Template:** [assets/templates/RateLimitedSync.cs](../assets/templates/RateLimitedSync.cs)

Uses a `_syncLocked` bool and a `_changeCounter` int to enforce a `SyncCooldown` (0.15 s) between serializations. On the first change in a window, the lock is set and `_OnSyncUnlock` is scheduled. Subsequent changes update `_localValue` without scheduling additional events. On unlock, `ExecuteSync` copies `_localValue` to `_syncedValue` and calls `RequestSerialization`. If the counter moved during the lock, one extra window fires to guarantee the final value is transmitted.

**How it works**:
1. The first change within a cooldown window locks further serializations and schedules `_OnSyncUnlock`.
2. Subsequent changes during the lock update `_localValue` but do not schedule additional events.
3. When the lock expires, `_OnSyncUnlock` serializes the current (latest) value.
4. The `_changeCounter` comparison ensures one extra window fires if the value was still moving at unlock time, guaranteeing the last write reaches the network.

---

### 3. Dual-Copy Sync Variables

**Problem**: Writing directly to `[UdonSynced]` variables from non-owner code is silently discarded at the next `OnDeserialization`. Code that freely mixes reads and writes to synced variables is error-prone and hard to reason about.

**Solution**: Maintain a *local working copy* alongside each synced variable. The local copy is the single source of truth for all in-world logic. `OnPreSerialization` copies local → synced; `OnDeserialization` copies synced → local. A dirty flag prevents unnecessary serializations.

**Template:** [assets/templates/DualCopySync.cs](../assets/templates/DualCopySync.cs)

Maintains `volume` (public local copy) and `_syncedVolume` ([UdonSynced] private copy) as strictly separate fields. A `_dirty` flag guards `OnPreSerialization`: it only copies local → synced when something changed. `OnDeserialization` copies synced → local and calls `ApplyVolume`. All game logic reads the local copy; the synced copy is never written outside the two serialization hooks.

**Benefits**:
- All game logic reads `volume` — no conditional owner checks scattered throughout the codebase.
- `_syncedVolume` is never written outside the two serialization hooks, making networking logic easy to audit.
- The dirty flag ensures `RequestSerialization()` produces a packet only when the value genuinely changed, avoiding spurious traffic.

---

### 4. Delayed Serialization Batching

**Problem**: Multiple rapid events (several players joining in quick succession, multi-field form submission) each call `RequestSerialization()` independently, producing redundant packets that carry nearly identical payloads.

**Solution**: Instead of serializing immediately, set a *pending* flag and schedule a single delayed serialization. All changes that arrive before the delay fires are batched into one packet.

**Template:** [assets/templates/BatchedSync.cs](../assets/templates/BatchedSync.cs)

Uses a `_syncPending` bool so that `ScheduleBatchedSync` is idempotent — only the first call within a `BatchDelay` (0.2 s) window schedules `_FlushBatch`. All three fields (`_playerCount`, `_readyFlags`, `_roundNumber`) are serialized in one packet regardless of how many mutation methods were called. `_FlushBatch` clears the pending flag then calls `RequestSerialization`. Tune `BatchDelay` to 100–300 ms for non-positional state.

**Key points**:
- `ScheduleBatchedSync` is idempotent: calling it multiple times before the delay fires has no effect beyond the first call.
- All three fields (`_playerCount`, `_readyFlags`, `_roundNumber`) are serialized together in one packet, regardless of how many mutation methods were called during the batch window.
- Tune `BatchDelay` to balance latency against packet reduction. 100–300 ms is typically invisible to players for non-positional state.

---

### 5. IsClogged Retry Pattern

**Problem**: When the Udon network is congested, `RequestSerialization()` calls may be silently dropped. There is no built-in retry or acknowledgement.

**Solution**: Check `Networking.IsClogged` before serializing. If the network is congested, skip the call and schedule a retry via `SendCustomEventDelayedSeconds`. Cap total retry attempts to prevent infinite retry storms during extended outages.

**Template:** [assets/templates/CloggedRetrySync.cs](../assets/templates/CloggedRetrySync.cs)

`TrySerialize` checks `Networking.IsClogged` before calling `RequestSerialization`. If congested, `ScheduleRetry` increments `_retryCount`, sets `_retryPending`, and schedules `_RetrySerialize` with linear back-off (`RetryDelay * _retryCount`). After `MaxRetries` (5) attempts, the cycle gives up and resets both counters. `_retryPending` prevents stacked retry chains if `TrySerialize` is called again while a retry is queued.

**Design notes**:
- `_retryPending` prevents multiple overlapping `SendCustomEventDelayedSeconds` chains from accumulating if `TrySerialize` is called again while a retry is already queued.
- Linear back-off (`RetryDelay * _retryCount`) reduces pressure on an already-congested network rather than hammering it at a fixed interval.
- `MaxRetries` caps total attempts. In practice, VRChat network congestion resolves within a few seconds; five retries at 1.5 s increments covers ~22 s of congestion before giving up.
- After an abandonment, the next call to `UpdateScore` or `SetGameState` resets the counter and starts fresh.

---


## See Also

- [networking.md](networking.md) - Sync modes, ownership, network events, data limits
- [networking-bandwidth.md](networking-bandwidth.md) - Bandwidth throttling, bit packing, data optimization
- [patterns-networking.md](patterns-networking.md) - Object pooling, game state management
- [troubleshooting.md](troubleshooting.md) - Debugging networking issues and ownership race conditions
