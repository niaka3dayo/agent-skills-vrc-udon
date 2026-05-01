# UdonSharp UI/Canvas Patterns

Immobilize guard, avatar-scale-aware UI, FOV-responsive positioning, platform-adaptive layout,
dynamic player list, scroll input abstraction, lookup-table localization, toggle-animator bridge,
settings persistence via PlayerObject, listener-based menu event system, finger-based touch
interaction for canvas UI, and modular app architecture with plugin lifecycle.

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

## 11. Finger-Based Touch Interaction for Canvas UI

VR users can interact with world-space Canvas UI by physically touching buttons with their
fingertips. This pattern tracks index finger bone positions, extrapolates the fingertip,
detects push events against the canvas plane, fires pointer events (Down/Drag/Up/Click),
provides haptic feedback, and falls back to raycast-based interaction for desktop users.

The system consists of two behaviours: `FingerPointer` tracks a single hand's finger state,
and `FingerTouchCanvas` manages the canvas, pointer events, and desktop fallback.

### FingerPointer (per-hand finger tracker)

```csharp
using UdonSharp;
using UnityEngine;
using VRC.SDKBase;

/// <summary>
/// Tracks a single hand's index finger position and provides the extrapolated
/// fingertip world position. Attach one instance per hand (left and right).
/// </summary>
[UdonBehaviourSyncMode(BehaviourSyncMode.None)]
public class FingerPointer : UdonSharpBehaviour
{
    [Header("Hand Configuration")]
    [Tooltip("Which hand this pointer tracks")]
    [SerializeField] private bool isLeftHand = true;

    [Header("Fingertip Extrapolation")]
    [Tooltip("Lerp factor beyond the distal bone to estimate fingertip (1.0 = distal, 1.8 = typical fingertip)")]
    [SerializeField] private float tipExtrapolation = 1.8f;

    [Header("Haptic Feedback")]
    [SerializeField] private float hapticDuration = 0.05f;
    [SerializeField] private float hapticAmplitude = 0.5f;
    [SerializeField] private float hapticFrequency = 150.0f;

    private VRCPlayerApi _localPlayer;
    private HumanBodyBones _intermediateBone;
    private HumanBodyBones _distalBone;
    private bool _isVR = false;
    private bool _initialized = false;

    /// <summary>
    /// Current extrapolated fingertip position in world space.
    /// </summary>
    [System.NonSerialized] public Vector3 FingertipPosition;

    /// <summary>
    /// Whether this pointer has valid tracking data this frame.
    /// </summary>
    [System.NonSerialized] public bool IsTracking;

    void Start()
    {
        Initialize();
    }

    private void Initialize()
    {
        if (_initialized) return;
        _initialized = true;

        _localPlayer = Networking.LocalPlayer;
        if (!Utilities.IsValid(_localPlayer)) return;

        _isVR = _localPlayer.IsUserInVR();

        if (isLeftHand)
        {
            _intermediateBone = HumanBodyBones.LeftIndexIntermediate;
            _distalBone = HumanBodyBones.LeftIndexDistal;
        }
        else
        {
            _intermediateBone = HumanBodyBones.RightIndexIntermediate;
            _distalBone = HumanBodyBones.RightIndexDistal;
        }
    }

    /// <summary>
    /// Call once per frame from the canvas manager to update finger position.
    /// </summary>
    public void UpdateTracking()
    {
        IsTracking = false;

        if (!_isVR) return;
        if (!Utilities.IsValid(_localPlayer)) return;

        Vector3 intermediate = _localPlayer.GetBonePosition(_intermediateBone);
        Vector3 distal = _localPlayer.GetBonePosition(_distalBone);

        // Zero vectors indicate missing tracking data
        if (intermediate == Vector3.zero && distal == Vector3.zero) return;

        FingertipPosition = Vector3.LerpUnclamped(intermediate, distal, tipExtrapolation);
        IsTracking = true;
    }

    /// <summary>
    /// Trigger haptic feedback on this hand.
    /// </summary>
    public void PlayHaptic()
    {
        if (!Utilities.IsValid(_localPlayer)) return;
        if (!_isVR) return;

        VRC_Pickup.PickupHand hand = isLeftHand
            ? VRC_Pickup.PickupHand.Left
            : VRC_Pickup.PickupHand.Right;

        _localPlayer.PlayHapticEventInHand(hand, hapticDuration, hapticAmplitude, hapticFrequency);
    }

    /// <summary>
    /// Returns true if this pointer is configured for the left hand.
    /// </summary>
    public bool GetIsLeftHand()
    {
        return isLeftHand;
    }

    /// <summary>
    /// Returns true if the local player is in VR.
    /// </summary>
    public bool GetIsVR()
    {
        return _isVR;
    }
}
```

