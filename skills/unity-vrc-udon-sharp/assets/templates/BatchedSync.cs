using UdonSharp;
using UnityEngine;
using VRC.SDKBase;

/// <summary>
/// Batches rapid state changes into a single serialization call by
/// deferring the actual RequestSerialization() by a short delay.
///
/// Key points:
/// - ScheduleBatchedSync is idempotent: calling it multiple times before the
///   delay fires has no effect beyond the first call.
/// - All fields are serialized together in one packet, regardless of how many
///   mutation methods were called during the batch window.
/// - Tune BatchDelay to balance latency against packet reduction.
///   100-300 ms is typically invisible to players for non-positional state.
///
/// Use this when multiple rapid events (several players joining in quick succession,
/// multi-field form submission) each call RequestSerialization() independently,
/// producing redundant packets with nearly identical payloads.
/// </summary>
[UdonBehaviourSyncMode(BehaviourSyncMode.Manual)]
public class BatchedSync : UdonSharpBehaviour
{
    // Delay before the batched serialization fires (seconds).
    private const float BatchDelay = 0.2f;

    [UdonSynced] private int  _playerCount;
    [UdonSynced] private int  _readyFlags;   // Bit field: one bit per player slot
    [UdonSynced] private int  _roundNumber;

    // True while a delayed serialization is already scheduled.
    private bool _syncPending;

    // ------------------------------------------------------------------
    // State mutation methods — each marks dirty and schedules one batch.
    // ------------------------------------------------------------------

    public void OnPlayerJoined(int slotIndex)
    {
        if (!Networking.IsOwner(gameObject)) return;

        _playerCount++;
        _readyFlags &= ~(1 << slotIndex); // New player is not ready yet
        ScheduleBatchedSync();
    }

    public void OnPlayerReady(int slotIndex)
    {
        if (!Networking.IsOwner(gameObject)) return;

        _readyFlags |= (1 << slotIndex);
        ScheduleBatchedSync();
    }

    public void AdvanceRound()
    {
        if (!Networking.IsOwner(gameObject)) return;

        _roundNumber++;
        _playerCount = 0;
        _readyFlags  = 0;
        ScheduleBatchedSync();
    }

    // ------------------------------------------------------------------
    // Batching logic
    // ------------------------------------------------------------------

    private void ScheduleBatchedSync()
    {
        if (_syncPending) return; // Batch already queued — do nothing

        _syncPending = true;
        SendCustomEventDelayedSeconds(nameof(_FlushBatch), BatchDelay);
    }

    /// <summary>Delayed callback: serialize all accumulated changes at once.</summary>
    public void _FlushBatch()
    {
        _syncPending = false;

        if (!Networking.IsOwner(gameObject)) return;

        RequestSerialization();
    }

    // ------------------------------------------------------------------
    // Deserialization
    // ------------------------------------------------------------------

    public override void OnDeserialization()
    {
        UpdateGameUI(_playerCount, _readyFlags, _roundNumber);
    }

    private void UpdateGameUI(int count, int flags, int round)
    {
        Debug.Log($"[BatchedSync] Round={round} Players={count} Ready=0b{System.Convert.ToString(flags, 2)}");
    }
}
