# VRChat Dynamics for Worlds Reference

Comprehensive guide to PhysBones, Contacts, and VRC Constraints in VRChat worlds (SDK 3.10.0 - 3.10.4).

**Supported SDK Versions**: 3.10.0 - 3.10.4

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
2. Choose `Shape Type`: `Sphere`, `Capsule`, or `Box`
3. Configure `Radius` (and `Height` for Capsule, or `Vector3 size` for Box)
4. Set collision tags (matching tags are reported as `matchingTags`)

```text
VRC Contact Sender (Sphere)
├── Shape Type: Sphere
├── Radius: 0.02 (finger-sized; max 3 m)
└── Collision Tags: ["Finger"]

VRC Contact Sender (Capsule)
├── Shape Type: Capsule
├── Radius: 0.05 (max 3 m)
├── Height: 0.3 (Y-axis, half-spheres included; max 6 m)
└── Collision Tags: ["Custom"]

VRC Contact Sender (Box)
├── Shape Type: Box
├── Size: (0.2, 0.1, 0.05) Vector3 size (max 6 m per axis after scale)
└── Collision Tags: ["Custom"]
```

**Shape comparison:**

| Shape | Fields | Typical use |
|-------|--------|-------------|
| `Sphere` | `Radius` | Point contacts (fingers, small projectiles) |
| `Capsule` | `Radius` + `Height` | Elongated contacts (arms, props, area triggers) |
| `Box` | `Vector3 size` | Flat panels, rectangular trigger volumes, face-proximity surfaces |

#### Contact Receiver

1. Add `VRC Contact Receiver` component to a GameObject
2. Add UdonBehaviour to the **same** GameObject
3. Choose `Shape Type` and configure its dimensions
4. Configure allowed content usage and collision tags
5. Implement contact events in Udon

```text
VRC Contact Receiver (Sphere)
├── Shape Type: Sphere
├── Radius: 0.05 (max 3 m)
├── Content Types: Avatar, World
└── Collision Tags: ["Finger", "Hand"]

VRC Contact Receiver (Capsule)
├── Shape Type: Capsule
├── Radius: 0.05 (max 3 m)
├── Height: 0.5 (Y-axis, half-spheres included; max 6 m)
├── Content Types: Avatar, World
└── Collision Tags: ["Hand"]

VRC Contact Receiver (Box)
├── Shape Type: Box
├── Size: (0.5, 0.1, 0.5) Vector3 size (max 6 m per axis after scale)
├── Use Face Proximity: true (proximity measures toward the positive-Z face)
└── Collision Tags: ["Hand"]
```

### Contact Events

```csharp
using UdonSharp;
using UnityEngine;
using VRC.Dynamics;
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

        ContactSenderProxy sender = info.contactSender;
        if (!sender.isValid) return;

        isPressed = true;
        buttonRenderer.material = pressedMaterial;
        clickSound.Play();

        if (sender.usage == DynamicsUsage.Avatar && sender.player != null && sender.player.IsValid())
        {
            Debug.Log($"Pressed by: {sender.player.displayName}");
        }
        else if (sender.usage == DynamicsUsage.World)
        {
            Debug.Log("Pressed by world contact sender");
        }

        Debug.Log($"Contact point: {info.contactPoint}, velocity: {info.enterVelocity}");

        // Perform button action
        OnButtonPressed();
    }

    public override void OnContactExit(ContactExitInfo info)
    {
        isPressed = false;
        buttonRenderer.material = normalMaterial;
    }

    void Update()
    {
        if (!isPressed) return;

        // Add lightweight continuous held-contact effects here.
    }

    private void OnButtonPressed()
    {
        // Your button logic here
    }
}
```

### Contact Event Payloads (SDK 3.10.4+)

`ContactEnterInfo` and `ContactExitInfo` expose proxy objects for the sender and receiver involved in the collision. Always check proxy `isValid` before reading `player`, `usage`, transform data, or comparing it with a scene `VRCContactSender` / `VRCContactReceiver` reference.

```csharp
public override void OnContactEnter(ContactEnterInfo info)
{
    ContactSenderProxy sender = info.contactSender;
    ContactReceiverProxy receiver = info.contactReceiver;

    if (!sender.isValid || !receiver.isValid) return;

    if (sender.usage == DynamicsUsage.Avatar && sender.player != null && sender.player.IsValid())
    {
        Debug.Log($"Avatar sender: {sender.player.displayName}");
    }
    else if (sender.usage == DynamicsUsage.World)
    {
        Debug.Log("World contact sender");
    }

    Vector3 point = info.contactPoint;
    Vector3 velocity = info.enterVelocity;
    string[] tags = info.matchingTags;
}

public override void OnContactExit(ContactExitInfo info)
{
    if (!info.contactSender.isValid || !info.contactReceiver.isValid) return;
    string[] tags = info.matchingTags;
}
```

