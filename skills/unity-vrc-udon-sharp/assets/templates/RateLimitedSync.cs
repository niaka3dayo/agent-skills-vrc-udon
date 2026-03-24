using UdonSharp;
using UnityEngine;
using VRC.SDKBase;

/// <summary>
/// Rate-limits serialization so that rapid changes (e.g., slider drag)
/// produce at most one sync per cooldown window. The last value written
/// during the window is always the one that gets sent.
///
/// How it works:
/// 1. The first change within a cooldown window locks further serializations
///    and schedules _OnSyncUnlock.
/// 2. Subsequent changes during the lock update _localValue but do not
///    schedule additional events.
/// 3. When the lock expires, _OnSyncUnlock serializes the current (latest) value.
/// 4. The _changeCounter comparison ensures one extra window fires if the value
///    was still moving at unlock time, guaranteeing the last write reaches the network.
/// </summary>
[UdonBehaviourSyncMode(BehaviourSyncMode.Manual)]
public class RateLimitedSync : UdonSharpBehaviour
{
    // How long to wait before allowing the next serialization (seconds).
    private const float SyncCooldown = 0.15f;

    [UdonSynced] private float _syncedValue;

    // Local working copy — always authoritative on the owner.
    private float _localValue;

    // True while a delayed sync is already scheduled.
    private bool _syncLocked;

    // Counts how many times _localValue changed during the current lock.
    // Used to detect whether a final sync is needed after unlock.
    private int _changeCounterAtLock;
    private int _changeCounter;

    // -----------------------------------------------
    // Public API — called by UI events, etc.
    // -----------------------------------------------

    /// <summary>Owner calls this whenever the controlled value changes.</summary>
    public void OnValueChanged(float newValue)
    {
        if (!Networking.IsOwner(gameObject)) return;

        _localValue = newValue;
        _changeCounter++;

        if (_syncLocked)
        {
            // A send is already scheduled; the updated _localValue will be
            // picked up when the lock expires.
            return;
        }

        // First change in a new window: lock immediately and schedule unlock.
        _syncLocked = true;
        _changeCounterAtLock = _changeCounter;
        SendCustomEventDelayedSeconds(nameof(_OnSyncUnlock), SyncCooldown);
    }

    // -----------------------------------------------
    // Delayed callback — called by SendCustomEventDelayedSeconds
    // -----------------------------------------------

    /// <summary>Invoked after the cooldown; serializes the latest value.</summary>
    public void _OnSyncUnlock()
    {
        _syncLocked = false;

        // Always serialize once on unlock to capture the final value.
        ExecuteSync();

        // If the value kept changing while we were locked, one more
        // delayed sync guarantees the very last write is transmitted.
        if (_changeCounter != _changeCounterAtLock)
        {
            _syncLocked = true;
            _changeCounterAtLock = _changeCounter;
            SendCustomEventDelayedSeconds(nameof(_OnSyncUnlock), SyncCooldown);
        }
    }

    // -----------------------------------------------
    // Serialization helpers
    // -----------------------------------------------

    private void ExecuteSync()
    {
        if (!Networking.IsOwner(gameObject)) return;
        _syncedValue = _localValue;
        RequestSerialization();
    }

    public override void OnDeserialization()
    {
        _localValue = _syncedValue;
        ApplyValue(_localValue);
    }

    private void ApplyValue(float value)
    {
        // Apply the synced value (e.g., set audio volume, seek position, etc.)
        Debug.Log($"[RateLimitedSync] Applied value: {value}");
    }
}
