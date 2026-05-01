# UdonSharp Event Reference

Complete reference of all events available in UdonSharp. Override these methods to respond to events.

**Supported SDK Versions**: 3.7.1 - 3.10.3

## Important: override vs Non-override

UdonSharp events include those that **require override** and those that **do not**. Using the wrong one causes a compile error (CS0115).

### override Required (VRChat/Udon-Specific Events)

`OnPlayerJoined`, `OnPlayerLeft`, `OnPlayerRespawn`, `OnDeserialization`, `OnPreSerialization`, `OnPostSerialization`, `OnOwnershipTransferred`, `OnOwnershipRequest`, `Interact`, `OnPickup`, `OnDrop`, `OnPickupUseDown`, `OnPickupUseUp`, `OnPlayerTriggerEnter/Stay/Exit`, `OnPlayerCollisionEnter/Stay/Exit`, `OnPlayerParticleCollision`, `OnStationEntered/Exited`, `OnPlayerRestored`, `OnContactEnter/Stay/Exit`, `OnPhysBoneGrab/Release`, `OnPhysBoneColliderEnter/Stay/Exit`, `OnDroneTriggerEnter`, `OnDroneTriggerExit`, `InputJump`, `InputUse`, `InputGrab`, `InputDrop`, `InputMoveHorizontal/Vertical`, `InputLookHorizontal/Vertical`, `MidiNoteOn/Off`, `MidiControlChange`, `OnVideo*`, `OnStringLoad*`, `OnImageLoad*`

### override Not Required (Standard Unity Callbacks)

`Start`, `Update`, `LateUpdate`, `FixedUpdate`, `OnEnable`, `OnDisable`, `OnDestroy`, `OnTriggerEnter/Stay/Exit`, `OnCollisionEnter/Stay/Exit`, `OnAnimatorMove`, `OnAnimatorIK`, `OnWillRenderObject`, `OnBecameVisible/Invisible`

```csharp
// WRONG: CS0115 error
public override void OnTriggerEnter(Collider other) { }
// CORRECT
public void OnTriggerEnter(Collider other) { }

// CORRECT: VRChat events require override
public override void OnPlayerJoined(VRCPlayerApi player) { }
```

---

## Update Events

Called every frame or physics tick.

| Event | When Called |
|-------|-------------|
| `void Update()` | Every frame |
| `void LateUpdate()` | After all Update calls |
| `void FixedUpdate()` | Every physics tick (~50Hz) |
| `void PostLateUpdate()` | After LateUpdate (VRChat-specific) |

```csharp
void Update()
{
    // Called every frame
    transform.Rotate(Vector3.up, rotationSpeed * Time.deltaTime);
}

void FixedUpdate()
{
    // Called at fixed intervals for physics
    rb.AddForce(Vector3.up * force);
}
```

### SendCustomEventDelayed and EventTiming (SDK 3.10.2+)

The third argument of `SendCustomEventDelayedSeconds` / `SendCustomEventDelayedFrames` specifies the execution timing.

| EventTiming | Description | Added In |
|-------------|------|--------------|
| `EventTiming.Update` | Within the Update loop (default) | 3.7.1+ |
| `EventTiming.LateUpdate` | Within LateUpdate | 3.7.1+ |
| `EventTiming.FixedUpdate` | Within physics tick | **3.10.2** |
| `EventTiming.PostLateUpdate` | After LateUpdate | **3.10.2** |

```csharp
// Default (Update timing)
SendCustomEventDelayedSeconds(nameof(MyMethod), 2.0f);

// Execute at FixedUpdate timing (SDK 3.10.2+)
SendCustomEventDelayedSeconds(nameof(PhysicsAction), 1.0f, EventTiming.FixedUpdate);

// Frame delay + PostLateUpdate timing (SDK 3.10.2+)
SendCustomEventDelayedFrames(nameof(CameraFollow), 1, EventTiming.PostLateUpdate);
```

> **Note**: `EventTiming.FixedUpdate` is suitable for processing that needs to sync with physics calculations, and `EventTiming.PostLateUpdate` is suitable for camera following and post-IK corrections.

---

## Input Events

VRChat-specific input events. Called when the player presses/releases buttons.

### Action Events