`ContactEnterInfo` includes `contactSender`, `contactReceiver`, `enterVelocity`, `contactPoint`, and `matchingTags`. `ContactExitInfo` includes `contactSender`, `contactReceiver`, and `matchingTags`.

### Dynamic Content Usage and Collision Tags

Use `UpdateContentTypes(DynamicsUsageFlags)` to choose accepted content categories and `UpdateCollisionTags(string[])` to change the matching tag set. A Contact can use up to 16 collision tags; extra tags are ignored.

```csharp
public class DynamicReceiver : UdonSharpBehaviour
{
    private VRCContactReceiver receiver;

    void Start()
    {
        receiver = GetComponent<VRCContactReceiver>();
    }

    public void EnableAvatarHandsOnly()
    {
        receiver.UpdateContentTypes(DynamicsUsageFlags.Avatar);
        receiver.UpdateCollisionTags(new string[] { "Hand", "Finger" });
    }

    public void EnableAvatarsAndWorldSenders()
    {
        receiver.UpdateContentTypes(DynamicsUsageFlags.Avatar | DynamicsUsageFlags.World);
        receiver.UpdateCollisionTags(new string[] { "Hand", "Finger", "Head", "Foot", "Custom" });
    }
}
```


### Runtime Contact Configuration

`VRCContactSender` and `VRCContactReceiver` expose `shapeType`, `radius`, `height`, `size`, `position`, and `rotation` from Udon. `size` is a `Vector3 size` for Box contacts; each box axis is capped at 6 meters after GameObject scale is applied. Batch runtime configuration writes, then call `ApplyConfigurationChanges()` once so the contact volume uses the new values.

```csharp
public VRCContactReceiver receiver;
public VRCContactSender sender;

public void ResizeBoxReceiver(Vector3 newSize, Vector3 offset)
{
    receiver.shapeType = ContactBase.ShapeType.Box;
    receiver.size = newSize;
    receiver.position = offset;
    receiver.ApplyConfigurationChanges();

    float proximity = receiver.CalculateProximity(sender);
    Debug.Log($"Current proximity: {proximity}");
}
```

Use `CalculateProximity(sender)` when you need an immediate `0.0-1.0` proximity value between a receiver and sender instead of waiting for avatar parameters or event state. For a Box receiver with `Use Face Proximity` enabled, proximity is measured toward the receiver's positive-Z face; otherwise it is measured toward the receiver center.

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

```text
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
using VRC.Dynamics;
using VRC.SDKBase;

public class GrabbableRope : UdonSharpBehaviour
{
    public AudioSource grabSound;
    public AudioSource releaseSound;

    private VRCPlayerApi currentGrabber;

    public override void OnPhysBoneGrabbed(PhysBoneGrabbedInfo info)
    {
        currentGrabber = info.player;
        grabSound.Play();

        if (info.player != null)
        {
            Debug.Log($"Rope grabbed by: {info.player.displayName}");
        }
    }

    public override void OnPhysBoneReleased(PhysBoneReleasedInfo info)
    {
        currentGrabber = null;
        releaseSound.Play();

        Debug.Log("Rope released");
    }

    public bool HasActiveGrab()
    {
        VRCPhysBone physBone = GetComponent<VRCPhysBone>();
        return physBone.IsGrabbed;
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

// Check current state
bool grabbed = physBone.IsGrabbed;
bool posed = physBone.IsPosed;

// Force release on the local client (SDK 3.10.0+)
physBone.ReleaseGrabs(); // Force release active grabs
physBone.ReleasePoses(); // Release frozen poses
```

### PhysBone Global Collision and Collider Udon Access

`VRCPhysBoneCollider` can be marked as **Global Collision** in the Inspector so PhysBones in the selected content types treat it as part of their collider list. The target PhysBone's Allow Collision rules still decide whether the collision is processed.

- Avatar global colliders can affect PhysBones in worlds when the world PhysBone allows avatar collisions.
- Avatars can have at most four additional PhysBone colliders with Global Collision enabled.
- Worlds have no documented count limit for global PhysBone colliders, but each collider still has runtime cost.
- Global Collision is supported only on Sphere and Capsule PhysBone colliders.
- Udon scripts can modify world collider shape fields, but the documented Udon-accessible fields do not include enabling/disabling `Global Collision` or changing whether a collider is global.

