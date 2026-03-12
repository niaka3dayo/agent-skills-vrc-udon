# UdonSharp Cheatsheet

**SDK 3.7.1 - 3.10.2 Coverage** (as of March 2026)

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
| `OnPhysBoneGrab(PhysBoneGrabInfo)` | **3.10+** PhysBone grabbed |

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

// Repeating
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
    if (info.isAvatar) {
        Debug.Log($"Touched by: {info.player?.displayName}");
    }
}

// PhysBone events
public override void OnPhysBoneGrab(PhysBoneGrabInfo info) {
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
| `string` | Variable | Subject to sync buffer size limit |
| `Vector3` | 12 | |
| `Quaternion` | 16 | |
| `Color` | 16 | |
| `T[]` | Variable | Arrays of the above types |

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
| Method not found | Make method `public` and remove parameters |
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

// Image download (Dispose required!)
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
| Memory management | Not required | `Dispose()` required |

**Dynamic VRCUrl generation: Not possible** -- `new VRCUrl(stringVar)` is blocked by the Udon VM at runtime.
For dynamic URLs: (1) `VRCUrlInputField` (user manual input), (2) `VRCUrl[]` array (predefined), (3) server-side routing

---

## Official Documentation & Error Investigation (WebSearch)

When you need the latest information or error investigation:

```text
# Official documentation search
WebSearch: "API name or feature site:creators.vrchat.com"

# UdonSharp API reference
WebSearch: "API name site:udonsharp.docs.vrchat.com"

# Forum search
WebSearch: "error message site:ask.vrchat.com"

# Known bug search
WebSearch: "error message site:feedback.vrchat.com"

# GitHub Issues
WebSearch: "error message site:github.com/vrchat-community/UdonSharp"
```

| Site | Purpose |
|------|---------|
| creators.vrchat.com | Official Udon / SDK documentation |
| udonsharp.docs.vrchat.com | UdonSharp API reference |
| ask.vrchat.com | Q&A, solutions |
| feedback.vrchat.com | Bug reports, status |
| GitHub | UdonSharp-specific bugs |
