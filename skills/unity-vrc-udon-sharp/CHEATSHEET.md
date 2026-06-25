# UdonSharp Cheatsheet

**SDK 3.7.1 - 3.10.4 Coverage**

## Blocked Features and Alternatives

| Blocked | Alternative |
|---------|------------|
| `List<T>` | `T[]` or `DataList` |
| `Dictionary<K,V>` | `DataDictionary` |
| `async/await` | `SendCustomEventDelayedSeconds()` |
| `yield return` | `SendCustomEventDelayedSeconds()` |
| `try/catch` | Null checks, validation |
| LINQ | `for` loops |
| `interface` | Base class / `SendCustomEvent` |

## Available Features (SDK 3.7.1+)

| Feature | SDK | Notes |
|---------|-----|-------|
| `StringBuilder` | 3.7.1 | Efficient string concatenation |
| `RegularExpressions` | 3.7.1 | Pattern matching |
| `System.Random` | 3.7.1 | Deterministic random numbers |
| `GetComponent<T>()` (inheritance) | 3.8+ | Works with UdonSharpBehaviour |
| `[NetworkCallable]` | 3.8.1 | Parameterized network events |
| Persistence | 3.7.4 | PlayerData/PlayerObject |
| Dynamics for Worlds | 3.10.0 | PhysBones, Contacts |
| VRCTween | 3.10.4 | Local tweens, cancelable delayed calls |

---

## Sync Modes

| Mode | Use Case | Limit | Sync Method |
|------|----------|-------|-------------|
| `NoVariableSync` | Events only | - | No sync |
| `Continuous` | Position/rotation | ~200B | Automatic ~10Hz |
| `Manual` | State/score | 280KB | `RequestSerialization()` |

```csharp
[UdonBehaviourSyncMode(BehaviourSyncMode.Manual)]
public class MyScript : UdonSharpBehaviour { }
```

### Sync Decision (Quick)

| Question | No | Yes |
|----------|-----|------|
| Visible to other players? | No sync | next |
| Needed by late joiners? | Events only | next |
| Continuous change? | Manual sync | Continuous |

**Target**: 1 behaviour < 50 bytes (reference: voting system=9B, shooting manager=38B)

---

## Sync Strategy Decision Tree

```text
Q1: Does data need to persist across sessions / per-player?
  Yes -> PlayerData (SDK 3.7.4+) or PlayerObject
  No  -> Q2

Q2: Do all players need to see the same state (late joiners included)?
  Yes -> [UdonSynced] variable (Manual or Continuous)
  No  -> Q3

Q3: Is it a one-shot action (fire-and-forget, no state needed)?
  Yes -> SendCustomNetworkEvent / [NetworkCallable] (SDK 3.8.1+)
  No  -> Keep it local (no sync needed)
```

| Scenario | Pattern |
|----------|---------|
| Per-player save data | `PlayerData` API |
| Shared persistent state (score, phase) | `[UdonSynced]` + Manual + `RequestSerialization()` |
| Continuous position/rotation | `[UdonSynced]` + Continuous |
| One-shot effect (sound, animation) | `SendCustomNetworkEvent` |
| Parameterized one-shot (SDK 3.8.1+) | `[NetworkCallable]` |
| Personal effect (only local player sees) | Local only, no sync |

---

## Networking Patterns

```csharp
[UdonSynced, FieldChangeCallback(nameof(Value))]
private int _value;

public int Value {
    get => _value;
    set { _value = value; OnValueChanged(); }
}

public void SetValue(int newValue) {
    Networking.SetOwner(Networking.LocalPlayer, gameObject);
    Value = newValue;
    RequestSerialization();
}
```

---

## Key Events

| Event | Trigger |
|-------|---------|
| `Interact()` | Player interacts |
| `OnPickup()` / `OnDrop()` | Pickup grabbed/released |
| `OnPlayerJoined(VRCPlayerApi)` | Player joined |
| `OnPlayerLeft(VRCPlayerApi)` | Player left |
| `OnPlayerTriggerEnter(VRCPlayerApi)` | Player entered trigger |
| `OnDeserialization()` | Synced data received |
| `OnOwnershipTransferred(VRCPlayerApi)` | Ownership changed |
| `OnPlayerRestored(VRCPlayerApi)` | **3.7.4+** Persistence data loaded |
| `OnContactEnter(ContactEnterInfo)` | **3.10+** Contact started |
| `OnPhysBoneGrabbed(PhysBoneGrabbedInfo)` | **3.10+** PhysBone grabbed |

