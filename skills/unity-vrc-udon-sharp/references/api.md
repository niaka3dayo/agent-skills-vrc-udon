# VRChat API Reference (UdonSharp)

Complete reference of VRChat-specific classes, methods, and types available in UdonSharp.

**Supported SDK Versions**: 3.7.1 - 3.10.2 (as of March 2026)

## VRCPlayerApi

Player information and actions. Obtained from `Networking.LocalPlayer` or event parameters.

### Properties

| Property | Type | Description |
|-----------|------|------|
| `displayName` | `string` | Player's display name |
| `playerId` | `int` | Unique player ID within this instance |
| `isLocal` | `bool` | True if this is the local player |
| `isMaster` | `bool` | True if this is the instance master |
| `isInstanceOwner` | `bool` | True if this is the instance owner |
| `isUserInVR` | `bool` | True if using VR |
| `isSuspended` | `bool` | True if suspended (tabbed out) |
| `isGrounded` | `bool` | True if grounded on the floor |

### Movement Methods

```csharp
// Teleport player
player.TeleportTo(Vector3 position, Quaternion rotation);
player.TeleportTo(Vector3 position, Quaternion rotation, VRC_SceneDescriptor.SpawnOrientation orientation);

// Get/Set velocity
Vector3 velocity = player.GetVelocity();
player.SetVelocity(Vector3 velocity);

// Movement settings
player.SetWalkSpeed(float speed);        // Default: 2.0
player.SetRunSpeed(float speed);         // Default: 4.0
player.SetStrafeSpeed(float speed);      // Default: 2.0
player.SetJumpImpulse(float impulse);    // Default: 3.0
player.SetGravityStrength(float strength); // Default: 1.0

// Immobilize player (prevent movement)
player.Immobilize(bool immobile);
```

### Position Methods

```csharp
// Get positions
Vector3 position = player.GetPosition();
Quaternion rotation = player.GetRotation();

// Get bone position (for avatar bones)
Vector3 bonePos = player.GetBonePosition(HumanBodyBones bone);
Quaternion boneRot = player.GetBoneRotation(HumanBodyBones bone);

// Tracking data (VR headset, controllers)
VRCPlayerApi.TrackingData trackingData = player.GetTrackingData(TrackingDataType type);
// trackingData.position, trackingData.rotation
```

### Voice and Audio

```csharp
// Voice settings (affects how others hear this player)
player.SetVoiceGain(float gain);              // 0-24 dB, default 15
player.SetVoiceDistanceNear(float distance);  // Default: 0
player.SetVoiceDistanceFar(float distance);   // Default: 25
player.SetVoiceVolumetricRadius(float radius); // Default: 0
player.SetVoiceLowpass(bool enabled);         // Default: true
```

### Avatar Methods

```csharp
// Avatar audio parameters
player.SetAvatarAudioGain(float gain);
player.SetAvatarAudioNearRadius(float radius);
player.SetAvatarAudioFarRadius(float radius);
player.SetAvatarAudioVolumetricRadius(float radius);
player.SetAvatarAudioForceSpatial(bool force);
```

### Avatar Scaling Methods

```csharp
// Get current avatar eye height
float eyeHeight = player.GetAvatarEyeHeightAsMeters();

// Set avatar eye height limits (local player only)
// Minimum: >= 0.2 meters, Maximum: <= 5.0 meters
player.SetAvatarEyeHeightMinimumByMeters(0.5f);
player.SetAvatarEyeHeightMaximumByMeters(3.0f);

// Get current limits
float minHeight = player.GetAvatarEyeHeightMinimumAsMeters();
float maxHeight = player.GetAvatarEyeHeightMaximumAsMeters();

// Set avatar eye height directly (within limits)
player.SetAvatarEyeHeightByMeters(1.6f);

// Set avatar eye height by multiplier (relative to avatar's default)
player.SetAvatarEyeHeightByMultiplier(1.5f); // 1.5x default height
```

### Pickup Methods

```csharp
// Get pickup in hand
VRC_Pickup pickup = player.GetPickupInHand(VRC_Pickup.PickupHand hand);

// Play haptic feedback
player.PlayHapticEventInHand(VRC_Pickup.PickupHand hand, float duration, float amplitude, float frequency);
```

