# UdonSharp Performance Patterns

Cross-class call overhead, partial class pattern, update handler, PostLateUpdate, spatial query optimization, animator hash caching, and platform detection.

## Performance Patterns

### Cross-Class Call Overhead

In Udon, calling methods on other UdonBehaviours has significant overhead (~1.5x slower than same-class calls). This creates a dilemma:

- **Good design** suggests splitting responsibilities across classes
- **Performance** suggests keeping everything in one class

Two patterns help resolve this: **Partial Classes** and **Update Handler Pattern**.

### Partial Class Pattern

Split a large class across multiple files while maintaining single-class performance:

```csharp
// MyGimmick.cs - Main entry points and core logic
using UdonSharp;
using UnityEngine;
using VRC.SDKBase;

public partial class MyGimmick : UdonSharpBehaviour
{
    void Start()
    {
        InitializeUI();
        InitializeSync();
    }

    public override void Interact()
    {
        HandleInteraction();
    }
}
```

```csharp
// MyGimmick.UI.cs - UI-related code
using TMPro;
using UnityEngine;
using UnityEngine.UI;

public partial class MyGimmick
{
    [Header("UI References")]
    [SerializeField] private TextMeshProUGUI statusText;
    [SerializeField] private Slider progressSlider;

    private void InitializeUI()
    {
        UpdateStatusDisplay();
    }

    private void UpdateStatusDisplay()
    {
        if (statusText != null)
        {
            statusText.text = $"State: {_currentState}";
        }
    }

    private void UpdateProgress(float progress)
    {
        if (progressSlider != null)
        {
            progressSlider.value = progress;
        }
    }
}
```

```csharp
// MyGimmick.Sync.cs - Network synchronization
using VRC.SDKBase;

public partial class MyGimmick
{
    [UdonSynced, FieldChangeCallback(nameof(CurrentState))]
    private int _currentState = 0;

    public int CurrentState
    {
        get => _currentState;
        set
        {
            _currentState = value;
            OnStateChanged();
        }
    }

    private void InitializeSync()
    {
        // Sync initialization
    }

    private void HandleInteraction()
    {
        if (!Networking.IsOwner(gameObject))
        {
            Networking.SetOwner(Networking.LocalPlayer, gameObject);
        }
        CurrentState = (_currentState + 1) % 3;
        RequestSerialization();
    }

    private void OnStateChanged()
    {
        UpdateStatusDisplay();
    }
}
```

**Benefits:**
- Same performance as a single class (verified by benchmarks)
- Better code organization and readability
- Easier to maintain large gimmicks
- Each file can focus on one responsibility

**File naming convention:**
| File | Responsibility |
|------|----------------|
| `Gimmick.cs` | Main entry points, core logic |
| `Gimmick.UI.cs` | UI handling, display updates |
| `Gimmick.Sync.cs` | Network synchronization |
| `Gimmick.Audio.cs` | Audio playback |
| `Gimmick.Animation.cs` | Animation control |

**Caveats:**
- All partials share the same member namespace (no duplicates allowed)
- `private` members are accessible across all partials
- Requires strict naming conventions for clarity
- This is an anti-pattern in standard C# (normally for generated code)

**Performance comparison:**

| Call Type | Time (1000 calls) |
|-----------|-------------------|
| Same-class method | 0.68 ms |
| Partial-class method (different file) | 0.68 ms |
| Other-class method | 1.04 ms |

### Update Handler Pattern

Separate `Update()` into a dedicated component that can be enabled/disabled:

```csharp
// GimmickManager.cs - Controls the gimmick, no Update()
using UdonSharp;
using UnityEngine;
using VRC.SDKBase;

public class GimmickManager : UdonSharpBehaviour
{
    [Header("References")]
    [SerializeField] private GimmickUpdateHandler updateHandler;

    [Header("Settings")]
    [SerializeField] private float processingDuration = 5.0f;

    private bool isProcessing = false;

    void Start()
    {
        // Ensure Update is disabled initially
        if (updateHandler != null)
        {
            updateHandler.enabled = false;
        }
    }

    public override void Interact()
    {
        if (isProcessing) return;
        StartProcessing();
    }

    public void StartProcessing()
    {
        isProcessing = true;

        if (updateHandler != null)
        {
            updateHandler.enabled = true;
        }

        // Auto-stop after duration
        SendCustomEventDelayedSeconds(nameof(StopProcessing), processingDuration);
    }

    public void StopProcessing()
    {
        isProcessing = false;

        if (updateHandler != null)
        {
            updateHandler.enabled = false;
        }
    }

    public bool IsProcessing => isProcessing;
}
```

