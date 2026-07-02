# VRChat Layers and Collision Reference

## Overview

VRChat uses Unity's layer system to organize GameObjects, control collisions, and perform selective rendering. When you create a project with the VRChat SDK, layers are automatically configured.

**Important**: Renaming or deleting VRChat reserved layers (0-21) will be overwritten at upload time.

---

## VRChat Reserved Layers (0-21)

### System Layers

| Layer # | Name | Purpose |
|---------|------|---------|
| 0 | Default | General objects |
| 1 | TransparentFX | Transparent effects |
| 2 | Ignore Raycast | Ignored by Raycast |
| 3 | Item | VRChat items placed by users; moved to Default at upload |
| 4 | Water | Water surfaces |
| 5 | UI | Unity UI |
| 6 | reserved6 | Reserved by VRChat - do not use |
| 7 | reserved7 | Reserved by VRChat - do not use |

### VRChat-Specific Layers

| Layer # | Name | Purpose |
|---------|------|---------|
| 8 | Interactive | Interactable objects |
| 9 | Player | Remote players |
| 10 | PlayerLocal | Local player |
| 11 | Environment | Environment objects (walls, floors) |
| 12 | UiMenu | VRChat UI menu |
| 13 | Pickup | Grabbable objects |
| 14 | PickupNoEnvironment | Pickups that don't collide with environment |
| 15 | StereoLeft | Stereo left eye |
| 16 | StereoRight | Stereo right eye |
| 17 | Walkthrough | Walk-through objects |
| 18 | MirrorReflection | Mirror reflection |
| 19 | InternalUI | VRChat menu, nameplates, debug panels - do not use |
| 20 | HardwareObjects | Controller/tracker models in-game - do not use |
| 21 | reserved4 | Reserved; objects on it move to Default at upload |

Layers 19/20 were previously named reserved2/reserved3 - VRChat has renamed
runtime layers before, which is another reason not to rely on layer names in
scripts.

---

## User Layers (22-31)

The **collision matrix** you configure for layers 22-31 IS preserved in
uploaded worlds.

Layer **names are NOT preserved**: at runtime the VRChat client overrides them
to `user0`-`user9` (layer 22 = `user0`, ... layer 31 = `user9`).