For world `VRCPhysBoneCollider` components, Udon can read and write `shapeType`, `radius`, `height`, `position`, and `rotation`. Batch changes and call `ApplyConfigurationChanges()` once after editing fields.

```csharp
public VRCPhysBoneCollider collider;

public void ConfigureCapsuleCollider(float radius, float height, Vector3 offset)
{
    collider.shapeType = VRC.Dynamics.VRCPhysBoneColliderBase.ShapeType.Capsule;
    collider.radius = radius;
    collider.height = height;
    collider.position = offset;
    collider.ApplyConfigurationChanges();
}
```

### PhysBone Collider Udon Boundary

SDK 3.10.4 exposes world `VRCPhysBoneCollider` configuration fields to Udon, but it does not expose separate PhysBone-collider enter/stay/exit callbacks on `UdonSharpBehaviour`. Use `OnPhysBoneGrabbed/Released/Posed/UnPosed` for PhysBone interaction state, and use Contacts when a world needs collider-like touch events.

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

```text
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
| **Network sync** | Compatible with VRChat networking (sync via UdonSynced/VRC_ObjectSync) | No VRChat network integration |
| **Performance** | Optimized for VRChat | Standard Unity performance |
| **Udon API access** | Full (`IsActive`, `SetSourceWeight`, etc.) | Not all properties exposed to Udon |
| **PhysBone compatibility** | Full | Not guaranteed |

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

## VRC Constraints Udon API

This section covers the full Udon API for controlling VRC Constraints at runtime. For component type selection and cross-platform considerations, see the [VRC Constraints vs Unity Constraints comparison table](#vrc-constraints-vs-unity-constraints) above.

### Constraint Types Overview

All six VRC Constraint types share a common base API. The table below summarises each type's purpose and the namespace required in UdonSharp:

| Component Class | Purpose | Typical Use Case |
|-----------------|---------|-----------------|
| `VRCPositionConstraint` | Constrains world/local position | Object that follows a target's position |
| `VRCRotationConstraint` | Constrains world/local rotation | Object that mirrors a target's rotation |
| `VRCScaleConstraint` | Constrains world/local scale | Object that scales with a target |
| `VRCParentConstraint` | Constrains position **and** rotation (like re-parenting) | Attaching props to moving targets |
| `VRCAimConstraint` | Rotates so a chosen axis points at the target | Turrets, eye tracking |
| `VRCLookAtConstraint` | Rotates so the forward axis looks at the target (Y-up preserved) | Billboards, simplified eye tracking |

All types live in `VRC.SDK3.Dynamics.Constraint.Components`.

### Udon-Accessible Properties

The properties below are available on every VRC Constraint component from Udon. Properties marked **read/write** can be set at runtime.

#### Common Properties (All Types)

| Property | Type | Access | Description |
|----------|------|--------|-------------|
| `IsActive` | `bool` | R/W | Enables or disables the constraint evaluation |
| `GlobalWeight` | `float` | R/W | Master blend weight (0.0 – 1.0) applied on top of per-source weights |
| `FreezeToWorld` | `bool` | R/W | When `true`, locks the constrained object in world space (ignores sources) |
| `AffectsPositionX/Y/Z` | `bool` | R/W | (Position / Parent) Toggle per-axis position constraint |
| `AffectsRotationX/Y/Z` | `bool` | R/W | (Rotation / Parent) Toggle per-axis rotation constraint |
| `AffectsScaleX/Y/Z` | `bool` | R/W | (Scale) Toggle per-axis scale constraint |

#### Source List Methods

| Method | Returns | Description |
|--------|---------|-------------|
| `GetSourceCount()` | `int` | Returns the current number of constraint sources |
| `GetSource(int index)` | `VRCConstraintSource` | Returns the source struct at the given index |
| `SetSource(int index, VRCConstraintSource source)` | `void` | Overwrites the source at the given index |
| `AddSource(VRCConstraintSource source)` | `void` | Appends a new source to the list |
| `RemoveSource(int index)` | `void` | Removes the source at the given index |
| `SetSourceWeight(int index, float weight)` | `void` | Convenience method – sets only the weight of source at index |

#### VRCConstraintSource Struct

`VRCConstraintSource` is a value-type struct. Always assign the full struct back after modifying it (struct-mutation rule applies — see [UdonSharp constraints reference](../rules/udonsharp-constraints.md)):

```csharp
// Fields
public Transform sourceTransform;   // The target Transform (can be null to disable source)
public float weight;                // Per-source blend weight (0.0 – 1.0)
```

### Code Examples

#### Example 1: Enable / Disable a Constraint at Runtime

Toggle a `VRCPositionConstraint` on and off, for example when a player picks up an object.

```csharp
using UdonSharp;
using UnityEngine;
using VRC.SDK3.Dynamics.Constraint.Components;
using VRC.SDKBase;