### FingerTouchCanvas (canvas touch detection and event dispatch)

```csharp
using UdonSharp;
using UnityEngine;
using UnityEngine.UI;
using VRC.SDKBase;

/// <summary>
/// Detects finger touch and desktop raycast interactions against a world-space Canvas.
/// Fires pointer events (Down, BeginDrag, Drag, EndDrag, Up, Click) on UdonSharpBehaviour listeners.
/// The Canvas must be in World Space render mode.
/// </summary>
[UdonBehaviourSyncMode(BehaviourSyncMode.None)]
public class FingerTouchCanvas : UdonSharpBehaviour
{
    [Header("References")]
    [SerializeField] private RectTransform canvasRect;
    [SerializeField] private FingerPointer leftPointer;
    [SerializeField] private FingerPointer rightPointer;

    [Header("Touch Detection")]
    [Tooltip("Maximum distance in local Z from canvas surface to register a touch")]
    [SerializeField] private float pushDistanceLimit = 0.05f;

    [Tooltip("Minimum XY movement in local space to trigger a drag event")]
    [SerializeField] private float dragThreshold = 5.0f;

    [Header("Canvas Push Effect")]
    [Tooltip("Optional transform to push toward finger on press")]
    [SerializeField] private Transform pushTarget;

    [Tooltip("Maximum push offset in local Z")]
    [SerializeField] private float maxPushOffset = 0.01f;

    [Header("Desktop Fallback")]
    [Tooltip("Maximum raycast distance for desktop interaction")]
    [SerializeField] private float desktopRayDistance = 5.0f;

    [Tooltip("Layer mask for desktop raycast")]
    [SerializeField] private LayerMask desktopRayMask = ~0;

    [Header("Event Listeners")]
    [Tooltip("UdonBehaviours that receive OnPointerDown/OnPointerBeginDrag/OnPointerDrag/OnPointerEndDrag/OnPointerUp/OnPointerClick events")]
    [SerializeField] private UdonSharpBehaviour[] eventListeners = new UdonSharpBehaviour[0];

    /// <summary>
    /// The pointer index (0 = left, 1 = right, 2 = desktop) that last triggered an event.
    /// Listeners can read this to determine which pointer fired the event.
    /// </summary>
    [HideInInspector] public int lastPointerIndex;

    // Per-pointer state (index 0 = left, 1 = right, 2 = desktop)
    private bool[] _isPressed = new bool[3];
    private Vector2[] _pressStartLocalXY = new Vector2[3];
    private bool[] _isDragging = new bool[3];

    private VRCPlayerApi _localPlayer;
    private bool _isVR = false;
    private bool _initialized = false;
    private Vector3 _pushTargetBasePos;

    void Start()
    {
        Initialize();
    }

    private void Initialize()
    {
        if (_initialized) return;
        _initialized = true;

        _localPlayer = Networking.LocalPlayer;
        if (!Utilities.IsValid(_localPlayer)) return;

        _isVR = _localPlayer.IsUserInVR();

        if (pushTarget != null)
        {
            _pushTargetBasePos = pushTarget.localPosition;
        }
    }

    void Update()
    {
        if (canvasRect == null) return;

        if (_isVR)
        {
            if (leftPointer != null)
            {
                leftPointer.UpdateTracking();
                ProcessFingerPointer(leftPointer, 0);
            }
            if (rightPointer != null)
            {
                rightPointer.UpdateTracking();
                ProcessFingerPointer(rightPointer, 1);
            }
        }
        else
        {
            ProcessDesktopRaycast();
        }

        UpdatePushEffect();
    }

    private void ProcessFingerPointer(FingerPointer pointer, int pointerIndex)
    {
        if (!pointer.IsTracking)
        {
            if (_isPressed[pointerIndex])
            {
                if (_isDragging[pointerIndex])
                {
                    FirePointerEndDrag(pointerIndex);
                }
                FirePointerUp(pointerIndex);
                _isPressed[pointerIndex] = false;
                _isDragging[pointerIndex] = false;
            }
            return;
        }

        // Convert fingertip world position to canvas local space
        Vector3 localPos = canvasRect.InverseTransformPoint(pointer.FingertipPosition);

        // Check XY bounds against canvas rect
        bool inBoundsXY = canvasRect.rect.Contains(new Vector2(localPos.x, localPos.y));

        // Check Z depth: localPos.z < 0 means finger is in front of canvas,
        // and we treat crossing Z=0 as the touch plane
        bool inDepth = localPos.z >= -pushDistanceLimit && localPos.z <= pushDistanceLimit;
        bool isTouching = inBoundsXY && inDepth && localPos.z <= 0.0f;

        if (isTouching && !_isPressed[pointerIndex])
        {
            // Pointer Down
            _isPressed[pointerIndex] = true;
            _isDragging[pointerIndex] = false;
            _pressStartLocalXY[pointerIndex] = new Vector2(localPos.x, localPos.y);
            pointer.PlayHaptic();
            FirePointerDown(pointerIndex);
        }
        else if (!isTouching && _isPressed[pointerIndex])
        {
            // Pointer Up
            if (_isDragging[pointerIndex])
            {
                FirePointerEndDrag(pointerIndex);
            }
            if (!_isDragging[pointerIndex] && inBoundsXY)
            {
                // Click: released on canvas without significant drag
                FirePointerClick(pointerIndex);
            }
            FirePointerUp(pointerIndex);
            _isPressed[pointerIndex] = false;
            _isDragging[pointerIndex] = false;
        }
        else if (isTouching && _isPressed[pointerIndex])
        {
            // Check for drag
            Vector2 currentXY = new Vector2(localPos.x, localPos.y);
            float dist = Vector2.Distance(currentXY, _pressStartLocalXY[pointerIndex]);
            if (dist >= dragThreshold)
            {
                if (!_isDragging[pointerIndex])
                {
                    FirePointerBeginDrag(pointerIndex);
                }
                _isDragging[pointerIndex] = true;
                FirePointerDrag(pointerIndex);
            }
        }
    }

    private void ProcessDesktopRaycast()
    {
        if (!Utilities.IsValid(_localPlayer)) return;

        VRCPlayerApi.TrackingData headData =
            _localPlayer.GetTrackingData(VRCPlayerApi.TrackingDataType.Head);
        Vector3 origin = headData.position;
        Vector3 forward = headData.rotation * Vector3.forward;

        RaycastHit hit;
        bool didHit = Physics.Raycast(origin, forward, out hit, desktopRayDistance, desktopRayMask);

        if (!didHit || hit.collider == null)
        {
            if (_isPressed[2])
            {
                if (_isDragging[2])
                {
                    FirePointerEndDrag(2);
                }
                FirePointerUp(2);
                _isPressed[2] = false;
                _isDragging[2] = false;
            }
            return;
        }

        // Check if the hit object is part of this canvas hierarchy
        bool isCanvasHit = false;
        Transform hitTransform = hit.collider.transform;
        Transform canvasTransform = canvasRect.transform;
        Transform check = hitTransform;
        for (int i = 0; i < 20; i++)
        {
            if (check == null) break;
            if (check == canvasTransform)
            {
                isCanvasHit = true;
                break;
            }
            check = check.parent;
        }

        if (!isCanvasHit)
        {
            if (_isPressed[2])
            {
                if (_isDragging[2])
                {
                    FirePointerEndDrag(2);
                }
                FirePointerUp(2);
                _isPressed[2] = false;
                _isDragging[2] = false;
            }
            return;
        }

        // Desktop uses InputUse (left mouse / VR trigger) via Input
        bool usePressed = Input.GetMouseButton(0);

        Vector3 localPos = canvasRect.InverseTransformPoint(hit.point);
        Vector2 localXY = new Vector2(localPos.x, localPos.y);

        if (usePressed && !_isPressed[2])
        {
            _isPressed[2] = true;
            _isDragging[2] = false;
            _pressStartLocalXY[2] = localXY;
            FirePointerDown(2);
        }
        else if (!usePressed && _isPressed[2])
        {
            if (_isDragging[2])
            {
                FirePointerEndDrag(2);
            }
            if (!_isDragging[2])
            {
                FirePointerClick(2);
            }
            FirePointerUp(2);
            _isPressed[2] = false;
            _isDragging[2] = false;
        }
        else if (usePressed && _isPressed[2])
        {
            float dist = Vector2.Distance(localXY, _pressStartLocalXY[2]);
            if (dist >= dragThreshold)
            {
                if (!_isDragging[2])
                {
                    FirePointerBeginDrag(2);
                }
                _isDragging[2] = true;
                FirePointerDrag(2);
            }
        }
    }

    private void UpdatePushEffect()
    {
        if (pushTarget == null) return;

        bool anyPressed = _isPressed[0] || _isPressed[1] || _isPressed[2];
        Vector3 targetPos = _pushTargetBasePos;

        if (anyPressed)
        {
            targetPos = _pushTargetBasePos + new Vector3(0.0f, 0.0f, maxPushOffset);
        }

        pushTarget.localPosition = Vector3.Lerp(
            pushTarget.localPosition,
            targetPos,
            Time.deltaTime * 10.0f
        );
    }

    private void FirePointerDown(int pointerIndex)
    {
        lastPointerIndex = pointerIndex;
        BroadcastEvent("OnPointerDown");
    }

    private void FirePointerUp(int pointerIndex)
    {
        lastPointerIndex = pointerIndex;
        BroadcastEvent("OnPointerUp");
    }

    private void FirePointerClick(int pointerIndex)
    {
        lastPointerIndex = pointerIndex;
        BroadcastEvent("OnPointerClick");
    }

    private void FirePointerDrag(int pointerIndex)
    {
        lastPointerIndex = pointerIndex;
        BroadcastEvent("OnPointerDrag");
    }

    private void FirePointerBeginDrag(int pointerIndex)
    {
        lastPointerIndex = pointerIndex;
        BroadcastEvent("OnPointerBeginDrag");
    }

    private void FirePointerEndDrag(int pointerIndex)
    {
        lastPointerIndex = pointerIndex;
        BroadcastEvent("OnPointerEndDrag");
    }

    private void BroadcastEvent(string eventName)
    {
        if (eventListeners == null) return;

        for (int i = 0; i < eventListeners.Length; i++)
        {
            if (Utilities.IsValid(eventListeners[i]))
            {
                eventListeners[i].SendCustomEvent(eventName);
            }
        }
    }
}
```

