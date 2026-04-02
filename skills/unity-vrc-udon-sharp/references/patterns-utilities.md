# UdonSharp Utility Patterns

Array helpers, array utility helpers (List&lt;T&gt; alternatives), event bus, GameObject relay communication, pseudo-struct double-cast, and abstract class callback patterns.

## Array Helpers

```csharp
public class ArrayHelpers : UdonSharpBehaviour
{
    // Find index in array
    public int FindIndex(GameObject[] array, GameObject target)
    {
        for (int i = 0; i < array.Length; i++)
        {
            if (array[i] == target) return i;
        }
        return -1;
    }

    // Shuffle array (Fisher-Yates)
    public void ShuffleArray(int[] array)
    {
        for (int i = array.Length - 1; i > 0; i--)
        {
            int j = Random.Range(0, i + 1);
            int temp = array[i];
            array[i] = array[j];
            array[j] = temp;
        }
    }

    // Resize array (create new)
    public GameObject[] ResizeArray(GameObject[] original, int newSize)
    {
        GameObject[] newArray = new GameObject[newSize];
        int copyLength = Mathf.Min(original.Length, newSize);
        System.Array.Copy(original, newArray, copyLength);
        return newArray;
    }
}
```

## Array Utility Helpers

UdonSharp does not support `List<T>`. The following static-style helpers use `System.Array.Copy` to provide list-like operations on plain arrays. Each operation returns a **new array**; the original is never modified.

> **Performance warning:** Every call allocates a new array and copies elements. Do not call these in `Update()` or any hot path. Prefer pre-sized arrays with a manual count variable for high-frequency code.

**Template:** [assets/templates/ArrayUtils.cs](../assets/templates/ArrayUtils.cs)

Provides `Add`, `Contains`, `AddUnique`, `Remove`, `RemoveAt`, and `Insert` operations for `GameObject[]`, plus `FindIndex` and `ShuffleArray` for `int[]`. All operations return new arrays; none mutate the source. UdonSharp does not support generic methods, so one set of signatures per element type is required — duplicate as needed for `UdonSharpBehaviour[]`, `int[]`, etc.

---

## Event Bus Pattern

### Problem

C# delegates and events are unavailable in UdonSharp. How can one behaviour notify several others when something changes?

### Solution

Maintain a `UdonSharpBehaviour[]` subscriber list. Raising an event iterates the list and calls `SendCustomEvent(methodName)` on each entry.

**Template:** [assets/templates/EventBus.cs](../assets/templates/EventBus.cs)

The `EventBus` class keeps a `UdonSharpBehaviour[]` array capped at `MaxListeners` (32). `RegisterListener` appends with duplicate check; `UnregisterListener` compacts the array in place. `RaiseEvent(string eventMethodName)` iterates the list, skips null entries with an in-place compaction pass, and calls `SendCustomEvent(eventMethodName)` on each live subscriber.

**Consumer example:**

```csharp
public class DoorController : UdonSharpBehaviour
{
    [SerializeField] private EventBus doorBus;
    [SerializeField] private Animator doorAnimator;

    void Start()
    {
        doorBus.RegisterListener(this);
    }

    // Called by EventBus.RaiseEvent("OnDoorOpened")
    public void OnDoorOpened()
    {
        doorAnimator.SetTrigger("Open");
    }
}
```

**Producer example:**

```csharp
public class DoorTrigger : UdonSharpBehaviour
{
    [SerializeField] private EventBus doorBus;

    public override void OnPlayerTriggerEnter(VRCPlayerApi player)
    {
        if (player.isLocal)
        {
            doorBus.RaiseEvent("OnDoorOpened");
        }
    }
}
```

---

## GameObject Relay Communication

### Problem

Direct references couple event producers tightly to their consumers. How can a behaviour react to a signal without the producer knowing its type?

### Solution

Use `GameObject.SetActive` as a signalling mechanism. The producer toggles a relay GameObject; any behaviour on that GameObject reacts in `OnEnable` or `OnDisable`.

**Producer — sends the signal:**

