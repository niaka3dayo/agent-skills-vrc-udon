# VRChat Dynamics for Worlds Reference

Comprehensive guide to PhysBones, Contacts, and VRC Constraints in VRChat worlds. Dynamics were introduced in SDK 3.10.0; the active verified target is SDK 3.10.6.

**Active support / last verified**: SDK 3.10.6
**Historical feature introduction**: SDK 3.10.0

SDK 3.10.0-3.10.5 entries are historical feature context only, not active support or validation targets for this Skill.

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

    public void _EnableAvatarHandsOnly()
    {
        receiver.UpdateContentTypes(DynamicsUsageFlags.Avatar);
        receiver.UpdateCollisionTags(new string[] { "Hand", "Finger" });
    }

    public void _EnableAvatarsAndWorldSenders()
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

    public void _Launch()
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

In [SDK 3.10.5](https://creators.vrchat.com/releases/release-3-10-5/), PhysBone
**Reset When Disabled** also resets animator parameters and Udon state. When
debugging a value that changes on disable, inspect this component setting before
adding a second reset in Udon. This does not add a new PhysBone callback.

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

    public bool _HasActiveGrab()
    {
        VRCPhysBone physBone = GetComponent<VRCPhysBone>();
        return physBone.IsGrabbed;
    }

    public VRCPlayerApi _GetGrabber()
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
using VRC.Dynamics;
using VRC.SDK3.Dynamics.Constraint.Components;

public class ConstraintController : UdonSharpBehaviour
{
    public VRCPositionConstraint posConstraint;

    public void _EnableConstraint()
    {
        posConstraint.IsActive = true;
        posConstraint.ApplyConfigurationChanges();
    }

    public void _DisableConstraint()
    {
        posConstraint.IsActive = false;
        posConstraint.ApplyConfigurationChanges();
    }

    // SDK 3.10.6+: copy the source struct, edit it, then write it back.
    public void SetWeight(float weight)
    {
        if (posConstraint.SourceCount == 0) return;
        VRCConstraintSource source = posConstraint.GetSource(0);
        source.Weight = weight;
        posConstraint.SetSource(0, source);
    }
}
```

After changing constraint properties from a script, call `ApplyConfigurationChanges()` once; the [official Constraints API](https://creators.vrchat.com/common-components/constraints/constraints-api) states that changes may not be applied otherwise.

### VRC Constraints vs Unity Constraints

VRChat provides its own constraint components as an alternative to Unity's built-in constraints. Worlds may use either system on Android. Prefer VRC Constraints for new work, and profile Unity Constraint-heavy scenes because overuse can significantly affect performance.

#### Comparison Table

| Feature | VRC Constraints | Unity Constraints |
|---------|----------------|-------------------|
| **Quest/Android worlds** | Supported | Permitted; profile performance |
| **PC** | Supported | Supported |
| **Network sync** | Compatible with VRChat networking (sync via UdonSynced/VRC_ObjectSync) | No VRChat network integration |
| **Performance** | Optimized for VRChat | Standard Unity performance |
| **Udon API access** | `IsActive`, `GlobalWeight`, `SmoothingFactor`, source methods (SDK 3.10.6+), etc. | Not all properties exposed to Udon |
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

// Also permitted in worlds, but profile the cost on every target device:
// public UnityEngine.Animations.ParentConstraint parentConstraint;
```

#### Decision Guide

| Scenario | Recommendation |
|----------|---------------|
| World targets PC + Quest | VRC Constraints preferred; profile either system on target hardware |
| World targets PC only | VRC Constraints preferred for new work |
| Need Udon API control | **VRC Constraints** (better API) |
| Migrating from Unity Constraints | Replace when API needs or profiling results justify it |
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
| `VRCLookAtConstraint` | Rotates so the forward axis looks at the target (Y-up preserved) | Aiming at a scene Transform, simplified eye tracking; for viewpoint-facing billboards use `VRCBillboard` (SDK 3.10.6+) |

All types live in `VRC.SDK3.Dynamics.Constraint.Components`.

### Udon-Accessible Properties

The properties below are read/write from Udon on every VRC Constraint component, except the read-only `TargetTransform`. Descriptions follow the [official Constraints API](https://creators.vrchat.com/common-components/constraints/constraints-api); call `ApplyConfigurationChanges()` once after script changes.

#### Common Properties (All Types)

| Property | Type | Description |
|----------|------|-------------|
| `IsActive` | `bool` | Enables or disables the constraint evaluation |
| `GlobalWeight` | `float` | Weight applied on top of all per-source weights |
| `Locked` | `bool` | Lock state; constraints are always treated as locked in play mode |
| `FreezeToWorld` | `bool` | Captures the current pose when switched on and tries to hold it in world space |
| `SolveInLocalSpace` | `bool` | Solves in local space instead of world space |
| `TargetTransform` | `Transform` | Read-only from Udon (no setter in the 3.10.6 wrapper). Transform that receives the result; `null` means the constraint's own transform |
| `SmoothingFactor` | `float` | SDK 3.10.6+. `0` snaps; higher values move about 63% of the way to the target every `SmoothingFactor` seconds |

Per-axis "Affects" toggles are Inspector/C# settings only; the 3.10.6 Udon wrapper has no `Affects*` accessors.

#### Source Methods (SDK 3.10.6+)

| Member | Returns | Notes |
|--------|---------|-------|
| `SourceCount` | `int` | Property, not a method |
| `GetSource(int index)` | `VRCConstraintSource` | Out of range: logs an error and returns an empty source |
| `SetSource(int index, VRCConstraintSource source)` | `void` | Overwrites the source at `index` |
| `AddSource(VRCConstraintSource source)` | `void` | Appends to the end |
| `RemoveSource(int index)` / `RemoveSource(VRCConstraintSource source)` | `void` / `bool` | The struct overload returns `true` when a matching source was removed |
| `GetSources(VRCConstraintSource[] sources)` | `int` | Copies into the array you pass; returns the number copied |
| `SetSources(VRCConstraintSource[] sources)` | `void` | Replaces every source; `null` or empty clears the list |
| `ClearSources()` | `void` | Removes every source |

These members are new in SDK 3.10.6. The SDK 3.10.4 and 3.10.5 Udon wrappers expose source access only through the `Sources` list. Do not generate `GetSourceCount()` or `SetSourceWeight()`: neither exists in SDK 3.10.4, 3.10.5, or 3.10.6. On 3.10.6, VRChat recommends these methods over editing `Sources` directly from Udon; direct list edits have reliability issues and stay exposed only for backward compatibility.

#### VRCConstraintSource Struct

`VRCConstraintSource` (namespace `VRC.Dynamics`) is a value-type struct with the properties `SourceTransform`, `Weight`, `ParentPositionOffset`, and `ParentRotationOffset`. Construct it with `new VRCConstraintSource(transform, weight)` or `new VRCConstraintSource(transform, weight, positionOffset, rotationOffset)`. A value returned by `GetSource()` is a copy: edit the copy, then write it back with `SetSource()`.

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
    public void _EnableConstraint()
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
        positionConstraint.ApplyConfigurationChanges();
    }

    public void _DisableConstraint()
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
        positionConstraint.ApplyConfigurationChanges();
    }

    // Toggle helper – safe to call from network events
    public void _ToggleConstraint()
    {
        if (positionConstraint == null) return;
        positionConstraint.IsActive = !positionConstraint.IsActive;
        positionConstraint.ApplyConfigurationChanges();
    }
}
```

**Notes**:
- Setting `IsActive = false` stops constraint evaluation entirely (cheapest option).
- Setting `GlobalWeight = 0` keeps evaluation running but blends to zero; useful for smooth transitions.
- Call `ApplyConfigurationChanges()` once after the property edits, as the official Constraints API requires for script changes.
- No ownership transfer is needed to change constraint properties on the local client. If the result must be visible to all players, combine with `[UdonSynced]` state and `RequestSerialization()`.

#### Example 2: Modify Constraint Sources at Runtime (SDK 3.10.6+)

Dynamically swap or blend between multiple target transforms — for example, switching which player a spotlight follows.

```csharp
using UdonSharp;
using UnityEngine;
using VRC.Dynamics;
using VRC.SDK3.Dynamics.Constraint.Components;

