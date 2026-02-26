using UdonSharp;
using UnityEngine;
using VRC.SDKBase;

/// <summary>
/// Template for modifying player movement settings.
/// Based on official VRChat documentation examples.
/// 
/// Usage:
/// 1. Attach to a GameObject with a trigger collider
/// 2. Configure speed multipliers in Inspector
/// 3. Player settings change when entering/exiting the trigger zone
/// </summary>
[UdonBehaviourSyncMode(BehaviourSyncMode.NoVariableSync)]
public class PlayerSettings : UdonSharpBehaviour
{
    [Header("Movement Settings")]
    [Tooltip("Walk speed when in zone (default: 2.0)")]
    public float walkSpeed = 2.0f;
    
    [Tooltip("Run speed when in zone (default: 4.0)")]
    public float runSpeed = 4.0f;
    
    [Tooltip("Strafe speed when in zone (default: 2.0)")]
    public float strafeSpeed = 2.0f;
    
    [Header("Jump Settings")]
    [Tooltip("Jump impulse when in zone (default: 3.0)")]
    public float jumpImpulse = 3.0f;
    
    [Tooltip("Gravity multiplier when in zone (default: 1.0)")]
    public float gravityStrength = 1.0f;
    
    [Header("Options")]
    [Tooltip("If true, settings reset when player leaves the zone")]
    public bool resetOnExit = true;
    
    [Tooltip("If true, immobilize player in zone")]
    public bool immobilizePlayer = false;
    
    // Default values for reset
    private const float DEFAULT_WALK = 2.0f;
    private const float DEFAULT_RUN = 4.0f;
    private const float DEFAULT_STRAFE = 2.0f;
    private const float DEFAULT_JUMP = 3.0f;
    private const float DEFAULT_GRAVITY = 1.0f;
    
    public override void OnPlayerTriggerEnter(VRCPlayerApi player)
    {
        // Only affect valid local player
        if (player == null || !player.IsValid() || !player.isLocal)
        {
            return;
        }

        ApplySettings(player);
    }
    
    public override void OnPlayerTriggerExit(VRCPlayerApi player)
    {
        // Only affect valid local player
        if (player == null || !player.IsValid() || !player.isLocal)
        {
            return;
        }

        if (resetOnExit)
        {
            ResetSettings(player);
        }
    }
    
    /// <summary>
    /// Apply custom settings to the player.
    /// </summary>
    private void ApplySettings(VRCPlayerApi player)
    {
        player.SetWalkSpeed(walkSpeed);
        player.SetRunSpeed(runSpeed);
        player.SetStrafeSpeed(strafeSpeed);
        player.SetJumpImpulse(jumpImpulse);
        player.SetGravityStrength(gravityStrength);
        player.Immobilize(immobilizePlayer);
    }
    
    /// <summary>
    /// Reset player to default VRChat settings.
    /// </summary>
    private void ResetSettings(VRCPlayerApi player)
    {
        player.SetWalkSpeed(DEFAULT_WALK);
        player.SetRunSpeed(DEFAULT_RUN);
        player.SetStrafeSpeed(DEFAULT_STRAFE);
        player.SetJumpImpulse(DEFAULT_JUMP);
        player.SetGravityStrength(DEFAULT_GRAVITY);
        player.Immobilize(false);
    }
    
    /// <summary>
    /// Call from Interact or other event to apply settings immediately.
    /// </summary>
    public void ApplyToLocalPlayer()
    {
        VRCPlayerApi localPlayer = Networking.LocalPlayer;
        if (localPlayer != null && localPlayer.IsValid())
        {
            ApplySettings(localPlayer);
        }
    }
    
    /// <summary>
    /// Call to reset local player to defaults.
    /// </summary>
    public void ResetLocalPlayer()
    {
        VRCPlayerApi localPlayer = Networking.LocalPlayer;
        if (localPlayer != null && localPlayer.IsValid())
        {
            ResetSettings(localPlayer);
        }
    }
}
