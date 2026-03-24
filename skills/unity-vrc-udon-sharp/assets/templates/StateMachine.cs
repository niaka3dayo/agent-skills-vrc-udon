using UdonSharp;
using UnityEngine;
using VRC.SDKBase;
using VRC.Udon;

/// <summary>
/// State machine template for VRChat worlds.
/// Demonstrates timed state transitions using SendCustomEventDelayedSeconds,
/// network-synchronized state, and late-joiner safety.
///
/// State flow:
///   Idle (0) --[Interact]--> Active (1) --[activeDuration]--> Cooldown (2) --[cooldownDuration]--> Idle (0)
///
/// Usage:
/// 1. Attach to a GameObject in the scene
/// 2. Assign visual feedback objects per state in the Inspector
/// 3. Call Activate() from a trigger, button, or another UdonBehaviour
/// 4. Only the owner drives timed transitions; all players apply visuals via OnDeserialization
/// </summary>
[UdonBehaviourSyncMode(BehaviourSyncMode.Manual)]
public class StateMachine : UdonSharpBehaviour
{
    // -------------------------------------------------------------------------
    // State constants (int instead of enum - safer in Udon)
    // -------------------------------------------------------------------------
    private const int STATE_IDLE     = 0;
    private const int STATE_ACTIVE   = 1;
    private const int STATE_COOLDOWN = 2;

    // -------------------------------------------------------------------------
    // Inspector fields
    // -------------------------------------------------------------------------
    [Header("Timing")]
    [Tooltip("How long the Active state lasts before moving to Cooldown (seconds)")]
    public float activeDuration = 3f;

    [Tooltip("How long the Cooldown state lasts before returning to Idle (seconds)")]
    public float cooldownDuration = 2f;

    [Header("Visual Feedback")]
    [Tooltip("GameObjects to show/hide when in Idle state")]
    public GameObject[] idleObjects;

    [Tooltip("GameObjects to show/hide when in Active state")]
    public GameObject[] activeObjects;

    [Tooltip("GameObjects to show/hide when in Cooldown state")]
    public GameObject[] cooldownObjects;

    [Header("Audio")]
    [Tooltip("Audio source for state change sounds")]
    public AudioSource audioSource;

    [Tooltip("Sound played when entering Active state")]
    public AudioClip activateSound;

    [Tooltip("Sound played when entering Cooldown state")]
    public AudioClip cooldownSound;

    [Tooltip("Sound played when returning to Idle state")]
    public AudioClip idleSound;

    [Header("Debug")]
    [Tooltip("Enable debug logging to the Unity console")]
    public bool debugMode = false;

    // -------------------------------------------------------------------------
    // Synced variables
    // -------------------------------------------------------------------------
    [UdonSynced]
    private int _currentState = STATE_IDLE;

    // -------------------------------------------------------------------------
    // Local (non-synced) state
    // -------------------------------------------------------------------------
    // Prevents side effects (audio) from firing when a late joiner first
    // receives the synced state via OnDeserialization.
    private bool _isInitialized = false;

    // Guards against scheduling multiple concurrent timers (e.g. rapid Activate calls)
    private bool _timerPending = false;

    // -------------------------------------------------------------------------
    // Unity lifecycle
    // -------------------------------------------------------------------------
    void Start()
    {
        // Apply the initial visual state without side effects.
        // _isInitialized remains false here; it is set to true only after the
        // first OnDeserialization (late joiners) or the first local state change.
        ApplyVisuals(_currentState);
    }

    // -------------------------------------------------------------------------
    // Public API
    // -------------------------------------------------------------------------

    /// <summary>
    /// Trigger the state machine from Idle -> Active.
    /// No-ops if not currently in Idle state.
    /// </summary>
    public void Activate()
    {
        if (_currentState != STATE_IDLE)
        {
            LogDebug("Activate() ignored: not in Idle state");
            return;
        }

        TakeOwnershipIfNeeded();
        EnterState(STATE_ACTIVE);
    }