### Player Tags

```csharp
// Tags (local only, not synced)
player.SetPlayerTag(string tagName, string tagValue);
string value = player.GetPlayerTag(string tagName);
player.ClearPlayerTags();
```

### Validity Check

```csharp
// Always check before using player reference
if (player != null && player.IsValid())
{
    // Safe to use player
}
```

## Networking Class

Static methods for network operations.

### Core Methods

```csharp
// Get local player
VRCPlayerApi localPlayer = Networking.LocalPlayer;

// Check instance master
bool isMaster = Networking.IsMaster;

// Get server time (synced across all players)
double serverTime = Networking.GetServerTimeInSeconds();

// Check network congestion
bool clogged = Networking.IsClogged;

// Simulate latency (for testing, editor only)
Networking.SimulateNetworkLatency(float latency);
```

### Ownership

```csharp
// Check ownership
bool isOwner = Networking.IsOwner(VRCPlayerApi player, GameObject obj);
bool isOwner = Networking.IsOwner(GameObject obj); // Checks local player

// Get owner
VRCPlayerApi owner = Networking.GetOwner(GameObject obj);

// Transfer ownership
Networking.SetOwner(VRCPlayerApi player, GameObject obj);
```

### Player Enumeration

```csharp
// Get player count
int count = VRCPlayerApi.GetPlayerCount();

// Get all players
VRCPlayerApi[] players = new VRCPlayerApi[VRCPlayerApi.GetPlayerCount()];
VRCPlayerApi.GetPlayers(players);

// Get player by ID
VRCPlayerApi player = VRCPlayerApi.GetPlayerById(int playerId);
```

## NetworkCalling Class (SDK 3.8.1+)

Monitoring and management of the network event queue.

```csharp
using VRC.SDK3.UdonNetworkCalling;

// Get queued events for a specific method on this behaviour
int queuedCount = NetworkCalling.GetQueuedEvents(
    (IUdonEventReceiver)this,
    nameof(MyNetworkMethod)
);

// Get total queued events across entire world
int totalQueued = NetworkCalling.GetAllQueuedEvents();

// Check if network is congested (also available via Networking.IsClogged)
bool isClogged = Networking.IsClogged;
```

### Usage Example: Rate Limit Monitoring

```csharp
using TMPro;
using UdonSharp;
using UnityEngine;
using VRC.SDK3.UdonNetworkCalling;
using VRC.SDKBase;
using VRC.Udon.Common.Interfaces;

public class NetworkMonitor : UdonSharpBehaviour
{
    [SerializeField] private TextMeshProUGUI statusText;

    void Update()
    {
        int myEventQueue = NetworkCalling.GetQueuedEvents(
            (IUdonEventReceiver)this,
            nameof(OnNetworkEvent)
        );
        int totalQueue = NetworkCalling.GetAllQueuedEvents();

        statusText.text = $"My Queue: {myEventQueue}\n" +
                          $"Total Queue: {totalQueue}\n" +
                          $"Clogged: {Networking.IsClogged}";
    }

    public void SendEvent()
    {
        // Check before sending to avoid queue buildup
        if (NetworkCalling.GetQueuedEvents((IUdonEventReceiver)this, nameof(OnNetworkEvent)) < 10)
        {
            SendCustomNetworkEvent(NetworkEventTarget.All, nameof(OnNetworkEvent));
        }
    }

    [NetworkCallable]
    public void OnNetworkEvent()
    {
        Debug.Log("Network event received!");
    }
}
```

## VRC_Pickup

Pickup component for holdable objects.

### Properties

| Property | Type | Description |
|-----------|------|------|
| `currentPlayer` | `VRCPlayerApi` | Player currently holding (null when not held) |
| `IsHeld` | `bool` | True if currently held |
| `currentHand` | `PickupHand` | Which hand is holding it |
| `pickupable` | `bool` | Whether it can be picked up |
| `DisallowTheft` | `bool` | Prevent theft by other players |

### Methods

