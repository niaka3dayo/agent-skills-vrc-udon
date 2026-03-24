using UdonSharp;
using UnityEngine;
using VRC.SDKBase;

/// <summary>
/// Wraps RequestSerialization() with a congestion-aware retry loop.
/// Retries up to MaxRetries times before giving up to avoid infinite loops
/// during sustained network outages.
///
/// Design notes:
/// - _retryPending prevents multiple overlapping SendCustomEventDelayedSeconds
///   chains from accumulating if TrySerialize is called again while a retry
///   is already queued.
/// - Linear back-off (RetryDelay * _retryCount) reduces pressure on an
///   already-congested network rather than hammering it at a fixed interval.
/// - MaxRetries caps total attempts. In practice, VRChat network congestion
///   resolves within a few seconds; five retries at 1.5 s increments covers
///   ~22 s of congestion before giving up.
/// - After an abandonment, the next call to UpdateScore or SetGameState
///   resets the counter and starts fresh.
///
/// Use Networking.IsClogged to detect network congestion before serializing.
/// When congested, RequestSerialization() calls may be silently dropped.
/// </summary>
[UdonBehaviourSyncMode(BehaviourSyncMode.Manual)]
public class CloggedRetrySync : UdonSharpBehaviour
{
    // Seconds to wait between retry attempts when the network is clogged.
    private const float RetryDelay   = 1.5f;

    // Maximum number of consecutive retry attempts before abandoning the sync.
    private const int   MaxRetries   = 5;

    [UdonSynced] private int _gameScore;
    [UdonSynced] private int _gameState; // 0=Idle, 1=Playing, 2=Ended

    // Tracks how many retries have been attempted for the current pending sync.
    private int _retryCount;

    // True while a retry is scheduled so we don't double-schedule.
    private bool _retryPending;

    // ------------------------------------------------------------------
    // Public API
    // ------------------------------------------------------------------

    public void UpdateScore(int score)
    {
        if (!Networking.IsOwner(gameObject)) return;

        _gameScore = score;
        TrySerialize();
    }

    public void SetGameState(int state)
    {
        if (!Networking.IsOwner(gameObject)) return;

        _gameState = state;
        TrySerialize();
    }

    // ------------------------------------------------------------------
    // Serialization with IsClogged check
    // ------------------------------------------------------------------

    private void TrySerialize()
    {
        if (!Networking.IsOwner(gameObject)) return;

        if (Networking.IsClogged)
        {
            ScheduleRetry();
            return;
        }

        // Network is clear — reset retry state and serialize.
        _retryCount   = 0;
        _retryPending = false;
        RequestSerialization();
    }

    private void ScheduleRetry()
    {
        if (_retryPending) return; // Already waiting — do not stack retries

        if (_retryCount >= MaxRetries)
        {
            Debug.LogWarning(
                $"[CloggedRetrySync] Gave up after {MaxRetries} retries. " +
                "Network congestion is severe or persistent.");
            _retryCount   = 0;
            _retryPending = false;
            return;
        }

        _retryCount++;
        _retryPending = true;

        float delay = RetryDelay * _retryCount; // Back off linearly per attempt
        SendCustomEventDelayedSeconds(nameof(_RetrySerialize), delay);
    }

    /// <summary>Delayed retry callback.</summary>
    public void _RetrySerialize()
    {
        _retryPending = false;
        TrySerialize(); // Checks IsClogged again; may schedule another retry
    }

    // ------------------------------------------------------------------
    // Deserialization
    // ------------------------------------------------------------------

    public override void OnDeserialization()
    {
        ApplyState(_gameScore, _gameState);
    }

    private void ApplyState(int score, int state)
    {
        Debug.Log($"[CloggedRetrySync] Score={score} State={state}");
    }
}
