# UdonSharp Common Patterns

Ready-to-use code patterns for VRChat world development.

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

        // Count players in range first
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
                    count++;
                }
            }
        }

        // Create result array
        VRCPlayerApi[] result = new VRCPlayerApi[count];
        int index = 0;
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
                    result[index++] = player;
                }
            }
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

## Utility Patterns

### Simple Object Pooling

```csharp
public class SimplePool : UdonSharpBehaviour
{
    public GameObject prefab;
    public int poolSize = 10;
    public Transform poolParent;

    private GameObject[] pool;
    private int nextIndex = 0;

    void Start()
    {
        pool = new GameObject[poolSize];
        for (int i = 0; i < poolSize; i++)
        {
            pool[i] = VRCInstantiate(prefab);
            pool[i].transform.SetParent(poolParent);
            pool[i].SetActive(false);
        }
    }

    public GameObject Get()
    {
        GameObject obj = pool[nextIndex];
        obj.SetActive(true);
        nextIndex = (nextIndex + 1) % poolSize;
        return obj;
    }

    public void Return(GameObject obj)
    {
        obj.SetActive(false);
    }
}
```

### Array Helpers

```csharp
public class ArrayHelpers : UdonSharpBehaviour
{
    // Find index in array
    public int FindIndex(GameObject[] array, GameObject target)
    {
        for (int i = 0; i < array.Length; i++)
        {
            if (array[i] == target) return i;
        }
        return -1;
    }

    // Shuffle array (Fisher-Yates)
    public void ShuffleArray(int[] array)
    {
        for (int i = array.Length - 1; i > 0; i--)
        {
            int j = Random.Range(0, i + 1);
            int temp = array[i];
            array[i] = array[j];
            array[j] = temp;
        }
    }

    // Resize array (create new)
    public GameObject[] ResizeArray(GameObject[] original, int newSize)
    {
        GameObject[] newArray = new GameObject[newSize];
        int copyLength = Mathf.Min(original.Length, newSize);
        System.Array.Copy(original, newArray, copyLength);
        return newArray;
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

Reference template: `assets/templates/UpdateHandler.cs`

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

## NetworkCallable Patterns (SDK 3.8.1+)

### Basic Parameterized RPC

```csharp
using UdonSharp;
using UnityEngine;
using VRC.SDKBase;
using VRC.Udon.Common.Interfaces;

[UdonBehaviourSyncMode(BehaviourSyncMode.Manual)]
public class NetworkCallableBasic : UdonSharpBehaviour
{
    public TextMeshProUGUI messageText;

    [NetworkCallable]
    public void ShowMessage(string message, int senderId)
    {
        VRCPlayerApi sender = VRCPlayerApi.GetPlayerById(senderId);
        string senderName = sender != null ? sender.displayName : "Unknown";
        messageText.text = $"{senderName}: {message}";
    }

    public void BroadcastMessage(string message)
    {
        SendCustomNetworkEvent(
            NetworkEventTarget.All,
            nameof(ShowMessage),
            message,
            Networking.LocalPlayer.playerId
        );
    }
}
```

### Damage System with NetworkCallable

```csharp
[UdonBehaviourSyncMode(BehaviourSyncMode.Manual)]
public class DamageReceiver : UdonSharpBehaviour
{
    [UdonSynced] private int health = 100;
    public TextMeshProUGUI healthText;

    [NetworkCallable]
    public void TakeDamage(int damage, Vector3 hitPosition, int attackerId)
    {
        // Only owner processes damage
        if (!Networking.IsOwner(gameObject))
        {
            // Forward to owner
            SendCustomNetworkEvent(
                NetworkEventTarget.Owner,
                nameof(TakeDamage),
                damage, hitPosition, attackerId
            );
            return;
        }

        health -= damage;
        RequestSerialization();

        // Notify all players of hit effect
        SendCustomNetworkEvent(
            NetworkEventTarget.All,
            nameof(ShowHitEffect),
            hitPosition
        );

        if (health <= 0)
        {
            SendCustomNetworkEvent(
                NetworkEventTarget.All,
                nameof(OnDeath)
            );
        }
    }

    [NetworkCallable]
    public void ShowHitEffect(Vector3 position)
    {
        // Spawn particle at hit position
        SpawnHitParticle(position);
    }

