# VRChat Dynamics for Worlds リファレンス

Comprehensive guide to PhysBones, Contacts, and VRC Constraints in VRChat worlds (SDK 3.10.0+).

**対応SDKバージョン**: 3.10.0+ (2025年〜)

## 概要

SDK 3.10.0 で **VRChat Dynamics** がワールドで利用可能になりました:

| コンポーネント | 用途 | ユースケース |
|-----------|---------|-----------|
| **PhysBones** | Physics-based bone animation | Ropes, chains, flags, interactive objects |
| **Contacts** | Collision detection system | Buttons, triggers, touch interaction |
| **VRC Constraints** | Constraint system | Rigging, following, look-at |

## Contacts (コンタクト)

### 基本コンセプト

Contacts は **Sender** と **Receiver** 間の衝突検出システムを提供する:

- **Contact Sender**: Emits contact signals (like a finger or projectile)
- **Contact Receiver**: Detects contact signals and triggers Udon events

### Contacts のセットアップ

#### Contact Sender (送信側)

1. Add `VRC Contact Sender` component to a GameObject
2. Configure `Radius` (collision size)
3. Set `Content Type` (identifies what kind of contact this is)

```
VRC Contact Sender
├── Radius: 0.02 (finger-sized)
├── Content Type: "Finger"
└── Shape: Sphere
```

#### Contact Receiver (受信側)

1. Add `VRC Contact Receiver` component to a GameObject
2. Add UdonBehaviour to the **same** GameObject
3. Configure allowed content types
4. Implement contact events in Udon

```
VRC Contact Receiver
├── Radius: 0.05
├── Allow Self: true (contacts from same avatar)
├── Allow Others: true (contacts from other avatars)
└── Content Types: ["Finger", "Hand"]
```

### Contact イベント

```csharp
using UdonSharp;
using UnityEngine;
using VRC.SDKBase;

public class ContactButton : UdonSharpBehaviour
{
    public AudioSource clickSound;
    public Material normalMaterial;
    public Material pressedMaterial;
    public Renderer buttonRenderer;

    private bool isPressed = false;

    public override void OnContactEnter(ContactEnterInfo info)
    {
        if (isPressed) return;

        isPressed = true;
        buttonRenderer.material = pressedMaterial;
        clickSound.Play();

        // Check if from avatar or world object
        if (info.isAvatar)
        {
            Debug.Log($"Pressed by: {info.player?.displayName}");
        }
        else
        {
            Debug.Log("Pressed by world object");
        }

        // Perform button action
        OnButtonPressed();
    }

    public override void OnContactStay(ContactStayInfo info)
    {
        // Called every frame while contact is maintained
    }

    public override void OnContactExit(ContactExitInfo info)
    {
        isPressed = false;
        buttonRenderer.material = normalMaterial;
    }

    private void OnButtonPressed()
    {
        // Your button logic here
    }
}
```

### ContactEnterInfo 構造体

```csharp
public struct ContactEnterInfo
{
    public string senderName;       // Name of the Contact Sender
    public bool isAvatar;           // True if from avatar, false if from world
    public VRCPlayerApi player;     // Player reference (only valid if isAvatar)
    public Vector3 position;        // World position of contact point
    public Vector3 normal;          // Contact normal direction
}
```

### 動的コンテンツタイプ

> **破壊的変更 (SDK 3.10.1)**: `VRCContactReceiver.UpdateContentTypes()` のシグネチャが `IEnumerable<string>` から **`string[]`** に変更されました。`List<string>` を直接渡していた場合は `.ToArray()` が必要ですが、UdonSharp では `List<T>` が使えないため、以下のように `string[]` を直接渡すのが正しいパターンです。

```csharp
public class DynamicReceiver : UdonSharpBehaviour
{
    private VRCContactReceiver receiver;

    void Start()
    {
        receiver = GetComponent<VRCContactReceiver>();
    }

    public void EnableHandsOnly()
    {
        // Only respond to hand contacts
        string[] types = new string[] { "Hand", "Finger" };
        receiver.UpdateContentTypes(types); // string[] を直接渡す
    }

    public void EnableAll()
    {
        // Respond to any contact
        string[] types = new string[] { "Hand", "Finger", "Head", "Foot", "Custom" };
        receiver.UpdateContentTypes(types);
    }
}
```

### Udon からの Contact Sender 操作

```csharp
public class ProjectileContact : UdonSharpBehaviour
{
    private VRCContactSender sender;

    void Start()
    {
        sender = GetComponent<VRCContactSender>();
    }

    public void Launch()
    {
        // The contact sender will trigger OnContactEnter
        // on any receiver it collides with
        GetComponent<Rigidbody>().AddForce(transform.forward * 10f, ForceMode.Impulse);
    }
}
```

## PhysBones

### 基本コンセプト

PhysBones は物理ベースのボーンアニメーションを提供する:

