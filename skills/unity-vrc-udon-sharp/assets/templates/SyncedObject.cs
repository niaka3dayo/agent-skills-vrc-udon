using UdonSharp;
using UnityEngine;
using VRC.SDKBase;
using VRC.Udon;

/// <summary>
/// Synchronized object template for multiplayer VRChat worlds.
/// Demonstrates proper network synchronization patterns with late-joiner safety.
/// See references/networking.md "Side-Effect Guard for Late Joiners" for details.
/// </summary>
[UdonBehaviourSyncMode(BehaviourSyncMode.Manual)]
public class SyncedObject : UdonSharpBehaviour
{
    [Header("Target Objects")]
    [Tooltip("Objects to control based on synced state")]
    public GameObject[] controlledObjects;

    [Header("Audio")]
    public AudioSource audioSource;
    public AudioClip toggleSound;

    [Header("Debug")]
    [Tooltip("Enable debug logging")]
    public bool debugMode = false;

    // Synced variables - these are synchronized across all players
    [UdonSynced, FieldChangeCallback(nameof(IsActive))]
    private bool _isActive = false;

    [UdonSynced]
    private int lastInteractorId = -1;

    // Late-joiner safety: prevents side effects (audio, animations) from
    // firing on the first OnDeserialization when a player joins mid-session.
    private bool _isInitialized = false;

    /// <summary>
    /// Property wrapper for synced _isActive field.
    /// Called automatically when the synced value changes.
    /// </summary>
    public bool IsActive
    {
        get => _isActive;
        set
        {
            _isActive = value;
            OnStateChanged();
        }
    }

    void Start()
    {
        // Apply initial visual state only (no side effects).
        // _isInitialized stays false until first OnDeserialization,
        // which is the late-joiner guard boundary.
        ApplyVisualState();
    }

    public override void Interact()
    {
        // Local interaction always marks as initialized (instance master
        // may never receive OnDeserialization for their own changes)
        _isInitialized = true;

        // Take ownership before modifying synced variables
        if (!Networking.IsOwner(gameObject))
        {
            Networking.SetOwner(Networking.LocalPlayer, gameObject);
        }

        // Store who interacted
        lastInteractorId = Networking.LocalPlayer.playerId;

        // Toggle state
        IsActive = !IsActive;

        // Request network sync
        RequestSerialization();

        LogDebug($"Interact: IsActive = {IsActive}, Owner = {Networking.GetOwner(gameObject).displayName}");
    }

    /// <summary>
    /// Called when IsActive changes (locally or from network).
    /// Plays side effects only after initialization (late-joiner safe).
    /// </summary>
    private void OnStateChanged()
    {
        // Always update visuals (safe for late joiners)
        ApplyVisualState();

        // Side effects only after initialization to prevent
        // audio/animation replay when a late joiner receives initial sync
        if (_isInitialized)
        {
            if (audioSource != null && toggleSound != null)
            {
                audioSource.PlayOneShot(toggleSound);
            }
        }

        LogDebug($"State changed to: {_isActive}");
    }

    /// <summary>
    /// Applies visual state without side effects. Safe to call during
    /// initialization and late-joiner deserialization.
    /// </summary>
    private void ApplyVisualState()
    {
        if (controlledObjects != null)
        {
            foreach (GameObject obj in controlledObjects)
            {
                if (obj != null)
                {
                    obj.SetActive(_isActive);
                }
            }
        }
    }

    /// <summary>
    /// Called when synced data is received from the network.
    /// The first call is the initial sync for late joiners.
    /// </summary>
    public override void OnDeserialization()
    {
        if (!_isInitialized)
        {
            // First deserialization (late joiner): mark as initialized
            // Side effects are already guarded in OnStateChanged via _isInitialized
            _isInitialized = true;
        }

        LogDebug($"Deserialization: IsActive = {_isActive}, LastInteractor = {lastInteractorId}");
    }

    /// <summary>
    /// Called when a new player joins the instance.
    /// </summary>
    public override void OnPlayerJoined(VRCPlayerApi player)
    {
        if (player == null || !player.IsValid()) return;

        // If we're the owner, send current state to new player
        if (Networking.IsOwner(gameObject))
        {
            RequestSerialization();
            LogDebug($"Syncing state for new player: {player.displayName}");
        }
    }

    /// <summary>
    /// Called when ownership of this object changes.
    /// </summary>
    public override void OnOwnershipTransferred(VRCPlayerApi player)
    {
        if (player == null || !player.IsValid()) return;
        LogDebug($"Ownership transferred to: {player.displayName}");
    }

    /// <summary>
    /// Public method to set state (for external scripts).
    /// </summary>
    public void SetState(bool newState)
    {
        _isInitialized = true;

        if (!Networking.IsOwner(gameObject))
        {
            Networking.SetOwner(Networking.LocalPlayer, gameObject);
        }

        IsActive = newState;
        RequestSerialization();
    }

    /// <summary>
    /// Public method to get current state.
    /// </summary>
    public bool GetState()
    {
        return _isActive;
    }

    /// <summary>
    /// Get the player who last interacted with this object.
    /// </summary>
    public VRCPlayerApi GetLastInteractor()
    {
        return VRCPlayerApi.GetPlayerById(lastInteractorId);
    }

    private void LogDebug(string message)
    {
        if (debugMode)
        {
            Debug.Log($"[SyncedObject:{gameObject.name}] {message}");
        }
    }
}
