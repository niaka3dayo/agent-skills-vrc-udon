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

## Cancellable Delayed Event

### Problem

`SendCustomEventDelayedSeconds` has no cancellation API. Once scheduled, the callback will fire even if the caller's state has changed and the event is no longer wanted. The generation-counter debounce (see [Delayed Event Debounce in patterns-networking.md](patterns-networking.md)) handles "soft cancel" — it lets the callback fire but makes it a no-op. That is sufficient for debounce cases but not for situations where the callback absolutely must not execute: side effects inside the callback (audio playback, network requests, object destruction) will still run through the guard check even if they then return early.

### Solution

Instantiate a helper `GameObject` that carries a tiny `UdonSharpBehaviour`. Schedule `SendCustomEventDelayedSeconds` on the helper itself. To cancel, call `Destroy(helperGameObject)` before the delay expires — the destroyed behaviour never executes its scheduled callback.

**Trade-off:** Allocates a `GameObject` per timer instance. Use the generation-counter pattern for high-frequency debounce; use this pattern only when the callback truly must not fire.

**When to use:**
- Retry timers that must be cancelled when the user changes their action before the retry fires
- Load timeout timers where a successful load must cleanly suppress the "timed out" callback
- Any case where the callback has irreversible side effects (network events, audio, state mutation)

```csharp
using UdonSharp;
using UnityEngine;

/// <summary>
/// Tiny helper behaviour instantiated per timer.
/// Destroying its GameObject before the delay expires cancels the callback.
/// </summary>
[AddComponentMenu("")]
[UdonBehaviourSyncMode(BehaviourSyncMode.NoVariableSync)]
public class CancellableTimer : UdonSharpBehaviour
{
    // Written by the factory before the delay is scheduled.
    [HideInInspector] public UdonSharpBehaviour CallbackTarget;
    [HideInInspector] public string              CallbackMethod;

    /// <summary>
    /// Called by SendCustomEventDelayedSeconds on this behaviour.
    /// Fires CallbackTarget.SendCustomEvent(CallbackMethod) and then
    /// destroys the helper GameObject.
    /// </summary>
    public void _Fire()
    {
        if (CallbackTarget != null)
        {
            CallbackTarget.SendCustomEvent(CallbackMethod);
        }

        // Clean up the helper object after firing.
        Destroy(gameObject);
    }
}
```

**Usage — create and cancel a timer:**

```csharp
using UdonSharp;
using UnityEngine;

[UdonBehaviourSyncMode(BehaviourSyncMode.NoVariableSync)]
public class RetryController : UdonSharpBehaviour
{
    [SerializeField] private GameObject _timerPrefab; // Prefab with CancellableTimer attached
    [SerializeField] private float      _retryDelay = 5f;

    private GameObject _pendingTimer;

    /// <summary>
    /// Schedules a retry. Cancels any previously pending retry first.
    /// </summary>
    public void ScheduleRetry()
    {
        if (_timerPrefab == null) { Debug.LogError("[RetryController] Timer prefab not assigned"); return; }

        CancelPendingRetry();

        _pendingTimer = VRCInstantiate(_timerPrefab);
        CancellableTimer timer = _pendingTimer.GetComponent<CancellableTimer>();
        if (timer == null) { Debug.LogError("[RetryController] CancellableTimer component missing"); Destroy(_pendingTimer); _pendingTimer = null; return; }
        timer.CallbackTarget = this;
        timer.CallbackMethod = nameof(OnRetryFired);

        // The callback fires on the helper; destroying _pendingTimer before
        // retryDelay seconds cancels it without any generation-counter bookkeeping.
        timer.SendCustomEventDelayedSeconds(nameof(CancellableTimer._Fire), _retryDelay);
    }

    /// <summary>
    /// Cancels the pending retry if one is scheduled.
    /// </summary>
    public void CancelPendingRetry()
    {
        if (_pendingTimer != null)
        {
            Destroy(_pendingTimer);
            _pendingTimer = null;
        }
    }

    /// <summary>
    /// Invoked by the timer when the delay expires without cancellation.
    /// </summary>
    public void OnRetryFired()
    {
        _pendingTimer = null;
        Debug.Log("[RetryController] Retry timer fired — executing retry logic.");
        // ... retry logic here
    }
}
```

