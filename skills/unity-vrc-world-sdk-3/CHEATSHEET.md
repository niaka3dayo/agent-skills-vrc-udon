# VRC World SDK 3 Cheatsheet

**SDK 3.7.1 - 3.10.4 supported**

---

## Table of Contents

| Section | Content |
|---------|---------|
| [Scene Setup](#scene-setup) | VRCWorld, Spawns, Respawn |
| [Components](#components) | Pickup, Station, ObjectSync, Contacts, PhysBones |
| [Layers](#layers) | Layer numbers and purposes |
| [Performance](#performance) | Limits and optimization |
| [Lighting](#lighting) | Bake settings |
| [Audio/Video](#audiovideo) | Audio and video |
| [Upload](#upload) | Upload procedure |

---

## Scene Setup

### Checklist

```text
□ VRCWorld prefab × 1
□ Spawns configured
□ Respawn Height set (below the floor)
□ "Setup Layers for VRChat" executed
□ Light baking complete
□ 45+ FPS (VR)
```

### VRC_SceneDescriptor

| Property | Description | Default |
|----------|-------------|---------|
| Spawns | Array of spawn points | Descriptor position |
| Spawn Order | First/Sequential/Random/Demo | Sequential |
| Respawn Height | Respawn Y coordinate | -100 |
| Reference Camera | Camera settings reference | None |
| Maximum Capacity | Max player count | - |
| Recommended Capacity | Recommended player count | - |

### Spawn Order

```text
First:      Always the first spawn
Sequential: 0 → 1 → 2 → 0 → 1 (in order)
Random:     Random selection
Demo:       Spawn point = center of room scale
```

---

## Components

### Required Elements

| Component | Collider | Rigidbody | Purpose |
|-----------|----------|-----------|---------|
| VRC_SceneDescriptor | - | - | World settings |
| VRC_Pickup | Required | Required | Grabbable |
| VRC_Station | Required | - | Sittable |
| VRC_ObjectSync | - | Required | Physics sync |
| VRC_Mirror | - | - | Mirror |

### VRC_Pickup Setup

```text
[GameObject]
├── Collider (IsTrigger recommended)
├── Rigidbody
├── VRC_Pickup
│   ├── Auto Hold: Yes/No (v1.1; AutoDetect is v1.0-only)
│   ├── Pickupable: true
│   └── Allow Theft: true
└── VRC_ObjectSync (for sync)
```

**Events:**
```csharp
OnPickup()           // When grabbed
OnDrop()             // When released
OnPickupUseDown()    // Trigger pressed
OnPickupUseUp()      // Trigger released
```

### VRC_Station Setup

```text
[GameObject]
├── Collider
└── VRC_Station
    ├── Player Mobility: Mobile/Immobilize
    ├── Disable Station Exit: false
    └── Station Enter/Exit Player Location
```

**Udon:**
```csharp
Networking.LocalPlayer.UseAttachedStation();

OnStationEntered(VRCPlayerApi player)
OnStationExited(VRCPlayerApi player)
```

### VRC_ObjectSync

```csharp
VRCObjectSync sync = (VRCObjectSync)GetComponent(typeof(VRCObjectSync));

sync.Respawn();           // Reset to initial position
sync.SetGravity(true);    // Gravity setting
sync.SetKinematic(false); // Physics setting
sync.FlagDiscontinuity(); // On teleport (skip interpolation)
```

### VRC_Mirror

```csharp
// Default OFF + toggle
void Start() => mirrorObject.SetActive(false);

public override void Interact()
{
    mirrorObject.SetActive(!mirrorObject.activeSelf);
}
```

### Contacts (SDK 3.10.4)

```text
VRC Contact Sender / VRC Contact Receiver shapes:
- Sphere: Radius
- Capsule: Radius + Height
- Box: Box Size X/Y/Z axes

Limits are applied after transform scale:
- Sphere/Capsule radius ≤ 3 m
- Box width/height/depth ≤ 6 m

Box-shaped Contact Receiver:
- Use Face Proximity = proximity to the local positive-Z face
```

For Contact Sender / Contact Receiver Udon events and APIs, use
`../../unity-vrc-udon-sharp/references/dynamics.md` instead of this world authoring sheet.

### PhysBones / Global Collision (SDK 3.10.4)

```text
VRCPhysBoneCollider Global Collision:
- World PhysBones can collide with avatar-origin globals when Allow Collision permits
- Avatars can add up to 4 additional global PhysBone colliders
- Worlds have no documented global collider count limit
- Global Collision supports Sphere/Capsule only
- PhysBone Allow Collision rules still apply

World Udon can edit VRCPhysBoneCollider settings; call
ApplyConfigurationChanges() after batched configuration changes.
```

---

## Layers

### VRChat Reserved Layers

| # | Name | Purpose |
|---|------|---------|
| 0 | Default | General objects |
| 9 | Player | Remote players |
| 10 | PlayerLocal | Local player |
| 11 | Environment | Walls, floors |
| 13 | Pickup | Grabbable objects |
| 14 | PickupNoEnvironment | Pickups that pass through walls |
| 17 | Walkthrough | Walk-through objects |
| 18 | MirrorReflection | Mirror only |
| **22-31** | **User** | **Available for custom use** |

### Layer Masks (Udon)

```csharp
// Get layer mask
int playerMask = 1 << 9;
int envMask = 1 << LayerMask.NameToLayer("Environment");

// Multiple layers
int combined = (1 << 9) | (1 << 11);

// Exclude
int exceptPlayer = ~(1 << 9);

// Raycast
Physics.Raycast(origin, dir, out hit, distance, playerMask);
```

---

## Performance

### Limits

| Item | PC | Quest |
|------|-----|-------|
| FPS Target | 45+ VR, 60+ Desktop | 72 |
| Mirrors | 1 (default OFF) | 0-1 |
| Video Players | 1-2 recommended | 1 recommended |
| Realtime Lights | 0-1 | 0 |
| Polygons | 500K-1M | 50K-100K |
| Materials | No limit | 25 or less |
| Texture Size | No limit | 1024 or less |

### Quest Restrictions

| Feature | PC | Quest |
|---------|-----|-------|
| Dynamic Bones | ✅ | ❌ |
| Cloth | ✅ | ❌ |
| Post-Processing | ✅ | ❌ |
| Unity Constraints | ✅ | ❌ |
| Realtime Shadows | ✅ | ⚠️ |

### Optimization Checklist

```text
□ Light baking complete
□ Realtime lights ≤ 1
□ Mirror default OFF
□ Video players kept to 1-2 (recommended)
□ Static Batching enabled
□ Occlusion Culling configured
□ LOD configured
```

---

## Lighting

### Quick Setup

```text
✅ DO:
├── Lightmapper: Progressive GPU
├── Light Mode: Baked / Mixed
├── Light Probes placed
└── Reflection Probes placed

❌ DON'T:
├── Overuse Realtime lights
├── High-resolution lightmaps
└── Overuse dynamic shadows
```

### Lightmap Settings

| Setting | PC | Quest |
|---------|-----|-------|
| Resolution | 20 texels/unit | 10 |
| Size | 2048 | 1024 |
| Directional | Directional | Non-Directional |
| Compress | ✅ | ✅ |

### Light Probes

```text
Placement locations:
✅ Where players walk
✅ Light/dark boundaries
✅ Indoor/outdoor boundaries
✅ Distribute vertically as well

Do NOT place:
❌ Inside walls
❌ Unreachable areas
```

---

## Audio/Video

### VRC_SpatialAudioSource

Pair world `AudioSource` components with `VRC_SpatialAudioSource` to avoid SDK Build Panel warnings. For warning-only additions, use Gain 0 dB and preserve existing `volume`, `spatialBlend`, rolloff, max distance, custom curves, and 2D/3D intent.

| Property | Baseline | Safe-preserve note |
|----------|----------|--------------------|
| Gain | 10 dB common default | Use 0 dB when adding only to avoid a warning |
| Near | 0 m | Keep 0 m unless `minDistance` / Near was authored |
| Far | Per use case | Match `maxDistance` or intended audible range; avoid wider Auto Fix ranges |
| Volumetric Radius | 0 m | Set intentionally for wide sources |
| Enable Spatialization | true for 3D | false for intentional 2D/global audio |
| Use AudioSource Volume Curve | false common default | true when preserving authored 3D rolloff |

### Video Player Comparison

| Feature | AVPro | Unity |
|---------|-------|-------|
| YouTube/Twitch | ✅ | ❌ |
| Live Stream | ✅ | ❌ |
| Editor Preview | ❌ | ✅ |
| Quest | ✅ | ✅ |

### Video Events

```csharp
OnVideoStart()
OnVideoEnd()
OnVideoError(VideoError error)
OnVideoReady()
```

### Audio Compression

| Type | Load Method | Quality |
|------|------------|---------|
| BGM | Streaming | 70% |
| SFX | Decompress | 50-70% |
| Ambient | Compressed | 50% |

---

## Upload

### Pre-Upload Checklist

```text
□ VRC_SceneDescriptor × 1
□ Spawns configured
□ Respawn Height appropriate
□ Layer/Collision verified
□ Lights baked
□ Mirror OFF default
□ 45+ FPS (VR)
□ No Validation errors
```

### Upload Procedure

```text
1. VRChat SDK > Show Control Panel
2. Builder tab
3. Check & fix Validations
4. Build & Test (local testing)
5. Build & Upload
6. World Settings
   - Name / Description
   - Content Warnings
   - Capacity
7. Upload
8. Verify on VRChat website
```

### Capacity Guidelines

| World Size | Recommended | Maximum |
|------------|-------------|---------|
| Small | 8-16 | 20-32 |
| Medium | 20-32 | 40-64 |
| Large | 40-80 | 80+ |

### Content Warnings

```text
□ Adult Language
□ Blood/Gore
□ Fear/Horror
□ Nudity/Suggestive
□ Substance Use
□ Violence
```

---

## Troubleshooting Quick Reference

| Issue | Solution |
|-------|----------|
| Player walks through walls | Layer → Environment |
| Can't grab Pickup | Add Collider + Rigidbody |
| Pickup doesn't sync | Add VRC_ObjectSync |
| Can't sit in Station | Add Collider |
| Mirror doesn't reflect | Check layers |
| Low FPS | Turn off mirror, bake lights |
| Doesn't work on Quest | Use Mobile shaders |
| Build error | Check Validation |
| World not found after upload | Change to Public |

---

## Official Docs & Issue Investigation (WebSearch)

```bash
# VRChat Forums
site:ask.vrchat.com "issue keyword"

# Bug reports & feature requests
site:feedback.vrchat.com "issue keyword"

# GitHub
site:github.com/vrchat-community "issue keyword"
```

---

## SDK Version Features

| SDK | Key Features |
|-----|-------------|
| 3.7.4 | Persistence API |
| 3.8.1 | [NetworkCallable] |
| 3.9.0 | Camera Dolly, Auto Hold |
| 3.10.0 | Dynamics (PhysBones, Contacts) |
| 3.10.4 | Box-shaped Contact Sender/Receiver authoring updates |

---

## Reference Index

| Topic | File |
|-------|------|
| Performance targets, Quest optimization checklist | [references/performance.md](references/performance.md) |
| Lightmap settings, Quest bake parameter reference | [references/lighting.md](references/lighting.md) |
| Full SDK 3.7.1-3.10.4 world component reference | [references/components.md](references/components.md) |
| VRChat layer system, collision, and selective rendering reference | [references/layers.md](references/layers.md) |
| Audio and video configuration, voice settings, Steam Audio, and video players | [references/audio-video.md](references/audio-video.md) |
| Upload procedure, pre-upload checklist, validation, world settings, and post-upload steps | [references/upload.md](references/upload.md) |
| Build/upload, scene setup, component, layer, performance, networking, and Quest troubleshooting | [references/troubleshooting.md](references/troubleshooting.md) |
| Pickup + Rigidbody template | [assets/templates/VRC_Pickup_Rigidbody.cs](assets/templates/VRC_Pickup_Rigidbody.cs) |
| Station (sit) template | [assets/templates/VRC_Station_Basic.cs](assets/templates/VRC_Station_Basic.cs) |
