# VRChat Dynamics for Worlds Reference

Comprehensive guide to PhysBones, Contacts, and VRC Constraints in VRChat worlds (SDK 3.10.0+).

**Supported SDK Versions**: 3.10.0+ (2025 onward)

## Overview

SDK 3.10.0 made **VRChat Dynamics** available in worlds:

| Component | Purpose | Use Cases |
|-----------|---------|-----------|
| **PhysBones** | Physics-based bone animation | Ropes, chains, flags, interactive objects |
| **Contacts** | Collision detection system | Buttons, triggers, touch interaction |
| **VRC Constraints** | Constraint system | Rigging, following, look-at |

## Contacts

### Basic Concept

Contacts provide a collision detection system between **Senders** and **Receivers**:

- **Contact Sender**: Emits contact signals (like a finger or projectile)
- **Contact Receiver**: Detects contact signals and triggers Udon events

### Contacts Setup

#### Contact Sender

1. Add `VRC Contact Sender` component to a GameObject
2. Configure `Radius` (collision size)
3. Set `Content Type` (identifies what kind of contact this is)

```
VRC Contact Sender
├── Radius: 0.02 (finger-sized)
├── Content Type: "Finger"
└── Shape: Sphere
```

#### Contact Receiver

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

### Contact Events

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

### ContactEnterInfo Struct

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

### Dynamic Content Types

> **Breaking Change (SDK 3.10.1)**: The signature of `VRCContactReceiver.UpdateContentTypes()` changed from `IEnumerable<string>` to **`string[]`**. If you were passing `List<string>` directly, you would need `.ToArray()`, but since `List<T>` is not available in UdonSharp, the correct pattern is to pass `string[]` directly as shown below.

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
        receiver.UpdateContentTypes(types); // Pass string[] directly
    }

    public void EnableAll()
    {
        // Respond to any contact
        string[] types = new string[] { "Hand", "Finger", "Head", "Foot", "Custom" };
        receiver.UpdateContentTypes(types);
    }
}
```

### Contact Sender Control from Udon

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

### Basic Concept

PhysBones provide physics-based bone animation:

- Simulate gravity, wind, and inertia on bones
- Support **grabbing** interaction
- Can be used for ropes, chains, hair, cloth

### PhysBones Setup

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

### PhysBone Events

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
physBone.ForceReleaseGrab();  // Force release the grab
physBone.ForceReleasePose();  // Force release the pose (reset bent PhysBone)
```

### PhysBone Dependency Sorting (SDK 3.8.0+)

Since SDK 3.8.0, PhysBone components are **automatically sorted based on dependencies**. PhysBone chains with parent-child relationships are evaluated in the correct order, resolving the unstable behavior seen in previous versions.

### Instantiated PhysBones (Caution)

PhysBones contained in objects created with `Instantiate()` **may not be network-synced**. Place objects that use PhysBones directly in the scene, or use VRChat Object Pool.

## VRC Constraints

### Basic Concept

VRC Constraints replace Unity's built-in Constraints with a VRChat-optimized version:

| Constraint | Purpose |
|------------|---------|
| **Position Constraint** | Follow position of target(s) |
| **Rotation Constraint** | Follow rotation of target(s) |
| **Scale Constraint** | Follow scale of target(s) |
| **Parent Constraint** | Follow position and rotation (like parenting) |
| **Aim Constraint** | Point at target |
| **Look At Constraint** | Look at target (optimized for eyes) |

### Constraints Setup

```
VRC Position Constraint
├── Sources: [Transform1 (weight 0.5), Transform2 (weight 0.5)]
├── Constraint Active: true
├── Lock: X, Y, Z
└── At Rest: (0, 0, 0)
```

### Accessing Constraints from Udon

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

### VRC Constraints vs Unity Constraints

VRChat provides its own constraint components that replace Unity's built-in constraints. **Unity Constraints are disabled on Quest/Android**, making VRC Constraints the only cross-platform option.

#### Comparison Table

| Feature | VRC Constraints | Unity Constraints |
|---------|----------------|-------------------|
| **Quest/Android** | Supported | Disabled |
| **PC** | Supported | Supported |
| **Network sync** | Integrated with VRChat networking | No network awareness |
| **Performance** | Optimized for VRChat | Standard Unity performance |
| **Udon API access** | Full (`IsActive`, `SetSourceWeight`, etc.) | Limited |
| **PhysBone compatibility** | Full | Not guaranteed |
| **Dependency sorting** | Automatic (SDK 3.8.0+) | Manual |

#### Formal Component Names

When referencing VRC Constraints in code or Inspector, use the exact component names:

| VRC Constraint | Unity Equivalent | Namespace |
|----------------|-----------------|-----------|
| `VRCPositionConstraint` | `PositionConstraint` | `VRC.SDK3.Dynamics.Constraint.Components` |
| `VRCRotationConstraint` | `RotationConstraint` | `VRC.SDK3.Dynamics.Constraint.Components` |
| `VRCScaleConstraint` | `ScaleConstraint` | `VRC.SDK3.Dynamics.Constraint.Components` |
| `VRCParentConstraint` | `ParentConstraint` | `VRC.SDK3.Dynamics.Constraint.Components` |
| `VRCAimConstraint` | `AimConstraint` | `VRC.SDK3.Dynamics.Constraint.Components` |
| `VRCLookAtConstraint` | `LookAtConstraint` | `VRC.SDK3.Dynamics.Constraint.Components` |

```csharp
using VRC.SDK3.Dynamics.Constraint.Components;

// Correct: Use VRC Constraint components
public VRCParentConstraint parentConstraint;
public VRCPositionConstraint positionConstraint;
public VRCRotationConstraint rotationConstraint;

// Wrong: Unity constraints are disabled on Quest
// public UnityEngine.Animations.ParentConstraint parentConstraint;
```

#### Decision Guide

| Scenario | Recommendation |
|----------|---------------|
| World targets PC + Quest | **VRC Constraints** (mandatory) |
| World targets PC only | VRC Constraints preferred (future-proof) |
| Need Udon API control | **VRC Constraints** (better API) |
| Migrating from Unity Constraints | Replace with VRC equivalents |
| Avatar constraints | Follow VRChat avatar documentation |

## Common Patterns

### Interactive Button with Feedback

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

### Grabbable Lever

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

### Touch-Sensitive Surface

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

## Important Notes

### Avatar vs World Contacts

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

### Performance Considerations

| Tip | Description |
|-----|-------------|
| Limit PhysBones | Each PhysBone chain has CPU cost |
| Minimize receivers | Only add where needed |
| Use appropriate radii | Larger = more collision checks |
| Disable when not needed | Disable components when inactive |

### Debugging

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

## Best Practices

1. **Test with multiple players** - Contacts behave differently with network latency
2. **Use appropriate content types** - Be specific to avoid unwanted triggers
3. **Handle null players** - `info.player` can be null for world objects
4. **Sync state, not events** - Use `[UdonSynced]` for persistent state
5. **Debounce rapid contacts** - Add cooldown to prevent spam
6. **Clean up on player leave** - Reset state in `OnPlayerLeft`
