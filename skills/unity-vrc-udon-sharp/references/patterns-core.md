# UdonSharp Core Patterns

Initialization, interaction, player detection, timer, audio, pickup, animation, UI, and teleportation patterns for VRChat world development.

## Initialization Patterns

In VRChat worlds, gimmicks are often **placed in an inactive state** (for performance optimization, conditional display, etc.). Since `Start()` is not called when the GameObject is inactive, initialization requires careful handling.

### Problem: Start() Not Called

```csharp
// BAD: Start() is not called when placed in an inactive state
public class BrokenGimmick : UdonSharpBehaviour
{
    private AudioSource audioSource;

    void Start()
    {
        // This is never reached if the GameObject is inactive!
        audioSource = GetComponent<AudioSource>();
    }

    public void PlaySound()
    {
        audioSource.Play(); // NullReferenceException!
    }
}
```

### Solution: Separate Initialize Method

```csharp
// GOOD: OnEnable + initialization flag pattern
public class RobustGimmick : UdonSharpBehaviour
{
    [Header("References")]
    [SerializeField] private AudioSource audioSource;

    private bool _initialized = false;

    void OnEnable()
    {
        // Called when transitioning from inactive to active
        Initialize();
    }

    void Start()
    {
        // Initializes here if active from the start
        Initialize();
    }

    private void Initialize()
    {
        if (_initialized) return;
        _initialized = true;

        // Fallback if not set via SerializeField
        if (audioSource == null)
        {
            audioSource = GetComponent<AudioSource>();
        }
    }

    public void PlaySound()
    {
        Initialize(); // Guard against being called externally first
        if (audioSource != null)
        {
            audioSource.Play();
        }
    }
}
```

### Full Pattern: Defensive Initialization

```csharp
public class DefensiveGimmick : UdonSharpBehaviour
{
    [Header("Configuration")]
    [SerializeField] private float speed = 1.0f;

    [Header("References (Auto-filled if empty)")]
    [SerializeField] private Transform targetTransform;
    [SerializeField] private Renderer targetRenderer;

    // Internal state
    private bool _initialized = false;
    private MaterialPropertyBlock _propBlock;

    // === Lifecycle ===

    void OnEnable()
    {
        Initialize();
    }

    void Start()
    {
        Initialize();
    }

    private void Initialize()
    {
        if (_initialized) return;
        _initialized = true;

        // Auto-fill missing references
        if (targetTransform == null)
        {
            targetTransform = transform;
        }
        if (targetRenderer == null)
        {
            targetRenderer = GetComponent<Renderer>();
        }

        // Initialize internal state
        _propBlock = new MaterialPropertyBlock();

        // Apply initial state
        ApplyInitialState();
    }

    private void ApplyInitialState()
    {
        // Apply initial state (also useful for late joiner support)
    }

    // === Public API ===

    public void DoAction()
    {
        Initialize(); // Defensive call

        // Safe to use all references
        targetRenderer.GetPropertyBlock(_propBlock);
        // ...
    }

    // === Reset ===

    public void ResetGimmick()
    {
        _initialized = false;
        Initialize();
    }
}
```

### Choosing the Right Approach

| Scenario | Recommended pattern |
|----------|--------------|
| Always-active objects | `Start()` only is fine |
| May be placed inactive | `OnEnable()` + `Initialize()` pattern |
| May be called externally before activation | Call `Initialize()` in public methods too |
| Combined with synced variables | Call `Initialize()` in `OnDeserialization()` too |

### Combined with Synced Variables

```csharp
public class SyncedGimmick : UdonSharpBehaviour
{
    [UdonSynced, FieldChangeCallback(nameof(State))]
    private int _state = 0;

    private bool _initialized = false;
    private Renderer _renderer;

    public int State
    {
        get => _state;
        set
        {
            _state = value;
            Initialize(); // Ensure initialization on sync receive
            ApplyState();
        }
    }

    void OnEnable() => Initialize();
    void Start() => Initialize();

    private void Initialize()
    {
        if (_initialized) return;
        _initialized = true;

        _renderer = GetComponent<Renderer>();
    }

    private void ApplyState()
    {
        if (_renderer == null) return;
        _renderer.enabled = _state > 0;
    }

    public override void OnDeserialization()
    {
        Initialize(); // Late joiner support
        ApplyState();
    }
}
```

