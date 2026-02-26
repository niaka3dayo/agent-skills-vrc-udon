# UdonSharp イベントリファレンス

Complete reference of all events available in UdonSharp. Override these methods to respond to events.

**対応SDKバージョン**: 3.7.1 - 3.10.1 (2026年2月時点)

## 重要: override と Non-override

UdonSharp のイベントには **override が必要なもの** と **不要なもの** がある。間違えるとコンパイルエラー (CS0115) になる。

### override 必須 (VRChat/Udon 固有イベント)

`OnPlayerJoined`, `OnPlayerLeft`, `OnPlayerRespawn`, `OnDeserialization`, `OnPreSerialization`, `OnPostSerialization`, `OnOwnershipTransferred`, `Interact`, `OnPickup`, `OnDrop`, `OnPickupUseDown`, `OnPickupUseUp`, `OnPlayerTriggerEnter/Stay/Exit`, `OnPlayerCollisionEnter/Stay/Exit`, `OnPlayerParticleCollision`, `OnStationEntered/Exited`, `OnPlayerRestored`, `OnContactEnter/Stay/Exit`, `OnPhysBoneGrab/Release`, `InputJump`, `InputUse`, `InputGrab`, `InputDrop`, `InputMoveHorizontal/Vertical`, `InputLookHorizontal/Vertical`, `MidiNoteOn/Off`, `MidiControlChange`, `OnVideo*`, `OnStringLoad*`, `OnImageLoad*`

### override 不要 (Unity 標準コールバック)

`Start`, `Update`, `LateUpdate`, `FixedUpdate`, `OnEnable`, `OnDisable`, `OnDestroy`, `OnTriggerEnter/Stay/Exit`, `OnCollisionEnter/Stay/Exit`, `OnAnimatorMove`, `OnAnimatorIK`, `OnWillRenderObject`, `OnBecameVisible/Invisible`

```csharp
// NG: CS0115 エラー
public override void OnTriggerEnter(Collider other) { }
// OK
public void OnTriggerEnter(Collider other) { }

// OK: VRChat イベントは override 必須
public override void OnPlayerJoined(VRCPlayerApi player) { }
```

---

## Update イベント

毎フレームまたは物理ティックごとに呼び出される。

| イベント | 呼び出しタイミング |
|-------|-------------|
| `void Update()` | Every frame |
| `void LateUpdate()` | After all Update calls |
| `void FixedUpdate()` | Every physics tick (~50Hz) |
| `void PostLateUpdate()` | After LateUpdate (VRChat-specific) |

```csharp
void Update()
{
    // Called every frame
    transform.Rotate(Vector3.up, rotationSpeed * Time.deltaTime);
}

void FixedUpdate()
{
    // Called at fixed intervals for physics
    rb.AddForce(Vector3.up * force);
}
```

## Input イベント

VRChat 固有の入力イベント。プレイヤーがボタンを押す/離すときに呼び出される。

### アクションイベント

| イベント | 呼び出しタイミング |
|-------|-------------|
| `InputJump(bool value, UdonInputEventArgs args)` | Jump button |
| `InputUse(bool value, UdonInputEventArgs args)` | Use/Interact button |
| `InputGrab(bool value, UdonInputEventArgs args)` | Grab button |
| `InputDrop(bool value, UdonInputEventArgs args)` | Drop button |

### 移動イベント

| イベント | 呼び出しタイミング |
|-------|-------------|
| `InputMoveHorizontal(float value, UdonInputEventArgs args)` | Left/right movement |
| `InputMoveVertical(float value, UdonInputEventArgs args)` | Forward/back movement |
| `InputLookHorizontal(float value, UdonInputEventArgs args)` | Look left/right |
| `InputLookVertical(float value, UdonInputEventArgs args)` | Look up/down |

```csharp
public override void InputJump(bool value, VRC.Udon.Common.UdonInputEventArgs args)
{
    if (value) // Button pressed (not released)
    {
        Debug.Log("Jump pressed!");
    }
}

public override void InputMoveHorizontal(float value, VRC.Udon.Common.UdonInputEventArgs args)
{
    // value is -1 to 1
    Debug.Log($"Horizontal input: {value}");
}
```

## Interact イベント

プレイヤーがオブジェクトとインタラクトしたときに呼び出される（コライダーが必要）。

```csharp
public override void Interact()
{
    Debug.Log($"{Networking.LocalPlayer.displayName} interacted with this!");
}
```

