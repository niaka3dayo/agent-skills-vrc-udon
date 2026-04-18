# VRChat SDK Migration Guide (3.7 to 3.10)

Step-by-step guide for upgrading UdonSharp worlds across major SDK versions.

**Applies to**: SDK 3.7.x through 3.10.2

> **Deprecation Notice**: SDK versions below 3.9.0 were deprecated on **December 2, 2025**.
> New world uploads are no longer possible with those versions.
> Worlds that have not yet migrated past 3.9.0 must update to continue publishing.

---

## SDK 3.7.x to 3.8.x

### New Features

#### GetComponent<T> for UdonSharpBehaviour Types (SDK 3.8.0+)

Before SDK 3.8, using the generic `GetComponent<T>()` form on types derived from `UdonSharpBehaviour` was unreliable. SDK 3.8 added proper support for the generic form on direct subclasses and through inheritance hierarchies.

```csharp
// SDK 3.7: Required cast syntax for reliability
MyScript s = (MyScript)(object)GetComponent(typeof(MyScript));

// SDK 3.8+: Generic form works correctly
MyScript s = GetComponent<MyScript>();

// SDK 3.8+: Also works through inheritance
public class BaseGimmick : UdonSharpBehaviour { }
public class DerivedGimmick : BaseGimmick { }

BaseGimmick base = GetComponent<BaseGimmick>();     // finds DerivedGimmick too
DerivedGimmick derived = GetComponent<DerivedGimmick>();
BaseGimmick[] all = GetComponents<BaseGimmick>();   // plural form also works
```

**Note**: Getting `UdonBehaviour` itself (the raw type, not your subclass) still requires the non-generic cast form: `(UdonBehaviour)GetComponent(typeof(UdonBehaviour))`.

#### [NetworkCallable] — Parameterized Network Events (SDK 3.8.1+)

Before SDK 3.8.1, network events had no parameter support. Callers had to pre-load synced variables and call `RequestSerialization()` before sending an event, creating race conditions.

`[NetworkCallable]` adds up to 8 typed parameters per network call, eliminating the pre-serialization pattern.

```csharp
using VRC.Udon.Common.Interfaces;

[UdonBehaviourSyncMode(BehaviourSyncMode.Manual)]
public class DamageSystem : UdonSharpBehaviour
{
    // Before (SDK 3.7): set synced var, RequestSerialization, then fire event
    // After (SDK 3.8.1): pass parameters directly

    [NetworkCallable]
    public void TakeDamage(int damage, int attackerId)
    {
        // Parameters arrive atomically — no race condition
        Debug.Log($"Took {damage} damage from player {attackerId}");
    }

    public void SendDamage(int damage, int attackerId)
    {
        SendCustomNetworkEvent(
            NetworkEventTarget.All,
            nameof(TakeDamage),
            damage,
            attackerId
        );
    }
}
```

Constraints on `[NetworkCallable]` methods:
- Method must be `public`
- Cannot be `static`, `virtual`, or `override`
- No method overloading
- Maximum 8 parameters
- Parameter types must be syncable types (same set as `[UdonSynced]`)
- Default rate limit: 5 calls/sec/event; configurable up to 100/sec via `[NetworkCallable(n)]`

#### New NetworkEventTarget Values (SDK 3.8.1+)

Two new targets were added to `NetworkEventTarget`:

| Target | Description |
|--------|-------------|
| `NetworkEventTarget.Others` | All players except the sender |
| `NetworkEventTarget.Self` | Local player only (equivalent to direct local call) |

`Others` is particularly useful for effects and sounds: the sender plays the effect locally, then broadcasts to `Others` so it is not played twice.

#### PhysBone Dependency Sorting (SDK 3.8.0+)

PhysBone components in parent-child relationships are now automatically sorted so parent chains evaluate before their children. Worlds that worked around evaluation-order instability with manual ordering may be able to remove those workarounds after upgrading.

#### Drone API: VRCDroneInteractable (SDK 3.8.0+)

SDK 3.8.0 introduced `VRCDroneInteractable` for creating drone-type vehicles. This is a new component category and does not replace or change existing components.

### Breaking Changes

None that affect standard UdonSharp worlds. The `GetComponent<T>` behavior change is purely additive.

### Migration Checklist: 3.7.x to 3.8.x

