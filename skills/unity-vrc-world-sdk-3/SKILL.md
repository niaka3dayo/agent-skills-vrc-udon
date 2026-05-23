---
name: unity-vrc-world-sdk-3
description: >
    VRChat World SDK 3 scene setup and optimization guide.
    Use this skill when configuring VRChat world scenes, placing SDK components,
    setting up layers, optimizing performance, or uploading worlds.
    Covers VRC_SceneDescriptor, spawn points, VRC_Pickup, VRC_Station,
    VRC_Mirror, VRC_ObjectSync, VRC_CameraDolly, layer/collision matrix,
    baked lighting, Quest/Android limits, and upload workflow.
    SDK 3.7.1 - 3.10.3 coverage.
    Triggers on: VRChat world, VRC SDK, scene setup, VRC_SceneDescriptor,
    spawn point, VRC_Pickup, VRC_Station, VRC_ObjectSync, layer setup,
    optimization, Quest support, light baking, upload, FPS improvement.
    Related: Use unity-vrc-udon-sharp for UdonSharp C# coding.
license: MIT
metadata:
    author: niaka3dayo
    version: "2.1.0"
    tags: vrchat, world-sdk, scene-setup, optimization, components, upload
---

# VRChat World SDK 3 Guide

## Table of Contents

| Section                                    | Content                    | Reference                       |
| ------------------------------------------ | -------------------------- | ------------------------------- |
| [Scene Setup](#scene-setup)                | VRC_SceneDescriptor, Spawn | This file                       |
| [Components](#components)                  | Pickup, Station, Mirror    | `references/components.md`      |
| [Layers & Collision](#layers-collision)   | Layers, Collision Matrix   | `references/layers.md`          |
| [Performance](#performance)                | Optimization guide         | `references/performance.md`     |
| [Lighting](#lighting)                      | Lighting settings          | `references/lighting.md`        |
| [Audio & Video](#audio-video)             | Audio, Video players       | `references/audio-video.md`     |
| [World Upload](#world-upload)              | Upload workflow            | `references/upload.md`          |
| [Troubleshooting](#troubleshooting)        | Problem solving            | `references/troubleshooting.md` |
| [Cheatsheet](CHEATSHEET.md)               | Quick reference            | `CHEATSHEET.md`                 |

---

## Common Mistakes (NEVER List)

These cause silent world failures, performance disasters, or Quest incompatibility:

| # | NEVER do this | Why it hurts | Use instead |
|---|---------------|-------------|-------------|
| 1 | Enable Mirror by default (active on world join) | Renders the entire scene twice — immediate FPS halving, catastrophic on Quest | Default Mirror OFF; add UdonSharp toggle or player-triggered activation |
| 2 | Use realtime directional lights with real-time shadows | Quest has no hardware shadow acceleration; each shadow caster costs 10-30 FPS | Baked lightmaps + light probes; set lights to Baked or Mixed mode |
| 3 | Set Respawn Height at or above the world floor | Player respawns → falls → respawns again → infinite loop; players cannot recover | Set to an unreachable depth (e.g., floor at Y=0 → Respawn at Y=-100) |
| 4 | Skip "Setup Layers for VRChat" on a new project | Layer collision matrix is wrong by default — players walk through walls, Pickups clip floors | Run VRChat SDK > Builder > "Setup Layers for VRChat" before placing any colliders |
| 5 | Enable Post-Processing without Quest build profile | Post-Processing is silently disabled at runtime on Quest but VRAM is still allocated | Use separate Android build profile or guard assets with `#if UNITY_ANDROID` |
| 6 | Place more than 2 active video players simultaneously | Each player adds significant decoding overhead; running >2 simultaneously is a common cause of frame drops and audio issues in practice | Disable extra players at scene start; activate only the currently playing one |
| 7 | Use Unity Constraints or Cloth on Quest | Both are disabled silently at runtime on Quest — animations freeze, cloth hangs in place | Use Animator-driven transforms (no constraints) or remove cloth from Quest meshes |
| 8 | Upload without completing a lightmap bake | Realtime GI calculates at runtime — 3-5× draw call overhead, unacceptable on Quest | Always bake lights before upload; Progressive GPU lightmapper is fastest |
| 9 | Place player walkable surfaces on Default layer (0) | Collision matrix is wrong by default — avatar physics collision is unreliable; players may clip through geometry | Use Environment (layer 11) for all walkable geometry, walls, and floors |
| 10 | Use very high lightmap resolution for large areas without profiling | Texture memory can spike significantly at high resolutions; a common cause of OOM crashes on mobile headsets | Start at 10-20 texels/unit as a practical guideline; profile VRAM and adjust — official guidance says "keep lightmap resolution low" for Quest |
| 11 | Add VRC_UIShape to a Screen Space or Overlay Canvas | VRC_UIShape requires World Space Canvas; other modes throw a runtime Unity error in VRChat — the UI renders visually but is not interactive, with no visible error to the world builder | Set Canvas > Render Mode to World Space before adding VRC_UIShape |

## Reference Loading Guide

Load only what the task requires.

| Task | MANDATORY READ | Optional | Do NOT Load | Load Rationale |
|------|---------------|----------|-------------|----------------|
| Setting up a new scene from scratch | `components.md`, `layers.md` | `upload.md` | `audio-video.md`, `troubleshooting.md` | Collision matrix non-obvious; component deps needed upfront |
| Making objects grabbable (VRC_Pickup) | `components.md` | `layers.md` | `audio-video.md`, `lighting.md` | Pickup/Rigidbody requirements not in standard Unity docs |
| Setting up seating (VRC_Station) | `components.md` | `layers.md` | `audio-video.md`, `performance.md` | Station collider + exit requirements are VRChat-specific |
| Optimizing FPS for Quest | `performance.md`, `lighting.md` | `troubleshooting.md` | `audio-video.md`, `upload.md` | Quest limits differ from PC; bake requirements non-obvious |
| Adding audio or video player | `audio-video.md`, `components.md` | `troubleshooting.md` | `lighting.md`, `performance.md` | AVPro vs Unity Video selection is VRChat-specific |
| Baking lights / lightmap setup | `lighting.md`, `performance.md` | — | `audio-video.md`, `layers.md` | Lightmap resolution and probe placement affect Quest VRAM |
| World upload and publish | `upload.md` | `troubleshooting.md` | `audio-video.md`, `lighting.md` | Upload steps and validation order are fragile; easy to miss |
| Debugging collision or layer issues | `layers.md`, `troubleshooting.md` | `components.md` | `audio-video.md`, `lighting.md` | VRChat collision matrix differs from Unity default |
| Mirror setup and configuration | `components.md` | `performance.md` | `audio-video.md`, `upload.md` | Mirror layer mask requirements are VRChat-specific |

## Before Starting a New World — Design Decisions

These decisions shape every downstream choice. Make them first, before placing any component.

| Decision | Options | Implication |
|---|---|---|
| **Quest required?** | Yes / No | Yes → Quest First philosophy applies from day 0, not as a retrofit |
| **Expected player count?** | 1–8 / 9–40 / 40+ | Affects spawn count, mirror policy, max video players |
| **Primary interaction?** | Grab (Pickup) / Sit (Station) / Watch (Video) / Explore | Determines which SDK components are mandatory |
| **Lighting approach?** | Baked / Mixed / Realtime | Realtime is only viable on PC-only worlds; all lights must be baked before upload |
| **Networked objects?** | None / Physics (Pickup+ObjectSync) / State (UdonSynced) | Determines sync architecture before Udon scripting begins |

---

## Design Philosophy: Quest First

**Build for Quest and get PC for free. Build for PC and Quest becomes a separate project.**

Quest (Meta Quest 2/3/Pro) defines the performance budget:
- **CPU/GPU**: ~2× slower than PC VR; tile-based GPU with no hardware shadow maps
- **VRAM**: ~4 GB shared with OS (vs 6–12 GB on PC); no HDR framebuffer
- **Thermal throttling**: Sustained 100% GPU load causes clock reduction within minutes

If a world runs at 72 FPS on Quest with a single test client, it will typically run at 90+ FPS on PC — though results vary by shader complexity, CPU-bound workloads, and hardware differences. The converse rarely holds. Verify against the [official VRChat optimization documentation](https://creators.vrchat.com/worlds/udon/performance-and-optimization/) before publishing.

**NEVER optimize exclusively for PC with "Quest support added later"** — by that point, lighting, materials, and mesh density are all locked to PC quality, and the Quest port requires rebuilding everything.

**Quest First Cascade** — when Quest is required, every downstream decision inherits constraints:

```text
Quest required? → Yes
  ├── Shaders: Mobile-only (Standard Lite, Toon Lit)
  ├── Lighting: Fully baked (no realtime shadows)
  ├── Geometry: < 50K triangles per world
  ├── Materials: < 25 unique materials
  ├── Audio: Mono, compressed, limited concurrent sources
  └── Physics: Simplified colliders, minimal Rigidbodies
```

## SDK Versions

**Supported versions**: SDK 3.7.1 - 3.10.3

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
| 3.10.2 | EventTiming extensions, PhysBones fixes, shader time globals                   | ✅             |
| 3.10.3 | `VRCPlayerApi.isVRCPlus`, VRCRaycast (avatar), Mirror render-order fix         | ✅ Latest stable |

> **Important**: SDK versions below 3.9.0 are **deprecated as of December 2, 2025**. New world uploads are no longer possible with these versions.

---

## Scene Setup

### VRC_SceneDescriptor (Required)

Exactly **one** is required in every VRChat world.

```text
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
| **Spawn Order**                 | enum        | Sequential/Random/Demo (Demo: all players to Spawns[0]) | Sequential |
| **Respawn Height**              | float       | Respawn height (Y axis)         | -100               |
| **Object Behaviour At Respawn** | enum        | Respawn/Destroy                 | Respawn            |
| **Reference Camera**            | Camera      | Player camera settings reference | None              |
| **Forbid User Portals**         | bool        | Disable user portals            | false              |
| **Voice Falloff Range**         | float       | Voice attenuation range         | -                  |
| **Interact Passthrough**        | LayerMask   | Interact passthrough layers     | Nothing            |
| **Maximum Capacity**            | int         | Max player count (hard limit)   | -                  |
| **Recommended Capacity**        | int         | Recommended player count (UI)   | -                  |

#### Reference Camera Usage

```csharp
// Usage:
// 1. Adjust Near/Far clipping (recommended for VR: 0.01 ~ 1000)
// 2. Apply Post Processing effects
// 3. Set background color

// ⚠️ MUST disable the Camera component after configuring — an active Reference Camera
//    renders a second viewport. VRChat reads only the camera settings, not its output.
// Assign the configured (disabled) Camera to VRC_SceneDescriptor > Reference Camera.
```

### Spawn Points Setup

```csharp
// Spawn points are empty GameObjects assigned to VRC_SceneDescriptor > Spawns array.
// Players enter facing the Z+ direction of the spawn Transform.

// VRChat-specific requirements:
// - At least 2-3 spawn points (for simultaneous joins — single spawn causes overlap)
// - Place slightly above the floor (~0.1m) to avoid floor collision on spawn
// - Keep clear of obstacles (VR player guardian area is larger than their avatar)
// - Account for VR guardian boundaries — desktop player sizes differ from VR
```

### Required Setup Checklist

```text
□ Exactly one VRCWorld Prefab exists in the scene
□ At least one Transform set in Spawns
□ Respawn Height set to an appropriate value (well below the floor)
□ Reference Camera configured for clipping distances (for VR)
□ Layer/Collision Matrix correctly configured
□ "Setup Layers for VRChat" has been executed
```

---

## Components

**MANDATORY READ** [`references/components.md`](references/components.md) (~800 lines) before configuring any VRC component below. Load in full — dependency requirements and Udon event hooks are distributed throughout.
**Do NOT Load**: `references/audio-video.md`, `references/lighting.md`.

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

```text
1. VRChat SDK > Show Control Panel
2. Builder tab
3. Click "Setup Layers for VRChat"
4. Collision Matrix is automatically configured
```

**MANDATORY READ** [`references/layers.md`](references/layers.md) when setting up collision or debugging physics. The default Unity collision matrix differs from the VRChat-correct one — always verify.
**Do NOT Load**: `references/audio-video.md`, `references/upload.md`.

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

### Performance Optimization Workflow

| Bottleneck Type | Key Indicators | Reference |
|----------------|---------------|-----------|
| CPU-bound | High script time, physics overhead | [performance.md](references/performance.md#optimization-workflow) §Optimization-Workflow |
| GPU-bound | Draw calls, overdraw, shader complexity | [performance.md](references/performance.md#optimization-workflow) §Optimization-Workflow |
| Memory | VRAM usage, texture size, mesh count | [performance.md](references/performance.md#optimization-workflow) §Optimization-Workflow |

**MANDATORY READ**: Load [performance.md](references/performance.md) before optimizing — measure first, then target the largest bottleneck.

**MANDATORY READ** [`references/performance.md`](references/performance.md) and [`references/lighting.md`](references/lighting.md) for Quest optimization.
**Do NOT Load**: `references/audio-video.md`, `references/upload.md`.

---

## Lighting

### Baked Lighting (Required)

```text
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

**MANDATORY READ** [`references/lighting.md`](references/lighting.md) when configuring lightmaps or light probe placement.
**Do NOT Load**: `references/audio-video.md`, `references/upload.md`, `references/layers.md`.

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

**MANDATORY READ** [`references/audio-video.md`](references/audio-video.md) for VRC_SpatialAudioSource or video player configuration.
**Do NOT Load**: `references/lighting.md`, `references/performance.md`.

---

## World Upload

### Upload Steps

```text
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

```text
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

**MANDATORY READ** [`references/upload.md`](references/upload.md) before running Build & Upload. Verify all pre-upload checklist items first.
**Do NOT Load**: `references/audio-video.md`, `references/lighting.md`.

---

## Troubleshooting

### Quick Router

Identify the symptom category and jump to the reference section:

| Symptom Category | Common Cause | Reference |
|-----------------|-------------|-----------|
| Player walks through walls / floor | Layer setup not run; geometry not on Environment (11) | [troubleshooting.md §Layer & Collision](references/troubleshooting.md#layer--collision-issues) |
| Can't grab / Pickup not working | Missing Collider, Rigidbody, or VRC_Pickup component | [troubleshooting.md §Component](references/troubleshooting.md#component-issues) |
| Object not syncing / snaps back | Missing VRC_ObjectSync or ownership not transferred | [troubleshooting.md §Networking](references/troubleshooting.md#networking-issues) |
| Can't sit / clips through Station | Missing Collider; Station Collision Transform needs adjustment | [troubleshooting.md §Component](references/troubleshooting.md#component-issues) |
| Mirror not reflecting | Layers mask missing Player/PlayerLocal/MirrorReflection | [troubleshooting.md §Component](references/troubleshooting.md#component-issues) |
| Build / Upload fails | Missing SceneDescriptor, script errors, layer warnings | [troubleshooting.md §Build](references/troubleshooting.md#build--upload-issues) |
| Performance issues | Mirror ON, realtime lights, uncooked lightmaps | [performance.md](references/performance.md) |
| Works in Editor but fails in VRChat | Editor Play ≠ SDK runtime; use Build & Test | [troubleshooting.md §Editor](references/troubleshooting.md#editor--runtime-discrepancy) |
| UI visible but not clickable | VRC_UIShape on Screen Space / Overlay Canvas (see NEVER #11) | [troubleshooting.md §Editor](references/troubleshooting.md#editor--runtime-discrepancy) |

**MANDATORY READ** [`references/troubleshooting.md`](references/troubleshooting.md) when diagnosing any issue. **Do NOT Load** for non-troubleshooting tasks.

---

## Related Skills

For C# scripting, network sync, and UdonSharp event implementation, use the `unity-vrc-udon-sharp` skill.

---

## Templates (`assets/templates/`)

Starter templates for common SDK component patterns. Each template compiles without modification; adjust Inspector fields and extend the event stubs for your world.

| Template | Purpose |
|---|---|
| `VRC_Pickup_Rigidbody.cs` | VRC_Pickup with Rigidbody — OnPickup/OnDrop/OnPickupUseDown/OnPickupUseUp events, ownership transfer, audio feedback |
| `VRC_Station_Basic.cs` | VRC_Station controller — OnStationEntered/OnStationExited events, PlayerMobility, force-eject API |

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
