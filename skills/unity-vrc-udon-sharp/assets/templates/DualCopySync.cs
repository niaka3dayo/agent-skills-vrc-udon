using UdonSharp;
using UnityEngine;
using VRC.SDKBase;

/// <summary>
/// Dual-copy pattern: a local working variable drives all in-world logic
/// while its synced counterpart handles network transport only.
///
/// Benefits:
/// - All game logic reads 'volume' — no conditional owner checks scattered throughout.
/// - _syncedVolume is never written outside the two serialization hooks, making
///   networking logic easy to audit.
/// - The dirty flag ensures RequestSerialization() produces a packet only when
///   the value genuinely changed, avoiding spurious traffic.
///
/// Writing directly to [UdonSynced] variables from non-owner code is silently
/// discarded at the next OnDeserialization. This pattern eliminates that pitfall
/// by keeping local and synced copies strictly separated.
/// </summary>
[UdonBehaviourSyncMode(BehaviourSyncMode.Manual)]
public class DualCopySync : UdonSharpBehaviour
{
    // ------------------------------------------------------------------
    // Local working copy — read/write freely from any in-world code.
    // Initialized to a sensible default; set by the owner at runtime.
    // ------------------------------------------------------------------
    public float volume = 0.5f;

    // ------------------------------------------------------------------
    // Synced copy — touched only in OnPreSerialization / OnDeserialization.
    // Never write to this directly outside of those two methods.
    // ------------------------------------------------------------------
    [UdonSynced] private float _syncedVolume;

    // True when the local copy differs from what was last serialized.
    private bool _dirty;

    // ------------------------------------------------------------------
    // Public API — any code (owner only) calls this to change volume.
    // ------------------------------------------------------------------

    public void SetVolume(float newVolume)
    {
        if (!Networking.IsOwner(gameObject)) return;

        if (Mathf.Approximately(newVolume, volume)) return; // No change — skip

        volume = newVolume;
        _dirty = true;
        RequestSerialization();
    }

    // ------------------------------------------------------------------
    // Serialization hooks
    // ------------------------------------------------------------------

    public override void OnPreSerialization()
    {
        if (!_dirty) return; // Nothing changed since last sync

        // Copy local → synced immediately before the packet is built.
        _syncedVolume = volume;
        _dirty = false;
    }

    public override void OnDeserialization()
    {
        // Copy synced → local so the rest of the world uses the new value.
        volume = _syncedVolume;
        ApplyVolume(volume);
    }

    // ------------------------------------------------------------------
    // Internal application of the value
    // ------------------------------------------------------------------

    private void ApplyVolume(float v)
    {
        // Drive audio sources, UI sliders, etc. from the local copy only.
        Debug.Log($"[DualCopySync] Volume applied: {v:F2}");
    }
}
