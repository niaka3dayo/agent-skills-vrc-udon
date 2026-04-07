# UdonSharp UI/Canvas Patterns

Immobilize guard, avatar-scale-aware UI, FOV-responsive positioning, platform-adaptive layout,
dynamic player list, scroll input abstraction, lookup-table localization, toggle-animator bridge,
settings persistence via PlayerObject, and listener-based menu event system.

## 1. Immobilize Guard Pattern

When the local player interacts with dropdown menus or scroll views, accidental movement
can disrupt the UI experience. The Immobilize Guard locks player locomotion while UI
is active and automatically releases it when the panel closes.

```csharp
using UdonSharp;
using UnityEngine;
using VRC.SDKBase;

/// <summary>
/// Attach to the root Canvas or panel GameObject.
/// Enable/disable the GameObject to toggle the guard.
/// </summary>
public class ImmobilizeGuard : UdonSharpBehaviour
{
    void OnEnable()
    {
        VRCPlayerApi local = Networking.LocalPlayer;
        if (local != null)
        {
            local.Immobilize(true);
        }
    }

    void OnDisable()
    {
        VRCPlayerApi local = Networking.LocalPlayer;
        if (local != null)
        {
            local.Immobilize(false);
        }
    }
}
```

> **Key notes:**
> - Always pair `Immobilize(true)` with a guaranteed `Immobilize(false)` path.
> - `OnDisable` fires when the GameObject is deactivated *and* when the player leaves the world, so there is no risk of permanent lock.
> - Combine with a semi-transparent background overlay to visually indicate the locked state.

---

## 2. Avatar-Scale-Aware UI

VRChat avatars vary wildly in scale. A Canvas that looks correct at default height may be
unreachable for tiny avatars or clip into giant ones. This pattern reads the local player's
head tracking height and rescales the Canvas RectTransform proportionally.

```csharp
using UdonSharp;
using UnityEngine;
using VRC.SDKBase;

[UdonBehaviourSyncMode(BehaviourSyncMode.NoVariableSync)]
public class AvatarScaleUI : UdonSharpBehaviour
{
    [Header("Configuration")]
    [SerializeField] private RectTransform canvasRect;

    [Tooltip("Reference avatar eye height in meters (default VRChat avatar)")]
    [SerializeField] private float referenceHeight = 1.65f;

    [Tooltip("Minimum scale clamp to prevent near-invisible UI")]
    [SerializeField] private float minScale = 0.3f;

    [Tooltip("Maximum scale clamp to prevent oversized UI")]
    [SerializeField] private float maxScale = 3.0f;

    private bool _initialized = false;

    void OnEnable()
    {
        Initialize();
        ApplyScale();
    }

    void Start()
    {
        Initialize();
        ApplyScale();
    }

    private void Initialize()
    {
        if (_initialized) return;
        _initialized = true;

        if (canvasRect == null)
        {
            canvasRect = GetComponent<RectTransform>();
        }
    }

    /// <summary>
    /// Call this when the avatar changes or periodically to keep the UI in sync.
    /// </summary>
    public void ApplyScale()
    {
        Initialize();

        VRCPlayerApi local = Networking.LocalPlayer;
        if (local == null) return;
        if (canvasRect == null) return;

        // Head tracking Y position approximates current avatar eye height
        VRCPlayerApi.TrackingData headData =
            local.GetTrackingData(VRCPlayerApi.TrackingDataType.Head);
        float currentHeight = headData.position.y;

        // Avoid division by zero for extremely small avatars
        if (currentHeight < 0.01f) currentHeight = 0.01f;

        float scaleFactor = currentHeight / referenceHeight;
        scaleFactor = Mathf.Clamp(scaleFactor, minScale, maxScale);

        canvasRect.localScale = Vector3.one * scaleFactor;
    }
}
```

> **Key notes:**
> - `GetTrackingData(Head).position.y` returns the world-space Y of the player's head, which correlates with avatar scale.
> - Clamp the scale factor to avoid UI becoming invisible (tiny avatars) or enormous (giant avatars).
> - Call `ApplyScale()` from an external trigger (e.g., avatar change event or a periodic timer) since there is no built-in "avatar changed" callback in UdonSharp.

---

## 3. FOV-Responsive UI Positioning

