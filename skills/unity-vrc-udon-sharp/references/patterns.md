# UdonSharp 共通パターン

Ready-to-use code patterns for VRChat world development.

## 初期化パターン

VRChatワールドでは、ギミックが**非アクティブ状態で配置**されることが多い（パフォーマンス最適化、条件付き表示など）。`Start()` は GameObjectがアクティブでないと呼ばれないため、初期化処理には注意が必要。

### 問題: Start() が呼ばれない

```csharp
// ❌ BAD: 非アクティブ状態で配置されるとStart()が呼ばれない
public class BrokenGimmick : UdonSharpBehaviour
{
    private AudioSource audioSource;

    void Start()
    {
        // GameObjectが非アクティブだと、ここに到達しない！
        audioSource = GetComponent<AudioSource>();
    }

    public void PlaySound()
    {
        audioSource.Play(); // NullReferenceException!
    }
}
```

### 解決策: 分離された Initialize メソッド

```csharp
// ✅ GOOD: OnEnable + 初期化フラグパターン
public class RobustGimmick : UdonSharpBehaviour
{
    [Header("References")]
    [SerializeField] private AudioSource audioSource;

    private bool _initialized = false;

    void OnEnable()
    {
        // 非アクティブ→アクティブ時に呼ばれる
        Initialize();
    }

    void Start()
    {
        // 最初からアクティブな場合はこちらで初期化
        Initialize();
    }

    private void Initialize()
    {
        if (_initialized) return;
        _initialized = true;

        // SerializeFieldで設定されていない場合のフォールバック
        if (audioSource == null)
        {
            audioSource = GetComponent<AudioSource>();
        }
    }

    public void PlaySound()
    {
        Initialize(); // 外部から先に呼ばれる可能性に備える
        if (audioSource != null)
        {
            audioSource.Play();
        }
    }
}
```

### 完全パターン: 防御的初期化

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
        // 初期状態を適用（Late Joiner対応にも使える）
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

### 各アプローチの使い分け

| シナリオ | 推奨パターン |
|----------|--------------|
| 常にアクティブなオブジェクト | `Start()` のみでOK |
| 非アクティブで配置される可能性 | `OnEnable()` + `Initialize()` パターン |
| 外部から先に呼ばれる可能性 | Public メソッド内でも `Initialize()` 呼び出し |
| Synced変数との組み合わせ | `OnDeserialization()` でも `Initialize()` 呼び出し |

### 同期変数との組み合わせ

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
            Initialize(); // Sync受信時も初期化を保証
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
        Initialize(); // Late Joiner対応
        ApplyState();
    }
}
```

---

## インタラクションパターン

### 基本的なボタン

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

### クールダウン付きボタン

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

### トグルスイッチ (同期)

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

## プレイヤー検知

### トリガーゾーン

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

### プレイヤーカウンター表示

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

### 範囲内の全プレイヤー取得

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

## タイマーパターン

### シンプルタイマー

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

### 遅延アクション (コルーチンなし)

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

### 繰り返しアクション

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

## オーディオパターン

### シンプルオーディオプレイヤー

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

### 同期ミュージックプレイヤー

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

## Pickup パターン

### 基本的な Pickup とイベント

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

### 投げられるオブジェクト

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

## アニメーションパターン

### シンプルなアニメーター制御

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

### 同期アニメーション状態

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

## UI パターン

### ボタン配列ハンドラー

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

### スライダー値表示

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

## ユーティリティパターン

### オブジェクトプーリング (シンプル)

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

### 配列ヘルパー

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

## テレポーテーション

### シンプルテレポーター

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

### マルチ目的地テレポーター

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

## パフォーマンスパターン

### クラス間呼び出しのオーバーヘッド

In Udon, calling methods on other UdonBehaviours has significant overhead (~1.5x slower than same-class calls). This creates a dilemma:

- **Good design** suggests splitting responsibilities across classes
- **Performance** suggests keeping everything in one class

Two patterns help resolve this: **Partial Classes** and **Update Handler Pattern**.

### Partial クラスパターン

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

### Update ハンドラーパターン

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

### 両パターンの組み合わせ

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

## NetworkCallable パターン (SDK 3.8.1+)

### 基本的なパラメータ付き RPC

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

### NetworkCallable によるダメージシステム

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

### チャットシステム

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

## Persistence パターン (SDK 3.7.4+)

### 設定マネージャー

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

### アンロックシステム

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

## Dynamics パターン (SDK 3.10.0+)

### インタラクティブボタン

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

### タッチピアノ

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

### 掴めるロープ (物理演算)

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

## 同期ゲーム状態管理

### 履歴/Undo の同期パターン

ゲームで Undo 機能を実装する場合、**履歴は synced 変数として全員で共有**する。
初期状態 = 履歴の 0 番目として保存し、リセット時は履歴 0 に戻す（別変数で初期状態を二重管理しない）。

**注意点:**
- **1回の論理操作 = 1回の履歴保存** (送信側と受信側で2回保存しない)
- 操作**前**ではなく操作**後**の状態を保存
- 履歴保存は Owner 側の操作処理メソッド内でのみ行う

```csharp
[UdonBehaviourSyncMode(BehaviourSyncMode.Manual)]
public class UndoableGameManager : UdonSharpBehaviour
{
    // --- 同期データ ---
    [UdonSynced] private byte[] currentState;     // 現在のゲーム状態
    [UdonSynced] private byte[] stateHistory;     // 全履歴 (フラット配列)
    [UdonSynced] private int historyCount;        // 保存済み履歴数
    private int stateSize;                        // 1状態あたりのサイズ

    void Start()
    {
        stateSize = 40; // 例: ボトル40本分
        currentState = new byte[stateSize];
        stateHistory = new byte[stateSize * 100]; // 最大100手
        InitializeGame();
        SaveStateToHistory(); // 初期状態 = 履歴[0]
    }

    // --- Owner のみ: 操作処理 ---
    [NetworkCallable]
    public void OwnerProcessMove(int from, int to, int playerId)
    {
        // バリデーション省略
        ExecuteMove(from, to);
        SaveStateToHistory(); // 操作後に1回だけ保存
        RequestSerialization();
    }

    // --- 履歴管理 ---
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
        if (historyCount <= 1) return; // 初期状態より前には戻れない
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
        // 履歴[0] = 初期状態に戻す (別変数で初期状態を保持しない)
        System.Array.Copy(stateHistory, 0, currentState, 0, stateSize);
        historyCount = 1;
        RequestSerialization();
    }

    // --- 全クライアント: 表示更新 ---
    public override void OnDeserialization()
    {
        // OnDeserialization で履歴を追加しない！(二重保存になる)
        UpdateDisplay();
    }

    private void InitializeGame() { /* currentState を初期化 */ }
    private void ExecuteMove(int from, int to) { /* currentState を変更 */ }
    private void UpdateDisplay() { /* currentState を UI に反映 */ }
}
```

**よくある間違い:**

| 間違い | 問題 | 正しい方法 |
|--------|------|-----------|
| OnDeserialization で履歴保存 | 送信側+受信側で2重保存 | Owner の操作メソッド内でのみ保存 |
| 初期状態を別変数で管理 | リセット時に不整合 | 履歴[0] = 初期状態 |
| 操作前の状態を保存 | Undo で1つ前でなく2つ前に戻る | 操作後の状態を保存 |
| 履歴を synced にしない | Undo 結果がプレイヤー間で不一致 | 履歴は synced 変数で全員共有 |