---

## Initialization Pattern (Inactive Object Support)

```csharp
// NG: Start() is not called when the object is inactive
void Start() { audioSource = GetComponent<AudioSource>(); }

// OK: OnEnable + flag pattern
private bool _initialized = false;

void OnEnable() => Initialize();
void Start() => Initialize();

private void Initialize() {
    if (_initialized) return;
    _initialized = true;
    audioSource = GetComponent<AudioSource>();
}

public void PlaySound() {
    Initialize(); // Guard against external calls
    audioSource.Play();
}
```

VRChat world scene setup: pair each `AudioSource` with `VRC_SpatialAudioSource`. For warning-only additions, use Gain 0 dB and preserve existing 2D/3D intent, volume, max distance, and rolloff curves.

| Scenario | Pattern |
|----------|---------|
| Always active | `Start()` only is fine |
| Placed as inactive | `OnEnable()` + `Initialize()` |
| Has synced variables | Also call `Initialize()` in `OnDeserialization()` |

---

## Player API Quick Reference

```csharp
// Get players
VRCPlayerApi local = Networking.LocalPlayer;
VRCPlayerApi[] all = new VRCPlayerApi[VRCPlayerApi.GetPlayerCount()];
VRCPlayerApi.GetPlayers(all);

// Check validity (ALWAYS do this before accessing VRCPlayerApi)
VRCPlayerApi player = Networking.LocalPlayer;
if (player != null && player.IsValid()) { }

// Properties
player.displayName    // string
player.playerId       // int
player.isLocal        // bool
player.isMaster       // bool
player.IsUserInVR()   // bool

// Position
player.GetPosition()  // Vector3
player.GetRotation()  // Quaternion
player.TeleportTo(pos, rot)

// Movement
player.SetVelocity(velocity)
player.GetVelocity()
player.Immobilize(true/false)
```

---

## Delayed Execution

```csharp
// Instead of coroutines
SendCustomEventDelayedSeconds(nameof(MyMethod), 2.0f);
SendCustomEventDelayedFrames(nameof(MyMethod), 1);

// EventTiming (SDK 3.10.2+): FixedUpdate / PostLateUpdate
SendCustomEventDelayedSeconds(nameof(PhysicsAction), 1.0f, EventTiming.FixedUpdate);
SendCustomEventDelayedFrames(nameof(CameraFollow), 1, EventTiming.PostLateUpdate);

// Repeating (single-instance, sparse timers only — see patterns-performance.md
// "Event Dispatch & Cross-Behaviour Call Cost Tiers" for many-instance / short-period alternatives)
public void StartLoop() {
    _running = true;
    DoLoop();
}
public void DoLoop() {
    if (!_running) return;
    // ... action ...
    SendCustomEventDelayedSeconds(nameof(DoLoop), 1.0f);
}
```

For cancelable timers on SDK 3.10.4+, use `VRCTween.DelayedCall`; keep helper-`GameObject` cancellation workarounds only for older SDK projects.

---

## VRCTween (SDK 3.10.4+)

```csharp
using VRC.SDK3.Components;

private VRCTweenHandle _scaleTween;

public void Pulse() {
    _scaleTween.Kill(); // safe no-op when invalid/default
    _scaleTween = gameObject.TweenScale(Vector3.one * 1.2f, 0.15f, VRCTweenEase.OutQuad)
        .OnComplete(this, nameof(OnPulseUp));
}

public void OnPulseUp() {
    _scaleTween = gameObject.TweenScale(Vector3.one, 0.15f, VRCTweenEase.OutQuad);
}

void OnDestroy() {
    gameObject.KillAllTweens();
}
```

| Need | Use | Notes |
|------|-----|-------|
| Smooth transform/UI/audio changes | `TweenPosition`, `TweenScale`, `TweenFade`, `TweenPitch` | Returns `VRCTweenHandle` |
| Cancelable delayed event | `VRCTween.DelayedCall(this, nameof(Method), seconds)` | Prefer over helper objects on SDK 3.10.4+ |
| Delayed active toggle | `VRCTween.DelayedSetActive(target, active, seconds)` | Use for local visibility/state toggles |
| Cleanup | `handle.Kill()` / `gameObject.KillAllTweens()` | Kill stored handles and long/infinite tweens |
| High-frequency retargeting | `ChangeEndValue`, `SetDuration`, `SetEase`, `Restart` | Reuse a handle instead of kill/recreate in hot paths |