```csharp
// GimmickUpdateHandler.cs - Contains Update() logic, enabled only when needed
using UdonSharp;
using UnityEngine;

public class GimmickUpdateHandler : UdonSharpBehaviour
{
    [SerializeField] private GimmickManager manager;
    [SerializeField] private Transform targetTransform;
    [SerializeField] private float rotationSpeed = 90f;

    void Update()
    {
        // This only runs when enabled
        if (targetTransform != null)
        {
            targetTransform.Rotate(Vector3.up, rotationSpeed * Time.deltaTime);
        }
    }
}
```

**Why this matters:**

With 100 inactive gimmicks in a world:

| Approach | CPU Time |
|----------|----------|
| Always-running Update with early return | 0.0745 ms |
| Disabled UpdateHandler | 0.0122 ms |

**6x performance improvement** for inactive gimmicks.

**When to use:**
- Gimmicks that are only active occasionally
- Optional features that players may not use
- Processing-intensive operations

**When NOT to use:**
- Gimmicks that are always active
- Simple Update() with minimal overhead
- When the extra component adds more complexity than benefit

### Combining Both Patterns

For complex gimmicks, combine Partial Class and Update Handler:

```csharp
// ComplexGimmick.cs
public partial class ComplexGimmick : UdonSharpBehaviour
{
    [SerializeField] private ComplexGimmickUpdateHandler updateHandler;
    // Main logic...
}

// ComplexGimmick.UI.cs
public partial class ComplexGimmick
{
    // UI code...
}

// ComplexGimmick.Sync.cs
public partial class ComplexGimmick
{
    // Sync code...
}

// ComplexGimmickUpdateHandler.cs (separate class, not partial)
public class ComplexGimmickUpdateHandler : UdonSharpBehaviour
{
    [SerializeField] private ComplexGimmick manager;

    void Update()
    {
        // Heavy per-frame processing
    }
}
```

This gives you:
- Organized code across multiple files (Partial Class)
- Controlled Update() execution (Update Handler)
- Best possible performance for both active and inactive states

## Performance Optimization Patterns

### PostLateUpdate for Camera-Dependent Effects

`Update()` runs before the camera moves each frame. For effects that must track the VRChat camera — nameplate overlays, HUD elements, billboard sprites — use `PostLateUpdate()` instead. It runs after the camera's final position is resolved.

Add change-detection to skip the GPU upload when the camera has not moved:

```csharp
public class CameraTracker : UdonSharpBehaviour
{
    [SerializeField] private Transform trackedTransform;

    private Vector3 _lastCameraPosition;
    private Quaternion _lastCameraRotation;

    public override void PostLateUpdate()
    {
        VRCPlayerApi localPlayer = Networking.LocalPlayer;
        if (localPlayer == null) return;

        VRCPlayerApi.TrackingData head = localPlayer.GetTrackingData(VRCPlayerApi.TrackingDataType.Head);
        Vector3 camPos = head.position;
        Quaternion camRot = head.rotation;

        // Skip update when camera has not moved (change detection)
        if (camPos == _lastCameraPosition && camRot == _lastCameraRotation) return;

        _lastCameraPosition = camPos;
        _lastCameraRotation = camRot;

        // Apply transform relative to camera
        if (trackedTransform != null)
        {
            trackedTransform.position = camPos + camRot * Vector3.forward * 2f;
            trackedTransform.rotation = camRot;
        }
    }
}
```

### Bounds Pre-Check for Spatial Queries

`Collider.ClosestPoint()` is expensive. When you have many potential colliders, compute a compound `Bounds` at startup that wraps all of them. Discard distant queries with a fast `Bounds.Contains()` before paying the full cost.

```csharp
public class SpatialQueryZone : UdonSharpBehaviour
{
    [SerializeField] private Collider[] zoneColliders;

    private Bounds _compoundBounds;

    void Start()
    {
        if (zoneColliders == null || zoneColliders.Length == 0) return;

        // Build compound bounds from all colliders
        _compoundBounds = zoneColliders[0].bounds;
        for (int i = 1; i < zoneColliders.Length; i++)
        {
            if (zoneColliders[i] != null)
            {
                _compoundBounds.Encapsulate(zoneColliders[i].bounds);
            }
        }
    }

    /// <summary>
    /// Returns the closest point on any zone collider, or Vector3.zero if the
    /// query point is clearly outside the compound bounds.
    /// </summary>
    public Vector3 GetClosestPoint(Vector3 queryPoint)
    {
        // Fast rejection: skip expensive ClosestPoint calls entirely
        if (!_compoundBounds.Contains(queryPoint)) return Vector3.zero;

        Vector3 closest = Vector3.zero;
        float minDist = float.MaxValue;

        for (int i = 0; i < zoneColliders.Length; i++)
        {
            if (zoneColliders[i] == null) continue;

            Vector3 candidate = zoneColliders[i].ClosestPoint(queryPoint);
            float dist = Vector3.Distance(queryPoint, candidate);
            if (dist < minDist)
            {
                minDist = dist;
                closest = candidate;
            }
        }

        return closest;
    }
}
```

