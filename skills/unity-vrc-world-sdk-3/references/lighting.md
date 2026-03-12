# VRChat World Lighting Guide

Lighting settings and optimization guide for VRChat worlds.

## Table of Contents

- [Lighting Fundamentals](#lighting-fundamentals)
- [Baked Lighting](#baked-lighting)
- [Light Probes](#light-probes)
- [Reflection Probes](#reflection-probes)
- [Quest Optimization](#quest-optimization)
- [Common Issues](#common-issues)

---

## Lighting Fundamentals

### Light Modes

| Mode | Performance | Dynamic Objects | Use Case |
|------|-------------|-----------------|----------|
| **Baked** | ✅ Best | ❌ No effect | Static environment |
| **Mixed** | ⚠️ Moderate | ✅ Affected | When dynamic shadows needed |
| **Realtime** | ❌ Heavy | ✅ Full support | Avoid whenever possible |

### Recommended Approach

```
✅ Recommended:
1. Environment lights → Baked
2. Light Probes → For dynamic objects
3. Reflection Probes → Improve reflection quality

❌ Avoid:
1. Realtime lights (dynamic shadows)
2. Excessive lightmap resolution
3. Many Mixed lights
```

---

## Baked Lighting

### Lightmap Settings

```
Window > Rendering > Lighting

Recommended settings:
├── Lightmapper: Progressive GPU (fast)
├── Lightmap Resolution: 10-20 texels/unit
├── Lightmap Padding: 2
├── Lightmap Size: 1024 (Quest) / 2048 (PC)
├── Compress Lightmaps: ✅
├── Ambient Occlusion: ✅
│   ├── Max Distance: 1-3
│   └── Indirect/Direct Contribution: 0.5-1
└── Directional Mode: Non-Directional (Quest)
```

### Object Settings

```
Static objects (Static):
├── Inspector > Static check
├── Contribute GI: ✅
└── Receive GI: Lightmaps

Dynamic objects:
├── Contribute GI: ❌
└── Receive GI: Light Probes
```

### Baking Procedure

```
1. Set all lights to Baked/Mixed
2. Mark static objects as Static
3. Place Light Probes
4. Click "Generate Lighting" in the Lighting window
5. Wait for completion (minutes to hours)
6. Review results and adjust as needed
```

---

## Light Probes

### Purpose

```
Light Probes:
- Apply baked lighting influence to
  dynamic objects (players, pickups)
- For objects that can't use Lightmaps
- Achieve dynamic lighting effects at low cost
```

### Placement Guidelines

```
Place at:
✅ Where players walk
✅ Light/dark boundaries
✅ Where colors change
✅ Indoor/outdoor boundaries
✅ Distribute vertically as well

Do NOT place at:
❌ Inside walls
❌ Unreachable areas
❌ Areas with only static objects
```

### Creation Steps

```
1. GameObject > Light > Light Probe Group
2. Click Edit Light Probes button
3. Add/move probes
4. Place in 3D (not just on the floor, include height)
5. Update with Generate Lighting
```

### Placement Density

```
Recommended density:
├── Indoor corridors: 2-3m intervals
├── Large open spaces: 3-5m intervals
├── Light/dark boundaries: 1m or less
└── Height: Multiple levels at 0.5m, 1.5m, 3m, etc.
```

---

## Reflection Probes

### Purpose

```
Reflection Probes:
- Provide environmental reflections
- Improve quality of metallic/glossy surfaces
- Alternative to realtime reflections
```

### Settings

```
Recommended settings:
├── Type: Baked (avoid Realtime)
├── Resolution: 128-256
├── HDR: ✅ (when quality is important)
├── Box Projection: Only when needed
├── Importance: 1 (default)
└── Blend Distance: 1-3
```

### Placement

```
Place at:
├── One per room
├── One large one outdoors
├── Where special reflections are needed
└── Consider overlap

Notes:
- Too many increases overhead
- Proper Bounds settings are important
```

---

## Quest Optimization

### Quest-Specific Settings

```
Required:
├── All lights set to Baked
├── Directional Mode: Non-Directional
├── Lightmap Size: 512-1024
├── Compress Lightmaps: ✅
└── Realtime lights: 0

Recommended shaders:
├── Mobile/VRChat/Lightmapped
├── Mobile/Diffuse
└── Mobile/Particles
```

### Quest Lighting Procedure

```
1. Switch Platform to Android
2. Remove all Realtime lights
3. Change Mixed → Baked
4. Lower lightmap resolution
5. Place Light Probes
6. Generate Lighting
7. Test on Quest hardware
```

---

## Common Issues

### Blurry Lightmaps

**Solution**:
```
1. Increase Lightmap Resolution (10→20)
2. Increase Lightmap Size (1024→2048)
3. Check object UV2
4. Enable Generate Lightmap UVs
```

### Visible Seams

**Solution**:
```
1. Increase Lightmap Padding (2→4)
2. Check object scale
3. Adjust UV2 seams
```

### Dark Dynamic Objects

**Solution**:
```
1. Place Light Probes
2. Set Receive GI to Light Probes
3. Re-run Generate Lighting
```

### Slow Baking

**Solution**:
```
1. Use Progressive GPU
2. Lower Lightmap Resolution
3. Remove unnecessary objects from Static
4. Reduce Bounces (2-3)
```

---

## Shader Global Variables

```csharp
// Lighting-related shader variables
// _VRChatCameraMode:
//   0 = Normal
//   1 = VR handheld
//   2 = Desktop handheld
//   3 = Screenshot

// Available for use in custom shaders
```

---

## Quick Reference

### Settings Checklist

```
□ All lights are Baked/Mixed
□ Static objects are marked Static
□ Light Probes placed
□ Reflection Probes placed
□ Lightmaps baked
□ Quest: Realtime lights = 0
□ Quest: Directional Mode = Non-Directional
```

### Performance Guidelines

| Setting | PC | Quest |
|---------|-----|-------|
| Lightmap Resolution | 20 | 10 |
| Lightmap Size | 2048 | 1024 |
| Reflection Probe Res | 256 | 128 |
| Realtime Lights | 0-1 | 0 |