    [NetworkCallable]
    public void OnDeath()
    {
        // Play death animation/sound
        Debug.Log("Target destroyed!");
    }

    public override void OnDeserialization()
    {
        healthText.text = $"HP: {health}";
    }
}
```

### Chat System

```csharp
[UdonBehaviourSyncMode(BehaviourSyncMode.None)]
public class ChatSystem : UdonSharpBehaviour
{
    public TextMeshProUGUI chatLog;
    public UnityEngine.UI.InputField inputField;

    private string[] messages = new string[50];
    private int messageIndex = 0;

    [NetworkCallable(10)] // Allow 10 messages/sec
    public void ReceiveMessage(string message, string senderName)
    {
        messages[messageIndex] = $"[{senderName}] {message}";
        messageIndex = (messageIndex + 1) % messages.Length;
        UpdateChatDisplay();
    }

    public void SendMessage()
    {
        string msg = inputField.text;
        if (string.IsNullOrEmpty(msg)) return;

        inputField.text = "";

        SendCustomNetworkEvent(
            NetworkEventTarget.All,
            nameof(ReceiveMessage),
            msg,
            Networking.LocalPlayer.displayName
        );
    }

    private void UpdateChatDisplay()
    {
        System.Text.StringBuilder sb = new System.Text.StringBuilder();
        for (int i = 0; i < messages.Length; i++)
        {
            if (!string.IsNullOrEmpty(messages[i]))
            {
                sb.AppendLine(messages[i]);
            }
        }
        chatLog.text = sb.ToString();
    }
}
```

## Persistence Patterns (SDK 3.7.4+)

### Settings Manager

```csharp
using UdonSharp;
using UnityEngine;
using VRC.SDKBase;
using VRC.SDK3.Persistence;

public class SettingsManager : UdonSharpBehaviour
{
    [Header("UI References")]
    public UnityEngine.UI.Slider volumeSlider;
    public UnityEngine.UI.Toggle musicToggle;
    public UnityEngine.UI.Dropdown qualityDropdown;

    private bool initialized = false;

    public override void OnPlayerRestored(VRCPlayerApi player)
    {
        if (!player.isLocal) return;

        // Load all settings
        if (PlayerData.TryGetFloat(player, "volume", out float vol))
            volumeSlider.value = vol;

        if (PlayerData.TryGetBool(player, "musicEnabled", out bool music))
            musicToggle.isOn = music;

        if (PlayerData.TryGetInt(player, "quality", out int quality))
            qualityDropdown.value = quality;

        initialized = true;
    }

    public void OnVolumeChanged()
    {
        if (!initialized) return;
        PlayerData.SetFloat(Networking.LocalPlayer, "volume", volumeSlider.value);
        ApplyVolume(volumeSlider.value);
    }

    public void OnMusicToggled()
    {
        if (!initialized) return;
        PlayerData.SetBool(Networking.LocalPlayer, "musicEnabled", musicToggle.isOn);
        ApplyMusic(musicToggle.isOn);
    }

    public void OnQualityChanged()
    {
        if (!initialized) return;
        PlayerData.SetInt(Networking.LocalPlayer, "quality", qualityDropdown.value);
        ApplyQuality(qualityDropdown.value);
    }
}
```

### Unlock System

```csharp
public class UnlockSystem : UdonSharpBehaviour
{
    [Header("Unlock Objects")]
    public GameObject[] unlockableObjects;
    public string[] unlockKeys;

    private bool dataReady = false;

    public override void OnPlayerRestored(VRCPlayerApi player)
    {
        if (!player.isLocal) return;
        dataReady = true;

        // Check all unlocks
        for (int i = 0; i < unlockableObjects.Length; i++)
        {
            if (PlayerData.TryGetBool(player, unlockKeys[i], out bool unlocked))
            {
                unlockableObjects[i].SetActive(unlocked);
            }
        }
    }

    public void Unlock(int index)
    {
        if (!dataReady) return;
        if (index < 0 || index >= unlockKeys.Length) return;

        PlayerData.SetBool(Networking.LocalPlayer, unlockKeys[index], true);
        unlockableObjects[index].SetActive(true);

        Debug.Log($"Unlocked: {unlockKeys[index]}");
    }

