# VRChat World Performance Optimization

## Project-defined criteria

VRChat does not publish one fixed FPS upload threshold for worlds. Define a
frame-time or frame-rate target for every supported device from the experience's
representative scenes and expected player count. Record the test scene, device,
client mode, player count, and thermal state with each result so later runs are
comparable.

---

## Optimization Workflow

If a measured result misses the project target, follow this workflow — measure before guessing:

```text
1. Measure
   ├── Unity Profiler: standard profiling in Play mode (primary; Deep Profile only for function-level deep dives — avoid on Quest, misleading results)
   ├── VRChat overlay: type "/perf" in-game
   └── Stats window: Draw Calls, Triangles, VRAM

2. Identify bottleneck category
   ├── CPU-bound (high Draw Calls): → Batching / LOD / Culling / Static flags
   ├── GPU-bound (shader cost): → Mirror / Realtime lights / Post-Processing
   ├── Memory (VRAM spikes): → Reduce texture resolution / video players
   └── Physics: → Remove Cloth on Android; profile Rigidbodies and Constraints

3. Fix the largest measured cost first, then re-measure
   Mirror ON by default     → Disable by default; measure the changed render time
   Realtime shadows         → Bake the default lighting; profile any required exception
   High lightmap resolution → Reduce it and compare memory on the target device
   Unbatched static objects → Test Static Batching or instancing and compare draw calls
   Many active particles    → Pool or disable off-screen systems and compare CPU/GPU time
```

**Never stack multiple changes before re-measuring** — you'll lose the ability to identify which change helped.

---

## Key Performance Factors

### 1. Mirrors

```text
Impact: ⚠️ Very high

Problem:
- Renders the entire scene twice
- In VR: 4 times (both eyes × 2)
- Each additional active mirror adds another expensive render workload

Countermeasures:
□ Maximum 1 per world
□ Default OFF
□ Enable via toggle
□ Auto-disable by distance
□ Lower resolution
```

### 2. Video Players

```text
Impact: ⚠️ High

Problem:
- Decoding processing is heavy
- Simultaneous playback increases load

Countermeasures:
□ Keep to 1-2 players on PC, 1 on Quest (recommended; no documented hard limit)
□ Avoid simultaneous playback
□ Provide a low-resolution option
```

### 3. Realtime Lights

```text
Impact: ⚠️ High

Problem:
- Dynamic shadows are very expensive
- Each light recalculates objects

Countermeasures:
□ Start with baked lighting
□ Keep realtime lights or shadows only when the effect is required and target-device profiling supports it
□ Use Light Probes for dynamic objects
□ If absolutely necessary, limit range
```

### 4. Draw Calls

```text
Impact: ⚠️ Medium to High

Problem:
- Each material/mesh generates a Draw Call
- Mobile is especially sensitive

Countermeasures:
□ Merge materials
□ Use texture atlases
□ Enable Static Batching
□ Use GPU Instancing
```

---

## Lighting Optimization

### Baked Lighting (Default)

```text
✅ Recommended settings:

Lighting Settings:
├── Lightmapper: Progressive GPU
├── Lightmap Resolution: 10-20 texels/unit
├── Lightmap Compression: Normal
└── Directional Mode: Non-Directional (Quest)

Light Settings:
├── Mode: Baked or Mixed
├── Indirect Multiplier: 1.0
└── Shadow Type: Soft Shadows (Baked)
```

### Light Probes

```text
Purpose:
- Apply baked lighting influence to
  dynamic objects (players, pickups)

Placement:
□ Place where players walk
□ Place densely at light/dark boundaries
□ Place at indoor/outdoor boundaries
□ Distribute in 3D (not just the floor, include height)
```

### Reflection Probes

```text
Purpose:
- Improve reflection quality
- Reduce load with baking

Settings:
├── Type: Baked (avoid Realtime)
├── Resolution: 128-256
├── Box Projection: Only when needed
└── Importance: Set appropriately
```

---

## Shader Optimization

### PC Shaders

```text
✅ Recommended:
- Standard Shader
- VRChat official shaders
- Shaders supporting single-pass stereo

❌ Avoid:
- Screen-space effects
- Complex tessellation
- Excessive pass count
```

### Quest/Android World Shaders