- [ ] Replace synced-variable-before-event patterns with `[NetworkCallable]` where appropriate
- [ ] Replace `NetworkEventTarget.All` + local guard logic with `NetworkEventTarget.Others` where you were filtering out the sender
- [ ] Replace verbose `(MyScript)(object)GetComponent(typeof(MyScript))` casts with `GetComponent<MyScript>()` in existing scripts
- [ ] Review PhysBone chain ordering; remove manual workarounds that are no longer needed

---

## SDK 3.8.x to 3.9.x

### New Features

#### Camera Dolly Udon API (SDK 3.9.0+)

SDK 3.9.0 added a Udon-accessible Camera Dolly system. Camera dolly tracks can be authored in the scene and controlled at runtime from UdonSharp, enabling cinematic camera movement sequences.

Key usage pattern: create a Camera Dolly track in the scene, assign a `VRCCameraDolly` reference in your UdonBehaviour, then call the track control methods.

#### Auto Hold Mode Simplification for Pickups (SDK 3.9.0+)

The `Auto Hold` field on `VRC_Pickup` was simplified. The old three-value enum (`Yes / No / AutoDetect`) was replaced with a simple checkbox (`Yes / No`). The `AutoDetect` option (which attempted to infer hold behavior from object size) is no longer available.

```csharp
// SDK 3.8 Inspector: Auto Hold = AutoDetect | Yes | No
// SDK 3.9 Inspector: Auto Hold = checked (Yes) | unchecked (No)

// AutoDetect is gone. Review each pickup and set the checkbox explicitly.
```

Worlds upgrading from 3.8 should audit all `VRC_Pickup` components and confirm the auto hold setting is intentional, since `AutoDetect` no longer exists as a fallback.

#### VRCCameraSettings API (SDK 3.9.0+)

Read-only access to the player's active camera properties. Namespace: `VRC.SDK3.Rendering`.

```csharp
using VRC.SDK3.Rendering;

// Two static instances
VRCCameraSettings screen = VRCCameraSettings.ScreenCamera; // main view
VRCCameraSettings photo  = VRCCameraSettings.PhotoCamera;  // in-game photo cam

// Properties (all read-only)
int   width   = screen.PixelWidth;
int   height  = screen.PixelHeight;
float fov     = screen.FieldOfView;
bool  active  = screen.Active;

// Event: fires when any camera property changes
public override void OnVRCCameraSettingsChanged(VRCCameraSettings camera)
{
    if (camera != VRCCameraSettings.ScreenCamera) return; // filter photo cam
    Debug.Log($"Resolution: {camera.PixelWidth}x{camera.PixelHeight}");
}
```

Camera properties cannot be set from Udon; the API is read-only.

#### Network ID Utility Improvements (SDK 3.9.0+)

SDK 3.9.0 included improvements to the Network ID Utility tool in the VRChat SDK panel. The tool assigns and manages network IDs used by `VRC_ObjectSync` and related components. Previously the tool had reliability issues with complex scenes; the 3.9.0 improvements reduced the likelihood of duplicate or missing IDs after scene edits.

**Action required**: After upgrading to SDK 3.9.x, open **VRChat SDK > Utilities > Network ID Utility** and run a scan to confirm IDs are clean.

### Breaking Changes

- **Auto Hold `AutoDetect` removed**: Any `VRC_Pickup` that previously used `AutoDetect` now defaults to `No`. Pickups that relied on auto-detection for hold behavior will need the checkbox set explicitly.

### Migration Checklist: 3.8.x to 3.9.x

- [ ] Open every scene and run **Network ID Utility** to verify no duplicate or missing network IDs
- [ ] Audit all `VRC_Pickup` components: `AutoDetect` is gone; verify each pickup's hold mode is set to the intended `Yes` or `No`
- [ ] Add `OnVRCCameraSettingsChanged` handling where scripts need to react to resolution or FOV changes (optional new capability)
- [ ] Review Camera Dolly sequences if upgrading from a custom dolly implementation

---

## SDK 3.9.x to 3.10.x

### New Features

#### VRChat Dynamics for Worlds (SDK 3.10.0+)

The largest addition of the 3.10 series: **PhysBones**, **Contacts**, and **VRC Constraints** are now available in worlds, not just on avatars.

**PhysBones** — physics-based bone chains for ropes, flags, chains, and interactive objects.

