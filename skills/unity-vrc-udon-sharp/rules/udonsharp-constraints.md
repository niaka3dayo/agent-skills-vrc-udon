# UdonSharp Compile Constraints (Always Loaded)

UdonSharp compiles C# to Udon Assembly. Always adhere to these constraints, which differ from standard C#.

**SDK Coverage**: 3.7.1 - 3.10.3

> For detailed examples, SDK version availability, and compiler behavior explanations,
> see `references/constraints.md`.

## Blocked Features

| Feature | Alternative |
|---------|------------|
| `List<T>`, `Dictionary<T,K>` | `T[]` arrays or `DataList`/`DataDictionary` (VRC.SDK3.Data) |
| `HashSet<T>`, `Queue<T>`, `Stack<T>` | Implement with arrays |
| Generic type parameters | Use concrete types |
| `interface` | Base class inheritance or `SendCustomEvent` |
| Method overloading | Unique method names (`DoInt`, `DoString`) |
| Operator overloading | Explicit methods |
| `try`/`catch`/`finally`/`throw` | Defensive null checks + early return |
| `async`/`await` | `SendCustomEventDelayedSeconds()` |
| `yield return` (coroutines) | `SendCustomEventDelayedSeconds()` |
| `StartCoroutine()` | `SendCustomEventDelayedSeconds()` |
| Delegates / C# events | `SendCustomEvent` |
| `Button.onClick.AddListener()` | Configure SendCustomEvent via Inspector |
| LINQ (`.Where`, `.Select`, etc.) | Manual for loops |
| Lambda expressions | Named methods |
| Local functions | private methods |
| Pattern matching | Traditional `if`/`switch` |
| Anonymous types | Explicit type definitions |
| `System.IO`, `System.Net` | `VRCStringDownloader`, `VRCImageDownloader` |
| `System.Reflection` | Not available |
| `System.Threading` | Not available |
| `unsafe`, pointers | Not available |

## Available Features (SDK 3.7.1+)

| Feature | Notes |
|---------|-------|
| `System.Text.StringBuilder` | Efficient string concatenation |
| `System.Text.RegularExpressions` | Regex pattern matching |
| `System.Random` | Seeded deterministic random numbers |
| `System.Type` | Runtime type information |
| `GetComponent<T>()` (inheritance) | Works with UdonSharpBehaviour subclasses (SDK 3.8+) |

## Code Generation Rules

### 1. Class Declaration

Must inherit from `UdonSharpBehaviour`. `MonoBehaviour` is forbidden.

```csharp
using UdonSharp;
using UnityEngine;
using VRC.SDKBase;
using VRC.Udon;

public class MyScript : UdonSharpBehaviour { }
```

### 2. Field Initialization

Field initializers are evaluated at compile time. Scene-dependent references must be obtained in `Start()` or via Lazy Init. See `references/constraints.md` for the lazy-init pattern.

```csharp
// OK: Compile-time constant
private int maxPlayers = 10;

// NG: Runtime value in field initializer (same value for all instances!)
// private int rng = Random.Range(0, 100);

// OK: Initialize in Start()
private int rng;
void Start() { rng = Random.Range(0, 100); }
```

### 3. Struct Mutation

Struct mutation methods do not modify the original value. Use the return value.

```csharp
// NG: v is not modified
v.Normalize();

// OK: Assign return value
v = v.normalized;
```

### 4. GetComponent Restrictions

`GetComponent<UdonBehaviour>()` is not exposed. Use cast syntax.

```csharp
// NG
UdonBehaviour ub = GetComponent<UdonBehaviour>();

// OK
UdonBehaviour ub = (UdonBehaviour)GetComponent(typeof(UdonBehaviour));

// OK (SDK 3.8+): Generic works for UdonSharpBehaviour subclasses
MyScript s = GetComponent<MyScript>();
```

### 5. Access Modifiers

Prefer `private` methods. Public methods slow down Udon's method lookup.

### 6. Recursive Methods

The `[RecursiveMethod]` attribute is required for recursive calls.

```csharp
[RecursiveMethod]
private int Factorial(int n) { ... }
```

### 7. uGUI Button Events and Unity Callbacks

- `Button.onClick.AddListener()` is not available -- configure OnClick via Inspector to call `SendCustomEvent`
- Unity callbacks (`OnTriggerEnter`, etc.) do **not** require `override` -- `override` is only for VRChat events

```csharp
// NG: override -> CS0115 error
public override void OnTriggerEnter(Collider other) { }
// OK: No override
public void OnTriggerEnter(Collider other) { }
// OK: VRChat events require override
public override void OnPlayerJoined(VRCPlayerApi player) { }
```