When players change their camera FOV (e.g., through VRChat camera zoom settings), world-space
UI panels can drift out of view. This pattern adjusts the Canvas offset using trigonometric
FOV calculations and hooks `OnVRCCameraSettingsChanged()` for live updates.

```csharp
using UdonSharp;
using UnityEngine;
using VRC.SDKBase;

[UdonBehaviourSyncMode(BehaviourSyncMode.NoVariableSync)]
public class FovResponsiveUI : UdonSharpBehaviour
{
    [Header("References")]
    [SerializeField] private Transform uiAnchor;

    [Header("Configuration")]
    [Tooltip("Distance from camera to UI panel in meters")]
    [SerializeField] private float baseDistance = 2.0f;

    [Tooltip("Reference FOV that the UI was designed for")]
    [SerializeField] private float referenceFov = 60.0f;

    private bool _isVR = false;

    void Start()
    {
        VRCPlayerApi local = Networking.LocalPlayer;
        if (local != null)
        {
            _isVR = local.IsUserInVR();
        }

        RecalculatePosition();
    }

    /// <summary>
    /// Called by VRChat when camera settings (FOV, near/far plane) change.
    /// </summary>
    public override void OnVRCCameraSettingsChanged()
    {
        RecalculatePosition();
    }

    private void RecalculatePosition()
    {
        if (uiAnchor == null) return;

        // In VR, FOV is determined by the headset and cannot be read reliably.
        // Apply distance adjustment only on desktop.
        if (_isVR) return;

        float currentFov = 60.0f;
        Camera screenCam = VRCCameraSettings.ScreenCamera;
        if (screenCam != null)
        {
            currentFov = screenCam.fieldOfView;
        }

        // Compute viewport-relative scale factor
        float refTan = Mathf.Tan((referenceFov / 2.0f) * Mathf.Deg2Rad);
        float curTan = Mathf.Tan((currentFov / 2.0f) * Mathf.Deg2Rad);

        // Avoid division by zero
        if (curTan < 0.001f) curTan = 0.001f;

        float distanceFactor = refTan / curTan;
        float adjustedDistance = baseDistance * distanceFactor;

        uiAnchor.localPosition = new Vector3(
            uiAnchor.localPosition.x,
            uiAnchor.localPosition.y,
            adjustedDistance
        );
    }
}
```

> **Key notes:**
> - `OnVRCCameraSettingsChanged()` fires whenever the player adjusts camera zoom or near/far clip planes.
> - VR headsets have a fixed FOV; this adjustment is only meaningful on desktop.
> - The tangent ratio preserves the apparent angular size of the UI panel regardless of FOV.

---

## 4. Platform-Adaptive UI Layout

VRChat worlds run on PC (Desktop and VR) and Quest (Android). Screen aspect ratios,
input methods, and performance budgets differ significantly. This pattern branches
UI layout at runtime based on platform and input mode.

```csharp
using UdonSharp;
using UnityEngine;
using VRC.SDKBase;

[UdonBehaviourSyncMode(BehaviourSyncMode.NoVariableSync)]
public class PlatformAdaptiveUI : UdonSharpBehaviour
{
    [Header("Platform-Specific Panels")]
    [SerializeField] private GameObject pcPanel;
    [SerializeField] private GameObject questPanel;

    [Header("Input-Mode Panels")]
    [SerializeField] private GameObject vrControlsHint;
    [SerializeField] private GameObject desktopControlsHint;

    [Header("Aspect-Dependent Elements")]
    [SerializeField] private GameObject landscapeSidebar;
    [SerializeField] private GameObject portraitBottomBar;

    void Start()
    {
        ApplyPlatformLayout();
        ApplyInputModeLayout();
        ApplyAspectLayout();
    }

    private void ApplyPlatformLayout()
    {
        // Compile-time platform check for Quest-specific UI
        #if UNITY_ANDROID || UNITY_IOS
        if (pcPanel != null) pcPanel.SetActive(false);
        if (questPanel != null) questPanel.SetActive(true);
        #else
        if (pcPanel != null) pcPanel.SetActive(true);
        if (questPanel != null) questPanel.SetActive(false);
        #endif
    }

    private void ApplyInputModeLayout()
    {
        VRCPlayerApi local = Networking.LocalPlayer;
        if (local == null) return;

        bool isVR = local.IsUserInVR();

        if (vrControlsHint != null) vrControlsHint.SetActive(isVR);
        if (desktopControlsHint != null) desktopControlsHint.SetActive(!isVR);
    }

    private void ApplyAspectLayout()
    {
        Camera screenCam = VRCCameraSettings.ScreenCamera;
        if (screenCam == null) return;

        float aspect = screenCam.aspect;
        bool isLandscape = aspect >= 1.0f;

        if (landscapeSidebar != null) landscapeSidebar.SetActive(isLandscape);
        if (portraitBottomBar != null) portraitBottomBar.SetActive(!isLandscape);
    }
}
```

