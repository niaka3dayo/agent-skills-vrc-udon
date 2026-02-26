# VRChat ワールドコンポーネント完全リファレンス

SDK 3.7.1 - 3.10.1 対応の全コンポーネント詳細リファレンス。

## 目次

- [VRC_SceneDescriptor](#vrc_scenedescriptor)
- [VRC_Pickup](#vrc_pickup)
- [VRC_Station](#vrc_station)
- [VRC_ObjectSync](#vrc_objectsync)
- [VRC_MirrorReflection](#vrc_mirrorreflection)
- [VRC_PortalMarker](#vrc_portalmarker)
- [VRC_SpatialAudioSource](#vrc_spatialaudiosource)
- [VRC_UIShape](#vrc_uishape)
- [VRC_AvatarPedestal](#vrc_avatarpedestal)
- [VRC_CameraDolly](#vrc_cameradolly)
- [VRCCameraSettings API](#vrccamerasettings-api)
- [許可済み Unity コンポーネント](#許可済み-unity-コンポーネント)

---

## VRC_SceneDescriptor

**必須**: すべてのVRChatワールドに1つ必要。

### 全プロパティ

| プロパティ | 型 | 説明 | デフォルト |
|-----------|------|------|-----------|
| Spawns | Transform[] | スポーン地点配列 | Descriptor位置 |
| Spawn Order | SpawnOrder | Sequential/Random/Demo | Sequential |
| Respawn Height | float | リスポーンY座標 | -100 |
| Object Behaviour At Respawn | enum | Respawn/Destroy | Respawn |
| Reference Camera | Camera | カメラ設定参照 | None |
| Forbid User Portals | bool | ポータル禁止 | false |
| Voice Falloff Range | float | ボイス減衰範囲 | - |
| Interact Passthrough | LayerMask | インタラクト透過 | Nothing |
| Maximum Capacity | int | 最大人数 | - |
| Recommended Capacity | int | 推奨人数 | - |
| Dynamic Materials | Material[] | 動的マテリアル | - |
| Dynamic Prefabs | GameObject[] | 動的プレハブ | - |

### Spawn Order 詳細

```csharp
// Sequential: 順番にスポーン
// Join順: Player1→Spawn0, Player2→Spawn1, Player3→Spawn2, Player4→Spawn0...

// Random: ランダム選択
// 毎回異なるスポーン地点

// Demo: 全員同じ場所
// 全プレイヤーが Spawns[0] に出現
```

### Reference Camera 設定

```csharp
// 用途:
// 1. Near Clip Plane: VR用 0.01m 推奨
// 2. Far Clip Plane: ワールドサイズに応じて調整
// 3. Post Processing: Profile適用
// 4. Background: Skybox または Solid Color
// 5. Clear Flags: 設定継承

// 設定手順:
// 1. Camera を作成
// 2. 設定を調整
// 3. Camera コンポーネントを無効化
// 4. SceneDescriptor の Reference Camera に割り当て
```

### Capacity の動作

```csharp
// Maximum Capacity:
// - この人数に達すると新規参加不可
// - ハードリミット

// Recommended Capacity:
// - この人数に達するとパブリックリストから非表示
// - ソフトリミット（直接参加は可能）

// 注意: 古いSDKでは Recommended 未設定時、
// 実際の Max = 指定値 × 2 になるバグあり
```

---

## VRC_Pickup

オブジェクトをプレイヤーが持てるようにする。

### 必須セットアップ

```
[Pickup GameObject]
├── Collider (Required)
│   └── IsTrigger = true 推奨
├── Rigidbody (Required)
│   ├── Use Gravity = true/false
│   └── Is Kinematic = false (持つ時)
├── VRC_Pickup
└── VRC_ObjectSync (ネットワーク同期時)
```

### 全プロパティ

| プロパティ | 型 | 説明 | デフォルト |
|-----------|------|------|-----------|
| Interaction Text | string | デスクトップでの表示テキスト | - |
| Use Text | string | VRでの使用テキスト | - |
| Throw Velocity Boost Min Speed | float | ブースト開始速度 | - |
| Throw Velocity Boost Scale | float | 投げ加速倍率 | - |
| Pickupable | bool | 持てるか | true |
| Pickup Orientation | enum | Any/Grip/Gun | Any |
| Allow Theft | bool | 奪取許可 | true |
| Exact Grip | Transform | 正確なグリップ位置 | null |
| Exact Gun | Transform | 正確なガン位置 | null |
| Proximity | float | 拾得可能距離 | 2.0 |
| **Auto Hold** | enum | Yes/No/AutoDetect | No |

### Auto Hold (SDK 3.9+)

```csharp
// v1.0 (旧): AutoDetect / Yes / No
// v1.1 (新): チェックボックス (Yes/No のみ)

// Yes: グリップを離しても持ち続ける
// No: グリップ中のみ保持

// AutoDetect (v1.0のみ):
// オブジェクトサイズから自動判定
```

### Pickup Orientation

```csharp
// Any: 持った位置そのまま
//      小物、ボールなど

// Grip: グリップ位置で持つ
//       ハンドル、工具など

// Gun: 銃持ちポーズ
//      銃、ポインターなど
```

### Udon イベント

```csharp
public class PickupHandler : UdonSharpBehaviour
{
    // 持った時
    public override void OnPickup()
    {
        Debug.Log("Picked up!");
    }

    // 離した時
    public override void OnDrop()
    {
        Debug.Log("Dropped!");
    }

    // トリガー押下 (VR) / 左クリック (Desktop)
    public override void OnPickupUseDown()
    {
        Debug.Log("Use started!");
    }

    // トリガー解放
    public override void OnPickupUseUp()
    {
        Debug.Log("Use ended!");
    }
}
```

### ネットワーク同期

```csharp
// VRC_ObjectSync を追加すると:
// - 位置・回転が自動同期
// - 物理状態が同期
// - 所有権が自動管理

// 所有権の流れ:
// 1. 持つ → ローカルプレイヤーが所有者に
// 2. 離す → 所有権維持
// 3. 他プレイヤーが持つ → 所有権移転
```

---

## VRC_Station

プレイヤーが座れる場所を作成。

### 必須セットアップ

```
[Station GameObject]
├── Collider (Required - Interact用)
└── VRC_Station
    ├── Entry Transform (オプション)
    └── Exit Transform (オプション)
```

### 全プロパティ

| プロパティ | 型 | 説明 | デフォルト |
|-----------|------|------|-----------|
| Player Mobility | enum | Mobile/Immobilize/ImmobilizeForVehicle | Immobilize |
| Can Use Station From Station | bool | Station間移動 | true |
| Animator Controller | AnimatorController | 座りアニメーション | null |
| Disable Station Exit | bool | 退出禁止 | false |
| Seated | bool | 座りアニメーション使用 | true |
| Station Enter Player Location | Transform | 入る位置 | null |
| Station Exit Player Location | Transform | 出る位置 | null |
| Controls Object | Transform | 乗り物制御用 | null |

### Player Mobility

```csharp
// Mobile: 自由に動ける
//         アニメーション付きの立ち位置など

// Immobilize: 完全固定
//             椅子、ベンチなど

// ImmobilizeForVehicle: 乗り物用
//                       プレイヤー視点がStation追従
```

### Udon 制御

```csharp
public class StationController : UdonSharpBehaviour
{
    // プレイヤーを座らせる
    public override void Interact()
    {
        Networking.LocalPlayer.UseAttachedStation();
    }

    // 座った時
    public override void OnStationEntered(VRCPlayerApi player)
    {
        Debug.Log($"{player.displayName} が座りました");
    }

    // 降りた時
    public override void OnStationExited(VRCPlayerApi player)
    {
        Debug.Log($"{player.displayName} が降りました");
    }
}
```

### アバター上の Station ルール

```
⚠️ アバター上の Station には追加制限:
- 最大 6 Station まで
- Station Descriptor (赤いボックス) はアップロード時に有効必須
- Entry/Exit は Station から 2m 以内
- FX レイヤーで有効/無効を制御
```

---

## VRC_ObjectSync

Transform と Rigidbody を自動ネットワーク同期。

### 全プロパティ

| プロパティ | 型 | 説明 | デフォルト |
|-----------|------|------|-----------|
| Allow Collision Ownership Transfer | bool | 衝突でオーナー移転 | false |

### Udon メソッド

```csharp
// VRC_ObjectSync の取得
VRCObjectSync sync = (VRCObjectSync)GetComponent(typeof(VRCObjectSync));

// 初期位置にリセット
sync.Respawn();

// 重力設定
sync.SetGravity(true);

// キネマティック設定
sync.SetKinematic(false);

// 瞬間移動時 (補間をスキップ)
sync.FlagDiscontinuity();

// ネットワーク統計 (デバッグ用)
float updateInterval = sync.UpdateInterval;
float receiveInterval = sync.ReceiveInterval;
```

### 所有権管理

```csharp
// 所有者確認
bool isOwner = Networking.IsOwner(gameObject);

// 所有者取得
VRCPlayerApi owner = Networking.GetOwner(gameObject);

// 所有権移転
Networking.SetOwner(Networking.LocalPlayer, gameObject);

// イベント
public override void OnOwnershipTransferred(VRCPlayerApi player)
{
    Debug.Log($"新しい所有者: {player.displayName}");
}
```

### VRC_ObjectSync vs UdonSynced

| 用途 | VRC_ObjectSync | UdonSynced |
|------|----------------|------------|
| Transform同期 | ✅ 自動 | ❌ 手動実装 |
| Rigidbody同期 | ✅ 自動 | ❌ 手動実装 |
| 状態のみ | ❌ 不要なオーバーヘッド | ✅ 最適 |
| カスタム補間 | ❌ 固定 | ✅ 自由 |
| 帯域制御 | ❌ 自動 | ✅ 細かく制御可能 |

---

## VRC_MirrorReflection

ミラー（鏡）を作成。

### パフォーマンス警告

```
⚠️ 重大なパフォーマンス影響:
- シーン全体を追加レンダリング
- VR: 両目×2 = 4倍レンダリング
- 複数ミラー: 指数的に増加
- 解像度が高いほど負荷増大
```

### ベストプラクティス

```csharp
// 推奨実装:
// 1. デフォルトで OFF
// 2. トグルボタンで有効化
// 3. 距離で自動無効化
// 4. 解像度を適切に設定

public class MirrorController : UdonSharpBehaviour
{
    [SerializeField] private GameObject mirrorObject;
    [SerializeField] private float autoDisableDistance = 10f;

    private VRCPlayerApi _localPlayer;
    private bool _initialized = false;

    void OnEnable() => Initialize();
    void Start() => Initialize();

    private void Initialize()
    {
        if (_initialized) return;
        _initialized = true;

        _localPlayer = Networking.LocalPlayer;
        mirrorObject.SetActive(false);
    }

    public override void Interact()
    {
        Initialize();
        mirrorObject.SetActive(!mirrorObject.activeSelf);
    }

    void Update()
    {
        if (!_initialized || !mirrorObject.activeSelf) return;

        float dist = Vector3.Distance(
            _localPlayer.GetPosition(),
            mirrorObject.transform.position
        );

        if (dist > autoDisableDistance)
        {
            mirrorObject.SetActive(false);
        }
    }
}
```

### シェーダーグローバル変数

```csharp
// ミラー関連のシェーダー変数 (読み取り専用)
// _VRChatCameraMode:
//   0 = 通常レンダリング
//   1 = VR ハンドヘルドカメラ
//   2 = Desktop ハンドヘルドカメラ
//   3 = スクリーンショット

// _VRChatMirrorMode:
//   0 = 通常レンダリング
//   1 = VR ミラー
//   2 = Desktop ミラー

// _VRChatMirrorCameraPos:
//   ミラーカメラのワールド座標
```

---

## VRC_PortalMarker

他のワールドへのポータルを作成。

### セットアップ

```
[Portal GameObject] ← シーン階層のルートに配置
├── VRC_PortalMarker
│   ├── World ID: wrld_xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
│   └── Custom Portal Prefab (オプション)
└── Visual (オプション)
```

### 重要な制限

```
⚠️ ポータルはシーン階層のルートに配置必須
   先行プレイヤーのインスタンス情報が他プレイヤーに同期されるため

⚠️ ワールド ID は VRChat ウェブサイトから取得
   例: wrld_4432ea9b-729c-46e3-8eaf-846aa0a37fdd
```

---

## VRC_SpatialAudioSource

3D空間オーディオを設定。AudioSource に自動追加される。

### 全プロパティ

| プロパティ | 型 | 説明 | デフォルト | 範囲 |
|-----------|------|------|-----------|------|
| Gain | float | 追加ボリューム | 0 dB | 0-24 dB |
| Near | float | 減衰開始距離 | 0 m | - |
| Far | float | 減衰終了距離 | 40 m | - |
| Volumetric Radius | float | 音源サイズ | 0 m | < Far |
| Use AudioSource Volume Curve | bool | カーブ使用 | false | - |
| Enable Spatialization | bool | 3D定位 | true | - |

### 用途別設定

```csharp
// BGM (2D):
// Enable Spatialization = false
// Near = 0, Far = 0

// 環境音 (広い音源):
// Near = 0, Far = 20-40
// Volumetric Radius = 5-10

// 効果音 (点音源):
// Near = 0, Far = 10
// Volumetric Radius = 0

// ボイス風:
// Near = 0, Far = 25
// Gain = 適度に調整
```

### アバター上の制限

```
⚠️ アバター上の AudioSource:
- Gain 上限: 10 dB
- Far 上限: 40 m
- 必ず VRC_SpatialAudioSource を追加すること
  (未追加だとSDKが自動生成し、予期しない動作の原因に)
```

---

## VRC_UIShape

Unity UI (Canvas) との VRChat インタラクションを有効化。

### セットアップ

```
[Canvas GameObject]
├── Canvas (Render Mode: World Space)
├── VRC_UIShape
├── Graphic Raycaster (自動追加)
└── UI Elements (Button, Slider, etc.)
```

### 設定手順

```csharp
// 方法1 (推奨): 自動セットアップ
// 1. UI > TextMeshPro (VRC) を選択
// 2. 自動的に正しい設定が適用される

// 方法2: 手動セットアップ
// 1. Canvas を作成
// 2. Render Mode を "World Space" に変更
// 3. Layer を "Default" に変更 (UI層ではインタラクト不可)
// 4. VRC_UIShape コンポーネントを追加
// 5. スケール調整 (デフォルト 1 = 1ピクセル1メートル)
//    推奨: 0.001 〜 0.005

// 重要:
// - EventSystem をシーンに配置 (削除しない)
// - Canvas の Z軸をプレイヤーから離れる方向に
// - UI要素の Navigation を "None" に設定
```

### TextMeshPro 推奨理由

```
✅ TextMeshPro:
- 高品質なテキストレンダリング
- VR での可読性向上
- スーパーサンプリング対応

❌ Unity Text:
- VR でぼやける
- パフォーマンス劣化
- 品質が低い
```

---

## VRC_AvatarPedestal

アバターを表示し、切り替え可能にする。

### セットアップ

```
[Pedestal GameObject]
├── VRC_AvatarPedestal
│   └── Avatar ID: avtr_xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
└── Display Model (オプション)
```

---

## VRC_CameraDolly

カメラドリーアニメーションを適用 (SDK 3.9+)。

### セットアップ

```
[Dolly Track]
├── VRC_CameraDolly
├── Cinemachine Path / Spline
└── Udon Controller
```

---

## VRCCameraSettings API

カメラ情報を取得 (SDK 3.9+)。

### プロパティ

```csharp
using VRC.SDK3.Rendering;

// 2つのカメラインスタンス
VRCCameraSettings screenCamera = VRCCameraSettings.ScreenCamera;
VRCCameraSettings photoCamera = VRCCameraSettings.PhotoCamera;

// プロパティ
int width = screenCamera.PixelWidth;
int height = screenCamera.PixelHeight;
float fov = screenCamera.FieldOfView;
bool isActive = photoCamera.Active;
```

### イベント

```csharp
public class CameraMonitor : UdonSharpBehaviour
{
    [SerializeField] private TextMeshProUGUI infoText;

    void Start()
    {
        OnVRCCameraSettingsChanged(VRCCameraSettings.ScreenCamera);
    }

    public override void OnVRCCameraSettingsChanged(VRCCameraSettings camera)
    {
        // ハンドヘルドカメラは無視
        if (camera != VRCCameraSettings.ScreenCamera) return;

        infoText.text = $"{camera.PixelWidth}x{camera.PixelHeight}\n" +
                        $"FOV: {camera.FieldOfView}°";
    }
}
```

---

## 許可済み Unity コンポーネント

VRChat で使用可能な Unity 標準コンポーネント。

### 物理

- Rigidbody
- BoxCollider, SphereCollider, CapsuleCollider, MeshCollider
- CharacterJoint, ConfigurableJoint, FixedJoint, HingeJoint, SpringJoint
- ConstantForce
- WheelCollider

### レンダリング

- MeshRenderer, SkinnedMeshRenderer
- MeshFilter
- Camera
- Light
- ReflectionProbe, LightProbeGroup, LightProbeProxyVolume
- LineRenderer, TrailRenderer
- ParticleSystem, ParticleSystemRenderer
- Projector
- Skybox
- LODGroup
- OcclusionArea, OcclusionPortal

### オーディオ

- AudioSource
- AudioReverbZone
- AudioChorusFilter, AudioDistortionFilter, AudioEchoFilter
- AudioHighPassFilter, AudioLowPassFilter, AudioReverbFilter

### UI

- Canvas, CanvasGroup, CanvasRenderer
- RectTransform

### アニメーション

- Animator
- PlayableDirector

### ナビゲーション

- NavMeshAgent
- NavMeshObstacle
- OffMeshLink

### その他

- Transform
- VideoPlayer
- TextMesh (TextMeshPro 推奨)
- Terrain, TerrainCollider
- Cloth
- WindZone
- Grid, GridLayout
- Tilemap, TilemapRenderer

### Quest/Android で無効

```
❌ Dynamic Bones
❌ Cloth (ワールドは可、アバターは不可)
❌ Physics on Avatar (Rigidbody, Collider, Joint)
❌ Cameras on Avatar
❌ Lights on Avatar
❌ Audio Sources on Avatar
❌ Unity Constraints (VRC Constraints 使用)
```
