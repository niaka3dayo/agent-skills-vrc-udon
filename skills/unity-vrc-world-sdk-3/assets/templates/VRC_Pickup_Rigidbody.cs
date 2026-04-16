using UdonSharp;
using UnityEngine;
using VRC.SDKBase;
using VRC.Udon; // Kept for consistency with other UdonSharp templates; not directly referenced here.

/// <summary>
/// Template for a UdonSharpBehaviour attached to a GameObject with VRC_Pickup and Rigidbody.
///
/// Requirements:
///   - This GameObject MUST have a Rigidbody component (VRC_Pickup will not work without it).
///   - This GameObject MUST have a Collider component (required for Interact detection).
///   - Add VRC_ObjectSync if you want position/physics to sync automatically across players.
///     Without VRC_ObjectSync, picking up the object also transfers ownership but does NOT
///     sync physics — add [UdonSynced] variables and call RequestSerialization() in OnPickup
///     for custom sync behaviour (BehaviourSyncMode.Manual is already set for this).
///
/// Sync mode note:
///   BehaviourSyncMode.Manual is used so that synced variables (if you add any) are
///   serialised on demand via RequestSerialization. If you add VRC_ObjectSync and have
///   no UdonSynced variables, you can safely switch to BehaviourSyncMode.None instead.
///
/// Ownership note:
///   Picking up a VRC_Pickup with VRC_ObjectSync automatically transfers ownership to the
///   grabbing player; Networking.SetOwner is called here only as an explicit example for
///   cases where ownership must be transferred before the pickup event (e.g. without ObjectSync).
///
/// Usage:
///   1. Add this script, VRC_Pickup, Rigidbody, Collider, and (optionally) VRC_ObjectSync
///      to the same GameObject.
///   2. Assign optional audio sources in the Inspector.
///   3. Override OnPickupUseDown / OnPickupUseUp to implement custom use behaviour.
/// </summary>
[UdonBehaviourSyncMode(BehaviourSyncMode.Manual)]
public class VRC_Pickup_Rigidbody : UdonSharpBehaviour
{
    [Header("Audio Feedback")]
    [Tooltip("Audio source used for pickup and drop sounds")]
    public AudioSource audioSource;

    [Tooltip("Sound played when the object is picked up")]
    public AudioClip pickupSound;

    [Tooltip("Sound played when the object is dropped")]
    public AudioClip dropSound;

    [Tooltip("Sound played when the Use button is pressed while holding")]
    public AudioClip useSound;

    [Header("Debug")]
    [Tooltip("Enable debug logging to the Unity console")]
    public bool debugMode = false;

    // Cached VRC_Pickup component — retrieved once in Start() to avoid repeated GetComponent calls.
    private VRC_Pickup _pickup;

    // [UdonSynced] private bool _isSynced; // Add UdonSynced fields here if needed, then call RequestSerialization() after changing them.

    // -------------------------------------------------------------------------
    // Unity lifecycle
    // -------------------------------------------------------------------------

    private void Start()
    {
        _pickup = (VRC_Pickup)GetComponent(typeof(VRC_Pickup));
    }

    // -------------------------------------------------------------------------
    // VRC_Pickup events
    // -------------------------------------------------------------------------

    /// <summary>
    /// Called on the local player when they pick up this object.
    /// At this point the local player has already become the owner
    /// (VRC_Pickup transfers ownership automatically on grab).
    /// </summary>
    public override void OnPickup()
    {
        // Explicit ownership transfer — required when VRC_ObjectSync is NOT present
        // and you manage synced variables manually. Safe to leave in even with ObjectSync.
        if (!Networking.IsOwner(gameObject))
        {
            Networking.SetOwner(Networking.LocalPlayer, gameObject);
        }

        PlaySound(pickupSound);
        LogDebug("OnPickup: picked up by " + GetLocalPlayerName());
    }

    /// <summary>
    /// Called on the local player when they drop this object.
    /// Ownership is NOT automatically transferred away on drop — the last holder
    /// remains owner until another player picks it up.
    /// </summary>
    public override void OnDrop()
    {
        PlaySound(dropSound);
        LogDebug("OnDrop: dropped by " + GetLocalPlayerName());
    }

    /// <summary>
    /// Called when the local player presses the Use button while holding this object.
    /// On desktop this is the left mouse button; in VR this is the trigger.
    /// NOTE: VRC_Pickup.AutoHold must be set to "Yes" for this event to fire on desktop.
    /// </summary>
    public override void OnPickupUseDown()
    {
        PlaySound(useSound);
        LogDebug("OnPickupUseDown");

        // Add your Use-button logic here.
        // To broadcast an effect to all players, use SendCustomNetworkEvent:
        //   SendCustomNetworkEvent(VRC.Udon.Common.Interfaces.NetworkEventTarget.All, "OnUsed");
        //   (Replace "OnUsed" with the actual name of your public networked method.)
    }

    /// <summary>
    /// Called when the local player releases the Use button while holding this object.
    /// NOTE: VRC_Pickup.AutoHold must be set to "Yes" for this event to fire on desktop.
    /// </summary>
    public override void OnPickupUseUp()
    {
        LogDebug("OnPickupUseUp");

        // Add your Use-button release logic here.
    }

    // -------------------------------------------------------------------------
    // Public API
    // -------------------------------------------------------------------------

    /// <summary>
    /// Forcibly drops the pickup from the local player's hand.
    /// Has no effect if this player is not currently holding the object.
    /// </summary>
    public void ForceDropPickup()
    {
        if (_pickup != null)
        {
            _pickup.Drop();
            LogDebug("ForceDropPickup called");
        }
    }

    /// <summary>
    /// Returns whether the local player is currently holding this pickup.
    /// </summary>
    public bool IsHeld()
    {
        if (_pickup == null) return false;
        return _pickup.IsHeld;
    }

    // -------------------------------------------------------------------------
    // Helpers
    // -------------------------------------------------------------------------

    private void PlaySound(AudioClip clip)
    {
        if (audioSource != null && clip != null)
        {
            audioSource.PlayOneShot(clip);
        }
    }

    private string GetLocalPlayerName()
    {
        VRCPlayerApi localPlayer = Networking.LocalPlayer;
        if (localPlayer == null || !localPlayer.IsValid()) return "Unknown";
        return localPlayer.displayName;
    }

    private void LogDebug(string message)
    {
        if (debugMode)
        {
            Debug.Log("[VRC_Pickup_Rigidbody:" + gameObject.name + "] " + message);
        }
    }
}
