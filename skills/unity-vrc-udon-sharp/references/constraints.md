# UdonSharp Constraints Reference

Complete reference of C# features and their availability in UdonSharp, including SDK version availability,
compiler behavior details, and annotated code examples.

**Supported SDK Versions**: 3.7.1 - 3.10.3

> For the quick-reference checklist and code generation rules, see `rules/udonsharp-constraints.md`.

---

## Compiler Behavior Overview

UdonSharp transpiles C# source to Udon Assembly, which runs on VRChat's UdonVM. This has several implications:

- **Static analysis at compile time**: Blocked features cause compile errors, not runtime exceptions.
- **Field initializers run at compile time**: Values are baked into the serialized asset, not evaluated at scene load.
- **Struct semantics differ**: UdonVM passes structs by value; mutating methods on structs return new values and do not modify the original.
- **Method lookup cost**: UdonVM performs string-based method lookup; public methods are visible to Udon's event system and incur slightly higher overhead.
- **Checked arithmetic**: UdonVM runs with overflow checking enabled by default. Operations that would silently wrap in standard C# will behave as checked.
- **No JIT**: There is no just-in-time compilation. All method dispatch is interpreted.

---

## Supported Features

### Data Types

| Type | Status | SDK Added | Notes |
|------|--------|-----------|-------|
| `int`, `float`, `double`, `bool` | Supported | 3.0+ | Basic value types work normally |
| `string`, `char` | Supported | 3.0+ | String interpolation (`$""`) available |
| `Vector3`, `Quaternion`, `Color` | Supported | 3.0+ | Unity struct types; see struct mutation caveat |
| `GameObject`, `Transform` | Supported | 3.0+ | Unity object types |
| `T[]` (one-dimensional arrays) | Supported | 3.0+ | Primary collection type |
| `T[,]` (multi-dimensional arrays) | Blocked | — | Use jagged arrays `T[][]` instead |
| `T[][]` (jagged arrays) | Supported | 3.0+ | Arrays of arrays |

### Control Flow

| Feature | Status | SDK Added | Notes |
|---------|--------|-----------|-------|
| `if`/`else` | Supported | 3.0+ | |
| `switch` | Supported | 3.0+ | |
| `for`, `foreach` | Supported | 3.0+ | |
| `while`, `do-while` | Supported | 3.0+ | |
| `break`, `continue`, `return` | Supported | 3.0+ | |
| Ternary operator `? :` | Supported | 3.0+ | |
| Null-coalescing `??` | Supported | 3.0+ | |
| Null-conditional `?.` | Supported | 3.0+ | |

### Methods and Properties

| Feature | Status | SDK Added | Notes |
|---------|--------|-----------|-------|
| User-defined methods | Supported | 3.0+ | Parameters and return values work |
| `out`/`ref` parameters | Supported | 3.0+ | |
| `params` keyword | Supported | 3.0+ | Variable arguments |
| Extension methods | Supported | 1.0+ | Works in UdonSharp 1.0+; static methods also valid |
| Properties (get/set) | Supported | 3.0+ | |
| Virtual methods | Supported | 3.0+ | For inheritance |
| `[RecursiveMethod]` | Required | 3.0+ | Attribute required for recursive calls |

### Object-Oriented Features

| Feature | Status | SDK Added | Notes |
|---------|--------|-----------|-------|
| `UdonSharpBehaviour` inheritance | Supported | 3.0+ | Required base class |
| Single inheritance | Supported | 3.0+ | One base class only |
| UdonSharpBehaviour-to-UdonSharpBehaviour inheritance | Supported | 3.0+ | Can inherit from custom UdonSharpBehaviours |
| Abstract classes | Supported | 3.0+ | |
| Virtual methods | Supported | 3.0+ | For polymorphism |
| Static fields/methods | Supported | 3.0+ | |
| Partial classes | Supported | 3.0+ | Split class across files |
| `typeof()` | Supported | 3.0+ | |

---

## Unsupported Features

### Collections and Generics

| Feature | Status | SDK Added | Alternative |
|---------|--------|-----------|-------------|
| `List<T>` | Blocked | — | Use `T[]` arrays or `DataList` (SDK 3.7.1+) |
| `Dictionary<T,K>` | Blocked | — | Use `DataDictionary` from VRC SDK (SDK 3.7.1+) |
| `Queue<T>`, `Stack<T>` | Blocked | — | Implement with arrays |
| `HashSet<T>` | Blocked | — | Use arrays with manual deduplication |
| Generic type parameters | Blocked | — | Use concrete types |

**DataList / DataDictionary (SDK 3.7.1+):**