```text
Shaders are not restricted for worlds in VRChat on Android.

✅ Recommended starting points:
- Mobile/VRChat/Lightmapped for an optimized basic lightmapped world shader
- Mobile-compatible particle shaders
- Custom shaders only after profiling them on the target Android device

❌ Absolutely avoid:
- Heavy use of transparency (Alpha)
- Screen-space effects
- Complex compute shaders
```

### Transparency Warning

```text
⚠️ Transparency (Alpha) issues:

Mobile GPUs are weak at Alpha fill rate:
- Transparent objects are drawn multiple times
- Overlapping increases cost exponentially

Countermeasures:
□ Design without transparency
□ If absolutely necessary, limit the area
□ Cutout > Transparent (when possible)
```

---

## Mesh and Geometry

### Polygon Guidelines

| Platform | Guidance | Upload limit |
|----------|----------|--------------|
| PC | Derive a project budget from profiling | No polygon-count upload limit documented here |
| Quest/Android | Budget approximately 250,000 triangles for the whole world | The recommendation is not an upload limit |

### Optimization Techniques

```text
□ Set up LOD (Level of Detail)
□ Enable Occlusion Culling
□ Remove invisible meshes
□ Use low-poly + baked shadows for distant scenery
```

### Static Batching

```csharp
// Mark non-moving objects as Static

Inspector:
[✓] Static
  [✓] Batching Static
  [✓] Occludee Static
  [✓] Occluder Static
```

---

## Occlusion Culling

### Setup

```text
1. Window > Rendering > Occlusion Culling
2. Set static objects as Occluder/Occludee
3. Bake

Settings:
├── Smallest Occluder: 5-10m (larger = faster)
├── Smallest Hole: 0.25m
└── Backface Threshold: 100
```

### Best Practices

```text
□ Set walls, floors, ceilings as Occluder
□ Small objects as Occludee only
□ Don't set transparent objects as Occluder
□ Simplify complex shapes
```

---

## Audio Optimization

### Compression Settings

```text
BGM:
├── Load Type: Streaming
├── Compression Format: Vorbis
└── Quality: 70%

Sound effects:
├── Load Type: Decompress On Load (short sounds)
├── Load Type: Compressed In Memory (long sounds)
└── Quality: 50-70%
```

### Spatial Audio

```text
□ Disable unnecessary audio sources
□ Set Max Distance appropriately
□ Fall back to 2D for distant sources
```

---

## Script Optimization

### Update() Optimization

```csharp
// ❌ Avoid per-frame processing
void Update()
{
    player = Networking.LocalPlayer; // Fetched every frame
}

// ✅ Use caching
private VRCPlayerApi _localPlayer;

void Start()
{
    _localPlayer = Networking.LocalPlayer;
}

void Update()
{
    // Use _localPlayer
}
```

### SendCustomEventDelayedSeconds

```csharp
// Space out frequent processing
void Start()
{
    SendCustomEventDelayedSeconds(nameof(_SlowUpdate), 0.5f);
}

// Leading underscore keeps this public member available to local code while blocking legacy network dispatch.
public void _SlowUpdate()
{
    // Processing every 0.5 seconds
    DoHeavyCalculation();
    SendCustomEventDelayedSeconds(nameof(_SlowUpdate), 0.5f);
}
```

---

## Platform-Specific Optimization

### Quest Optimization Checklist

```text
□ Total world geometry starts within the approximately 250,000-triangle recommendation
□ Material count and draw calls minimized, then verified with profiling
□ Texture resolution ≤ 1024x1024
□ World shaders tested on the target Android device
□ Lighting baked by default; any realtime exception profiled on-device
□ No mirrors or minimal
□ Video players kept to 1 (recommended)
□ No Post Processing
```

### PC Optimization Checklist

```text
□ Project-defined performance target met in representative scenes and player counts
□ Minimal realtime lights
□ Mirror = default OFF
□ Light baking complete
□ Occlusion Culling configured
□ LOD configured
□ Post Processing kept moderate
```

---

## Profiling Tools

### Unity Profiler

```text
Window > Analysis > Profiler

Items to check:
- CPU Usage: Compare main-thread and rendering frame time with the project criterion
- Rendering: Draw Calls, Tris, Batches
- Memory: Texture usage
```

### Frame Debugger

```text
Window > Analysis > Frame Debugger

Use for:
- Draw Call breakdown
- Batching effectiveness
- Detecting overdraw
```

### VRChat Debug Menu

```text
In-game checks:
- FPS
- Network stats
- Avatar performance
```

---

