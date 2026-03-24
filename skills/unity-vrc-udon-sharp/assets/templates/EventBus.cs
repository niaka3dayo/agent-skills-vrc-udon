using UdonSharp;
using UnityEngine;

/// <summary>
/// A minimal event bus. Producers call RaiseEvent(); consumers register themselves
/// and implement the matching handler method.
///
/// C# delegates and events are unavailable in UdonSharp. This pattern maintains
/// a UdonSharpBehaviour[] subscriber list. Raising an event iterates the list and
/// calls SendCustomEvent(methodName) on each entry.
/// </summary>
public class EventBus : UdonSharpBehaviour
{
    // Internal listener registry
    [SerializeField] private UdonSharpBehaviour[] _listeners = new UdonSharpBehaviour[0];
    private int _listenerCount = 0;

    // Maximum listeners before compaction is required
    private const int MaxListeners = 32;

    void Start()
    {
        _listeners = new UdonSharpBehaviour[MaxListeners];
        _listenerCount = 0;
    }

    /// <summary>
    /// Register a listener. The listener must implement the handler method by name.
    /// </summary>
    public void RegisterListener(UdonSharpBehaviour listener)
    {
        if (listener == null) return;
        if (_listenerCount >= MaxListeners) return;

        // Avoid duplicate registrations
        for (int i = 0; i < _listenerCount; i++)
        {
            if (_listeners[i] == listener) return;
        }

        _listeners[_listenerCount] = listener;
        _listenerCount++;
    }

    /// <summary>
    /// Unregister a listener.
    /// </summary>
    public void UnregisterListener(UdonSharpBehaviour listener)
    {
        for (int i = 0; i < _listenerCount; i++)
        {
            if (_listeners[i] == listener)
            {
                // Compact: shift remaining entries left
                _listenerCount--;
                for (int j = i; j < _listenerCount; j++)
                {
                    _listeners[j] = _listeners[j + 1];
                }
                _listeners[_listenerCount] = null;
                return;
            }
        }
    }

    /// <summary>
    /// Raise an event. Every registered listener receives SendCustomEvent(eventMethodName).
    /// Null or destroyed listeners are silently skipped and compacted out.
    /// </summary>
    public void RaiseEvent(string eventMethodName)
    {
        int writeIndex = 0;
        for (int i = 0; i < _listenerCount; i++)
        {
            UdonSharpBehaviour listener = _listeners[i];

            // Skip destroyed or null entries
            if (listener == null) continue;

            _listeners[writeIndex] = listener;
            writeIndex++;

            listener.SendCustomEvent(eventMethodName);
        }

        // Zero out stale tail slots after compaction
        for (int i = writeIndex; i < _listenerCount; i++)
        {
            _listeners[i] = null;
        }
        _listenerCount = writeIndex;
    }
}