> **When to use:** Prefer fixed-size `T[]` arrays for most cases — they are faster, type-safe at compile time, and work with `[UdonSynced]`. Use `DataList` / `DataDictionary` only when: (1) the collection size is truly unknown at compile time and varies at runtime, (2) you need heterogeneous value types in a single container (via `DataToken`), or (3) you are parsing JSON with `VRCJson` (which returns `DataDictionary` / `DataList` natively). Do not adopt DataList just because it feels more familiar than manual array resizing — the `ArrayUtils` helper pattern (see [patterns-utilities.md](patterns-utilities.md)) covers `Add` / `Remove` / `FindIndex` for typed arrays with no boxing overhead.

```csharp
using VRC.SDK3.Data;

// Instead of List<string>
DataList stringList = new DataList();
stringList.Add("item1");
stringList.Add("item2");
string first = stringList[0].String;
int count = stringList.Count;

// Iterate a DataList
for (int i = 0; i < stringList.Count; i++)
{
    Debug.Log(stringList[i].String);
}

// Instead of Dictionary<string, int>
DataDictionary dict = new DataDictionary();
dict["key1"] = 100;
dict["key2"] = 200;
int value = dict["key1"].Int;

// Check key existence
if (dict.ContainsKey("key1"))
{
    Debug.Log("Found: " + dict["key1"].Int);
}
```

### Language Features