### 8. UdonSharpProgramAsset Requirement

Every `.cs` UdonSharpBehaviour needs a corresponding `.asset` (UdonSharpProgramAsset). Without it, the script won't compile to Udon.

**When creating a new `.cs` file, the agent MUST follow this procedure:**

1. **Check**: Verify that `Assets/Editor/UdonSharpProgramAssetAutoGenerator.cs` exists in the user's Unity project
2. **Install if missing**: If the file does not exist, create the `Assets/Editor/` directory (if needed) and write the auto-generator using the implementation from `references/editor-scripting.md` (UdonSharpProgramAsset Auto-Generation section)
3. **Notify**: Inform the user that the auto-generator was installed and that new `.cs` files will automatically receive `.asset` files on domain reload

Do NOT assume the auto-generator is already installed. The agent cannot verify installation status without explicitly checking, so skipping this procedure based on assumption is prohibited. See `references/editor-scripting.md` for the full implementation.

### 9. UdonBehaviour Component Wiring

After the `.asset` file is generated (Rule 8), the GameObject's `UdonBehaviour` component must reference that `.asset` in its **Program Source** field. Without this assignment, the UdonBehaviour exists on the GameObject but executes nothing — no error, no warning, no compile failure. The same silent-failure family as Rule 8, but at the **component layer** instead of the file layer.

| State | `.asset` exists? | `programSource` set? | Symptom |
|-------|:-:|:-:|---------|
| Healthy | Yes | Yes | Code runs |
| Rule 8 violation | No | (n/a) | "The associated script cannot be loaded" |
| Rule 9 violation | Yes | No | Component present, **no events fire**, no log |

**When the agent creates UdonBehaviour components programmatically (Unity automation, editor scripts, prefab manipulation), it MUST verify after creation:**

1. The GameObject has a `UdonBehaviour` component
2. That component's `programSource` field references the matching `UdonSharpProgramAsset`
3. The referenced `.asset` is the one paired with the intended `.cs` (same base name, same folder)

**Preferred API (handles wiring automatically):**

```csharp
#if UNITY_EDITOR && !COMPILER_UDONSHARP
using UdonSharpEditor;
    // Creates UdonBehaviour AND sets programSource in one call
    MyScript script = gameObject.AddUdonSharpComponent<MyScript>();
#endif
```

When manipulating `UdonBehaviour` directly without `AddUdonSharpComponent`, the agent is responsible for assigning `programSource` itself. See `references/editor-scripting.md` for proxy-system specifics and `references/troubleshooting.md` for diagnostic steps.

## Attribute Quick Reference

### Class Level

| Attribute | Purpose |
|-----------|---------|
| `[UdonBehaviourSyncMode(mode)]` | Specify sync mode |
| `[DefaultExecutionOrder(n)]` | Control execution order |

### Field Level

| Attribute | Purpose |
|-----------|---------|
| `[UdonSynced]` | Sync field |
| `[UdonSynced(UdonSyncMode.Linear)]` | Linear interpolation (position/rotation) |
| `[UdonSynced(UdonSyncMode.Smooth)]` | Smooth interpolation |
| `[FieldChangeCallback(nameof(Prop))]` | Invoke property setter on change |

### Method Level

| Attribute | Purpose |
|-----------|---------|
| `[RecursiveMethod]` | Allow recursive calls |
| `[NetworkCallable]` | Network event (SDK 3.8.1+) |

## Syncable Types

Types that can be used with `[UdonSynced]`:

`bool`, `byte`, `sbyte`, `char`, `short`, `ushort`, `int`, `uint`, `long`, `ulong`,
`float`, `double`, `string` (2 bytes/char; bounded by sync mode budget — keep short in Continuous), `Vector2`, `Vector3`, `Vector4`,
`Quaternion`, `Color`, `Color32`, `T[]` (arrays of the above types)

## Validation Checklist

- [ ] Not using `List<T>` / `Dictionary<T,K>`
- [ ] No `interface` declarations
- [ ] No method overloading (all method names are unique)
- [ ] No `try`/`catch`
- [ ] No `async`/`await` / `yield return`
- [ ] No LINQ / Lambda
- [ ] No `System.IO` / `System.Net`
- [ ] Recursive methods have `[RecursiveMethod]`
- [ ] Using return values for struct methods
- [ ] Not using `AddListener()`
- [ ] Unity callbacks (OnTriggerEnter, etc.) do not have override
- [ ] Auto-generator (`UdonSharpProgramAssetAutoGenerator.cs`) confirmed present in `Assets/Editor/` (installed if it was missing)
- [ ] Every UdonBehaviour created programmatically has its `programSource` populated with the matching `.asset` (Rule 9)