**Requirements:**
- GameObject must have a Collider
- Collider must NOT be set to "Is Trigger" (for default interact)
- Set "Interact Text" in UdonBehaviour component to customize prompt

## Pickup イベント

VRC_Pickup コンポーネントを持つオブジェクトで呼び出される。

| イベント | 呼び出しタイミング |
|-------|-------------|
| `void OnPickup()` | When picked up |
| `void OnDrop()` | When dropped |
| `void OnPickupUseDown()` | When use button pressed while holding |
| `void OnPickupUseUp()` | When use button released while holding |

```csharp
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
    // Fire weapon, activate tool, etc.
    DoAction();
}

public override void OnPickupUseUp()
{
    // Release trigger, stop action
    StopAction();
}
```

## Player イベント

プレイヤーの参加・退出・状態変更時に呼び出される。

| イベント | 呼び出しタイミング |
|-------|-------------|
| `void OnPlayerJoined(VRCPlayerApi player)` | Player joins instance |
| `void OnPlayerLeft(VRCPlayerApi player)` | Player leaves instance |
| `void OnPlayerRespawn(VRCPlayerApi player)` | Player respawns |

```csharp
public override void OnPlayerJoined(VRCPlayerApi player)
{
    Debug.Log($"{player.displayName} joined!");

    // Sync state for new player if we own the object
    if (Networking.IsOwner(gameObject))
    {
        RequestSerialization();
    }
}

public override void OnPlayerLeft(VRCPlayerApi player)
{
    Debug.Log($"{player.displayName} left!");
    // Clean up player-specific data
}
```

## Persistence イベント (SDK 3.7.4+)

PlayerData の永続化操作で呼び出される。

| イベント | 呼び出しタイミング |
|-------|-------------|
| `void OnPlayerRestored(VRCPlayerApi player)` | Player's saved data has been loaded |
| `void OnPlayerDataUpdated(VRCPlayerApi player, PlayerData.Info[] infos)` | PlayerData was updated |

```csharp
public override void OnPlayerRestored(VRCPlayerApi player)
{
    if (!player.isLocal) return;

    Debug.Log($"{player.displayName}'s data restored!");

    // PlayerDataにアクセスして保存されたデータを読み込む
    if (PlayerData.TryGetInt(player, "highScore", out int score))
    {
        highScoreDisplay.text = $"High Score: {score}";
    }
}
```

**Important:** `OnPlayerRestored` が呼ばれるまで PlayerData にアクセスしてはいけません。

## VRChat Dynamics イベント (SDK 3.10.0+)

ワールド内の PhysBones と Contacts で呼び出される。

### Contact イベント

| イベント | 呼び出しタイミング |
|-------|-------------|
| `void OnContactEnter(ContactEnterInfo info)` | Contact sender starts contacting receiver |
| `void OnContactStay(ContactStayInfo info)` | Contact ongoing |
| `void OnContactExit(ContactExitInfo info)` | Contact ends |

```csharp
public override void OnContactEnter(ContactEnterInfo info)
{
    Debug.Log($"Contact from: {info.senderName}");

    // アバターからのコンタクトかワールドからか判定
    if (info.isAvatar)
    {
        // アバターからのコンタクト
        VRCPlayerApi player = info.player;
        if (player != null && player.IsValid())
        {
            Debug.Log($"Touched by: {player.displayName}");
        }
    }
    else
    {
        // ワールドオブジェクトからのコンタクト
        Debug.Log("Touched by world object");
    }
}

public override void OnContactExit(ContactExitInfo info)
{
    Debug.Log($"Contact ended: {info.senderName}");
}
```

### PhysBones イベント

| イベント | 呼び出しタイミング |
|-------|-------------|
| `void OnPhysBoneGrab(PhysBoneGrabInfo info)` | PhysBone grabbed |
| `void OnPhysBoneRelease(PhysBoneReleaseInfo info)` | PhysBone released |

```csharp
public override void OnPhysBoneGrab(PhysBoneGrabInfo info)
{
    Debug.Log($"PhysBone grabbed by {info.player?.displayName}");
}

public override void OnPhysBoneRelease(PhysBoneReleaseInfo info)
{
    Debug.Log($"PhysBone released");
}
```

**Note:** Contact/PhysBone events are triggered on all UdonBehaviours attached to the same GameObject as the receiver.

## Player Trigger/Collision イベント