```csharp
VRC_Pickup pickup = (VRC_Pickup)GetComponent(typeof(VRC_Pickup));

// Force drop
pickup.Drop();
pickup.Drop(VRCPlayerApi player); // Drop from specific player

// Generate haptic
pickup.GenerateHapticEvent(float duration, float amplitude, float frequency);
```

## VRCStation

Seat/station component.

### Properties

| Property | Type | Description |
|-----------|------|------|
| `seated` | `bool` | Whether someone is seated |
| `Occupant` | `VRCPlayerApi` | Current occupant (null when empty) |

### Methods

```csharp
VRCStation station = (VRCStation)GetComponent(typeof(VRCStation));

// Use station
station.UseStation(VRCPlayerApi player);
station.ExitStation(VRCPlayerApi player);
```

## VRCObjectPool

Object pooling for network-aware objects.

### Methods

```csharp
public VRCObjectPool pool;

// Spawn (owner only)
GameObject spawned = pool.TryToSpawn();

// Return to pool
pool.Return(GameObject obj);
```

## VRCObjectSync

Automatic position/rotation sync for physics objects.

### Methods

```csharp
VRCObjectSync sync = (VRCObjectSync)GetComponent(typeof(VRCObjectSync));

// Teleport (respects network sync)
sync.TeleportTo(Transform target);

// Respawn to original position
sync.Respawn();

// Enable/disable gravity and kinematic
sync.SetGravity(bool enabled);
sync.SetKinematic(bool enabled);

// Flag for update
sync.FlagDiscontinuity();
```

## VRCUrl / VRCStringDownloader / VRCImageDownloader

For details on the Web Loading API, see `references/web-loading.md`.

**Key Points:**
- `VRCStringDownloader.LoadUrl(url, (IUdonEventReceiver)this)` -- Text/JSON download
- `new VRCImageDownloader().DownloadImage(url, material, (IUdonEventReceiver)this, textureInfo)` -- Image download
- Rate limit: **Once every 5 seconds** (for String/Image each)
- Max image resolution: **2048 x 2048**
- Trusted URLs: Domain allowlist restrictions apply
- Memory management: Must release with `IVRCImageDownload.Dispose()`

```csharp
// String Loading (VRC.SDK3.StringLoading)
VRCStringDownloader.LoadUrl(dataUrl, (IUdonEventReceiver)this);
// -> OnStringLoadSuccess / OnStringLoadError

// Image Loading (VRC.SDK3.ImageLoading)
var downloader = new VRCImageDownloader();
downloader.DownloadImage(imageUrl, material, (IUdonEventReceiver)this);
// -> OnImageLoadSuccess / OnImageLoadError
```

## Enumerations

### NetworkEventTarget

```csharp
using VRC.Udon.Common.Interfaces;

NetworkEventTarget.All    // Send to all players including self
NetworkEventTarget.Owner  // Send to object owner only
```

### TrackingDataType

```csharp
VRCPlayerApi.TrackingDataType.Head
VRCPlayerApi.TrackingDataType.LeftHand
VRCPlayerApi.TrackingDataType.RightHand
VRCPlayerApi.TrackingDataType.Origin
```

### PickupHand

```csharp
VRC_Pickup.PickupHand.None
VRC_Pickup.PickupHand.Left
VRC_Pickup.PickupHand.Right
```

### SpawnOrientation

```csharp
VRC_SceneDescriptor.SpawnOrientation.Default
VRC_SceneDescriptor.SpawnOrientation.AlignPlayerWithSpawnPoint
VRC_SceneDescriptor.SpawnOrientation.AlignRoomWithSpawnPoint
```

## Synced Variable Types and Sizes

Know the sizes of synced types for bandwidth optimization:

| Type | Size (bytes) | Notes |
|------|--------------|-------|
| `bool` | 1 | |
| `byte`, `sbyte` | 1 | |
| `short`, `ushort` | 2 | |
| `int`, `uint` | 4 | |
| `long`, `ulong` | 8 | |
| `float` | 4 | |
| `double` | 8 | |
| `char` | 2 | UTF-16 |
| `string` | variable | ~2 bytes per char + overhead, max ~50 chars |
| `Vector2` | 8 | 2 floats |
| `Vector3` | 12 | 3 floats |
| `Vector4` | 16 | 4 floats |
| `Quaternion` | 16 | 4 floats |
| `Color` | 16 | 4 floats (RGBA) |
| `Color32` | 4 | 4 bytes (RGBA) |
| `VRCUrl` | variable | String-like |