VRCTween is **local-only**: it does not automatically sync. For shared animation state, sync the intent/time separately and recreate or seek the local tween per client. Invalid/default `VRCTweenHandle` operations are safe no-ops; check `handle.IsValid` only when branching on creation success.

---

## Inter-Script Communication

```csharp
// Call method on another script
otherScript.SendCustomEvent("MethodName");

// Pass data
otherScript.SetProgramVariable("fieldName", value);
otherScript.SendCustomEvent("ProcessData");

// Network event (legacy - no params)
SendCustomNetworkEvent(NetworkEventTarget.All, "MethodName");
SendCustomNetworkEvent(NetworkEventTarget.Owner, "MethodName");
```

---

## NetworkCallable (SDK 3.8.1+)

```csharp
// Method must have [NetworkCallable] attribute
[NetworkCallable]
public void TakeDamage(int damage, int attackerId) {
    health -= damage;
}

// Call with up to 8 parameters
SendCustomNetworkEvent(
    NetworkEventTarget.All,
    nameof(TakeDamage),
    damage, attackerId
);
```

**Constraints:** `public`, no `static`/`virtual`/`override`, max 8 params, syncable types only

---

## Persistence (SDK 3.7.4+)

```csharp
using VRC.SDK3.Persistence;

// Wait for data to load
public override void OnPlayerRestored(VRCPlayerApi player) {
    if (!player.isLocal) return;
    if (PlayerData.TryGetInt(player, "score", out int s)) {
        score = s;
    }
}

// Save data
PlayerData.SetInt(Networking.LocalPlayer, "score", 100);
```

**Limit:** 100KB per player per world

---

## Dynamics (SDK 3.10.0+)

```csharp
// Contact events
public override void OnContactEnter(ContactEnterInfo info) {
    ContactSenderProxy sender = info.contactSender;
    if (!sender.isValid) return;

    VRCPlayerApi player = sender.player;
    Debug.Log(player != null
        ? $"Touched by: {player.displayName}"
        : $"Touched by usage: {sender.usage}");
}

// PhysBone events
public override void OnPhysBoneGrabbed(PhysBoneGrabbedInfo info) {
    Debug.Log($"Grabbed by: {info.player?.displayName}");
}
```

---

## Syncable Types

| Type | Bytes | Notes |
|------|-------|-------|
| `bool` | 1 | |
| `byte` | 1 | 0-255 |
| `short` | 2 | |
| `int` | 4 | |
| `float` | 4 | |
| `string` | 2 bytes/char | Subject to sync buffer size limit |
| `Vector3` | 12 | |
| `Quaternion` | 16 | |
| `Color` | 16 | |
| `T[]` | Variable | Arrays of the above types |
| `VRCUrl` | 2 bytes/char | Arrays sync too (VRChat 2021.3.2+) |

**Not syncable:** `GameObject`, `Transform`, `VRCPlayerApi`, custom classes

---

## Debug Template

```csharp
[SerializeField] private bool _debug = false;

private void Log(string msg) {
    if (_debug) Debug.Log($"[{gameObject.name}] {msg}");
}
```

---

## Common Fixes

| Error | Fix |
|-------|-----|
| Sync not working | `SetOwner()` -> modify -> `RequestSerialization()` |
| NullReference on player | Check `player != null && player.IsValid()` |
| Method not found (SendCustomEvent / network event target) | Make the target method public and parameterless (pass data via `SetProgramVariable`); plain network events are also parameterless ([NetworkCallable] allows up to 8) |
| FieldChangeCallback not firing | Use property setter even for local changes |
| Cannot modify struct | `var v = struct; v.x = 1; struct = v;` |
| Start() not called | Inactive object support: `OnEnable()` + `Initialize()` |

---

## Web Loading (String / Image Download)

See `references/web-loading.md` for details.

