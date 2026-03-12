# UdonSharp Constraints Reference

Complete reference of C# features and their availability in UdonSharp.

**Supported SDK Versions**: 3.7.1 - 3.10.2 (as of March 2026)

## Supported Features

### Data Types

| Type | Status | Notes |
|------|--------|-------|
| `int`, `float`, `double`, `bool` | Supported | Basic value types work normally |
| `string`, `char` | Supported | String interpolation (`$""`) available |
| `Vector3`, `Quaternion`, `Color` | Supported | Unity struct types |
| `GameObject`, `Transform` | Supported | Unity object types |
| `T[]` (one-dimensional arrays) | Supported | Primary collection type |
| `T[,]` (multi-dimensional arrays) | Supported | Works but less common |
| `T[][]` (jagged arrays) | Supported | Arrays of arrays |

### Control Flow

| Feature | Status | Notes |
|---------|--------|-------|
| `if`/`else` | Supported | |
| `switch` | Supported | |
| `for`, `foreach` | Supported | |
| `while`, `do-while` | Supported | |
| `break`, `continue`, `return` | Supported | |
| Ternary operator `? :` | Supported | |
| Null-coalescing `??` | Supported | |
| Null-conditional `?.` | Supported | |

### Methods and Properties

| Feature | Status | Notes |
|---------|--------|-------|
| User-defined methods | Supported | Parameters and return values work |
| `out`/`ref` parameters | Supported | |
| `params` keyword | Supported | Variable arguments |
| Extension methods | Supported | |
| Properties (get/set) | Supported | |
| Virtual methods | Supported | For inheritance |
| `[RecursiveMethod]` | Required | For recursive calls |

### Object-Oriented Features

| Feature | Status | Notes |
|---------|--------|-------|
| `UdonSharpBehaviour` inheritance | Supported | Required base class |
| Single inheritance | Supported | One base class only |
| UdonSharpBehaviour to UdonSharpBehaviour inheritance | Supported | Can inherit from other UdonSharpBehaviours |
| Abstract classes | Supported | |
| Virtual methods | Supported | For polymorphism |
| Static fields/methods | Supported | |
| Partial classes | Supported | Split class across files |
| `typeof()` | Supported | |

## Unsupported Features

### Collections and Generics

| Feature | Status | Alternative |
|---------|--------|-------------|
| `List<T>` | Blocked | Use `T[]` arrays or `DataList` |
| `Dictionary<T,K>` | Blocked | Use `DataDictionary` from VRC SDK |
| `Queue<T>`, `Stack<T>` | Blocked | Implement with arrays |
| `HashSet<T>` | Blocked | Use arrays with manual deduplication |
| Generic type parameters | Blocked | Use concrete types |

**DataList/DataDictionary Example:**

```csharp
using VRC.SDK3.Data;

// Instead of List<string>
DataList stringList = new DataList();
stringList.Add("item1");
stringList.Add("item2");
string first = stringList[0].String;

// Instead of Dictionary<string, int>
DataDictionary dict = new DataDictionary();
dict["key1"] = 100;
dict["key2"] = 200;
int value = dict["key1"].Int;
```

### Language Features