| Event | When Called |
|-------|-------------|
| `InputJump(bool value, UdonInputEventArgs args)` | Jump button |
| `InputUse(bool value, UdonInputEventArgs args)` | Use/Interact button |
| `InputGrab(bool value, UdonInputEventArgs args)` | Grab button |
| `InputDrop(bool value, UdonInputEventArgs args)` | Drop button |

### Movement Events

| Event | When Called |
|-------|-------------|
| `InputMoveHorizontal(float value, UdonInputEventArgs args)` | Left/right movement |
| `InputMoveVertical(float value, UdonInputEventArgs args)` | Forward/back movement |
| `InputLookHorizontal(float value, UdonInputEventArgs args)` | Look left/right |
| `InputLookVertical(float value, UdonInputEventArgs args)` | Look up/down |

```csharp
public override void InputJump(bool value, VRC.Udon.Common.UdonInputEventArgs args)
{
    if (value) // Button pressed (not released)
    {
        Debug.Log("Jump pressed!");
    }
}

public override void InputMoveHorizontal(float value, VRC.Udon.Common.UdonInputEventArgs args)
{
    // value is -1 to 1
    Debug.Log($"Horizontal input: {value}");
}
```

## Interact Event

Called when a player interacts with the object (requires a Collider).

```csharp
public override void Interact()
{
    Debug.Log($"{Networking.LocalPlayer.displayName} interacted with this!");
}
```

**Requirements:**
- GameObject must have a Collider
- Collider must NOT be set to "Is Trigger" (for default interact)
- Set "Interact Text" in UdonBehaviour component to customize prompt

## Pickup Events

Called on objects with a VRC_Pickup component.

| Event | When Called |
|-------|-------------|
| `void OnPickup()` | When picked up |
| `void OnDrop()` | When dropped |
| `void OnPickupUseDown()` | When use button pressed while holding |
| `void OnPickupUseUp()` | When use button released while holding |

```csharp
public override void OnPickup()
{
    Debug.Log("Picked up!");
}

public override void OnDrop()
{
    Debug.Log("Dropped!");
}

public override void OnPickupUseDown()
{
    // Fire weapon, activate tool, etc.
    DoAction();
}

public override void OnPickupUseUp()
{
    // Release trigger, stop action
    StopAction();
}
```

## Player Events

Called when players join, leave, or change state.

| Event | When Called |
|-------|-------------|
| `void OnPlayerJoined(VRCPlayerApi player)` | Player joins instance |
| `void OnPlayerLeft(VRCPlayerApi player)` | Player leaves instance |
| `void OnPlayerRespawn(VRCPlayerApi player)` | Player respawns |

```csharp
public override void OnPlayerJoined(VRCPlayerApi player)
{
    Debug.Log($"{player.displayName} joined!");

    // Sync state for new player if we own the object
    if (Networking.IsOwner(gameObject))
    {
        RequestSerialization();
    }
}

public override void OnPlayerLeft(VRCPlayerApi player)
{
    Debug.Log($"{player.displayName} left!");
    // Clean up player-specific data
}
```

## Persistence Events (SDK 3.7.4+)

Called during PlayerData persistence operations.

| Event | When Called |
|-------|-------------|
| `void OnPlayerRestored(VRCPlayerApi player)` | Player's saved data has been loaded |
| `void OnPlayerDataUpdated(VRCPlayerApi player, PlayerData.Info[] infos)` | PlayerData was updated |

```csharp
public override void OnPlayerRestored(VRCPlayerApi player)
{
    if (!player.isLocal) return;

    Debug.Log($"{player.displayName}'s data restored!");

    // Access PlayerData to load saved data
    if (PlayerData.TryGetInt(player, "highScore", out int score))
    {
        highScoreDisplay.text = $"High Score: {score}";
    }
}
```

**Important:** Do not access PlayerData until `OnPlayerRestored` has been called.

## VRChat Dynamics Events (SDK 3.10.0+)

Called for PhysBones and Contacts in worlds.

### Contact Events

| Event | When Called |
|-------|-------------|
| `void OnContactEnter(ContactEnterInfo info)` | Contact sender starts contacting receiver |
| `void OnContactStay(ContactStayInfo info)` | Contact ongoing |
| `void OnContactExit(ContactExitInfo info)` | Contact ends |