---

## Interaction Patterns

### Basic Button

```csharp
using UdonSharp;
using UnityEngine;
using VRC.SDKBase;
using VRC.Udon;

public class SimpleButton : UdonSharpBehaviour
{
    public GameObject targetObject;
    private bool isOn = false;

    public override void Interact()
    {
        isOn = !isOn;
        targetObject.SetActive(isOn);
    }
}
```

### Button with Cooldown

```csharp
public class CooldownButton : UdonSharpBehaviour
{
    public float cooldownTime = 2.0f;
    private float lastInteractTime = -999f;

    public override void Interact()
    {
        if (Time.time - lastInteractTime < cooldownTime)
        {
            return; // Still on cooldown
        }

        lastInteractTime = Time.time;
        DoAction();
    }

    private void DoAction()
    {
        Debug.Log("Button pressed!");
    }
}
```

### Synced Toggle Switch

```csharp
public class SyncedSwitch : UdonSharpBehaviour
{
    public GameObject[] controlledObjects;

    [UdonSynced, FieldChangeCallback(nameof(IsOn))]
    private bool _isOn = false;

    public bool IsOn
    {
        get => _isOn;
        set
        {
            _isOn = value;
            UpdateObjects();
        }
    }

    public override void Interact()
    {
        Networking.SetOwner(Networking.LocalPlayer, gameObject);
        IsOn = !IsOn;
        RequestSerialization();
    }

    private void UpdateObjects()
    {
        foreach (GameObject obj in controlledObjects)
        {
            if (obj != null)
            {
                obj.SetActive(_isOn);
            }
        }
    }
}
```

## Player Detection

### Trigger Zone

```csharp
public class PlayerTrigger : UdonSharpBehaviour
{
    public GameObject activateOnEnter;
    private int playersInZone = 0;

    public override void OnPlayerTriggerEnter(VRCPlayerApi player)
    {
        playersInZone++;

        if (player.isLocal)
        {
            OnLocalPlayerEnter();
        }

        activateOnEnter.SetActive(playersInZone > 0);
    }

    public override void OnPlayerTriggerExit(VRCPlayerApi player)
    {
        playersInZone--;

        if (player.isLocal)
        {
            OnLocalPlayerExit();
        }

        activateOnEnter.SetActive(playersInZone > 0);
    }

    private void OnLocalPlayerEnter()
    {
        Debug.Log("Welcome to the zone!");
    }

    private void OnLocalPlayerExit()
    {
        Debug.Log("Goodbye!");
    }
}
```

### Player Counter Display

```csharp
using TMPro;

public class PlayerCounter : UdonSharpBehaviour
{
    public TextMeshProUGUI counterText;

    void Start()
    {
        UpdateCounter();
    }

    public override void OnPlayerJoined(VRCPlayerApi player)
    {
        UpdateCounter();
    }

    public override void OnPlayerLeft(VRCPlayerApi player)
    {
        UpdateCounter();
    }

    private void UpdateCounter()
    {
        VRCPlayerApi[] players = new VRCPlayerApi[VRCPlayerApi.GetPlayerCount()];
        VRCPlayerApi.GetPlayers(players);
        counterText.text = $"Players: {players.Length}";
    }
}
```

### Get All Players in Range

```csharp
public class ProximityDetector : UdonSharpBehaviour
{
    public float detectionRange = 5.0f;

    public VRCPlayerApi[] GetPlayersInRange()
    {
        VRCPlayerApi[] allPlayers = new VRCPlayerApi[VRCPlayerApi.GetPlayerCount()];
        VRCPlayerApi.GetPlayers(allPlayers);

        // Single pass: collect matches into an oversized temp array, then copy
        VRCPlayerApi[] temp = new VRCPlayerApi[allPlayers.Length];
        int count = 0;

        foreach (VRCPlayerApi player in allPlayers)
        {
            if (player != null && player.IsValid())
            {
                float distance = Vector3.Distance(
                    transform.position,
                    player.GetPosition()
                );
                if (distance <= detectionRange)
                {
                    temp[count++] = player;
                }
            }
        }

        // Trim to actual count
        VRCPlayerApi[] result = new VRCPlayerApi[count];
        for (int i = 0; i < count; i++)
        {
            result[i] = temp[i];
        }

        return result;
    }
}
```

