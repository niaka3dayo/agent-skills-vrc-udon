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