```csharp
public override void OnContactEnter(ContactEnterInfo info)
{
    Debug.Log($"Contact from: {info.senderName}");

    // Determine if contact is from avatar or world object
    if (info.isAvatar)
    {
        // Contact from avatar
        VRCPlayerApi player = info.player;
        if (player != null && player.IsValid())
        {
            Debug.Log($"Touched by: {player.displayName}");
        }
    }
    else
    {
        // Contact from world object
        Debug.Log("Touched by world object");
    }
}

public override void OnContactExit(ContactExitInfo info)
{
    Debug.Log($"Contact ended: {info.senderName}");
}
```

### PhysBones Events

| Event | When Called |
|-------|-------------|
| `void OnPhysBoneGrab(PhysBoneGrabInfo info)` | PhysBone grabbed |
| `void OnPhysBoneRelease(PhysBoneReleaseInfo info)` | PhysBone released |
| `void OnPhysBoneColliderEnter(PhysBoneColliderInfo info)` | A PhysBone collider starts intersecting the bone chain |
| `void OnPhysBoneColliderStay(PhysBoneColliderInfo info)` | A PhysBone collider continues to intersect the bone chain |
| `void OnPhysBoneColliderExit(PhysBoneColliderInfo info)` | A PhysBone collider stops intersecting the bone chain |

```csharp
public override void OnPhysBoneGrab(PhysBoneGrabInfo info)
{
    Debug.Log($"PhysBone grabbed by {info.player?.displayName}");
}

public override void OnPhysBoneRelease(PhysBoneReleaseInfo info)
{
    Debug.Log($"PhysBone released");
}

public override void OnPhysBoneColliderEnter(PhysBoneColliderInfo info)
{
    // info.isAvatar — true if the collider belongs to an avatar
    // info.player   — player reference (valid when isAvatar is true)
    // info.bone     — the specific bone transform that was hit
    Debug.Log($"PhysBone collider entered — bone: {info.bone?.name}, " +
              $"avatar: {info.isAvatar}, player: {info.player?.displayName}");
}

public override void OnPhysBoneColliderStay(PhysBoneColliderInfo info)
{
    // Called every frame while the collider intersects. Keep this lightweight.
}

public override void OnPhysBoneColliderExit(PhysBoneColliderInfo info)
{
    Debug.Log($"PhysBone collider exited — bone: {info.bone?.name}");
}
```

**Note:** Contact/PhysBone events are triggered on all UdonBehaviours attached to the same GameObject as the receiver.

## Player Trigger/Collision Events

Called when players enter/exit triggers or collide.

### Trigger Events

| Event | When Called |
|-------|-------------|
| `void OnPlayerTriggerEnter(VRCPlayerApi player)` | Player enters trigger |
| `void OnPlayerTriggerStay(VRCPlayerApi player)` | Player stays in trigger |
| `void OnPlayerTriggerExit(VRCPlayerApi player)` | Player exits trigger |

### Collision Events

| Event | When Called |
|-------|-------------|
| `void OnPlayerCollisionEnter(VRCPlayerApi player)` | Player collision starts |
| `void OnPlayerCollisionStay(VRCPlayerApi player)` | Player collision ongoing |
| `void OnPlayerCollisionExit(VRCPlayerApi player)` | Player collision ends |

### Particle Collision Event

| Event | When Called |
|-------|-------------|
| `void OnPlayerParticleCollision(VRCPlayerApi player)` | Particle hits player |

```csharp
public override void OnPlayerTriggerEnter(VRCPlayerApi player)
{
    if (player.isLocal)
    {
        // Only affect local player
        ShowWelcomeMessage();
    }
}
```

**Requirements:**
- GameObject must have Collider with "Is Trigger" checked
- For collision events, Collider must NOT be trigger

## Drone Events

Called when a player's drone enters or exits a trigger collider attached to the same GameObject as this behaviour.

| Event | When Called |
|-------|-------------|
| `void OnDroneTriggerEnter(Collider other)` | Drone enters the trigger |
| `void OnDroneTriggerExit(Collider other)` | Drone exits the trigger |

```csharp
public override void OnDroneTriggerEnter(Collider other)
{
    VRCDroneApi drone = Networking.LocalPlayer.GetDrone();
    if (!Utilities.IsValid(drone)) return;

    VRCPlayerApi pilot = drone.GetPlayer();
    if (Utilities.IsValid(pilot))
    {
        Debug.Log($"{pilot.displayName}'s drone entered the zone");
    }
}

public override void OnDroneTriggerExit(Collider other)
{
    Debug.Log("Drone exited the trigger zone");
}
```

