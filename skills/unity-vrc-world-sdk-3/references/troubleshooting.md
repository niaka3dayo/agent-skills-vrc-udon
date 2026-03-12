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
```
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

### World not found after upload

**Symptom**: Upload succeeded but world doesn't appear

**Solution**:
```
1. Log in to the VRChat website
2. Check "My Worlds"
3. Check privacy settings
4. Wait a few minutes (may take time to propagate)
5. Restart the VRChat client
```

### "Build was cancelled"

**Symptom**: Build was cancelled

**Solution**:
```
1. Check Unity Console for errors
2. Resolve script compilation errors
3. Fix Missing References
4. Build again
```

---

## Scene Setup Issues

### Player doesn't appear at spawn point

**Symptom**: Appears at an unexpected location when joining

**Solution**:
```
1. Check the VRC_SceneDescriptor Spawns array
2. Confirm valid Transforms are set in Spawns
3. Verify spawn positions aren't inside obstacles
4. Confirm spawn Y coordinates are above Respawn Height
```

### Player continuously respawns

**Symptom**: Keeps respawning immediately after joining

**Solution**:
```
1. Check Respawn Height
2. Confirm spawn positions are above Respawn Height
3. Verify spawn positions aren't below the floor
4. Set Respawn Height low enough (e.g., -100)
```

### Reference Camera not taking effect

**Symptom**: Camera settings aren't being applied

**Solution**:
```
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
```
1. Add VRC_ObjectSync component
2. Confirm a Rigidbody exists
3. Check Is Kinematic settings
```

### Can't release VRC_Pickup

**Symptom**: Can't release a grabbed object

**Solution**:
```
1. Check Auto Hold settings (SDK 3.9+)
2. Check if an Udon script is preventing Drop
3. Re-add the VRC_Pickup component
```

### Can't sit in VRC_Station

**Symptom**: Can't interact with the Station

**Solution**:
```
1. Check that a Collider exists
2. Confirm VRC_Station's Disable Station Exit is false
3. If using UseAttachedStation() in Udon,
   verify the script is on the same object as the Station
```

### Can't exit VRC_Station

**Symptom**: Can't exit after sitting

**Solution**:
```
1. If Disable Station Exit is true, set it to false
2. Verify Exit Transform isn't inside an obstacle
3. Implement forced exit in Udon
```

### VRC_Mirror doesn't reflect

**Symptom**: Nothing displays in the mirror

**Solution**:
```
1. Check MirrorReflection layer settings
2. Confirm the mirror is enabled
3. Check the camera's Near/Far Clip
4. Check mirror resolution
```

### VRC_ObjectSync is misaligned

**Symptom**: Synced object position differs between players

**Solution**:
```
1. Call FlagDiscontinuity() on teleport
2. Check Allow Collision Ownership Transfer settings
3. Avoid frequent ownership transfers
```

---

## Layer & Collision Issues

### Player walks through walls

**Symptom**: Passes through walls or objects

**Solution**:
```
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
```
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
4. Check video player count (max 2)
5. Reduce Draw Calls
6. Reduce polygon count
7. Lower texture resolution
```

### Mirror is slow

**Symptom**: FPS drops drastically when mirror is enabled

**Solution**:
```
1. Lower mirror resolution
2. Limit to 1 mirror
3. Default OFF with toggle
4. Implement auto-disable by distance
```

### Lighting is slow

**Symptom**: FPS drops near lights

**Solution**:
```
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

```
Window > General > Console
- Prioritize errors (red)
- Also check warnings (yellow)
- Identify the source from the stack trace
```

#### Step 2: VRChat SDK Validation

```
VRChat SDK > Show Control Panel
Builder tab > Validations section
- Auto-fixable issues have buttons for fixing
- Follow instructions for manual fixes
```

#### Step 3: Build and Test

```text
VRChat SDK > Show Control Panel
Builder tab > "Build & Test New Build"
- Multi-player test with Number of Clients
- Check debug information inside VRChat
```

#### Step 4: Search Official Documentation (WebSearch)

```
WebSearch: "error message or keyword site:creators.vrchat.com"
```

#### Step 5: VRChat Forums Search (WebSearch)

```
WebSearch:
  query: "error message site:ask.vrchat.com"
  allowed_domains: ["ask.vrchat.com"]
```

#### Step 6: Canny (Known Bugs) Search

```
WebSearch:
  query: "issue site:feedback.vrchat.com"
  allowed_domains: ["feedback.vrchat.com"]
```

#### Step 7: GitHub Issues Search

```
WebSearch:
  query: "issue site:github.com/vrchat-community"
  allowed_domains: ["github.com"]
```

---

## Quick Reference: Error → Solution

| Error/Issue | Solution |
|-------------|----------|
| Missing SceneDescriptor | Add VRCWorld Prefab |
| Layer Matrix warning | "Setup Layers for VRChat" |
| Can't grab Pickup | Add Collider + Rigidbody |
| Pickup doesn't sync | Add VRC_ObjectSync |
| Can't sit in Station | Add Collider |
| Mirror doesn't reflect | Check layers |
| Walking through walls | Environment layer |
| Low FPS | Mirror OFF, bake lights |
| Doesn't work on Quest | Use Mobile shaders |
| Late Joiner sync | Apply in OnDeserialization |

---

## Resources

- [VRChat Creators](https://creators.vrchat.com/worlds/)
- [VRChat Forums](https://ask.vrchat.com/)
- [VRChat Canny](https://feedback.vrchat.com/)
- [SDK Release Notes](https://creators.vrchat.com/releases/)
