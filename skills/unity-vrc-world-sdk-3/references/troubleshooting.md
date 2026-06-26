# VRChat World Troubleshooting Guide

Common problems encountered during world development and their solutions.

## Table of Contents

- [Build & Upload Issues](#build--upload-issues)
- [Scene Setup Issues](#scene-setup-issues)
- [Component Issues](#component-issues)
- [Layer & Collision Issues](#layer--collision-issues)
- [Performance Issues](#performance-issues)
- [Networking Issues](#networking-issues)
- [Quest/Android Issues](#questandroid-issues)
- [Investigation Steps](#investigation-steps)

---

## Build & Upload Issues

### "Missing VRC_SceneDescriptor"

**Symptom**: Error saying SceneDescriptor is missing during build

**Solution**:

```text

1. VRChat SDK > Show Control Panel
2. Builder tab
3. "Add VRChat World" or add VRCWorld Prefab
4. Confirm exactly 1 exists in the scene

```

### "Layer collision matrix needs setup"

**Symptom**: Warning that layer settings are incorrect

**Solution**:

```text

1. VRChat SDK > Show Control Panel
2. Builder tab
3. Click "Setup Layers for VRChat"
4. Layers and collision matrix are automatically configured

```

Before using the setup buttons in a mature project, check
[build-validation.md](build-validation.md#layer-and-collision-setup): layer
setup can move custom layers and requires layer-mask review.

### World not found after upload

**Symptom**: Upload succeeded but world doesn't appear

**Solution**:

```text

1. Log in to the VRChat website
2. Check "My Worlds"
3. Check privacy settings
4. Wait a few minutes (may take time to propagate)
5. Restart the VRChat client

```

### "Build was cancelled"

**Symptom**: Build was cancelled

**Solution**:

```text

1. Check Unity Console for errors
2. Resolve script compilation errors
3. Fix Missing References
4. Build again

```

If the cancellation came from SDK Validations, copy the exact red/yellow/white
message and match it in
[build-validation.md](build-validation.md#sdk-3104-world-alert-catalog).

### "Unsupported component" warnings

**Symptom**: SDK validation flags non-whitelisted scripts or components

**Solution**: Remove them, tag dev-only objects `EditorOnly`, or mark setup-helper
components with `IEditorOnly` — see
[components.md](components.md#editor-only-objects-and-components).
For broader Build Panel alert handling, use
[build-validation.md](build-validation.md).

---

## Scene Setup Issues

### Player doesn't appear at spawn point

**Symptom**: Appears at an unexpected location when joining

**Solution**:

```text

1. Check the VRC_SceneDescriptor Spawns array
2. Confirm valid Transforms are set in Spawns
3. Verify spawn positions aren't inside obstacles
4. Confirm spawn Y coordinates are above Respawn Height

```

### Player continuously respawns

**Symptom**: Keeps respawning immediately after joining

**Solution**:

```text

1. Check Respawn Height
2. Confirm spawn positions are above Respawn Height
3. Verify spawn positions aren't below the floor
4. Set Respawn Height low enough (e.g., -100)

```

### Reference Camera not taking effect

**Symptom**: Camera settings aren't being applied

**Solution**:

```text

1. Confirm the Reference Camera's Camera component is disabled
2. Verify it's correctly assigned to SceneDescriptor's Reference Camera field
3. For Post Processing, also check the Volume

```

---

## Component Issues

### Can't grab VRC_Pickup

**Symptom**: Can't interact with or grab the object

**Solution**:

```text

1. Check that a Collider exists
2. Check that a Rigidbody exists
3. Confirm VRC_Pickup's Pickupable is true
4. Verify the layer is correct (Pickup layer recommended)
5. Confirm the Collider is enabled

```

### VRC_Pickup doesn't sync

**Symptom**: Grabbed object not visible to other players

**Solution**:

```text

1. Add VRC_ObjectSync component
2. Confirm a Rigidbody exists
3. Check Is Kinematic settings

```

### Pickup grabbed but immediately released by second player

**Symptom**: A second player grabs the Pickup but it snaps back or releases immediately

**Solution**:

```text

1. Check Allow Theft on VRC_Pickup
2. If Allow Theft is disabled, the current holder owns it exclusively — a second grab is blocked
3. Enable Allow Theft if shared grabbing is intended

```

### Can't release VRC_Pickup

**Symptom**: Can't release a grabbed object

**Solution**:

```text

1. Check Auto Hold settings (SDK 3.9+)
2. Check if an Udon script is preventing Drop
3. Re-add the VRC_Pickup component

```

### Can't sit in VRC_Station

**Symptom**: Can't interact with the Station

**Solution**:

```text

1. Check that a Collider exists on the same or a child GameObject
2. Confirm VRC_Station's Disable Station Exit is false
3. If using UseAttachedStation() in Udon,
   verify the script is on the same object as the Station

```

### Player clips into Station geometry after sitting

**Symptom**: Avatar visually penetrates the seat or floor after sitting

**Solution**:

```text

1. Adjust the Station Enter Player Location transform on the VRC_Station
2. Move Station Enter Player Location to an unobstructed seated position
3. Ensure Station Exit Player Location is also clear of obstacles

```

### Can't exit VRC_Station

**Symptom**: Can't exit after sitting

**Solution**:

```text

1. If Disable Station Exit is true, set it to false
2. Verify Station Exit Player Location isn't inside an obstacle
3. Implement forced exit in Udon

```

### VRC_Mirror doesn't reflect

**Symptom**: Nothing displays in the mirror

**Solution**:

```text

1. Open VRC_MirrorReflection > Layers. Must include:
   - Player (9)
   - PlayerLocal (10)
   - MirrorReflection (18)
   - Environment (11)
2. Confirm the mirror GameObject is enabled
3. Check the camera's Near/Far Clip
4. Check mirror resolution

```

### VRC_ObjectSync is misaligned

**Symptom**: Synced object position differs between players

**Solution**:

```text

1. Call FlagDiscontinuity() on teleport
2. Check Allow Collision Ownership Transfer settings
3. Avoid frequent ownership transfers

```

---

## Layer & Collision Issues

### Player walks through walls

**Symptom**: Passes through walls or objects

**Solution**:

```text

1. Set walls to Environment layer
2. Confirm a Collider exists
3. Check Collider's Is Trigger is false
4. Verify Player and Environment collide in Collision Matrix

```

### Pickup falls through floor

**Symptom**: Dropped objects fall through the floor

**Solution**:

```text

1. Set Pickup to Pickup layer
2. Set floor to Environment layer
3. Verify Pickup and Environment collide in Collision Matrix
4. Set Rigidbody's Collision Detection to Continuous

```

### Object not visible in mirror

**Symptom**: Specific objects don't appear in the mirror

**Solution**:

```text

1. Check the object's layer
2. Verify relationship with MirrorReflection layer
3. Confirm the object's Renderer is enabled

```

---

## Performance Issues

### Low FPS

**Symptom**: Low frame rate

**Solution**:

```text

1. Set mirror to default OFF
2. Reduce/remove realtime lights
3. Bake lights
4. Check video player count (1-2 recommended)
5. Reduce Draw Calls
6. Reduce polygon count
7. Lower texture resolution

```

### Mirror is slow

**Symptom**: FPS drops drastically when mirror is enabled

**Solution**:

```text

1. Lower mirror resolution
2. Limit to 1 mirror
3. Default OFF with toggle
4. Implement auto-disable by distance

```

### Lighting is slow

**Symptom**: FPS drops near lights

**Solution**:

```text

1. Remove realtime lights
2. Change to Mixed or Baked
3. Bake lightmaps
4. Place Light Probes
5. Lower shadow quality

```

---

## Networking Issues

### Object ownership won't transfer

**Symptom**: SetOwner doesn't work

**Solution**:

```csharp

// Correct call:
Networking.SetOwner(Networking.LocalPlayer, gameObject);

// If VRC_ObjectSync is present:
// Check Allow Collision Ownership Transfer settings

```

### Pickup returns to original position on drop

**Symptom**: Dropped object snaps back to its original position for remote players

**Solution**:

```csharp

// Ownership is not being transferred. Call SetOwner before moving:
Networking.SetOwner(Networking.LocalPlayer, gameObject);

// Without ownership transfer, only the local client moves the object
// and it snaps back when the local client releases it.

```

### State doesn't sync for Late Joiners

**Symptom**: State not reflected for players who join later

**Solution**:

```csharp

// Apply state in OnDeserialization
public override void OnDeserialization()
{
    ApplyState();
}

// VRC_ObjectSync auto-syncs
// For Udon variables, use [UdonSynced] attribute

```

---

## Quest/Android Issues

### World doesn't display on Quest

**Symptom**: Works on PC but not on Quest

**Solution**:

```text

1. Verify with Android build target
2. Change shaders to Mobile-compatible
3. Remove Dynamic Bones (disabled on Quest)
4. Remove Cloth (disabled on Quest)
5. Remove Post Processing (disabled on Quest)
6. Reduce polygon count (recommended under 100K)

```

### Poor performance on Quest

**Symptom**: Low FPS on Quest

**Solution**:

```text

1. Polygon count: Under 100K
2. Material count: Under 25
3. Textures: 1024x1024 or less
4. Lights: Fully baked
5. Shaders: Mobile/VRChat/Lightmapped
6. Minimize transparency
7. Remove or minimize mirrors

```

---

## Investigation Steps

### Steps for Investigating Unknown Errors

#### Step 1: Check Unity Console

```text

Window > General > Console
- Prioritize errors (red)
- Also check warnings (yellow)
- Identify the source from the stack trace

```

#### Step 2: VRChat SDK Validation

```text

VRChat SDK > Show Control Panel
Builder tab > Validations section
- Auto-fixable issues have buttons for fixing
- Follow instructions for manual fixes
- For exact SDK 3.10.4 red/yellow/white alert meanings and Auto Fix side effects,
  use references/build-validation.md

```

#### Step 3: Build and Test

```text

VRChat SDK > Show Control Panel
Builder tab > "Build & Test New Build"
- Multi-player test with Number of Clients
- Check debug information inside VRChat

```

#### Step 4: Search Official Documentation (WebSearch)

```yaml

WebSearch: "error message or keyword site:creators.vrchat.com"

```

#### Step 5: VRChat Forums Search (WebSearch)

```yaml

WebSearch:
  query: "error message site:ask.vrchat.com"
  allowed_domains: ["ask.vrchat.com"]

```

#### Step 6: Canny (Known Bugs) Search

```yaml

WebSearch:
  query: "issue site:feedback.vrchat.com"
  allowed_domains: ["feedback.vrchat.com"]

```

#### Step 7: GitHub Issues Search

```yaml

WebSearch:
  query: "issue site:github.com/vrchat-community"
  allowed_domains: ["github.com"]

```

---

## Editor / Runtime Discrepancy

### World works in Unity Editor but fails in VRChat

**Symptom**: Behavior in Editor Play mode differs from actual VRChat client

**Solution**:

```text

Unity Play mode does not replicate all SDK behaviors.
Use "Build & Test New Build" (VRChat SDK > Builder tab) to launch the actual
VRChat client locally. Editor Play is useful only for quick UdonSharp iteration.

```

### Interactive UI element is visible but cannot be clicked in VRChat

**Symptom**: Canvas UI renders but is not interactive in VRChat

**Solution**:

```text

VRC_UIShape requires World Space Canvas.
Screen Space and Overlay modes throw a runtime Unity error in VRChat —
the UI renders visually but is not interactive, with no visible error.

Fix: Set Canvas > Render Mode to World Space before adding VRC_UIShape.

```

---

## Quick Reference: Error → Solution

| Error/Issue | Solution |
|-------------|----------|
| Missing SceneDescriptor | Add VRCWorld Prefab |
| Layer Matrix warning | Check `build-validation.md`, then run "Setup Layers for VRChat" and review custom layers |
| Can't grab Pickup | Add Collider + Rigidbody |
| Pickup doesn't sync | Add VRC_ObjectSync |
| Can't sit in Station | Add Collider |
| Mirror doesn't reflect | Check layers |
| Walking through walls | Environment layer |
| Low FPS | Mirror OFF, bake lights |
| Doesn't work on Quest | Use Mobile shaders |
| Late Joiner sync | Apply in OnDeserialization |
| SDK Build Panel warning | Match exact message in `build-validation.md` |

---

## Resources

- [VRChat Creators](https://creators.vrchat.com/worlds/)
- [VRChat Forums](https://ask.vrchat.com/)
- [VRChat Canny](https://feedback.vrchat.com/)
- [SDK Release Notes](https://creators.vrchat.com/releases/)