> **Key notes:**
> - `#if UNITY_ANDROID || UNITY_IOS` is evaluated at **compile time**, producing separate builds for PC and Quest with no runtime overhead.
> - `IsUserInVR()` detects VR headsets at runtime — a PC user can be in either Desktop or VR mode.
> - `VRCCameraSettings.ScreenCamera.aspect` returns the current viewport aspect ratio, useful for detecting portrait-mode streaming or unusual resolutions.

---

## 5. Dynamic Player List UI

Many worlds need a live player list for teleportation, team assignment, or voting.
This pattern enumerates all players, creates a button for each, refreshes on join/leave,
and dispatches click callbacks using button name parsing.

```csharp
using UdonSharp;
using UnityEngine;
using UnityEngine.UI;
using TMPro;
using VRC.SDKBase;

[UdonBehaviourSyncMode(BehaviourSyncMode.NoVariableSync)]
public class DynamicPlayerList : UdonSharpBehaviour
{
    [Header("References")]
    [SerializeField] private Transform listParent;
    [SerializeField] private GameObject buttonTemplate;

    [Header("Configuration")]
    [Tooltip("Prefix for button names used to identify player ID")]
    [SerializeField] private string buttonPrefix = "PlayerBtn_";

    private GameObject[] _activeButtons = new GameObject[0];

    void Start()
    {
        if (buttonTemplate != null)
        {
            buttonTemplate.SetActive(false);
        }
        RefreshPlayerList();
    }

    public override void OnPlayerJoined(VRCPlayerApi player)
    {
        RefreshPlayerList();
    }

    public override void OnPlayerLeft(VRCPlayerApi player)
    {
        RefreshPlayerList();
    }

    public void RefreshPlayerList()
    {
        // Clean up existing buttons
        for (int i = 0; i < _activeButtons.Length; i++)
        {
            if (_activeButtons[i] != null)
            {
                Destroy(_activeButtons[i]);
            }
        }

        int playerCount = VRCPlayerApi.GetPlayerCount();
        VRCPlayerApi[] players = new VRCPlayerApi[playerCount];
        VRCPlayerApi.GetPlayers(players);

        _activeButtons = new GameObject[playerCount];

        for (int i = 0; i < playerCount; i++)
        {
            if (players[i] == null) continue;
            if (!players[i].IsValid()) continue;

            GameObject btn = Object.Instantiate(buttonTemplate);
            btn.transform.SetParent(listParent, false);
            btn.SetActive(true);

            // Encode player ID in button name for callback dispatch
            btn.name = buttonPrefix + players[i].playerId.ToString();

            // Set display text
            TextMeshProUGUI label = btn.GetComponentInChildren<TextMeshProUGUI>();
            if (label != null)
            {
                label.text = players[i].displayName;
            }

            _activeButtons[i] = btn;
        }
    }

    /// <summary>
    /// Called by each button's OnClick UnityEvent. The button passes
    /// its own GameObject name so we can extract the player ID.
    /// </summary>
    public void OnPlayerButtonClicked(string buttonName)
    {
        if (buttonName == null) return;

        // Parse player ID from button name
        string idStr = buttonName.Replace(buttonPrefix, "");
        int playerId = -1;

        // Manual int parse (no int.TryParse in older Udon runtimes)
        bool valid = true;
        int result = 0;
        for (int i = 0; i < idStr.Length; i++)
        {
            char c = idStr[i];
            if (c < '0' || c > '9')
            {
                valid = false;
                break;
            }
            result = result * 10 + (c - '0');
        }
        if (valid && idStr.Length > 0)
        {
            playerId = result;
        }

        if (playerId < 0) return;

        VRCPlayerApi targetPlayer = VRCPlayerApi.GetPlayerById(playerId);
        if (targetPlayer == null) return;
        if (!targetPlayer.IsValid()) return;

        // Example action: teleport local player to target player
        VRCPlayerApi local = Networking.LocalPlayer;
        if (local == null) return;

        Vector3 targetPos = targetPlayer.GetPosition();
        Quaternion targetRot = targetPlayer.GetRotation();
        local.TeleportTo(targetPos, targetRot);
    }
}
```