```csharp
using VRC.SDK3.StringLoading;  // String Loading
using VRC.SDK3.ImageLoading;   // Image Loading
using VRC.SDK3.Data;           // VRCJson

// String download
VRCStringDownloader.LoadUrl(url, (IUdonEventReceiver)this);
// -> OnStringLoadSuccess(IVRCStringDownload) / OnStringLoadError

// Image download (Dispose the wrapper + Destroy the assigned Texture2D — see image-loading-vram.md)
var dl = new VRCImageDownloader();
dl.DownloadImage(url, material, (IUdonEventReceiver)this, textureInfo);
// -> OnImageLoadSuccess(IVRCImageDownload) / OnImageLoadError

// JSON parse (after string download)
if (VRCJson.TryDeserializeFromJson(result.Result, out DataToken json))
{
    DataDictionary dict = json.DataDictionary;
    // Numbers are stored as Double: (int)token.Double
}
```

| Constraint | String Loading | Image Loading |
|------------|:-:|:-:|
| Rate limit | 5 sec / request | 5 sec / request (scene-wide) |
| Max size | - | 2048x2048 |
| Redirects | Trusted only | Not allowed |
| Trusted URL | Separate domain list | Separate domain list |
| Memory management | Not required | `Dispose()` releases the wrapper; also `Destroy()` the assigned `Texture2D` |

**Dynamic VRCUrl generation: Not possible** -- `new VRCUrl(stringVar)` is blocked by the Udon VM at runtime.
For dynamic URLs: (1) `VRCUrlInputField` (user manual input), (2) `VRCUrl[]` array (predefined), (3) server-side routing

---

## Reference Index

| Topic | File |
|-------|------|
| Full VRChat API quick reference (VRCPlayerApi, networking, camera, persistence, data containers) | [references/api.md](references/api.md) |
| Testing in Editor (ClientSim), multi-client debugging | [references/testing.md](references/testing.md) |
| Networking ownership, sync modes, IsMaster migration | [references/networking.md](references/networking.md) |
| Web / Image loading, VRCUrl constraints | [references/web-loading.md](references/web-loading.md) |
| UI / Canvas patterns | [references/patterns-ui.md](references/patterns-ui.md) |
| Video player patterns | [references/patterns-video.md](references/patterns-video.md) |
| Custom inspectors, editor-only setup components (IEditorOnly) | [references/editor-scripting.md](references/editor-scripting.md) |
| UdonSharp C# feature constraints and compiler behavior | [references/constraints.md](references/constraints.md) |
| UdonSharp event overrides and Unity callback rules | [references/events.md](references/events.md) |
| Common compile, runtime, networking, persistence, dynamics, editor, and performance issues | [references/troubleshooting.md](references/troubleshooting.md) |
| Networking mistakes, data-loss causes, and advanced sync patterns | [references/networking-antipatterns.md](references/networking-antipatterns.md) |
| Network bandwidth throttling, request serialization, bit packing, and owner-centric architecture | [references/networking-bandwidth.md](references/networking-bandwidth.md) |
| Object pooling, synced game state, NetworkCallable, persistence, dynamics, and debouncing patterns | [references/patterns-networking.md](references/patterns-networking.md) |
| Practical synced gimmick examples for local, event, and synced-variable patterns | [references/sync-examples.md](references/sync-examples.md) |
| Persistent PlayerData and PlayerObject storage | [references/persistence.md](references/persistence.md) |
| PhysBones, Contacts, and VRC Constraints in worlds | [references/dynamics.md](references/dynamics.md) |
| Initialization, interaction, player detection, timer, audio, pickup, animation, UI, and teleportation patterns | [references/patterns-core.md](references/patterns-core.md) |
| Cross-class call overhead, partial classes, update handlers, PostLateUpdate, spatial queries, and animator hashes | [references/patterns-performance.md](references/patterns-performance.md) |
| Array helpers, event bus, GameObject relay communication, pseudo-struct double-cast, and callback patterns | [references/patterns-utilities.md](references/patterns-utilities.md) |
| VRCTween local animation, cancelable delayed calls, cleanup, and high-frequency reuse | [references/vrctween.md](references/vrctween.md) |
| VRCImageDownloader GPU memory lifecycle, safe texture cleanup, fades, and staggering | [references/image-loading-vram.md](references/image-loading-vram.md) |
| Advanced packed resource loading with VRCStringDownloader | [references/web-loading-advanced.md](references/web-loading-advanced.md) |
| SDK upgrade steps, version-by-version changes, and migration checklists | [references/sdk-migration.md](references/sdk-migration.md) |
| Preserving task-specific design intent across long or resumed work | [references/context-preservation.md](references/context-preservation.md) |
