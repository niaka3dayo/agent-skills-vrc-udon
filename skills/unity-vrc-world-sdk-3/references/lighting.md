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

---

## Quest Bake Parameter Reference

Detailed recommended parameters for baking lightmaps targeting Quest/Android. These supplement the Quick Reference table with rationale and acceptable ranges.

### Lightmap Resolution: PC vs Quest

| Setting | PC | Quest | Why |
|---|---|---|---|
| Lightmap Resolution | 10–20 texels/unit | **5–10 texels/unit** | Lower resolution keeps lightmap textures within 1024×1024 and reduces build size |
| Max Lightmap Size | 2048×2048 | **1024×1024** | Quest GPU memory is limited; oversized lightmaps cause stuttering and load failures |
| Directional Mode | Directional or Non-Directional | **Non-Directional (required)** | Directional mode stores an extra texture per lightmap; not worth the cost on Quest |
| Compress Lightmaps | Optional | **Required** | Uncompressed lightmaps can exceed the 100 MB Android build limit |

> If your world still looks dark or blurry at 5 texels/unit, increase to 10 before raising Max Size.
> Raising resolution is cheaper in quality terms; raising size increases memory consumption more.

### Bounce Count

Bounces control how many times indirect light reflects off surfaces. More bounces improve realism but increase bake time and can add unwanted light bleed.

| Platform | Recommended Bounces | Notes |
|---|---|---|
| Quest | **2–3** | Sufficient for enclosed interiors; 2 is often enough outdoors (approximate guideline — adjust based on profiling) |
| PC | 3–4 | Use 4 only for complex interiors with many reflective surfaces (approximate guideline — adjust based on profiling) |

In Unity Lighting Settings:
```text
Window > Rendering > Lighting > Lightmapping Settings
└── Indirect Bounces: 2  (Quest)  /  3  (PC)
```

### Baked vs Mixed Lighting: Quest Guidance

On Quest, **Baked lighting is strongly preferred over Mixed**. Use this decision guide:

```text
Does the world have any moving lights or real-time shadows?
├── Yes → Is this required? (gameplay mechanic, not just aesthetics)
│   ├── Yes → Use Mixed (PC only); remove or replace with Baked on Android build
│   └── No  → Switch to Baked and use light probes for dynamics
└── No  → Use Baked for everything
```

| Mode | Quest Support | Notes |
|---|---|---|
| **Baked** | Full support | Required for Quest builds; zero runtime cost |
| **Mixed (Subtractive)** | Partial support | Shadowmask not fully supported; avoid |
| **Mixed (Shadowmask)** | Not recommended | Extra memory, inconsistent shadow behaviour |
| **Realtime** | Avoid | No shadow support on Quest; significant GPU cost even without shadows |

Practical rule: **convert all Mixed lights to Baked before the Android build**. Use the Platform Override workflow (Unity Build Settings → Android) to maintain separate PC and Quest lighting if needed.

### Baked Ambient Occlusion

Baked AO adds depth cues where surfaces meet, at zero runtime cost. Screen-space AO (SSAO) is unavailable on Quest.

```text
Window > Rendering > Lighting > Lightmapping Settings

Recommended settings for Quest:
├── Ambient Occlusion: ✓ Enabled
├── Max Distance:       1.0–2.0 m  (larger = broader but softer AO)
├── Indirect AO:        0.5–1.0
└── Direct AO:          0 (default — direct AO can look artificial)

PC can use higher Max Distance (2–3 m) for richer results.
```

> Baked AO is included in the base lightmap texture — no extra textures or memory.
> Enable it for all Quest builds without hesitation.

### Light Probe Density (Quest)

Light probes provide baked lighting influence to dynamic objects (players, pickups). More probes improve quality; excessive probes increase bake time and CPU cost.

| Area Type | Quest Recommended Spacing | Notes |
|---|---|---|
| Narrow corridors | 2–3 m intervals | Players fill most of the space |
| Open indoor areas | 3–4 m intervals | Sufficient for smooth transitions |
| Light/shadow boundaries | ≤ 1 m intervals | Tight clustering prevents hard edges |
| Outdoor areas | 4–6 m intervals | Light varies slowly outdoors |

Vertical placement: place probes at multiple heights (floor level ~0.5 m, mid-body ~1.5 m, head ~2 m) to capture the full player silhouette.

### Reflection Probe Settings (Quest)

| Setting | Quest Recommended | Notes |
|---|---|---|
| Type | **Baked** | Realtime probes re-render every frame — avoid on Quest |
| Resolution | **128** | 256 is acceptable for hero areas only |
| HDR | Disabled | Saves ~50% reflection texture memory; enable only for hero areas with highly reflective metallic or glossy surfaces that require HDR reflections |
| Box Projection | Only when needed | Adds overdraw; use only in box-shaped rooms |

Aim for one probe per enclosed room and one large probe outdoors. Avoid overlapping more than 2–3 probes in any one area.

---

## Lighting Workflow Summary: PC vs Quest

```text
PC Build                           Quest/Android Build
────────────────────────────────   ──────────────────────────────────
Resolution: 10–20 texels/unit      Resolution: 5–10 texels/unit
Max Size:   2048×2048              Max Size:   1024×1024
Bounces:    3–4                    Bounces:    2–3
Direction:  Directional (opt.)     Direction:  Non-Directional (required)
Compress:   Optional               Compress:   Required
AO:         Optional (baked)       AO:         Baked only (no SSAO)
Refl. res:  256                    Refl. res:  128
Lights:     Mixed or Baked         Lights:     Baked only
```

## See Also

- [performance.md](performance.md) - Overall performance targets and Quest optimization checklist that governs lighting budgets
