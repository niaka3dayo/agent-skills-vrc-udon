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

```text

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

```text

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

```text

Static objects (Static):
├── Inspector > Static check
├── Contribute GI: ✅
└── Receive GI: Lightmaps

Dynamic objects:
├── Contribute GI: ❌
└── Receive GI: Light Probes

```

### Baking Procedure

```text

1. Bake environment lighting; identify any effect that truly needs Mixed/Realtime
2. Mark static objects as Static
3. Place Light Probes
4. Click "Generate Lighting" in the Lighting window
5. Wait for completion (minutes to hours)
6. Review results and adjust as needed

```

---

## Light Probes

### Purpose

```text

Light Probes:
- Apply baked lighting influence to
  dynamic objects (players, pickups)
- For objects that can't use Lightmaps
- Achieve dynamic lighting effects at low cost

```

### Placement Guidelines

```text

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

```text

1. GameObject > Light > Light Probe Group
2. Click Edit Light Probes button
3. Add/move probes
4. Place in 3D (not just on the floor, include height)
5. Update with Generate Lighting

```

### Placement Density

```text

Recommended density:
├── Indoor corridors: 2-3m intervals
├── Large open spaces: 3-5m intervals
├── Light/dark boundaries: 1m or less
└── Height: Multiple levels at 0.5m, 1.5m, 3m, etc.

```

---

## Reflection Probes

### Purpose

```text

Reflection Probes:
- Provide environmental reflections
- Improve quality of metallic/glossy surfaces
- Alternative to realtime reflections

```

### Settings

```text

Recommended settings:
├── Type: Baked (avoid Realtime)
├── Resolution: 128-256
├── HDR: ✅ (when quality is important)
├── Box Projection: Only when needed
├── Importance: 1 (default)
└── Blend Distance: 1-3

```

### Placement

```text

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

### Android Starting Settings

```text

Recommended baseline:
├── Environment lights baked
├── Directional Mode: start with Non-Directional and compare quality/memory
├── Lightmap Size: 512-1024
├── Compress Lightmaps: ✅
└── Realtime or Mixed lighting: retain only after target-device profiling

Recommended shaders:
├── Mobile/VRChat/Lightmapped
├── Mobile/Diffuse
└── Mobile/Particles

```

### Quest Lighting Procedure

```text

1. Switch Platform to Android
2. Bake environment lighting as the default
3. Keep only necessary Mixed or Realtime effects and measure them on target hardware
4. Lower lightmap resolution
5. Place Light Probes
6. Generate Lighting
7. Test on Quest hardware

```

---

## Common Issues

### Blurry Lightmaps

**Solution**:

```text

1. Increase Lightmap Resolution (10→20)
2. Increase Lightmap Size (1024→2048)
3. Check object UV2
4. Enable Generate Lightmap UVs

```

### Visible Seams

**Solution**:

```text

1. Increase Lightmap Padding (2→4)
2. Check object scale
3. Adjust UV2 seams

```

### Dark Dynamic Objects

**Solution**:

```text

1. Place Light Probes
2. Set Receive GI to Light Probes
3. Re-run Generate Lighting

```

### Slow Baking

**Solution**:

```text

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

```text

□ Environment lighting baked; any Mixed/Realtime exception profiled on target hardware
□ Static objects are marked Static
□ Light Probes placed
□ Reflection Probes placed
□ Lightmaps baked
□ Android: realtime or Mixed lighting justified by target-device profiling
□ Android: Directional Mode selected after comparing memory and visual quality

```

### Performance Guidelines

| Setting | PC | Quest |
|---------|-----|-------|
| Lightmap Resolution | 20 | 10 |
| Lightmap Size | 2048 | 1024 |
| Reflection Probe Res | 256 | 128 |
| Realtime Lighting | Profile | Baked default; retain only with target-device profiling |

---

## Quest Bake Parameter Reference

Detailed recommended parameters for baking lightmaps targeting Quest/Android. These supplement the Quick Reference table with rationale and acceptable ranges.

### Lightmap Resolution: PC vs Quest

| Setting | PC | Quest | Why |
|---|---|---|---|
| Lightmap Resolution | 10–20 texels/unit | **5–10 texels/unit** | Lower resolution keeps lightmap textures within 1024×1024 and reduces build size |
| Max Lightmap Size | 2048×2048 | **1024×1024** | Quest GPU memory is limited; oversized lightmaps cause stuttering and load failures |
| Directional Mode | Directional or Non-Directional | **Start with Non-Directional** | Directional mode stores extra lightmap data; keep it only when measured memory cost and visual quality justify it |
| Compress Lightmaps | Optional | **Recommended baseline** | Compare memory and visual artifacts; the final compressed world must remain under the 100 MB Android limit |

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
│   ├── Yes → Prototype Mixed or Realtime, then keep it only if target-device profiling passes
│   └── No  → Switch to Baked and use light probes for dynamics
└── No  → Use Baked for everything

```

| Mode | Quest Support | Notes |
|---|---|---|
| **Baked** | Supported | Recommended default for environment lighting |
| **Mixed** | Supported in worlds | Measure shadow, memory, and GPU cost on the target device |
| **Realtime** | Supported in worlds | Very expensive; keep only with a demonstrated need and target-device evidence |

Practical rule: bake the default Android lighting first. Use platform-specific
content when necessary, and document target-device measurements for any Mixed or
Realtime lighting that remains.

### Baked Ambient Occlusion

Baked AO stores the effect in the lightmap rather than evaluating screen-space AO at runtime. Post-processing, including SSAO, is disabled on Android.

```text

Window > Rendering > Lighting > Lightmapping Settings

Recommended settings for Quest:
├── Ambient Occlusion: ✓ Enabled
├── Max Distance:       1.0–2.0 m  (larger = broader but softer AO)
├── Indirect AO:        0.5–1.0
└── Direct AO:          0 (default — direct AO can look artificial)

PC can use higher Max Distance (2–3 m) for richer results.

```

> Baked AO is stored in the lightmap. Check bake time, texture memory, and the
> result in headset before keeping it.

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
| HDR | Start disabled | Compare reflection texture memory and visual range; enable only where the measured result justifies it |
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
Direction:  Directional (opt.)     Direction:  Start Non-Directional; measure alternatives
Compress:   Optional               Compress:   Recommended baseline; verify artifacts
AO:         Optional (baked)       AO:         Baked baseline; post-processing disables SSAO
Refl. res:  256                    Refl. res:  128
Lights:     Mixed or Baked         Lights:     Baked default; profile exceptions

```

## See Also

- [performance.md](performance.md) - Overall performance targets and Quest optimization checklist that governs lighting budgets