- Simulate gravity, wind, and inertia on bones
- Support **grabbing** interaction
- Can be used for ropes, chains, hair, cloth

### PhysBones のセットアップ

1. Add `VRC Phys Bone` component to a root bone
2. Configure physics parameters
3. Add UdonBehaviour for grab events (optional)

```
VRC Phys Bone
├── Root Transform: RopeStart
├── End Bone: (auto-detected or manual)
├── Integration Type: Simplified
├── Pull: 0.2
├── Spring: 0.8
├── Gravity: 0.5
└── Grab Movement: 1.0
```

### PhysBone イベント

```csharp
using UdonSharp;
using UnityEngine;
using VRC.SDKBase;

public class GrabbableRope : UdonSharpBehaviour
{
    public AudioSource grabSound;
    public AudioSource releaseSound;

    private VRCPlayerApi currentGrabber;

    public override void OnPhysBoneGrab(PhysBoneGrabInfo info)
    {
        currentGrabber = info.player;
        grabSound.Play();

        if (info.player != null)
        {
            Debug.Log($"Rope grabbed by: {info.player.displayName}");
        }
    }

    public override void OnPhysBoneRelease(PhysBoneReleaseInfo info)
    {
        currentGrabber = null;
        releaseSound.Play();

        Debug.Log("Rope released");
    }

    public bool IsGrabbed()
    {
        VRCPhysBone physBone = GetComponent<VRCPhysBone>();
        return physBone.IsGrabbed();
    }

    public VRCPlayerApi GetGrabber()
    {
        return currentGrabber;
    }
}
```

### PhysBone API

```csharp
VRCPhysBone physBone = GetComponent<VRCPhysBone>();

// Check if grabbed
bool grabbed = physBone.IsGrabbed();

// Get grabbing player
VRCPlayerApi grabber = physBone.GetGrabbingPlayer();

// Get affected transforms
Transform[] bones = physBone.GetAffectedTransforms();

// Force release (SDK 3.10.0+)
physBone.ForceReleaseGrab();  // グラブを強制解除
physBone.ForceReleasePose();  // ポーズを強制解除（曲げたPhysBoneをリセット）
```

### PhysBone 依存関係ソート (SDK 3.8.0+)

SDK 3.8.0 以降、PhysBone コンポーネントは**依存関係に基づいて自動ソート**されます。親子関係を持つ PhysBone チェーンが正しい順序で評価されるため、以前のバージョンで発生していた不安定な挙動が解消されています。

### Instantiated PhysBones (注意)

`Instantiate()` で生成されたオブジェクトに含まれる PhysBone は、**ネットワーク同期されない場合があります**。PhysBone を使うオブジェクトはシーンに直接配置するか、VRChat Object Pool を使用してください。

## VRC Constraints

### 基本コンセプト

VRC Constraints は Unity 組み込みの Constraints を VRChat 最適化バージョンに置き換えたもの:

| Constraint | 用途 |
|------------|---------|
| **Position Constraint** | Follow position of target(s) |
| **Rotation Constraint** | Follow rotation of target(s) |
| **Scale Constraint** | Follow scale of target(s) |
| **Parent Constraint** | Follow position and rotation (like parenting) |
| **Aim Constraint** | Point at target |
| **Look At Constraint** | Look at target (optimized for eyes) |

### Constraints のセットアップ

```
VRC Position Constraint
├── Sources: [Transform1 (weight 0.5), Transform2 (weight 0.5)]
├── Constraint Active: true
├── Lock: X, Y, Z
└── At Rest: (0, 0, 0)
```

### Udon からの Constraints アクセス

```csharp
using UdonSharp;
using UnityEngine;
using VRC.SDK3.Dynamics.Constraint.Components;

public class ConstraintController : UdonSharpBehaviour
{
    public VRCPositionConstraint posConstraint;
    public VRCAimConstraint aimConstraint;

    public void EnableConstraint()
    {
        posConstraint.IsActive = true;
    }

    public void DisableConstraint()
    {
        posConstraint.IsActive = false;
    }

    public void SetWeight(float weight)
    {
        // Set source weight (index 0)
        posConstraint.SetSourceWeight(0, weight);
    }
}
```

## よくあるパターン

### フィードバック付きインタラクティブボタン