```csharp
public class LightSwitchTrigger : UdonSharpBehaviour
{
    [SerializeField] private GameObject lightsOnRelay;
    [SerializeField] private GameObject lightsOffRelay;

    private bool _lightsOn = false;

    public override void Interact()
    {
        _lightsOn = !_lightsOn;

        if (_lightsOn)
        {
            // Pulse the relay: activate then deactivate next frame
            lightsOnRelay.SetActive(true);
            lightsOnRelay.SetActive(false);
        }
        else
        {
            lightsOffRelay.SetActive(true);
            lightsOffRelay.SetActive(false);
        }
    }
}
```

**Consumer — reacts to the signal:**

```csharp
/// <summary>
/// Attach to the lightsOnRelay GameObject.
/// OnEnable fires every time the producer calls SetActive(true).
/// </summary>
public class LightsOnResponder : UdonSharpBehaviour
{
    [SerializeField] private Light[] sceneLights;

    void OnEnable()
    {
        for (int i = 0; i < sceneLights.Length; i++)
        {
            if (sceneLights[i] != null)
            {
                sceneLights[i].enabled = true;
            }
        }
    }

    void OnDisable()
    {
        // OnDisable is called immediately after OnEnable in the pulse pattern above.
        // Use a separate relay GameObject for each signal direction to keep concerns clear.
    }
}
```

**When to prefer this over EventBus:**
- Very simple one-shot signals where subscriber registration overhead is unnecessary
- Signals that must persist across scene loads (relay GameObject survives)
- Visual debugging: relay active state is visible in the Hierarchy

---

## Pseudo-Struct via object[] Double-Cast

### Problem

UdonSharp lacks full `struct` support and has no generics. You cannot define:

```csharp
struct ItemData { int Id; string Name; float Price; }
List<ItemData> items = new List<ItemData>();
```

`DataDictionary` is available but has no compile-time type checking — a typo in a key string silently returns null at runtime.

### Solution

Define a **type class**: a `UdonSharpBehaviour` subclass whose sole purpose is to carry typed data. A static-style `New(...)` factory packs fields into an `object[]` and casts it through `object` to the type class:

```csharp
return (ItemData)(object)(new object[] { id, name, price });
```

A companion **extension class** reverses the cast to read individual fields:

```csharp
return (int)(((object[])(object)val)[0]);
```

This exploits the UdonSharp runtime's willingness to round-trip `UdonSharpBehaviour`-derived types through an intermediate `object` cast — an empirically observed behaviour in UdonSharp's runtime type system. This pattern is used in production VRChat worlds but is not officially documented by VRChat.

### Type Class and Extension

```csharp
using UdonSharp;
using UnityEngine;

/// <summary>
/// Data carrier for a catalogue item.
/// Not a real MonoBehaviour — never attach directly to a GameObject.
/// </summary>
[AddComponentMenu("")]
[UdonBehaviourSyncMode(BehaviourSyncMode.NoVariableSync)]
public class ItemData : UdonSharpBehaviour
{
    // Field layout: public so ItemDataExt can reference them without magic numbers
    public const int IdxId    = 0;
    public const int IdxName  = 1;
    public const int IdxPrice = 2;

    /// <summary>
    /// Creates an immutable ItemData instance.
    /// </summary>
    public static ItemData New(int id, string name, float price)
    {
        return (ItemData)(object)(new object[] { id, name, price });
    }
}
```

```csharp
using UdonSharp;
using UnityEngine;

/// <summary>
/// Getter extensions for ItemData.
/// Usage: myItem.Id(), myItem.Name(), myItem.Price()
/// </summary>
[AddComponentMenu("")]
[UdonBehaviourSyncMode(BehaviourSyncMode.NoVariableSync)]
public class ItemDataExt : UdonSharpBehaviour
{
    public static int Id(ItemData val)
    {
        return (int)(((object[])(object)val)[ItemData.IdxId]);
    }

    public static string Name(ItemData val)
    {
        return (string)(((object[])(object)val)[ItemData.IdxName]);
    }

    public static float Price(ItemData val)
    {
        return (float)(((object[])(object)val)[ItemData.IdxPrice]);
    }
}
```

### Usage