### Animator Parameter Hash Caching

`Animator.SetFloat(string, float)` resolves the string to an internal hash every call. Cache the hash in `Start()` and use the integer overload in `Update()`.

```csharp
public class AnimatedPlatform : UdonSharpBehaviour
{
    [SerializeField] private Animator platformAnimator;

    // Cached hashes — computed once, reused every frame
    private int _speedHash;
    private int _isMovingHash;
    private int _directionHash;

    void Start()
    {
        _speedHash     = Animator.StringToHash("Speed");
        _isMovingHash  = Animator.StringToHash("IsMoving");
        _directionHash = Animator.StringToHash("Direction");
    }

    void Update()
    {
        float currentSpeed = GetPlatformSpeed();
        bool moving = currentSpeed > 0.01f;

        // Integer overloads: no string lookup at runtime
        platformAnimator.SetFloat(_speedHash, currentSpeed);
        platformAnimator.SetBool(_isMovingHash, moving);
        platformAnimator.SetFloat(_directionHash, GetPlatformDirection());
    }

    private float GetPlatformSpeed()
    {
        // Platform-specific logic
        return 0f;
    }

    private float GetPlatformDirection()
    {
        // Platform-specific logic
        return 0f;
    }
}
```

**Rule of thumb:** Cache any string passed to `Animator.Set*` or `Animator.Get*` that is called more than once per second.

### Platform Detection Pattern

Use VRChat's runtime API to branch behaviour by platform. Check once in `Start()` and store results in fields rather than querying every frame.

```csharp
public class PlatformAdapter : UdonSharpBehaviour
{
    private bool _isVR = false;
    private bool _isMobile = false;

    void Start()
    {
        VRCPlayerApi localPlayer = Networking.LocalPlayer;
        if (localPlayer == null) return;

        _isVR = localPlayer.IsUserInVR();

        // Mobile players use touch input as their last input method
        _isMobile = InputManager.GetLastUsedInputMethod() == VRCInputMethod.Touch;

        ApplyPlatformSettings();
    }

    private void ApplyPlatformSettings()
    {
        if (_isVR)
        {
            // Adjust interaction distances for VR reach
            Debug.Log("VR mode: adjusting grab distances");
        }
        else if (_isMobile)
        {
            // Enlarge touch targets for mobile players
            Debug.Log("Mobile mode: scaling up UI hit areas");
        }
        else
        {
            // Desktop mouse+keyboard defaults
            Debug.Log("Desktop mode");
        }
    }

    public bool IsVR => _isVR;
    public bool IsMobile => _isMobile;
    public bool IsDesktop => !_isVR && !_isMobile;
}
```

> **Note:** `InputManager.GetLastUsedInputMethod()` reflects the last device the player used, not a fixed platform flag. It can change during a session if the player switches devices. For a stable platform classification, check only `IsUserInVR()` at `Start()` and treat everything else as flat-screen.

---

### Frame Budget Stopwatch

#### Problem

Heavy synchronous operations — parsing large downloaded strings, decoding Base64 data, building UI elements from network payloads — can stall the main thread for tens of milliseconds. UdonSharp has no `async`/`await` and no coroutines. If the entire operation runs in a single frame, VR users will see a visible hitch.

#### Solution

Use `System.Diagnostics.Stopwatch` to measure how much time has elapsed within the current frame. After each processing step, call a `BranchByBudget` helper:

- If the elapsed time is **under the budget** (default 20 ms), call the next step immediately via `SendCustomEvent` — no frame boundary is crossed.
- If the elapsed time **meets or exceeds the budget**, defer to the next frame via `SendCustomEventDelayedFrames(nextMethodName, 1)` and restart the stopwatch.

Each deferred frame resets the stopwatch so the next step gets a full fresh budget.

#### Why 20 ms?

VR targets 90 FPS (≈11.1 ms per frame). A 20 ms budget is deliberately looser than one frame: it allows small overruns without dropping two frames in a row, while still yielding control before a second heavy step can compound the problem. Adjust `_processBudgetMs` in the Inspector to match your target framerate and workload.