```csharp
public class PhysicalButton : UdonSharpBehaviour
{
    [Header("References")]
    public Transform buttonTop;
    public AudioSource pressSound;
    public AudioSource releaseSound;

    [Header("Settings")]
    public float pressDepth = 0.02f;
    public float pressSpeed = 10f;

    [UdonSynced] private bool isPressed = false;
    private Vector3 originalPosition;
    private Vector3 pressedPosition;

    void Start()
    {
        originalPosition = buttonTop.localPosition;
        pressedPosition = originalPosition - new Vector3(0, pressDepth, 0);
    }

    void Update()
    {
        Vector3 target = isPressed ? pressedPosition : originalPosition;
        buttonTop.localPosition = Vector3.Lerp(
            buttonTop.localPosition,
            target,
            Time.deltaTime * pressSpeed
        );
    }

    public override void OnContactEnter(ContactEnterInfo info)
    {
        if (isPressed) return;

        Networking.SetOwner(Networking.LocalPlayer, gameObject);
        isPressed = true;
        RequestSerialization();

        pressSound.Play();
        OnButtonPressed();
    }

    public override void OnContactExit(ContactExitInfo info)
    {
        if (!isPressed) return;

        Networking.SetOwner(Networking.LocalPlayer, gameObject);
        isPressed = false;
        RequestSerialization();

        releaseSound.Play();
    }

    private void OnButtonPressed()
    {
        // Your button action
        SendCustomNetworkEvent(
            VRC.Udon.Common.Interfaces.NetworkEventTarget.All,
            nameof(DoButtonAction)
        );
    }

    public void DoButtonAction()
    {
        Debug.Log("Button action executed!");
    }
}
```

### つかめるレバー

```csharp
public class GrabbableLever : UdonSharpBehaviour
{
    [Header("Settings")]
    public float minAngle = -45f;
    public float maxAngle = 45f;
    public float threshold = 30f;

    [UdonSynced, FieldChangeCallback(nameof(LeverState))]
    private bool _leverState = false;

    public bool LeverState
    {
        get => _leverState;
        set
        {
            _leverState = value;
            OnLeverStateChanged();
        }
    }

    public override void OnPhysBoneGrab(PhysBoneGrabInfo info)
    {
        // Take ownership when grabbed
        Networking.SetOwner(info.player, gameObject);
    }

    void Update()
    {
        // Check lever angle
        float angle = transform.localEulerAngles.x;
        if (angle > 180) angle -= 360;

        bool newState = angle > threshold;

        if (newState != _leverState && Networking.IsOwner(gameObject))
        {
            LeverState = newState;
            RequestSerialization();
        }
    }

    private void OnLeverStateChanged()
    {
        Debug.Log($"Lever is now: {(_leverState ? "ON" : "OFF")}");
    }
}
```

### タッチ感応サーフェス

```csharp
public class TouchSurface : UdonSharpBehaviour
{
    public Material idleMaterial;
    public Material touchMaterial;
    public Renderer surfaceRenderer;

    private int touchCount = 0;

    public override void OnContactEnter(ContactEnterInfo info)
    {
        touchCount++;
        UpdateVisual();

        // Spawn effect at touch point
        SpawnTouchEffect(info.position);
    }

    public override void OnContactExit(ContactExitInfo info)
    {
        touchCount--;
        if (touchCount < 0) touchCount = 0;
        UpdateVisual();
    }

    private void UpdateVisual()
    {
        surfaceRenderer.material = touchCount > 0 ? touchMaterial : idleMaterial;
    }

    private void SpawnTouchEffect(Vector3 position)
    {
        // Spawn particle or visual effect
    }
}
```

## 重要な注意事項

### アバター vs ワールド Contacts

```csharp
public override void OnContactEnter(ContactEnterInfo info)
{
    if (info.isAvatar)
    {
        // Contact from an avatar (player)
        // - "Allow Self" setting applies
        // - "Allow Others" setting applies
        VRCPlayerApi player = info.player;
    }
    else
    {
        // Contact from a world object (VRC Contact Sender in world)
        // - "Allow Self" and "Allow Others" are IGNORED
        // - Always triggers regardless of settings
    }
}
```

### パフォーマンスに関する考慮事項

| ヒント | 説明 |
|-----|-------------|
| Limit PhysBones | Each PhysBone chain has CPU cost |
| Minimize receivers | Only add where needed |
| Use appropriate radii | Larger = more collision checks |
| Disable when not needed | Disable components when inactive |

### デバッグ

```csharp
public class DynamicsDebug : UdonSharpBehaviour
{
    public override void OnContactEnter(ContactEnterInfo info)
    {
        Debug.Log($"[Contact] Enter - Sender: {info.senderName}, " +
                  $"Avatar: {info.isAvatar}, Player: {info.player?.displayName}, " +
                  $"Position: {info.position}");
    }

    public override void OnPhysBoneGrab(PhysBoneGrabInfo info)
    {
        Debug.Log($"[PhysBone] Grab - Player: {info.player?.displayName}, " +
                  $"Bone: {info.bone?.name}");
    }
}
```

## ベストプラクティス

1. **Test with multiple players** - Contacts behave differently with network latency
2. **Use appropriate content types** - Be specific to avoid unwanted triggers
3. **Handle null players** - `info.player` can be null for world objects
4. **Sync state, not events** - Use `[UdonSynced]` for persistent state
5. **Debounce rapid contacts** - Add cooldown to prevent spam
6. **Clean up on player leave** - Reset state in `OnPlayerLeft`