| Feature | Status | Alternative |
|---------|--------|-------------|
| `interface` | Blocked | Use base class or `SendCustomEvent` |
| Method overloading | Blocked | Use distinct method names |
| Operator overloading | Blocked | Use explicit methods |
| `try`/`catch`/`finally` | Blocked | Use defensive null checks |
| `throw` exceptions | Blocked | Use return values for errors |
| `async`/`await` | Blocked | Use `SendCustomEventDelayedSeconds` |
| `yield return` (coroutines) | Blocked | Use delayed events |
| Delegates | Blocked | Use `SendCustomEvent` |
| `Button.onClick.AddListener()` | Blocked | Inspector OnClick -> `SendCustomEvent` |
| Events (C# events) | Blocked | Use UdonSharp events |
| LINQ | Blocked | Use manual loops |
| Anonymous types | Blocked | Define explicit types |
| Lambda expressions | Blocked | Use named methods |
| Local functions | Blocked | Use private methods |
| Pattern matching | Blocked | Use traditional `if`/`switch` |

**Method Overloading Alternative:**

```csharp
// WRONG - overloading not supported
public void DoSomething(int value) { }
public void DoSomething(string value) { }

// CORRECT - use distinct names
public void DoSomethingInt(int value) { }
public void DoSomethingString(string value) { }
```

**Exception Handling Alternative:**

```csharp
// WRONG - try/catch not supported
try {
    ProcessData(data);
} catch (Exception e) {
    Debug.LogError(e.Message);
}

// CORRECT - defensive programming
if (data == null)
{
    Debug.LogError("Data is null");
    return;
}
ProcessData(data);
```

### System Namespaces

| Namespace | Status | Notes |
|-----------|--------|-------|
| `System.IO` | Blocked | Not available (security) |
| `System.Net` | Blocked | Use `VRCStringDownloader`, `VRCImageDownloader` |
| `System.Reflection` | Blocked | Not available |
| `System.Threading` | Blocked | Not available |
| `System.Linq` | Blocked | Use manual loops |
| `System.Text.StringBuilder` | **Available (3.7.1+)** | Efficient string concatenation |
| `System.Text.RegularExpressions` | **Available (3.7.1+)** | Pattern matching (Regex) |
| `System.Random` | **Available (3.7.1+)** | Deterministic random with seed |
| `System.Type` | **Available (3.7.1+)** | Runtime type interaction |

**StringBuilder Example (SDK 3.7.1+):**

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

**Regex Example (SDK 3.7.1+):**

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

### Unsafe and Low-Level Features

| Feature | Status | Notes |
|---------|--------|-------|
| `unsafe` keyword | Blocked | Memory safety |
| Pointers (`*`, `&`) | Blocked | Not available |
| `fixed` statement | Blocked | Not available |
| `stackalloc` | Blocked | Not available |

## Behavioral Differences from C#

### Numeric Overflow Checking

UdonVM checks for numeric overflow. Operations that overflow will behave differently:

```csharp
// In standard C#, this wraps around
int max = int.MaxValue;
int overflow = max + 1; // In Udon: checked for overflow
```

### Struct Method Mutation

Mutating methods on structs do NOT modify the original struct:

```csharp
// WRONG - Normalize() doesn't change the vector
Vector3 v = new Vector3(3, 4, 0);
v.Normalize(); // v is still (3, 4, 0)!

// CORRECT - use property or reassign
Vector3 v = new Vector3(3, 4, 0);
v = v.normalized; // v is now (0.6, 0.8, 0)
```

### Array Operations

Some array operations behave differently:

```csharp
// Array.Resize creates a new array (as expected)
int[] arr = new int[5];
System.Array.Resize(ref arr, 10);

// Array.Copy works as expected
int[] source = new int[] { 1, 2, 3 };
int[] dest = new int[3];
System.Array.Copy(source, dest, 3);
```

## VRChat-Specific Types

UdonSharp provides access to VRChat-specific types:

| Type | Purpose |
|------|---------|
| `VRCPlayerApi` | Player information and actions |
| `VRCStation` | Station/seat management |
| `VRCPickup` | Pickup object handling |
| `VRCAvatarParameterDriver` | Avatar parameter control |
| `VRCUrl` | URL handling for downloads |
| `DataList`, `DataDictionary` | Generic-like collections |
| `DataToken` | Type-safe data container |

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
- [ ] Struct methods return new values (not mutating)

## Known Limitations and Caveats

### Prefab Field Changes

Changes to serialized fields on prefabs do NOT propagate to instances in the scene or other prefabs that reference them. This is a Unity limitation that affects UdonSharp as well.

**Workaround**: After modifying a prefab, manually update instances or use `PrefabUtility.ApplyPrefabInstance` in editor scripts.

### Field Initializers

Field initializers are evaluated at **compile time**, not runtime. This means:

```csharp
// WRONG - Random.Range is evaluated once at compile time
private int randomValue = Random.Range(0, 100); // Same value for all instances!

// CORRECT - Initialize in Start()
private int randomValue;

void Start()
{
    randomValue = Random.Range(0, 100);
}
```

### GetComponent and UdonBehaviour

Generic `GetComponent<UdonBehaviour>()` is not directly exposed, but **SDK 3.8+** improved support for inherited types:

```csharp
// WRONG - Raw UdonBehaviour generic
UdonBehaviour udon = GetComponent<UdonBehaviour>();

// CORRECT - Cast syntax for raw UdonBehaviour
UdonBehaviour udon = (UdonBehaviour)GetComponent(typeof(UdonBehaviour));

// CORRECT (SDK 3.8+) - Generic works for UdonSharpBehaviour inheritance
MyScript script = GetComponent<MyScript>(); // Works for UdonSharpBehaviour types

// CORRECT (SDK 3.8+) - Works with inheritance hierarchy
public class BaseGimmick : UdonSharpBehaviour { }
public class DerivedGimmick : BaseGimmick { }

// This now works correctly:
BaseGimmick gimmick = GetComponent<BaseGimmick>();
DerivedGimmick derived = GetComponent<DerivedGimmick>();
```

**Note:** SDK 3.8+ added proper handling for `GetComponent(s)<T>()` on UdonSharpBehaviour types using inheritance.

### Struct Method Mutation (Reiterated)

Methods that mutate structs do NOT modify the original:

```csharp
// WRONG
Vector3 v = new Vector3(3, 4, 0);
v.Normalize(); // v is UNCHANGED!

// CORRECT
v = v.normalized;
```

### uGUI Button Event Registration

`Button.onClick.AddListener()` is not available (delegate-based). uGUI button events must be configured in the Unity Inspector.

```csharp
// WRONG - NotImplementedException at runtime
button.onClick.AddListener(() => DoSomething());
button.onClick.AddListener(DoSomething); // Also not possible

// CORRECT - Configure in Unity Inspector:
// 1. Add to the Button component's OnClick() list
// 2. Drag the UdonBehaviour
// 3. Select SendCustomEvent
// 4. Enter the method name (e.g., "OnButtonClicked")
```