```csharp
using UdonSharp;
using UnityEngine;
using System.Diagnostics;

[UdonBehaviourSyncMode(BehaviourSyncMode.NoVariableSync)]
public class FrameBudgetProcessor : UdonSharpBehaviour
{
    [Header("Processing Data")]
    [SerializeField] private string[] _inputLines;

    [Header("Budget Settings")]
    [SerializeField] private float _processBudgetMs = 20f;

    // Internal state
    private Stopwatch _stopwatch;
    private int _currentIndex;
    private string[] _results;

    void Start()
    {
        _stopwatch = new Stopwatch();
    }

    // ── Public entry point ────────────────────────────────────────────────

    public void BeginProcessing()
    {
        if (_inputLines == null || _inputLines.Length == 0) return;

        _currentIndex = 0;
        _results = new string[_inputLines.Length];

        // Start the stopwatch fresh for this batch
        _stopwatch.Reset();
        _stopwatch.Start();

        SendCustomEvent(nameof(Step1_Parse));
    }

    // ── Processing pipeline ───────────────────────────────────────────────

    public void Step1_Parse()
    {
        while (_currentIndex < _inputLines.Length)
        {
            // Simulate per-line work (replace with real parsing logic)
            _results[_currentIndex] = _inputLines[_currentIndex].Trim();
            _currentIndex++;

            // Yield if the frame budget is spent
            if (BranchByBudget(nameof(Step1_Parse))) return;
        }

        // All lines parsed — move to next stage via SendCustomEvent (not BranchByBudget).
        // BranchByBudget is for within-stage iteration only; using it for stage transitions
        // causes a deadlock because the freshly-reset stopwatch always reads 0 ms elapsed,
        // so BranchByBudget never defers and Step2 runs in the same frame budget window.
        _currentIndex = 0;
        SendCustomEvent(nameof(Step2_Transform));
    }

    public void Step2_Transform()
    {
        // Reset the stopwatch at the start of each stage so the budget is fresh
        _stopwatch.Reset();
        _stopwatch.Start();

        while (_currentIndex < _results.Length)
        {
            // Simulate transform work
            _results[_currentIndex] = _results[_currentIndex].ToUpper();
            _currentIndex++;

            if (BranchByBudget(nameof(Step2_Transform))) return;
        }

        // Move to next stage — use SendCustomEvent, not BranchByBudget (same reason as above)
        _currentIndex = 0;
        SendCustomEvent(nameof(Step3_BuildUI));
    }

    public void Step3_BuildUI()
    {
        // Reset the stopwatch at the start of each stage so the budget is fresh
        _stopwatch.Reset();
        _stopwatch.Start();

        while (_currentIndex < _results.Length)
        {
            // Simulate UI construction work per entry
            _currentIndex++;

            if (BranchByBudget(nameof(Step3_BuildUI))) return;
        }

        SendCustomEvent(nameof(OnProcessingComplete));
    }

    public void OnProcessingComplete()
    {
        _stopwatch.Stop();
        UnityEngine.Debug.Log("[FrameBudgetProcessor] Processing complete.");
    }

    // ── Budget helper ─────────────────────────────────────────────────────

    /// <summary>
    /// Returns true and defers <paramref name="nextMethodName"/> to the next frame
    /// if the current frame budget is exhausted.  Returns false if the budget has
    /// not yet been spent (caller should continue its loop).
    /// </summary>
    private bool BranchByBudget(string nextMethodName)
    {
        if (_stopwatch.Elapsed.TotalMilliseconds >= _processBudgetMs)
        {
            // Budget spent — hand back control and resume next frame
            SendCustomEventDelayedFrames(nextMethodName, 1);
            _stopwatch.Reset();
            _stopwatch.Start();
            return true;
        }
        return false;
    }
}
```

**Notes:**

- `System.Diagnostics.Stopwatch` is available in UdonSharp (verified in SDK 3.7.1+; not explicitly listed in the official allowlist but confirmed working in production worlds).
- `SendCustomEventDelayedFrames` is documented in [events.md](events.md).
- The `BranchByBudget` helper is checked **after each unit of work**, not before, so the final unit in a budget window may slightly exceed the target. Keep individual work units small (single array element, single string operation) to minimise overshoot.
- Do not share a single `Stopwatch` instance across two simultaneous processing pipelines — each pipeline needs its own instance and its own `_processBudgetMs` field.
- **Important:** `Stopwatch` measures wall-clock time continuously, including idle time between frames. When `BranchByBudget` defers work to the next frame via `SendCustomEventDelayedFrames`, the stopwatch is reset and restarted in `BranchByBudget` so the next frame begins with a fresh budget. If you restructure this pattern, always reset the stopwatch at the start of each new frame's work — otherwise the elapsed time will include the inter-frame gap and the budget will appear instantly exhausted.