**Requirements:**
- GameObject must have a Collider with "Is Trigger" checked
- Events fire only on the local client

## Networking Events

Called during sync and ownership changes.

| Event | When Called |
|-------|-------------|
| `void OnPreSerialization()` | Before data is serialized (owner only) |
| `void OnDeserialization()` | After receiving synced data |
| `void OnDeserialization(DeserializationResult result)` | With result info |
| `void OnPostSerialization(SerializationResult result)` | After serialization complete |
| `void OnOwnershipTransferred(VRCPlayerApi player)` | Ownership changed |
| `bool OnOwnershipRequest(VRCPlayerApi requestingPlayer, VRCPlayerApi requestedOwner)` | Ownership requested (return `true` to accept, `false` to reject) |

```csharp
public override void OnPreSerialization()
{
    // Prepare data before sending (owner only)
    // Good place to pack data or update timestamps
}

public override void OnDeserialization()
{
    // Data received from owner
    UpdateDisplay();
}

public override void OnPostSerialization(SerializationResult result)
{
    if (!result.success)
    {
        Debug.LogError($"Serialization failed!");
    }
    Debug.Log($"Sent {result.byteCount} bytes");
}

public override void OnOwnershipTransferred(VRCPlayerApi player)
{
    Debug.Log($"New owner: {player.displayName}");

    if (player.isLocal)
    {
        // We are now the owner
        OnBecameOwner();
    }
}
```

### Ownership Request Arbitration

`OnOwnershipRequest` allows the current owner to accept or reject ownership transfers. The callback runs locally on **both the requester and the current owner**, so the logic must return the same result on both sides to avoid desync.

```csharp
/// <summary>
/// Called on both the requester's and the current owner's clients
/// when another player requests ownership. Return true to accept,
/// false to reject the transfer. The result MUST agree on both sides.
/// </summary>
public override bool OnOwnershipRequest(
    VRCPlayerApi requestingPlayer,
    VRCPlayerApi requestedOwner)
{
    if (requestingPlayer == null || !requestingPlayer.IsValid()) return true;

    // Example: Only allow ownership transfer when game is in lobby phase
    if (gamePhase != 0)
    {
        return false; // Reject during active gameplay
    }

    return true;
}
```

> **Important**: This callback runs locally on **both the requester and the current owner**. The logic must return the same result on both sides to avoid desync. If the current owner has disconnected, the callback is not invoked — VRChat auto-assigns a new owner directly.

## Station Events

Called when a player enters/exits a VRCStation (seat, vehicle).

| Event | When Called |
|-------|-------------|
| `void OnStationEntered(VRCPlayerApi player)` | Player sat down |
| `void OnStationExited(VRCPlayerApi player)` | Player stood up |

```csharp
public override void OnStationEntered(VRCPlayerApi player)
{
    Debug.Log($"{player.displayName} sat down");

    if (player.isLocal)
    {
        // Start vehicle controls
        EnableVehicleControls();
    }
}

public override void OnStationExited(VRCPlayerApi player)
{
    if (player.isLocal)
    {
        DisableVehicleControls();
    }
}
```

## Video Player Events

Called by VRCUnityVideoPlayer or AVProVideoPlayer.

| Event | When Called |
|-------|-------------|
| `void OnVideoStart()` | Video starts playing |
| `void OnVideoEnd()` | Video ends |
| `void OnVideoPause()` | Video paused |
| `void OnVideoPlay()` | Video resumed |
| `void OnVideoReady()` | Video loaded and ready |
| `void OnVideoError(VideoError error)` | Error occurred |
| `void OnVideoLoop()` | Video looped |

```csharp
public override void OnVideoReady()
{
    Debug.Log("Video ready to play");
}

public override void OnVideoError(VideoError videoError)
{
    Debug.LogError($"Video error: {videoError}");
}
```

## String/Image Loading Events

Called after VRCStringDownloader or VRCImageDownloader requests.
For API details, constraints, and practical patterns, see `references/web-loading.md`.

| Event | When Called |
|-------|-------------|
| `void OnStringLoadSuccess(IVRCStringDownload result)` | String download succeeded |
| `void OnStringLoadError(IVRCStringDownload result)` | String download failed |
| `void OnImageLoadSuccess(IVRCImageDownload result)` | Image download succeeded |
| `void OnImageLoadError(IVRCImageDownload result)` | Image download failed |