| Feature | Status | SDK Added | Alternative |
|---------|--------|-----------|-------------|
| `interface` | Blocked | — | Use base class or `SendCustomEvent` |
| Method overloading | Blocked | — | Use distinct method names |
| Operator overloading | Blocked | — | Use explicit methods |
| `try`/`catch`/`finally` | Blocked | — | Use defensive null checks |
| `throw` exceptions | Blocked | — | Use return values for errors |
| `async`/`await` | Blocked | — | Use `SendCustomEventDelayedSeconds` |
| `yield return` (coroutines) | Blocked | — | Use delayed events |
| Delegates | Blocked | — | Use `SendCustomEvent` |
| `Button.onClick.AddListener()` | Blocked | — | Inspector OnClick -> `SendCustomEvent` |
| Events (C# events) | Blocked | — | Use UdonSharp events |
| LINQ | Blocked | — | Use manual loops |
| Anonymous types | Blocked | — | Define explicit types |
| Lambda expressions | Blocked | — | Use named methods |
| Local functions | Blocked | — | Use private methods |
| Pattern matching | Blocked | — | Use traditional `if`/`switch` |

**Method Overloading Alternative:**

```csharp
// WRONG - overloading not supported
public void DoSomething(int value) { }
public void DoSomething(string value) { }  // Compile error

// CORRECT - use distinct names
public void DoSomethingInt(int value) { }
public void DoSomethingString(string value) { }
```

**Exception Handling Alternative (defensive programming):**

```csharp
// WRONG - try/catch not supported
try {
    ProcessData(data);
} catch (Exception e) {
    Debug.LogError(e.Message);
}

// CORRECT - guard clauses and early returns
if (data == null)
{
    Debug.LogError("[MyScript] Data is null, aborting ProcessData");
    return;
}
ProcessData(data);
```

**Async / Coroutine Alternative:**

```csharp
// WRONG - async/await and coroutines not supported
private async Task DelayedAction()
{
    await Task.Delay(2000);
    DoSomething();
}

// CORRECT - use SendCustomEventDelayedSeconds
public void TriggerDelayed()
{
    SendCustomEventDelayedSeconds(nameof(DoSomething), 2f);
}

public void DoSomething()
{
    // Called 2 seconds later
}
```

### System Namespaces

| Namespace | Status | SDK Added | Notes |
|-----------|--------|-----------|-------|
| `System.IO` | Blocked | — | Not available (security restriction) |
| `System.Net` | Blocked | — | Use `VRCStringDownloader`, `VRCImageDownloader` |
| `System.Reflection` | Blocked | — | Not available |
| `System.Threading` | Blocked | — | Not available |
| `System.Linq` | Blocked | — | Use manual loops |
| `System.Text.StringBuilder` | Available | **3.7.1** | Efficient string concatenation |
| `System.Text.RegularExpressions` | Available | **3.7.1** | Pattern matching (Regex) |
| `System.Random` | Available | **3.7.1** | Deterministic random with seed |
| `System.Type` | Available | **3.7.1** | Runtime type interaction |

**StringBuilder (SDK 3.7.1+):**

```csharp
using System.Text;

public class StringBuilderExample : UdonSharpBehaviour
{
    public void BuildPlayerList()
    {
        VRCPlayerApi[] players = new VRCPlayerApi[VRCPlayerApi.GetPlayerCount()];
        VRCPlayerApi.GetPlayers(players);

        StringBuilder sb = new StringBuilder();
        sb.Append("Players:\n");

        foreach (VRCPlayerApi player in players)
        {
            if (player != null && player.IsValid())
            {
                sb.Append("- ");
                sb.Append(player.displayName);
                sb.Append("\n");
            }
        }

        Debug.Log(sb.ToString());
    }
}
```

**Regex (SDK 3.7.1+):**

```csharp
using System.Text.RegularExpressions;

public class RegexExample : UdonSharpBehaviour
{
    public bool IsValidUsername(string username)
    {
        // 3-16 characters, alphanumeric and underscores only
        Regex pattern = new Regex(@"^[a-zA-Z0-9_]{3,16}$");
        return pattern.IsMatch(username);
    }
}
```

**System.Random with seed (SDK 3.7.1+):**

```csharp
public class SeededRandom : UdonSharpBehaviour
{
    private System.Random _rng;

    void Start()
    {
        // Seed with player count for deterministic-per-session results
        _rng = new System.Random(VRCPlayerApi.GetPlayerCount());
    }

    public int NextInt(int minInclusive, int maxExclusive)
    {
        return _rng.Next(minInclusive, maxExclusive);
    }
}
```

### Unsafe and Low-Level Features

| Feature | Status | SDK Added | Notes |
|---------|--------|-----------|-------|
| `unsafe` keyword | Blocked | — | Memory safety restriction |
| Pointers (`*`, `&`) | Blocked | — | Not available |
| `fixed` statement | Blocked | — | Not available |
| `stackalloc` | Blocked | — | Not available |

---

## Behavioral Differences from Standard C#

### Checked Arithmetic (Numeric Overflow)

UdonVM runs with overflow checking enabled. Operations that silently wrap in unchecked C# will behave as if in a `checked` block:

```csharp
// In standard C# (unchecked), this wraps to int.MinValue
int max = int.MaxValue;
int overflow = max + 1;
// In UdonVM: overflow is detected (avoid relying on wrap-around behavior)

// Safe pattern: guard against overflow explicitly
if (value < int.MaxValue)
{
    value++;
}
```

### Struct Method Mutation

UdonVM passes structs by value. Methods that appear to mutate a struct (like `Normalize()`) actually return a new value and leave the original unchanged:

```csharp
// WRONG - Normalize() doesn't change v
Vector3 v = new Vector3(3, 4, 0);
v.Normalize();
Debug.Log(v); // Still (3, 4, 0)!

// CORRECT - use the property form, which returns a new value
Vector3 v = new Vector3(3, 4, 0);
v = v.normalized;
Debug.Log(v); // (0.6, 0.8, 0)

// Same applies to other struct mutating patterns:
Quaternion q = transform.rotation;
q.Normalize();           // WRONG - q is not normalized
q = q.normalized;        // CORRECT
```

### Field Initializers Are Compile-Time

Field initializers are evaluated when UdonSharp compiles the script, not at scene load or instance creation. The baked value is stored in the serialized asset.

```csharp
// WRONG - Random.Range is evaluated once at compile time
// All instances of this script get the same value
private int randomValue = Random.Range(0, 100);

// CORRECT - evaluate at runtime in Start()
private int randomValue;

void Start()
{
    randomValue = Random.Range(0, 100); // Different each play
}
```

**Lazy Initialization Pattern** (for objects that may be inactive at Start):

```csharp
private Transform _target;
private bool _initialized;

private void EnsureInit()
{
    if (_initialized) return;
    var go = GameObject.Find("Target");
    if (go != null) _target = go.transform;
    _initialized = true;
}

public void DoWork()
{
    EnsureInit();
    if (_target == null) return;
    // use _target
}
```

### Array Operations

Standard array utilities work as expected, but note that `Array.Resize` creates a new array:

```csharp
// Array.Resize creates a new array (ref parameter reflects this)
int[] arr = new int[5];
System.Array.Resize(ref arr, 10);
// arr now references the new 10-element array

// Array.Copy works as expected
int[] source = new int[] { 1, 2, 3 };
int[] dest = new int[3];
System.Array.Copy(source, dest, 3);
```

---

## GetComponent and SDK Version Notes

### Pre-3.8: Cast Syntax Required

Before SDK 3.8, generic `GetComponent<UdonBehaviour>()` was not exposed:

```csharp
// WRONG (all SDK versions for raw UdonBehaviour)
UdonBehaviour ub = GetComponent<UdonBehaviour>();

// CORRECT - cast syntax
UdonBehaviour ub = (UdonBehaviour)GetComponent(typeof(UdonBehaviour));
```

### SDK 3.8+: Generic Works for UdonSharpBehaviour Inheritance

SDK 3.8 added proper generic `GetComponent<T>()` support for types that inherit from `UdonSharpBehaviour`:

```csharp
// CORRECT (SDK 3.8+) - works for direct UdonSharpBehaviour subclasses
MyScript script = GetComponent<MyScript>();

// CORRECT (SDK 3.8+) - works through inheritance hierarchy
public class BaseGimmick : UdonSharpBehaviour { }
public class DerivedGimmick : BaseGimmick { }

BaseGimmick gimmick = GetComponent<BaseGimmick>();
DerivedGimmick derived = GetComponent<DerivedGimmick>();

// GetComponents (plural) also works
BaseGimmick[] all = GetComponents<BaseGimmick>();
```

---

## uGUI Button Event Registration

`Button.onClick.AddListener()` uses delegates, which are blocked. Button click events must be wired in the Unity Inspector.

```csharp
// WRONG - delegates not supported; throws at compile time
button.onClick.AddListener(() => DoSomething());
button.onClick.AddListener(DoSomething);

// CORRECT - wire in the Unity Inspector:
// 1. Select the Button GameObject
// 2. In OnClick(), click "+"
// 3. Drag the UdonBehaviour component into the object field
// 4. Select the dropdown: UdonBehaviour -> SendCustomEvent (string)
// 5. Enter the exact method name, e.g. "OnButtonClicked"

public void OnButtonClicked()
{
    // Called by the Inspector-configured OnClick event
}
```

---

## Unity Callback Override Rules

Unity lifecycle callbacks (`OnTriggerEnter`, `OnCollisionEnter`, etc.) must **not** use `override`.
VRChat network events (`OnPlayerJoined`, `OnOwnershipRequest`, etc.) **must** use `override`.

```csharp
// NG: override on Unity callback causes CS0115
public override void OnTriggerEnter(Collider other) { }

// OK: Unity callbacks without override
public void OnTriggerEnter(Collider other) { }
public void OnCollisionEnter(Collision collision) { }
public void OnParticleCollision(GameObject other) { }

// OK: VRChat events require override
public override void OnPlayerJoined(VRCPlayerApi player) { }
public override void OnPlayerLeft(VRCPlayerApi player) { }
public override void OnOwnershipRequest(VRCPlayerApi requester, VRCPlayerApi newOwner) { }
```

---

## VRChat-Specific Types

| Type | Purpose | SDK Added |
|------|---------|-----------|
| `VRCPlayerApi` | Player information and actions | 3.0+ |
| `VRCStation` | Station/seat management | 3.0+ |
| `VRCPickup` | Pickup object handling | 3.0+ |
| `VRCAvatarParameterDriver` | Avatar parameter control | 3.0+ |
| `VRCUrl` | URL handling for downloads | 3.0+ |
| `DataList` | Generic-like ordered list | 3.7.1+ |
| `DataDictionary` | Generic-like key-value map | 3.7.1+ |
| `DataToken` | Type-safe data container | 3.7.1+ |

---

## Known Limitations and Caveats

### Prefab Field Changes

Changes to serialized fields on prefabs do NOT propagate to scene instances automatically. This is a Unity limitation that affects UdonSharp as well.

**Workaround**: After modifying a prefab, manually update instances or use `PrefabUtility.ApplyPrefabInstance` in editor scripts.

### Public Method Lookup Cost

Udon dispatches events (like `SendCustomEvent`) by searching public method names as strings. Having many public methods increases dispatch time. Keep methods `private` unless they need to be accessible from other UdonBehaviours or from the Inspector.

### String Sync Limit

Synced `string` fields (`[UdonSynced]`) are encoded at 2 bytes per character. There is no separate per-string character limit; the practical limit is set by the sync mode's per-serialization buffer:

- **Continuous sync**: ~200 bytes shared across all synced fields on the behaviour. A single synced string can consume the entire budget quickly (e.g., a 100-character string = 200 bytes), leaving no room for other fields.
- **Manual sync**: 280,496 bytes (~280KB) per serialization, allowing much larger strings.

For Continuous sync, keep synced strings very short or switch to Manual sync.

---

## Quick Validation Checklist

Before compiling UdonSharp code, verify:

- [ ] No `List<T>` or `Dictionary<T,K>` usage
- [ ] No `interface` declarations
- [ ] No method overloading (all methods have unique names)
- [ ] No `try`/`catch` blocks
- [ ] No `async`/`await` or `yield return`
- [ ] No LINQ queries (`.Where()`, `.Select()`, etc.)
- [ ] No lambda expressions (`=>` in variable context)
- [ ] No `System.IO` or `System.Net` usage
- [ ] All recursive methods have `[RecursiveMethod]` attribute
- [ ] Struct methods: using return values, not relying on in-place mutation
- [ ] Unity callbacks (OnTriggerEnter, etc.) do not have `override`
- [ ] VRChat event callbacks (OnPlayerJoined, etc.) do have `override`
- [ ] `Button.onClick` not used; events configured in Inspector

## Advanced Constraint Workarounds

### Object Array Pseudo-Struct (Multi-Field State Container)

UdonSharp lacks custom constructors, user-defined structs, and generics. When you need a reusable data object
that holds multiple typed fields per slot (e.g., per-pointer touch state, per-player session data), there is no
direct equivalent of a C# struct or class constructor.

> **Cross-reference**: The full pseudo-struct pattern with additional usage examples is also documented in
> [patterns-utilities.md](patterns-utilities.md).

**Workaround**: Pack multiple typed arrays into an `object[]`, then cast the whole array to an `UdonSharpBehaviour`
type. This exploits the fact that UdonVM stores UdonSharpBehaviour references as plain objects at runtime, allowing
the cast chain `(MyType)(object)objectArray` to succeed. Each index in the `object[]` represents a "field" of the
pseudo-struct, and each element is a typed array where the array index represents the slot (instance).

**Why this works**: UdonVM does not perform strict type checking on `object` casts at the level that standard CLR
does. The `UdonSharpBehaviour` type reference becomes a handle to the underlying `object[]`, which can be cast back
to access the typed arrays inside.

**Complete Example -- Multi-Pointer Touch State Container:**

```csharp
using UdonSharp;
using UnityEngine;
using UnityEngine.UI;
using VRC.SDKBase;

// The "struct" type -- the class body contains only the factory method.
// No fields are declared here; all state lives in the object[] created by New().
[AddComponentMenu("")]
[UdonBehaviourSyncMode(BehaviourSyncMode.NoVariableSync)]
public class PointerState : UdonSharpBehaviour
{
    /// <summary>
    /// Creates a new pseudo-struct with per-slot arrays for the given capacity.
    /// Each slot represents one pointer/finger that can interact simultaneously.
    /// </summary>
    public static PointerState New(int slotCount)
    {
        // Field 0: the UI element each pointer is currently touching
        Graphic[] activeGraphics = new Graphic[slotCount];
        // Field 1: world-space position where the pointer first made contact
        Vector3[] startPositions = new Vector3[slotCount];
        // Field 2: cumulative drag distance for each pointer
        float[] dragDistances = new float[slotCount];
        // Field 3: whether each slot is currently active
        bool[] isActive = new bool[slotCount];

        object[] buffer = new object[]
        {
            activeGraphics,   // index 0
            startPositions,   // index 1
            dragDistances,    // index 2
            isActive          // index 3
        };

        // Cast the object[] to the UdonSharpBehaviour type.
        // This is the key trick: UdonVM allows this reinterpret cast.
        return (PointerState)(object)buffer;
    }
}

// Typed accessors are defined as static methods in a separate UdonSharpBehaviour.
// UdonSharp does not support static classes or extension methods (this T syntax),
// so plain static methods with an explicit first parameter are used instead.
[AddComponentMenu("")]
[UdonBehaviourSyncMode(BehaviourSyncMode.NoVariableSync)]
public class PointerStateExt : UdonSharpBehaviour
{
    // --- Field 0: ActiveGraphic ---

    public static Graphic GetActiveGraphic(PointerState self, int slot)
    {
        return ((Graphic[])((object[])(object)self)[0])[slot];
    }

    public static void SetActiveGraphic(PointerState self, int slot, Graphic graphic)
    {
        ((Graphic[])((object[])(object)self)[0])[slot] = graphic;
    }

    // --- Field 1: StartPosition ---

    public static Vector3 GetStartPosition(PointerState self, int slot)
    {
        return ((Vector3[])((object[])(object)self)[1])[slot];
    }

    public static void SetStartPosition(PointerState self, int slot, Vector3 position)
    {
        ((Vector3[])((object[])(object)self)[1])[slot] = position;
    }

    // --- Field 2: DragDistance ---

    public static float GetDragDistance(PointerState self, int slot)
    {
        return ((float[])((object[])(object)self)[2])[slot];
    }

    public static void SetDragDistance(PointerState self, int slot, float distance)
    {
        ((float[])((object[])(object)self)[2])[slot] = distance;
    }

    // --- Field 3: IsActive ---

    public static bool GetIsActive(PointerState self, int slot)
    {
        return ((bool[])((object[])(object)self)[3])[slot];
    }

    public static void SetIsActive(PointerState self, int slot, bool active)
    {
        ((bool[])((object[])(object)self)[3])[slot] = active;
    }

    // --- Lifecycle Methods ---

    /// <summary>
    /// Initializes a slot when a pointer begins interaction.
    /// </summary>
    public static void InitSlot(PointerState self, int slot, Graphic graphic, Vector3 worldPosition)
    {
        ClearSlot(self, slot);
        SetActiveGraphic(self, slot, graphic);
        SetStartPosition(self, slot, worldPosition);
        SetDragDistance(self, slot, 0f);
        SetIsActive(self, slot, true);
    }

    /// <summary>
    /// Resets all fields for a slot to default values.
    /// </summary>
    public static void ClearSlot(PointerState self, int slot)
    {
        SetActiveGraphic(self, slot, null);
        SetStartPosition(self, slot, Vector3.zero);
        SetDragDistance(self, slot, 0f);
        SetIsActive(self, slot, false);
    }
}

// Usage in a manager script
public class InputManager : UdonSharpBehaviour
{
    private PointerState _pointerState;
    private const int MaxPointers = 16;

    void Start()
    {
        // Create the pseudo-struct with capacity for 16 simultaneous pointers
        _pointerState = PointerState.New(MaxPointers);
    }

    public void OnPointerDown(int pointerIndex, Graphic hitGraphic, Vector3 worldPos)
    {
        if (pointerIndex < 0 || pointerIndex >= MaxPointers) return;
        PointerStateExt.InitSlot(_pointerState, pointerIndex, hitGraphic, worldPos);
    }

    public void OnPointerUp(int pointerIndex)
    {
        if (pointerIndex < 0 || pointerIndex >= MaxPointers) return;
        if (!PointerStateExt.GetIsActive(_pointerState, pointerIndex)) return;

        float totalDrag = PointerStateExt.GetDragDistance(_pointerState, pointerIndex);
        Debug.Log($"[InputManager] Pointer {pointerIndex} released after {totalDrag:F2} units of drag");

        PointerStateExt.ClearSlot(_pointerState, pointerIndex);
    }

    public void OnPointerMove(int pointerIndex, Vector3 currentWorldPos)
    {
        if (pointerIndex < 0 || pointerIndex >= MaxPointers) return;
        if (!PointerStateExt.GetIsActive(_pointerState, pointerIndex)) return;

        Vector3 startPos = PointerStateExt.GetStartPosition(_pointerState, pointerIndex);
        float distance = Vector3.Distance(startPos, currentWorldPos);
        PointerStateExt.SetDragDistance(_pointerState, pointerIndex, distance);
    }
}
```

**Pattern Summary:**

| Element | Purpose |
|---------|---------|
| `UdonSharpBehaviour` subclass | Type identity for the pseudo-struct; holds only the `New()` factory |
| `New(int count)` static method | Factory that creates the `object[]` and casts it to the type |
| `object[]` buffer | Holds one typed array per "field" at each index |
| `(T)(object)buffer` cast | Reinterprets the `object[]` as the UdonSharpBehaviour type |
| Static methods in `PointerStateExt` | Provide typed get/set accessors with the reverse cast chain |
| `InitSlot` / `ClearSlot` | Lifecycle methods to set up and tear down per-slot state |

**Caveats:**

- **Cast chain performance**: Each accessor performs `(object) -> object[] -> T[] -> element`. This involves
  multiple unboxing steps per access. Avoid calling accessors in tight per-frame loops over large arrays.
  If performance is critical, cache the inner typed array locally:
  ```csharp
  // Cache for hot-path iteration
  float[] distances = (float[])((object[])(object)_pointerState)[2];
  for (int i = 0; i < MaxPointers; i++)
  {
      if (distances[i] > threshold) { /* ... */ }
  }
  ```
- **Debugging difficulty**: The pseudo-struct does not appear in the Unity Inspector. You cannot inspect field
  values through the normal UdonSharp variable display. Add explicit `Debug.Log` calls during development.
- **No compile-time safety on field indices**: Using integer indices (`[0]`, `[1]`, etc.) for field access is
  error-prone. Keep the mapping documented in the `New()` method comments and never access the `object[]`
  directly outside the static accessor methods.
- **Not serializable**: The pseudo-struct cannot be saved to the scene or synced over the network. It is
  purely a runtime data structure.

---

### VRCUrl Array Sync Workaround

`VRCUrl[]` arrays cannot be marked with `[UdonSynced]`. UdonSharp's sync system only supports syncing individual
`VRCUrl` fields, not arrays of them. This is a known limitation of the Udon serialization layer -- the sync
system does not handle `VRCUrl` as a syncable array element type.

**Workaround**: Declare each URL as a separate `[UdonSynced]` field (`SyncedUrl_0` through `SyncedUrl_N`), then
use `switch` statements to map a runtime index to the correct field for reading and writing. Metadata (sender
name, timestamp, content type, etc.) can be synced as a single JSON string via `VRCJson` serialization.

**Complete Example -- Synced URL List with Metadata:**

```csharp
using UdonSharp;
using UnityEngine;
using VRC.SDK3.Data;
using VRC.SDKBase;

[UdonBehaviourSyncMode(BehaviourSyncMode.Manual)]
public class SyncedUrlList : UdonSharpBehaviour
{
    private const int MaxUrls = 8;

    // Each VRCUrl must be synced individually -- arrays are not supported.
    [UdonSynced] private VRCUrl SyncedUrl_0;
    [UdonSynced] private VRCUrl SyncedUrl_1;
    [UdonSynced] private VRCUrl SyncedUrl_2;
    [UdonSynced] private VRCUrl SyncedUrl_3;
    [UdonSynced] private VRCUrl SyncedUrl_4;
    [UdonSynced] private VRCUrl SyncedUrl_5;
    [UdonSynced] private VRCUrl SyncedUrl_6;
    [UdonSynced] private VRCUrl SyncedUrl_7;

    // Metadata for all URLs synced as a single JSON string.
    // Format: [[timestamp, typeId, "senderName"], ...]
    [UdonSynced] private string SyncedMetadataJson = "[]";

    // Local cache of parsed metadata
    private DataList _metadataList;

    // Pending operation state (used when ownership transfer is in progress)
    private bool _pendingAdd = false;
    private VRCUrl _pendingAddUrl;
    private int _pendingAddType;
    private bool _pendingRemove = false;
    private int _pendingRemoveIndex;

    // --- Index-to-Field Accessor (Set) ---

    private void SetUrlAtIndex(int index, VRCUrl url)
    {
        switch (index)
        {
            case 0: SyncedUrl_0 = url; break;
            case 1: SyncedUrl_1 = url; break;
            case 2: SyncedUrl_2 = url; break;
            case 3: SyncedUrl_3 = url; break;
            case 4: SyncedUrl_4 = url; break;
            case 5: SyncedUrl_5 = url; break;
            case 6: SyncedUrl_6 = url; break;
            case 7: SyncedUrl_7 = url; break;
            default:
                Debug.LogWarning($"[SyncedUrlList] Index {index} out of range (max {MaxUrls - 1})");
                break;
        }
    }

    // --- Index-to-Field Accessor (Get) ---

    private VRCUrl GetUrlAtIndex(int index)
    {
        switch (index)
        {
            case 0: return SyncedUrl_0;
            case 1: return SyncedUrl_1;
            case 2: return SyncedUrl_2;
            case 3: return SyncedUrl_3;
            case 4: return SyncedUrl_4;
            case 5: return SyncedUrl_5;
            case 6: return SyncedUrl_6;
            case 7: return SyncedUrl_7;
            default: return VRCUrl.Empty;
        }
    }

    // --- Public API ---

    /// <summary>
    /// Adds a URL with metadata. Takes ownership, updates synced state, and requests serialization.
    /// </summary>
    public bool AddUrl(VRCUrl url, int contentType)
    {
        if (!ParseMetadata()) return false;

        if (_metadataList.Count >= MaxUrls)
        {
            Debug.LogWarning("[SyncedUrlList] URL list is full");
            return false;
        }

        if (!Networking.IsOwner(gameObject))
        {
            // Defer until ownership is confirmed
            _pendingAdd = true;
            _pendingAddUrl = url;
            _pendingAddType = contentType;
            _pendingRemove = false;
            Networking.SetOwner(Networking.LocalPlayer, gameObject);
            return true;
        }

        ExecuteAddUrl(url, contentType);
        return true;
    }

    private void ExecuteAddUrl(VRCUrl url, int contentType)
    {
        if (!ParseMetadata()) return;
        if (_metadataList.Count >= MaxUrls) return;

        // Build metadata entry: [timestamp, contentType, senderName]
        long timestamp = System.DateTimeOffset.UtcNow.ToUnixTimeMilliseconds();
        string senderName = Networking.LocalPlayer.displayName;

        DataList entry = new DataList();
        entry.Add(timestamp);
        entry.Add(contentType);
        entry.Add(senderName);

        _metadataList.Add(entry);

        // Store URL at the new index
        int newIndex = _metadataList.Count - 1;
        SetUrlAtIndex(newIndex, url);

        // Serialize metadata to JSON
        if (!SerializeMetadata()) return;

        RequestSerialization();
    }

    /// <summary>
    /// Removes a URL by index. Shifts subsequent URLs down to fill the gap.
    /// </summary>
    public bool RemoveUrl(int removeIndex)
    {
        if (!ParseMetadata()) return false;
        if (removeIndex < 0 || removeIndex >= _metadataList.Count) return false;

        if (!Networking.IsOwner(gameObject))
        {
            // Defer until ownership is confirmed
            _pendingRemove = true;
            _pendingRemoveIndex = removeIndex;
            _pendingAdd = false;
            Networking.SetOwner(Networking.LocalPlayer, gameObject);
            return true;
        }

        ExecuteRemoveUrl(removeIndex);
        return true;
    }

    private void ExecuteRemoveUrl(int removeIndex)
    {
        if (!ParseMetadata()) return;
        if (removeIndex < 0 || removeIndex >= _metadataList.Count) return;

        _metadataList.RemoveAt(removeIndex);

        // Shift URL fields down to fill the gap
        for (int i = removeIndex; i < _metadataList.Count; i++)
        {
            SetUrlAtIndex(i, GetUrlAtIndex(i + 1));
        }
        // Clear the last slot
        SetUrlAtIndex(_metadataList.Count, VRCUrl.Empty);

        if (!SerializeMetadata()) return;

        RequestSerialization();
    }

    public override void OnOwnershipTransferred(VRCPlayerApi player)
    {
        if (!player.isLocal) return;

        if (_pendingAdd)
        {
            _pendingAdd = false;
            ExecuteAddUrl(_pendingAddUrl, _pendingAddType);
        }
        else if (_pendingRemove)
        {
            _pendingRemove = false;
            ExecuteRemoveUrl(_pendingRemoveIndex);
        }
    }

    /// <summary>
    /// Returns the VRCUrl at the given index.
    /// </summary>
    public VRCUrl GetUrl(int index)
    {
        return GetUrlAtIndex(index);
    }

    /// <summary>
    /// Returns the current number of stored URLs.
    /// </summary>
    public int GetCount()
    {
        if (!ParseMetadata()) return 0;
        return _metadataList.Count;
    }

    // --- Deserialization (receiving sync from owner) ---

    public override void OnDeserialization()
    {
        if (!ParseMetadata())
        {
            Debug.LogWarning("[SyncedUrlList] Failed to parse metadata on deserialization");
            return;
        }

        // URLs are automatically synced via their individual [UdonSynced] fields.
        // Metadata is parsed from the JSON string above.
        // Notify listeners or update UI here.
        Debug.Log($"[SyncedUrlList] Received {_metadataList.Count} URLs");
    }

    // --- Internal Helpers ---

    private bool ParseMetadata()
    {
        if (VRCJson.TryDeserializeFromJson(SyncedMetadataJson, out DataToken token))
        {
            _metadataList = token.DataList;
            return true;
        }
        Debug.LogError("[SyncedUrlList] Failed to deserialize metadata JSON");
        return false;
    }

    private bool SerializeMetadata()
    {
        if (VRCJson.TrySerializeToJson(_metadataList, JsonExportType.Minify, out DataToken token))
        {
            SyncedMetadataJson = token.String;
            return true;
        }
        Debug.LogError("[SyncedUrlList] Failed to serialize metadata JSON");
        return false;
    }
}
```

**Pattern Summary:**

| Element | Purpose |
|---------|---------|
| Individual `[UdonSynced] VRCUrl` fields | Each URL synced as its own field (array sync not supported) |
| `switch`-based get/set methods | Maps runtime index to the correct field |
| `[UdonSynced] string` for metadata | JSON-encoded array of `[timestamp, type, sender]` entries |
| `VRCJson.TrySerializeToJson` / `TryDeserializeFromJson` | Serialization of structured metadata into a single synced string |
| `OnDeserialization` | Handles incoming sync data on non-owner clients |
| Pending-operation + `OnOwnershipTransferred` | Carries multi-step deferred operation parameters (Add vs Remove) from the request site to the callback. |

> *Note: `Networking.SetOwner` is locally immediate (post-2021.2.2), so this pattern is not required for ownership timing — it survives because it cleanly carries the operation context from the request site into the callback. See [networking-antipatterns.md §1](networking-antipatterns.md#1-ownership-race-condition) for the immediate-after-SetOwner alternative when no parameter passing is needed.*

**Bandwidth and Performance Considerations:**

- **Each `[UdonSynced]` field contributes to sync payload size.** VRCUrl fields are serialized as strings
  (the full URL text). With Manual sync mode, all synced fields are sent together in one `RequestSerialization`
  call, even if only one URL changed.
- **Recommended capacity: 8-16 fields** for most use cases. Going beyond 16 significantly increases the per-sync
  payload. At 64 fields, the sync payload can become large enough to cause noticeable latency, especially in
  worlds with many synced objects.
- **Metadata as JSON is bandwidth-efficient**: A single `[UdonSynced] string` holding structured JSON is far
  cheaper than syncing individual metadata fields (sender, timestamp, type) per URL slot.
- **Deletion requires shifting**: When removing a URL from the middle, all subsequent URL fields must be
  reassigned (shifted down). This is an O(n) operation on synced fields. For frequently modified lists, consider
  using a "soft delete" flag in the metadata instead of physically shifting.
- **Late-joiner sync**: All `[UdonSynced]` fields are automatically sent to late joiners. No special handling
  is needed beyond calling `RequestSerialization()` in `OnPlayerJoined` if the owner needs to push current state.

---

## See Also

- [api.md](api.md) - VRChat-specific types and VRC Constraint API available in UdonSharp
- [troubleshooting.md](troubleshooting.md) - Common compile and runtime errors with UdonSharp constraints