> **Key notes:**
> - `Object.Instantiate()` works in UdonSharp for scene objects. The template button must exist in the scene (not an asset prefab).
> - Player IDs are encoded in the button `name` field and parsed back on click — this avoids needing per-button UdonBehaviours.
> - Always check `IsValid()` before using a `VRCPlayerApi` reference, as players may leave between list refresh and click.
> - For large player counts (80+), consider recycling buttons instead of Destroy/Instantiate every refresh.

---

## 6. ScrollRect VR/Desktop Input Abstraction

Unity's built-in `ScrollRect` responds to mouse scroll on desktop but has no native support
for VR controller thumbstick scrolling. This pattern polls VR input axes and desktop mouse
scroll, then applies the appropriate scroll delta each frame.

```csharp
using UdonSharp;
using UnityEngine;
using UnityEngine.UI;
using VRC.SDKBase;

[UdonBehaviourSyncMode(BehaviourSyncMode.NoVariableSync)]
public class ScrollInputAdapter : UdonSharpBehaviour
{
    [Header("References")]
    [SerializeField] private ScrollRect scrollRect;

    [Header("Configuration")]
    [SerializeField] private float vrScrollSpeed = 0.5f;
    [SerializeField] private float desktopScrollSpeed = 0.1f;

    [Tooltip("Dead zone for VR thumbstick to prevent drift")]
    [SerializeField] private float vrDeadZone = 0.15f;

    private bool _isVR = false;

    void Start()
    {
        VRCPlayerApi local = Networking.LocalPlayer;
        if (local != null)
        {
            _isVR = local.IsUserInVR();
        }
    }

    void Update()
    {
        if (scrollRect == null) return;

        float scrollDelta = 0.0f;

        if (_isVR)
        {
            scrollDelta = GetVRScrollDelta();
        }
        else
        {
            scrollDelta = GetDesktopScrollDelta();
        }

        if (Mathf.Abs(scrollDelta) > 0.001f)
        {
            Vector2 pos = scrollRect.normalizedPosition;
            pos.y = Mathf.Clamp01(pos.y + scrollDelta);
            scrollRect.normalizedPosition = pos;
        }
    }

    private float GetVRScrollDelta()
    {
        // InputLookVertical maps to the right-hand thumbstick Y axis
        float axis = Input.GetAxis("Oculus_CrossPlatform_SecondaryThumbstickVertical");

        // Apply dead zone
        if (Mathf.Abs(axis) < vrDeadZone) return 0.0f;

        return axis * vrScrollSpeed * Time.deltaTime;
    }

    private float GetDesktopScrollDelta()
    {
        float mouseScroll = Input.GetAxis("Mouse ScrollWheel");
        return mouseScroll * desktopScrollSpeed;
    }
}
```

> **Key notes:**
> - VR thumbstick axes vary by headset. `Oculus_CrossPlatform_SecondaryThumbstickVertical` covers most SteamVR and Oculus setups in VRChat.
> - Apply a dead zone to prevent unintentional drift from loose thumbsticks.
> - Desktop scroll uses `Mouse ScrollWheel`, which returns small float values per frame; adjust `desktopScrollSpeed` to taste.
> - This pattern runs in `Update()` — see the Update Handler pattern in `patterns-performance.md` for centralized update management in complex worlds.

---

## 7. Lookup-Table Localization

For worlds that support multiple languages, a lookup-table approach using parallel arrays
provides simple, efficient localization without external libraries. Font sizes can be
adjusted per language (CJK characters often need different sizes than Latin text).