    public void ResetAllUnlocks()
    {
        if (!dataReady) return;

        for (int i = 0; i < unlockKeys.Length; i++)
        {
            PlayerData.DeleteKey(Networking.LocalPlayer, unlockKeys[i]);
            unlockableObjects[i].SetActive(false);
        }
    }
}
```

## Dynamics Patterns (SDK 3.10.0+)

### Interactive Button

```csharp
public class ContactButton : UdonSharpBehaviour
{
    [Header("Visual Feedback")]
    public Transform buttonTop;
    public Material normalMaterial;
    public Material pressedMaterial;
    public Renderer buttonRenderer;

    [Header("Audio")]
    public AudioSource pressSound;
    public AudioSource releaseSound;

    [Header("Settings")]
    public float pressDepth = 0.02f;
    public float pressSpeed = 10f;
    public float cooldown = 0.5f;

    private bool isPressed = false;
    private float lastPressTime;
    private Vector3 originalPos;
    private Vector3 pressedPos;

    void Start()
    {
        originalPos = buttonTop.localPosition;
        pressedPos = originalPos - new Vector3(0, pressDepth, 0);
    }

    void Update()
    {
        Vector3 target = isPressed ? pressedPos : originalPos;
        buttonTop.localPosition = Vector3.Lerp(
            buttonTop.localPosition, target, Time.deltaTime * pressSpeed);
    }

    public override void OnContactEnter(ContactEnterInfo info)
    {
        if (isPressed) return;
        if (Time.time - lastPressTime < cooldown) return;

        isPressed = true;
        lastPressTime = Time.time;
        buttonRenderer.material = pressedMaterial;
        pressSound.Play();

        OnButtonPressed(info);
    }

    public override void OnContactExit(ContactExitInfo info)
    {
        isPressed = false;
        buttonRenderer.material = normalMaterial;
        releaseSound.Play();
    }

    private void OnButtonPressed(ContactEnterInfo info)
    {
        if (info.isAvatar && info.player != null)
        {
            Debug.Log($"Button pressed by: {info.player.displayName}");
        }
        // Add your button action here
    }
}
```

### Touch Piano

```csharp
public class TouchPiano : UdonSharpBehaviour
{
    public AudioSource[] noteAudioSources;
    public int noteIndex;

    private bool isPlaying = false;

    public override void OnContactEnter(ContactEnterInfo info)
    {
        if (isPlaying) return;
        isPlaying = true;

        if (noteIndex >= 0 && noteIndex < noteAudioSources.Length)
        {
            noteAudioSources[noteIndex].Play();
        }
    }

    public override void OnContactExit(ContactExitInfo info)
    {
        isPlaying = false;

        if (noteIndex >= 0 && noteIndex < noteAudioSources.Length)
        {
            noteAudioSources[noteIndex].Stop();
        }
    }
}
```

### Grabbable Rope (Physics)

```csharp
public class GrabbableRope : UdonSharpBehaviour
{
    [Header("Sync")]
    [UdonSynced] private bool isGrabbed = false;
    [UdonSynced] private int grabberId = -1;

    [Header("Audio")]
    public AudioSource grabSound;
    public AudioSource releaseSound;

    public override void OnPhysBoneGrab(PhysBoneGrabInfo info)
    {
        Networking.SetOwner(info.player, gameObject);
        isGrabbed = true;
        grabberId = info.player.playerId;
        RequestSerialization();

        grabSound.Play();
    }

    public override void OnPhysBoneRelease(PhysBoneReleaseInfo info)
    {
        isGrabbed = false;
        grabberId = -1;
        RequestSerialization();

        releaseSound.Play();
    }

    public bool IsGrabbed() => isGrabbed;

    public VRCPlayerApi GetGrabber()
    {
        if (grabberId < 0) return null;
        return VRCPlayerApi.GetPlayerById(grabberId);
    }
}
```

## Synced Game State Management

### History/Undo Sync Pattern

When implementing undo functionality in a game, **history is shared among all players as synced variables**.
The initial state is saved as history entry 0, and resetting returns to history 0 (no separate variable for initial state).

**Important notes:**
- **1 logical operation = 1 history save** (do not save twice on both sender and receiver)
- Save the state **after** the operation, not before
- History saving is done only within the owner's operation processing method

```csharp
[UdonBehaviourSyncMode(BehaviourSyncMode.Manual)]
public class UndoableGameManager : UdonSharpBehaviour
{
    // --- Synced data ---
    [UdonSynced] private byte[] currentState;     // Current game state
    [UdonSynced] private byte[] stateHistory;     // All history (flat array)
    [UdonSynced] private int historyCount;        // Number of saved history entries
    private int stateSize;                        // Size per state