    /// <summary>
    /// Force reset to Idle from any state (owner only).
    /// Useful for emergency stop buttons or admin controls.
    /// </summary>
    public void ForceIdle()
    {
        TakeOwnershipIfNeeded();
        _timerPending = false;
        EnterState(STATE_IDLE);
    }

    /// <summary>
    /// Returns the current state constant (STATE_IDLE, STATE_ACTIVE, STATE_COOLDOWN).
    /// </summary>
    public int GetCurrentState()
    {
        return _currentState;
    }

    // -------------------------------------------------------------------------
    // Interact (VRChat built-in)
    // -------------------------------------------------------------------------

    /// <summary>
    /// Called when a player clicks / interacts with this object.
    /// Activates the state machine if it is currently Idle.
    /// </summary>
    public override void Interact()
    {
        Activate();
    }

    // -------------------------------------------------------------------------
    // State transitions
    // -------------------------------------------------------------------------

    /// <summary>
    /// Core state transition. Sets the synced variable, serializes, applies
    /// visuals/audio, and schedules the next timed transition if required.
    /// Must be called only by the owner.
    /// </summary>
    private void EnterState(int newState)
    {
        _isInitialized = true;
        _currentState  = newState;

        RequestSerialization();
        ApplyVisuals(newState);
        PlayStateSound(newState);

        LogDebug("Entered state: " + StateToString(newState));

        // Schedule the next automatic transition
        if (newState == STATE_ACTIVE)
        {
            _timerPending = true;
            SendCustomEventDelayedSeconds(nameof(_OnActiveDurationElapsed), activeDuration);
        }
        else if (newState == STATE_COOLDOWN)
        {
            _timerPending = true;
            SendCustomEventDelayedSeconds(nameof(_OnCooldownDurationElapsed), cooldownDuration);
        }
        else
        {
            _timerPending = false;
        }
    }

    /// <summary>
    /// Callback fired by SendCustomEventDelayedSeconds after activeDuration.
    /// Only the owner should act on this; non-owners receive the result via OnDeserialization.
    /// </summary>
    public void _OnActiveDurationElapsed()
    {
        // Guard: only proceed if we still own this object and state has not changed externally
        if (!Networking.IsOwner(gameObject))
        {
            LogDebug("_OnActiveDurationElapsed: skipped (not owner)");
            return;
        }

        if (_currentState != STATE_ACTIVE)
        {
            LogDebug("_OnActiveDurationElapsed: skipped (state changed before timer fired)");
            return;
        }

        _timerPending = false;
        EnterState(STATE_COOLDOWN);
    }

    /// <summary>
    /// Callback fired by SendCustomEventDelayedSeconds after cooldownDuration.
    /// Only the owner should act on this.
    /// </summary>
    public void _OnCooldownDurationElapsed()
    {
        if (!Networking.IsOwner(gameObject))
        {
            LogDebug("_OnCooldownDurationElapsed: skipped (not owner)");
            return;
        }

        if (_currentState != STATE_COOLDOWN)
        {
            LogDebug("_OnCooldownDurationElapsed: skipped (state changed before timer fired)");
            return;
        }

        _timerPending = false;
        EnterState(STATE_IDLE);
    }

    // -------------------------------------------------------------------------
    // Network callbacks
    // -------------------------------------------------------------------------

    /// <summary>
    /// Called when synced data is received from the network.
    /// The very first call on join is the late-joiner state restore.
    /// </summary>
    public override void OnDeserialization()
    {
        // Suppress side effects (audio) on the first sync (late joiner restore).
        // Visuals are always applied so the late joiner sees the correct state.
        bool suppressSideEffects = !_isInitialized;
        _isInitialized = true;

        ApplyVisuals(_currentState);

        if (!suppressSideEffects)
        {
            PlayStateSound(_currentState);
        }

        LogDebug("OnDeserialization: state = " + StateToString(_currentState)
                 + (suppressSideEffects ? " (late-joiner restore, audio suppressed)" : ""));
    }