## Timer Patterns

### Simple Timer

```csharp
public class SimpleTimer : UdonSharpBehaviour
{
    public float duration = 60f;
    public TextMeshProUGUI timerText;

    private float timeRemaining;
    private bool isRunning = false;

    public void StartTimer()
    {
        timeRemaining = duration;
        isRunning = true;
    }

    public void StopTimer()
    {
        isRunning = false;
    }

    void Update()
    {
        if (!isRunning) return;

        timeRemaining -= Time.deltaTime;

        if (timeRemaining <= 0)
        {
            timeRemaining = 0;
            isRunning = false;
            OnTimerComplete();
        }

        UpdateDisplay();
    }

    private void UpdateDisplay()
    {
        int minutes = Mathf.FloorToInt(timeRemaining / 60);
        int seconds = Mathf.FloorToInt(timeRemaining % 60);
        timerText.text = $"{minutes:00}:{seconds:00}";
    }

    private void OnTimerComplete()
    {
        Debug.Log("Timer finished!");
    }
}
```

### Delayed Action (Without Coroutines)

```csharp
public class DelayedAction : UdonSharpBehaviour
{
    public void DoAfterDelay(float seconds)
    {
        SendCustomEventDelayedSeconds(nameof(ExecuteDelayedAction), seconds);
    }

    public void ExecuteDelayedAction()
    {
        Debug.Log("Delayed action executed!");
    }

    // Cancel by disabling the component
    public void CancelDelayed()
    {
        // Note: There's no direct way to cancel SendCustomEventDelayedSeconds
        // Use a flag instead
    }
}
```

### Repeating Action

```csharp
public class RepeatingAction : UdonSharpBehaviour
{
    public float interval = 1.0f;
    private bool isRepeating = false;

    public void StartRepeating()
    {
        isRepeating = true;
        DoRepeat();
    }

    public void StopRepeating()
    {
        isRepeating = false;
    }

    public void DoRepeat()
    {
        if (!isRepeating) return;

        // Your repeating action here
        Debug.Log("Tick!");

        // Schedule next iteration
        SendCustomEventDelayedSeconds(nameof(DoRepeat), interval);
    }
}
```

## Audio Patterns

### Simple Audio Player

```csharp
public class AudioPlayer : UdonSharpBehaviour
{
    public AudioSource audioSource;
    public AudioClip[] clips;

    public void PlayClip(int index)
    {
        if (index >= 0 && index < clips.Length)
        {
            audioSource.clip = clips[index];
            audioSource.Play();
        }
    }

    public void PlayRandom()
    {
        if (clips.Length > 0)
        {
            int randomIndex = Random.Range(0, clips.Length);
            PlayClip(randomIndex);
        }
    }

    public void Stop()
    {
        audioSource.Stop();
    }
}
```

### Synced Music Player

```csharp
public class SyncedMusicPlayer : UdonSharpBehaviour
{
    public AudioSource audioSource;
    public AudioClip[] tracks;

    [UdonSynced, FieldChangeCallback(nameof(CurrentTrack))]
    private int _currentTrack = -1;

    [UdonSynced, FieldChangeCallback(nameof(IsPlaying))]
    private bool _isPlaying = false;

    public int CurrentTrack
    {
        get => _currentTrack;
        set
        {
            _currentTrack = value;
            if (_currentTrack >= 0 && _currentTrack < tracks.Length)
            {
                audioSource.clip = tracks[_currentTrack];
                if (_isPlaying) audioSource.Play();
            }
        }
    }

    public bool IsPlaying
    {
        get => _isPlaying;
        set
        {
            _isPlaying = value;
            if (_isPlaying) audioSource.Play();
            else audioSource.Stop();
        }
    }

    public void PlayTrack(int index)
    {
        Networking.SetOwner(Networking.LocalPlayer, gameObject);
        CurrentTrack = index;
        IsPlaying = true;
        RequestSerialization();
    }

    public void TogglePlay()
    {
        Networking.SetOwner(Networking.LocalPlayer, gameObject);
        IsPlaying = !IsPlaying;
        RequestSerialization();
    }
}
```