**When to use:**

- Parsing large strings received from `VRCUrl` or `VRCStringDownloader` downloads
- Batch texture or colour decoding from Base64 data
- Building UI panels from multi-entry data arrays
- Any single-threaded operation that may take more than 5 ms in isolation

---

### Heavy Processing Architecture

#### Problem

The Frame Budget Stopwatch above solves *when to yield* — but large-scale systems (world builders, replay-based games, procedural generators) also need to answer *what to process*, *how to rebuild*, and *how to cancel safely*. Without a clear separation between authoritative data and derived visuals, a reset or late-joiner sync can leave the world in an inconsistent state.

#### Core Principle: Authoritative Data vs Derived State

Split every heavy system into two layers:

| Layer | Holds | Examples | Survives reset? |
|-------|-------|----------|----------------|
| **Authoritative** | Minimal data that fully describes the current state | Operation log (`byte[]`), config arrays, placement indices | Yes — this IS the state |
| **Derived** | Visuals / physics / UI generated from authoritative data | Instantiated GameObjects, UI text, material colours | No — regenerated on demand |

The rebuild contract: given only the authoritative layer, the system can regenerate all derived state from scratch. This makes reset, undo, and late-joiner sync straightforward — replay the authoritative data through the same generation pipeline.

#### Pattern: Cursor-Based Rebuild

When derived state involves many objects (e.g., 200+ placed blocks), rebuilding in a single frame causes a VR hitch. Combine the authoritative/derived split with the `BranchByBudget` stopwatch:

```csharp
using UdonSharp;
using UnityEngine;
using System.Diagnostics;

[UdonBehaviourSyncMode(BehaviourSyncMode.Manual)]
public class RebuildableWorld : UdonSharpBehaviour
{
    // Pool size and synced array size must match.
    private const int MaxPlacements = 256;

    [Header("Authoritative Data")]
    [UdonSynced] private int[] _placementIds = new int[MaxPlacements];
    [UdonSynced] private Vector3[] _placementPositions = new Vector3[MaxPlacements];
    [UdonSynced] private int _placementCount;

    [Header("Derived State — pre-allocate MaxPlacements objects in the scene")]
    [SerializeField] private GameObject[] _blockPool;
    private int _rebuildCursor;
    private bool _isRebuilding;

    [Header("Budget")]
    [SerializeField] private float _budgetMs = 16f;
    private Stopwatch _sw;

    void Start()
    {
        _sw = new Stopwatch();

        // Fail-fast: detect Inspector misconfiguration before any rebuild
        if (_blockPool == null || _blockPool.Length < MaxPlacements)
        {
            Debug.LogError($"[RebuildableWorld] _blockPool must have at least {MaxPlacements} entries.");
            return;
        }
    }

    // --- Authoritative mutation (owner only) ---

    public void AddPlacement(int blockId, Vector3 position)
    {
        if (!Networking.IsOwner(gameObject)) return;
        if (_placementCount >= MaxPlacements) return;
        // Block incremental adds while a full rebuild is in flight
        // to avoid double-applying the new entry.
        if (_isRebuilding) return;

        _placementIds[_placementCount] = blockId;
        _placementPositions[_placementCount] = position;
        _placementCount++;

        // Instant local feedback for the single new block
        ApplyOnePlacement(_placementCount - 1);
        RequestSerialization();
    }

    // --- Full rebuild (reset, undo, late-joiner) ---

    public void BeginFullRebuild()
    {
        // Hide all derived objects before rebuilding
        for (int i = 0; i < _blockPool.Length; i++)
        {
            _blockPool[i].SetActive(false);
        }

        _rebuildCursor = 0;
        _isRebuilding = true;
        _sw.Reset();
        _sw.Start();
        SendCustomEvent(nameof(_RebuildStep));
    }

    public void _RebuildStep()
    {
        // Guard: if cancelled or a new BeginFullRebuild was called while
        // a previous deferred _RebuildStep was still pending, bail out.
        if (!_isRebuilding) return;

        while (_rebuildCursor < _placementCount)
        {
            ApplyOnePlacement(_rebuildCursor);
            _rebuildCursor++;

            if (_sw.Elapsed.TotalMilliseconds >= _budgetMs)
            {
                SendCustomEventDelayedFrames(nameof(_RebuildStep), 1);
                _sw.Reset();
                _sw.Start();
                return;
            }
        }

        _sw.Stop();
        _isRebuilding = false;
    }

    private void ApplyOnePlacement(int index)
    {
        if (index < 0 || index >= _blockPool.Length) return;
        if (_blockPool[index] == null) return;
        _blockPool[index].SetActive(true);
        _blockPool[index].transform.position = _placementPositions[index];
        // blockId lookup omitted for brevity
    }

    // --- Sync ---

    public override void OnDeserialization()
    {
        // Late joiner or owner change: full rebuild from authoritative data.
        // If a previous rebuild is mid-flight, BeginFullRebuild resets the
        // cursor and sets _isRebuilding = true; the stale deferred callback
        // from the old rebuild bails out at the guard in _RebuildStep.
        BeginFullRebuild();
    }
}
```

