# UdonSharp Compile Constraints (Always Loaded)

UdonSharp compiles C# to Udon Assembly. Code that executes in the Udon runtime must adhere to these constraints, which differ from standard C#. Unity/Editor-side field initializer evaluation has the narrow exception described below.

**Active support / last verified**: SDK 3.10.4

Older version numbers in this rule record feature introductions or migration facts only; SDK 3.7.1-3.10.3 are not supported or validation targets for this Skill.

> For detailed examples, SDK version availability, and compiler behavior explanations,
> see `references/constraints.md`.

## Blocked in Udon Runtime

| Feature | Alternative |
|---------|------------|
| `List<T>`, `Dictionary<T,K>` in Udon runtime code | `T[]` arrays or `DataList`/`DataDictionary` (VRC.SDK3.Data) |
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
| LINQ (`.Where`, `.Select`, etc.) in Udon runtime code | Manual for loops |
| Lambda expressions in Udon runtime code | Named methods |
| Local functions | private methods |
| Pattern matching | Traditional `if`/`switch` |
| Anonymous types | Explicit type definitions |
| `System.IO`, `System.Net` | `VRCStringDownloader`, `VRCImageDownloader` |
| `System.Reflection` | Not available |
| `System.Threading` | Not available |
| `unsafe`, pointers | Not available |

## Available Features (historical baseline: SDK 3.7.1)

The version labels in this section are historical feature-introduction markers; use SDK 3.10.4 for current generation and validation.

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

### 2. Editor-Evaluated Field Initializers

Field initializers are evaluated as ordinary C# on the Unity/Editor side, and their resulting value becomes initial data for the compiled Udon program. An initializer may directly use LINQ/lambdas or call a static helper on the same `UdonSharpBehaviour` that uses `List<T>`, provided the final field type and value are supported by Udon. This does not make those features callable from `Start()`, `Interact()`, or other Udon runtime methods. A `Random.Range` call in an initializer is evaluated in the Editor and stored as the compiled Udon program's baked default, not runtime randomness.

Use `Start()` or a lazy-init guard only for local or per-client randomness. For shared per-object or per-session seed/state, the owner generates it and stores it in a `[UdonSynced]` field; with Manual sync, establish ownership before writing and then call `RequestSerialization()`. Receivers may apply derived state in `OnDeserialization()` when needed, but that callback is not required for the field synchronization itself, and late joiners receive the current synced state.

Keep initializer generation pure and independent of scene, player, or runtime state. Do not use `Networking.LocalPlayer`, scene references, or main-thread-only Unity APIs such as `FindObjectsByType`; constructors and field initializers can run on a loading thread. See `references/constraints.md` for complete examples and the lazy-init pattern.

```csharp
// OK: Editor-evaluated initial value that Udon can hold
private int maxPlayers = 10;

// NG: Random.Range is evaluated in the Editor and baked into the program
// private int seed = Random.Range(0, 100);

// NG: Player/runtime state is unavailable during initial value generation
// private VRCPlayerApi player = Networking.LocalPlayer;

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

See [`Event Dispatch & Cross-Behaviour Call Cost Tiers`](../references/patterns-performance.md#event-dispatch--cross-behaviour-call-cost-tiers) for the full method-visibility tier table.

### Public field serialization

`[HideInInspector] public` hides a field from the Inspector but keeps Unity serialization enabled. Use it when Editor-time DI, baking, or autowiring must persist the value into a Scene/Prefab. Use `[System.NonSerialized] public` for a runtime-only field that another UdonBehaviour accesses through direct access or `SetProgramVariable`. If `[HideInInspector]` is intentional, comment the persistence reason next to the declaration.

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
// public override void OnTriggerEnter(Collider other) { }
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
`Quaternion`, `Color`, `Color32`, `VRCUrl`, `T[]` (arrays of the above types)

## Validation Checklist

- [ ] No `List<T>` / `Dictionary<T,K>` in Udon runtime code
- [ ] No `interface` declarations
- [ ] No method overloading (all method names are unique)
- [ ] No `try`/`catch`
- [ ] No `async`/`await` / `yield return`
- [ ] No LINQ / Lambda in Udon runtime code
- [ ] Editor-evaluated field initializers produce only Udon-supported final values and do not depend on scene/player/runtime state or main-thread-only Unity APIs
- [ ] No `System.IO` / `System.Net`
- [ ] Recursive methods have `[RecursiveMethod]`
- [ ] Using return values for struct methods
- [ ] Not using `AddListener()`
- [ ] Unity callbacks (OnTriggerEnter, etc.) do not have override
- [ ] Auto-generator (`UdonSharpProgramAssetAutoGenerator.cs`) confirmed present in `Assets/Editor/` (installed if it was missing)
- [ ] Every UdonBehaviour created programmatically has its `programSource` populated with the matching `.asset` (Rule 9)