**When to use:**
- Building interactive panels (keyboards, control panels, menus) that VR players touch with their fingers.
- Creating immersive UI that responds to physical hand presence rather than laser pointers.
- Tablet or kiosk-style in-world devices where direct touch feels natural.

> **Key notes:**
> - `GetBonePosition()` returns `Vector3.zero` when tracking data is unavailable (e.g., on desktop or when the avatar lacks the bone). Always check for zero vectors before using the result.
> - `LerpUnclamped` with a factor of ~1.8 extends the segment from intermediate to distal bone to approximate the fingertip, since VRChat does not expose a dedicated fingertip bone.
> - `InverseTransformPoint` converts from world space to the canvas's local coordinate system, where `rect.Contains()` checks XY bounds and the Z axis represents push depth.
> - Haptic feedback via `PlayHapticEventInHand()` fires only for the local player and only in VR.
> - The desktop fallback uses `Physics.Raycast` from head tracking data and `Input.GetMouseButton(0)` for click detection. Ensure the canvas or its children have colliders on the correct layer.
> - The push effect lerps the `pushTarget` transform forward when any pointer is pressed, giving tactile visual feedback.

---

## 12. Modular App Architecture (Plugin Lifecycle)

When building a device with multiple screens or applications (e.g., an in-world tablet,
control panel, or information kiosk), a modular app architecture keeps each feature isolated
while a central manager handles app switching, transitions, and event forwarding.

