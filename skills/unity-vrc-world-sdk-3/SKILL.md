---
name: unity-vrc-world-sdk-3
description: >
    VRChat World SDK 3 scene setup and optimization guide.
    Use this skill when configuring VRChat world scenes, placing SDK components,
    setting up layers, optimizing performance, or uploading worlds.
    Covers VRC_SceneDescriptor, spawn points, VRC_Pickup, VRC_Station,
    VRC_Mirror, VRC_ObjectSync, VRC_CameraDolly, layer/collision matrix,
    baked lighting, Quest/Android limits, and upload workflow.
    SDK 3.7.1 - 3.10.2 coverage.
    Triggers on: VRChat world, VRC SDK, scene setup, VRC_SceneDescriptor,
    spawn point, VRC_Pickup, VRC_Station, VRC_ObjectSync, layer setup,
    optimization, Quest support, light baking, upload, FPS improvement.
    Related: Use unity-vrc-udon-sharp for UdonSharp C# coding.
license: MIT
metadata:
    author: niaka3dayo
    version: "1.2.1"
    tags: vrchat, world-sdk, scene-setup, optimization, components, upload
---

# VRChat World SDK 3 Guide

## Table of Contents

| Section                                    | Content                    | Reference                       |
| ------------------------------------------ | -------------------------- | ------------------------------- |
| [Scene Setup](#scene-setup)                | VRC_SceneDescriptor, Spawn | This file                       |
| [Components](#components)                  | Pickup, Station, Mirror    | `references/components.md`      |
| [Layers & Collision](#layers--collision)   | Layers, Collision Matrix   | `references/layers.md`          |
| [Performance](#performance)                | Optimization guide         | `references/performance.md`     |
| [Lighting](#lighting)                      | Lighting settings          | `references/lighting.md`        |
| [Audio & Video](#audio--video)             | Audio, Video players       | `references/audio-video.md`     |
| [World Upload](#world-upload)              | Upload workflow            | `references/upload.md`          |
| [Troubleshooting](#troubleshooting)        | Problem solving            | `references/troubleshooting.md` |
| [Cheatsheet](CHEATSHEET.md)               | Quick reference            | `CHEATSHEET.md`                 |

---

## SDK Versions

**Supported versions**: SDK 3.7.1 - 3.10.2 (as of March 2026)

| SDK    | New Features                                                                   | Status         |
| ------ | ------------------------------------------------------------------------------ | -------------- |
| 3.7.1  | StringBuilder, Regex, System.Random                                            | ✅             |
| 3.7.4  | **Persistence API** (PlayerData/PlayerObject)                                  | ✅             |
| 3.7.6  | **Multi-platform Build & Publish** (simultaneous PC + Android builds)          | ✅             |
| 3.8.0  | PhysBone dependency sorting, **Force Kinematic On Remote**, Drone API          | ✅             |
| 3.8.1  | **[NetworkCallable]** events with parameters, `Others`/`Self` targets          | ✅             |
| 3.9.0  | **Camera Dolly API**, Auto Hold simplification, VRCCameraSettings              | ✅             |
| 3.10.0 | **Dynamics for Worlds** (PhysBones, Contacts, VRC Constraints)                 | ✅             |
| 3.10.1 | Bug fixes and stability improvements                                           | ✅             |
| 3.10.2 | EventTiming extensions, PhysBones fixes, shader time globals                   | ✅ Latest stable |

> **Important**: SDK versions below 3.9.0 are **deprecated as of December 2, 2025**. New world uploads are no longer possible with these versions.

---

## Scene Setup

### VRC_SceneDescriptor (Required)

Exactly **one** is required in every VRChat world.

```
[VRCWorld Prefab]
├── VRC_SceneDescriptor (Required)
├── VRC_PipelineManager (Auto-added)
├── VRCWorldSettings (Optional - movement speed settings)
└── AvatarScalingSettings (Optional - avatar scale limits)
```

#### All Properties

| Property                        | Type        | Description                     | Default           |
| ------------------------------- | ----------- | ------------------------------- | ------------------ |
| **Spawns**                      | Transform[] | Array of spawn points           | Descriptor position |
| **Spawn Order**                 | enum        | Sequential/Random/Demo          | Sequential         |
| **Respawn Height**              | float       | Respawn height (Y axis)         | -100               |
| **Object Behaviour At Respawn** | enum        | Respawn/Destroy                 | Respawn            |
| **Reference Camera**            | Camera      | Player camera settings reference | None              |
| **Forbid User Portals**         | bool        | Disable user portals            | false              |
| **Voice Falloff Range**         | float       | Voice attenuation range         | -                  |
| **Interact Passthrough**        | LayerMask   | Interact passthrough layers     | Nothing            |
| **Maximum Capacity**            | int         | Max player count (hard limit)   | -                  |
| **Recommended Capacity**        | int         | Recommended player count (UI)   | -                  |

#### Spawn Order Behavior

```
Sequential: 0 → 1 → 2 → 0 → 1 → 2... (in order)
Random:     Random selection
Demo:       All players spawn at Spawns[0]
```

#### Reference Camera Usage

```csharp
// Usage:
// 1. Adjust Near/Far clipping (recommended for VR: 0.01 ~ 1000)
// 2. Apply Post Processing effects
// 3. Set background color

// Setup steps:
// 1. Create a Camera (name: "ReferenceCamera")
// 2. Adjust Camera component settings
// 3. Disable the Camera (uncheck the component)
// 4. Assign it to VRC_SceneDescriptor's Reference Camera
```

### Spawn Points Setup

```csharp
// Setup steps:
// 1. Create an empty GameObject
// 2. Set position and rotation (players face the Z+ direction)
// 3. Add to the VRC_SceneDescriptor Spawns array

// Recommendations:
// - At least 2-3 spawn points (for simultaneous joins)
// - Slightly above the floor (~0.1m)
// - Clear of obstacles
// - Account for VR player guardian boundaries
```

### Required Setup Checklist

```
□ Exactly one VRCWorld Prefab exists in the scene
□ At least one Transform set in Spawns
□ Respawn Height set to an appropriate value (well below the floor)
□ Reference Camera configured for clipping distances (for VR)
□ Layer/Collision Matrix correctly configured
□ "Setup Layers for VRChat" has been executed
```

---

## Components

| Component                  | Required Elements        | Purpose                        | SDK  |
| -------------------------- | ------------------------ | ------------------------------ | ---- |
| **VRC_SceneDescriptor**    | -                        | World settings (required)      | -    |
| **VRC_Pickup**             | Collider + Rigidbody     | Grabbable objects              | -    |
| **VRC_Station**            | Collider                 | Sittable locations             | -    |
| **VRC_ObjectSync**         | Rigidbody                | Auto-sync Transform/physics    | -    |
| **VRC_MirrorReflection**   | -                        | Mirror (⚠️ high cost)         | -    |
| **VRC_PortalMarker**       | -                        | Portal to other worlds         | -    |
| **VRC_SpatialAudioSource** | AudioSource              | 3D audio                       | -    |
| **VRC_UIShape**            | Canvas (World Space)     | Unity UI interaction           | -    |
| **VRC_AvatarPedestal**     | -                        | Avatar display/switch          | -    |
| **VRC_CameraDolly**        | -                        | Camera dolly                   | 3.9+ |

### VRC_ObjectSync vs UdonSynced

| Scenario                        | VRC_ObjectSync | UdonSynced variables |
| ------------------------------- | -------------- | -------------------- |
| Throwable objects / physics     | ✅ Recommended | ❌                   |
| State only / complex logic      | ❌             | ✅ Recommended       |

> **SDK 3.8.0+**: `Force Kinematic On Remote` — Makes Rigidbody kinematic on non-owner clients, preventing unexpected physics behavior.

**→ For detailed properties, Udon events, and code examples, see `references/components.md`**

---

## Layers & Collision

### VRChat Reserved Layers

| Layer #   | Name                | Purpose                        |
| --------- | ------------------- | ------------------------------ |
| 0         | Default             | General objects                |
| 9         | Player              | Remote players                 |
| 10        | PlayerLocal         | Local player                   |
| 11        | Environment         | Environment (walls, floors)    |
| 13        | Pickup              | Grabbable objects              |
| 14        | PickupNoEnvironment | Pickups that don't collide with environment |
| 17        | Walkthrough         | Walk-through objects           |
| 18        | MirrorReflection    | Mirror reflection only         |
| **22-31** | **User Layers**     | **Available for custom use**   |

### Layer Setup Steps

```
1. VRChat SDK > Show Control Panel
2. Builder tab
3. Click "Setup Layers for VRChat"
4. Collision Matrix is automatically configured
```

**→ For details, see `references/layers.md`**

---

## Performance

### Target FPS

| Platform   | FPS Target | Measurement Point      |
| ---------- | ---------- | ---------------------- |
| PC VR      | 45+ FPS    | Spawn point, 1 player  |
| PC Desktop | 60+ FPS    | Spawn point, 1 player  |
| Quest      | 72 FPS     | Spawn point, 1 player  |

### Critical Limits

| Item                | Recommended           | Reason                        |
| ------------------- | --------------------- | ----------------------------- |
| Mirrors             | 1, default OFF        | Renders the entire scene 2x   |
| Video players       | Max 2                 | Decoding overhead             |
| Realtime lights     | 0-1                   | Dynamic shadows are expensive  |
| Lightmaps           | **Required**          | Performance foundation         |

### Quest/Android Restrictions

| Component          | PC  | Quest         |
| ------------------ | --- | ------------- |
| Dynamic Bones      | ✅  | ❌ Disabled   |
| Cloth              | ✅  | ❌ Disabled   |
| Post-Processing    | ✅  | ❌ Disabled   |
| Unity Constraints  | ✅  | ❌ Disabled   |
| Realtime lights    | ✅  | ⚠️ Avoid     |

**→ For details, see `references/performance.md`**

---

## Lighting

### Baked Lighting (Required)

```
✅ Recommended settings:
├── Lightmapper: Progressive GPU
├── Lightmap Resolution: 10-20 texels/unit
├── Light Mode: Baked or Mixed
└── Light Probes: Place along player paths

❌ Avoid:
├── Realtime lights (dynamic shadows)
├── High-resolution lightmaps (memory consumption)
└── Excessive Reflection Probes
```

**→ For details, see `references/lighting.md`**

---

## Audio & Video

### VRC_SpatialAudioSource

| Property              | Description           | Default            |
| --------------------- | --------------------- | ------------------ |
| Gain                  | Volume (dB)           | 0 (World: +10)    |
| Near                  | Attenuation start     | 0m                 |
| Far                   | Attenuation end       | 40m                |
| Volumetric Radius     | Source spread          | 0m                 |
| Enable Spatialization | 3D positioning        | true               |

### Video Player Selection

| Feature            | AVPro | Unity Video |
| ------------------ | ----- | ----------- |
| Live streaming     | ✅    | ❌          |
| Editor preview     | ❌    | ✅          |
| YouTube/Twitch     | ✅    | ❌          |
| Quest support      | ✅    | ✅          |

**→ For details, see `references/audio-video.md`**

---

## World Upload

### Upload Steps

```
1. Check Validation
   └── VRChat SDK > Build Panel > Validations

2. Build & Test (local testing)
   └── "Build & Test New Build"
   └── Supports multi-client testing

3. Upload
   └── "Build and Upload"
   └── Set Content Warnings
   └── Set Capacity

4. Publish settings
   └── Configure public/private on the VRChat website
```

### Pre-Upload Checklist

```
□ VRC_SceneDescriptor × 1
□ Spawns configured
□ Respawn Height appropriate
□ Layer/Collision Matrix verified
□ Light baking complete
□ Mirror default OFF
□ 45+ FPS in VR
□ No Validation errors
□ Content Warnings set
□ Capacity set
```

**→ For details, see `references/upload.md`**

---

## Troubleshooting

### Common Issues

| Issue                           | Cause                      | Solution                   |
| ------------------------------- | -------------------------- | -------------------------- |
| Player walks through walls      | Wrong layer                | Set to Environment         |
| Can't grab Pickup               | Missing Collider/Rigidbody | Add both                   |
| Pickup doesn't sync             | Missing ObjectSync         | Add VRC_ObjectSync         |
| Can't sit in Station            | Missing Collider           | Add Collider               |
| Mirror doesn't reflect          | Layer settings             | Check MirrorReflection     |
| Build error                     | Validation failure         | Check SDK Panel            |

**→ For details, see `references/troubleshooting.md`**

---

## Related Skills

| Task                     | Skill to Use              |
| ------------------------ | ------------------------- |
| C# code creation         | `unity-vrc-udon-sharp`    |
| Network sync (Udon)      | `unity-vrc-udon-sharp`    |
| Event implementation     | `unity-vrc-udon-sharp`    |
| Scene setup              | **This skill**            |
| Component placement      | **This skill**            |
| Performance optimization | **This skill**            |

---

## Web Search

### Official Documentation (WebSearch)

```
# Search official documentation
WebSearch: "component or feature to look up site:creators.vrchat.com"
```

### Issue Investigation (WebSearch)

```
# Step 1: Forum search
WebSearch:
  query: "issue description site:ask.vrchat.com"
  allowed_domains: ["ask.vrchat.com"]

# Step 2: Known bug search
WebSearch:
  query: "issue description site:feedback.vrchat.com"
  allowed_domains: ["feedback.vrchat.com"]

# Step 3: GitHub Issues
WebSearch:
  query: "issue description site:github.com/vrchat-community"
```

### Official Resources

| Resource          | URL                                   |
| ----------------- | ------------------------------------- |
| VRChat Creators   | https://creators.vrchat.com/worlds/   |
| VRChat Forums     | https://ask.vrchat.com/               |
| VRChat Canny      | https://feedback.vrchat.com/          |
| SDK Release Notes | https://creators.vrchat.com/releases/ |

---

## References

| File                            | Content                   | Approx. Lines |
| ------------------------------- | ------------------------- | ------------- |
| `references/components.md`      | All component details     | 800+          |
| `references/layers.md`          | Layers & collision        | 400+          |
| `references/performance.md`     | Performance optimization  | 500+          |
| `references/lighting.md`        | Lighting settings         | 400+          |
| `references/audio-video.md`     | Audio & video             | 400+          |
| `references/upload.md`          | Upload procedure          | 300+          |
| `references/troubleshooting.md` | Troubleshooting guide     | 500+          |
| `CHEATSHEET.md`                 | Quick reference           | 200+          |
