# VRChat World Performance Optimization

## Performance Targets

### Minimum Requirements

| Platform | FPS Target | Measurement Point |
|----------|-----------|-------------------|
| PC VR | 45+ FPS | Spawn point, 1 player |
| PC Desktop | 60+ FPS | Spawn point, 1 player |
| Quest | 72 FPS | Spawn point, 1 player |

### Performance Tiers

```
Excellent: 90+ FPS (PC), 72 FPS stable (Quest)
Good: 60-90 FPS (PC), 60-72 FPS (Quest)
Acceptable: 45-60 FPS (PC), 45-60 FPS (Quest)
Poor: < 45 FPS - improvement required
```

---

## Key Performance Factors

### 1. Mirrors

```
Impact: ⚠️ Very high

Problem:
- Renders the entire scene twice
- In VR: 4 times (both eyes × 2)
- Multiple mirrors increase load exponentially

Countermeasures:
□ Maximum 1 per world
□ Default OFF
□ Enable via toggle
□ Auto-disable by distance
□ Lower resolution
```

### 2. Video Players

```
Impact: ⚠️ High

Problem:
- Decoding processing is heavy
- Simultaneous playback increases load

Countermeasures:
□ Maximum 2
□ Avoid simultaneous playback
□ Provide a low-resolution option
```

### 3. Realtime Lights

```
Impact: ⚠️ High

Problem:
- Dynamic shadows are very expensive
- Each light recalculates objects

Countermeasures:
□ 0-1 realtime lights
□ Bake lights
□ Use Light Probes for dynamic objects
□ If absolutely necessary, limit range
```

### 4. Draw Calls

```
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

### Baked Lighting (Required)

```
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

```
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

```
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

### Quest/Android Shaders

```
✅ Required:
- Use Mobile shaders
- Mobile/VRChat/Lightmapped (recommended)
- Mobile/Particles series

❌ Absolutely avoid:
- Heavy use of transparency (Alpha)
- Screen-space effects
- Complex compute shaders
```

### Transparency Warning

```
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

| Platform | Recommended | Maximum |
|----------|-------------|---------|
| PC | 500K - 1M | 2M |
| Quest | 50K - 100K | 200K |

### Optimization Techniques

```
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

```
1. Window > Rendering > Occlusion Culling
2. Set static objects as Occluder/Occludee
3. Bake

Settings:
├── Smallest Occluder: 5-10m (larger = faster)
├── Smallest Hole: 0.25m
└── Backface Threshold: 100
```

### Best Practices

```
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

```
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
    SendCustomEventDelayedSeconds(nameof(SlowUpdate), 0.5f);
}

public void SlowUpdate()
{
    // Processing every 0.5 seconds
    DoHeavyCalculation();
    SendCustomEventDelayedSeconds(nameof(SlowUpdate), 0.5f);
}
```

---

## Platform-Specific Optimization

### Quest Optimization Checklist

```
□ Polygon count < 100K
□ Material count < 25
□ Texture resolution ≤ 1024x1024
□ Mobile shaders used
□ Lights fully baked
□ Realtime lights = 0
□ No mirrors or minimal
□ Video players ≤ 1
□ No Post Processing
```

### PC Optimization Checklist

```
□ 45+ FPS in VR
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

```
Window > Analysis > Profiler

Items to check:
- CPU Usage: Below 16ms (60FPS)
- Rendering: Draw Calls, Tris, Batches
- Memory: Texture usage
```

### Frame Debugger

```
Window > Analysis > Frame Debugger

Use for:
- Draw Call breakdown
- Batching effectiveness
- Detecting overdraw
```

### VRChat Debug Menu

```
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

```
□ 45+ FPS (VR) achieved
□ Light baking complete
□ Realtime lights ≤ 1
□ Mirror default OFF
□ Video players ≤ 2
□ Static Batching enabled
□ Occlusion Culling configured
□ LOD configured (large objects)
□ Textures compressed
□ Mobile support (if needed)
```

---

## Quest/Android Content Limitations

Cross-platform worlds (PC + Quest) require stricter constraints on the Quest/Android build.
These limits apply to the Android build target and are enforced at upload time or at runtime.

Reference: https://creators.vrchat.com/worlds/udon/

### Hard Limits

| Constraint | Limit | Notes |
|-----------|-------|-------|
| World build size (compressed) | 100 MB max | Aim for 5–8 MB in practice |
| Texture resolution | 1024×1024 recommended max | Higher resolutions increase memory and load time |
| Custom shaders | Not supported | Standard or Mobile shaders only |
| Post-processing effects | Not supported | Bloom, depth of field, color grading unavailable |
| Real-time shadows | Not supported | Baked lighting only |
| Video player (AVPro) | Not supported | Use Unity Video Player component instead |
| Particle systems | Limited | Reduce count and complexity |

### Features Not Available on Quest

```
❌ Custom shaders (HLSL/ShaderLab beyond Mobile subset)
❌ Post-processing stack (any effect)
❌ Real-time shadow casting and receiving
❌ AVPro video player
❌ Screen-space ambient occlusion (SSAO)
❌ Screen-space reflections (SSR)
❌ Tessellation and geometry shaders
❌ Compute shaders (limited/unavailable)
❌ Some particle system modules (trails, sub-emitters in complex setups)
```

### World Build Size Management

```
Target size breakdown (5–8 MB goal):