**IVRCStringDownload**: `Result` (string), `ResultBytes` (byte[]), `Error` (string), `ErrorCode` (int), `Url` (VRCUrl)

**IVRCImageDownload**: `Result` (Texture2D), `SizeInMemoryBytes` (int), `Error` (string), `ErrorCode` (int), `Material`, `TextureInfo`

```csharp
public override void OnStringLoadSuccess(IVRCStringDownload result)
{
    string data = result.Result;
    Debug.Log($"Downloaded: {data}");
}

public override void OnStringLoadError(IVRCStringDownload result)
{
    Debug.LogError($"Download failed ({result.ErrorCode}): {result.Error}");
}
```

## MIDI Events

Called when MIDI input is received (PC only).

| Event | When Called |
|-------|-------------|
| `void MidiNoteOn(int channel, int note, int velocity)` | Note pressed |
| `void MidiNoteOff(int channel, int note, int velocity)` | Note released |
| `void MidiControlChange(int channel, int number, int value)` | Control changed |

```csharp
public override void MidiNoteOn(int channel, int note, int velocity)
{
    Debug.Log($"Note on: channel={channel}, note={note}, velocity={velocity}");
    PlayNote(note, velocity / 127f);
}
```

## Standard Unity Events

Standard Unity events that work in UdonSharp.

### Lifecycle

| Event | When Called |
|-------|-------------|
| `void Start()` | First frame (after all Awake) |
| `void OnEnable()` | When enabled |
| `void OnDisable()` | When disabled |
| `void OnDestroy()` | When destroyed |

### Physics

| Event | When Called |
|-------|-------------|
| `void OnTriggerEnter(Collider other)` | Object enters trigger |
| `void OnTriggerStay(Collider other)` | Object stays in trigger |
| `void OnTriggerExit(Collider other)` | Object exits trigger |
| `void OnCollisionEnter(Collision collision)` | Collision starts |
| `void OnCollisionStay(Collision collision)` | Collision ongoing |
| `void OnCollisionExit(Collision collision)` | Collision ends |

### Rendering

| Event | When Called |
|-------|-------------|
| `void OnWillRenderObject()` | Before rendering |
| `void OnBecameVisible()` | Became visible to camera |
| `void OnBecameInvisible()` | No longer visible |

### Animation

| Event | When Called |
|-------|-------------|
| `void OnAnimatorMove()` | Animator root motion update |
| `void OnAnimatorIK(int layerIndex)` | IK pass |

```csharp
void Start()
{
    // Initialize after all Awake calls
    InitializeComponents();
}

void OnTriggerEnter(Collider other)
{
    // Non-player object entered trigger
    if (other.CompareTag("Projectile"))
    {
        TakeDamage();
    }
}
```

## Event Execution Order