**Key points:**

- `AddPlacement` mutates the authoritative arrays and applies instant local feedback for one block — no full rebuild needed for incremental changes. It is blocked while `_isRebuilding` is true to avoid double-applying entries.
- `BeginFullRebuild` is the universal entry point for reset, undo, and late-joiner sync. It clears all derived state and walks the authoritative data with a cursor. If called while a previous rebuild is in progress, the stale deferred `_RebuildStep` callback safely exits via the `_isRebuilding` guard.
- The `_blockPool` is pre-allocated in the scene (UdonSharp cannot instantiate at runtime). The pool size must equal `MaxPlacements`; both the synced arrays and the pool share this constant.
- `Vector3[]` sync is valid but costs 12 bytes per element. For large placement counts consider packing positions into `int[]` with fixed-point encoding — see [networking-bandwidth.md](networking-bandwidth.md).

#### Pattern: Operation Log with Replay

For systems where the *sequence of actions* matters (board games, drawing tools), store an operation log rather than final state. This enables undo, replay, and late-joiner catch-up:

```csharp
// Authoritative layer: operation log
[UdonSynced] private byte[] _opLog;       // Packed operations
[UdonSynced] private int _opCount;         // Number of valid entries

// Each operation is a fixed-size record (e.g., 4 bytes):
//   byte 0: operation type (place=0, remove=1, move=2)
//   byte 1: target slot index
//   byte 2-3: parameter (e.g., colour index, position index)

private void ReplayFromScratch()
{
    ResetDerivedState();
    for (int i = 0; i < _opCount; i++)
    {
        int offset = i * 4;
        byte opType = _opLog[offset];
        byte slot   = _opLog[offset + 1];
        int param   = (_opLog[offset + 2] << 8) | _opLog[offset + 3];
        ApplyOperation(opType, slot, param);
    }
}
```

**Cross-reference:** The `UndoableGameManager.cs` template uses **full-state snapshots** rather than operation logs — each move saves the complete `currentState` array via `System.Array.Copy`. Use snapshots when state is small and replay is expensive; use the operation-log approach when state is large but individual operations are compact. See [assets/templates/UndoableGameManager.cs](../assets/templates/UndoableGameManager.cs).

> **Note:** The operation-log snippet above is a fragment showing the data layout and replay loop. In a full implementation, wrap it in an `UdonSharpBehaviour` class with `[UdonBehaviourSyncMode(BehaviourSyncMode.Manual)]` and add an initialized array (e.g., `private byte[] _opLog = new byte[4000];` for up to 1000 four-byte operations — 4 KB, well within the ~282 KB Manual sync limit).

#### Reset vs Cancel

These are distinct operations — conflating them causes bugs:

| Operation | Meaning | Authoritative data | Derived state | In-progress work |
|-----------|---------|-------------------|---------------|-----------------|
| **Reset** | Return to a known initial state | Revert to snapshot (e.g., `_opCount = 0` or restore `history[0]`) | Full rebuild from reverted data | Abort and discard |
| **Cancel** | Abort an in-progress multi-frame operation | Keep current authoritative data unchanged | Stop rebuild cursor, keep whatever is already rendered | Abort only the pending steps |

```csharp
// Cancel: stop an in-progress rebuild without touching authoritative data
public void CancelRebuild()
{
    _isRebuilding = false;
    // Derived state is partially rebuilt — acceptable for cancel.
    // Next user action or sync will trigger a fresh full rebuild if needed.
}

// Reset: revert authoritative data, then rebuild
public void ResetToInitial()
{
    if (!Networking.IsOwner(gameObject)) return;
    _placementCount = 0;
    BeginFullRebuild();
    RequestSerialization();
}
```

