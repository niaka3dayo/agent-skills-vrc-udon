using UdonSharp;
using UnityEngine;
using VRC.SDKBase;
using VRC.SDK3.Persistence;

/// <summary>
/// Data persistence template for VRChat worlds (SDK 3.7.4+).
/// Demonstrates PlayerData key-value storage with save button and auto-save patterns.
///
/// Setup:
/// 1. Attach this script to a GameObject as an UdonBehaviour component
/// 2. Add the VRCEnablePersistence component to the SAME GameObject
///    (required to opt this behaviour into cloud persistence)
/// 3. Wire up UI buttons and sliders in the Inspector
/// 4. Never call Save() or read data before OnPlayerRestored fires
///
/// See references/persistence.md for PlayerData vs PlayerObject comparison.
/// </summary>
[UdonBehaviourSyncMode(BehaviourSyncMode.NoVariableSync)]
public class DataPersistence : UdonSharpBehaviour
{
    // -------------------------------------------------------------------------
    // Inspector wiring
    // -------------------------------------------------------------------------

    [Header("UI Elements")]
    [Tooltip("Button that calls SaveData() via SendCustomEvent")]
    public UnityEngine.UI.Button saveButton;

    [Tooltip("Volume slider — value is auto-saved on change")]
    public UnityEngine.UI.Slider volumeSlider;

    [Tooltip("Music toggle — value is auto-saved on change")]
    public UnityEngine.UI.Toggle musicToggle;

    [Tooltip("Label showing save status feedback to the player")]
    public UnityEngine.UI.Text statusLabel;

    [Header("Settings")]
    [Tooltip("Enable debug logging")]
    public bool debugMode = false;

    // -------------------------------------------------------------------------
    // PlayerData key constants
    // Keep keys short — they count against the 100 KB per-player storage limit.
    // -------------------------------------------------------------------------

    private const string KEY_HIGH_SCORE  = "hs";
    private const string KEY_VOLUME      = "vol";
    private const string KEY_MUSIC_ON    = "mus";
    private const string KEY_DISPLAY_NAME = "dname";

    // -------------------------------------------------------------------------
    // Default values — used when no saved data exists for a key
    // -------------------------------------------------------------------------

    private const int   DEFAULT_HIGH_SCORE   = 0;
    private const float DEFAULT_VOLUME       = 1.0f;
    private const bool  DEFAULT_MUSIC_ON     = true;
    private const string DEFAULT_DISPLAY_NAME = "";

    // -------------------------------------------------------------------------
    // Runtime state
    // -------------------------------------------------------------------------

    // Guard: true once OnPlayerRestored has fired for the local player.
    // Never read or write PlayerData before this flag is set.
    private bool _dataRestored = false;

    // In-memory copies of persistent values for fast local access
    private int    _highScore    = DEFAULT_HIGH_SCORE;
    private float  _volume       = DEFAULT_VOLUME;
    private bool   _musicOn      = DEFAULT_MUSIC_ON;
    private string _savedName    = DEFAULT_DISPLAY_NAME;

    // -------------------------------------------------------------------------
    // Lifecycle
    // -------------------------------------------------------------------------

    void Start()
    {
        // UI is disabled until data is restored so the player cannot save
        // stale defaults over real saved data.
        SetUIInteractable(false);
        SetStatus("Loading saved data...");
    }

    // -------------------------------------------------------------------------
    // VRChat persistence event
    // -------------------------------------------------------------------------

    /// <summary>
    /// Called by VRChat once the local player's persisted data is loaded from
    /// the cloud. This is the ONLY safe point to read PlayerData for the first
    /// time. Late joiners will also receive this event.
    /// </summary>
    public override void OnPlayerRestored(VRCPlayerApi player)
    {
        // OnPlayerRestored fires for every player in the instance.
        // Only process the local player's own data.
        if (player == null || !player.IsValid() || !player.isLocal)
        {
            return;
        }

        LoadAllData(player);

        _dataRestored = true;

        // Apply loaded values to UI
        ApplyToUI();

        // Re-enable UI now that real data is in memory
        SetUIInteractable(true);
        SetStatus("Data loaded.");

        LogDebug($"OnPlayerRestored: score={_highScore}, vol={_volume}, music={_musicOn}, name={_savedName}");
    }

    // -------------------------------------------------------------------------
    // Load helpers
    // -------------------------------------------------------------------------

    /// <summary>
    /// Reads all persisted keys for the local player.
    /// Missing keys fall back to their declared defaults.
    /// </summary>
    private void LoadAllData(VRCPlayerApi player)
    {
        // int — high score
        if (PlayerData.TryGetInt(player, KEY_HIGH_SCORE, out int score))
        {
            _highScore = score;
        }
        else
        {
            // No saved data exists yet; keep the compile-time default
            _highScore = DEFAULT_HIGH_SCORE;
            LogDebug("No saved high score — using default.");
        }

        // float — volume
        if (PlayerData.TryGetFloat(player, KEY_VOLUME, out float vol))
        {
            _volume = vol;
        }
        else
        {
            _volume = DEFAULT_VOLUME;
            LogDebug("No saved volume — using default.");
        }

        // bool — music enabled
        if (PlayerData.TryGetBool(player, KEY_MUSIC_ON, out bool music))
        {
            _musicOn = music;
        }
        else
        {
            _musicOn = DEFAULT_MUSIC_ON;
            LogDebug("No saved music setting — using default.");
        }

        // string — saved display name (example of string persistence)
        if (PlayerData.TryGetString(player, KEY_DISPLAY_NAME, out string name))
        {
            _savedName = name;
        }
        else
        {
            _savedName = DEFAULT_DISPLAY_NAME;
            LogDebug("No saved display name — using default.");
        }
    }