## Common Performance Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| Low FPS | Mirror always ON | Default OFF |
| Low FPS | Realtime lights | Bake |
| Stuttering | GC Allocation | Object pooling |
| Slow loading | Large textures | Compress, lower resolution |
| Doesn't work on Quest | Heavy shaders | Mobile shaders |

---

## Quick Optimization Checklist

```text
□ Project-defined performance target met on every supported device
□ Light baking complete
□ Realtime lighting and shadows justified by profiling
□ Mirror default OFF
□ Video players kept to 1-2 (recommended)
□ Static Batching enabled
□ Occlusion Culling configured
□ LOD configured (large objects)
□ Textures compressed
□ Mobile support (if needed)
```

---

## Quest/Android Content Limitations

Cross-platform worlds (PC + Android) need an Android-specific performance budget.
The table distinguishes the enforced world-size limit from optimization guidance;
recommendations are not upload limits.

Reference: https://creators.vrchat.com/platforms/android/quest-content-optimization

### Android Limits and High-Cost Features

| Constraint | Status | Notes |
|-----------|--------|-------|
| World build size after build-time compression | **100 MB hard limit** | Worlds above this size cannot be uploaded or accessed on Android |
| Texture resolution | 1024×1024 rule of thumb | Higher resolutions increase memory and load time |
| World shaders | Unrestricted | Prefer mobile-compatible shaders; profile every custom shader on the target device |
| Post-processing effects | Disabled | Bloom, depth of field, color grading are unavailable |
| Real-time shadows | High-cost guidance | Prefer baked lighting; keep only after profiling on the target Android device |
| Video players | Work with some limitations | See audio-video.md (some URLs unsupported on Quest) |
| Particle systems | Profile complexity | The cited guide documents avatar limits, not a fixed world particle cap |

### Features to Remove or Treat with Caution on Quest

```text
⚠️ Custom world shaders: permitted, but profile their passes, overdraw, and target-device GPU time
❌ Post-processing stack (any effect)
⚠️ Real-time shadow casting and receiving (avoid by default; retain only with target-device evidence)
❌ Screen-space ambient occlusion (SSAO)
❌ Screen-space reflections (SSR)
⚠️ Tessellation, geometry, and compute features: verify build-target support and profile the actual shader on-device
❌ Some particle system modules (trails, sub-emitters in complex setups)
```

### World Build Size Management

```text
The enforced Android world limit is 100 MB after build-time compression. Set a
smaller project budget from load-time and memory testing. The much smaller size
target in the avatar section of the official guide does not apply to worlds.

Reduction strategies:
□ Use ASTC compression for all textures (Quest-native format)
□ Cap textures at 1024×1024; use 512×512 for distant/minor objects
□ Merge textures into atlases to reduce individual asset overhead
□ Remove duplicate or unused assets before building
□ Strip unused shader variants
```

---

## Quest/Android Optimization Techniques

### Texture Compression and Sizing

```text
Quest-native format: ASTC (Adaptive Scalable Texture Compression)

Settings per texture type:
┌─────────────────────┬──────────────┬────────────────┐
│ Texture Type        │ Max Size     │ ASTC Block     │
├─────────────────────┼──────────────┼────────────────┤
│ Diffuse/Albedo      │ 1024×1024    │ ASTC 6×6       │
│ Normal Map          │ 512×512      │ ASTC 6×6       │
│ UI / HUD            │ 512×512      │ ASTC 4×4       │
│ Distant scenery     │ 256×256      │ ASTC 8×8       │
└─────────────────────┴──────────────┴────────────────┘

Steps:
□ Select texture in Project → Inspector
□ Platform: Android
□ Override For Android: ✓
□ Max Size: 1024 (or lower)
□ Format: ASTC 6x6 block
□ Compression: Normal
```

### Material Merging and Texture Atlasing

```text
Goal: minimize unique material count and measured draw-call cost. The official
guide does not define a fixed world material limit.

Draw call reduction math:
- 100 objects × 3 materials each = 300 draw calls
- 100 objects × 1 atlas material   = ~1–10 draw calls (batched)

Workflow:
□ Group objects by similar surface properties
□ Pack diffuse textures into a single atlas (e.g. 2048×2048 split 4×4)
□ Remap UV coordinates to atlas regions
□ Assign one shared material to all objects in the group
□ Re-check that atlas resolution stays within 1024 per tile region

Tools: Unity Sprite Atlas, third-party atlas packers, manual UV remap
```

