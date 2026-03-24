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
```

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


## See Also

- [patterns-core.md](patterns-core.md) - Initialization, interaction, timer, audio, pickup, animation, UI
- [patterns-networking.md](patterns-networking.md) - Object pooling, game state, NetworkCallable
- [patterns-utilities.md](patterns-utilities.md) - Array helpers, event bus, relay communication
- [networking.md](networking.md) - Network bandwidth throttling and sync optimization