    // -------------------------------------------------------------------------
    // Save — explicit (save button)
    // -------------------------------------------------------------------------

    /// <summary>
    /// Explicit save triggered by a UI button.
    /// Wire the button's OnClick to call this via SendCustomEvent("SaveData").
    /// </summary>
    public void SaveData()
    {
        if (!_dataRestored)
        {
            SetStatus("Still loading — please wait.");
            LogDebug("SaveData() called before OnPlayerRestored.");
            return;
        }

        VRCPlayerApi local = Networking.LocalPlayer;
        if (local == null || !local.IsValid())
        {
            LogDebug("LocalPlayer not valid during SaveData().");
            return;
        }

        // Snapshot current UI state into memory before writing
        ReadFromUI();
        WriteAllData(local);

        SetStatus("Saved!");
        LogDebug($"SaveData: score={_highScore}, vol={_volume}, music={_musicOn}");
    }

    // -------------------------------------------------------------------------
    // Auto-save — called by UI element OnValueChanged events
    // -------------------------------------------------------------------------

    /// <summary>
    /// Auto-save for the volume slider.
    /// Wire the slider's OnValueChanged to call this via SendCustomEvent("OnVolumeChanged").
    /// </summary>
    public void OnVolumeChanged()
    {
        if (!_dataRestored)
        {
            return;
        }

        VRCPlayerApi local = Networking.LocalPlayer;
        if (local == null || !local.IsValid())
        {
            return;
        }

        if (volumeSlider != null)
        {
            _volume = volumeSlider.value;
            PlayerData.SetFloat(local, KEY_VOLUME, _volume);
            LogDebug($"Auto-saved volume: {_volume}");
        }
    }

    /// <summary>
    /// Auto-save for the music toggle.
    /// Wire the toggle's OnValueChanged to call this via SendCustomEvent("OnMusicToggled").
    /// </summary>
    public void OnMusicToggled()
    {
        if (!_dataRestored)
        {
            return;
        }

        VRCPlayerApi local = Networking.LocalPlayer;
        if (local == null || !local.IsValid())
        {
            return;
        }

        if (musicToggle != null)
        {
            _musicOn = musicToggle.isOn;
            PlayerData.SetBool(local, KEY_MUSIC_ON, _musicOn);
            LogDebug($"Auto-saved music: {_musicOn}");
        }
    }

    // -------------------------------------------------------------------------
    // Write helpers
    // -------------------------------------------------------------------------

    /// <summary>
    /// Writes all in-memory values to PlayerData.
    /// Only the local player can write to their own data.
    /// </summary>
    private void WriteAllData(VRCPlayerApi player)
    {
        PlayerData.SetInt(player, KEY_HIGH_SCORE, _highScore);
        PlayerData.SetFloat(player, KEY_VOLUME, _volume);
        PlayerData.SetBool(player, KEY_MUSIC_ON, _musicOn);

        // Only update the saved name if the player has one
        string displayName = player.displayName;
        if (displayName != null && displayName.Length > 0)
        {
            PlayerData.SetString(player, KEY_DISPLAY_NAME, displayName);
        }
    }

    // -------------------------------------------------------------------------
    // Score update — example of modifying a persistent int
    // -------------------------------------------------------------------------

    /// <summary>
    /// Updates the high score if the new score is higher, then persists it.
    /// Call from game logic when a round ends.
    /// </summary>
    public void TryUpdateHighScore(int newScore)
    {
        if (!_dataRestored)
        {
            return;
        }

        if (newScore <= _highScore)
        {
            return;
        }

        VRCPlayerApi local = Networking.LocalPlayer;
        if (local == null || !local.IsValid())
        {
            return;
        }

        _highScore = newScore;
        PlayerData.SetInt(local, KEY_HIGH_SCORE, _highScore);

        SetStatus("New high score: " + _highScore);
        LogDebug($"High score updated: {_highScore}");
    }

    // -------------------------------------------------------------------------
    // Public accessors (read-only — for other UdonBehaviours)
    // -------------------------------------------------------------------------

    /// <summary>Returns the in-memory high score. Valid after OnPlayerRestored.</summary>
    public int GetHighScore()
    {
        return _highScore;
    }

    /// <summary>Returns true once OnPlayerRestored has fired for the local player.</summary>
    public bool IsDataReady()
    {
        return _dataRestored;
    }

    // -------------------------------------------------------------------------
    // UI helpers
    // -------------------------------------------------------------------------

    private void ApplyToUI()
    {
        if (volumeSlider != null)
        {
            volumeSlider.value = _volume;
        }

        if (musicToggle != null)
        {
            musicToggle.isOn = _musicOn;
        }
    }

    private void ReadFromUI()
    {
        if (volumeSlider != null)
        {
            _volume = volumeSlider.value;
        }

        if (musicToggle != null)
        {
            _musicOn = musicToggle.isOn;
        }
    }

    private void SetUIInteractable(bool interactable)
    {
        if (saveButton != null)
        {
            saveButton.interactable = interactable;
        }
    }

    private void SetStatus(string message)
    {
        if (statusLabel != null)
        {
            statusLabel.text = message;
        }
    }

    private void LogDebug(string message)
    {
        if (debugMode)
        {
            Debug.Log("[DataPersistence:" + gameObject.name + "] " + message);
        }
    }
}