```csharp
[UdonBehaviourSyncMode(BehaviourSyncMode.NoVariableSync)]
public class CatalogueDisplay : UdonSharpBehaviour
{
    private ItemData[] _catalogue;

    void Start()
    {
        // Build a typed array of pseudo-structs
        _catalogue = new ItemData[]
        {
            ItemData.New(1, "Health Potion", 50f),
            ItemData.New(2, "Iron Sword",   300f),
            ItemData.New(3, "Leather Boots", 120f),
        };

        LogCatalogue();
    }

    private void LogCatalogue()
    {
        for (int i = 0; i < _catalogue.Length; i++)
        {
            ItemData item = _catalogue[i];
            int   id    = ItemDataExt.Id(item);
            string name = ItemDataExt.Name(item);
            float price = ItemDataExt.Price(item);

            Debug.Log($"[{id}] {name} — {price}G");
        }
    }

    // "Updating" an entry means replacing it with a new instance (immutable)
    public void MarkdownPrice(int index, float newPrice)
    {
        if (index < 0 || index >= _catalogue.Length) return;

        ItemData old = _catalogue[index];
        _catalogue[index] = ItemData.New(
            ItemDataExt.Id(old),
            ItemDataExt.Name(old),
            newPrice
        );
    }
}
```

**Limitations:**

- Instances are **immutable by design**. To "update" a field, replace the entry in the array with a new `New(...)` call (see `MarkdownPrice` above).
- The `[AddComponentMenu("")]` attribute hides the type class from Unity's Add Component menu — it is a data carrier, not a real behaviour, and should never appear in Inspector component lists.
- Do not rely on `GetComponent<ItemData>()` — the type class is never attached to a GameObject.

**When to use:**

- Typed rows parsed from JSON or downloaded string data
- Structured entries in fixed-size arrays (inventory, leaderboard, catalogue)
- Any case where `DataDictionary` string-key access feels error-prone

---

## Abstract Class Callback Pattern

### Problem

The `interface` keyword is blocked in UdonSharp. When building modular systems — a data loader that must notify its caller when finished — you cannot define `ILoadCallback`. Using bare `SendCustomEvent(stringName)` loses type safety: callers receive no arguments and must re-read public fields manually, with no compiler guard against mismatched names.

### Solution

Define an **abstract base class** with abstract callback methods. Concrete handlers subclass it and override those methods. A **mediator** bridges the string-based `SendCustomEvent` call from the worker to the typed method on the callback reference.

```
Worker ──SendCustomEvent──▶ Mediator ──typed call──▶ AbstractBase ──override──▶ ConcreteHandler
```

This three-layer structure gives you:

| Layer | Responsibility |
|---|---|
| **Worker** | Does the work; stores results in `public` fields; calls `callback.SendCustomEvent(nameof(OnResultReady))` |
| **Mediator** | Receives the string event; reads worker's public fields; calls the typed abstract method |
| **Abstract base** | Declares the typed callback signature; concrete subclasses override it |

### Comparison

| Approach | Type safety | Argument passing | Compile-time check |
|---|---|---|---|
| `SendCustomEvent(string)` | None | None (read public fields manually) | No |
| Abstract callback via mediator | Full | Typed parameters | Yes |

### Implementation

```csharp
using UdonSharp;
using UnityEngine;

/// <summary>
/// Abstract base for any component that needs to receive process results.
/// Subclass this and override OnProcessComplete.
/// </summary>
[AddComponentMenu("")]
[UdonBehaviourSyncMode(BehaviourSyncMode.NoVariableSync)]
public abstract class ProcessCallbackBase : UdonSharpBehaviour
{
    /// <summary>
    /// Called by ProcessMediator when DataProcessor finishes.
    /// </summary>
    /// <param name="success">Whether the operation succeeded.</param>
    /// <param name="data">Processed output lines.</param>
    public abstract void OnProcessComplete(bool success, string[] data);
}
```