### Mesh Optimization

```text
LOD (Level of Detail) setup:
├── LOD0: full detail   (within ~10m)
├── LOD1: 50% tris      (10–30m)
├── LOD2: 20% tris      (30–60m)
└── Culled              (beyond 60m)

Decimation targets for Quest:
□ Hero/focal objects:   ≤ 5K triangles
□ Background objects:   ≤ 1K triangles
□ Ground/floor planes:  minimize subdivision
□ Total scene:          budget approximately 250,000 triangles; reduce further when profiling calls for it

Additional steps:
□ Remove interior faces never visible to players
□ Weld duplicate vertices
□ Apply mesh compression in import settings (Medium or High)
```

### Android Lighting Workflow

```text
Baking lighting is the default Android path. Keep Mixed or Realtime lighting only
when it is required by the experience and survives target-device profiling.

Recommended settings for Quest:
├── Lightmapper:           Progressive GPU (fast; fall back to CPU if GPU memory is insufficient)
├── Lightmap Resolution:   5–10 texels/unit (lower = smaller textures)
├── Lightmap Size:         1024×1024 max per map
├── Directional Mode:      Start with Non-Directional; compare quality/memory before changing it
├── Ambient Occlusion:     Baked baseline (Android post-processing disables SSAO)
└── Compress Lightmaps:    ✓ (reduces build size significantly)

Checklist:
□ Environment lighting baked
□ Mixed or Realtime lights retained only with documented target-device profiling
□ Light Probes placed for dynamic objects (players, pickups)
□ Reflection Probes set to Baked, resolution 128
□ Window > Rendering > Lighting > Generate Lighting → complete without errors
□ No "Baking" or "Auto" warnings in the Lighting window
```

### Draw Call Reduction

```text
Target draw calls for Quest: < 50 (excellent), < 100 (acceptable)

Techniques:
□ Static Batching: mark all non-moving objects as Batching Static
□ Dynamic Batching: enabled by default; keep meshes < 300 vertices each
□ GPU Instancing: enable on ALL materials used for repeated objects
   Inspector → Material → Enable GPU Instancing ✓
□ Combine meshes: merge small static meshes in the same area
□ Single texture atlas per material set (see Material Merging above)

GPU Instancing in UdonSharp:
// No code changes needed — instancing is a material setting.
// Ensure MeshRenderer.material.enableInstancing = true is NOT
// overriding the inspector setting at runtime.
```

### Occlusion Culling for Quest

```text
Occlusion culling is especially important on Quest due to limited fill rate.

Aggressive settings for Quest:
├── Smallest Occluder: 3–5m  (lower value = more occlusion objects)
├── Smallest Hole:     0.2m
└── Backface Threshold: 100

Extra steps for Quest:
□ Divide large open spaces with low walls or props as occluders
□ Rooms and corridors benefit most — ensure each room is enclosed
□ Verify bake: use Scene view occlusion visualization to confirm culling
□ Check Camera > Occlusion Culling is enabled on the main camera
```

---

## Quest Compatibility Pre-Upload Checklist

Verify all items below before uploading a Quest-compatible world build.

### Build Size

```text
□ Android build size after compression < 100 MB
□ A smaller project budget chosen from measured load time and memory use
□ No uncompressed or oversized textures (check via Project > Stats)
□ No duplicate assets left in the project
```

### Shaders and Materials

```text
□ Prefer Mobile-compatible shaders where they meet the visual requirements:
    - Mobile/Diffuse
    - Mobile/Bumped Diffuse
    - Mobile/Particles/Alpha Blended
    - VRChat/Mobile/Toon Lit (if using VRChat shaders)
□ Every custom world shader profiled on the target Android device
□ GPU Instancing enabled on all materials applied to repeated objects
□ A project material/draw-call budget chosen from profiling (no fixed world material upload limit)
□ No post-processing volumes or components in the scene
```

### Lighting

```text
□ Default environment lighting baked (Window > Rendering > Lighting shows no pending bake)
□ Realtime or Mixed lights retained only when required and supported by target-device measurements
□ Directional Mode selected from measured memory cost and required visual quality
□ Light Probes cover all player-accessible areas
□ Reflection Probes baked, resolution ≤ 128
□ Lightmap textures compressed
```

### Geometry

