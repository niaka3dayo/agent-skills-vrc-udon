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
- [VRCStation + Trigger Detection Issues](#vrcstation--trigger-detection-issues)
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

## VRCStation + Trigger Detection Issues

When a player sits in a VRCStation, the **PlayerLocal (Layer 10) capsule collider is effectively disabled**. This causes `OnPlayerTriggerEnter`, `OnPlayerTriggerExit`, and `OnPlayerTriggerStay` to **not fire** for seated players.

This is a [known unresolved issue since 2019](https://vrchat.canny.io/sdk-bug-reports/p/playerlocal-collision-should-remain-on-players-in-stations). No SDK version between 3.7.0 and 3.10.2 has fixed it.

### Symptoms

| Symptom | Likely Cause |
|---------|-------------|
| Trigger zone works for walking players but not seated | PlayerLocal collider disabled in station |
| OnPlayerTriggerExit fires when player sits down inside zone | Collider state change triggers exit event |
| Area effects don't activate when avatar station moves into zone | Same root cause |

---

### Workaround 1: Immobilize Station + Static Zone Check (Recommended)

For stations with `PlayerMobility = Immobilize`, the seated position is fixed. Compare the station Transform position to the zone Bounds at seating time. No polling is needed.

> **Note:** This script tracks a single seated player. Attach one instance per VRCStation.
> For tracking multiple stations, use the polling approach (Workaround 2) or instantiate
> one script per station.

```csharp
using UdonSharp;
using UnityEngine;
using VRC.SDKBase;

[UdonBehaviourSyncMode(BehaviourSyncMode.None)]
public class StationZoneCheckStatic : UdonSharpBehaviour
{
    [Header("References")]
    [SerializeField] private Collider zoneCollider;
    [SerializeField] private VRCStation station;

    private bool _isPlayerInZone = false;
    private int _seatedPlayerId = -1;

    public override void OnStationEntered(VRCPlayerApi player)
    {
        if (!Utilities.IsValid(player)) return;

        _seatedPlayerId = player.playerId;

        Bounds bounds = zoneCollider.bounds;
        // VRCStation inherits Component; explicit cast needed for UdonSharp .transform access
        Vector3 stationPosition = ((Component)station).transform.position;

        if (bounds.Contains(stationPosition))
        {
            _isPlayerInZone = true;
            OnPlayerEnteredZone(player);
        }
    }

    public override void OnStationExited(VRCPlayerApi player)
    {
        if (!Utilities.IsValid(player)) return;

        if (_isPlayerInZone)
        {
            _isPlayerInZone = false;
            OnPlayerExitedZone(player);
        }
        _seatedPlayerId = -1;
    }

    public override void OnPlayerLeft(VRCPlayerApi player)
    {
        if (!Utilities.IsValid(player)) return;

        // OnStationExited may NOT fire when a seated player leaves
        if (player.playerId == _seatedPlayerId)
        {
            if (_isPlayerInZone)
            {
                _isPlayerInZone = false;
            }
            _seatedPlayerId = -1;
        }
    }

    private void OnPlayerEnteredZone(VRCPlayerApi player)
    {
        Debug.Log($"[StationZoneCheck] {player.displayName} entered zone (seated)");
    }

    private void OnPlayerExitedZone(VRCPlayerApi player)
    {
        Debug.Log($"[StationZoneCheck] {player.displayName} exited zone (unseated)");
    }
}
```

---

### Workaround 2: Position Polling for Mobile Stations

For stations that can move (avatar stations, moving platforms), poll seated player positions periodically. This approach checks every 0.5 seconds instead of every frame to reduce overhead.

```csharp
using UdonSharp;
using UnityEngine;
using VRC.SDKBase;

[UdonBehaviourSyncMode(BehaviourSyncMode.None)]
public class StationZoneCheckPolling : UdonSharpBehaviour
{
    [Header("References")]
    [SerializeField] private Collider zoneCollider;

    [Header("Settings")]
    [SerializeField] private int maxTrackedPlayers = 40;
    [SerializeField] private float pollInterval = 0.5f;

    private int[] _seatedPlayerIds;
    private bool[] _isInZone;
    private int _seatedCount = 0;
    private float _lastPollTime = 0f;

    void Start()
    {
        _seatedPlayerIds = new int[maxTrackedPlayers];
        _isInZone = new bool[maxTrackedPlayers];
    }

    public override void OnStationEntered(VRCPlayerApi player)
    {
        if (!Utilities.IsValid(player)) return;
        if (_seatedCount >= maxTrackedPlayers) return;

        // Avoid duplicates
        for (int i = 0; i < _seatedCount; i++)
        {
            if (_seatedPlayerIds[i] == player.playerId) return;
        }

        _seatedPlayerIds[_seatedCount] = player.playerId;
        _isInZone[_seatedCount] = false;
        _seatedCount++;
    }

    public override void OnStationExited(VRCPlayerApi player)
    {
        if (!Utilities.IsValid(player)) return;
        RemoveSeatedPlayer(player.playerId, player);
    }

    public override void OnPlayerLeft(VRCPlayerApi player)
    {
        if (!Utilities.IsValid(player)) return;
        RemoveSeatedPlayer(player.playerId, null);
    }

    private void RemoveSeatedPlayer(int playerId, VRCPlayerApi player)
    {
        for (int i = 0; i < _seatedCount; i++)
        {
            if (_seatedPlayerIds[i] == playerId)
            {
                if (_isInZone[i])
                {
                    _isInZone[i] = false;
                    if (Utilities.IsValid(player))
                    {
                        OnPlayerExitedZone(player);
                    }
                }

                // Swap with last element
                _seatedCount--;
                _seatedPlayerIds[i] = _seatedPlayerIds[_seatedCount];
                _isInZone[i] = _isInZone[_seatedCount];
                return;
            }
        }
    }

    void Update()
    {
        if (_seatedCount == 0) return;
        if (Time.time - _lastPollTime < pollInterval) return;
        _lastPollTime = Time.time;

        Bounds bounds = zoneCollider.bounds;

        for (int i = 0; i < _seatedCount; i++)
        {
            VRCPlayerApi player = VRCPlayerApi.GetPlayerById(_seatedPlayerIds[i]);
            if (!Utilities.IsValid(player))
            {
                // Player left without event — clean up
                _seatedCount--;
                _seatedPlayerIds[i] = _seatedPlayerIds[_seatedCount];
                _isInZone[i] = _isInZone[_seatedCount];
                i--;
                continue;
            }

            bool currentlyInZone = bounds.Contains(player.GetPosition());

            if (currentlyInZone && !_isInZone[i])
            {
                _isInZone[i] = true;
                OnPlayerEnteredZone(player);
            }
            else if (!currentlyInZone && _isInZone[i])
            {
                _isInZone[i] = false;
                OnPlayerExitedZone(player);
            }
        }
    }

    private void OnPlayerEnteredZone(VRCPlayerApi player)
    {
        Debug.Log($"[StationZonePoll] {player.displayName} entered zone");
    }

    private void OnPlayerExitedZone(VRCPlayerApi player)
    {
        Debug.Log($"[StationZonePoll] {player.displayName} exited zone");
    }
}
```

---

### Workaround 3: Follow-Target Collider

When neither static bounds check nor position polling is suitable — e.g., avatar stations on moving platforms where the zone itself also moves, or when you need standard Unity trigger events (`OnTriggerEnter`/`OnTriggerExit`) rather than manual polling.

**Concept:** Spawn or enable a hidden GameObject with a trigger collider that follows the seated player's position every frame. This "proxy collider" enters trigger zones on behalf of the seated player, restoring normal trigger-based detection.

> **Note:** This script manages a single seated player. Attach one instance per VRCStation.
> The trigger zone's own UdonBehaviour receives standard `OnTriggerEnter`/`OnTriggerExit`
> from the proxy collider.

```csharp
using UdonSharp;
using UnityEngine;
using VRC.SDKBase;

/// <summary>
/// Enables a hidden trigger collider that follows the seated player every frame.
/// The proxy enters trigger zones on behalf of the player, restoring normal
/// OnTriggerEnter / OnTriggerExit detection while the player is seated.
///
/// Setup:
///   1. Create a child GameObject with a trigger Collider (e.g., SphereCollider).
///   2. Place that collider on a layer that interacts with your trigger zone layer
///      (avoid PlayerLocal — it is disabled during station use).
///   3. Assign the child's Collider to followCollider in the Inspector.
///   4. Disable the child GameObject by default (the script enables it on seat).
/// </summary>
[UdonBehaviourSyncMode(BehaviourSyncMode.None)]
public class PlayerFollowCollider : UdonSharpBehaviour
{
    [Header("References")]
    [Tooltip("Trigger collider on a child GameObject (disabled by default).")]
    [SerializeField] private Collider followCollider;

    private VRCPlayerApi _trackedPlayer;
    private bool _isTracking = false;

    public override void OnStationEntered(VRCPlayerApi player)
    {
        if (!Utilities.IsValid(player)) return;

        _trackedPlayer = player;
        _isTracking = true;

        // Place at current position before enabling to avoid a frame of stale position
        followCollider.transform.position = player.GetPosition();
        followCollider.gameObject.SetActive(true);
    }

    public override void OnStationExited(VRCPlayerApi player)
    {
        if (!Utilities.IsValid(player)) return;

        StopTracking();
    }

    public override void OnPlayerLeft(VRCPlayerApi player)
    {
        if (!Utilities.IsValid(player)) return;

        // OnStationExited may NOT fire when a seated player leaves the instance
        if (_isTracking && _trackedPlayer.playerId == player.playerId)
        {
            StopTracking();
        }
    }

    void Update()
    {
        if (!_isTracking) return;

        if (!Utilities.IsValid(_trackedPlayer))
        {
            // Player reference became invalid — clean up
            StopTracking();
            return;
        }

        followCollider.transform.position = _trackedPlayer.GetPosition();
    }

    private void StopTracking()
    {
        _isTracking = false;
        _trackedPlayer = null;
        followCollider.gameObject.SetActive(false);
    }
}
```

**Key considerations:**
- The follow collider **must not** be on the PlayerLocal layer (Layer 10) — that layer is disabled for seated players. Use a dedicated interaction layer.
- Always validate with `Utilities.IsValid()` before accessing player data.
- Performance: one moving collider per seated player is lightweight compared to polling multiple players against bounds.
- Cleanup on `OnPlayerLeft` is essential — `OnStationExited` is not guaranteed when a player disconnects.
- The trigger zone's UdonBehaviour receives standard `OnTriggerEnter`/`OnTriggerExit` from the proxy collider, so existing trigger logic works without modification.

---

### OnPlayerLeft Failsafe (Important)

`OnStationExited` may **not fire** when a seated player leaves the instance. Always pair station tracking with `OnPlayerLeft` cleanup to prevent stale data.

```csharp
public override void OnPlayerLeft(VRCPlayerApi player)
{
    if (!Utilities.IsValid(player)) return;

    // Clean up any station-related state for this player
    if (player.playerId == _seatedPlayerId)
    {
        _seatedPlayerId = -1;
        _isPlayerInZone = false;
    }
}
```

---

### Station Disable Behavior

| Action | Effect |
|--------|--------|
| Disable the station's **Collider** | Prevents new players from sitting, but does **not** eject seated players |
| Disable the station's **GameObject** | Force ejects the seated player (`station.gameObject.SetActive(false)`) |
| Call `station.ExitStation(player)` | Only works for the **local player** (`Networking.LocalPlayer`) |

---

### See Also

- [events.md — OnStationEntered/OnStationExited](events.md#station-events) — Station event signatures and usage
- [patterns-core.md — Trigger Zone Detection](patterns-core.md#trigger-zone) — Standard trigger zone pattern for walking players

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

**Symptoms:**
- Inspector shows "The associated script cannot be loaded" on UdonBehaviour
- UdonBehaviour component shows no linked program
- Script compiles in IDE but doesn't run as Udon in Unity

**Causes:**
1. Script has compile errors
2. Script GUID mismatch (meta file conflict)
3. **UdonSharpProgramAsset (`.asset`) is missing** — most common when scripts are created by AI or outside Unity's "Create > U# Script" menu

**Solution:**
1. Fix all compile errors first
2. Check the Console for detailed error messages
3. Remove the UdonBehaviour and re-add the UdonSharpBehaviour
4. **If the `.asset` file is missing**: Install `UdonSharpProgramAssetAutoGenerator.cs` (from `assets/templates/`) into your `Assets/Editor/` folder. This auto-generates `.asset` files for new UdonSharp scripts on import. See [Editor Scripting Reference: UdonSharpProgramAsset Auto-Generation](editor-scripting.md#udonsharpprogramasset-auto-generation) for details

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
| **Trigger not firing for seated players** | PlayerLocal collider disabled in station — use position check workaround |
| **.asset missing / script not loaded** | Install `UdonSharpProgramAssetAutoGenerator.cs` in `Assets/Editor/` |

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

## See Also

- [constraints.md](constraints.md) - Supported and unsupported C# features — the root cause of many compile errors
- [networking.md](networking.md) - Ownership patterns and sync troubleshooting reference

### Search Tips

| Technique | Example |
|------------|-----|
| Exact match | `"The type or namespace could not be found"` |
| SDK version filter | `SDK 3.10 error` |
| Resolved filter | `solved` or check Canny status |
| Date filter | Prioritize latest info (old solutions may not work) |