Each app extends `AppModule` and receives lifecycle callbacks. The `AppManager` discovers
apps at startup, manages CanvasGroup-based transitions, syncs the active app across the
network, and forwards pickup/interaction events to the current app.

### AppModule (base class for each app screen)

```csharp
using UdonSharp;
using UnityEngine;

/// <summary>
/// Base class for modular app screens. Subclass this for each app
/// and override the lifecycle hooks as needed. Requires a CanvasGroup
/// on the same GameObject for transition alpha control.
/// </summary>
[RequireComponent(typeof(CanvasGroup))]
[UdonBehaviourSyncMode(BehaviourSyncMode.None)]
public class AppModule : UdonSharpBehaviour
{
    [Header("App Metadata")]
    [Tooltip("Display name shown in the app launcher")]
    public string appName = "Unnamed App";

    [Tooltip("Icon texture shown in the app launcher")]
    public Texture2D appIcon;

    /// <summary>
    /// Called when this app becomes the active app.
    /// </summary>
    public virtual void OnAppOpen()
    {
    }

    /// <summary>
    /// Called when this app is being replaced by another app or the home screen.
    /// </summary>
    public virtual void OnAppClose()
    {
    }

    /// <summary>
    /// Called when the device is picked up while this app is active.
    /// </summary>
    public virtual void OnDevicePickup()
    {
    }

    /// <summary>
    /// Called when the device use button is pressed while this app is active.
    /// </summary>
    public virtual void OnDeviceUseDown()
    {
    }

    /// <summary>
    /// Called when the device use button is released while this app is active.
    /// </summary>
    public virtual void OnDeviceUseUp()
    {
    }

    /// <summary>
    /// Called when the device is dropped while this app is active.
    /// </summary>
    public virtual void OnDeviceDrop()
    {
    }

    /// <summary>
    /// Called when a pointer press occurs on this app's UI.
    /// </summary>
    public virtual void OnAppPointerDown()
    {
    }

    /// <summary>
    /// Called when a pointer release occurs on this app's UI.
    /// </summary>
    public virtual void OnAppPointerUp()
    {
    }
}
```

