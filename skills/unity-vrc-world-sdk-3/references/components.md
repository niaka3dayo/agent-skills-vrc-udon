# VRChat World Components Complete Reference

Full component reference for SDK 3.7.1 - 3.10.2.

## Table of Contents

- [VRC_SceneDescriptor](#vrc_scenedescriptor)
- [VRC_Pickup](#vrc_pickup)
- [VRC_Station](#vrc_station)
- [VRC_ObjectSync](#vrc_objectsync)
- [VRC_MirrorReflection](#vrc_mirrorreflection)
- [VRC_PortalMarker](#vrc_portalmarker)
- [VRC_SpatialAudioSource](#vrc_spatialaudiosource)
- [VRC_UIShape](#vrc_uishape)
- [VRC_AvatarPedestal](#vrc_avatarpedestal)
- [VRC_CameraDolly](#vrc_cameradolly)
- [VRCCameraSettings API](#vrccamerasettings-api)
- [Allowed Unity Components](#allowed-unity-components)

---

## VRC_SceneDescriptor

**Required**: One is needed in every VRChat world.

### All Properties

| Property | Type | Description | Default |
|----------|------|-------------|---------|
| Spawns | Transform[] | Array of spawn points | Descriptor position |
| Spawn Order | SpawnOrder | Sequential/Random/Demo | Sequential |
| Respawn Height | float | Respawn Y coordinate | -100 |
| Object Behaviour At Respawn | enum | Respawn/Destroy | Respawn |
| Reference Camera | Camera | Camera settings reference | None |
| Forbid User Portals | bool | Disable portals | false |
| Voice Falloff Range | float | Voice attenuation range | - |
| Interact Passthrough | LayerMask | Interact passthrough | Nothing |
| Maximum Capacity | int | Max player count | - |
| Recommended Capacity | int | Recommended player count | - |
| Dynamic Materials | Material[] | Dynamic materials | - |
| Dynamic Prefabs | GameObject[] | Dynamic prefabs | - |

### Spawn Order Details

```csharp
// Sequential: Spawn in order
// Join order: Player1→Spawn0, Player2→Spawn1, Player3→Spawn2, Player4→Spawn0...

// Random: Random selection
// Different spawn point each time

// Demo: All at the same location
// All players appear at Spawns[0]
```

### Reference Camera Settings

```csharp
// Usage:
// 1. Near Clip Plane: 0.01m recommended for VR
// 2. Far Clip Plane: Adjust based on world size
// 3. Post Processing: Apply Profile
// 4. Background: Skybox or Solid Color
// 5. Clear Flags: Settings are inherited

// Setup steps:
// 1. Create a Camera
// 2. Adjust settings
// 3. Disable the Camera component
// 4. Assign to SceneDescriptor's Reference Camera
```

### Capacity Behavior

```csharp
// Maximum Capacity:
// - No new joins once this count is reached
// - Hard limit

// Recommended Capacity:
// - Hidden from public listings when reached
// - Soft limit (direct join is still possible)

// Note: In older SDKs, when Recommended was not set,
// the actual Max = specified value × 2 (bug)
```

---

## VRC_Pickup

Allows players to grab objects.

### Required Setup

```
[Pickup GameObject]
├── Collider (Required)
│   └── IsTrigger = true recommended
├── Rigidbody (Required)
│   ├── Use Gravity = true/false
│   └── Is Kinematic = false (when held)
├── VRC_Pickup
└── VRC_ObjectSync (for network sync)
```

### All Properties

| Property | Type | Description | Default |
|----------|------|-------------|---------|
| Interaction Text | string | Text displayed on desktop | - |
| Use Text | string | Use text in VR | - |
| Throw Velocity Boost Min Speed | float | Boost start speed | - |
| Throw Velocity Boost Scale | float | Throw acceleration multiplier | - |
| Pickupable | bool | Can be grabbed | true |
| Pickup Orientation | enum | Any/Grip/Gun | Any |
| Allow Theft | bool | Allow stealing | true |
| Exact Grip | Transform | Exact grip position | null |
| Exact Gun | Transform | Exact gun position | null |
| Proximity | float | Pickup distance | 2.0 |
| **Auto Hold** | enum | Yes/No/AutoDetect | No |

### Auto Hold (SDK 3.9+)

```csharp
// v1.0 (old): AutoDetect / Yes / No
// v1.1 (new): Checkbox (Yes/No only)

// Yes: Keeps holding after releasing grip
// No: Only held while gripping

// AutoDetect (v1.0 only):
// Auto-determines based on object size
```

### Pickup Orientation

```csharp
// Any: Held at the grab position
//      Small items, balls, etc.

// Grip: Held at grip position
//       Handles, tools, etc.

// Gun: Gun holding pose
//      Guns, pointers, etc.
```

### Udon Events

```csharp
public class PickupHandler : UdonSharpBehaviour
{
    // When grabbed
    public override void OnPickup()
    {
        Debug.Log("Picked up!");
    }

    // When released
    public override void OnDrop()
    {
        Debug.Log("Dropped!");
    }

    // Trigger pressed (VR) / Left click (Desktop)
    public override void OnPickupUseDown()
    {
        Debug.Log("Use started!");
    }

    // Trigger released
    public override void OnPickupUseUp()
    {
        Debug.Log("Use ended!");
    }
}
```

### Network Sync

```csharp
// When VRC_ObjectSync is added:
// - Position and rotation are auto-synced
// - Physics state is synced
// - Ownership is auto-managed

// Ownership flow:
// 1. Grab → Local player becomes owner
// 2. Release → Ownership maintained
// 3. Another player grabs → Ownership transfers
```

---

## VRC_Station

Creates a location where players can sit.

### Required Setup

```
[Station GameObject]
├── Collider (Required - for Interact)
└── VRC_Station
    ├── Entry Transform (optional)
    └── Exit Transform (optional)
```

### All Properties

| Property | Type | Description | Default |
|----------|------|-------------|---------|
| Player Mobility | enum | Mobile/Immobilize/ImmobilizeForVehicle | Immobilize |
| Can Use Station From Station | bool | Station-to-station transfer | true |
| Animator Controller | AnimatorController | Sitting animation | null |
| Disable Station Exit | bool | Prevent exit | false |
| Seated | bool | Use seated animation | true |
| Station Enter Player Location | Transform | Entry position | null |
| Station Exit Player Location | Transform | Exit position | null |
| Controls Object | Transform | Vehicle control target | null |

### Player Mobility

```csharp
// Mobile: Free to move
//         Standing positions with animation, etc.

// Immobilize: Fully fixed
//             Chairs, benches, etc.

// ImmobilizeForVehicle: For vehicles
//                       Player view follows the Station
```

### Udon Control

```csharp
public class StationController : UdonSharpBehaviour
{
    // Seat the player
    public override void Interact()
    {
        Networking.LocalPlayer.UseAttachedStation();
    }

    // When seated
    public override void OnStationEntered(VRCPlayerApi player)
    {
        Debug.Log($"{player.displayName} sat down");
    }

    // When exited
    public override void OnStationExited(VRCPlayerApi player)
    {
        Debug.Log($"{player.displayName} stood up");
    }
}
```

### Avatar Station Rules

```
⚠️ Additional restrictions for Stations on avatars:
- Maximum 6 Stations
- Station Descriptor (red box) must be enabled at upload time
- Entry/Exit must be within 2m of the Station
- Enable/disable controlled via the FX layer
```

---

## VRC_ObjectSync

Automatically syncs Transform and Rigidbody over the network.

### All Properties

| Property | Type | Description | Default |
|----------|------|-------------|---------|
| Allow Collision Ownership Transfer | bool | Transfer ownership on collision | false |

### Udon Methods

```csharp
// Get VRC_ObjectSync
VRCObjectSync sync = (VRCObjectSync)GetComponent(typeof(VRCObjectSync));

// Reset to initial position
sync.Respawn();

// Gravity setting
sync.SetGravity(true);

// Kinematic setting
sync.SetKinematic(false);

// On teleport (skip interpolation)
sync.FlagDiscontinuity();

// Network statistics (for debugging)
float updateInterval = sync.UpdateInterval;
float receiveInterval = sync.ReceiveInterval;
```

### Ownership Management

```csharp
// Check ownership
bool isOwner = Networking.IsOwner(gameObject);

// Get owner
VRCPlayerApi owner = Networking.GetOwner(gameObject);

// Transfer ownership
Networking.SetOwner(Networking.LocalPlayer, gameObject);

// Event
public override void OnOwnershipTransferred(VRCPlayerApi player)
{
    Debug.Log($"New owner: {player.displayName}");
}
```

### VRC_ObjectSync vs UdonSynced

| Use Case | VRC_ObjectSync | UdonSynced |
|----------|----------------|------------|
| Transform sync | ✅ Automatic | ❌ Manual implementation |
| Rigidbody sync | ✅ Automatic | ❌ Manual implementation |
| State only | ❌ Unnecessary overhead | ✅ Optimal |
| Custom interpolation | ❌ Fixed | ✅ Flexible |
| Bandwidth control | ❌ Automatic | ✅ Fine-grained control |

---

## VRC_MirrorReflection

Creates a mirror.

### Performance Warning

```
⚠️ Significant performance impact:
- Renders the entire scene an additional time
- VR: Both eyes × 2 = 4x rendering
- Multiple mirrors: Increases exponentially
- Higher resolution = more overhead
```

### Best Practices

```csharp
// Recommended implementation:
// 1. Default OFF
// 2. Toggle button to enable
// 3. Auto-disable by distance
// 4. Set appropriate resolution

public class MirrorController : UdonSharpBehaviour
{
    [SerializeField] private GameObject mirrorObject;
    [SerializeField] private float autoDisableDistance = 10f;

    private VRCPlayerApi _localPlayer;
    private bool _initialized = false;

    void OnEnable() => Initialize();
    void Start() => Initialize();

    private void Initialize()
    {
        if (_initialized) return;
        _initialized = true;

        _localPlayer = Networking.LocalPlayer;
        mirrorObject.SetActive(false);
    }

    public override void Interact()
    {
        Initialize();
        mirrorObject.SetActive(!mirrorObject.activeSelf);
    }

    void Update()
    {
        if (!_initialized || !mirrorObject.activeSelf) return;

        float dist = Vector3.Distance(
            _localPlayer.GetPosition(),
            mirrorObject.transform.position
        );

        if (dist > autoDisableDistance)
        {
            mirrorObject.SetActive(false);
        }
    }
}
```

### Shader Global Variables

```csharp
// Mirror-related shader variables (read-only)
// _VRChatCameraMode:
//   0 = Normal rendering
//   1 = VR handheld camera
//   2 = Desktop handheld camera
//   3 = Screenshot

// _VRChatMirrorMode:
//   0 = Normal rendering
//   1 = VR mirror
//   2 = Desktop mirror

// _VRChatMirrorCameraPos:
//   Mirror camera world position
```

---

## VRC_PortalMarker

Creates a portal to another world.

### Setup

```
[Portal GameObject] ← Place at the root of the scene hierarchy
├── VRC_PortalMarker
│   ├── World ID: wrld_xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
│   └── Custom Portal Prefab (optional)
└── Visual (optional)
```

### Important Restrictions

```
⚠️ Portals must be placed at the root of the scene hierarchy
   Instance information from preceding players is synced to other players

⚠️ World ID is obtained from the VRChat website
   Example: wrld_4432ea9b-729c-46e3-8eaf-846aa0a37fdd
```

---

## VRC_SpatialAudioSource

Configures 3D spatial audio. Automatically added to AudioSource.

### All Properties

| Property | Type | Description | Default | Range |
|----------|------|-------------|---------|-------|
| Gain | float | Additional volume | 0 dB | 0-24 dB |
| Near | float | Attenuation start distance | 0 m | - |
| Far | float | Attenuation end distance | 40 m | - |
| Volumetric Radius | float | Source size | 0 m | < Far |
| Use AudioSource Volume Curve | bool | Use curve | false | - |
| Enable Spatialization | bool | 3D positioning | true | - |

### Settings by Use Case

```csharp
// BGM (2D):
// Enable Spatialization = false
// Near = 0, Far = 0

// Ambient sound (wide source):
// Near = 0, Far = 20-40
// Volumetric Radius = 5-10

// Sound effects (point source):
// Near = 0, Far = 10
// Volumetric Radius = 0

// Voice-like:
// Near = 0, Far = 25
// Gain = adjust appropriately
```

### Avatar Restrictions

```
⚠️ AudioSource on avatars:
- Gain limit: 10 dB
- Far limit: 40 m
- Always add VRC_SpatialAudioSource
  (If not added, SDK auto-generates one, causing unexpected behavior)
```

---

## VRC_UIShape

Enables VRChat interaction with Unity UI (Canvas).

### Setup

```
[Canvas GameObject]
├── Canvas (Render Mode: World Space)
├── VRC_UIShape
├── Graphic Raycaster (auto-added)
└── UI Elements (Button, Slider, etc.)
```

### Configuration Steps

```csharp
// Method 1 (recommended): Auto setup
// 1. Select UI > TextMeshPro (VRC)
// 2. Correct settings are applied automatically

// Method 2: Manual setup
// 1. Create a Canvas
// 2. Change Render Mode to "World Space"
// 3. Change Layer to "Default" (can't interact on UI layer)
// 4. Add VRC_UIShape component
// 5. Adjust scale (default 1 = 1 pixel per meter)
//    Recommended: 0.001 ~ 0.005

// Important:
// - Keep EventSystem in the scene (don't delete it)
// - Canvas Z-axis should face away from the player
// - Set Navigation to "None" on UI elements
```

### TextMeshPro Recommendation

```
✅ TextMeshPro:
- High-quality text rendering
- Better readability in VR
- Supersampling support

❌ Unity Text:
- Blurry in VR
- Performance degradation
- Lower quality
```

---

## VRC_AvatarPedestal

Displays avatars and allows switching.

### Setup

```
[Pedestal GameObject]
├── VRC_AvatarPedestal
│   └── Avatar ID: avtr_xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
└── Display Model (optional)
```

---

## VRC_CameraDolly

Moves the player's camera along a defined spline path (SDK 3.9+). Typically used for cinematic intros, tutorials, and guided tours.

### Setup

```
[Dolly Track Root]
├── VRC_CameraDolly
│   ├── Path (SplineContainer or CinemachinePath reference)
│   ├── Duration (float, seconds for a full traversal)
│   └── Loop (bool)
└── UdonController (UdonSharpBehaviour)
```

### VRC_CameraDolly Udon API

```csharp
VRCCameraDolly dolly = (VRCCameraDolly)GetComponent(typeof(VRCCameraDolly));

// Start playback from position 0
dolly.Play();

// Stop playback and release camera control
dolly.Stop();

// Pause at the current position
dolly.Pause();

// Resume from paused position
dolly.Resume();

// Jump to a normalized position along the path (0.0 = start, 1.0 = end)
dolly.SetPosition(float normalizedT);

// Get current normalized position
float t = dolly.GetPosition();

// Set playback speed multiplier (1.0 = normal, 2.0 = double speed, -1.0 = reverse)
dolly.SetSpeed(float speedMultiplier);

// Check if currently playing
bool isPlaying = dolly.IsPlaying;

// Check if looping is enabled
bool loops = dolly.Loop;
```

### Udon Control Example

```csharp
using UdonSharp;
using UnityEngine;
using VRC.SDKBase;

public class DollyController : UdonSharpBehaviour
{
    [SerializeField] private VRCCameraDolly dolly;

    // Call from UI button or trigger
    public override void Interact()
    {
        if (dolly.IsPlaying)
        {
            dolly.Stop();
        }
        else
        {
            dolly.SetPosition(0f);
            dolly.Play();
        }
    }

    // Jump to midpoint on demand
    public void JumpToMid()
    {
        dolly.SetPosition(0.5f);
    }
}
```

### Ownership and Network Notes

```
- VRC_CameraDolly only affects the local player's camera.
- Play/Stop calls are local — no network sync is built in.
- To sync a cinematic across all players, call Play() via
  SendCustomNetworkEvent(NetworkEventTarget.All, nameof(StartDolly)).
- Only one dolly can be active per player at a time.
  Calling Play() on a second dolly automatically stops the first.
```

---

## VRCCameraSettings API

Retrieves camera information (SDK 3.9+).

### Properties

```csharp
using VRC.SDK3.Rendering;

// Two camera instances
VRCCameraSettings screenCamera = VRCCameraSettings.ScreenCamera;
VRCCameraSettings photoCamera = VRCCameraSettings.PhotoCamera;

// Properties
int width = screenCamera.PixelWidth;
int height = screenCamera.PixelHeight;
float fov = screenCamera.FieldOfView;
bool isActive = photoCamera.Active;
```

### Events

```csharp
public class CameraMonitor : UdonSharpBehaviour
{
    [SerializeField] private TextMeshProUGUI infoText;

    void Start()
    {
        OnVRCCameraSettingsChanged(VRCCameraSettings.ScreenCamera);
    }

    public override void OnVRCCameraSettingsChanged(VRCCameraSettings camera)
    {
        // Ignore handheld camera
        if (camera != VRCCameraSettings.ScreenCamera) return;

        infoText.text = $"{camera.PixelWidth}x{camera.PixelHeight}\n" +
                        $"FOV: {camera.FieldOfView}°";
    }
}
```

---

## Allowed Unity Components

Unity standard components available in VRChat.

### Physics

- Rigidbody
- BoxCollider, SphereCollider, CapsuleCollider, MeshCollider
- CharacterJoint, ConfigurableJoint, FixedJoint, HingeJoint, SpringJoint
- ConstantForce
- WheelCollider

### Rendering

- MeshRenderer, SkinnedMeshRenderer
- MeshFilter
- Camera
- Light
- ReflectionProbe, LightProbeGroup, LightProbeProxyVolume
- LineRenderer, TrailRenderer
- ParticleSystem, ParticleSystemRenderer
- Projector
- Skybox
- LODGroup
- OcclusionArea, OcclusionPortal

### Audio

- AudioSource
- AudioReverbZone
- AudioChorusFilter, AudioDistortionFilter, AudioEchoFilter
- AudioHighPassFilter, AudioLowPassFilter, AudioReverbFilter

### UI

- Canvas, CanvasGroup, CanvasRenderer
- RectTransform

### Animation

- Animator
- PlayableDirector

### Navigation

- NavMeshAgent
- NavMeshObstacle
- OffMeshLink

### Other

- Transform
- VideoPlayer
- TextMesh (TextMeshPro recommended)
- Terrain, TerrainCollider
- Cloth
- WindZone
- Grid, GridLayout
- Tilemap, TilemapRenderer

### Disabled on Quest/Android

```
❌ Dynamic Bones
❌ Cloth (allowed in worlds, not on avatars)
❌ Physics on Avatar (Rigidbody, Collider, Joint)
❌ Cameras on Avatar
❌ Lights on Avatar
❌ Audio Sources on Avatar
❌ Unity Constraints (use VRC equivalents: VRCPositionConstraint, VRCRotationConstraint, VRCScaleConstraint, VRCParentConstraint, VRCAimConstraint, VRCLookAtConstraint)
```

## See Also

- [performance.md](performance.md) - Component-level performance budgets and Quest optimization checklist
- [audio-video.md](audio-video.md) - VRCUnityVideoPlayer, AVPro, and VRCSpatialAudioSource component details