## Pickup Patterns

### Basic Pickup with Events

```csharp
public class CustomPickup : UdonSharpBehaviour
{
    public override void OnPickup()
    {
        Debug.Log("Picked up!");
    }

    public override void OnDrop()
    {
        Debug.Log("Dropped!");
    }

    public override void OnPickupUseDown()
    {
        Debug.Log("Use button pressed!");
        DoPickupAction();
    }

    public override void OnPickupUseUp()
    {
        Debug.Log("Use button released!");
    }

    private void DoPickupAction()
    {
        // Action when use button is pressed while holding
    }
}
```

### Throwable Object

```csharp
public class Throwable : UdonSharpBehaviour
{
    public float throwForce = 10f;
    private Rigidbody rb;
    private VRC_Pickup pickup;

    void Start()
    {
        rb = GetComponent<Rigidbody>();
        pickup = (VRC_Pickup)GetComponent(typeof(VRC_Pickup));
    }

    public override void OnDrop()
    {
        // Apply throw force based on hand velocity
        VRCPlayerApi player = Networking.LocalPlayer;
        if (player != null)
        {
            Vector3 velocity = player.GetVelocity();
            rb.velocity = velocity * throwForce;
        }
    }
}
```

## Animation Patterns

### Simple Animator Control

```csharp
public class AnimatorController : UdonSharpBehaviour
{
    public Animator animator;

    public void PlayAnimation(string triggerName)
    {
        animator.SetTrigger(triggerName);
    }

    public void SetBool(string paramName, bool value)
    {
        animator.SetBool(paramName, value);
    }

    public void SetFloat(string paramName, float value)
    {
        animator.SetFloat(paramName, value);
    }
}
```

### Synced Animation State

```csharp
public class SyncedAnimator : UdonSharpBehaviour
{
    public Animator animator;
    public string boolParameter = "IsActive";

    [UdonSynced, FieldChangeCallback(nameof(AnimState))]
    private bool _animState = false;

    public bool AnimState
    {
        get => _animState;
        set
        {
            _animState = value;
            animator.SetBool(boolParameter, value);
        }
    }

    public override void Interact()
    {
        Networking.SetOwner(Networking.LocalPlayer, gameObject);
        AnimState = !AnimState;
        RequestSerialization();
    }
}
```

## UI Patterns

### Button Array Handler

```csharp
public class ButtonHandler : UdonSharpBehaviour
{
    public int buttonIndex;
    public UdonSharpBehaviour targetScript;
    public string methodName;

    public void OnClick()
    {
        // Store index for target to read
        targetScript.SetProgramVariable("selectedIndex", buttonIndex);
        targetScript.SendCustomEvent(methodName);
    }
}
```

### Slider Value Display

```csharp
using UnityEngine.UI;

public class SliderDisplay : UdonSharpBehaviour
{
    public Slider slider;
    public TextMeshProUGUI valueText;
    public string format = "{0:F1}";

    public void OnSliderChanged()
    {
        valueText.text = string.Format(format, slider.value);
    }
}
```

## Teleportation

### Simple Teleporter

```csharp
public class Teleporter : UdonSharpBehaviour
{
    public Transform destination;

    public override void Interact()
    {
        VRCPlayerApi player = Networking.LocalPlayer;
        if (player != null)
        {
            player.TeleportTo(
                destination.position,
                destination.rotation
            );
        }
    }
}
```

### Multi-Destination Teleporter

```csharp
public class MultiTeleporter : UdonSharpBehaviour
{
    public Transform[] destinations;
    private int currentIndex = 0;

    public override void Interact()
    {
        if (destinations.Length == 0) return;

        VRCPlayerApi player = Networking.LocalPlayer;
        if (player != null)
        {
            player.TeleportTo(
                destinations[currentIndex].position,
                destinations[currentIndex].rotation
            );
            currentIndex = (currentIndex + 1) % destinations.Length;
        }
    }
}
```