```text
□ Total triangle count compared with the approximately 250,000-triangle recommendation and reduced when profiling requires it
□ LOD groups configured for all objects > 1K triangles
□ Particle systems measured for CPU, GPU, overdraw, and memory cost on the target device
□ Occlusion Culling baked and verified
□ Static Batching enabled for all non-moving objects
```

### Platform-Specific Features

```text
□ Video players configured for Quest (see audio-video.md)
□ No post-processing components (Post Process Volume, etc.)
□ Realtime lights and shadows removed unless target-device profiling justifies them
□ No screen-space effects in any material or renderer
□ Audio sources: compressed formats, streaming for BGM
```

### Testing

```text
□ Build and Run targeting Android in Unity — check for shader errors
□ Tested in VRChat on actual Quest hardware or using a Quest emulator
□ Frame time or frame rate measured in representative scenes and at the expected player count
□ No visible lighting artifacts (dark patches, blown-out areas)
□ All interactive elements (pickups, triggers) work correctly on Quest
□ No crashes or memory warnings during extended play session
```

---

## World Performance Rating

VRChat does **not** have a formal in-client performance ranking system for worlds (unlike avatars which display Excellent/Good/Medium/Poor badges). There is no SDK-enforced ranking threshold that blocks world uploads based on polygon count or draw calls.

Use the **Project-defined criteria** at the top for performance validation. The
100 MB compressed world-size rule is a hard Android limit; triangle, material,
and rendering values are budgets to validate through profiling, not upload gates.

### Official World Triangle Budget (Quest)

From the official Android Content Optimization documentation:
<https://creators.vrchat.com/platforms/android/quest-content-optimization/>

```text
VRChat recommends budgeting approximately 250,000 triangles for the whole world.
```

> This is an optimization recommendation, not an upload limit. A lower budget can
> leave more room for avatars and effects, but it must be chosen from the needs and
> measurements of the world rather than presented as an official hard boundary.

### Per-Object Polygon Guidelines (Quest)

These are approximate guidelines based on community practice and the official optimization guide:
<https://creators.vrchat.com/platforms/android/quest-content-optimization/>

| Object Category | Triangle Target | Notes |
|---|---|---|
| Hero / focal interactive objects | ≤ 5,000 | Pickups, NPCs, key props |
| Background / decorative objects | ≤ 1,000 | Furniture, environmental details |
| Ground / floor planes | Minimal subdivision | Avoid dense meshes; bake detail into textures |
| Total scene | Approximately 250K | Official world budget recommendation; not an upload limit |

### Draw Call Targets (Quest)

No hard SDK limit exists for draw calls. The targets below are community-derived approximate
guidelines, not official VRChat thresholds. Verify current recommendations against the
official documentation: <https://creators.vrchat.com/platforms/android/quest-content-optimization/>

> These are community-derived approximate guidelines, not official VRChat thresholds.

| Tier | Draw Calls | Expected Result |
|---|---|---|
| Initial low-cost target | < 50 | Investigate whether batching and culling remain effective |
| Review range | 50–100 | Measure render-thread and GPU cost on the target device |
| Investigation priority | > 100 | Inspect materials, passes, batching, and visible geometry; the count alone does not predict FPS |

Reduce draw calls with Static Batching, GPU Instancing, and texture atlasing (see Draw Call Reduction section above).

### Texture Compression Format (Quest)

Quest uses the Qualcomm Adreno GPU, which natively supports **ASTC** (Adaptive Scalable Texture Compression). Always override textures to ASTC for the Android platform:

```text
Inspector → Texture → Android override:
├── Format: ASTC 6x6 block  (diffuse, albedo — good quality/size balance)
├── Format: ASTC 4x4 block  (UI, normal maps — higher quality)
└── Format: ASTC 8x8 block  (distant/minor textures — smaller size)

ETC2 is the fallback when ASTC is unavailable. Prefer ASTC for all new content.
```

### Lightmap Resolution and Size (Quest)

For detailed lightmap resolution and size recommendations (texels/unit, max size, directional mode, compression, AO settings), see:

- **[Android Lighting Workflow](#android-lighting-workflow)** — full settings table in this file
- **[references/lighting.md — Quest Bake Parameter Reference](lighting.md#quest-bake-parameter-reference)** — rationale, acceptable ranges, and Baked vs Mixed decision guide

## See Also

- [components.md](components.md) - Component reference including Quest-incompatible components to avoid
- [lighting.md](lighting.md) - Baked lighting settings and lightmap resolution guidelines for PC and Quest