```csharp
public class GrabbableRope : UdonSharpBehaviour
{
    public override void OnPhysBoneGrab(PhysBoneGrabInfo info)
    {
        Debug.Log($"Grabbed by {info.player?.displayName}");
    }

    public override void OnPhysBoneRelease(PhysBoneReleaseInfo info)
    {
        Debug.Log("Released");
    }
}

// PhysBone API
VRCPhysBone pb = GetComponent<VRCPhysBone>();
bool grabbed      = pb.IsGrabbed();
pb.ForceReleaseGrab();  // force-release a grab
pb.ForceReleasePose();  // reset a bent chain
```

**Contacts** — collision detection between `VRC Contact Sender` and `VRC Contact Receiver` components.

```csharp
public class ContactButton : UdonSharpBehaviour
{
    public override void OnContactEnter(ContactEnterInfo info)
    {
        if (info.isAvatar)
            Debug.Log($"Pressed by {info.player?.displayName}");
        else
            Debug.Log("Pressed by world object");
    }

    public override void OnContactExit(ContactExitInfo info) { }
}
```

**VRC Constraints** — cross-platform replacements for Unity's built-in constraint components. Unity Constraints are disabled on Quest/Android; VRC Constraints work on all platforms.

```csharp
using VRC.SDK3.Dynamics.Constraint.Components;

public class ConstraintController : UdonSharpBehaviour
{
    public VRCPositionConstraint posConstraint;

    public void EnableFollow() => posConstraint.IsActive = true;
    public void DisableFollow() => posConstraint.IsActive = false;

    public void SetWeight(float w) => posConstraint.SetSourceWeight(0, w);
}
```

VRC Constraint types: `VRCPositionConstraint`, `VRCRotationConstraint`, `VRCScaleConstraint`, `VRCParentConstraint`, `VRCAimConstraint`, `VRCLookAtConstraint`. All share a common Udon API (`IsActive`, `GlobalWeight`, `GetSource` / `SetSource`, etc.). See [dynamics.md](dynamics.md) for the full reference.

#### Persistence Storage Information API (SDK 3.10.0+)

New `VRCPlayerApi` methods to query how much persistence storage (PlayerData + PlayerObject combined) a player is consuming.

```csharp
int used  = player.GetPlayerDataStorageUsage(); // bytes
int limit = player.GetPlayerDataStorageLimit(); // bytes (typically 102400)
player.RequestStorageUsageUpdate();             // request a fresh value from server
```

The `OnPersistenceUsageUpdated` event fires when updated usage data arrives:

```csharp
public override void OnPersistenceUsageUpdated(VRCPlayerApi player)
{
    if (!player.isLocal) return;
    int used  = player.GetPlayerDataStorageUsage();
    int limit = player.GetPlayerDataStorageLimit();
    Debug.Log($"Storage: {used}/{limit} bytes");
}
```

See [persistence.md](persistence.md) for a full monitoring example.

#### EventTiming Extensions (SDK 3.10.2+)

`SendCustomEventDelayedSeconds` and `SendCustomEventDelayedFrames` gained two new `EventTiming` values:

| EventTiming | When | Use case |
|-------------|------|----------|
| `EventTiming.Update` | Update loop | General logic (was the only option) |
| `EventTiming.LateUpdate` | After all Update calls | Post-animation logic |
| `EventTiming.FixedUpdate` | Physics tick | Physics-synchronized callbacks |
| `EventTiming.PostLateUpdate` | After LateUpdate | Camera follow, post-IK corrections |

```csharp
// Schedule a physics-safe callback
SendCustomEventDelayedSeconds(nameof(PhysicsStep), 1.0f, EventTiming.FixedUpdate);

// Schedule a camera-follow update after IK
SendCustomEventDelayedFrames(nameof(UpdateCamera), 1, EventTiming.PostLateUpdate);
```

`FixedUpdate` and `PostLateUpdate` are new in SDK 3.10.2; `Update` and `LateUpdate` existed since SDK 3.7.1.

#### PhysBone Collider Callbacks (SDK 3.10.0+)

In addition to grab/release events, PhysBones now fire three collider-interaction callbacks on any UdonBehaviour attached to the same GameObject as the `VRC Phys Bone` component:

| Event | Trigger |
|-------|---------|
| `OnPhysBoneColliderEnter(PhysBoneColliderInfo info)` | A PhysBone collider starts intersecting the bone chain |
| `OnPhysBoneColliderStay(PhysBoneColliderInfo info)` | A PhysBone collider continues intersecting each frame |
| `OnPhysBoneColliderExit(PhysBoneColliderInfo info)` | A PhysBone collider stops intersecting |