public class ConstraintToggle : UdonSharpBehaviour
{
    [Header("Constraint to control")]
    public VRCPositionConstraint positionConstraint;

    [Header("Optional: animate global weight instead of hard on/off")]
    public bool useWeightFade = false;

    // Called from a UI button or InteractEvent
    public void EnableConstraint()
    {
        if (positionConstraint == null) return;

        if (useWeightFade)
        {
            positionConstraint.GlobalWeight = 1f;
        }
        else
        {
            positionConstraint.IsActive = true;
        }
    }

    public void DisableConstraint()
    {
        if (positionConstraint == null) return;

        if (useWeightFade)
        {
            positionConstraint.GlobalWeight = 0f;
        }
        else
        {
            positionConstraint.IsActive = false;
        }
    }

    // Toggle helper – safe to call from network events
    public void ToggleConstraint()
    {
        if (positionConstraint == null) return;
        positionConstraint.IsActive = !positionConstraint.IsActive;
    }
}
```

**Notes**:
- Setting `IsActive = false` stops constraint evaluation entirely (cheapest option).
- Setting `GlobalWeight = 0` keeps evaluation running but blends to zero; useful for smooth transitions.
- No ownership transfer is needed to change constraint properties on the local client. If the result must be visible to all players, combine with `[UdonSynced]` state and `RequestSerialization()`.

#### Example 2: Modify Constraint Sources at Runtime

Dynamically swap or blend between multiple target transforms — for example, switching which player a spotlight follows.

```csharp
using UdonSharp;
using UnityEngine;
using VRC.SDK3.Dynamics.Constraint.Components;
using VRC.SDKBase;

public class ConstraintSourceSwapper : UdonSharpBehaviour
{
    [Header("The aim constraint that points a spotlight")]
    public VRCAimConstraint spotlightAim;

    [Header("A pool of potential target transforms")]
    public Transform[] targetPool;

    // Switch the single source to point at a new target
    public void SetTarget(int targetIndex)
    {
        if (spotlightAim == null) return;
        if (targetIndex < 0 || targetIndex >= targetPool.Length) return;

        // Build a new source struct pointing at the chosen transform
        VRCConstraintSource newSource = new VRCConstraintSource();
        newSource.sourceTransform = targetPool[targetIndex];
        newSource.weight = 1f;

        if (spotlightAim.GetSourceCount() == 0)
        {
            spotlightAim.AddSource(newSource);
        }
        else
        {
            // Overwrite the first (and only) source
            spotlightAim.SetSource(0, newSource);
        }
    }

    // Blend equally between two targets by adjusting their weights
    public void BlendBetweenTargets(int indexA, int indexB, float weightA)
    {
        if (spotlightAim == null) return;
        if (spotlightAim.GetSourceCount() < 2) return;

        float weightB = 1f - weightA;

        // SetSourceWeight is a convenience wrapper; equivalent to reading the source,
        // updating weight, and calling SetSource() back.
        spotlightAim.SetSourceWeight(indexA, weightA);
        spotlightAim.SetSourceWeight(indexB, weightB);
    }

    // Remove all sources except the first, then clear it
    public void ClearAllSources()
    {
        if (spotlightAim == null) return;

        int count = spotlightAim.GetSourceCount();
        // Remove from the end to avoid index shifting
        for (int i = count - 1; i > 0; i--)
        {
            spotlightAim.RemoveSource(i);
        }

        if (spotlightAim.GetSourceCount() > 0)
        {
            VRCConstraintSource empty = new VRCConstraintSource();
            empty.sourceTransform = null;
            empty.weight = 0f;
            spotlightAim.SetSource(0, empty);
        }
    }
}
```

**Notes**:
- `VRCConstraintSource` is a **struct** — always construct a new instance and assign it; do not attempt to mutate the value returned by `GetSource()` in place (see [struct mutation caveat](../rules/udonsharp-constraints.md#3-struct-mutation)).
- Remove sources from the **highest index downward** when removing multiple at once, to avoid index shifting mid-loop.
- `SetSourceWeight(index, weight)` is a shorthand for read-modify-write with `GetSource` / `SetSource`; both approaches are equivalent.

### Per-Type Additional Properties

Some constraint types expose extra writable properties beyond the common set:

| Type | Extra Properties | Description |
|------|-----------------|-------------|
| `VRCAimConstraint` | `AimVector`, `UpVector`, `WorldUpVector`, `WorldUpType` | Axis vectors for the aim calculation |
| `VRCLookAtConstraint` | `Roll` | Roll angle offset around the look axis |
| `VRCParentConstraint` | `AffectsPositionX/Y/Z`, `AffectsRotationX/Y/Z` | Independent axis masking for position and rotation |

### Runtime Source Management — Pattern Summary

```csharp
using VRC.SDK3.Dynamics.Constraint.Components;