    void Start()
    {
        stateSize = 40; // Example: 40 bottles
        currentState = new byte[stateSize];
        stateHistory = new byte[stateSize * 100]; // Max 100 moves
        InitializeGame();
        SaveStateToHistory(); // Initial state = history[0]
    }

    // --- Owner only: process operations ---
    [NetworkCallable]
    public void OwnerProcessMove(int from, int to, int playerId)
    {
        // Validation omitted
        ExecuteMove(from, to);
        SaveStateToHistory(); // Save once after the operation
        RequestSerialization();
    }

    // --- History management ---
    private void SaveStateToHistory()
    {
        int offset = historyCount * stateSize;
        System.Array.Copy(currentState, 0, stateHistory, offset, stateSize);
        historyCount++;
    }

    public void OnUndoClicked()
    {
        SendCustomNetworkEvent(NetworkEventTarget.Owner, nameof(OwnerUndo));
    }

    [NetworkCallable]
    public void OwnerUndo()
    {
        if (historyCount <= 1) return; // Cannot go before initial state
        historyCount--;
        int offset = (historyCount - 1) * stateSize;
        System.Array.Copy(stateHistory, offset, currentState, 0, stateSize);
        RequestSerialization();
    }

    public void OnResetClicked()
    {
        SendCustomNetworkEvent(NetworkEventTarget.Owner, nameof(OwnerReset));
    }

    [NetworkCallable]
    public void OwnerReset()
    {
        // Return to history[0] = initial state (no separate variable for initial state)
        System.Array.Copy(stateHistory, 0, currentState, 0, stateSize);
        historyCount = 1;
        RequestSerialization();
    }

    // --- All clients: update display ---
    public override void OnDeserialization()
    {
        // Do NOT add to history in OnDeserialization! (causes double-saving)
        UpdateDisplay();
    }

    private void InitializeGame() { /* Initialize currentState */ }
    private void ExecuteMove(int from, int to) { /* Modify currentState */ }
    private void UpdateDisplay() { /* Reflect currentState in UI */ }
}
```

**Common mistakes:**

| Mistake | Problem | Correct approach |
|--------|------|-----------|
| Saving history in OnDeserialization | Double-saving on sender + receiver | Save only in owner's operation method |
| Managing initial state in a separate variable | Inconsistency on reset | history[0] = initial state |
| Saving state before the operation | Undo goes back 2 steps instead of 1 | Save state after the operation |
| Not making history synced | Undo results differ between players | Share history as synced variables |

## Array Utility Helpers

UdonSharp does not support `List<T>`. The following static-style helpers use `System.Array.Copy` to provide list-like operations on plain arrays. Each operation returns a **new array**; the original is never modified.

> **Performance warning:** Every call allocates a new array and copies elements. Do not call these in `Update()` or any hot path. Prefer pre-sized arrays with a manual count variable for high-frequency code.

```csharp
public class ArrayUtils : UdonSharpBehaviour
{
    // Add<T> - append one element, return a new array one element longer.
    public GameObject[] AddGameObject(GameObject[] source, GameObject item)
    {
        GameObject[] result = new GameObject[source.Length + 1];
        System.Array.Copy(source, result, source.Length);
        result[source.Length] = item;
        return result;
    }

    // Contains<T> - return true when the element is present.
    public bool ContainsGameObject(GameObject[] source, GameObject item)
    {
        for (int i = 0; i < source.Length; i++)
        {
            if (source[i] == item) return true;
        }
        return false;
    }

    // AddUnique<T> - append only when the element is not already present.
    public GameObject[] AddUniqueGameObject(GameObject[] source, GameObject item)
    {
        if (ContainsGameObject(source, item)) return source;
        return AddGameObject(source, item);
    }

    // Remove<T> - remove first occurrence, return a new array one element shorter.
    // Returns the original array unchanged when the element is not found.
    public GameObject[] RemoveGameObject(GameObject[] source, GameObject item)
    {
        int removeIndex = -1;
        for (int i = 0; i < source.Length; i++)
        {
            if (source[i] == item)
            {
                removeIndex = i;
                break;
            }
        }
        if (removeIndex < 0) return source;
        return RemoveAtGameObject(source, removeIndex);
    }