プレイヤーがトリガーに出入りしたり衝突したときに呼び出される。

### Trigger イベント

| イベント | 呼び出しタイミング |
|-------|-------------|
| `void OnPlayerTriggerEnter(VRCPlayerApi player)` | Player enters trigger |
| `void OnPlayerTriggerStay(VRCPlayerApi player)` | Player stays in trigger |
| `void OnPlayerTriggerExit(VRCPlayerApi player)` | Player exits trigger |

### Collision イベント

| イベント | 呼び出しタイミング |
|-------|-------------|
| `void OnPlayerCollisionEnter(VRCPlayerApi player)` | Player collision starts |
| `void OnPlayerCollisionStay(VRCPlayerApi player)` | Player collision ongoing |
| `void OnPlayerCollisionExit(VRCPlayerApi player)` | Player collision ends |

### Particle Collision イベント

| イベント | 呼び出しタイミング |
|-------|-------------|
| `void OnPlayerParticleCollision(VRCPlayerApi player)` | Particle hits player |

```csharp
public override void OnPlayerTriggerEnter(VRCPlayerApi player)
{
    if (player.isLocal)
    {
        // Only affect local player
        ShowWelcomeMessage();
    }
}
```

**Requirements:**
- GameObject must have Collider with "Is Trigger" checked
- For collision events, Collider must NOT be trigger

## Networking イベント

同期とオーナーシップ変更時に呼び出される。

| イベント | 呼び出しタイミング |
|-------|-------------|
| `void OnPreSerialization()` | Before data is serialized (owner only) |
| `void OnDeserialization()` | After receiving synced data |
| `void OnDeserialization(DeserializationResult result)` | With result info |
| `void OnPostSerialization(SerializationResult result)` | After serialization complete |
| `void OnOwnershipTransferred(VRCPlayerApi player)` | Ownership changed |
| `void OnOwnershipRequest(VRCPlayerApi requestingPlayer, VRCPlayerApi requestedOwner)` | Ownership requested |

```csharp
public override void OnPreSerialization()
{
    // Prepare data before sending (owner only)
    // Good place to pack data or update timestamps
}

public override void OnDeserialization()
{
    // Data received from owner
    UpdateDisplay();
}

public override void OnPostSerialization(SerializationResult result)
{
    if (!result.success)
    {
        Debug.LogError($"Serialization failed!");
    }
    Debug.Log($"Sent {result.byteCount} bytes");
}

public override void OnOwnershipTransferred(VRCPlayerApi player)
{
    Debug.Log($"New owner: {player.displayName}");
    
    if (player.isLocal)
    {
        // We are now the owner
        OnBecameOwner();
    }
}
```

## Station イベント

プレイヤーが VRCStation（座席、乗り物）に乗り降りしたときに呼び出される。

| イベント | 呼び出しタイミング |
|-------|-------------|
| `void OnStationEntered(VRCPlayerApi player)` | Player sat down |
| `void OnStationExited(VRCPlayerApi player)` | Player stood up |

```csharp
public override void OnStationEntered(VRCPlayerApi player)
{
    Debug.Log($"{player.displayName} sat down");
    
    if (player.isLocal)
    {
        // Start vehicle controls
        EnableVehicleControls();
    }
}

public override void OnStationExited(VRCPlayerApi player)
{
    if (player.isLocal)
    {
        DisableVehicleControls();
    }
}
```

## Video Player イベント

VRCUnityVideoPlayer または AVProVideoPlayer によって呼び出される。

| イベント | 呼び出しタイミング |
|-------|-------------|
| `void OnVideoStart()` | Video starts playing |
| `void OnVideoEnd()` | Video ends |
| `void OnVideoPause()` | Video paused |
| `void OnVideoPlay()` | Video resumed |
| `void OnVideoReady()` | Video loaded and ready |
| `void OnVideoError(VideoError error)` | Error occurred |
| `void OnVideoLoop()` | Video looped |

```csharp
public override void OnVideoReady()
{
    Debug.Log("Video ready to play");
}

public override void OnVideoError(VideoError videoError)
{
    Debug.LogError($"Video error: {videoError}");
}
```

## String/Image Loading イベント

VRCStringDownloader または VRCImageDownloader リクエスト後に呼び出される。
API 詳細・制約・実用パターンは `references/web-loading.md` を参照。