```csharp
using UdonSharp;
using UnityEngine;
using TMPro;
using VRC.SDKBase;

[UdonBehaviourSyncMode(BehaviourSyncMode.NoVariableSync)]
public class LookupLocalization : UdonSharpBehaviour
{
    [Header("UI Elements")]
    [SerializeField] private TextMeshProUGUI[] textElements;

    [Header("Japanese Localization")]
    [SerializeField] private string[] textsJa;
    [SerializeField] private float[] fontSizesJa;

    [Header("English Localization")]
    [SerializeField] private string[] textsEn;
    [SerializeField] private float[] fontSizesEn;

    private int _currentLanguage = 0; // 0 = ja, 1 = en

    public int CurrentLanguage
    {
        get => _currentLanguage;
        set
        {
            _currentLanguage = value;
            RefreshAllText();
        }
    }

    void Start()
    {
        DetectLanguage();
        RefreshAllText();
    }

    private void DetectLanguage()
    {
        string lang = VRCPlayerApi.GetCurrentLanguage();

        if (lang == "ja" || lang == "ja-JP")
        {
            _currentLanguage = 0;
        }
        else
        {
            // Default to English for all non-Japanese languages
            _currentLanguage = 1;
        }
    }

    private void RefreshAllText()
    {
        if (textElements == null) return;

        string[] texts = _currentLanguage == 0 ? textsJa : textsEn;
        float[] sizes = _currentLanguage == 0 ? fontSizesJa : fontSizesEn;

        for (int i = 0; i < textElements.Length; i++)
        {
            if (textElements[i] == null) continue;

            if (texts != null && i < texts.Length)
            {
                textElements[i].text = texts[i];
            }

            if (sizes != null && i < sizes.Length && sizes[i] > 0)
            {
                textElements[i].fontSize = sizes[i];
            }
        }
    }

    /// <summary>
    /// Called from a language toggle button to switch manually.
    /// </summary>
    public void ToggleLanguage()
    {
        CurrentLanguage = _currentLanguage == 0 ? 1 : 0;
    }
}
```

> **Key notes:**
> - `VRCPlayerApi.GetCurrentLanguage()` returns the player's VRChat client language (e.g., `"ja"`, `"en"`, `"ko"`).
> - Parallel arrays must have matching indices: `textsJa[0]` and `textsEn[0]` correspond to `textElements[0]`.
> - CJK characters are wider and taller than Latin — use `fontSizesJa` / `fontSizesEn` to set per-language sizes for readability.
> - To add more languages, extend the pattern with additional parallel arrays and a numeric language index.

---

## 8. Toggle Switch with Animator Bridge

Bridging Unity UI `Toggle` components to `Animator` parameters allows visual state changes
(door open/close, light on/off) driven directly from UI toggles. This pattern also manages
toggle color states for visual feedback.

```csharp
using UdonSharp;
using UnityEngine;
using UnityEngine.UI;

[UdonBehaviourSyncMode(BehaviourSyncMode.NoVariableSync)]
public class ToggleAnimatorBridge : UdonSharpBehaviour
{
    [Header("References")]
    [SerializeField] private Toggle uiToggle;
    [SerializeField] private Animator targetAnimator;
    [SerializeField] private Image handleImage;

    [Header("Animator")]
    [SerializeField] private string animatorBoolName = "IsActive";

    [Header("Colors")]
    [SerializeField] private Color onColor = new Color(0.2f, 0.8f, 0.2f, 1.0f);
    [SerializeField] private Color offColor = new Color(0.5f, 0.5f, 0.5f, 1.0f);
    [SerializeField] private Color disabledColor = new Color(0.3f, 0.3f, 0.3f, 0.5f);

    private bool _initialized = false;

    void Start()
    {
        Initialize();
        ApplyVisualState();
    }

    private void Initialize()
    {
        if (_initialized) return;
        _initialized = true;
    }

    /// <summary>
    /// Hook this to Toggle.onValueChanged in the Inspector.
    /// </summary>
    public void OnToggleValueChanged()
    {
        Initialize();

        if (uiToggle == null) return;

        bool isOn = uiToggle.isOn;

        // Bridge to Animator
        if (targetAnimator != null)
        {
            targetAnimator.SetBool(animatorBoolName, isOn);
        }

        ApplyVisualState();
    }

    private void ApplyVisualState()
    {
        if (handleImage == null) return;

        if (uiToggle == null || !uiToggle.interactable)
        {
            handleImage.color = disabledColor;
            return;
        }

        handleImage.color = uiToggle.isOn ? onColor : offColor;
    }

    /// <summary>
    /// Set the toggle state programmatically without triggering onValueChanged.
    /// </summary>
    public void SetToggleWithoutNotify(bool value)
    {
        if (uiToggle == null) return;
        uiToggle.SetIsOnWithoutNotify(value);
        ApplyVisualState();
    }
}
```