Keep `OnPhysBoneColliderStay` handlers lightweight; it fires every frame and can create significant overhead.

### Breaking Changes

#### VRCContactReceiver.UpdateContentTypes() Signature Change (SDK 3.10.1)

The parameter type of `UpdateContentTypes()` changed from `IEnumerable<string>` to `string[]`. Since `List<T>` is not available in UdonSharp, correct code already used `string[]` directly. If any script was passing a collection via an interface reference, update to a `string[]` literal or array variable.

```csharp
// Correct (works in all 3.10.x)
string[] types = new string[] { "Hand", "Finger" };
receiver.UpdateContentTypes(types);
```

#### Unity Constraints — Quest Impact

Unity's built-in constraint components (`PositionConstraint`, `ParentConstraint`, etc.) are **disabled on Quest/Android**. Worlds that previously worked PC-only may discover Quest visitors see no constraint behavior. Replace all Unity Constraints with their VRC Constraint equivalents before uploading a cross-platform world.

| Unity Constraint | VRC Replacement |
|-----------------|----------------|
| `PositionConstraint` | `VRCPositionConstraint` |
| `RotationConstraint` | `VRCRotationConstraint` |
| `ScaleConstraint` | `VRCScaleConstraint` |
| `ParentConstraint` | `VRCParentConstraint` |
| `AimConstraint` | `VRCAimConstraint` |
| `LookAtConstraint` | `VRCLookAtConstraint` |

Namespace for all VRC Constraints: `VRC.SDK3.Dynamics.Constraint.Components`.

### Migration Checklist: 3.9.x to 3.10.x

- [ ] Replace all Unity Constraint components with VRC Constraint equivalents (mandatory for Quest support)
- [ ] Add `using VRC.SDK3.Dynamics.Constraint.Components;` to any script that references VRC Constraints
- [ ] Verify `VRCContactReceiver.UpdateContentTypes()` calls pass `string[]` (not a list or interface type)
- [ ] Implement `OnPersistenceUsageUpdated` if your world writes PlayerData and you want to warn players of storage limits
- [ ] Audit `SendCustomEventDelayed*` calls: use `EventTiming.FixedUpdate` for physics-coupled callbacks, `EventTiming.PostLateUpdate` for camera/IK callbacks, instead of frame-delay workarounds
- [ ] For worlds using PhysBones in world space: avoid placing them inside `Instantiate()`-created objects (PhysBones in instantiated objects may not be network-synced; use scene-placed objects or VRChat Object Pool instead)
- [ ] Test the Contact-based interactions with multiple players; `Allow Self` / `Allow Others` settings on `VRC Contact Receiver` do not apply to world-object senders

---

#### SDK 3.10.3 changes

Small surface, but each item has non-obvious consequences documented elsewhere — this entry just routes you to them.

- **`VRCPlayerApi.isVRCPlus`** (bool) added. Evaluated per-client; read after `OnPlayerRestored`, not inside `OnPlayerJoined`. Never `[UdonSynced]` the result. Full timing and anti-sync rationale: `api.md` (VRCPlayerApi Properties > isVRCPlus subsection).
- **NEVER #19** (design-axis, not silent-failure): do not gate core gameplay, safety, or moderation features by `isVRCPlus`. See SKILL.md NEVER table and the cosmetic-indicator pattern in `patterns-core.md`.
- **VRCRaycast**: avatar-side component (added 3.10.3). Udon runtime access is not indicated by the release notes. World builders should design collider/layer setup with avatar-driven raycasts in mind — see `unity-vrc-world-sdk-3/references/components.md`.
- **Mirror rendering internals**: VRChat's mirror pipeline moved from `OnWillRenderObject` to `Camera.onPreCull` for 2026.1.3 client parity. Udon scripts do not interact with either hook, so no script-side migration is required.
- **Toon Standard shader** (avatar-only): not covered by this skill.

---

## See Also

- [networking.md](networking.md) — `[NetworkCallable]`, sync modes, NetworkEventTarget reference
- [dynamics.md](dynamics.md) — PhysBones, Contacts, VRC Constraints full API
- [persistence.md](persistence.md) — PlayerData, PlayerObject, storage monitoring
- [events.md](events.md) — EventTiming, all Udon event signatures
- [constraints.md](constraints.md) — `GetComponent<T>` behavior, UdonSharp compile constraints