public class ConstraintSourceSwapper : UdonSharpBehaviour
{
    [Header("The aim constraint that points a spotlight")]
    public VRCAimConstraint spotlightAim;

    [Header("A pool of potential target transforms")]
    public Transform[] targetPool;

    // Point the single source at a new target
    public void SetTarget(int targetIndex)
    {
        if (spotlightAim == null) return;
        if (targetIndex < 0 || targetIndex >= targetPool.Length) return;

        VRCConstraintSource newSource = new VRCConstraintSource(targetPool[targetIndex], 1f);

        if (spotlightAim.SourceCount == 0)
        {
            spotlightAim.AddSource(newSource);
        }
        else
        {
            spotlightAim.SetSource(0, newSource);
        }
    }

    // Blend between two existing sources by editing their weights
    public void BlendBetweenTargets(int indexA, int indexB, float weightA)
    {
        if (spotlightAim == null) return;
        int count = spotlightAim.SourceCount;
        if (indexA < 0 || indexA >= count || indexB < 0 || indexB >= count) return;

        VRCConstraintSource sourceA = spotlightAim.GetSource(indexA);
        sourceA.Weight = weightA;
        spotlightAim.SetSource(indexA, sourceA);

        VRCConstraintSource sourceB = spotlightAim.GetSource(indexB);
        sourceB.Weight = 1f - weightA;
        spotlightAim.SetSource(indexB, sourceB);
    }