    // RemoveAt<T> - remove the element at a given index.
    public GameObject[] RemoveAtGameObject(GameObject[] source, int index)
    {
        if (index < 0 || index >= source.Length) return source;
        GameObject[] result = new GameObject[source.Length - 1];
        System.Array.Copy(source, 0, result, 0, index);
        System.Array.Copy(source, index + 1, result, index, source.Length - index - 1);
        return result;
    }

    // Insert<T> - insert an element before the given index.
    public GameObject[] InsertGameObject(GameObject[] source, int index, GameObject item)
    {
        if (index < 0) index = 0;
        if (index > source.Length) index = source.Length;
        GameObject[] result = new GameObject[source.Length + 1];
        System.Array.Copy(source, 0, result, 0, index);
        result[index] = item;
        System.Array.Copy(source, index, result, index + 1, source.Length - index);
        return result;
    }
}
```

Repeat the same signatures for `UdonSharpBehaviour[]`, `int[]`, or any other element type you need — UdonSharp does not support generic methods, so one copy per type is required.

---

## Event Bus Pattern

### Problem

C# delegates and events are unavailable in UdonSharp. How can one behaviour notify several others when something changes?

### Solution

Maintain a `UdonSharpBehaviour[]` subscriber list. Raising an event iterates the list and calls `SendCustomEvent(methodName)` on each entry.

```csharp
using UdonSharp;
using UnityEngine;

/// <summary>
/// A minimal event bus. Producers call RaiseEvent(); consumers register themselves
/// and implement the matching handler method.
/// </summary>
public class EventBus : UdonSharpBehaviour
{
    // Internal listener registry
    [SerializeField] private UdonSharpBehaviour[] _listeners = new UdonSharpBehaviour[0];
    private int _listenerCount = 0;

    // Maximum listeners before compaction is required
    private const int MaxListeners = 32;

    void Start()
    {
        _listeners = new UdonSharpBehaviour[MaxListeners];
        _listenerCount = 0;
    }

    /// <summary>
    /// Register a listener. The listener must implement the handler method by name.
    /// </summary>
    public void RegisterListener(UdonSharpBehaviour listener)
    {
        if (listener == null) return;
        if (_listenerCount >= MaxListeners) return;

        // Avoid duplicate registrations
        for (int i = 0; i < _listenerCount; i++)
        {
            if (_listeners[i] == listener) return;
        }

        _listeners[_listenerCount] = listener;
        _listenerCount++;
    }

    /// <summary>
    /// Unregister a listener.
    /// </summary>
    public void UnregisterListener(UdonSharpBehaviour listener)
    {
        for (int i = 0; i < _listenerCount; i++)
        {
            if (_listeners[i] == listener)
            {
                // Compact: shift remaining entries left
                _listenerCount--;
                for (int j = i; j < _listenerCount; j++)
                {
                    _listeners[j] = _listeners[j + 1];
                }
                _listeners[_listenerCount] = null;
                return;
            }
        }
    }

    /// <summary>
    /// Raise an event. Every registered listener receives SendCustomEvent(eventMethodName).
    /// Null or destroyed listeners are silently skipped and compacted out.
    /// </summary>
    public void RaiseEvent(string eventMethodName)
    {
        int writeIndex = 0;
        for (int i = 0; i < _listenerCount; i++)
        {
            UdonSharpBehaviour listener = _listeners[i];

            // Skip destroyed or null entries
            if (listener == null) continue;

            _listeners[writeIndex] = listener;
            writeIndex++;

            listener.SendCustomEvent(eventMethodName);
        }

        // Zero out stale tail slots after compaction
        for (int i = writeIndex; i < _listenerCount; i++)
        {
            _listeners[i] = null;
        }
        _listenerCount = writeIndex;
    }
}
```

**Consumer example:**

```csharp
public class DoorController : UdonSharpBehaviour
{
    [SerializeField] private EventBus doorBus;
    [SerializeField] private Animator doorAnimator;

    void Start()
    {
        doorBus.RegisterListener(this);
    }

    // Called by EventBus.RaiseEvent("OnDoorOpened")
    public void OnDoorOpened()
    {
        doorAnimator.SetTrigger("Open");
    }
}
```

**Producer example:**

```csharp
public class DoorTrigger : UdonSharpBehaviour
{
    [SerializeField] private EventBus doorBus;