#### Guidelines

| Guideline | Rationale |
|-----------|-----------|
| Keep authoritative data in synced arrays, derived state in local references | Late joiners receive authoritative data via `OnDeserialization` and rebuild locally |
| One rebuild entry point (`BeginFullRebuild`) for all triggers | Reset, undo, late-joiner sync, and error recovery all use the same path — fewer edge cases |
| Do not mix rebuild progress with sync serialization | If `RequestSerialization` fires mid-rebuild, the partial derived state is irrelevant — only authoritative data is transmitted |
| Cap operation logs with a maximum size | `byte[]` sync has a ~282 KB Manual sync limit; a 4-byte-per-op log with 1000 ops = 4 KB — well within budget |
| Use cancel for user-initiated abort, reset for state revert | Cancel preserves partial visual progress; reset guarantees a clean starting state |

---

## Rate Limit Resolver

### Problem

VRChat enforces a **5-second rate limit** on video URL loads shared across the entire scene. Multiple behaviours in the same world that independently trigger URL loads will collide: the second request within the 5-second window is silently rejected, leaving the requester waiting indefinitely with no error callback.

**Cross-reference:** The same 5-second rate limit applies to `VRCStringDownloader` and image-loading requests. See [web-loading.md](web-loading.md) for details on string/image downloads.

### Solution

A singleton `UrlLoadScheduler` behaviour serialised into every world that needs video URL loading. It owns an array-based queue of pending load requests. Each request stores the requester behaviour reference and a callback method name. The scheduler drains one request per 5.05-second cycle (5.05 s adds a small margin above the hard limit), ensuring no two loads collide.

All video-loading behaviours in the world hold a `[SerializeField]` reference to the same `UrlLoadScheduler` instance rather than triggering loads directly.

**Architecture:**

```
VideoPlayerA ──ScheduleLoad──▶ UrlLoadScheduler
VideoPlayerB ──ScheduleLoad──▶  (shared singleton)
                                     │
                          every 5.05s │ drain one request
                                     ▼
                          requester.SendCustomEvent(callbackName)
```

```csharp
using UdonSharp;
using UnityEngine;
using VRC.SDKBase;

/// <summary>
/// Singleton scheduler that enforces the VRChat 5-second URL-load rate limit.
/// Place one instance in the scene and wire all video-loading behaviours to it
/// via SerializeField.
/// </summary>
[UdonBehaviourSyncMode(BehaviourSyncMode.NoVariableSync)]
public class UrlLoadScheduler : UdonSharpBehaviour
{
    [Header("Rate Limit")]
    [Tooltip("Minimum seconds between URL loads. Must be >= 5.0.")]
    [SerializeField] private float _intervalSeconds = 5.05f;

    // Queue storage — parallel arrays act as a struct-of-arrays queue.
    private const int MaxQueueDepth = 16;

    private UdonSharpBehaviour[] _queueRequesters
        = new UdonSharpBehaviour[MaxQueueDepth];
    private string[] _queueCallbacks = new string[MaxQueueDepth];
    private VRCUrl[] _queueUrls      = new VRCUrl[MaxQueueDepth];

    private int _queueHead  = 0; // index of oldest item (dequeue from here)
    private int _queueTail  = 0; // index of next free slot (enqueue here)
    private int _queueCount = 0;

    private bool _drainPending = false;

    void Start()
    {
        // Enforce the VRChat rate-limit lower bound at runtime regardless of
        // what the Inspector field was set to.
        if (_intervalSeconds < 5.0f) _intervalSeconds = 5.0f;
    }

    // ── Public API ────────────────────────────────────────────────────────

    /// <summary>
    /// Enqueues a URL load request. When the scheduler drains this request,
    /// it calls requester.SendCustomEvent(callbackName).
    /// The requester is expected to perform the actual VRCUrl load inside
    /// that callback.
    /// </summary>
    public void ScheduleLoad(
        UdonSharpBehaviour requester,
        string callbackName,
        VRCUrl url)
    {
        if (requester == null || string.IsNullOrEmpty(callbackName)) return;

        if (_queueCount >= MaxQueueDepth)
        {
            Debug.LogWarning("[UrlLoadScheduler] Queue full — dropping load request.");
            return;
        }

        _queueRequesters[_queueTail] = requester;
        _queueCallbacks[_queueTail]  = callbackName;
        _queueUrls[_queueTail]       = url;

        _queueTail  = (_queueTail + 1) % MaxQueueDepth;
        _queueCount++;

        // Start the drain loop if it is not already running.
        if (!_drainPending)
        {
            _drainPending = true;
            SendCustomEvent(nameof(_DrainNext));
        }
    }

    // ── Internal drain loop ───────────────────────────────────────────────

    /// <summary>
    /// Dequeues and dispatches one request, then schedules itself again
    /// if the queue is still non-empty.
    /// </summary>
    public void _DrainNext()
    {
        if (_queueCount == 0)
        {
            _drainPending = false;
            return;
        }

        // Dequeue the oldest request.
        UdonSharpBehaviour requester = _queueRequesters[_queueHead];
        string callbackName          = _queueCallbacks[_queueHead];
        // VRCUrl is written to the requester's public field before the callback.
        VRCUrl url                   = _queueUrls[_queueHead];

        // Clear the slot.
        _queueRequesters[_queueHead] = null;
        _queueCallbacks[_queueHead]  = null;
        _queueUrls[_queueHead]       = null;
        _queueHead  = (_queueHead + 1) % MaxQueueDepth;
        _queueCount--;

        // Deliver the URL to the requester via a public field, then fire the callback.
        if (requester != null)
        {
            requester.SetProgramVariable("ScheduledUrl", url);
            // IMPORTANT: Consumer must have a public field named exactly "ScheduledUrl" (VRCUrl type).
            // If the field is renamed, this call silently fails at runtime.
            requester.SendCustomEvent(callbackName);
        }

        // Schedule the next drain after the rate-limit interval.
        if (_queueCount > 0)
        {
            SendCustomEventDelayedSeconds(nameof(_DrainNext), _intervalSeconds);
        }
        else
        {
            _drainPending = false;
        }
    }
}
```