// --- Read ---
int count = constraint.GetSourceCount();
VRCConstraintSource src = constraint.GetSource(0);
float w = src.weight;
Transform t = src.sourceTransform;

// --- Write (weight only) ---
constraint.SetSourceWeight(0, 0.5f);

// --- Write (full source) ---
// IMPORTANT: structs must be fully reassigned — do not mutate GetSource() result in place
VRCConstraintSource updated = constraint.GetSource(0);
updated.sourceTransform = someNewTransform; // modify copy
updated.weight = 0.75f;
constraint.SetSource(0, updated);           // write back

// --- Add ---
VRCConstraintSource newSrc = new VRCConstraintSource();
newSrc.sourceTransform = targetTransform;
newSrc.weight = 1f;
constraint.AddSource(newSrc);

// --- Remove (always remove from highest index first in loops) ---
constraint.RemoveSource(count - 1);
```

### Performance Considerations

| Tip | Reason |
|-----|--------|
| Disable (`IsActive = false`) when not needed | Stops CPU evaluation of the constraint entirely |
| Prefer `SetSourceWeight` over removing/re-adding sources | Avoids internal list reallocation |
| Avoid modifying sources every `Update()` frame | Batch changes and apply only when the target actually changes |
| Use `GlobalWeight` for smooth fades | Cheaper than adding/removing sources for blending |

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

    public override void OnPhysBoneGrabbed(PhysBoneGrabbedInfo info)
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

        // Spawn effect at estimated touch point on the receiver surface.
        SpawnTouchEffect(info.contactPoint);
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
    ContactSenderProxy sender = info.contactSender;
    if (!sender.isValid) return;

    if (sender.usage == DynamicsUsage.Avatar)
    {
        // Contact from an avatar-owned sender.
        // - Avatar receiver Allow Self / Allow Others settings apply on avatars.
        VRCPlayerApi player = sender.player;
    }
    else if (sender.usage == DynamicsUsage.World)
    {
        // Contact from a world object (VRC Contact Sender in world).
        // - Avatar-only Allow Self / Allow Others settings do not describe world senders.
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
        ContactSenderProxy sender = info.contactSender;
        if (!sender.isValid) return;

        string playerName = (sender.player != null && sender.player.IsValid())
            ? sender.player.displayName
            : "none";
        Debug.Log($"[Contact] Enter - Usage: {sender.usage}, Player: {playerName}, " +
                  $"Point: {info.contactPoint}, Velocity: {info.enterVelocity}");
    }

    public override void OnPhysBoneGrabbed(PhysBoneGrabbedInfo info)
    {
        string playerName = (info.player != null && info.player.IsValid())
            ? info.player.displayName
            : "none";
        Debug.Log($"[PhysBone] Grab - Player: {playerName}, Object: {gameObject.name}");
    }
}
```

## Best Practices

1. **Test with multiple players** - Contacts behave differently with network latency
2. **Use precise DynamicsUsageFlags and collision tags** - Be specific to avoid unwanted triggers
3. **Handle null proxy players** - after `isValid`, read `info.contactSender.player` / `info.contactReceiver.player`; world-side contacts may not have a player
4. **Sync state, not events** - Use `[UdonSynced]` for persistent state
5. **Debounce rapid contacts** - Add cooldown to prevent spam
6. **Clean up on player leave** - Reset state in `OnPlayerLeft`

## See Also

- [events.md](events.md) - Full reference for `OnContactEnter/Exit` and `OnPhysBoneGrabbed/Released` signatures
- [patterns-core.md](patterns-core.md) - Common patterns for interactive objects using Contacts and PhysBones
- [networking.md](networking.md) - Syncing contact/grab state across players with `[UdonSynced]`