    public void _ClearAllSources()
    {
        if (spotlightAim == null) return;
        spotlightAim.ClearSources();
    }
}
```

**Notes**:
- `VRCConstraintSource` is a **struct**: `GetSource()` returns a copy, so write the edited copy back with `SetSource()`.
- Check `index < SourceCount` before `GetSource()` / `SetSource()`; an out-of-range index logs an error instead of throwing.
- Removing by index shifts later sources down. When removing several by index, go from the highest index downward, or use `ClearSources()` / `SetSources()`.

### Per-Type Additional Properties

Some constraint types expose extra Udon properties beyond the common set (names as exposed by the 3.10.6 Udon wrapper):

| Type | Extra Properties | Description |
|------|-----------------|-------------|
| `VRCAimConstraint` | `AimAxis`, `UpAxis`, `WorldUp`, `WorldUpVector`, `WorldUpTransform` | Aim alignment; `WorldUp` is `VRCConstraintBase.WorldUpType` (`VRC.Dynamics`) |
| `VRCLookAtConstraint` | `Roll`, `UseUpTransform`, `WorldUpTransform` | `Roll` applies only while `UseUpTransform` is `false` |
| `VRCPositionConstraint` / `VRCRotationConstraint` / `VRCScaleConstraint` | `*AtRest`, `*Offset` | At-rest and offset values for the constrained channel |
| `VRCParentConstraint` | `PositionAtRest`, `RotationAtRest` | Per-source offsets live on each source (`ParentPositionOffset` / `ParentRotationOffset`) |

### Runtime Source Management — Pattern Summary (SDK 3.10.6+)

```csharp
using VRC.Dynamics;
using VRC.SDK3.Dynamics.Constraint.Components;

// --- Read ---
int count = constraint.SourceCount;
VRCConstraintSource src = constraint.GetSource(0);
float w = src.Weight;
Transform t = src.SourceTransform;

// --- Write (copy, edit, write back) ---
VRCConstraintSource updated = constraint.GetSource(0);
updated.SourceTransform = someNewTransform;
updated.Weight = 0.75f;
constraint.SetSource(0, updated);

// --- Add / remove ---
constraint.AddSource(new VRCConstraintSource(targetTransform, 1f));
bool removed = constraint.RemoveSource(updated);
constraint.RemoveSource(constraint.SourceCount - 1);

// --- Bulk ---
VRCConstraintSource[] snapshot = new VRCConstraintSource[constraint.SourceCount];
int copied = constraint.GetSources(snapshot);
constraint.SetSources(snapshot);
constraint.ClearSources();
```

### Performance Considerations

| Tip | Reason |
|-----|--------|
| Disable (`IsActive = false`) when not needed | Stops evaluation of the constraint |
| Edit an existing source's `Weight` instead of removing/re-adding sources | Keeps source indices stable |
| Avoid modifying sources every `Update()` frame | Batch changes and apply only when the target actually changes |
| Use `GlobalWeight` or `SmoothingFactor` for smooth transitions | No per-frame Udon interpolation loop |

## Common Patterns

### Interactive Button with Feedback

```csharp
using UdonSharp;
using UnityEngine;
using VRC.Dynamics;
using VRC.SDK3.UdonNetworkCalling;
using VRC.SDKBase;
using VRC.Udon.Common.Interfaces;

public class PhysicalButton : UdonSharpBehaviour
{
    private const float ReceiverCooldown = 0.5f;

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
    private float lastAcceptedActionTime = float.MinValue;

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
            nameof(_DoButtonAction)
        );
    }

    [NetworkCallable(2)]
    public void _DoButtonAction()
    {
        if (!NetworkCalling.InNetworkCall) return;

        VRCPlayerApi caller = NetworkCalling.CallingPlayer;
        if (caller == null || !caller.IsValid()) return;

        // Any valid caller may trigger this diagnostic effect. The local
        // cooldown bounds aggregate execution across all callers.
        if (Time.time - lastAcceptedActionTime < ReceiverCooldown) return;
        lastAcceptedActionTime = Time.time;
        Debug.Log("Button action executed!");
    }
}
```

The receiver accepts any valid caller because the action is diagnostic only.
`[NetworkCallable(N)]` paces remote sends for one event on one behaviour and queues excess sends on the sender. It is not an aggregate receiver or resource bound across callers. The receiver-local cooldown bounds execution on each client; use a stricter session role policy before replacing the log with privileged or state-changing work.

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