Textures:       2–4 MB  (largest contributor — compress aggressively)
Meshes:         1–2 MB
Audio:          0.5–1 MB
Other assets:   0.5 MB

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

```
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

```
Goal: minimize unique material count (target < 25)

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

```
LOD (Level of Detail) setup:
├── LOD0: full detail   (within ~10m)
├── LOD1: 50% tris      (10–30m)
├── LOD2: 20% tris      (30–60m)
└── Culled              (beyond 60m)

Decimation targets for Quest:
□ Hero/focal objects:   ≤ 5K triangles
□ Background objects:   ≤ 1K triangles
□ Ground/floor planes:  minimize subdivision
□ Total scene:          50K–100K triangles (hard cap 200K)

Additional steps:
□ Remove interior faces never visible to players
□ Weld duplicate vertices
□ Apply mesh compression in import settings (Medium or High)
```

### Baked Lighting Workflow for Quest

```
Mandatory: all lighting must be baked before uploading the Quest build.

Recommended settings for Quest:
├── Lightmapper:           Progressive CPU (stable) or GPU
├── Lightmap Resolution:   5–10 texels/unit (lower = smaller textures)
├── Lightmap Size:         1024×1024 max per map
├── Directional Mode:      Non-Directional  ← required for Quest
├── Ambient Occlusion:     Baked only (no SSAO)
└── Compress Lightmaps:    ✓ (reduces build size significantly)

Checklist:
□ All lights set to Baked or Mixed mode
□ Realtime lights = 0 in Quest build
□ Light Probes placed for dynamic objects (players, pickups)
□ Reflection Probes set to Baked, resolution 128
□ Window > Rendering > Lighting > Generate Lighting → complete without errors
□ No "Baking" or "Auto" warnings in the Lighting window
```

### Draw Call Reduction

```
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

```
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

```
□ Android build size after compression < 100 MB
□ Targeting 5–8 MB for typical worlds
□ No uncompressed or oversized textures (check via Project > Stats)
□ No duplicate assets left in the project
```

### Shaders and Materials

```
□ All materials use Mobile-compatible shaders:
    - Mobile/Diffuse
    - Mobile/Bumped Diffuse
    - Mobile/Particles/Alpha Blended
    - VRChat/Mobile/Toon Lit (if using VRChat shaders)
□ No custom HLSL shaders or unsupported ShaderLab features
□ GPU Instancing enabled on all materials applied to repeated objects
□ Material count < 25 per scene section
□ No post-processing volumes or components in the scene
```

### Lighting

```
□ Lighting fully baked (Window > Rendering > Lighting shows no pending bake)
□ Realtime lights = 0 (or removed entirely)
□ No Mixed lights with Shadowmask (baked-only mode required)
□ Directional Mode set to Non-Directional in Lighting Settings
□ Light Probes cover all player-accessible areas
□ Reflection Probes baked, resolution ≤ 128
□ Lightmap textures compressed
```

### Geometry

```
□ Total triangle count < 200K (target 50K–100K)
□ LOD groups configured for all objects > 1K triangles
□ No excessive particle systems (count ≤ 10, particles/system ≤ 100)
□ Occlusion Culling baked and verified
□ Static Batching enabled for all non-moving objects
```

### Platform-Specific Features

```
□ No AVPro video player components — replaced with Unity Video Player
□ No post-processing components (Post Process Volume, etc.)
□ No real-time shadow settings on any light
□ No screen-space effects in any material or renderer
□ Audio sources: compressed formats, streaming for BGM
```

### Testing

```
□ Build and Run targeting Android in Unity — check for shader errors
□ Tested in VRChat on actual Quest hardware or using a Quest emulator
□ Frame rate monitored: stable 72 FPS at spawn with 1 player
□ No visible lighting artifacts (dark patches, blown-out areas)
□ All interactive elements (pickups, triggers) work correctly on Quest
□ No crashes or memory warnings during extended play session
```