> **Key notes:**
> - Wire `OnToggleValueChanged()` to the Toggle's `onValueChanged` event in the Unity Inspector.
> - Use `SetIsOnWithoutNotify()` when restoring state from persistence or network sync to avoid re-triggering the callback loop.
> - The `ColorBlock` on the Toggle's `Graphic` handles hover/pressed states automatically; this pattern only manages the custom handle color.

---

## 9. UI Settings Persistence via PlayerObject

Player preferences (volume, language, UI scale) should persist across rejoin.
This pattern uses `PlayerObject` (SDK 3.7.4+) with a sentinel value pattern:
`-1` means "use the world default."

```csharp
using UdonSharp;
using UnityEngine;
using UnityEngine.UI;
using VRC.SDKBase;

[UdonBehaviourSyncMode(BehaviourSyncMode.Manual)]
public class UISettingsStore : UdonSharpBehaviour
{
    [Header("Persisted Settings")]
    [UdonSynced] public int savedVolume = -1;     // -1 = use default
    [UdonSynced] public int savedLanguage = -1;   // -1 = auto-detect
    [UdonSynced] public int savedUIScale = -1;    // -1 = use default

    [Header("Defaults")]
    [SerializeField] private int defaultVolume = 80;
    [SerializeField] private int defaultLanguage = 0;
    [SerializeField] private int defaultUIScale = 100;

    [Header("UI References")]
    [SerializeField] private Slider volumeSlider;

    private bool _initialized = false;
    private VRCPlayerApi _localPlayer;

    void Start()
    {
        _localPlayer = Networking.LocalPlayer;
    }

    /// <summary>
    /// Called by VRChat when this player's PlayerObject data is restored.
    /// </summary>
    public override void OnPlayerRestored(VRCPlayerApi player)
    {
        if (player == null) return;
        if (!player.isLocal) return;

        ApplySettings();
    }

    private void ApplySettings()
    {
        int vol = savedVolume >= 0 ? savedVolume : defaultVolume;
        int lang = savedLanguage >= 0 ? savedLanguage : defaultLanguage;
        int scale = savedUIScale >= 0 ? savedUIScale : defaultUIScale;

        // Apply volume
        if (volumeSlider != null)
        {
            volumeSlider.SetValueWithoutNotify(vol / 100.0f);
        }

        // Apply other settings via SendCustomEvent to external behaviours
        // ...
    }

    /// <summary>
    /// Call this when the player changes volume via the UI slider.
    /// </summary>
    public void OnVolumeChanged()
    {
        if (volumeSlider == null) return;

        Networking.SetOwner(_localPlayer, gameObject);
        savedVolume = Mathf.RoundToInt(volumeSlider.value * 100.0f);
        RequestSerialization();
    }

    /// <summary>
    /// Look up another player's settings store from their PlayerObjects.
    /// </summary>
    public static UISettingsStore FindForPlayer(VRCPlayerApi player)
    {
        // Returns the UISettingsStore component from the given player's PlayerObjects
        return Networking.FindComponentInPlayerObjects<UISettingsStore>(player);
    }

    /// <summary>
    /// Reset all settings to sentinel values (will use defaults on next load).
    /// </summary>
    public void ResetToDefaults()
    {
        Networking.SetOwner(_localPlayer, gameObject);
        savedVolume = -1;
        savedLanguage = -1;
        savedUIScale = -1;
        RequestSerialization();
        ApplySettings();
    }
}
```

> **Key notes:**
> - PlayerObject instances are created per-player by VRChat. The component on the PlayerObject prefab becomes a per-player data store.
> - The `-1` sentinel pattern lets you distinguish "player never set this" from "player explicitly chose value 0."
> - `OnPlayerRestored()` fires after the player's persistent data is loaded. Apply saved state here, not in `Start()`.
> - `Networking.FindComponentInPlayerObjects<T>(player)` retrieves another player's PlayerObject component, useful for displaying their preferences.

