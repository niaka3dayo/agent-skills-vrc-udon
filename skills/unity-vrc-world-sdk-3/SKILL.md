---
name: unity-vrc-world-sdk-3
description: >
    VRChat World SDK 3 guide for scene and Inspector setup, component placement,
    optimization, and upload. Use for VRChat world scene configuration,
    VRC SDK components, layers, baked lighting, Quest/Android performance,
    Dynamics for Worlds, Build Panel warning triage, validation, and upload.
    Covers VRC_SceneDescriptor, VRC_Pickup, VRC_Station, VRC_Mirror,
    VRC_ObjectSync, VRC_CameraDolly, spawn points, collision matrices,
    PhysBone and Contact component placement, Box Contacts,
    Global Avatar PhysBone Colliders, and VRCPhysBoneCollider component setup.
    SDK 3.7.1-3.10.4. Triggers on: VRChat world scene, VRC SDK, scene setup,
    component placement, optimization, Quest support, light baking, upload,
    SDK validation, Build Panel warning, Auto Fix, red warning, yellow warning, or white warning.
    Do not use for UdonSharp C# or VRCTween calls; use
    unity-vrc-udon-sharp for runtime scripting.
license: MIT
metadata:
    author: niaka3dayo
    version: "3.0.1"
    tags: vrchat, world-sdk, scene-setup, optimization, components, upload, sdk-validation, build-panel
---

# VRChat World SDK 3 Guide

## Table of Contents

