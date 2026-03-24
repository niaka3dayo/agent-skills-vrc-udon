# UdonSharp Utility Patterns

Array helpers, array utility helpers (List&lt;T&gt; alternatives), event bus, and GameObject relay communication patterns.

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


## See Also

- [patterns-core.md](patterns-core.md) - Initialization, interaction, timer, audio, pickup, animation, UI
- [patterns-networking.md](patterns-networking.md) - Object pooling, game state, NetworkCallable
- [patterns-performance.md](patterns-performance.md) - Partial class, update handler, performance optimization
- [api.md](api.md) - VRCPlayerApi, Networking, and UdonSharp API reference