### AppManager (discovery, switching, sync, and event forwarding)

```csharp
using UdonSharp;
using UnityEngine;
using UnityEngine.UI;
using TMPro;
using VRC.SDKBase;

/// <summary>
/// Manages a collection of AppModule instances. Handles auto-discovery,
/// CanvasGroup-based transitions, synced app selection, and pickup event forwarding.
/// Place all app GameObjects as children of the appsParent transform.
/// </summary>
[UdonBehaviourSyncMode(BehaviourSyncMode.Manual)]
public class AppManager : UdonSharpBehaviour
{
    [Header("References")]
    [Tooltip("Parent transform whose children contain AppModule components")]
    [SerializeField] private Transform appsParent;

    [Tooltip("Optional: parent transform for dynamically created app icons in the launcher")]
    [SerializeField] private Transform iconListParent;

    [Tooltip("Optional: prefab for app icon buttons (must exist in scene, not an asset)")]
    [SerializeField] private GameObject iconButtonTemplate;

    [Header("Transition")]
    [Tooltip("Speed of CanvasGroup alpha fade transitions")]
    [SerializeField] private float transitionSpeed = 8.0f;

    [Header("Synced State")]
    [UdonSynced, FieldChangeCallback(nameof(SyncedAppIndex))]
    private int _syncedAppIndex = -1;

    // Discovered apps
    private AppModule[] _apps = new AppModule[0];
    private CanvasGroup[] _canvasGroups = new CanvasGroup[0];
    private int _appCount = 0;

    // Transition state
    private int _currentAppIndex = -1;
    private int _targetAppIndex = -1;
    private bool _isTransitioning = false;
    private int _previousAppIndex = -1;

    // Pending open state — carries the requested operation from OpenApp/CloseCurrentApp
    // into OnOwnershipTransferred so the callback knows which app to open.
    // Note: Networking.SetOwner is locally immediate (post-2021.2.2), so a request that
    // already owns the object can execute synchronously; this field exists for the
    // ownership-transfer code path only.
    // -2 = no pending operation, -1 = pending close, >= 0 = pending open index
    private int _pendingOpenIndex = -2;

    /// <summary>
    /// Synced property: when the synced value changes, trigger a transition.
    /// </summary>
    public int SyncedAppIndex
    {
        get => _syncedAppIndex;
        set
        {
            _syncedAppIndex = value;
            BeginTransition(value);
        }
    }

    void Start()
    {
        DiscoverApps();
        InitializeAllAppsHidden();

        if (iconButtonTemplate != null)
        {
            iconButtonTemplate.SetActive(false);
        }

        BuildIconList();
    }

    private void DiscoverApps()
    {
        if (appsParent == null) return;

        int childCount = appsParent.childCount;

        // First pass: count valid apps
        int count = 0;
        for (int i = 0; i < childCount; i++)
        {
            Transform child = appsParent.GetChild(i);
            AppModule app = child.GetComponent<AppModule>();
            if (Utilities.IsValid(app))
            {
                count++;
            }
        }

        _apps = new AppModule[count];
        _canvasGroups = new CanvasGroup[count];
        _appCount = count;

        // Second pass: collect references
        int idx = 0;
        for (int i = 0; i < childCount; i++)
        {
            Transform child = appsParent.GetChild(i);
            AppModule app = child.GetComponent<AppModule>();
            if (Utilities.IsValid(app))
            {
                _apps[idx] = app;
                _canvasGroups[idx] = child.GetComponent<CanvasGroup>();
                idx++;
            }
        }
    }

    private void InitializeAllAppsHidden()
    {
        for (int i = 0; i < _appCount; i++)
        {
            if (Utilities.IsValid(_canvasGroups[i]))
            {
                _canvasGroups[i].alpha = 0.0f;
                _canvasGroups[i].interactable = false;
                _canvasGroups[i].blocksRaycasts = false;
            }
        }
    }

    private void BuildIconList()
    {
        if (iconListParent == null) return;
        if (iconButtonTemplate == null) return;

        for (int i = 0; i < _appCount; i++)
        {
            GameObject iconObj = Object.Instantiate(iconButtonTemplate);
            iconObj.transform.SetParent(iconListParent, false);
            iconObj.SetActive(true);
            iconObj.name = "AppIcon_" + i.ToString();

            // Set icon texture if a RawImage is present on the template
            RawImage rawImage =
                iconObj.GetComponentInChildren<RawImage>();
            if (rawImage != null && Utilities.IsValid(_apps[i]) && _apps[i].appIcon != null)
            {
                rawImage.texture = _apps[i].appIcon;
            }

            // Set label if a Text component is present
            TextMeshProUGUI label =
                iconObj.GetComponentInChildren<TextMeshProUGUI>();
            if (label != null && Utilities.IsValid(_apps[i]))
            {
                label.text = _apps[i].appName;
            }
        }
    }

    /// <summary>
    /// Open an app by index. Call from icon button OnClick events.
    /// The button name must contain the index (e.g., "AppIcon_2").
    /// </summary>
    public void OpenApp(int appIndex)
    {
        if (appIndex < 0 || appIndex >= _appCount) return;

        VRCPlayerApi local = Networking.LocalPlayer;
        if (local == null) return;

        if (!Networking.IsOwner(local, gameObject))
        {
            _pendingOpenIndex = appIndex;
            Networking.SetOwner(local, gameObject);
            return;
        }

        ExecuteOpenApp(appIndex);
    }

    /// <summary>
    /// Close the current app and return to the home state (no app active).
    /// </summary>
    public void CloseCurrentApp()
    {
        VRCPlayerApi local = Networking.LocalPlayer;
        if (local == null) return;

        if (!Networking.IsOwner(local, gameObject))
        {
            _pendingOpenIndex = -1;
            Networking.SetOwner(local, gameObject);
            return;
        }

        ExecuteOpenApp(-1);
    }

    private void ExecuteOpenApp(int appIndex)
    {
        SyncedAppIndex = appIndex;
        RequestSerialization();
    }

    public override void OnOwnershipTransferred(VRCPlayerApi player)
    {
        if (!player.isLocal) return;

        if (_pendingOpenIndex != -2)
        {
            int idx = _pendingOpenIndex;
            _pendingOpenIndex = -2;
            ExecuteOpenApp(idx);
        }
    }

    /// <summary>
    /// Called by icon buttons. Parse the button name to extract the app index.
    /// Button name format: "AppIcon_N" where N is the app index.
    /// </summary>
    public void OnIconButtonClicked(string buttonName)
    {
        if (buttonName == null) return;

        string prefix = "AppIcon_";
        if (buttonName.Length <= prefix.Length) return;

        string idxStr = buttonName.Substring(prefix.Length);

        // Manual int parse
        int result = 0;
        bool valid = true;
        for (int i = 0; i < idxStr.Length; i++)
        {
            char c = idxStr[i];
            if (c < '0' || c > '9')
            {
                valid = false;
                break;
            }
            result = result * 10 + (c - '0');
        }

        if (valid && idxStr.Length > 0)
        {
            OpenApp(result);
        }
    }

    private void BeginTransition(int targetIndex)
    {
        if (targetIndex == _currentAppIndex) return;

        _previousAppIndex = _currentAppIndex;
        _targetAppIndex = targetIndex;
        _isTransitioning = true;

        // Notify the previous app that it is closing
        if (_previousAppIndex >= 0 && _previousAppIndex < _appCount)
        {
            if (Utilities.IsValid(_apps[_previousAppIndex]))
            {
                _apps[_previousAppIndex].OnAppClose();
            }
        }

        // Prepare the target app's CanvasGroup
        if (_targetAppIndex >= 0 && _targetAppIndex < _appCount)
        {
            if (Utilities.IsValid(_canvasGroups[_targetAppIndex]))
            {
                // Enable raycasts immediately so it can receive input once visible
                _canvasGroups[_targetAppIndex].blocksRaycasts = true;
            }
        }
    }

    void Update()
    {
        if (!_isTransitioning) return;

        float step = transitionSpeed * Time.deltaTime;
        bool fadeOutDone = true;
        bool fadeInDone = true;

        // Fade out previous app
        if (_previousAppIndex >= 0 && _previousAppIndex < _appCount)
        {
            CanvasGroup prevCg = _canvasGroups[_previousAppIndex];
            if (Utilities.IsValid(prevCg))
            {
                prevCg.alpha = Mathf.MoveTowards(prevCg.alpha, 0.0f, step);
                if (prevCg.alpha > 0.001f)
                {
                    fadeOutDone = false;
                }
                else
                {
                    prevCg.alpha = 0.0f;
                    prevCg.interactable = false;
                    prevCg.blocksRaycasts = false;
                }
            }
        }

        // Fade in target app
        if (_targetAppIndex >= 0 && _targetAppIndex < _appCount)
        {
            CanvasGroup targetCg = _canvasGroups[_targetAppIndex];
            if (Utilities.IsValid(targetCg))
            {
                targetCg.alpha = Mathf.MoveTowards(targetCg.alpha, 1.0f, step);
                if (targetCg.alpha < 0.999f)
                {
                    fadeInDone = false;
                }
                else
                {
                    targetCg.alpha = 1.0f;
                    targetCg.interactable = true;
                }
            }
        }

        bool done = fadeOutDone && fadeInDone;

        if (done)
        {
            _isTransitioning = false;
            _currentAppIndex = _targetAppIndex;

            // Notify the new app that it is now active
            if (_currentAppIndex >= 0 && _currentAppIndex < _appCount)
            {
                if (Utilities.IsValid(_apps[_currentAppIndex]))
                {
                    _apps[_currentAppIndex].OnAppOpen();
                }
            }
        }
    }

    // ----- Pickup/Interaction event forwarding -----

    public override void OnPickup()
    {
        ForwardToCurrentApp("OnDevicePickup");
    }

    public override void OnDrop()
    {
        ForwardToCurrentApp("OnDeviceDrop");
    }

    public override void OnPickupUseDown()
    {
        ForwardToCurrentApp("OnDeviceUseDown");
    }

    public override void OnPickupUseUp()
    {
        ForwardToCurrentApp("OnDeviceUseUp");
    }

    private void ForwardToCurrentApp(string eventName)
    {
        if (_currentAppIndex < 0 || _currentAppIndex >= _appCount) return;

        AppModule currentApp = _apps[_currentAppIndex];
        if (Utilities.IsValid(currentApp))
        {
            currentApp.SendCustomEvent(eventName);
        }
    }

    /// <summary>
    /// Returns the number of discovered apps.
    /// </summary>
    public int GetAppCount()
    {
        return _appCount;
    }

    /// <summary>
    /// Returns the currently active app index (-1 if none).
    /// </summary>
    public int GetCurrentAppIndex()
    {
        return _currentAppIndex;
    }
}
```