| Section                                    | Content                    | Reference                       |
| ------------------------------------------ | -------------------------- | ------------------------------- |
| [Scene Setup](#scene-setup)                | VRC_SceneDescriptor, Spawn | This file                       |
| [Components](#components)                  | Pickup, Station, Mirror    | `references/components.md`      |
| [Layers & Collision](#layers--collision)  | Layers, Collision Matrix   | `references/layers.md`          |
| [Performance](#performance)                | Optimization guide         | `references/performance.md`     |
| [Lighting](#lighting)                      | Lighting settings          | `references/lighting.md`        |
| [Audio & Video](#audio--video)            | Audio, Video players       | `references/audio-video.md`     |
| [Build Validation](references/build-validation.md) | Red/yellow/white SDK alerts | `references/build-validation.md` |
| [World Upload](#world-upload)              | Upload workflow            | `references/upload.md`          |
| [Troubleshooting](#troubleshooting)        | Problem solving            | `references/troubleshooting.md` |
| [Cheatsheet](CHEATSHEET.md)               | Quick reference            | `CHEATSHEET.md`                 |

---

## Method Migration

The following public methods were renamed because an unprefixed, parameterless
public UdonSharp method remains callable through legacy network dispatch:

| Before | After |
|---|---|
| `ForceDropPickup` | `_ForceDropPickup` |
| `IsHeld` | `_IsHeld` |
| `IsOccupied` | `_IsOccupied` |
| `StopSound` | `_StopSound` |
| `SlowUpdate` | `_SlowUpdate` |

Update Inspector event strings, `SendCustomEvent*` calls, delayed events and
`nameof(...)` expressions, and cross-behaviour calls. Compatibility aliases are
not provided because an old unprefixed alias would restore the same legacy network exposure.

---

## Common Mistakes (NEVER List)

These cause silent world failures, performance disasters, or Quest incompatibility:

| # | NEVER do this | Why it hurts | Use instead |
|---|---------------|-------------|-------------|
| 1 | Enable Mirror by default (active on world join) | A mirror adds another costly scene render; the impact depends on view, scene, resolution, and device | Default Mirror OFF; add a player-controlled toggle and profile each target device |
| 2 | Use realtime directional lights with real-time shadows without profiling | Realtime shadow cost varies with scene geometry, view, and target device and can dominate frame time on Android | Prefer baked lightmaps + light probes; profile the target device before keeping any realtime shadows |
| 3 | Set Respawn Height at or above the world floor | Player respawns → falls → respawns again → infinite loop; players cannot recover | Set to an unreachable depth (e.g., floor at Y=0 → Respawn at Y=-100) |
| 4 | Skip "Setup Layers for VRChat" on a new project | Layer collision matrix is wrong by default — players walk through walls, Pickups clip floors | Run VRChat SDK > Builder > "Setup Layers for VRChat" before placing any colliders |
| 5 | Enable Post-Processing without an Android build profile | Post-processing is disabled at runtime on Android, so the authored effect will not appear and unnecessary resources can still enlarge the build | Use a separate Android build profile with post-processing removed |
| 6 | Place more than 2 active video players simultaneously | Each player adds significant decoding overhead; running >2 simultaneously is a common cause of frame drops and audio issues in practice | Disable extra players at scene start; activate only the currently playing one |
| 7 | Use Cloth on Android, or add many Unity Constraints without profiling | Cloth is disabled on Android. Unity Constraints are permitted in worlds, but overuse can significantly affect performance | Remove Cloth from the Android build; prefer VRC Constraints for new work and profile any constraint-heavy setup |
| 8 | Upload without completing a lightmap bake | Realtime GI adds substantial scene-dependent render cost and is unsuitable as an unmeasured fallback on Android | Bake lights before upload, then verify the result on the target device |
| 9 | Place player walkable surfaces on Default layer (0) | Collision matrix is wrong by default — avatar physics collision is unreliable; players may clip through geometry | Use Environment (layer 11) for all walkable geometry, walls, and floors |
| 10 | Use very high lightmap resolution for large areas without profiling | Texture memory can spike significantly at high resolutions; a common cause of OOM crashes on mobile headsets | Start at 10-20 texels/unit (PC) / 5-10 (Quest) as a practical guideline; profile VRAM and adjust — official guidance says "keep lightmap resolution low" for Quest |
| 11 | Add VRC_UIShape to a Screen Space or Overlay Canvas | VRC_UIShape requires World Space Canvas; other modes throw a runtime Unity error in VRChat — the UI renders visually but is not interactive, with no visible error to the world builder | Set Canvas > Render Mode to World Space before adding VRC_UIShape |

## Reference Loading Guide

Load only what the task requires.

| Task | MANDATORY READ | Optional | Do NOT Load | Load Rationale |
|------|---------------|----------|-------------|----------------|
| Setting up a new scene from scratch | `components.md`, `layers.md` | `upload.md` | `audio-video.md`, `troubleshooting.md` | Collision matrix non-obvious; component deps needed upfront |
| Making objects grabbable (VRC_Pickup) | `components.md` | `layers.md` | `audio-video.md`, `lighting.md` | Pickup/Rigidbody requirements not in standard Unity docs |
| Configuring Dynamics for Worlds (PhysBones, Contacts, Box Contacts, Global Avatar PhysBone Colliders, world `VRCPhysBoneCollider` access) | `components.md` | `layers.md`, `troubleshooting.md`; use `unity-vrc-udon-sharp` for Udon code | `audio-video.md`, `lighting.md` | Dynamics component availability and Udon access are SDK-version sensitive |
| Setting up seating (VRC_Station) | `components.md` | `layers.md` | `audio-video.md`, `performance.md` | Station collider + exit requirements are VRChat-specific |
| Optimizing FPS for Quest | `performance.md`, `lighting.md` | `troubleshooting.md` | `audio-video.md`, `upload.md` | Quest limits differ from PC; bake requirements non-obvious |
| Adding audio or video player / voice zones (SetVoiceGain, Steam Audio) | `audio-video.md`, `components.md` | `troubleshooting.md` | `lighting.md`, `performance.md` | AVPro vs Unity Video selection is VRChat-specific |
| Baking lights / lightmap setup | `lighting.md`, `performance.md` | — | `audio-video.md`, `layers.md` | Lightmap resolution and probe placement affect Quest VRAM |
| SDK Build Panel validation alerts, red/yellow/white warnings, or Auto Fix questions | `build-validation.md` | `upload.md`, `troubleshooting.md` | `audio-video.md`, `lighting.md` | Alert severity, build consequence, and Auto Fix side effects must come from SDK-backed catalog |
| World upload and publish | `upload.md` | `build-validation.md`, `troubleshooting.md` | `audio-video.md`, `lighting.md` | Upload steps and validation order are fragile; easy to miss |
| Debugging collision or layer issues | `layers.md`, `troubleshooting.md` | `components.md` | `audio-video.md`, `lighting.md` | VRChat collision matrix differs from Unity default |
| Mirror setup and configuration | `components.md` | `performance.md` | `audio-video.md`, `upload.md` | Mirror layer mask requirements are VRChat-specific |

## Before Starting a New World — Design Decisions

These decisions shape every downstream choice. Make them first, before placing any component.

| Decision | Options | Implication |
|---|---|---|
| **Quest required?** | Yes / No | Yes → Quest First philosophy applies from day 0, not as a retrofit |
| **Expected player count?** | 1–8 / 9–40 / 40+ | Affects spawn count, mirror policy, max video players |
| **Primary interaction?** | Grab (Pickup) / Sit (Station) / Watch (Video) / Explore | Determines which SDK components are mandatory |
| **Lighting approach?** | Baked / Mixed / Realtime | Prefer baked lighting on Android; profile each target device before keeping realtime lighting or shadows |
| **Networked objects?** | None / Physics (Pickup+ObjectSync) / State (UdonSynced) | Determines sync architecture before Udon scripting begins |

---

## Design Philosophy: Quest First

**If the world must run on Android, decide those constraints before tuning the PC build. Test each target separately.**

Android headsets have mobile CPU, GPU, memory, and thermal budgets that differ
from PC and vary by device:
- **GPU**: Realtime lights, shadows, overdraw, and complex shaders can dominate frame time
- **Memory**: Textures and lightmaps share limited system memory with the client
- **Thermals**: Sustained load can reduce available performance during a session

Measure each target device independently; PC results do not establish Android
performance, and a single-client Quest result does not predict a particular PC
frame rate. Use the Unity Profiler and the [official Android content optimization
guide](https://creators.vrchat.com/platforms/android/quest-content-optimization/)
before publishing.

**NEVER optimize exclusively for PC with "Quest support added later"** — by that point, lighting, materials, and mesh density are all locked to PC quality, and the Quest port requires rebuilding everything.

**Quest First Cascade** — when Quest is required, every downstream decision inherits constraints:

```text
Quest required? → Yes
  ├── Shaders: World shaders are unrestricted; prefer mobile-compatible shaders and profile custom ones
  ├── Lighting: Baked by default; retain realtime effects only after target-device profiling
  ├── Geometry: Budget approximately 250,000 triangles for the whole world; reduce further when profiling calls for it
  ├── Materials: Minimize unique materials and draw calls; no fixed world upload limit is documented
  ├── Audio: Mono, compressed, limited concurrent sources
  └── Physics: Simplified colliders, minimal Rigidbodies
```

## SDK Versions

**Covered versions**: SDK 3.7.1 - 3.10.4 (last verified: 3.10.4)

| SDK    | New Features                                                                   | Status         |
| ------ | ------------------------------------------------------------------------------ | -------------- |
| 3.7.1  | StringBuilder, Regex, System.Random                                            | ✅             |
| 3.7.4  | **Persistence API** (PlayerData/PlayerObject)                                  | ✅             |
| 3.7.6  | **Multi-platform Build & Publish** (simultaneous PC + Android builds)          | ✅             |
| 3.8.0  | PhysBone dependency sorting, **Force Kinematic On Remote**, Drone API          | ✅             |
| 3.8.1  | **[NetworkCallable]** events with parameters, `Others`/`Self` targets, VRCCameraSettings | ✅ |
| 3.9.0  | **Camera Dolly API**, Auto Hold simplification, VRCCameraSettings additions (CullingMask, GetCurrentCamera) | ✅ |
| 3.10.0 | **Dynamics for Worlds** (PhysBones, Contacts, VRC Constraints)                 | ✅             |
| 3.10.1 | Bug fixes and stability improvements                                           | ✅             |
| 3.10.2 | EventTiming extensions, PhysBones fixes, shader time globals                   | ✅             |
| 3.10.3 | `VRCPlayerApi.isVRCPlus`, VRCRaycast (avatar), Mirror render-order fix         | ✅             |
| 3.10.4 | VRCTween, Box-shaped Contacts, Global Avatar PhysBone Colliders, world `VRCPhysBoneCollider` Udon access, Data Container capacity APIs | ✅ Last verified |

Use the current supported SDK for publishing and verify version-sensitive APIs against the matching release notes before migrating a project.

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

#### Key Properties

| Property                        | Type        | Description                     | Default           |
| ------------------------------- | ----------- | ------------------------------- | ------------------ |
| **Spawns**                      | Transform[] | Array of spawn points           | Descriptor position |
| **Spawn Order**                 | enum        | First/Sequential/Random/Demo (First: always the first spawn; Demo: spawn point is the center of room scale) | Sequential |
| **Spawn Orientation**           | enum        | Default/Align Player With Spawn Point/Align Room With Spawn Point | Default |
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
**Do NOT Load**: `references/audio-video.md` (unless the task involves audio/video components), `references/lighting.md`.

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
| **VRCCameraSettings**      | None (static API)        | Read camera info from Udon     | 3.8.1+ |

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

### Performance Criteria

Define the performance target from the supported devices, representative scenes, and expected player count. Record a frame-time or frame-rate target for each build target before profiling. VRChat does not provide one fixed FPS upload threshold for worlds.

### Starting Budgets

| Item                | Recommended           | Reason                        |
| ------------------- | --------------------- | ----------------------------- |
| Mirrors             | 1, default OFF        | Renders the entire scene 2x   |
| Video players       | 1-2 recommended       | Decoding overhead; no documented hard limit |
| Realtime lighting   | Baked by default      | Keep realtime lights or shadows only after target-device profiling |
| Lightmaps           | Bake and verify       | Primary Android lighting path  |

### Quest/Android Restrictions

| Component          | PC  | Quest         |
| ------------------ | --- | ------------- |
| Dynamic Bones      | ✅  | ❌ Disabled   |
| Cloth              | ✅  | ❌ Disabled   |
| Post-Processing    | ✅  | ❌ Disabled   |
| Unity Constraints  | ✅  | ✅ Permitted in worlds; profile cost |
| Realtime lights    | ✅  | ⚠️ Expensive; keep only with device evidence |

### Performance Optimization Workflow

| Bottleneck Type | Key Indicators | Reference |
|----------------|---------------|-----------|
| CPU-bound | High script time, physics overhead | [performance.md](references/performance.md#optimization-workflow) §Optimization-Workflow |
| GPU-bound | Draw calls, overdraw, shader complexity | [performance.md](references/performance.md#optimization-workflow) §Optimization-Workflow |
| Memory | VRAM usage, texture size, mesh count | [performance.md](references/performance.md#optimization-workflow) §Optimization-Workflow |

**MANDATORY READ**: Load [performance.md](references/performance.md) before optimizing — measure first, then target the largest bottleneck — and [`references/lighting.md`](references/lighting.md) for Quest optimization.
**Do NOT Load**: `references/audio-video.md`, `references/upload.md`.

---

## Lighting

### Baked Lighting (Default)

```text
✅ Recommended settings:
├── Lightmapper: Progressive GPU
├── Lightmap Resolution: 10-20 texels/unit (PC) / 5-10 (Quest)
├── Light Mode: Baked by default; use Mixed/Realtime only when the effect is necessary and measured
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

Plan each world `AudioSource` with a `VRC_SpatialAudioSource`: a bare `AudioSource` triggers a VRChat SDK Build Panel warning. Add the companion deliberately, avoid Auto Fix as a blind default, and do not overwrite existing `VRC_SpatialAudioSource` values or tuned `AudioSource` curves unless requested.

| Property              | Description           | Baseline / safe-preserve note |
| --------------------- | --------------------- | ----------------------------- |
| Gain                  | Volume boost (0-24 dB) | 10 dB is common/default; use 0 dB for warning-only additions to preserve loudness |
| Near                  | Attenuation start     | 0m unless the sound needs an intentional near field |
| Far                   | Attenuation end       | Match existing `maxDistance` or the intended audible range; avoid blind default/Auto Fix ranges |
| Volumetric Radius     | Source spread          | 0m for point sources; set intentionally for wide sources |
| Enable Spatialization | 3D positioning        | false for intentional 2D/global audio; true for authored 3D audio |

When preserving an existing `AudioSource`, keep `volume`, `spatialBlend`, `rolloffMode`, `maxDistance`, and custom curves; use Gain 0 dB; enable `Use AudioSource Volume Curve` for tuned 3D rolloff; match Far to the existing `maxDistance` or intended audible range; and keep Near at 0m unless an existing `minDistance`/Near value was intentionally authored.

### Video Player Selection

| Feature            | AVPro | Unity Video |
| ------------------ | ----- | ----------- |
| Live streaming     | ✅    | ❌          |
| Editor preview     | ❌    | ✅          |
| YouTube/Twitch     | ✅    | ❌          |
| Quest support      | ✅    | ✅          |

**MANDATORY READ** [`references/audio-video.md`](references/audio-video.md) for VRC_SpatialAudioSource or video player configuration.
**Optional**: `references/components.md` when wiring audio/video components.
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
□ Project-defined frame-time or frame-rate target met in representative scenes and player counts
□ No Validation errors
□ Content Warnings set
□ Capacity set
```

**MANDATORY READ** [`references/upload.md`](references/upload.md) before running Build & Upload. Verify all pre-upload checklist items first.
**MANDATORY READ** [`references/build-validation.md`](references/build-validation.md) when the user asks about SDK Build Panel validation, red/yellow/white warnings, Auto Fix, or a copied validation message.
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
| Can't sit / clips through Station | Missing Collider; Station Enter Player Location needs adjustment | [troubleshooting.md §Component](references/troubleshooting.md#component-issues) |
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

Starter templates for common SDK component patterns. Repository checks cover static checks; import them into the target SDK project, compile, and run Build & Test before use. Adjust Inspector fields and extend the event stubs for your world.

| Template | Purpose |
|---|---|
| `VRC_Pickup_Rigidbody.cs` | VRC_Pickup with Rigidbody — OnPickup/OnDrop/OnPickupUseDown/OnPickupUseUp events, ownership transfer, audio feedback |
| `VRC_Station_Basic.cs` | VRC_Station controller — OnStationEntered/OnStationExited events, PlayerMobility, force-eject API |

## References

| File                            | Content                                                                                          | Approx. Lines |
| ------------------------------- | ----------------------------------------------------------------------------------------------- | ------------- |
| `references/components.md`      | All component details, component whitelist, Dynamics for Worlds, editor-only exclusion (EditorOnly tag / IEditorOnly) | 800+          |
| `references/layers.md`          | Layers & collision                                                                               | 230+          |
| `references/performance.md`     | Performance optimization                                                                         | 700+          |
| `references/lighting.md`        | Lighting settings                                                                                | 400+          |
| `references/audio-video.md`     | Audio & video                                                                                    | 600+          |
| `references/build-validation.md` | SDK 3.10.4 Build Panel red/yellow/white validation alert catalog, safe fixes, Auto Fix side effects | 180+       |
| `references/upload.md`          | Upload procedure                                                                                 | 300+          |
| `references/troubleshooting.md` | Troubleshooting guide                                                                            | 500+          |
| `CHEATSHEET.md`                 | Quick reference                                                                                  | 200+          |