> **Note: This contradicts the official documentation (verified by runtime
> testing).** The official docs state that VRChat "will not override the name
> and collision matrix" of layers 22-31. Runtime observation (2026-07) shows
> layer *names* ARE overridden to `user0`-`user9`; only the collision matrix is
> preserved. See [Issue #286](https://github.com/niaka3dayo/agent-skills-vrc-udon/issues/286)
> (includes a layer-dump script and full runtime output) and
> [this independent report](https://ask.vrchat.com/t/user-defined-unity-layers-raycasts-ignored-by-vrchat/47933).
> If official docs or client behavior change, re-verify with the layer-dump
> script in #286.

| Layer # | Suggested Use |
|---------|---------------|
| 22 | Custom purpose 1 |
| 23 | Custom purpose 2 |
| 24 | Custom purpose 3 |
| 25 | Custom purpose 4 |
| 26 | Custom purpose 5 |
| 27 | Custom purpose 6 |
| 28 | Custom purpose 7 |
| 29 | Custom purpose 8 |
| 30 | Custom purpose 9 |
| 31 | Avoid - Unity Editor preview uses it (see note below) |

Naming user layers in the editor is fine for organization, but **scripts must
reference user layers by number or bitmask** - never by name.

`LayerMask.NameToLayer("YourCustomName")` returns the correct layer in the
editor and ClientSim, but returns `-1` in the live client because the name was
overridden. Feeding `-1` into a shift does not fail loudly: C# masks the shift
count to its low 5 bits, so `1 << -1` evaluates to `1 << 31` and the mask
silently targets layer 31 instead of your layer. This "works in ClientSim,
breaks in the live client" divergence is the failure mode reported in
Issue #286.

```csharp
// ✅ Safe: reference user layers by number
private const int LAYER_PROJECTILES = 25;
int projectileMask = 1 << LAYER_PROJECTILES;

// ❌ Breaks in the live client: custom layer names are overridden to user0-user9
int broken = LayerMask.NameToLayer("Projectiles"); // returns -1 at runtime
int brokenMask = 1 << broken; // == 1 << 31: wrong layer, no error raised
```

Layer 31 is named `user9` at runtime, but the official docs recommend avoiding
it because Unity Editor preview mechanics use it. Suggested usable range:
22-30.

### Commonly Used Custom Layers

```text
Layer 22: "Intangible" - Decorations with no collision
Layer 23: "LocalOnly" - Local-only objects
Layer 24: "TriggerZone" - Trigger zones only
Layer 25: "Projectiles" - Projectiles
```

These names are editor-side organization only; scripts should still use layer
numbers or bitmasks.

---

## Layer Usage Guidelines

### Default (Layer 0)

```text
Purpose:
- General objects
- Objects that don't need special handling

Notes:
- Collides with players
- Detected by Raycast
```

### Environment (Layer 11)

```text
Purpose:
- Walls, floors, ceilings
- Walkable terrain
- Obstacles

Characteristics:
- Reliably collides with players
- Pickups also collide
```

### Pickup (Layer 13)

```text
Purpose:
- Objects with VRC_Pickup

Characteristics:
- Collides with players
- Collides with environment
- Collision with other Pickups depends on settings
```

### PickupNoEnvironment (Layer 14)

```text
Purpose:
- Pickups that pass through environment
- Objects that can be handed through walls

Characteristics:
- Collides with players
- Does NOT collide with environment
```

### Walkthrough (Layer 17)

```text
Purpose:
- Walk-through objects
- Visual barriers
- Effect colliders

Characteristics:
- Players can walk through
- Trigger events can still fire
```

### MirrorReflection (Layer 18)

```text
Purpose:
- Objects to display in mirrors
- Mirror-only layer

Notes:
- Not visible to regular cameras
- Displayed only in mirrors
```

---

## Collision Matrix

### Checking the Current Matrix

```text
Edit > Project Settings > Physics > Layer Collision Matrix
```

### VRChat Default Collision Matrix

```text
Important collision pairs:

✅ Collide:
- Player ↔ Environment
- Player ↔ Pickup
- PlayerLocal ↔ Environment
- Pickup ↔ Environment

❌ Do NOT collide:
- Player ↔ Player (VRChat controlled)
- Player ↔ PlayerLocal
- PickupNoEnvironment ↔ Environment
- Walkthrough ↔ Player
```

### Custom Layer Collision Settings

```csharp
// Set layer collision via script (editor only)
#if UNITY_EDITOR
Physics.IgnoreLayerCollision(22, 11, true); // Disable collision between Layer 22 and Environment
#endif
```

---

## Layer Masks in Udon

`LayerMask.NameToLayer` and `LayerMask.GetMask` are only safe with
**VRChat-defined layer names** that are verified present at runtime. For user
layers 22-31, always use numeric constants.

### Getting Layer Masks

```csharp
// Get mask from layer number
int playerLayer = LayerMask.NameToLayer("Player");
int layerMask = 1 << playerLayer;

// Multiple layer mask
int mask = (1 << LayerMask.NameToLayer("Player")) |
           (1 << LayerMask.NameToLayer("Environment"));
```

### Raycast with Layer Masks

```csharp
// Raycast only specific layers
int playerMask = 1 << 9; // Player layer

RaycastHit hit;
if (Physics.Raycast(origin, direction, out hit, maxDistance, playerMask))
{
    // Hit a Player
}

// Exclude specific layers
int everythingExceptPlayer = ~(1 << 9);
```

### Commonly Used Layer Masks

```csharp
// Common masks
private int _environmentMask;
private int _playerMask;
private int _pickupMask;

void Start()
{
    _environmentMask = 1 << LayerMask.NameToLayer("Environment");
    _playerMask = 1 << LayerMask.NameToLayer("Player");
    _pickupMask = 1 << LayerMask.NameToLayer("Pickup");
}
```

---

## Layer Best Practices

### Recommendations

```text
✅ Choose the appropriate layer:
- Floors, walls → Environment
- Grabbable items → Pickup
- Decorations (no collision needed) → User Layer + collision disabled

✅ Use User Layers:
- When custom collision settings are needed
- For specific Raycast filtering
- Reference user layers from scripts by number or constants
```

### Prohibited Actions

```text
❌ Avoid:
- Renaming VRChat reserved layers
- Using Player/PlayerLocal layers (VRChat exclusive)
- Enabling unnecessary collisions
- Referencing user layers (22-31) by name in scripts
```

---

## Troubleshooting

### Common Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| Player walks through walls | Wrong layer | Set to Environment |
| Pickup falls through floor | Using PickupNoEnvironment | Change to Pickup |
| Object not visible in mirror | Layer settings | Check MirrorReflection |
| Raycast not detecting | Layer mask | Use correct mask |
| Works in ClientSim only | Custom layer name lookup | Use layer numbers |

### Debugging Layer Issues

```csharp
// Check an object's layer
Debug.Log($"Layer: {gameObject.layer} ({LayerMask.LayerToName(gameObject.layer)})");

// Check collision matrix
bool willCollide = !Physics.GetIgnoreLayerCollision(layerA, layerB);
Debug.Log($"Layers {layerA} and {layerB} collision: {willCollide}");
```

---

## Quick Reference

### Layer Number List

```text
0  = Default
9  = Player
10 = PlayerLocal
11 = Environment
13 = Pickup
14 = PickupNoEnvironment
17 = Walkthrough
18 = MirrorReflection
22-31 = User Layers (collision kept; names become user0-user9 — use numbers)
```

### Common Operations

```csharp
// Set layer
gameObject.layer = LayerMask.NameToLayer("Pickup");

// Check layer
if (gameObject.layer == LayerMask.NameToLayer("Environment")) { }

// Change all children including self
foreach (Transform child in transform.GetComponentsInChildren<Transform>())
{
    child.gameObject.layer = newLayer;
}
```