---

## Re-Entrance Guard

### Problem

During an event broadcast loop — `RaiseEvent` iterating a subscriber array and calling `SendCustomEvent` on each listener — a listener's handler may itself call `RaiseEvent` on the same event bus. This creates either infinite recursion (stack overflow in Udon) or corrupted iteration (the array is modified while being iterated).

### Solution

Add a `bool _isEmitting` guard to the event bus. Set it `true` immediately before the iteration and `false` immediately after. If `RaiseEvent` is called while `_isEmitting` is already `true`, skip the call (log a warning in development builds). This mirrors the pattern used in most production event systems.

**Cross-reference:** See the [Event Bus Pattern](#event-bus-pattern) in this file for the base implementation that this guard extends.

```csharp
using UdonSharp;
using UnityEngine;

/// <summary>
/// Event bus with re-entrance guard.
/// Prevents recursive RaiseEvent calls from corrupting the subscriber iteration.
/// </summary>
[UdonBehaviourSyncMode(BehaviourSyncMode.NoVariableSync)]
public class GuardedEventBus : UdonSharpBehaviour
{
    private const int MaxListeners = 32;

    [SerializeField] private UdonSharpBehaviour[] _listeners
        = new UdonSharpBehaviour[MaxListeners];
    private int _listenerCount = 0;

    // Re-entrance guard: true while RaiseEvent is iterating _listeners.
    private bool _isEmitting = false;

    public void RegisterListener(UdonSharpBehaviour listener)
    {
        if (listener == null) return;

        // Duplicate check
        for (int i = 0; i < _listenerCount; i++)
        {
            if (_listeners[i] == listener) return;
        }

        if (_listenerCount >= MaxListeners)
        {
            Debug.LogWarning("[GuardedEventBus] Listener limit reached.");
            return;
        }

        _listeners[_listenerCount] = listener;
        _listenerCount++;
    }

    public void UnregisterListener(UdonSharpBehaviour listener)
    {
        for (int i = 0; i < _listenerCount; i++)
        {
            if (_listeners[i] == listener)
            {
                // Compact in place
                _listeners[i] = _listeners[_listenerCount - 1];
                _listeners[_listenerCount - 1] = null;
                _listenerCount--;
                return;
            }
        }
    }

    /// <summary>
    /// Raises <paramref name="eventMethodName"/> on all registered listeners.
    /// Re-entrant calls (from within a listener handler) are silently dropped.
    /// </summary>
    public void RaiseEvent(string eventMethodName)
    {
        if (_isEmitting)
        {
            // A listener is calling RaiseEvent from inside its own handler.
            // Dropping this call prevents infinite recursion and iteration corruption.
            Debug.LogWarning(
                $"[GuardedEventBus] Re-entrant RaiseEvent('{eventMethodName}') dropped.");
            return;
        }

        _isEmitting = true;

        for (int i = 0; i < _listenerCount; i++)
        {
            if (_listeners[i] != null)
            {
                _listeners[i].SendCustomEvent(eventMethodName);
            }
        }

        _isEmitting = false;
    }
}
```

**Notes:**
- If you need deferred re-entrant events (fire after the current broadcast completes), capture the call in a small pending-event queue (a `string[]` with a head/tail counter) and drain it after `_isEmitting = false`.
- `_isEmitting` does not need `[UdonSynced]`; it is a local execution-flow flag with no network meaning.

---

## UdonEvent Pseudo-Delegate

### Problem

C# delegates are blocked in UdonSharp. When a system needs a runtime-swappable, one-to-one callback — for example, a Strategy pattern where an external module overrides a hook point — there is no built-in mechanism.

**Difference from Event Bus:** The [Event Bus Pattern](#event-bus-pattern) is one-to-many broadcast; `UdonAction` is one-to-one and reassignable at runtime.

**Difference from Abstract Callback:** The [Abstract Class Callback Pattern](#abstract-class-callback-pattern) provides compile-time typed signatures via an abstract base class; `UdonAction` is stringly-typed but lighter weight (no mediator class required) and can be swapped by external code at any time.

### Solution

Store `{ UdonSharpBehaviour target, string eventName }` as a two-element `object[]` and cast it through the pseudo-struct double-cast technique (see [Pseudo-Struct via object\[\] Double-Cast](#pseudo-struct-via-object-double-cast)) to give it a named type. A companion class provides `New()`, `Invoke()`, and `SetTarget()` factory/extension methods.

**When to use:**
- Strategy pattern: swap the algorithm at runtime without changing the caller
- Hook points that external modules (loaded after world init) can register for
- Single-subscriber callbacks that must be reassigned without re-wiring Inspector references

```csharp
using UdonSharp;
using UnityEngine;

/// <summary>
/// Pseudo-delegate type: wraps a (target, eventName) pair.
/// Not a real MonoBehaviour — never attach directly to a GameObject.
/// </summary>
[AddComponentMenu("")]
[UdonBehaviourSyncMode(BehaviourSyncMode.NoVariableSync)]
public class UdonAction : UdonSharpBehaviour
{
    // Field layout indices
    public const int IdxTarget    = 0;
    public const int IdxEventName = 1;
}
```

```csharp
using UdonSharp;
using UnityEngine;

/// <summary>
/// Factory and extension methods for UdonAction.
/// </summary>
[AddComponentMenu("")]
[UdonBehaviourSyncMode(BehaviourSyncMode.NoVariableSync)]
public class UdonActionExt : UdonSharpBehaviour
{
    /// <summary>
    /// Creates a new UdonAction pointing to target.eventName.
    /// </summary>
    public static UdonAction New(UdonSharpBehaviour target, string eventName)
    {
        return (UdonAction)(object)(new object[] { target, eventName });
    }

    /// <summary>
    /// Invokes the callback. No-op if action or target is null.
    /// </summary>
    public static void Invoke(UdonAction action)
    {
        if (action == null) return;

        object[] raw = (object[])(object)action;
        UdonSharpBehaviour target    = (UdonSharpBehaviour)raw[UdonAction.IdxTarget];
        string             eventName = (string)raw[UdonAction.IdxEventName];

        if (target == null || string.IsNullOrEmpty(eventName)) return;

        target.SendCustomEvent(eventName);
    }

    /// <summary>
    /// Returns a new UdonAction with the same event name but a different target.
    /// (UdonAction instances are immutable; reassignment creates a new instance.)
    /// </summary>
    public static UdonAction SetTarget(UdonAction action, UdonSharpBehaviour newTarget)
    {
        if (action == null) return UdonActionExt.New(newTarget, "");

        object[] raw = (object[])(object)action;
        string eventName = (string)raw[UdonAction.IdxEventName];

        return UdonActionExt.New(newTarget, eventName);
    }

    /// <summary>
    /// Returns the event name stored in the action (useful for debugging).
    /// </summary>
    public static string GetEventName(UdonAction action)
    {
        if (action == null) return "";
        return (string)(((object[])(object)action)[UdonAction.IdxEventName]);
    }
}
```

**Usage — Strategy pattern with swappable callback:**

```csharp
using UdonSharp;
using UnityEngine;

[UdonBehaviourSyncMode(BehaviourSyncMode.NoVariableSync)]
public class LoadOrchestrator : UdonSharpBehaviour
{
    // The active success handler — can be reassigned by external modules.
    private UdonAction _onSuccess;

    void Start()
    {
        // Default handler: show a simple status label.
        _onSuccess = UdonActionExt.New(this, nameof(DefaultSuccessHandler));
    }

    /// <summary>
    /// External modules call this to override the success hook.
    /// </summary>
    public void SetSuccessCallback(UdonSharpBehaviour target, string methodName)
    {
        _onSuccess = UdonActionExt.New(target, methodName);
    }

    public void SimulateLoad()
    {
        Debug.Log("[LoadOrchestrator] Load complete — invoking success callback.");
        UdonActionExt.Invoke(_onSuccess);
    }

    public void DefaultSuccessHandler()
    {
        Debug.Log("[LoadOrchestrator] Default success handler called.");
    }
}
```

---


## See Also

- [patterns-core.md](patterns-core.md) - Initialization, interaction, timer, audio, pickup, animation, UI
- [patterns-networking.md](patterns-networking.md) - Object pooling, game state, NetworkCallable
- [patterns-performance.md](patterns-performance.md) - Partial class, update handler, performance optimization
- [api.md](api.md) - VRCPlayerApi, Networking, and UdonSharp API reference