Reference: [VRChat Official Docs — Event Execution Order](https://creators.vrchat.com/worlds/udon/event-execution-order/)

### Per-Frame Lifecycle

The Unity/VRChat per-frame execution order (steady state, every frame):

| Step | Event | Notes |
|------|-------|-------|
| 1 | `OnEnable()` | Only on the frame the behaviour becomes enabled |
| 2 | `Start()` | Only on the first frame the behaviour is active |
| 3 | `FixedUpdate()` | Physics tick (~50 Hz); may run 0 or more times per frame |
| 4 | `Update()` | Every render frame |
| 5 | `LateUpdate()` | After all `Update` calls |
| 6 | `PostLateUpdate()` | VRChat-specific; after `LateUpdate`, before render |

> **Note**: `Awake()` is **not available** in UdonSharp. Use `Start()` for one-time initialization instead.

**Networking events** (`OnDeserialization`, `OnPreSerialization`, etc.) are dispatched between frames and can fire at any point outside the per-frame order above.

---

### Initialization Guarantee

`OnEnable` and `Start` are guaranteed to run **before any other event** fires on the behaviour, and they run with **no gap between them** on the initial activation. This means:

- You can safely access component references set up in `Start()` from any event handler.
- No VRChat event (player join, deserialization, etc.) will interrupt `OnEnable`/`Start`.

---

### Scenario: Instance Creator (First Player)

When you are the first player to enter an instance:

```
_onEnable → _start
    ↓
OnPlayerJoined(self)          ← fires for yourself
    ↓
OnMasterChanged               ← master transferred from nobody to you
```

- You are immediately both Master and Owner of scene objects.
- No `OnDeserialization` fires because there is no prior state to receive.

---

### Scenario: Late Joiner

When you join an existing instance:

```
_onEnable → _start
    ↓
OnPlayerJoined(player A)      ← for each player already in the instance
OnPlayerJoined(player B)      ← (order matches instance join order)
OnPlayerJoined(self)          ← last: your own join event
    ↓
OnDeserialization             ← receives synced variable state from owner
```

> **Note**: `OnPlayerJoined` fires for **every** player currently in the instance, including yourself. You will always be the last entry in this sequence.

> **Note**: Synced variable values are **not guaranteed to be initialized** before `OnDeserialization` fires. Do not read synced variables in `Start()` for late joiners — they may still be at default values.

#### Edge Case: Owner Calls RequestSerialization Near OnPlayerJoined

If the current owner calls `RequestSerialization()` at or very close to the time a late joiner's `OnPlayerJoined` fires (for example, in their own `OnPlayerJoined` handler), the following race condition can occur on the **late joiner's client**:

1. Synced variable value arrives and changes.
2. `OnVariableChanged` fires for the changed variable.
3. `OnDeserialization` fires immediately after.

In this specific edge case (most likely when the late joiner is the **first instance** on its client), `OnVariableChanged` can fire **before** `Start()` has returned. Guard against this with an initialization flag (see pattern below).

---

### Scenario: Another Player Joins Your Instance

When a new player joins while you are already in the instance:

```
OnPlayerJoined(newPlayer)     ← fires only for the newly joined player
```

If you are the owner of synced objects, this is the correct place to call `RequestSerialization()` to push current state to the late joiner:

```csharp
public override void OnPlayerJoined(VRCPlayerApi player)
{
    if (Networking.IsOwner(gameObject))
    {
        RequestSerialization();
    }
}
```

---

### Practical Patterns

#### Do Not Access Synced State in Start()

```csharp
// WRONG: syncedScore may still be 0 (default) for a late joiner
void Start()
{
    UpdateScoreDisplay(syncedScore);
}

// CORRECT: wait for OnDeserialization before reading synced state
public override void OnDeserialization()
{
    UpdateScoreDisplay(syncedScore);
}
```

#### Initialization Flag Guard

Use a `_isInitialized` flag to ensure setup code runs exactly once after the first `OnDeserialization`, and to guard against `OnVariableChanged` firing before `Start()` completes:

```csharp
[UdonSynced] private int _syncedScore;
private bool _isInitialized;

void Start()
{
    _isInitialized = false;
}

public override void OnDeserialization()
{
    if (!_isInitialized)
    {
        _isInitialized = true;
        InitializeFromSyncedState();
    }
    UpdateDisplay();
}

// OnVariableChanged can fire before Start() in edge cases — guard with the flag
public override void OnVariableChanged()
{
    if (!_isInitialized) return;
    UpdateDisplay();
}

private void InitializeFromSyncedState()
{
    UpdateDisplay();
    // Perform any one-time setup that depends on synced variables
}
```

> **Note**: On the **instance creator's client**, `OnDeserialization` never fires on initial load (there is no prior state). Initialize with default values in `Start()` and let `OnDeserialization` handle updates from that point on.

## Best Practices

### Player Validity Check

```csharp
public override void OnPlayerTriggerEnter(VRCPlayerApi player)
{
    if (player == null || !player.IsValid())
    {
        return;
    }
    // Safe to use player
}
```

### Local vs All Players

```csharp
public override void OnPlayerJoined(VRCPlayerApi player)
{
    // This runs for ALL players in the instance

    if (player.isLocal)
    {
        // Only runs for the joining player themselves
        ShowTutorial();
    }
}
```

### Ownership Check Before Sync

```csharp
public override void OnPlayerJoined(VRCPlayerApi player)
{
    // Only owner should trigger sync for late joiners
    if (Networking.IsOwner(gameObject))
    {
        RequestSerialization();
    }
}
```

## See Also

- [api.md](api.md) - VRCPlayerApi and Networking class reference for types used in event handlers
- [dynamics.md](dynamics.md) - PhysBone and Contact component setup for the events listed here
- [networking.md](networking.md) - Serialization and ownership events in depth (`OnDeserialization`, `OnOwnershipTransferred`)
- [patterns-video.md](patterns-video.md) - Video player event handling patterns (`OnVideoReady`, `OnVideoError`, `OnVideoStart`, `OnVideoEnd`)