**Consumer — how a video-loading behaviour uses the scheduler:**

```csharp
using UdonSharp;
using UnityEngine;
using VRC.SDKBase;

[UdonBehaviourSyncMode(BehaviourSyncMode.Manual)]
public class ManagedVideoLoader : UdonSharpBehaviour
{
    [SerializeField] private UrlLoadScheduler _scheduler;

    // Written by UrlLoadScheduler before the callback fires.
    // The field name must match the string constant used in UrlLoadScheduler._DrainNext
    // ("ScheduledUrl"). Use FIELD_SCHEDULED_URL when calling SetProgramVariable from
    // custom code to avoid silent mismatches.
    public const string FIELD_SCHEDULED_URL = "ScheduledUrl";
    [HideInInspector] public VRCUrl ScheduledUrl;

    public void RequestLoad(VRCUrl url)
    {
        if (_scheduler == null) { Debug.LogError("[ManagedVideoLoader] Scheduler not assigned"); return; }
        _scheduler.ScheduleLoad(this, nameof(OnScheduledLoad), url);
    }

    /// <summary>
    /// Called by UrlLoadScheduler when it is safe to load.
    /// ScheduledUrl is already set at this point.
    /// </summary>
    public void OnScheduledLoad()
    {
        if (ScheduledUrl == null) return;
        Debug.Log($"[ManagedVideoLoader] Loading URL: {ScheduledUrl}");
        // Perform the actual VRCUrl load here (e.g. videoPlayer.LoadURL(ScheduledUrl)).
    }
}
```

**Notes:**
- `_intervalSeconds` defaults to 5.05 s. Do not set it below 5.0.
- If two behaviours call `ScheduleLoad` in the same frame, only the first starts the drain loop; the second is queued and will fire after 5.05 s.
- The queue depth is 16 by default. Increase `MaxQueueDepth` if the world can have more concurrent requesters than that.
- `ScheduledUrl` on the consumer must be declared `public` (not `[HideInInspector]` alone) for `SetProgramVariable` to write it; the `[HideInInspector]` attribute hides it from the Inspector while keeping it accessible to the scheduler.
- **`SetProgramVariable` field-name contract**: The scheduler writes to the field named `"ScheduledUrl"` by string at runtime. If the consumer renames that field, `SetProgramVariable` silently no-ops and the callback receives `null`. Always keep the field name in sync with the string literal in `_DrainNext`.

---


## See Also

- [patterns-core.md](patterns-core.md) - Initialization, interaction, timer, audio, pickup, animation, UI
- [patterns-networking.md](patterns-networking.md) - Object pooling, game state, NetworkCallable
- [patterns-utilities.md](patterns-utilities.md) - Array helpers, event bus, relay communication
- [networking.md](networking.md) - Network bandwidth throttling and sync optimization
- [web-loading-advanced.md](web-loading-advanced.md) - Packed resource loading, Base64 texture decode, LRU cache
