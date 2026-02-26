using UdonSharp;
using UnityEngine;
using VRC.SDKBase;
using VRC.Udon;

/// <summary>
/// Basic interaction template for VRChat objects.
/// Handles player interaction events and provides common functionality.
/// </summary>
public class BasicInteraction : UdonSharpBehaviour
{
    [Header("Target Objects")]
    [Tooltip("Objects to toggle when interacted")]
    public GameObject[] targetObjects;

    [Header("Audio")]
    [Tooltip("Audio source for interaction sounds")]
    public AudioSource audioSource;
    [Tooltip("Sound to play on interaction")]
    public AudioClip interactSound;

    [Header("Settings")]
    [Tooltip("Cooldown between interactions in seconds")]
    public float cooldownTime = 0.5f;

    private bool isToggled = false;
    private float lastInteractTime = -999f;

    void Start()
    {
        // Initialize target objects state
        UpdateTargetObjects();
    }

    public override void Interact()
    {
        // Check cooldown
        if (Time.time - lastInteractTime < cooldownTime)
        {
            return;
        }
        lastInteractTime = Time.time;

        // Toggle state
        isToggled = !isToggled;

        // Play sound
        PlayInteractSound();

        // Update objects
        UpdateTargetObjects();

        // Log for debugging (remove in production)
        Debug.Log($"[BasicInteraction] Toggled to: {isToggled}");
    }

    private void UpdateTargetObjects()
    {
        if (targetObjects == null) return;

        foreach (GameObject obj in targetObjects)
        {
            if (obj != null)
            {
                obj.SetActive(isToggled);
            }
        }
    }

    private void PlayInteractSound()
    {
        if (audioSource != null && interactSound != null)
        {
            audioSource.PlayOneShot(interactSound);
        }
    }

    /// <summary>
    /// Public method to set toggle state programmatically.
    /// </summary>
    public void SetState(bool newState)
    {
        isToggled = newState;
        UpdateTargetObjects();
    }

    /// <summary>
    /// Public method to get current toggle state.
    /// </summary>
    public bool GetState()
    {
        return isToggled;
    }
}