### Bandwidth Limits

- **Continuous sync**: ~200 bytes per UdonBehaviour
- **Manual sync**: ~282KB per UdonBehaviour
- **Total transmission**: ~11 KB/sec

## SerializationResult

Returned from `OnPostSerialization` for debugging:

```csharp
public override void OnPostSerialization(SerializationResult result)
{
    Debug.Log($"Synced {result.byteCount} bytes, success: {result.success}");
}
```

| Property | Type | Description |
|-----------|------|------|
| `success` | `bool` | Whether serialization succeeded |
| `byteCount` | `int` | Number of bytes serialized |

## DataList and DataDictionary

Generic-like collections from `VRC.SDK3.Data`:

```csharp
using VRC.SDK3.Data;

// DataList (replaces List<T>)
DataList list = new DataList();
list.Add("item1");
list.Add(42);
list.Add(3.14f);

string str = list[0].String;
int num = list[1].Int;
float flt = list[2].Float;

int count = list.Count;
list.RemoveAt(0);
list.Clear();

// DataDictionary (replaces Dictionary<string, T>)
DataDictionary dict = new DataDictionary();
dict["key1"] = "value1";
dict["key2"] = 100;

string val = dict["key1"].String;
int num = dict["key2"].Int;

bool hasKey = dict.ContainsKey("key1");
dict.Remove("key1");
```

### DataToken

A type-safe container used by DataList/DataDictionary:

```csharp
DataToken token = new DataToken("hello");
DataToken token = new DataToken(42);
DataToken token = new DataToken(3.14f);

// Type checking
TokenType type = token.TokenType; // String, Int, Float, etc.

// Value extraction
string s = token.String;
int i = token.Int;
float f = token.Float;
bool b = token.Boolean;
```

## PlayerData API (SDK 3.7.4+)

Key-value storage for player data persisted across sessions.

### Static Methods

```csharp
using VRC.SDK3.Persistence;

// Check if key exists
bool exists = PlayerData.HasKey(player, "highScore");

// Get values (with TryGet pattern)
if (PlayerData.TryGetInt(player, "highScore", out int score))
{
    Debug.Log($"High score: {score}");
}

// Set values (only on local player's own data)
PlayerData.SetInt(Networking.LocalPlayer, "highScore", 1000);
PlayerData.SetString(Networking.LocalPlayer, "username", "Player1");
PlayerData.SetFloat(Networking.LocalPlayer, "volume", 0.8f);
PlayerData.SetBool(Networking.LocalPlayer, "tutorialComplete", true);

// Delete key
PlayerData.DeleteKey(Networking.LocalPlayer, "oldKey");
```

### Supported Types

| Method | Type | Size Limit |
|---------|------|-----------|
| `SetBool` / `TryGetBool` | `bool` | 1 byte |
| `SetInt` / `TryGetInt` | `int` | 4 bytes |
| `SetFloat` / `TryGetFloat` | `float` | 4 bytes |
| `SetDouble` / `TryGetDouble` | `double` | 8 bytes |
| `SetString` / `TryGetString` | `string` | ~50 chars |
| `SetBytes` / `TryGetBytes` | `byte[]` | ~100KB total |
| `SetVector3` / `TryGetVector3` | `Vector3` | 12 bytes |
| `SetQuaternion` / `TryGetQuaternion` | `Quaternion` | 16 bytes |
| `SetColor` / `TryGetColor` | `Color` | 16 bytes |

### Storage Limits

| Limit | Value |
|------|------|
| PlayerData per player per world | 100 KB |
| PlayerObject per player per world | 100 KB |
| Single UdonBehaviour with VRC Enable Persistence | 108 bytes per variable type |

### Usage Pattern

