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
| 3 | - | Unused |
| 4 | Water | Water surfaces |
| 5 | UI | Unity UI |

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
| 19 | reserved2 | Reserved |
| 20 | reserved3 | Reserved |
| 21 | reserved4 | Reserved |

---

## User Layers (22-31)

**Available for custom use**: Names and collision settings are preserved.

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
| 31 | Custom purpose 10 |

### Commonly Used Custom Layers

```
Layer 22: "Intangible" - Decorations with no collision
Layer 23: "LocalOnly" - Local-only objects
Layer 24: "TriggerZone" - Trigger zones only
Layer 25: "Projectiles" - Projectiles
```

---

## Layer Usage Guidelines

### Default (Layer 0)

```
Purpose:
- General objects
- Objects that don't need special handling

Notes:
- Collides with players
- Detected by Raycast
```

### Environment (Layer 11)

```
Purpose:
- Walls, floors, ceilings
- Walkable terrain
- Obstacles

Characteristics:
- Reliably collides with players
- Pickups also collide
```

### Pickup (Layer 13)

```
Purpose:
- Objects with VRC_Pickup

Characteristics:
- Collides with players
- Collides with environment
- Collision with other Pickups depends on settings
```

### PickupNoEnvironment (Layer 14)

```
Purpose:
- Pickups that pass through environment
- Objects that can be handed through walls

Characteristics:
- Collides with players
- Does NOT collide with environment
```

### Walkthrough (Layer 17)

```
Purpose:
- Walk-through objects
- Visual barriers
- Effect colliders

Characteristics:
- Players can walk through
- Trigger events can still fire
```

### MirrorReflection (Layer 18)

```
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

```
Edit > Project Settings > Physics > Layer Collision Matrix
```

### VRChat Default Collision Matrix

```
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

```
✅ Choose the appropriate layer:
- Floors, walls → Environment
- Grabbable items → Pickup
- Decorations (no collision needed) → User Layer + collision disabled

✅ Use User Layers:
- When custom collision settings are needed
- For specific Raycast filtering
```

### Prohibited Actions

```
❌ Avoid:
- Renaming VRChat reserved layers
- Using Player/PlayerLocal layers (VRChat exclusive)
- Enabling unnecessary collisions
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

```
0  = Default
9  = Player
10 = PlayerLocal
11 = Environment
13 = Pickup
14 = PickupNoEnvironment
17 = Walkthrough
18 = MirrorReflection
22-31 = User Layers (custom)
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
