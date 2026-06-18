using UdonSharp;
using UnityEngine;
using VRC.Dynamics;
using VRC.SDKBase;
using VRC.Udon;

/// <summary>
/// VRCContactReceiver template for VRChat worlds (SDK 3.10.0+).
/// Demonstrates OnContactEnter/Exit, avatar vs world object detection,
/// debounce cooldown, and visual/audio feedback.
///
/// Setup:
/// 1. Add "VRC Contact Receiver" component to this GameObject.
/// 2. Set Shape Type to Sphere, Capsule, or Box. Capsule uses Height; Box uses Vector3 Size.
/// 3. Configure Radius/Size, content usage, and collision tags.
/// 4. Assign the public fields below in the Inspector.
///
/// See references/dynamics.md "Contacts" for full API documentation.
/// </summary>
[UdonBehaviourSyncMode(BehaviourSyncMode.None)]
public class ContactReceiver : UdonSharpBehaviour
{
    [Header("Visual Feedback")]
    [Tooltip("Objects to activate while contact is held")]
    public GameObject[] activeObjects;

    [Tooltip("Objects to deactivate while contact is held")]
    public GameObject[] inactiveObjects;

    [Tooltip("Renderer whose material is swapped on contact")]
    public Renderer targetRenderer;

    [Tooltip("Material shown when no contact is present")]
    public Material idleMaterial;

    [Tooltip("Material shown while contact is active")]
    public Material activeMaterial;

    [Header("Audio")]
    [Tooltip("Audio source for contact sounds")]
    public AudioSource audioSource;

    [Tooltip("Sound to play when contact begins")]
    public AudioClip enterSound;

    [Tooltip("Sound to play when contact ends")]
    public AudioClip exitSound;

    [Header("Settings")]
    [Tooltip("Minimum seconds between repeated OnContactEnter triggers")]
    public float cooldownTime = 0.5f;

    [Tooltip("If true, only accept contacts from avatar-owned Contact Senders")]
    public bool avatarOnlyMode = false;

    [Tooltip("Enable debug logging")]
    public bool debugMode = false;

    // How many senders are currently overlapping this receiver.
    // OnContactEnter increments; OnContactExit decrements.
    private int _contactCount = 0;

    // Timestamp of the last accepted OnContactEnter to debounce rapid triggers.
    private float _lastEnterTime = -999f;

    // Cached active state so ApplyVisual is idempotent when count stays > 0.
    private bool _isActive = false;

    // -------------------------------------------------------------------------
    // Unity lifecycle
    // -------------------------------------------------------------------------

    void Start()
    {
        // Apply the idle visual state on world load.
        ApplyVisual(false);
    }

    // -------------------------------------------------------------------------
    // VRCContactReceiver callbacks
    // Contact callbacks must use 'override' when declared on UdonSharpBehaviour.
    // -------------------------------------------------------------------------

    /// <summary>
    /// Called once when a new Contact Sender enters the receiver volume.
    /// </summary>
    public override void OnContactEnter(ContactEnterInfo info)
    {
        ContactSenderProxy sender = info.contactSender;
        ContactReceiverProxy receiver = info.contactReceiver;
        if (!sender.isValid || !receiver.isValid)
        {
            return;
        }

        // Optionally filter out world/item senders.
        if (avatarOnlyMode && sender.usage != DynamicsUsage.Avatar)
        {
            return;
        }

        _contactCount++;

        // Debounce: ignore rapid re-entry within cooldownTime seconds.
        if (Time.time - _lastEnterTime < cooldownTime)
        {
            return;
        }
        _lastEnterTime = Time.time;

        if (!_isActive)
        {
            _isActive = true;
            ApplyVisual(true);
            PlaySound(enterSound);
        }

        // Log source type and player name for debugging.
        if (debugMode)
        {
            string playerName = (sender.player != null && sender.player.IsValid())
                ? sender.player.displayName
                : "none";
            Debug.Log($"[ContactReceiver:{gameObject.name}] Enter usage={sender.usage} player={playerName} point={info.contactPoint}");
        }
    }

    /// <summary>
    /// Called once when a Contact Sender leaves the receiver volume.
    /// </summary>
    public override void OnContactExit(ContactExitInfo info)
    {
        ContactSenderProxy sender = info.contactSender;
        ContactReceiverProxy receiver = info.contactReceiver;
        if (!sender.isValid || !receiver.isValid)
        {
            return;
        }

        if (avatarOnlyMode && sender.usage != DynamicsUsage.Avatar)
        {
            return;
        }

        _contactCount--;

        // Clamp to zero to guard against missed Enter events (e.g. late join).
        if (_contactCount < 0)
        {
            _contactCount = 0;
        }

        // Only deactivate when the last sender has left.
        if (_contactCount == 0 && _isActive)
        {
            _isActive = false;
            ApplyVisual(false);
            PlaySound(exitSound);

            if (debugMode)
            {
                Debug.Log($"[ContactReceiver:{gameObject.name}] Exit (all senders gone) usage={sender.usage}");
            }
        }
    }

    // -------------------------------------------------------------------------
    // Visual helpers
    // -------------------------------------------------------------------------

    /// <summary>
    /// Applies visual state based on whether contact is active.
    /// Safe to call at any time; no audio or other side effects.
    /// </summary>
    private void ApplyVisual(bool contactActive)
    {
        // Enable objects that should appear while contact is held.
        if (activeObjects != null)
        {
            int len = activeObjects.Length;
            for (int i = 0; i < len; i++)
            {
                if (activeObjects[i] != null)
                {
                    activeObjects[i].SetActive(contactActive);
                }
            }
        }

        // Disable objects that should hide while contact is held.
        if (inactiveObjects != null)
        {
            int len = inactiveObjects.Length;
            for (int i = 0; i < len; i++)
            {
                if (inactiveObjects[i] != null)
                {
                    inactiveObjects[i].SetActive(!contactActive);
                }
            }
        }

        // Swap material on the target renderer.
        if (targetRenderer != null)
        {
            Material mat = contactActive ? activeMaterial : idleMaterial;
            if (mat != null)
            {
                targetRenderer.material = mat;
            }
        }
    }

    // -------------------------------------------------------------------------
    // Audio helpers
    // -------------------------------------------------------------------------

    private void PlaySound(AudioClip clip)
    {
        if (audioSource != null && clip != null)
        {
            audioSource.PlayOneShot(clip);
        }
    }

    // -------------------------------------------------------------------------
    // Public API (for external UdonBehaviours)
    // -------------------------------------------------------------------------

    /// <summary>
    /// Returns true while at least one Contact Sender overlaps the receiver.
    /// </summary>
    public bool IsContacted()
    {
        return _isActive;
    }

    /// <summary>
    /// Returns the number of Contact Senders currently overlapping the receiver.
    /// </summary>
    public int GetContactCount()
    {
        return _contactCount;
    }

    /// <summary>
    /// Resets internal contact state (e.g. call from OnPlayerLeft to clean up
    /// if a player disconnects while their avatar is overlapping the receiver).
    /// </summary>
    public void ResetContactState()
    {
        _contactCount = 0;

        if (_isActive)
        {
            _isActive = false;
            ApplyVisual(false);
        }

        if (debugMode)
        {
            Debug.Log($"[ContactReceiver:{gameObject.name}] State reset");
        }
    }
}