    /// <summary>
    /// Called when a new player joins.
    /// The owner re-serializes to push current state to the newcomer.
    /// </summary>
    public override void OnPlayerJoined(VRCPlayerApi player)
    {
        if (player == null || !player.IsValid()) return;

        if (Networking.IsOwner(gameObject))
        {
            RequestSerialization();
            LogDebug("OnPlayerJoined: re-serialized for " + player.displayName);
        }
    }

    /// <summary>
    /// Called when ownership of this object is transferred.
    /// The new owner resumes responsibility for timed transitions.
    /// </summary>
    public override void OnOwnershipTransferred(VRCPlayerApi player)
    {
        if (player == null || !player.IsValid()) return;

        LogDebug("Ownership transferred to: " + player.displayName);

        // If this client is now the new owner and a timer-driven state is active,
        // resume the transition. The timer fires once more but the guards in the
        // callback methods ensure only one transition occurs.
        if (Networking.IsOwner(gameObject))
        {
            if (_currentState == STATE_ACTIVE && !_timerPending)
            {
                _timerPending = true;
                SendCustomEventDelayedSeconds(nameof(_OnActiveDurationElapsed), activeDuration);
                LogDebug("OnOwnershipTransferred: resumed Active timer");
            }
            else if (_currentState == STATE_COOLDOWN && !_timerPending)
            {
                _timerPending = true;
                SendCustomEventDelayedSeconds(nameof(_OnCooldownDurationElapsed), cooldownDuration);
                LogDebug("OnOwnershipTransferred: resumed Cooldown timer");
            }
        }
    }

    // -------------------------------------------------------------------------
    // Helpers
    // -------------------------------------------------------------------------

    /// <summary>
    /// Takes ownership of this object if the local player is not already the owner.
    /// Must be called before modifying any [UdonSynced] variable.
    /// </summary>
    private void TakeOwnershipIfNeeded()
    {
        if (!Networking.IsOwner(gameObject))
        {
            Networking.SetOwner(Networking.LocalPlayer, gameObject);
        }
    }

    /// <summary>
    /// Enables/disables the correct visual GameObjects for the given state.
    /// Safe to call at any time, including during initialization.
    /// </summary>
    private void ApplyVisuals(int state)
    {
        SetObjectsActive(idleObjects,     state == STATE_IDLE);
        SetObjectsActive(activeObjects,   state == STATE_ACTIVE);
        SetObjectsActive(cooldownObjects, state == STATE_COOLDOWN);
    }

    /// <summary>
    /// Activates or deactivates each non-null GameObject in the array.
    /// </summary>
    private void SetObjectsActive(GameObject[] objects, bool active)
    {
        if (objects == null) return;

        for (int i = 0; i < objects.Length; i++)
        {
            if (objects[i] != null)
            {
                objects[i].SetActive(active);
            }
        }
    }

    /// <summary>
    /// Plays the audio clip associated with entering the given state.
    /// No-ops if audioSource or the clip is not assigned.
    /// </summary>
    private void PlayStateSound(int state)
    {
        if (audioSource == null) return;

        AudioClip clip = null;
        if (state == STATE_IDLE)
        {
            clip = idleSound;
        }
        else if (state == STATE_ACTIVE)
        {
            clip = activateSound;
        }
        else if (state == STATE_COOLDOWN)
        {
            clip = cooldownSound;
        }

        if (clip != null)
        {
            audioSource.PlayOneShot(clip);
        }
    }

    /// <summary>
    /// Returns a human-readable name for the given state constant.
    /// </summary>
    private string StateToString(int state)
    {
        if (state == STATE_IDLE)     return "Idle";
        if (state == STATE_ACTIVE)   return "Active";
        if (state == STATE_COOLDOWN) return "Cooldown";
        return "Unknown(" + state + ")";
    }

    private void LogDebug(string message)
    {
        if (debugMode)
        {
            Debug.Log("[StateMachine:" + gameObject.name + "] " + message);
        }
    }
}