**When to use:**
- Building a multi-screen device (tablet, kiosk, terminal) where each screen is a self-contained feature.
- Creating a plugin-style architecture where new apps can be added by placing a new child GameObject under the apps parent.
- Any scenario requiring CanvasGroup-based animated transitions between UI panels with network sync.

> **Key notes:**
> - `AppModule` uses `virtual` lifecycle methods. Subclasses override only the hooks they need (e.g., a clock app only overrides `OnAppOpen` to start its timer).
> - `CanvasGroup.alpha` controls visibility, `interactable` controls whether UI elements respond to input, and `blocksRaycasts` controls whether the panel intercepts pointer events. All three must be managed together for correct transitions.
> - The `[FieldChangeCallback]` attribute on `SyncedAppIndex` ensures the property setter runs on all clients when the synced value changes, triggering the transition on remote players.
> - App discovery iterates `appsParent` children at `Start()`. Adding or removing apps at runtime is not supported — all apps must be present in the scene hierarchy at load time.
> - Pickup events (`OnPickup`, `OnDrop`, `OnPickupUseDown`, `OnPickupUseUp`) are forwarded from the manager to the active app via `SendCustomEvent`, allowing each app to respond to device interactions independently.
> - Icon buttons are instantiated from a scene template at startup. Wire each button's OnClick to call `OnIconButtonClicked` with the button's name.

---

## See Also

- [patterns-core.md](patterns-core.md) - Basic UI patterns (button handler, slider display), initialization, interaction
- [patterns-networking.md](patterns-networking.md) - Synced game state, object pooling, NetworkCallable (see also: Pattern 12 synced app selection)
- [patterns-utilities.md](patterns-utilities.md) - Array helpers, event bus, relay communication
- [patterns-performance.md](patterns-performance.md) - Update handler, platform optimization (see also: Pattern 11 per-frame finger tracking)
- [persistence.md](persistence.md) - PlayerData/PlayerObject API details
- [api.md](api.md) - VRCPlayerApi, VRCCameraSettings, GetBonePosition, PlayHapticEventInHand reference