| イベント | 呼び出しタイミング |
|-------|-------------|
| `void OnStringLoadSuccess(IVRCStringDownload result)` | String download succeeded |
| `void OnStringLoadError(IVRCStringDownload result)` | String download failed |
| `void OnImageLoadSuccess(IVRCImageDownload result)` | Image download succeeded |
| `void OnImageLoadError(IVRCImageDownload result)` | Image download failed |

**IVRCStringDownload**: `Result` (string), `ResultBytes` (byte[]), `Error` (string), `ErrorCode` (int), `Url` (VRCUrl)

**IVRCImageDownload**: `Result` (Texture2D), `SizeInMemoryBytes` (int), `Error` (string), `ErrorCode` (int), `Material`, `TextureInfo`

```csharp
public override void OnStringLoadSuccess(IVRCStringDownload result)
{
    string data = result.Result;
    Debug.Log($"Downloaded: {data}");
}

public override void OnStringLoadError(IVRCStringDownload result)
{
    Debug.LogError($"Download failed ({result.ErrorCode}): {result.Error}");
}
```

## MIDI イベント

MIDI 入力を受信したときに呼び出される（PC のみ）。

| イベント | 呼び出しタイミング |
|-------|-------------|
| `void MidiNoteOn(int channel, int note, int velocity)` | Note pressed |
| `void MidiNoteOff(int channel, int note, int velocity)` | Note released |
| `void MidiControlChange(int channel, int number, int value)` | Control changed |

```csharp
public override void MidiNoteOn(int channel, int note, int velocity)
{
    Debug.Log($"Note on: channel={channel}, note={note}, velocity={velocity}");
    PlayNote(note, velocity / 127f);
}
```

## Unity 標準イベント

UdonSharp で動作する Unity 標準イベント。

### ライフサイクル

| イベント | 呼び出しタイミング |
|-------|-------------|
| `void Start()` | First frame (after all Awake) |
| `void OnEnable()` | When enabled |
| `void OnDisable()` | When disabled |
| `void OnDestroy()` | When destroyed |

### 物理演算

| イベント | 呼び出しタイミング |
|-------|-------------|
| `void OnTriggerEnter(Collider other)` | Object enters trigger |
| `void OnTriggerStay(Collider other)` | Object stays in trigger |
| `void OnTriggerExit(Collider other)` | Object exits trigger |
| `void OnCollisionEnter(Collision collision)` | Collision starts |
| `void OnCollisionStay(Collision collision)` | Collision ongoing |
| `void OnCollisionExit(Collision collision)` | Collision ends |

### レンダリング

| イベント | 呼び出しタイミング |
|-------|-------------|
| `void OnWillRenderObject()` | Before rendering |
| `void OnBecameVisible()` | Became visible to camera |
| `void OnBecameInvisible()` | No longer visible |

### アニメーション

| イベント | 呼び出しタイミング |
|-------|-------------|
| `void OnAnimatorMove()` | Animator root motion update |
| `void OnAnimatorIK(int layerIndex)` | IK pass |

```csharp
void Start()
{
    // Initialize after all Awake calls
    InitializeComponents();
}

void OnTriggerEnter(Collider other)
{
    // Non-player object entered trigger
    if (other.CompareTag("Projectile"))
    {
        TakeDamage();
    }
}
```

## イベント実行順序

1. `Awake()` - Not available in UdonSharp
2. `OnEnable()`
3. `Start()` - First frame
4. `FixedUpdate()` - Physics tick
5. `Update()` - Every frame
6. `LateUpdate()` - After all Updates
7. `PostLateUpdate()` - VRChat-specific, after LateUpdate

**Networking events** can occur at any time between frames.

## ベストプラクティス

### プレイヤーの有効性チェック

```csharp
public override void OnPlayerTriggerEnter(VRCPlayerApi player)
{
    if (player == null || !player.IsValid())
    {
        return;
    }
    // Safe to use player
}
```

### ローカル vs 全プレイヤー

```csharp
public override void OnPlayerJoined(VRCPlayerApi player)
{
    // This runs for ALL players in the instance
    
    if (player.isLocal)
    {
        // Only runs for the joining player themselves
        ShowTutorial();
    }
}
```

### 同期前のオーナーシップチェック

```csharp
public override void OnPlayerJoined(VRCPlayerApi player)
{
    // Only owner should trigger sync for late joiners
    if (Networking.IsOwner(gameObject))
    {
        RequestSerialization();
    }
}
```
