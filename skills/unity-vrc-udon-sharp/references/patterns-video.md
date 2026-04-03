# UdonSharp Video Player Patterns

State machine, server-time sync, late-joiner handling, AVPro texture stabilization,
error retry with fallback, synced playlist management, and platform-specific URL selection.

## 1. Video Player State Machine

### State Definitions

Use a `byte` constant block for the state enum. `byte` is the smallest synced type (1 byte),
costs less bandwidth than `int`, and is sufficient for up to 255 distinct states.

| Value | Name | Description |
|-------|------|-------------|
| `0` | `Idle` | No video loaded, player is dormant |
| `1` | `Loading` | `PlayURL` called, waiting for network/decode |
| `2` | `Ready` | Video loaded, buffered, not yet started |
| `3` | `Playing` | Video actively playing |
| `4` | `Paused` | Video paused mid-playback |
| `5` | `Error` | Irrecoverable error; retry logic may attempt recovery |

### State Transition Table

| From \ To | Idle | Loading | Ready | Playing | Paused | Error |
|-----------|------|---------|-------|---------|--------|-------|
| Idle | — | `PlayURL` | — | — | — | — |
| Loading | Cancel | — | `OnVideoReady` | — | — | `OnVideoError` |
| Ready | Stop | — | — | Play | — | — |
| Playing | Stop | — | — | — | Pause | `OnVideoError` |
| Paused | Stop | — | — | Resume | — | `OnVideoError` |
| Error | Reset | Retry | — | — | — | — |

### Code Example

```csharp
using UdonSharp;
using UnityEngine;
using VRC.SDKBase;
using VRC.SDK3.Video.Components;
using VRC.SDK3.Video.Components.AVPro;
using VRC.Udon.Common.Interfaces;

[UdonBehaviourSyncMode(BehaviourSyncMode.Manual)]
public class VideoPlayerStateMachine : UdonSharpBehaviour
{
    // State constants (byte to minimise sync bandwidth)
    private const byte StateIdle    = 0;
    private const byte StateLoading = 1;
    private const byte StateReady   = 2;
    private const byte StatePlaying = 3;
    private const byte StatePaused  = 4;
    private const byte StateError   = 5;

    [Header("Player References")]
    [SerializeField] private BaseVRCVideoPlayer _videoPlayer;

    [UdonSynced, FieldChangeCallback(nameof(PlayerState))]
    private byte _playerState = StateIdle;

    // Listener array for observer pattern
    [SerializeField] private UdonSharpBehaviour[] _listeners;

    // Listeners must implement a public method with this name
    private const string EVENT_STATE_CHANGED = "OnVideoStateChanged";

    public byte PlayerState
    {
        get => _playerState;
        set
        {
            _playerState = value;
            NotifyListeners();
        }
    }

    // Owner-only: transition to a new state
    private void SetState(byte newState)
    {
        if (!Networking.IsOwner(gameObject)) return;
        PlayerState = newState;
        RequestSerialization();
    }

    // === Video Events ===

    public override void OnVideoReady()
    {
        if (_playerState == StateLoading)
        {
            SetState(StateReady);
        }
    }

    public override void OnVideoStart()
    {
        SetState(StatePlaying);
    }

    public override void OnVideoEnd()
    {
        SetState(StateIdle);
    }

    public override void OnVideoError(VideoError error)
    {
        SetState(StateError);
    }

    // === Public API ===

    public void RequestPlay()
    {
        Networking.SetOwner(Networking.LocalPlayer, gameObject);
        SetState(StateLoading);
        // Caller is responsible for calling _videoPlayer.PlayURL(url)
    }

    public void RequestPause()
    {
        if (_playerState != StatePlaying) return;
        Networking.SetOwner(Networking.LocalPlayer, gameObject);
        _videoPlayer.Pause();
        SetState(StatePaused);
    }

    public void RequestResume()
    {
        if (_playerState != StatePaused) return;
        Networking.SetOwner(Networking.LocalPlayer, gameObject);
        _videoPlayer.Play();
        SetState(StatePlaying);
    }

    public void RequestStop()
    {
        Networking.SetOwner(Networking.LocalPlayer, gameObject);
        _videoPlayer.Stop();
        SetState(StateIdle);
    }

    // === Listener Notification ===

    private void NotifyListeners()
    {
        if (_listeners == null) return;
        foreach (UdonSharpBehaviour listener in _listeners)
        {
            if (listener != null)
            {
                listener.SendCustomEvent(EVENT_STATE_CHANGED);
            }
        }
    }
}
```

