# UdonSharp Constraints Reference

Complete reference of C# features and their availability in UdonSharp, including SDK version availability,
compiler behavior details, and annotated code examples.

**Supported SDK Versions**: 3.7.1 - 3.10.2 (as of March 2026)

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
| `T[,]` (multi-dimensional arrays) | Supported | 3.0+ | Works but less common |
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
| Extension methods | Supported | 3.0+ | |
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

Synced `string` fields (`[UdonSynced]`) have an approximate 50-character limit. For longer strings, split across multiple fields or use a different sync strategy.

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