```csharp
public class PersistentScore : UdonSharpBehaviour
{
    private int highScore = 0;
    private bool dataLoaded = false;

    public override void OnPlayerRestored(VRCPlayerApi player)
    {
        if (!player.isLocal) return;

        // Wait for data to be loaded before accessing
        if (PlayerData.TryGetInt(player, "highScore", out int saved))
        {
            highScore = saved;
        }
        dataLoaded = true;
    }

    public void SaveScore(int score)
    {
        if (!dataLoaded) return; // Not loaded yet

        if (score > highScore)
        {
            highScore = score;
            PlayerData.SetInt(Networking.LocalPlayer, "highScore", score);
        }
    }
}
```

## VRCCameraSettings API (SDK 3.9.0+)

Control VRChat camera settings.

```csharp
// Get camera settings component
VRCCameraSettings cameraSettings = GetComponent<VRCCameraSettings>();

// Near/Far clip planes
cameraSettings.nearClipPlane = 0.01f;
cameraSettings.farClipPlane = 1000f;

// Field of view
cameraSettings.fieldOfView = 60f;

// Background color/skybox
cameraSettings.clearFlags = CameraClearFlags.Skybox;
cameraSettings.backgroundColor = Color.black;
```

## VRChat Dynamics API (SDK 3.10.0+)

PhysBones, Contacts, and VRC Constraints in worlds.

### VRCContactReceiver

Receives contact events from Contact Senders.

```csharp
// Get contact receiver component
VRCContactReceiver receiver = GetComponent<VRCContactReceiver>();

// Configure allowed content types
string[] allowedTypes = new string[] { "Hand", "Finger", "Custom" };
receiver.UpdateContentTypes(allowedTypes);

// Properties
bool allowSelf = receiver.allowSelf;     // Allow contacts from same avatar
bool allowOthers = receiver.allowOthers; // Allow contacts from other avatars
```

### VRCContactSender

Sends contact events to receivers.

```csharp
VRCContactSender sender = GetComponent<VRCContactSender>();

// Properties
float radius = sender.radius;
string contentType = sender.contentType;
```

### VRCPhysBone

Physics-based bone system in worlds.

```csharp
VRCPhysBone physBone = GetComponent<VRCPhysBone>();

// Properties (read-only in most cases)
bool isGrabbed = physBone.IsGrabbed();
VRCPlayerApi grabbingPlayer = physBone.GetGrabbingPlayer();

// Get affected transforms
Transform[] affectedBones = physBone.GetAffectedTransforms();
```

### Contact Event Info Structs

```csharp
// ContactEnterInfo
public struct ContactEnterInfo
{
    public string senderName;       // Contact sender name
    public bool isAvatar;           // True if from avatar
    public VRCPlayerApi player;     // Player if isAvatar is true
    public Vector3 position;        // Contact position
    public Vector3 normal;          // Contact normal
}

// ContactStayInfo
public struct ContactStayInfo
{
    public string senderName;
    public bool isAvatar;
    public VRCPlayerApi player;
    public Vector3 position;
    public Vector3 normal;
}

// ContactExitInfo
public struct ContactExitInfo
{
    public string senderName;
    public bool isAvatar;
    public VRCPlayerApi player;
}
```

### PhysBone Event Info Structs

```csharp
// PhysBoneGrabInfo
public struct PhysBoneGrabInfo
{
    public VRCPlayerApi player;     // Grabbing player
    public Transform bone;          // Grabbed bone
}

// PhysBoneReleaseInfo
public struct PhysBoneReleaseInfo
{
    public VRCPlayerApi player;
    public Transform bone;
}
```

### Usage Example: Interactive Button with Contacts

```csharp
public class ContactButton : UdonSharpBehaviour
{
    public AudioSource clickSound;
    public Animator buttonAnimator;

    private bool isPressed = false;

    public override void OnContactEnter(ContactEnterInfo info)
    {
        if (isPressed) return;

        isPressed = true;
        clickSound.Play();
        buttonAnimator.SetTrigger("Press");

        Debug.Log($"Button pressed by: {(info.isAvatar ? info.player?.displayName : "world object")}");
    }

    public override void OnContactExit(ContactExitInfo info)
    {
        isPressed = false;
        buttonAnimator.SetTrigger("Release");
    }
}
```