## Lazy Initialization Guard

### Problem

`Start()` execution order between UdonBehaviours placed in a scene is not guaranteed. An external script may call a public method before the target behaviour's `Start()` has run, resulting in null-reference errors.

### Solution

Use a private `_initialized` flag and an explicit `Initialize()` method. Call `Initialize()` from both `Start()` and every public API entry point.

```csharp
public class ScoreBoard : UdonSharpBehaviour
{
    [SerializeField] private TextMeshProUGUI scoreText;

    private bool _initialized = false;
    private int _score = 0;

    void Start()
    {
        Initialize();
    }

    private void Initialize()
    {
        if (_initialized) return;
        _initialized = true;

        // One-time setup that requires Unity component access
        if (scoreText == null)
        {
            scoreText = GetComponentInChildren<TextMeshProUGUI>();
        }
        RefreshDisplay();
    }

    /// <summary>
    /// May be called by other behaviours before this object's Start() runs.
    /// The Initialize() guard ensures safety.
    /// </summary>
    public void AddScore(int points)
    {
        Initialize(); // Guard: idempotent, safe to call repeatedly
        _score += points;
        RefreshDisplay();
    }

    public void ResetScore()
    {
        Initialize();
        _score = 0;
        RefreshDisplay();
    }

    private void RefreshDisplay()
    {
        if (scoreText != null)
        {
            scoreText.text = _score.ToString();
        }
    }
}
```

**Key rules:**
- `Initialize()` must be idempotent (guarded by `_initialized`).
- Every `public` method that touches component references should call `Initialize()` first.
- Do not reset `_initialized` to `false` unless you also repeat all setup work (use a dedicated `Reset()` method that sets `_initialized = false` and then calls `Initialize()`).

---

## VRC+ Detection — Reading `isVRCPlus` (SDK 3.10.3+)

This pattern reads `VRCPlayerApi.isVRCPlus` on the local player and conditionally enables a `GameObject`. Substitute any behaviour you want to condition on subscription status — the code shape is the same regardless of what the target object does. Whether and how to use `isVRCPlus` is a design decision left to the caller.

Two technical constraints shape the code: `isVRCPlus` must be read after `OnPlayerRestored` (see `api.md` for the timing rationale), and the value must never be `[UdonSynced]` (each client evaluates `player.isVRCPlus` locally, so a synced value would misreport state for every other client).

```csharp
using UdonSharp;
using UnityEngine;
using VRC.SDKBase;

public class LocalVRCPlusBadge : UdonSharpBehaviour
{
    [SerializeField] private GameObject plusBadge;

    public override void OnPlayerRestored(VRCPlayerApi player)
    {
        if (player == null || !player.isLocal) return;
        plusBadge.SetActive(player.isVRCPlus);
    }
}
```

Notes:
- The read is on the **local** player against the local `VRCPlayerApi`. Applying this to remote players works the same way — iterate `VRCPlayerApi.GetPlayers()` on each client and evaluate each player's `isVRCPlus` locally; never sync the result.
- Do not skip the `OnPlayerRestored` gate. Reading in `OnPlayerJoined` may return an unset / default value while the profile is still being fetched.
- If you need to react to a subscription change mid-session, re-read inside whatever update hook you already have; still no `[UdonSynced]`.

---


## See Also

- [dynamics.md](dynamics.md) - PhysBones, Contacts, and VRC Constraints for physics-based interactions
- [patterns-networking.md](patterns-networking.md) - Object pooling, game state, NetworkCallable, persistence, dynamics
- [patterns-performance.md](patterns-performance.md) - Partial class, update handler, PostLateUpdate, spatial query
- [patterns-ui.md](patterns-ui.md) - UI/Canvas patterns, immobilize guard, localization, settings persistence
- [patterns-utilities.md](patterns-utilities.md) - Array helpers, event bus, relay communication
- [networking.md](networking.md) - Ownership model, sync modes, and RequestSerialization details
