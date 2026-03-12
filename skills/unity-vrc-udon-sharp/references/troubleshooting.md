# UdonSharp Troubleshooting Guide

Common errors, causes, and solutions for VRChat UdonSharp development.

**Supported SDK Versions**: 3.7.1 - 3.10.2 (as of March 2026)

## Table of Contents

- [Compile Errors](#compile-errors)
- [Runtime Errors](#runtime-errors)
- [Networking Issues](#networking-issues)
- [NetworkCallable Issues (SDK 3.8.1+)](#networkcallable-issues-sdk-381)
- [Persistence Issues (SDK 3.7.4+)](#persistence-issues-sdk-374)
- [Dynamics Issues (SDK 3.10.0+)](#dynamics-issues-sdk-3100)
- [Editor Issues](#editor-issues)
- [Performance Issues](#performance-issues)
- [Common Pitfalls](#common-pitfalls)

---

## Compile Errors

### "UdonSharp does not support X"

**Symptoms:**
```
UdonSharpException: UdonSharp does not currently support [feature]
```

**Common unsupported features:**
| Feature | Alternative |
|---------|-------------|
| `async/await` | `SendCustomEventDelayedSeconds()` |
| `yield return` / coroutines | `SendCustomEventDelayedSeconds()` |
| Generics `List<T>` | Arrays `T[]` or `DataList` |
| LINQ | Manual loops |
| `dynamic` | Explicit types |
| `ref`/`out` parameters | Return values or class fields |
| Multi-dimensional arrays `T[,]` | Jagged arrays `T[][]` |
| Delegates / Events | `SendCustomEvent()` |
| `nameof()` on external types | String literals |
| `try/catch/finally` | Validate inputs, null checks |

**Solution:**
Use the alternatives documented. See `constraints.md` for the complete list.

---

### "The type or namespace 'X' could not be found"

**Symptoms:**
```
CS0246: The type or namespace name 'List' could not be found
```

**Causes:**
1. Using an unsupported System type
2. Missing `using` directive
3. Assembly definition issues

**Solution:**

```csharp
// Wrong - List<T> not supported
using System.Collections.Generic;
List<int> numbers = new List<int>();

// Correct - Use arrays
int[] numbers = new int[10];

// Or use DataList for dynamic sizing
DataList list = new DataList();
list.Add(new DataToken(42));
```

---

### "'UdonSharpBehaviour' does not contain a definition for 'X'"

**Symptoms:**
```
CS1061: 'UdonSharpBehaviour' does not contain a definition for 'StartCoroutine'
```

**Cause:** Attempting to use MonoBehaviour methods not exposed to Udon.

**Common unexposed methods and alternatives:**

| Unexposed method | Alternative |
|----------------|-------------|
| `StartCoroutine()` | `SendCustomEventDelayedSeconds()` |
| `StopCoroutine()` | Boolean flag check |
| `Invoke()` | `SendCustomEvent()` |
| `InvokeRepeating()` | `SendCustomEventDelayedSeconds()` loop |
| `GetComponentsInChildren<T>()` | Inspector references or manual search |
| `FindObjectOfType<T>()` | Inspector references |

---

### "Field 'X' is not serializable"

**Symptoms:**
```
UdonSharp: Field 'X' is not serializable
```

**Cause:** Attempting to sync an unsupported type.

**Syncable types:**
- Primitives: `bool`, `byte`, `sbyte`, `short`, `ushort`, `int`, `uint`, `long`, `ulong`, `float`, `double`, `char`
- Strings: `string`
- Unity types: `Vector2`, `Vector3`, `Vector4`, `Quaternion`, `Color`, `Color32`
- Arrays of above types

**Not syncable:**
- Custom classes/structs
- `GameObject`, `Transform`
- `VRCPlayerApi`

**Solution:**
```csharp
// Wrong - Cannot sync VRCPlayerApi
[UdonSynced] private VRCPlayerApi targetPlayer;

// Correct - Sync player ID instead
[UdonSynced] private int targetPlayerId;

public VRCPlayerApi GetTargetPlayer()
{
    return VRCPlayerApi.GetPlayerById(targetPlayerId);
}
```

---

## Runtime Errors

### "NullReferenceException"

**Symptoms:**
```
NullReferenceException: Object reference not set to an instance of an object
```

**Common causes:**
1. Inspector references not assigned
2. Calling `GetComponent()` on the wrong object
3. Player left during an operation
4. Object was destroyed

**Solution:**

```csharp
// Always validate Inspector references
void Start()
{
    if (targetObject == null)
    {
        Debug.LogError($"[{gameObject.name}] targetObject is not assigned!");
        enabled = false;
        return;
    }
}

// Always check player validity
public override void OnPlayerTriggerEnter(VRCPlayerApi player)
{
    if (player == null || !player.IsValid())
    {
        return;
    }
    // Safe to use player
}

// Check before accessing synced player
public void DoSomethingWithPlayer()
{
    VRCPlayerApi player = VRCPlayerApi.GetPlayerById(syncedPlayerId);
    if (player == null || !player.IsValid())
    {
        Debug.LogWarning("Player no longer valid");
        return;
    }
    // Safe to use player
}
```

---

### "SendCustomEvent: Method 'X' not found"

**Symptoms:**
```
[UdonBehaviour] SendCustomEvent: Method 'MyMethod' not found
```

**Causes:**
1. Typo in method name
2. Method is private (must be public)
3. Method has parameters (not supported)

**Solution:**

```csharp
// Wrong - Method is private
private void MyMethod() { }

// Wrong - Method has parameters
public void MyMethod(int value) { }

// Correct - Public, parameterless
public void MyMethod() { }

// For passing data, use SetProgramVariable first
otherScript.SetProgramVariable("inputValue", 42);
otherScript.SendCustomEvent("ProcessInput");
```

---

### "Heap ran out of memory"

**Symptoms:**
```
Udon heap ran out of memory
```

**Causes:**
1. Creating large numbers of objects in loops
2. Arrays that are too large
3. String concatenation in loops
4. Memory leaks from arrays that are not cleared

**Solution:**

```csharp
// Wrong - Creates new array every frame
void Update()
{
    VRCPlayerApi[] players = new VRCPlayerApi[VRCPlayerApi.GetPlayerCount()];
    VRCPlayerApi.GetPlayers(players);
}

// Correct - Reuse array, resize when needed
private VRCPlayerApi[] _playerCache;
private int _lastPlayerCount = 0;

void Update()
{
    int currentCount = VRCPlayerApi.GetPlayerCount();
    if (_playerCache == null || _playerCache.Length < currentCount)
    {
        _playerCache = new VRCPlayerApi[currentCount + 10]; // Buffer
    }
    VRCPlayerApi.GetPlayers(_playerCache);
}

// Wrong - String concatenation creates garbage
string result = "";
for (int i = 0; i < 100; i++)
{
    result += i.ToString(); // Creates new string each iteration
}

// Correct - Use char array or limit concatenation
// For display purposes, just show final result
```

---

### "ArrayIndexOutOfRangeException"

**Symptoms:**
```
IndexOutOfRangeException: Index was outside the bounds of the array
```

**Common causes:**
1. Array not initialized
2. Off-by-one errors
3. Player count changed during iteration

**Solution:**

```csharp
// Always check array bounds
public void ProcessArray(int[] data)
{
    if (data == null || data.Length == 0)
    {
        return;
    }

    for (int i = 0; i < data.Length; i++)
    {
        // Safe access
    }
}

// Be careful with player arrays
public override void OnPlayerLeft(VRCPlayerApi player)
{
    // GetPlayers() count has already changed!
    // Cache count before iteration if needed
}
```

---

## Networking Issues

### Variables Not Syncing

**Symptoms:**
- `[UdonSynced]` variables not updating on other clients
- State differs between players

**Checklist:**

1. **Is the variable properly marked?**
```csharp
// Correct
[UdonSynced] private int myValue;
```

2. **Is the type syncable?** (See syncable types above)

3. **Did you call RequestSerialization()?**
```csharp
public void ChangeValue()
{
    myValue = 42;
    RequestSerialization(); // Required for Manual sync mode!
}
```

4. **Do you have ownership?**
```csharp
public void ChangeValue()
{
    if (!Networking.IsOwner(gameObject))
    {
        Networking.SetOwner(Networking.LocalPlayer, gameObject);
    }
    myValue = 42;
    RequestSerialization();
}
```

5. **Check sync mode:**
```csharp
// For infrequent changes (buttons, toggles)
[UdonBehaviourSyncMode(BehaviourSyncMode.Manual)]

// For continuous changes (position, rotation)
[UdonBehaviourSyncMode(BehaviourSyncMode.Continuous)]
```

---

### FieldChangeCallback Not Firing

**Symptoms:** Property setter not called during synchronization.

**Checklist:**

1. **Correct attribute syntax?**
```csharp
// Correct - nameof() points to PROPERTY
[UdonSynced, FieldChangeCallback(nameof(MyProperty))]
private int _myValue;

public int MyProperty
{
    get => _myValue;
    set
    {
        _myValue = value;
        OnValueChanged();
    }
}
```

2. **Using property everywhere locally?**
```csharp
// Wrong - Bypasses callback
_myValue = 10;

// Correct - Uses property
MyProperty = 10;
```

3. **Sync mode compatibility:**
   - Works with `Manual` sync mode
   - May have timing issues with `Continuous`

---

### Ownership Transfer Race Conditions

**Problem:** Multiple players attempting to take ownership simultaneously.

**Symptoms:**
- Unexpected ownership changes
- State desynchronization
- "Flickering" between states

**Solution:**
```csharp
// Use ownership request pattern
public override void Interact()
{
    if (Networking.IsOwner(gameObject))
    {
        // Already owner, proceed
        DoAction();
    }
    else
    {
        // Request ownership, wait for transfer
        _pendingAction = true;
        Networking.SetOwner(Networking.LocalPlayer, gameObject);
    }
}

public override void OnOwnershipTransferred(VRCPlayerApi player)
{
    if (player.isLocal && _pendingAction)
    {
        _pendingAction = false;
        DoAction();
    }
}

private void DoAction()
{
    // Modify synced variables here
    RequestSerialization();
}
```

---

### Late Joiner State Issues

**Problem:** Late joiners do not see the correct state.

**Solution:**
```csharp
public override void OnPlayerJoined(VRCPlayerApi player)
{
    // Only owner needs to sync
    if (Networking.IsOwner(gameObject))
    {
        RequestSerialization();
    }
}

// Or use Start() for initial state
void Start()
{
    // This runs after OnDeserialization for late joiners
    ApplyState();
}
```

---

## NetworkCallable Issues (SDK 3.8.1+)

### "Method 'X' is not network callable"

**Symptoms:**
```
Method 'X' cannot be called as a network event
```

**Causes:**
1. Missing `[NetworkCallable]` attribute
2. Method is not `public`
3. Method is `static`, `virtual`, or `override`
4. Method has more than 8 parameters

**Solution:**
```csharp
// WRONG
public void MyMethod(int value) { } // Missing attribute

private void MyMethod(int value) { } // Private

// CORRECT
[NetworkCallable]
public void MyMethod(int value) { }
```

---

### NetworkCallable Parameters Not Received

**Symptoms:** Parameters arrive as default values (0, null, etc.)

**Causes:**
1. Parameter type is not syncable
2. Rate limit exceeded
3. SDK version mismatch

**Checklist:**
1. Verify parameter types are syncable (int, float, string, Vector3, etc.)
2. Check rate limits (default 5/sec, max 100/sec)
3. Ensure all clients are on SDK 3.8.1+

```csharp
// WRONG - VRCPlayerApi is not syncable
[NetworkCallable]
public void SetTarget(VRCPlayerApi player) { }

// CORRECT - Use player ID instead
[NetworkCallable]
public void SetTarget(int playerId) { }
```

---

### NetworkCallable Rate Limit Exceeded

**Symptoms:** Events are dropped and do not reach all clients

**Solution:**
```csharp
// Increase rate limit (max 100/sec)
[NetworkCallable(100)]
public void HighFrequencyEvent(float value) { }

// Or throttle on sender side
private float lastSendTime;
private const float SEND_INTERVAL = 0.1f;

public void SendIfReady(int value)
{
    if (Time.time - lastSendTime < SEND_INTERVAL) return;
    lastSendTime = Time.time;
    SendCustomNetworkEvent(NetworkEventTarget.All, nameof(MyEvent), value);
}
```

---

## Persistence Issues (SDK 3.7.4+)

### PlayerData Not Loading

**Symptoms:** `TryGet` always returns false, data appears empty

**Causes:**
1. Accessing before `OnPlayerRestored`
2. Key does not exist
3. Wrong player reference

**Solution:**
```csharp
private bool dataReady = false;

public override void OnPlayerRestored(VRCPlayerApi player)
{
    if (!player.isLocal) return;
    dataReady = true;

    // NOW safe to access
    if (PlayerData.TryGetInt(player, "score", out int score))
    {
        Debug.Log($"Loaded score: {score}");
    }
}

public void SaveScore(int score)
{
    if (!dataReady)
    {
        Debug.LogWarning("Data not ready!");
        return;
    }
    PlayerData.SetInt(Networking.LocalPlayer, "score", score);
}
```

---

### PlayerData Not Saving

**Symptoms:** Data does not persist across sessions

**Causes:**
1. Writing to wrong player (not local player)
2. Exceeding storage limit (100 KB)
3. Key name too long (max 128 characters)

**Solution:**
```csharp
// WRONG - Trying to write to other player's data
PlayerData.SetInt(otherPlayer, "score", 100); // Will fail silently

// CORRECT - Write to local player only
PlayerData.SetInt(Networking.LocalPlayer, "score", 100);

// Debug storage usage
string[] keys = PlayerData.GetKeys(Networking.LocalPlayer);
Debug.Log($"Using {keys.Length} keys");
```

---

### OnPlayerRestored Not Firing

**Symptoms:** Event is not called, data does not load

**Causes:**
1. VRC Enable Persistence not enabled on UdonBehaviour
2. Script not present in scene at load time
3. Player data is corrupted

**Solution:**
1. Check the "VRC Enable Persistence" checkbox in Inspector
2. Ensure the script is active in the scene hierarchy
3. Test with a new instance (no saved data)

---

## Dynamics Issues (SDK 3.10.0+)

### OnContactEnter Not Firing

**Symptoms:** Contact events not triggering at all

**Causes:**
1. UdonBehaviour not on the same GameObject as the Contact Receiver
2. Content types do not match
3. Allow Self/Allow Others is disabled

**Checklist:**
1. Ensure VRC Contact Receiver and UdonBehaviour are on the same GameObject
2. Verify Sender's content types match Receiver's allowed types
3. Check Allow Self/Allow Others settings (applies to avatar contacts only)

```csharp
// Verify receiver is on this GameObject
void Start()
{
    VRCContactReceiver receiver = GetComponent<VRCContactReceiver>();
    if (receiver == null)
    {
        Debug.LogError("No VRCContactReceiver on this GameObject!");
    }
}
```

---

### Contact Events Firing Too Frequently

**Symptoms:** OnContactEnter called repeatedly, log spam

**Causes:**
1. Multiple colliders on the Sender
2. Contacts rapidly entering and exiting
3. No debounce logic

**Solution:**
```csharp
private float lastContactTime;
private const float DEBOUNCE = 0.1f;

public override void OnContactEnter(ContactEnterInfo info)
{
    if (Time.time - lastContactTime < DEBOUNCE) return;
    lastContactTime = Time.time;

    // Handle contact
}
```

---

### PhysBone Grab Not Working

**Symptoms:** Cannot grab PhysBone, events do not fire

**Causes:**
1. Grabbing is disabled on VRC Phys Bone component
2. Player's hand is too far from grab point
3. Grab radius is too small

**Solution:**
1. Verify "Allow Grabbing" on VRC Phys Bone
2. Increase "Grab Movement" value
3. Test grab radius with different values

---

### Contact/PhysBone Player Is Null

**Symptoms:** `info.player` is null when accessed

**Cause:** Contact is from a world object, not from an avatar

**Solution:**
```csharp
public override void OnContactEnter(ContactEnterInfo info)
{
    if (info.isAvatar)
    {
        // From avatar - player is valid
        if (info.player != null && info.player.IsValid())
        {
            Debug.Log($"Contact from: {info.player.displayName}");
        }
    }
    else
    {
        // From world object - player is null
        Debug.Log("Contact from world object");
    }
}
```

---

## Editor Issues

### UdonSharpBehaviour Displays as UdonBehaviour in Inspector

**Cause:** Proxy system not properly synchronized.

**Solution:**

1. **Reimport the script:**
   - Right-click the `.cs` file -> Reimport

2. **Force sync:**
   - Click the UdonBehaviour component
   - Three-dot menu -> "Refresh UdonSharp Component"

3. **Restart Unity if unresolved**

---

### Changes Not Saved on Prefab

**Cause:** UdonSharp uses a proxy system, and changes to the proxy are not auto-saved.

**Solution:**
```csharp
#if UNITY_EDITOR
// In custom editor or after programmatic changes
UdonSharpEditorUtility.CopyProxyToUdon(behaviour);
EditorUtility.SetDirty(behaviour);
#endif
```

---

### "The associated script cannot be loaded"

**Causes:**
1. Script has compile errors
2. Script GUID mismatch
3. UdonSharpProgramAsset is missing

**Solution:**
1. Fix all compile errors
2. Remove the UdonBehaviour and re-add the UdonSharpBehaviour
3. Check the Console for detailed error messages

---

## Performance Issues

### FPS Drop from Many UdonBehaviours

**Checklist:**

1. **Disable Update() when not needed:**
```csharp
// Don't do this
void Update()
{
    if (!isActive) return;
    // Processing
}

// Do this instead
public void Activate()
{
    enabled = true;
}

public void Deactivate()
{
    enabled = false;
}

void Update()
{
    // Only runs when enabled
}
```

2. **Reduce cross-script calls:**
```csharp
// Cross-script calls have ~1.5x overhead
// Use partial classes for large scripts instead
```

3. **Cache component references:**
```csharp
// Wrong - GetComponent every frame
void Update()
{
    GetComponent<Renderer>().material.color = newColor;
}

// Correct - Cache in Start()
private Renderer _renderer;

void Start()
{
    _renderer = GetComponent<Renderer>();
}

void Update()
{
    _renderer.material.color = newColor;
}
```

4. **Use spatial partitioning:**
   - Only process objects near players
   - Use trigger zones to activate/deactivate

---

### Network Bandwidth Exceeded

**Symptoms:**
- "Network rate limited" warnings
- Sync delays for all players

**Solution:**

1. **Reduce sync frequency:**
```csharp
// Don't sync every frame
private float _lastSyncTime;
private const float SYNC_INTERVAL = 0.1f; // 10 times per second

void Update()
{
    if (Time.time - _lastSyncTime > SYNC_INTERVAL)
    {
        RequestSerialization();
        _lastSyncTime = Time.time;
    }
}
```

2. **Use smaller data types:**
```csharp
// byte = 1 byte, int = 4 bytes
[UdonSynced] private byte smallValue; // 0-255 range

// short = 2 bytes
[UdonSynced] private short mediumValue; // -32768 to 32767
```

3. **Use Continuous sync mode for smoothly changing values:**
```csharp
[UdonBehaviourSyncMode(BehaviourSyncMode.Continuous)]
public class SmoothSync : UdonSharpBehaviour
{
    [UdonSynced(UdonSyncMode.Smooth)] // Interpolated locally
    private Vector3 position;
}
```

---

## Common Pitfalls

### Start() Not Called on Inactive Objects

**Problem:**
```csharp
// Inactive GameObjects do not call Start()
public class BrokenGimmick : UdonSharpBehaviour
{
    private AudioSource audioSource;

    void Start()
    {
        // This is never reached if the GameObject is inactive!
        audioSource = GetComponent<AudioSource>();
    }

    public void PlaySound()
    {
        audioSource.Play(); // NullReferenceException!
    }
}
```

**Symptoms:**
- Gimmick is placed in an inactive state
- NullReferenceException occurs after activation
- "Should work but doesn't" situation

**Solution:**
```csharp
// OnEnable + initialization flag pattern
public class RobustGimmick : UdonSharpBehaviour
{
    private AudioSource audioSource;
    private bool _initialized = false;

    void OnEnable()
    {
        Initialize();
    }

    void Start()
    {
        Initialize();
    }

    private void Initialize()
    {
        if (_initialized) return;
        _initialized = true;

        audioSource = GetComponent<AudioSource>();
    }

    public void PlaySound()
    {
        Initialize(); // Guard against being called externally first
        if (audioSource != null)
        {
            audioSource.Play();
        }
    }
}
```

**Situations where this occurs:**
- Gimmicks placed inactive for performance optimization
- Conditionally displayed UI or objects
- Pooled objects (Object Pooling)
- Gimmicks activated by triggers

---

### Field Initializers Not Working

**Problem:**
```csharp
// This doesn't work as expected
public int maxHealth = 100; // Serialized value from Inspector wins
```

**Solution:**
```csharp
// Use Start() or explicit initialization
private int _maxHealth;

void Start()
{
    if (_maxHealth == 0)
    {
        _maxHealth = 100;
    }
}
```

---

### GetComponent Returns Proxy Instead of UdonSharpBehaviour

**Problem:**
```csharp
// Returns UdonBehaviour, not your type
var myScript = other.GetComponent<MyScript>();
```

**Solution (Runtime):**
```csharp
// Cast works at runtime in VRChat
var myScript = (MyScript)other.GetComponent(typeof(UdonBehaviour));
```

**Solution (Editor):**
```csharp
#if UNITY_EDITOR
var myScript = other.GetUdonSharpComponent<MyScript>();
#else
var myScript = (MyScript)other.GetComponent(typeof(UdonBehaviour));
#endif
```

---

### Struct Modifications Not Persisting

**Problem:**
```csharp
transform.position.x = 5; // Doesn't work!
```

**Solution:**
```csharp
// Assign full struct
Vector3 pos = transform.position;
pos.x = 5;
transform.position = pos;
```

---

### Cannot Cancel SendCustomEventDelayedSeconds

**Problem:** No built-in way to cancel delayed events.

**Solution:**
```csharp
private bool _shouldExecute = true;

public void ScheduleAction()
{
    _shouldExecute = true;
    SendCustomEventDelayedSeconds(nameof(DelayedAction), 5f);
}

public void CancelAction()
{
    _shouldExecute = false;
}

public void DelayedAction()
{
    if (!_shouldExecute) return;
    // Do action
}
```

---

### VRCPlayerApi Becomes Invalid

**Problem:** Holding a `VRCPlayerApi` reference, but the player has left.

**Solution:**
```csharp
// Wrong - Storing reference
private VRCPlayerApi _targetPlayer;

// Correct - Store ID, get player when needed
private int _targetPlayerId = -1;

public void SetTarget(VRCPlayerApi player)
{
    _targetPlayerId = player.playerId;
}

public VRCPlayerApi GetTarget()
{
    if (_targetPlayerId < 0) return null;

    VRCPlayerApi player = VRCPlayerApi.GetPlayerById(_targetPlayerId);
    if (player == null || !player.IsValid())
    {
        _targetPlayerId = -1;
        return null;
    }
    return player;
}
```

---

## Debugging Techniques

### Logging Best Practices

```csharp
// Use consistent format
private void Log(string message)
{
    Debug.Log($"[{GetType().Name}:{gameObject.name}] {message}");
}

// Conditional logging
[SerializeField] private bool _debugMode = false;

private void LogDebug(string message)
{
    if (_debugMode)
    {
        Debug.Log($"[DEBUG:{gameObject.name}] {message}");
    }
}
```

### State Visualization

```csharp
// Show state in world using TextMeshPro
public TextMeshProUGUI debugText;

void Update()
{
    if (debugText != null)
    {
        debugText.text = $"State: {_currentState}\n" +
                        $"Owner: {Networking.GetOwner(gameObject)?.displayName}\n" +
                        $"IsLocal: {Networking.IsOwner(gameObject)}";
    }
}
```

### Network Debugging

```csharp
public override void OnPreSerialization()
{
    LogDebug($"Sending: value={_syncedValue}");
}

public override void OnDeserialization()
{
    LogDebug($"Received: value={_syncedValue}");
}

public override void OnOwnershipTransferred(VRCPlayerApi player)
{
    LogDebug($"Ownership -> {player.displayName}");
}
```

---

## Quick Reference: Error -> Solution

| Error | Quick fix |
|-------|-----------|
| "does not support X" | Check constraints.md for alternative |
| NullReferenceException | Add null checks, validate Inspector refs |
| Method not found | Make method public, remove parameters |
| Variables not syncing | SetOwner -> change -> RequestSerialization |
| FieldChangeCallback silent | Use property setter locally, check nameof() |
| Heap out of memory | Reuse arrays, avoid string concat in loops |
| Proxy issues | Reimport script, refresh component |
| Low FPS | Disable unused Update(), cache components |
| **NetworkCallable not working** | Add `[NetworkCallable]`, make public |
| **PlayerData empty** | Wait for `OnPlayerRestored` first |
| **OnContactEnter not firing** | UdonBehaviour must be on same GameObject |
| **Contact player is null** | Check `info.isAvatar` before accessing |

---

## Resources

- [Official UdonSharp Docs](https://udonsharp.docs.vrchat.com/)
- [VRChat Creator Docs](https://creators.vrchat.com/worlds/udon/)
- [UdonSharp GitHub Issues](https://github.com/vrchat-community/UdonSharp/issues)
- [VRChat Forums](https://ask.vrchat.com/) - Q&A, solutions
- [VRChat Canny](https://feedback.vrchat.com/) - Bug reports, known issues

---

## Investigation Steps for Unknown Errors

For errors not covered in this document, follow these investigation steps:

### Step 1: Search Official Docs (WebSearch)

```
WebSearch: "error message or keyword site:creators.vrchat.com"
```

### Step 2: Search VRChat Forums (WebSearch)

```
WebSearch:
  query: "error message site:ask.vrchat.com"
  allowed_domains: ["ask.vrchat.com"]
```

Look for solutions from community members who encountered the same issue.

### Step 3: Search Canny (Known Bugs)

```
WebSearch:
  query: "error message site:feedback.vrchat.com"
  allowed_domains: ["feedback.vrchat.com"]
```

Check whether VRChat officially recognizes the bug and if workarounds exist.

### Step 4: Search GitHub Issues

```
WebSearch:
  query: "error message site:github.com/vrchat-community/UdonSharp"
  allowed_domains: ["github.com"]
```

Check for UdonSharp-specific bugs and fix status.

### Search Tips

| Technique | Example |
|------------|-----|
| Exact match | `"The type or namespace could not be found"` |
| SDK version filter | `SDK 3.10 error` |
| Resolved filter | `solved` or check Canny status |
| Date filter | Prioritize latest info (old solutions may not work) |