> **Note on non-owner state**: Non-owners do not call `SetState` directly — they receive state changes via `FieldChangeCallback` on deserialization. Between `OnVideoStart` firing locally and the next deserialization, a non-owner's `_playerState` may be stale. UI components should check `activeHandler.IsPlaying` / `activeHandler.IsPaused` in addition to `_playerState` for accurate local display.

> **Rate limit coordination**: The examples in this document call `_videoPlayer.PlayURL()` directly
> for clarity. In production worlds with multiple video players, wrap all `PlayURL` calls through
> a shared rate limit scheduler to avoid VRChat's 5-second rate limit collision.
> See the [Rate Limit Resolver](patterns-performance.md#rate-limit-resolver) pattern.

---

## 2. Server-Time Playback Position Sync

### Core Formula

The playback position is never synced directly. Instead, the owner records *when* they
started the video (using server clock), and every client recomputes the current position
independently:

```
currentPosition = syncStartTime
                + (Networking.GetServerTimeInMilliseconds() - syncClockTime) / 1000f
                * syncSpeed
```

This formula is drift-resistant: a late joiner receives the same `syncClockTime` /
`syncStartTime` pair and arrives at the same position regardless of when they joined.

### Synced Variable Layout

| Variable | Type | Purpose |
|----------|------|---------|
| `syncUrl` | `VRCUrl` | Currently playing URL |
| `syncClockTime` | `int` | Server timestamp (ms) captured when sync was committed |
| `syncStartTime` | `float` | Playback offset (seconds) at the moment the sync was committed |
| `syncSpeed` | `float` | Playback rate (1.0 = normal, 0.5 = half-speed) |

> **int precision note**: `Networking.GetServerTimeInMilliseconds()` returns a signed 32-bit
> integer. It wraps after ~24.8 days of uptime. For sessions shorter than a few hours this is
> irrelevant, but for always-on worlds consider using the difference modulo `int.MaxValue` or
> switching to `GetServerTimeInSeconds()` (double) to avoid overflow.
> **The examples below use `int` for simplicity; production code should convert to `long` or
> `double` for sessions exceeding 24 hours.**

### Drift Correction

Because video decoders can drift slightly, clients run a periodic check. If the difference
between the expected position (formula result) and the actual player position exceeds a
threshold (~1 second), the client seeks to the correct position.

### Code Example

```csharp
using UdonSharp;
using UnityEngine;
using VRC.SDKBase;
using VRC.SDK3.Video.Components;
using VRC.SDK3.Video.Components.AVPro;

[UdonBehaviourSyncMode(BehaviourSyncMode.Manual)]
public class PlaybackTimeSynchronizer : UdonSharpBehaviour
{
    [SerializeField] private BaseVRCVideoPlayer _videoPlayer;

    [UdonSynced] private VRCUrl   _syncUrl       = VRCUrl.Empty;
    [UdonSynced] private int      _syncClockTime = 0;   // server ms at commit
    [UdonSynced] private float    _syncStartTime = 0f;  // playback offset at commit
    [UdonSynced] private float    _syncSpeed     = 1f;

    private const float DriftThreshold   = 1.0f;  // seconds before corrective seek
    private const float DriftCheckPeriod = 10.0f; // seconds between checks
    private float _nextDriftCheck = 0f;
    private bool  _isPlaying      = false;

    // === Owner: commit current sync state ===

    public void UpdateSyncedPosition()
    {
        if (!Networking.IsOwner(gameObject)) return;

        _syncClockTime = Networking.GetServerTimeInMilliseconds();
        _syncStartTime = _videoPlayer.GetTime();
        _syncSpeed     = 1f; // extend here for variable-speed support
        RequestSerialization();
    }

    // === All clients: apply synced state ===

    private float CalcExpectedPosition()
    {
        int elapsed = Networking.GetServerTimeInMilliseconds() - _syncClockTime;
        return _syncStartTime + (elapsed / 1000f) * _syncSpeed;
    }

    public void ApplySyncedPosition()
    {
        float expected = CalcExpectedPosition();
        float duration = _videoPlayer.GetDuration();

        // Don't seek past the end of the video
        if (duration > 0f && expected >= duration)
        {
            return;
        }

        _videoPlayer.SetTime(expected);
    }

    // === Playback state — consumers must call these when playback state changes ===
    // Note: drift correction is suppressed while paused to avoid spurious seeks.

    public void OnPlay()
    {
        _isPlaying = true;
    }

    public void OnPause()
    {
        _isPlaying = false;
    }

    // === Drift check (called from Update) ===

    void Update()
    {
        if (!_isPlaying) return;
        if (Time.time < _nextDriftCheck) return;
        _nextDriftCheck = Time.time + DriftCheckPeriod;

        float expected = CalcExpectedPosition();
        float actual   = _videoPlayer.GetTime();
        float drift    = Mathf.Abs(expected - actual);

        if (drift > DriftThreshold)
        {
            _videoPlayer.SetTime(expected);
        }
    }

    public override void OnDeserialization()
    {
        ApplySyncedPosition();
    }
}
```

---

## 3. Late Joiner Video Sync

### Flow

```
OnDeserialization
  → URL in synced state?
      → PlayURL(syncUrl)
          → OnVideoReady
              → CalcExpectedPosition()
                  → elapsed > duration?  YES → stay Idle (video ended)
                                         NO  → SetTime(expected) → Play
```

The critical constraint: **seek before `OnVideoReady` is silently ignored by the
video player**. Always wait for `OnVideoReady` to seek.

### Edge Cases

| Condition | Action |
|-----------|--------|
| Video has already ended (`elapsed >= duration`) | Set state to `Idle`, do not call `Play()` |
| Duration is 0 (live stream) | Skip the elapsed check; always play from current position |
| Same URL already loaded | Skip `PlayURL`; go straight to seek |

### Code Example

```csharp
using UdonSharp;
using UnityEngine;
using VRC.SDKBase;
using VRC.SDK3.Video.Components;
using VRC.SDK3.Video.Components.AVPro;

[UdonBehaviourSyncMode(BehaviourSyncMode.Manual)]
public class LateJoinerVideoSync : UdonSharpBehaviour
{
    [SerializeField] private BaseVRCVideoPlayer _videoPlayer;

    [UdonSynced] private VRCUrl _syncUrl       = VRCUrl.Empty;
    [UdonSynced] private int    _syncClockTime = 0;
    [UdonSynced] private float  _syncStartTime = 0f;

    private bool   _pendingSeek = false;
    private VRCUrl _currentUrl;

    public override void OnDeserialization()
    {
        // Only load if there is a URL to play
        if (_syncUrl == null || string.IsNullOrEmpty(_syncUrl.Get())) return;

        // If already playing the same URL, just sync position without reloading
        if (_currentUrl != null && _currentUrl.Get() == _syncUrl.Get())
        {
            ApplySync();
            return;
        }

        _pendingSeek = true;
        _currentUrl  = _syncUrl;
        // In production, route through UrlLoadScheduler (see Rate Limit Resolver pattern)
        _videoPlayer.PlayURL(_syncUrl);
        // Seek is deferred to OnVideoReady
    }

    public override void OnVideoReady()
    {
        if (!_pendingSeek) return;
        _pendingSeek = false;
        ApplySync();
    }

    private void ApplySync()
    {
        float elapsed  = (Networking.GetServerTimeInMilliseconds() - _syncClockTime) / 1000f;
        float expected = _syncStartTime + elapsed;
        float duration = _videoPlayer.GetDuration();

        // Video ended before this player joined
        if (duration > 0f && expected >= duration)
        {
            _videoPlayer.Stop();
            return;
        }

        _videoPlayer.SetTime(expected);
        _videoPlayer.Play();
    }

    public override void OnVideoError(VideoError error)
    {
        _pendingSeek = false;
    }
}
```

---

## 4. AVPro Texture Blit Buffering

### Problem

AVPro's output texture is updated asynchronously by the native video decoder. Between
decoder frames, the texture reference may briefly point to an invalid or blank buffer,
causing visible flickering on the display surface.

### Solution

Blit the AVPro output into a stable `RenderTexture` every `LateUpdate`. Because the
`RenderTexture` retains its last written content, viewers see the previous good frame
rather than a blank one during the brief gap. Assign the `RenderTexture` (not the AVPro
source texture) to the display material or `RawImage`.

> **Note**: Unity's built-in `VideoPlayer` component does **not** have this issue.
> Apply this pattern only when using an AVPro-based video player component.

### Namespace Required

```csharp
using VRC.SDK3.Rendering; // for VRCGraphics.Blit
```

### Code Example

```csharp
using UdonSharp;
using UnityEngine;
using VRC.SDKBase;
using VRC.SDK3.Video.Components.AVPro;
using VRC.SDK3.Rendering;

[UdonBehaviourSyncMode(BehaviourSyncMode.NoVariableSync)]
public class AVProTextureStabilizer : UdonSharpBehaviour
{
    [Header("Source")]
    [SerializeField] private VRCAvProVideoPlayer _avProPlayer;

    [Header("Output")]
    [SerializeField] private RenderTexture _stableTexture;
    [SerializeField] private Renderer[]    _displayRenderers;

    private bool _initialized = false;

    void Start()
    {
        Initialize();
    }

    private void Initialize()
    {
        if (_initialized) return;
        _initialized = true;

        // Assign the stable RenderTexture to all display surfaces
        foreach (Renderer r in _displayRenderers)
        {
            if (r != null)
            {
                r.material.mainTexture = _stableTexture;
            }
        }
    }

    void LateUpdate()
    {
        Initialize(); // defensive guard

        // Retrieve the live AVPro texture
        Texture sourceTexture = _avProPlayer.GetCurrentTexture();

        // Source may be null immediately after video start or during seeks
        if (sourceTexture == null) return;

        // Blit into the stable RenderTexture, preserving last-good frame on null
        VRCGraphics.Blit(sourceTexture, _stableTexture);
    }
}
```

---

## 5. Video Error Retry with Player Fallback

### VideoError Response Table

| `VideoError` value | Meaning | Recommended action |
|--------------------|---------|-------------------|
| `InvalidURL` | URL is malformed or unsupported | Permanent — do not retry |
| `AccessDenied` | Domain not on trusted list | Permanent — do not retry |
| `RateLimited` | Too many requests to the CDN | Retry after **5.5 seconds** |
| `PlayerError` | Decoder / codec mismatch | Retry N times; then try alternate player |
| `Unknown` | Unclassified failure | Retry once; give up on second failure |

### Retry Logic

```
OnVideoError
  → permanent error?  → SetState(Error), notify user, stop
  → retriable error?
      → retryCount < maxRetries?
          → schedule RetryLoad after retryDelay seconds
          → if PlayerError and retryCount >= maxRetries/2 → swap player type
      → retryCount >= maxRetries  → SetState(Error), give up
```

### Code Example

```csharp
using UdonSharp;
using UnityEngine;
using VRC.SDKBase;
using VRC.SDK3.Video.Components;
using VRC.SDK3.Video.Components.AVPro;

[UdonBehaviourSyncMode(BehaviourSyncMode.Manual)]
public class VideoErrorHandler : UdonSharpBehaviour
{
    [Header("Players (primary / fallback)")]
    [SerializeField] private BaseVRCVideoPlayer _primaryPlayer;
    [SerializeField] private BaseVRCVideoPlayer _fallbackPlayer;

    [Header("Retry Configuration")]
    [SerializeField] private int   _maxRetries       = 3;
    [SerializeField] private float _defaultRetryDelay = 2.0f;
    [SerializeField] private float _rateLimitedDelay  = 5.5f;

    [UdonSynced] private VRCUrl _currentUrl = VRCUrl.Empty;

    private int              _retryCount     = 0;
    private BaseVRCVideoPlayer _activePlayer;
    private bool             _usingFallback  = false;

    void Start()
    {
        _activePlayer = _primaryPlayer;
    }

    // Call this to start playback
    public void LoadUrl(VRCUrl url)
    {
        if (!Networking.IsOwner(gameObject))
        {
            Networking.SetOwner(Networking.LocalPlayer, gameObject);
        }

        _currentUrl  = url;
        _retryCount  = 0;
        _usingFallback = false;
        _activePlayer  = _primaryPlayer;

        RequestSerialization();
        _activePlayer.PlayURL(_currentUrl);
    }

    public override void OnVideoError(VideoError error)
    {
        // Permanent errors: don't retry
        if (error == VideoError.InvalidURL || error == VideoError.AccessDenied)
        {
            NotifyPermanentError(error);
            return;
        }

        // Rate limit: long wait, same player
        if (error == VideoError.RateLimited)
        {
            _retryCount++;
            if (_retryCount > _maxRetries)
            {
                NotifyPermanentError(error);
                return;
            }
            SendCustomEventDelayedSeconds(nameof(RetryLoad), _rateLimitedDelay);
            return;
        }

        // PlayerError or Unknown: increment counter
        _retryCount++;

        if (_retryCount > _maxRetries)
        {
            NotifyPermanentError(error);
            return;
        }

        // Switch to fallback player at the midpoint of retries for PlayerError
        if (error == VideoError.PlayerError && _retryCount > _maxRetries / 2)
        {
            _usingFallback = !_usingFallback;
            _activePlayer  = _usingFallback ? _fallbackPlayer : _primaryPlayer;
        }

        SendCustomEventDelayedSeconds(nameof(RetryLoad), _defaultRetryDelay);
    }

    public void RetryLoad()
    {
        if (_currentUrl == null || string.IsNullOrEmpty(_currentUrl.Get())) return;
        // In production, route through UrlLoadScheduler (see Rate Limit Resolver pattern)
        _activePlayer.PlayURL(_currentUrl);
    }

    private void NotifyPermanentError(VideoError error)
    {
        _retryCount = 0;
        Debug.LogWarning($"[VideoErrorHandler] Permanent error: {error}. Giving up.");
        // Notify state machine or UI here
    }

    public override void OnVideoReady()
    {
        _retryCount = 0; // successful load clears the counter
    }
}
```

---

## 6. Synced Playlist / Queue Management

### Queue Structure

| Synced variable | Type | Purpose |
|-----------------|------|---------|
| `_queueUrls` | `VRCUrl[]` | Ordered list of URLs |
| `_queuePlayerTypes` | `byte[]` | Player type per entry (0 = Unity, 1 = AVPro) |
| `_queueHead` | `int` | Index of the currently playing entry |

The queue is FIFO: `_queueHead` advances on each video end. Add appends to the logical
tail; the owner compacts the array only when removing mid-queue entries.

### Repeat Modes

| Mode constant | Behaviour |
|---------------|-----------|
| `RepeatNone` | Stop after the last entry |
| `RepeatOne` | Replay the current `_queueHead` URL indefinitely |
| `RepeatAll` | Reset `_queueHead` to 0 after the last entry |

### Code Example

```csharp
using UdonSharp;
using UnityEngine;
using VRC.SDKBase;
using VRC.SDK3.Video.Components;
using VRC.SDK3.Video.Components.AVPro;

[UdonBehaviourSyncMode(BehaviourSyncMode.Manual)]
public class SyncedPlaylistManager : UdonSharpBehaviour
{
    private const byte RepeatNone = 0;
    private const byte RepeatOne  = 1;
    private const byte RepeatAll  = 2;

    [Header("Player References")]
    [SerializeField] private BaseVRCVideoPlayer _unityPlayer;
    [SerializeField] private BaseVRCVideoPlayer _avProPlayer;

    [UdonSynced] private VRCUrl[] _queueUrls        = new VRCUrl[0];
    [UdonSynced] private byte[]   _queuePlayerTypes = new byte[0];
    [UdonSynced] private int      _queueHead        = 0;
    [UdonSynced] private byte     _repeatMode       = RepeatNone;

    // Owner-only: add a URL to the end of the queue
    public void AddToQueue(VRCUrl url, byte playerType)
    {
        if (!Networking.IsOwner(gameObject)) return;

        int len = _queueUrls.Length;
        VRCUrl[] newUrls  = new VRCUrl[len + 1];
        byte[]   newTypes = new byte[len + 1];

        for (int i = 0; i < len; i++)
        {
            newUrls[i]  = _queueUrls[i];
            newTypes[i] = _queuePlayerTypes[i];
        }
        newUrls[len]  = url;
        newTypes[len] = playerType;

        _queueUrls        = newUrls;
        _queuePlayerTypes = newTypes;
        RequestSerialization();

        // Start playback if queue was empty
        if (len == 0) PlayCurrentEntry();
    }

    // Owner-only: advance to the next queue entry
    public void AdvanceQueue()
    {
        if (!Networking.IsOwner(gameObject)) return;

        if (_repeatMode == RepeatOne)
        {
            PlayCurrentEntry(); // replay same index
            return;
        }

        int nextIndex = _queueHead + 1;

        if (nextIndex >= _queueUrls.Length)
        {
            if (_repeatMode == RepeatAll)
            {
                _queueHead = 0;
            }
            else
            {
                // RepeatNone: queue exhausted
                _queueHead = _queueUrls.Length;
                RequestSerialization();
                return;
            }
        }
        else
        {
            _queueHead = nextIndex;
        }

        RequestSerialization();
        PlayCurrentEntry();
    }

    // Owner-only: shuffle remaining entries (Fisher-Yates on indices after head)
    public void ShuffleRemaining()
    {
        if (!Networking.IsOwner(gameObject)) return;

        int start = _queueHead + 1;
        int end   = _queueUrls.Length - 1;

        for (int i = end; i > start; i--)
        {
            int j = Random.Range(start, i + 1);

            VRCUrl tempUrl  = _queueUrls[i];
            byte   tempType = _queuePlayerTypes[i];
            _queueUrls[i]        = _queueUrls[j];
            _queuePlayerTypes[i] = _queuePlayerTypes[j];
            _queueUrls[j]        = tempUrl;
            _queuePlayerTypes[j] = tempType;
        }

        RequestSerialization();
    }

    public void SetRepeatMode(byte mode)
    {
        if (!Networking.IsOwner(gameObject)) return;
        _repeatMode = mode;
        RequestSerialization();
    }

    private void PlayCurrentEntry()
    {
        if (_queueHead < 0 || _queueHead >= _queueUrls.Length) return;

        VRCUrl url        = _queueUrls[_queueHead];
        byte   playerType = _queuePlayerTypes[_queueHead];

        BaseVRCVideoPlayer player = (playerType == 1) ? _avProPlayer : _unityPlayer;
        player.PlayURL(url);
    }

    public override void OnVideoEnd()
    {
        AdvanceQueue();
    }
}
```

---

## 7. Platform-Specific URL Selection

### Problem

PC and Quest (Android) support different video codecs, resolutions, and bitrates. A URL
that works on PC may fail or perform poorly on Quest, and vice versa.

### Solution A — Compile-Time (Recommended for URL Arrays)

Use `#if UNITY_ANDROID` preprocessor directives to select between two sets of URL arrays.
The inactive branch is stripped at build time, resulting in smaller bundles.

### Solution B — Runtime

Read a platform tag at runtime and choose from paired fields. Suitable for individual
URL pairs where separate compile-time builds are impractical (e.g., single-URL picker UI).

### Code Example

```csharp
using UdonSharp;
using UnityEngine;
using VRC.SDKBase;
using VRC.SDK3.Video.Components;
using VRC.SDK3.Video.Components.AVPro;

[UdonBehaviourSyncMode(BehaviourSyncMode.NoVariableSync)]
public class PlatformUrlSelector : UdonSharpBehaviour
{
    // === Solution A: Compile-time selection (URL arrays) ===
#if UNITY_ANDROID
    [Header("Quest URLs")]
    [SerializeField] private VRCUrl[] _platformUrls;
#else
    [Header("PC URLs")]
    [SerializeField] private VRCUrl[] _platformUrls;
#endif

    // === Solution B: Runtime selection (individual URL pairs) ===

    [Header("Runtime URL Pairs")]
    [SerializeField] private VRCUrl _pcUrl;
    [SerializeField] private VRCUrl _questUrl;

    [SerializeField] private BaseVRCVideoPlayer _videoPlayer;

    // Play a specific index from the platform-appropriate array (Solution A)
    public void PlayByIndex(int index)
    {
        if (index < 0 || index >= _platformUrls.Length) return;
        // In production, route through UrlLoadScheduler (see Rate Limit Resolver pattern)
        _videoPlayer.PlayURL(_platformUrls[index]);
    }

    // Play using the runtime pair (Solution B)
    public void PlayWithRuntimeSelection()
    {
#if UNITY_ANDROID
        VRCUrl selected = _questUrl;
#else
        VRCUrl selected = _pcUrl;
#endif
        if (selected != null && !string.IsNullOrEmpty(selected.Get()))
        {
            // In production, route through UrlLoadScheduler (see Rate Limit Resolver pattern)
            _videoPlayer.PlayURL(selected);
        }
    }
}
```

> **Recommendation**: Use compile-time selection (`#if UNITY_ANDROID`) for URL arrays
> and playlists — the branch is eliminated entirely at build time, reducing asset size.
> Use runtime selection only when a single pair of URLs needs to be chosen dynamically
> (for example, when the URL is entered by a user at runtime).

---

## See Also

- [events.md](events.md) — `OnVideoReady`, `OnVideoEnd`, `OnVideoError`, and all video callbacks
- [patterns-networking.md](patterns-networking.md) — Ownership model, `RequestSerialization`, synced array helpers
- [patterns-performance.md](patterns-performance.md) — Frame budget management, `LateUpdate` cost
- [web-loading.md](web-loading.md) — `VRCUrl` trusted domains and rate limits
- [image-loading-vram.md](image-loading-vram.md) — GPU texture lifecycle (applies to `RenderTexture` targets)
