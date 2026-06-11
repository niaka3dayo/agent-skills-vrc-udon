# VRChat API Reference (UdonSharp)

Complete reference of VRChat-specific classes, methods, and types available in UdonSharp.

**Supported SDK Versions**: 3.7.1 - 3.10.3

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
| `isVRCPlus` | `bool` | True if the player has an active VRC+ subscription (requires SDK 3.10.3+) |

#### `isVRCPlus` — Timing and Per-Client Evaluation (SDK 3.10.3+)

`isVRCPlus` is evaluated **per-client, on the local machine**. Each client reads its own value from VRChat account data — the value for a remote player is whatever that player's client has reported to the network.

Two properties of that model drive correct usage:

- **Timing**: Reading `isVRCPlus` inside `OnPlayerJoined` is not guaranteed to return an authoritative value. `OnPlayerJoined` fires during the network handshake before the player's profile and persistence data have settled; the subscription state may still be unset when the event fires. Gate reads behind `OnPlayerRestored` (or a local `_playerReady` flag set there) — `OnPlayerRestored` fires after persistence data has been loaded, which is the earliest point where account-tied properties are reliable.
- **Anti-sync**: Do **NOT** store `isVRCPlus` in an `[UdonSynced]` variable and broadcast it. Each client must read `player.isVRCPlus` on its own against the `VRCPlayerApi` it holds. Syncing a single master-evaluated value will misreport the state for every other player and is a correctness bug, not a bandwidth optimisation. (See NEVER #18 for the general form of this anti-pattern; `isVRCPlus` is a new axis — "per-client evaluation" rather than "component reference.")

For a worked example of reading the property and enabling a local `GameObject` based on it, see `patterns-core.md` (VRC+ Detection — Reading `isVRCPlus`).

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
// Voice settings — how the local (listening) player hears the target player
player.SetVoiceGain(float gain);              // 0-24 dB, default 15
player.SetVoiceDistanceNear(float distance);  // Default: 0
player.SetVoiceDistanceFar(float distance);   // Default: 25
player.SetVoiceVolumetricRadius(float radius); // Default: 0
player.SetVoiceLowpass(bool enabled);         // Default: true

// Getters for the same settings (release-noted in SDK 3.6.1; see Note)
float gain    = player.GetVoiceGain();
float near    = player.GetVoiceDistanceNear();
float far     = player.GetVoiceDistanceFar();
float radius  = player.GetVoiceVolumetricRadius();
bool  lowpass = player.GetVoiceLowpass();
```

> **Note**: The voice getters are named in the [SDK 3.6.1 release notes](https://creators.vrchat.com/releases/release-3-6-1/) — added to `VRCPlayerApi` and exposed to Udon — but do not appear on the current [Player Audio](https://creators.vrchat.com/worlds/udon/players/player-audio/), Players, or UdonSharp API reference pages. Each is parameterless and returns the value type of its matching setter (4 `float`, 1 `bool`). This entry records that they exist and their signatures; it does not specify runtime read semantics. What a getter returns before its setter has run, whether it reflects the last value set versus the live effective value, and whether local- and remote-player reads behave identically, are not verified here — confirm against your SDK/client before relying on a getter's return value (for example, before using one in place of your own tracked state). Re-check after the Voice Audio Rework (SDK 3.10.4) lands.

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

### Language Methods

```csharp
string language = VRCPlayerApi.GetCurrentLanguage(); // local user's selected language, RFC 5646: en, ja, zh-CN
string[] languages = VRCPlayerApi.GetAvailableLanguages(); // selectable languages
```

These are local-user getters, not per-remote-player reads.

### PlayerObject Methods

```csharp
// Find a component in the player's PlayerObject instance
// The reference parameter identifies which component type to find
Transform matched = (Transform)player.FindComponentInPlayerObjects(referenceTransform);

// Always validate before use
if (Utilities.IsValid(matched))
{
    Debug.Log($"Found transform: {matched.name}");
}
```

`FindComponentInPlayerObjects` searches the PlayerObject hierarchy belonging to `player` for a component that matches the type and identity of the reference. The return value must be cast to the target component type. Always check with `Utilities.IsValid()` before using the result, as the player's PlayerObject may not be loaded yet.

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

Object pooling for network-aware objects. The pool manages and synchronizes the active state of each held object across all players.

**Class**: `VRC.SDK3.Components.VRCObjectPool`

### Properties

| Property | Type | Description |
|----------|------|-------------|
| `Pool` | `GameObject[]` | The objects managed by this pool |

### Methods

| Method | Signature | Owner-only | Network-synchronized |
|---|---|---|---|
| `TryToSpawn()` | `GameObject TryToSpawn()` | Yes | Yes |
| `Return(obj)` | `void Return(GameObject obj)` | Yes | Yes |
| `Shuffle()` | `void Shuffle()` | Yes | Yes |

`TryToSpawn()` and `Return()` are publicly documented on creators.vrchat.com; `Shuffle()` is observed in the SDK 3.10.3 Udon wrapper symbols (`__Shuffle__SystemVoid` in `VRC.Udon.VRCWrapperModules.dll`) but absent from public API docs at the time of writing — its owner-only / synced behavior follows the same runtime contract as the other two methods. All three methods silently no-op when called by a non-owner at runtime; for patterns that require any client to trigger pool operations, see [Usage Pattern: Interact-Driven (User-Triggered)](#usage-pattern-interact-driven-user-triggered).

```csharp
public VRCObjectPool pool;

// Activate an unused object; returns null if all objects are in use.
GameObject spawned = pool.TryToSpawn();

// Return an object to the pool (deactivates it).
pool.Return(spawned);

// Shuffle the internal order of available objects.
pool.Shuffle();
```

### Ownership Behavior

The VRCObjectPool itself is a networked object; only its **owner** can call `TryToSpawn()`, `Return()`, or `Shuffle()`. Non-owner calls silently no-op at runtime (see Methods table above). To support callers from any client (e.g. `Interact()` handlers), see [Usage Pattern: Interact-Driven (User-Triggered)](#usage-pattern-interact-driven-user-triggered).

- **`TryToSpawn()`** activates an available pooled object and returns it. The ownership of the activated object is **not** automatically transferred to any specific player — call `Networking.SetOwner()` explicitly after spawning if you need the spawned object to be owned by a particular player.
- **`Return()`** deactivates the object and returns it to the pool. Only the pool owner can call this method.
- **`Shuffle()`** randomizes the internal order of available pooled objects, synchronized across all clients. Only the pool owner can call this method.

### Network Synchronization

The pool synchronizes the active/inactive state of every held object across all players. Late joiners automatically receive the correct active or inactive state for each pooled object.

### Pooled Object Contract

When writing an UdonSharp behaviour that is intended to run on pooled objects, it should follow this convention so the pool can set ownership correctly:

```csharp
using UdonSharp;
using VRC.SDKBase;

public class PooledObject : UdonSharpBehaviour
{
    // Set by the pool manager after TryToSpawn(); null when unassigned
    public VRCPlayerApi Owner;

    // Called on all clients when the object is assigned to a new owner
    public void OnOwnerSet()
    {
        // React to ownership assignment here
        if (Utilities.IsValid(Owner))
        {
            Debug.Log($"Object assigned to: {Owner.displayName}");
        }
    }

    void OnEnable()
    {
        // OnEnable fires before Start() when the pool activates this object.
        // Use this instead of the deprecated OnSpawn event.
    }

    void OnDisable()
    {
        // Fired when Return() deactivates this object.
        Owner = null;
    }
}
```

> **Note**: `OnSpawn` is **deprecated**. Use `OnEnable` to react to an object being activated by the pool.

### Usage Pattern: Master-Managed Pool

```csharp
using UdonSharp;
using UnityEngine;
using VRC.SDK3.Components;
using VRC.SDKBase;
using VRC.Udon.Common.Interfaces;

[UdonBehaviourSyncMode(BehaviourSyncMode.Manual)]
public class PoolManager : UdonSharpBehaviour
{
    public VRCObjectPool objectPool;

    public override void OnPlayerJoined(VRCPlayerApi player)
    {
        // Only the pool owner (e.g. master) calls TryToSpawn
        if (!Networking.IsOwner(objectPool.gameObject)) return;

        GameObject spawned = objectPool.TryToSpawn();
        if (spawned == null)
        {
            Debug.LogWarning("No objects available in pool");
            return;
        }

        // Transfer ownership of the spawned object to the joining player
        Networking.SetOwner(player, spawned);

        PooledObject pooledBehaviour = (PooledObject)spawned.GetComponent(typeof(PooledObject));
        if (Utilities.IsValid(pooledBehaviour))
        {
            pooledBehaviour.Owner = player;
            pooledBehaviour.SendCustomNetworkEvent(NetworkEventTarget.All, nameof(PooledObject.OnOwnerSet));
        }
    }

    public override void OnPlayerLeft(VRCPlayerApi player)
    {
        if (!Networking.IsOwner(objectPool.gameObject)) return;

        // Find and return the object assigned to the leaving player
        foreach (GameObject obj in objectPool.Pool)
        {
            if (!obj.activeInHierarchy) continue;

            PooledObject pooledBehaviour = (PooledObject)obj.GetComponent(typeof(PooledObject));
            if (Utilities.IsValid(pooledBehaviour) && pooledBehaviour.Owner == player)
            {
                objectPool.Return(obj);
                break;
            }
        }
    }
}
```

### Usage Pattern: Interact-Driven (User-Triggered)

The Master-Managed pattern above protects its pool calls with an `IsOwner` guard inside `OnPlayerJoined`. `OnPlayerJoined` runs on every client when a new player joins; the guard ensures only the pool owner's client actually executes `TryToSpawn()` / `Return()` — non-owner clients early-return safely without hitting a silent no-op at the pool method itself. When the trigger is `Interact()`, the handler body runs only on the interacting player's local client. Writing `pool.TryToSpawn()` directly there works only when the interacting player happens to own the pool — for everyone else the call reaches the pool method and silently no-ops with no exception. There are two correct resolutions, presented as a cost tier below.

| Tier | Approach | Cost | When |
|---|---|---|---|
| 1 | Forward to current pool owner via `SendCustomNetworkEvent(NetworkEventTarget.Owner, …)`; do spawn inside the owner-side handler | One network event, no ownership change | Default. Preserves whatever ownership scheme the pool already uses (master-managed, last-interactor, etc.). |
| 2 | Take ownership locally with `Networking.SetOwner(LocalPlayer, pool.gameObject)`, then call `TryToSpawn()` / `Shuffle()` directly | One ownership transfer per Interact, no separate event | When the interaction semantically implies "this player now owns the next spawn" (e.g. each player owns their own ammo pool). |

#### Tier 1 — Forward to owner (recommended)

> **Setup precondition**: Attach `PoolInteractForwarded` to the **same GameObject as the `VRCObjectPool`** it references. `NetworkEventTarget.Owner` resolves to the owner of the *sending UdonBehaviour's* GameObject (per [creators.vrchat.com networking events](https://creators.vrchat.com/worlds/udon/networking/events/)), not to `objectPool.gameObject`. Co-location ensures the event is delivered to the pool owner. If you need the interactor and the pool on separate GameObjects, see Tier 2 instead.

```csharp
using UdonSharp;
using UnityEngine;
using VRC.SDK3.Components;
using VRC.SDKBase;
using VRC.Udon.Common.Interfaces;

// Attach this script to the SAME GameObject as the VRCObjectPool it references.
public class PoolInteractForwarded : UdonSharpBehaviour
{
    public VRCObjectPool objectPool;

    public override void Interact()
    {
        // NetworkEventTarget.Owner targets the owner of THIS UdonBehaviour's
        // GameObject. Since this script is co-located with objectPool, the
        // event is delivered to the pool owner — no ownership change needed.
        SendCustomNetworkEvent(NetworkEventTarget.Owner, nameof(OwnerSpawn));
    }

    public void OwnerSpawn()
    {
        // Defensive: if ownership transferred between the event send and arrival,
        // the new owner will still see this fire on the old owner's client; the
        // guard makes the call a safe no-op rather than silently spawning on
        // a stale owner.
        if (!Networking.IsOwner(objectPool.gameObject)) return;
        objectPool.Shuffle();
        GameObject spawned = objectPool.TryToSpawn();
        // ... assign ownership of `spawned` if needed
    }
}
```

`OwnerSpawn` runs on the client that owns this script's GameObject (which, per the co-location precondition above, is the pool owner). The `IsOwner` guard is defensive against a race where ownership transfers between the `SendCustomNetworkEvent` call and the handler arriving on the previous owner's client.

#### Tier 2 — Take ownership first (acceptable)

```csharp
using UdonSharp;
using UnityEngine;
using VRC.SDK3.Components;
using VRC.SDKBase;

public class PoolInteractTakeOwnership : UdonSharpBehaviour
{
    public VRCObjectPool objectPool;

    public override void Interact()
    {
        Networking.SetOwner(Networking.LocalPlayer, objectPool.gameObject);
        objectPool.Shuffle();
        GameObject spawned = objectPool.TryToSpawn();
        // ... assign ownership of `spawned` if needed
    }
}
```

`Networking.SetOwner` is locally immediate post-SDK 2021.2.2, so it is safe to call pool methods on the next line under an `IsOwner` invariant. See [networking.md](networking.md) for the full ownership model.

#### Choosing between Tier 1 and Tier 2

Use Tier 1 by default. Use Tier 2 when the interaction conceptually transfers ownership of the pool to the interacting player — for example, per-player ammo pools or individual draw-card decks. Mixing both patterns in one world is fine when each pool's role is different; Tier framing applies per-pool, not globally.

### VRCObjectPool vs VRCInstantiate

| | VRCObjectPool | VRCInstantiate |
|---|---|---|
| **Sync** | Network-synchronized across all players | Local only — not synced |
| **Ownership** | Managed by pool owner; spawned object ownership must be set manually | No ownership concept |
| **Late joiners** | Receive correct state automatically | Miss any previously instantiated objects |
| **Object reuse** | Pre-allocated pool; `Return()` makes objects available again | Objects persist until destroyed |
| **Use when** | Spawning networked bullets, per-player data containers, shared world objects | Local particle effects, client-side previews, non-networked decorations |

#### Decision Flow

```text
Does every player need to see the spawned object?
├── No  --> VRCInstantiate (local, no sync overhead)
└── Yes --> VRCObjectPool (synchronized, ownership-aware)
         Does the object need to be reused frequently?
         ├── Yes --> VRCObjectPool (pooling avoids repeated allocation)
         └── No  --> VRCObjectPool still preferred over VRCInstantiate for synced objects
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
- Memory management: `IVRCImageDownload.Dispose()` releases the download wrapper, not the GPU texture — destroy the assigned `Texture2D` (see `image-loading-vram.md`)

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
NetworkEventTarget.Others // Send to all players except self (SDK 3.8.1+)
NetworkEventTarget.Self   // Send to local player only (SDK 3.8.1+)
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
| `string` | variable | 2 bytes per char; no separate per-string limit — bounded by sync mode budget |
| `Vector2` | 8 | 2 floats |
| `Vector3` | 12 | 3 floats |
| `Vector4` | 16 | 4 floats |
| `Quaternion` | 16 | 4 floats |
| `Color` | 16 | 4 floats (RGBA) |
| `Color32` | 4 | 4 bytes (RGBA) |
| `VRCUrl` | variable | String-like |

### Bandwidth Limits

- **Continuous sync**: ~200 bytes per UdonBehaviour
- **Manual sync**: ~280KB (280,496 bytes) per UdonBehaviour
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

## VRCCameraSettings API (SDK 3.8.1+; CullingMask and GetCurrentCamera added in 3.9.0)

Read-only access to VRChat's built-in camera parameters. Provides two static instances and an event callback when settings change.

Namespace: `VRC.SDK3.Rendering`

### Static Camera Instances

| Instance | Description |
|----------|-------------|
| `VRCCameraSettings.ScreenCamera` | The player's main view (desktop window or VR headset) |
| `VRCCameraSettings.PhotoCamera` | The handheld in-game photo camera |

### Properties

| Property | Type | Description |
|----------|------|-------------|
| `PixelWidth` | `int` | Render target width in pixels |
| `PixelHeight` | `int` | Render target height in pixels |
| `FieldOfView` | `float` | Horizontal field of view in degrees |
| `Active` | `bool` | True if this camera is currently active |

```csharp
using VRC.SDK3.Rendering;

// Read main screen camera properties
VRCCameraSettings screen = VRCCameraSettings.ScreenCamera;
int w = screen.PixelWidth;
int h = screen.PixelHeight;
float fov = screen.FieldOfView;
bool active = screen.Active;

// Read photo camera properties
VRCCameraSettings photo = VRCCameraSettings.PhotoCamera;
bool photoOpen = photo.Active;
```

### Event Callback

`OnVRCCameraSettingsChanged` fires whenever any camera property changes (resolution, FOV, active state). Override it on any `UdonSharpBehaviour`.

```csharp
// Signature
public override void OnVRCCameraSettingsChanged(VRCCameraSettings camera) { }
```

### Usage Example

```csharp
using TMPro;
using UdonSharp;
using UnityEngine;
using VRC.SDK3.Rendering;
using VRC.SDKBase;

public class CameraMonitor : UdonSharpBehaviour
{
    [SerializeField] private TextMeshProUGUI infoText;

    void Start()
    {
        // Initialize display with current values
        UpdateDisplay(VRCCameraSettings.ScreenCamera);
    }

    public override void OnVRCCameraSettingsChanged(VRCCameraSettings camera)
    {
        // Skip changes from the photo camera
        if (camera != VRCCameraSettings.ScreenCamera) return;

        UpdateDisplay(camera);
    }

    private void UpdateDisplay(VRCCameraSettings camera)
    {
        infoText.text = $"Resolution: {camera.PixelWidth}x{camera.PixelHeight}\n" +
                        $"FOV: {camera.FieldOfView:F1} deg\n" +
                        $"Photo cam: {VRCCameraSettings.PhotoCamera.Active}";
    }
}
```

### Notes

```text
- All properties are read-only from Udon. Camera settings cannot be set via this API.
- OnVRCCameraSettingsChanged fires for both ScreenCamera and PhotoCamera changes;
  filter by comparing the parameter with VRCCameraSettings.ScreenCamera.
- PixelWidth / PixelHeight reflect the actual render resolution, which changes when
  the player resizes the window or toggles the photo camera.
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
float radius = receiver.radius;          // Collision radius (both shapes; max 3 m)
float height = receiver.height;          // Capsule height along Y, half-spheres included (max 6 m)
ContactBase.ShapeType shapeType = receiver.shapeType; // Sphere or Capsule
```

Shape and dimension properties are read/write from Udon. `height` is only meaningful when `shapeType` is `ContactBase.ShapeType.Capsule`.

### VRCContactSender

Sends contact events to receivers.

```csharp
VRCContactSender sender = GetComponent<VRCContactSender>();

// Properties
float radius = sender.radius;             // Collision radius (both shapes; max 3 m)
float height = sender.height;             // Capsule height along Y, half-spheres included (max 6 m)
ContactBase.ShapeType shapeType = sender.shapeType; // Sphere or Capsule
string contentType = sender.contentType;  // Contact tag string (e.g. "Finger", "Hand", or custom)
```

Shape and dimension properties are read/write from Udon. `height` is only meaningful when `shapeType` is `ContactBase.ShapeType.Capsule`.

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

## VRCDroneApi

The drone that a player controls when in drone mode. Obtain the local player's drone via `Networking.LocalPlayer.GetDrone()`.

### Getting the Drone

```csharp
// Get the drone associated with the local player
VRCDroneApi drone = Networking.LocalPlayer.GetDrone();

// Always validate before use — returns null when the player is not in drone mode
if (Utilities.IsValid(drone))
{
    // Safe to use drone
}
```

### Methods

```csharp
// Teleport the drone to a world-space position and rotation
drone.TeleportTo(Vector3 position, Quaternion rotation);

// Set the drone's current velocity (world space, meters per second)
drone.SetVelocity(Vector3 velocity);

// Get the VRCPlayerApi of the player piloting this drone
VRCPlayerApi pilot = drone.GetPlayer();
```

### Usage Example

```csharp
using UdonSharp;
using UnityEngine;
using VRC.SDKBase;
using VRC.Udon.Common.Interfaces;

public class DroneCheckpoint : UdonSharpBehaviour
{
    [SerializeField] private Transform respawnPoint;

    public override void OnDroneTriggerEnter(Collider other)
    {
        VRCDroneApi drone = Networking.LocalPlayer.GetDrone();
        if (!Utilities.IsValid(drone)) return;

        // Teleport the drone back to the respawn point
        drone.TeleportTo(respawnPoint.position, respawnPoint.rotation);
        drone.SetVelocity(Vector3.zero);

        VRCPlayerApi pilot = drone.GetPlayer();
        if (Utilities.IsValid(pilot))
        {
            Debug.Log($"{pilot.displayName}'s drone hit a checkpoint");
        }
    }
}
```

## VRC Camera Dolly API (SDK 3.9.0+)

Defines camera dolly animations applied to the local player's VRChat user camera.
Three components work together in a fixed parent-child hierarchy.

**Available since**: SDK 3.9.0

> **No ClientSim preview**: Camera dolly animations do not render in ClientSim.
> Use **Build and Test** to preview animations at runtime.

### Component Hierarchy

```text
GameObject (VRC Camera Dolly Animation)
├── GameObject (VRC Camera Dolly Path)
│   ├── GameObject (VRC Camera Dolly Point)
│   └── GameObject (VRC Camera Dolly Point)
└── GameObject (VRC Camera Dolly Path)
    ├── GameObject (VRC Camera Dolly Point)
    ├── GameObject (VRC Camera Dolly Point)
    └── GameObject (VRC Camera Dolly Point)
```

### VRC Camera Dolly Animation — Inspector Parameters

Configure these in the Unity Inspector on the top-level `VRC Camera Dolly Animation` component:

| Parameter | Description |
|-----------|-------------|
| `Is Relative To Player` | Anchor animation to the local player's position instead of world origin |
| `Is Speed Based` | Use speed values per point rather than fixed durations |
| `Is Using Look At Me` | Enable Look-At-Me horizontal/vertical offsets on points |
| `Is Using Greenscreen` | Enable Green Screen HSL controls on points |
| `Is Using Multi Stream` | Enable multi-stream animation mode |
| `Path Type` | Interpolation method for the path (linear, smooth, etc.) |
| `Loop Type` | How the animation loops (none, loop, ping-pong) |
| `Capture Type` | Capture methodology for the animation |
| `Focus Mode` | Camera focus mode for this animation |
| `Anchor Mode` | Camera anchor mode for this animation |
| `Paths` | List of `VRC Camera Dolly Path` children; populate via **Collect Paths & Points** |

### VRC Camera Dolly Path — Inspector Parameters

| Parameter | Description |
|-----------|-------------|
| `Points` | List of `VRC Camera Dolly Point` children; populated via **Collect Paths & Points** |

### VRC Camera Dolly Point — Inspector Parameters (Keyframe)

| Parameter | Description |
|-----------|-------------|
| `Zoom` | Keyframe zoom value |
| `Duration` | Duration for this keyframe (time-based mode only) |
| `Speed` | Speed for this keyframe (speed-based mode only) |
| `Focal Distance` | Focal distance (manual focus mode) |
| `Aperture` | Aperture value (manual or semi-auto focus mode) |
| `Hue` | Greenscreen hue (greenscreen mode) |
| `Saturation` | Greenscreen saturation (greenscreen mode) |
| `Lightness` | Greenscreen lightness (greenscreen mode) |
| `Look At Me X Offset` | Horizontal Look-At-Me offset (Look-At-Me mode) |
| `Look At Me Y Offset` | Vertical Look-At-Me offset (Look-At-Me mode) |

### UdonSharp API

The scripting surface for Camera Dolly is intentionally minimal. The primary method is:

```csharp
// Apply the animation to the local player's VRChat user camera
dollyAnimation.Import();
```

`Import()` reads all paths and points collected on the `VRC Camera Dolly Animation` component and applies the resulting animation to the camera of the **local client** only. It has no return value.

### Setup and Usage

```csharp
using UdonSharp;
using UnityEngine;
using VRC.SDKBase;
using VRC.SDK3.Components;

public class DollyController : UdonSharpBehaviour
{
    // Drag the GameObject that holds VRC Camera Dolly Animation into this field
    [SerializeField] private VRCCameraDollyAnimation dollyAnimation;

    // Call this to start the camera dolly animation for the local player
    public void PlayDolly()
    {
        if (!Utilities.IsValid(dollyAnimation)) return;
        dollyAnimation.Import();
    }
}
```

> **Important**: Before entering Play mode or building, select the top-level `VRC Camera Dolly Animation` object and click **Collect Paths & Points** to register all child paths and points. Any time you add, remove, or re-order children, repeat this step.

### Limitations

- The API applies the animation to the **local player only**. To trigger it for all players, use `SendCustomNetworkEvent(NetworkEventTarget.All, nameof(PlayDolly))`.
- No properties of the animation, paths, or points are readable or writable from UdonSharp at runtime.
- There is no event callback when the animation completes.
- No ClientSim preview; Build and Test is required to see the animation.

## See Also

- [constraints.md](constraints.md) - C# feature availability in UdonSharp that affects which APIs can be used
- [events.md](events.md) - Complete event list and execution-order diagrams
- [networking.md](networking.md) - `Networking` class, ownership, and `RequestSerialization` patterns