---

## 10. Listener-Based Menu Event System

A generic event system for menu open/close (or any UI state change) that notifies multiple
subscribers. Since UdonSharp lacks `List<T>` and delegates, this pattern uses a fixed-size
array with manual resize for listener management.

```csharp
using UdonSharp;
using UnityEngine;

[UdonBehaviourSyncMode(BehaviourSyncMode.NoVariableSync)]
public class MenuEventBroadcaster : UdonSharpBehaviour
{
    [Header("Events")]
    [SerializeField] private string openEventName = "OnMenuOpened";
    [SerializeField] private string closeEventName = "OnMenuClosed";

    private UdonSharpBehaviour[] _listeners = new UdonSharpBehaviour[0];
    private int _listenerCount = 0;

    private bool _isOpen = false;

    /// <summary>
    /// Register a listener to receive menu events.
    /// </summary>
    public void AddListener(UdonSharpBehaviour listener)
    {
        if (listener == null) return;

        // Check for duplicate
        for (int i = 0; i < _listenerCount; i++)
        {
            if (_listeners[i] == listener) return;
        }

        // Resize array if full
        if (_listenerCount >= _listeners.Length)
        {
            int newSize = _listeners.Length == 0 ? 4 : _listeners.Length * 2;
            UdonSharpBehaviour[] newArray = new UdonSharpBehaviour[newSize];
            for (int i = 0; i < _listenerCount; i++)
            {
                newArray[i] = _listeners[i];
            }
            _listeners = newArray;
        }

        _listeners[_listenerCount] = listener;
        _listenerCount++;
    }

    /// <summary>
    /// Remove a listener from the notification list.
    /// </summary>
    public void RemoveListener(UdonSharpBehaviour listener)
    {
        if (listener == null) return;

        for (int i = 0; i < _listenerCount; i++)
        {
            if (_listeners[i] == listener)
            {
                // Shift remaining elements
                for (int j = i; j < _listenerCount - 1; j++)
                {
                    _listeners[j] = _listeners[j + 1];
                }
                _listeners[_listenerCount - 1] = null;
                _listenerCount--;
                return;
            }
        }
    }

    /// <summary>
    /// Open the menu and notify all listeners.
    /// </summary>
    public void OpenMenu()
    {
        if (_isOpen) return;
        _isOpen = true;
        Broadcast(openEventName);
    }

    /// <summary>
    /// Close the menu and notify all listeners.
    /// </summary>
    public void CloseMenu()
    {
        if (!_isOpen) return;
        _isOpen = false;
        Broadcast(closeEventName);
    }

    /// <summary>
    /// Toggle the menu state.
    /// </summary>
    public void ToggleMenu()
    {
        if (_isOpen)
        {
            CloseMenu();
        }
        else
        {
            OpenMenu();
        }
    }

    private void Broadcast(string eventName)
    {
        for (int i = 0; i < _listenerCount; i++)
        {
            if (_listeners[i] != null)
            {
                _listeners[i].SendCustomEvent(eventName);
            }
        }
    }
}
```

> **Key notes:**
> - UdonSharp does not support `List<T>`, so the array is resized manually with a doubling strategy (similar to `ArrayList`).
> - `SendCustomEvent()` calls a `public void` method by name on the target behaviour. Listeners must have public methods matching `openEventName` / `closeEventName`.
> - Duplicate registration is prevented by a linear scan before adding.
> - For worlds with many listeners (16+), consider pre-allocating the array size in the Inspector to avoid repeated resizing.
> - See `patterns-utilities.md` for a more general-purpose EventBus implementation.

---

## See Also

- [patterns-core.md](patterns-core.md) - Basic UI patterns (button handler, slider display), initialization, interaction
- [patterns-networking.md](patterns-networking.md) - Synced game state, object pooling, NetworkCallable
- [patterns-utilities.md](patterns-utilities.md) - Array helpers, event bus, relay communication
- [patterns-performance.md](patterns-performance.md) - Update handler, platform optimization
- [persistence.md](persistence.md) - PlayerData/PlayerObject API details
- [api.md](api.md) - VRCPlayerApi, VRCCameraSettings reference