```csharp
using UdonSharp;
using UnityEngine;

/// <summary>
/// Worker: performs the data processing and notifies a mediator when done.
/// Results are written to public fields before the event fires so the
/// mediator can read them synchronously.
/// </summary>
[UdonBehaviourSyncMode(BehaviourSyncMode.NoVariableSync)]
public class DataProcessor : UdonSharpBehaviour
{
    [Header("Callback")]
    [SerializeField] private ProcessMediator _mediator;

    // Public result fields — written before SendCustomEvent fires
    [HideInInspector] public bool ResultSuccess;
    [HideInInspector] public string[] ResultData;

    public void Process(string[] inputLines)
    {
        // Simulate work
        string[] output = new string[inputLines.Length];
        for (int i = 0; i < inputLines.Length; i++)
        {
            output[i] = inputLines[i].Trim();
        }

        ResultSuccess = true;
        ResultData    = output;

        // Notify mediator via string event.
        // String literal used instead of nameof(ProcessMediator.OnResultReady) because
        // UdonSharp's nameof support for cross-class members is unreliable at runtime.
        _mediator.SendCustomEvent("OnResultReady");
    }
}
```

```csharp
using UdonSharp;
using UnityEngine;

/// <summary>
/// Mediator: bridges the string-based worker callback to the typed abstract method.
/// </summary>
[UdonBehaviourSyncMode(BehaviourSyncMode.NoVariableSync)]
public class ProcessMediator : UdonSharpBehaviour
{
    [Header("References")]
    [SerializeField] private DataProcessor _worker;
    [SerializeField] private ProcessCallbackBase _callback;

    // Called by DataProcessor via SendCustomEvent
    public void OnResultReady()
    {
        if (_callback == null) return;

        // Read typed results from worker's public fields
        bool     success = _worker.ResultSuccess;
        string[] data    = _worker.ResultData;

        // Forward as a typed call — compiler enforces the signature
        _callback.OnProcessComplete(success, data);
    }
}
```

```csharp
using UdonSharp;
using UnityEngine;
using TMPro;

/// <summary>
/// Concrete handler: receives typed results and updates the UI.
/// </summary>
[UdonBehaviourSyncMode(BehaviourSyncMode.NoVariableSync)]
public class MyResultHandler : ProcessCallbackBase
{
    [SerializeField] private TextMeshProUGUI _statusLabel;
    [SerializeField] private TextMeshProUGUI[] _lineLabels;

    public override void OnProcessComplete(bool success, string[] data)
    {
        if (_statusLabel != null)
        {
            _statusLabel.text = success ? "Done" : "Failed";
        }

        int count = Mathf.Min(data.Length, _lineLabels.Length);
        for (int i = 0; i < count; i++)
        {
            if (_lineLabels[i] != null)
            {
                _lineLabels[i].text = data[i];
            }
        }
    }
}
```

**Notes:**

- The mediator holds the `ProcessCallbackBase` reference as the **abstract type**, not the concrete type. This means any subclass of `ProcessCallbackBase` can be plugged in without changing the mediator.
- The `[AddComponentMenu("")]` on `ProcessCallbackBase` keeps it out of Unity's Add Component menu.
- `abstract` methods are `public` in the abstract class, but calling them via `SendCustomEvent` on an abstract class reference is unreliable: abstract methods have no concrete Udon bytecode body, so the Udon VM cannot dispatch to them by name. The mediator therefore uses a direct typed call (`_callback.OnProcessComplete(...)`) against the concrete instance. This is intentional — it is the typed boundary.
- The worker's public result fields (`ResultSuccess`, `ResultData`) act as a temporary buffer. Read them synchronously inside `OnResultReady`; they may be overwritten if a second `Process` call fires before your handler completes.

**When to use:**

- Data loading pipelines where a downloader or decoder notifies a display controller
- UI systems that need to react to events from multiple independent worker types
- Multi-step workflows where each stage hands off to a typed "done" handler

---


## See Also

- [patterns-core.md](patterns-core.md) - Initialization, interaction, timer, audio, pickup, animation, UI
- [patterns-networking.md](patterns-networking.md) - Object pooling, game state, NetworkCallable
- [patterns-performance.md](patterns-performance.md) - Partial class, update handler, performance optimization
- [api.md](api.md) - VRCPlayerApi, Networking, and UdonSharp API reference