    public override void OnPlayerTriggerEnter(VRCPlayerApi player)
    {
        if (player.isLocal)
        {
            doorBus.RaiseEvent("OnDoorOpened");
        }
    }
}
```

---

## GameObject Relay Communication

### Problem

Direct references couple event producers tightly to their consumers. How can a behaviour react to a signal without the producer knowing its type?

### Solution

Use `GameObject.SetActive` as a signalling mechanism. The producer toggles a relay GameObject; any behaviour on that GameObject reacts in `OnEnable` or `OnDisable`.

**Producer — sends the signal:**

```csharp
public class LightSwitchTrigger : UdonSharpBehaviour
{
    [SerializeField] private GameObject lightsOnRelay;
    [SerializeField] private GameObject lightsOffRelay;

    private bool _lightsOn = false;

    public override void Interact()
    {
        _lightsOn = !_lightsOn;

        if (_lightsOn)
        {
            // Pulse the relay: activate then deactivate next frame
            lightsOnRelay.SetActive(true);
            lightsOnRelay.SetActive(false);
        }
        else
        {
            lightsOffRelay.SetActive(true);
            lightsOffRelay.SetActive(false);
        }
    }
}
```

**Consumer — reacts to the signal:**

```csharp
/// <summary>
/// Attach to the lightsOnRelay GameObject.
/// OnEnable fires every time the producer calls SetActive(true).
/// </summary>
public class LightsOnResponder : UdonSharpBehaviour
{
    [SerializeField] private Light[] sceneLights;

    void OnEnable()
    {
        for (int i = 0; i < sceneLights.Length; i++)
        {
            if (sceneLights[i] != null)
            {
                sceneLights[i].enabled = true;
            }
        }
    }

    void OnDisable()
    {
        // OnDisable is called immediately after OnEnable in the pulse pattern above.
        // Use a separate relay GameObject for each signal direction to keep concerns clear.
    }
}
```

**When to prefer this over EventBus:**
- Very simple one-shot signals where subscriber registration overhead is unnecessary
- Signals that must persist across scene loads (relay GameObject survives)
- Visual debugging: relay active state is visible in the Hierarchy

---

## Delayed Event Debounce

### Problem

`SendCustomEventDelayedSeconds` schedules a future event, but there is no cancellation API. If the same event is scheduled multiple times in quick succession (e.g., a rapid button tap), all enqueued callbacks fire.

### Solution

Use an integer generation counter. Each new schedule increments the counter and captures the current value. The callback checks whether the counter has advanced; if so, a newer schedule exists and this invocation is a no-op.

```csharp
public class DebouncedSearch : UdonSharpBehaviour
{
    [SerializeField] private float debounceDelay = 0.5f;

    // Monotonically increasing; each new schedule captures the current value.
    private int _scheduleGeneration = 0;

    /// <summary>
    /// Call this whenever input changes. Only the callback scheduled after the
    /// last call within debounceDelay seconds will actually execute.
    /// </summary>
    public void OnInputChanged()
    {
        _scheduleGeneration++;
        // Pass the current generation as a serialized field so the callback can read it.
        // UdonSharp does not support lambda captures, so store in a member variable.
        _pendingGeneration = _scheduleGeneration;
        SendCustomEventDelayedSeconds(nameof(ExecuteSearch), debounceDelay);
    }

    // Captured generation for the most recently scheduled callback.
    private int _pendingGeneration = 0;

    public void ExecuteSearch()
    {
        // If _scheduleGeneration has moved past _pendingGeneration, a newer
        // schedule supersedes this one — bail out.
        if (_scheduleGeneration != _pendingGeneration) return;

        // Safe to execute: this is the most recent scheduled callback.
        PerformSearch();
    }

    private void PerformSearch()
    {
        Debug.Log("Executing debounced search");
        // ... actual search logic
    }
}
```

> **Note:** This pattern ensures only the *last* scheduled event executes. It does not prevent intermediate callbacks from running their guard check — it only makes them return immediately.

---

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

- [networking.md](networking.md) - Ownership model, sync modes, and `RequestSerialization` details
- [api.md](api.md) - `VRCPlayerApi`, `Networking`, and `VRCObjectPool` API reference
- [troubleshooting.md](troubleshooting.md) - Solutions for common pitfalls seen in these patterns
