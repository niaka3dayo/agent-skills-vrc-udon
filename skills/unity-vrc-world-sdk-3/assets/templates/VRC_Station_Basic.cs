using UdonSharp;
using UnityEngine;
using VRC.SDKBase;
using VRC.Udon;

/// <summary>
/// Template for controlling a VRC_Station component from UdonSharp.
///
/// Requirements:
///   - This GameObject MUST have a Collider (required for Interact to fire).
///   - Add a VRC_Station component to the same or a child GameObject.
///
/// Station behaviour notes:
///   - OnStationEntered and OnStationExited fire on ALL clients for any player
///     who enters or exits the station.
///   - Disable Station Exit prevents the default exit gesture; you must call
///     station.ExitStation(player) manually from Udon to release the player.
///   - ImmobilizeForVehicle: Use this mobility mode when the station is on a
///     moving platform (e.g. vehicle). The player view follows the station transform.
///   - Real-time lights and post-processing are unavailable on Quest — ensure
///     any visual effects triggered here use baked or lightweight alternatives.
///
/// Sync mode note:
///   BehaviourSyncMode.None is intentional — this script has no UdonSynced
///   variables. All state tracking (_isOccupied) is local-only; see the field
///   comment below for late-joiner implications.
///
/// Usage:
///   1. Add this script, a Collider, and VRC_Station to the same GameObject.
///   2. Assign the stationComponent field in the Inspector.
///   3. Optionally set PlayerMobility in the Inspector to control movement.
///   4. Extend OnStationEntered / OnStationExited with your world logic.
/// </summary>
[UdonBehaviourSyncMode(BehaviourSyncMode.None)]
public class VRC_Station_Basic : UdonSharpBehaviour
{
    [Header("Station Reference")]
    [Tooltip("VRC_Station component to control. Must be on the same or a child GameObject.")]
    public VRCStation stationComponent;

    [Header("Mobility Settings")]
    [Tooltip(
        "Mobile = player can move freely.\n" +
        "Immobilize = player is fixed at the entry point (chairs, benches).\n" +
        "ImmobilizeForVehicle = fixed, but view follows the station (vehicles).")]
    public VRCStation.Mobility playerMobility = VRCStation.Mobility.Immobilize;

    [Header("Audio Feedback")]
    [Tooltip("Audio source for enter and exit sounds")]
    public AudioSource audioSource;

    [Tooltip("Sound played when any player enters this station")]
    public AudioClip enterSound;

    [Tooltip("Sound played when any player exits this station")]
    public AudioClip exitSound;

    [Header("Debug")]
    [Tooltip("Enable debug logging to the Unity console")]
    public bool debugMode = false;

    // Tracks whether a player is currently in this station (local approximation only).
    // This value is NOT synced across the network. Late-joining players always start
    // with _isOccupied = false and will only see the correct state after the next
    // OnStationEntered/OnStationExited event fires.
    // To persist occupancy state for late joiners, add:
    //   [UdonSynced] private bool _isOccupiedSynced;
    // and call RequestSerialization() inside OnStationEntered/OnStationExited.
    // Switch BehaviourSyncMode to Manual when adding UdonSynced variables.
    private bool _isOccupied = false;

    // -------------------------------------------------------------------------
    // Unity lifecycle
    // -------------------------------------------------------------------------

    private void Start()
    {
        // Apply the configured mobility mode to the station at startup.
        if (stationComponent != null)
        {
            stationComponent.PlayerMobility = playerMobility;
        }
    }

    // -------------------------------------------------------------------------
    // VRChat interaction (seat the local player on Interact)
    // -------------------------------------------------------------------------

    /// <summary>
    /// Called when the local player interacts with (clicks) this object.
    /// Seats the local player in the station.
    /// </summary>
    public override void Interact()
    {
        if (stationComponent == null)
        {
            LogDebug("Interact: stationComponent is not assigned");
            return;
        }

        VRCPlayerApi localPlayer = Networking.LocalPlayer;
        if (localPlayer == null || !localPlayer.IsValid()) return;

        stationComponent.UseStation(localPlayer);
        LogDebug("Interact: " + localPlayer.displayName + " entering station");
    }

    // -------------------------------------------------------------------------
    // VRC_Station events
    // -------------------------------------------------------------------------

    /// <summary>
    /// Called on ALL clients when any player enters this station.
    /// Use player.isLocal to distinguish the sitting player from observers.
    /// </summary>
    public override void OnStationEntered(VRCPlayerApi player)
    {
        if (player == null || !player.IsValid()) return;

        _isOccupied = true;
        PlaySound(enterSound);
        LogDebug("OnStationEntered: " + player.displayName + " (local=" + player.isLocal + ")");

        // Add your on-enter logic here.
        // Example: disable the Interact prompt while occupied
        //   DisableInteractive = true;
    }

    /// <summary>
    /// Called on ALL clients when any player exits this station.
    /// </summary>
    public override void OnStationExited(VRCPlayerApi player)
    {
        if (player == null || !player.IsValid()) return;

        _isOccupied = false;
        PlaySound(exitSound);
        LogDebug("OnStationExited: " + player.displayName + " (local=" + player.isLocal + ")");

        // Add your on-exit logic here.
        // Example: re-enable the Interact prompt
        //   DisableInteractive = false;
    }

    // -------------------------------------------------------------------------
    // Public API
    // -------------------------------------------------------------------------

    /// <summary>
    /// Ejects the specified player from this station.
    /// Call this to force-exit a player when Disable Station Exit is enabled.
    /// </summary>
    public void EjectPlayer(VRCPlayerApi player)
    {
        if (stationComponent == null || player == null || !player.IsValid()) return;
        stationComponent.ExitStation(player);
        LogDebug("EjectPlayer: ejecting " + player.displayName);
    }

    /// <summary>
    /// Changes the mobility mode at runtime.
    /// Must be called before the player enters for it to take effect.
    /// </summary>
    public void SetMobility(VRCStation.Mobility mobility)
    {
        playerMobility = mobility;
        if (stationComponent != null)
        {
            stationComponent.PlayerMobility = mobility;
        }
        LogDebug("SetMobility: " + mobility.ToString());
    }

    /// <summary>
    /// Returns whether any player is currently in this station.
    /// This is a local approximation based on received events and may be
    /// briefly inconsistent for late-joining players.
    /// </summary>
    public bool IsOccupied()
    {
        return _isOccupied;
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

    private void LogDebug(string message)
    {
        if (debugMode)
        {
            Debug.Log("[VRC_Station_Basic:" + gameObject.name + "] " + message);
        }
    }
}
