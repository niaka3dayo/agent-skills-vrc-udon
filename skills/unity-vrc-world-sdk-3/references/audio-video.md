# VRChat Audio & Video Guide

Complete guide for audio and video configuration.

## Table of Contents

- [Audio Overview](#audio-overview)
- [VRC_SpatialAudioSource](#vrc_spatialaudiosource)
- [Voice Settings](#voice-settings)
- [Steam Audio Integration](#steam-audio-integration)
- [Video Players](#video-players)
- [AVPro vs Unity Video Player](#avpro-vs-unity-video-player)
- [Video Player Setup](#video-player-setup)
- [Optimization](#optimization)
- [Troubleshooting](#troubleshooting)

---

## Audio Overview

### VRChat Audio Components

| Component | Purpose | Use Case |
|-----------|---------|----------|
| AudioSource | Unity standard audio | Basic sound playback |
| VRC_SpatialAudioSource | VRChat spatial audio | Companion for AudioSource; avoids SDK Build Panel warnings |
| VoiceSettings | Voice settings | Configured in VRC_SceneDescriptor |

### Audio System Architecture

```text
[Audio Source]
├── Unity AudioSource (base functionality)
└── VRC_SpatialAudioSource (extended functionality)
    ├── Gain control
    ├── Near/Far distance
    ├── Volumetric radius
    └── Spatialization options
```

---

## VRC_SpatialAudioSource

### Component Settings

Add `VRC_SpatialAudioSource` alongside Unity `AudioSource` components in world scenes to avoid SDK Build Panel warnings. Choose settings that preserve the sound's intent.
For the exact SDK warning text and Auto Fix side effects, see
[build-validation.md](build-validation.md#audiosource-and-vrc_spatialaudiosource).

| Property | Type | Description | Default / safe-preserve note |
|----------|------|-------------|------------------------------|
| **Gain** | float (dB) | Volume adjustment (0-24 dB) | 10 dB is common/default; use 0 dB for warning-only additions to preserve loudness |
| **Near** | float (m) | Attenuation start distance | 0 m unless the sound needs an intentional near field |
| **Far** | float (m) | Attenuation end distance (0=infinite) | Match existing `AudioSource.maxDistance` or intended audible range; avoid wider Auto Fix/default ranges |
| **Volumetric Radius** | float (m) | Source spread | 0 m for point sources; set intentionally for wide sources |
| **Enable Spatialization** | bool | Enable 3D positioning | false for intentional 2D/global audio; true for authored 3D audio |
| **Use AudioSource Volume Curve** | bool | Use AudioSource curve | true when preserving an existing custom 3D rolloff; otherwise choose deliberately |

### AudioSource Pairing Rule

```text
For every AudioSource in a VRChat world:
1. Add or keep VRC_SpatialAudioSource on the same GameObject.
2. Do not overwrite existing VRC_SpatialAudioSource values.
3. Preserve `volume`, `spatialBlend`, `rolloffMode`, `maxDistance`, and custom curves.
4. Use Gain = 0 dB for warning-only additions; raise Gain only for intentional sound design.
5. Set Far from `maxDistance` or the intended audible range; keep Near at 0 m unless an existing `minDistance`/Near value was intentionally authored.
```

| Audio intent | Safe VRC_SpatialAudioSource setup | Notes |
|--------------|-----------------------------------|-------|
| BGM / UI / global 2D audio | Enable Spatialization = false, Gain = 0 dB | Keeps the original 2D presentation; Near/Far are not the design control. |
| New 3D point SFX | Enable Spatialization = true, Gain = 0 dB, Far set to the intended audible distance | Tune loudness with `AudioSource.volume` first, then raise Gain only intentionally. |
| Existing tuned 3D AudioSource | Enable Spatialization = true, Use AudioSource Volume Curve = true, Gain = 0 dB, Far matched to `maxDistance`/design distance | Keeps authored rolloff/custom curves; avoid changing Near/Far unless requested. |
| Wide area source | Enable Spatialization = true, Gain = 0 dB unless intentionally boosted, set Volumetric Radius/Far explicitly | Use Volumetric Radius for source size; do not make Far large just to make it audible. |

### Distance Attenuation Model

```text
Near = 2m, Far = 10m example:

Distance(m): 0    2    4    6    8    10   12
Volume(%):   100  100  75   50   25   0    0
             ←Near→←--Attenuation--→←Far→

Near = Attenuation start (100% maintained)
Far = Attenuation end (0%)
```

### Volumetric Radius

```text
Volumetric Radius = 0 (point source):
- Calculated from listener-to-source distance
- For small objects

Volumetric Radius > 0 (volumetric source):
- Calculated from distance to the source's "surface"
- For large objects (waterfalls, crowds, etc.)
- Example: Radius=5m → attenuation starts from the surface of a 5m sphere
```

### Configuration Examples

#### Ambient Sound (BGM)

```text
AudioSource:
├── Spatial Blend: 0 (2D)
├── Loop: true
└── Volume: 0.5

VRC_SpatialAudioSource:
├── Gain: 0 dB (preserve original loudness)
├── Enable Spatialization: false
└── (Near/Far ignored in 2D mode)
```

#### 3D Sound Effects (footsteps, doors)

```text
AudioSource:
├── Spatial Blend: 1 (3D)
├── Loop: false
└── Volume: 1.0

VRC_SpatialAudioSource:
├── Gain: 0 dB (start from AudioSource volume)
├── Near: 1 m
├── Far: 15 m (intended audible distance)
├── Volumetric Radius: 0
└── Enable Spatialization: true
```

#### Wide Area Source (waterfall, crowd)

```text
AudioSource:
├── Spatial Blend: 1 (3D)
├── Loop: true
└── Volume: 1.0

VRC_SpatialAudioSource:
├── Gain: 0 dB unless the wide source is intentionally boosted
├── Near: 5 m
├── Far: 50 m (authored area, not an Auto Fix fallback)
├── Volumetric Radius: 10 m
└── Enable Spatialization: true
```

### Udon Control

```csharp
public class AudioController : UdonSharpBehaviour
{
    [SerializeField] private AudioSource audioSource;
    [SerializeField] private AudioClip[] clips;

    public void PlaySound(int index)
    {
        if (index >= 0 && index < clips.Length)
        {
            audioSource.PlayOneShot(clips[index]);
        }
    }

    public void SetVolume(float volume)
    {
        audioSource.volume = Mathf.Clamp01(volume);
    }

    // Leading underscore keeps this public member available to local code while blocking legacy network dispatch.
    public void _StopSound()
    {
        audioSource.Stop();
    }
}
```

---

## Voice Settings

### VRC_SceneDescriptor Voice Properties

| Property | Type | Description | Default |
|----------|------|-------------|---------|
| **Voice Falloff Range** | float | Voice attenuation range | - |
| **Voice Near** | float | Voice near distance | - |
| **Voice Far** | float | Voice far distance | - |
| **Voice Volume** | float | Voice volume | - |
| **Voice Disable Lowpass** | bool | Disable lowpass filter | false |

### Voice Zone (Udon)

```csharp
// Modify a player's voice settings
public class VoiceZone : UdonSharpBehaviour
{
    public override void OnPlayerTriggerEnter(VRCPlayerApi player)
    {
        if (player.isLocal)
        {
            // Change the range at which this player's voice is heard
        }
    }
}
```

---

## Steam Audio Integration

> **Status**: Shipped default. Steam Audio replaced ONSP as the spatializer for every player on every platform in
> VRChat client release **2025.4.2** ([December 3, 2025, Build 1768](https://docs.vrchat.com/docs/vrchat-202542)).
> This is a client version, not an SDK version — no SDK upgrade is involved.

### Steam Audio Replaced ONSP

VRChat's spatial audio backend is **Steam Audio** (Valve). It replaced **ONSP (Oculus Native Spatializer Plugin)**,
ending the open beta. There is no world descriptor setting for the spatializer and the release notes describe no
opt-out: Steam Audio is shipped to all players on every platform.

| Aspect | Current behavior |
|--------|------------------|
| Spatializer (in VRChat) | Steam Audio, all platforms |
| Spatializer (Unity Play Mode) | ClientSim still emulates through ONSP as of SDK 3.10.4 |
| Creator opt-in / opt-out | None; always active |
| `VRC_SpatialAudioSource` authoring | Unchanged; VRChat converts the component to Steam Audio at load time |
| Player voice | Deliberately **not** a 1:1 conversion — see [Player Voice Changed Audibly](#player-voice-changed-audibly) |
| Room reverb, occlusion, reflections | Not available; gated behind a future world SDK update |
| Legacy `ONSPAudioSource` components | Deprecated; Build Panel flags, Auto Fix converts — see below |

A runtime conversion layer keeps existing content working: author with `VRC_SpatialAudioSource` exactly as before
and VRChat converts it under the hood when the world loads. Most content came through unchanged — VRChat reported
that "almost all content will work without any adjustments" after two months of open beta — but the conversion is
not guaranteed to be inaudible
([Developer Update, December 4, 2025](https://ask.vrchat.com/t/developer-update-4-december-2025/47243)).

That update also draws a line that matters when triaging a complaint. Three symptoms are **functional bugs VRChat
wants reported**, not things to tune around: audio levels changing drastically, falloff curves not being respected,
and ranges not applying the same. Separately, some differences are expected and are the creator's to absorb:
direction and audible distance cues, and minor shifts in tonality, EQ, or mixing.

VRChat also added a server-side tuning path in
[2025.4.2p1](https://docs.vrchat.com/docs/vrchat-202542p1), so parts of the audio experience can change without a
client update. A world tuned by ear is worth re-checking occasionally rather than treated as settled.

Advanced Steam Audio capabilities are **not available to world creators**: "Certain aspects of Steam Audio will
require an update to our world SDK ... Until then, features like occlusion, reflections, audio raytracing, etc. will
not be available." No timeline has been announced.

Do not install the Steam Audio Unity package into a world project to reach those features. No Steam Audio component
appears on the [allowlisted world components](https://creators.vrchat.com/worlds/whitelisted-world-components/) list,
and components outside that list do not work in uploaded worlds. VRChat staff have stated that no Steam Audio
components are supported and that the package should not be installed into world SDK projects.

For the `ONSPAudioSource` Build Panel warning, what Auto Fix copies, and the listening check it calls for, see
[build-validation.md](build-validation.md#audiosource-and-vrc_spatialaudiosource).

### What This Means for World Creators

```text
Since client 2025.4.2:
├── Author with VRC_SpatialAudioSource exactly as before — same properties, same Inspector
├── VRChat converts the component to Steam Audio when the world loads
├── No new required configuration and no spatializer to choose
└── Judge the result in-client (Build & Test or an uploaded instance), not in Unity Play Mode
```

**Unity Play Mode is not a valid place to judge Steam Audio behavior.** ClientSim emulates `VRC_SpatialAudioSource`
through ONSP — `ClientSimSpatialAudioHelper` derives from `ONSPAudioSource` in SDK 3.10.4, and the SDK still ships
the Oculus spatializer plugins. What you hear in the editor is the old backend.

### Current Udon Audio APIs

The `VRCPlayerApi` voice setters are unchanged and remain the way to implement voice zones:

```csharp
// VRCPlayerApi voice control
player.SetVoiceGain(float gain);              // 0-24 dB, default 15
player.SetVoiceDistanceNear(float distance);  // Default: 0
player.SetVoiceDistanceFar(float distance);   // Default: 25
player.SetVoiceVolumetricRadius(float radius); // Default: 0
player.SetVoiceLowpass(bool enabled);         // Default: true
```

### Player Voice Changed Audibly

The API surface is unchanged, but what it sounds like is not. Voice is the one area where VRChat **deliberately did
not aim for a 1:1 conversion** from ONSP:

- Falloff curves differ slightly
- EQ and compressor tuning changed
- Source-directionality was added — a speaker's orientation relative to the listener now affects what you hear
- Client [2025.4.2p1](https://docs.vrchat.com/docs/vrchat-202542p1) applied further tuning to voice falloff and
  compression

Treat voice-zone values tuned before 2025.4.2 as a starting point to re-verify by ear, not as settings that reproduce
the old result.

### Audio Audit Checklist

Run these checks if the world sounds different after the switch:

```text
Report to VRChat as bugs — do not tune around these:
□ Audio levels changed drastically compared to how the world sounded under ONSP
□ Falloff curves are not being respected
□ Ranges are not applying the same

Expected differences — absorb these in your own tuning:
□ Direction and audible distance cues differ
□ Minor shifts in tonality, EQ, or mixing

VRC_SpatialAudioSource components:
□ Every AudioSource has a companion VRC_SpatialAudioSource, so the SDK Build Panel has no bare-AudioSource warning
□ Existing VRC_SpatialAudioSource values were preserved unless the design required a change
□ Warning-only additions use Gain = 0 dB and keep 2D/3D intent unchanged
□ Verify Near/Far values still achieve the intended effect
□ Check Gain values — especially sources touched by SDK Auto Fix
□ Volumetric Radius sources (waterfalls, crowds) behave as intended

Voice zones:
□ Re-verify every VRCPlayerApi voice setter the world calls by ear — SetVoiceGain, SetVoiceDistanceNear,
  SetVoiceDistanceFar, SetVoiceVolumetricRadius, SetVoiceLowpass
□ Account for source-directionality — a speaker facing away now sounds different

In-client listening pass:
□ Walk the world in-client and confirm sources match their intended tuning
□ Pay attention to wide Volumetric Radius sources and 2D/BGM loudness
□ Use the Audio Sources debug page (next section) to spot sources without a spatial audio component
```

Reverb and occlusion need no checks of their own:

- Unity Reverb Zones and Audio Mixer effects are not part of the spatializer swap
- The spatializer applies no occlusion of its own
- Manual occlusion, such as volume scripting, continues to work
- Steam Audio's own reverb and occlusion are not exposed to creators

### Inspecting Audio In-Client

The in-client **Audio Sources** debug page (added in client 2026.1.2) lists every active `AudioSource` in the world.
Its `VRC/SAS` column shows whether a source has a `VRC_SpatialAudioSource` and whether it was converted to Steam
Audio — use it to catch sources that never received a spatial audio component.

Open it with the **Toggle Debug UI** button at the bottom of the Quick Menu Settings page. By default only the world
author can open the Audio Sources page; enable **World Debugging** in the world's settings on the VRChat website to
let others see it — users already in the instance must rejoin before the page becomes available to them. See the
official [World Debug Views](https://creators.vrchat.com/worlds/udon/world-debug-views/) documentation for the full
column list.

---

## Video Players

### Types and Features

| Feature | AVPro | Unity Video Player |
|---------|-------|--------------------|
| **Live streaming** | ✅ Supported | ❌ Not supported |
| **YouTube/Twitch** | ✅ Supported | ❌ Not supported |
| **Local files** | ✅ | ✅ |
| **Editor preview** | ❌ | ✅ |
| **Quest support** | ✅ | ✅ |
| **HLS/DASH** | ✅ | ❌ |
| **Performance** | Good | Good |
| **Reliability** | High | Medium |

### Selection Guide

```text
Use AVPro:
✅ Want to play YouTube/Twitch URLs
✅ Want to display live streams
✅ Need high reliability

Use Unity Video Player:
✅ Want editor preview
✅ Simple local file playback
✅ Need a lightweight implementation
```

---

## AVPro vs Unity Video Player

### AVPro Video Player

```text
[Setup]
1. Use the VRCAVProVideoPlayer Prefab included in the VRChat SDK
2. Or add the VRC_AVProVideoPlayer component

[Features]
├── Supported URLs:
│   ├── YouTube (youtube.com, youtu.be)
│   ├── Twitch (twitch.tv)
│   ├── HLS/DASH streams
│   └── Direct video URLs
│
├── Audio:
│   └── Via VRC_AVProVideoSpeaker
│
└── Limitations:
    ├── Cannot play in the editor
    └── Some URLs not supported on Quest
```

### Unity Video Player

```text
[Setup]
1. Use the VRCUnityVideoPlayer Prefab
2. Or add the VRC_UnityVideoPlayer component

[Features]
├── Supported URLs:
│   ├── Direct video URLs (.mp4, .webm)
│   └── Local file references
│
├── Audio:
│   └── Direct AudioSource connection
│
└── Advantages:
    ├── Preview available in editor
    └── Simple setup
```

---

## Video Player Setup

### AVPro Video Player Setup

```text
[AVPro Video Player Object]
├── VRC_AVProVideoPlayer
│   ├── Auto Play: false (recommended)
│   ├── Loop: false
│   └── Maximum Resolution: 1080
│
├── Mesh/Quad (screen)
│   └── Material with RenderTexture
│
└── VRC_AVProVideoSpeaker
    ├── AudioSource
    └── VRC_SpatialAudioSource (for 3D)
```

### Unity Video Player Setup

```text
[Unity Video Player Object]
├── VRC_UnityVideoPlayer
│   ├── Auto Play: false (recommended)
│   └── Loop: false
│
├── Mesh/Quad (screen)
│   └── Material with RenderTexture
│
└── AudioSource
    └── VRC_SpatialAudioSource (for 3D)
```

### Udon Video Control

```csharp
using UdonSharp;
using UnityEngine;
using VRC.SDKBase;
using VRC.SDK3.Video.Components;
using VRC.SDK3.Video.Components.AVPro;

public class VideoController : UdonSharpBehaviour
{
    [SerializeField] private VRCAVProVideoPlayer avProPlayer;
    // Or
    // [SerializeField] private VRCUnityVideoPlayer unityPlayer;

    [SerializeField] private VRCUrl defaultUrl;

    private bool _isPlaying = false;

    void Start()
    {
        // Initialization
    }

    public override void Interact()
    {
        // Toggle playback
        if (_isPlaying)
        {
            avProPlayer.Stop();
            _isPlaying = false;
        }
        else
        {
            avProPlayer.PlayURL(defaultUrl);
            _isPlaying = true;
        }
    }

    // Video events
    public override void OnVideoStart()
    {
        Debug.Log("Video started");
        _isPlaying = true;
    }

    public override void OnVideoEnd()
    {
        Debug.Log("Video ended");
        _isPlaying = false;
    }

    public override void OnVideoError(VRC.SDK3.Components.Video.VideoError videoError)
    {
        Debug.LogError($"Video error: {videoError}");
        _isPlaying = false;
    }
}
```

### URL-Synced Video Player

```csharp
using UdonSharp;
using UnityEngine;
using VRC.SDKBase;
using VRC.SDK3.Video.Components.AVPro;

[UdonBehaviourSyncMode(BehaviourSyncMode.Manual)]
public class SyncedVideoPlayer : UdonSharpBehaviour
{
    [SerializeField] private VRCAVProVideoPlayer videoPlayer;

    [UdonSynced, FieldChangeCallback(nameof(SyncedUrl))]
    private VRCUrl _syncedUrl;

    public VRCUrl SyncedUrl
    {
        get => _syncedUrl;
        set
        {
            _syncedUrl = value;
            if (_syncedUrl != null && _syncedUrl.Get() != "")
            {
                videoPlayer.PlayURL(_syncedUrl);
            }
        }
    }

    public void PlayVideo(VRCUrl url)
    {
        if (!Networking.IsOwner(gameObject))
        {
            Networking.SetOwner(Networking.LocalPlayer, gameObject);
        }

        SyncedUrl = url;
        RequestSerialization();
    }
}
```

---

## Optimization

### Audio Optimization

```text
Compression settings:

BGM (long audio):
├── Load Type: Streaming
├── Compression Format: Vorbis
├── Quality: 70%
└── Sample Rate: 44100 Hz

Sound effects (short audio):
├── Load Type: Decompress On Load
├── Compression Format: Vorbis
├── Quality: 50-70%
└── Preload Audio Data: ✅

Ambient sounds (looping):
├── Load Type: Compressed In Memory
├── Compression Format: Vorbis
├── Quality: 50%
└── Loop: ✅
```

### Video Optimization

```text
⚠️ Limitations:

Video players per world:
├── Recommended: 1-2
└── Maximum: not documented — performance-bound in practice

Simultaneous playback:
├── Avoid simultaneous playback
└── Use low resolution if necessary

Resolution settings:
├── PC: Up to 1080p
├── Quest: 720p recommended
└── Limit with Maximum Resolution
```

### Memory Considerations

```text
Video player memory impact:

RenderTexture size:
├── 1920x1080: ~8MB
├── 1280x720: ~4MB
└── 854x480: ~2MB

Countermeasures:
□ Use only the necessary resolution
□ Stop when not in use
□ Size RenderTexture appropriately
```

---

## Troubleshooting

### Audio Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| No sound | Volume = 0 | Check Volume |
| No sound | Spatial Blend misconfigured | Check 2D/3D |
| No 3D positioning | Enable Spatialization = false | Enable it for authored 3D audio only |
| Too loud/quiet | Gain or AudioSource volume setting | Start with `AudioSource.volume`; use Gain intentionally |
| Can't hear at distance | Far setting too small | Increase Far only to the intended audible distance |

### Video Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| Won't play | Unsupported URL | AVPro + supported URL |
| Won't play on Quest | Unsupported URL | Use direct URL |
| No audio | Speaker not configured | Add AVProVideoSpeaker |
| Black screen | RenderTexture not connected | Check Material |
| Stuttering | High resolution | Lower Maximum Resolution |

### Common Audio Code Issues

```csharp
// ❌ Problem: No AudioSource caching
void PlaySound()
{
    GetComponent<AudioSource>().Play(); // Searches every time
}

// ✅ Solution: Use caching
private AudioSource _audioSource;

void Start()
{
    _audioSource = GetComponent<AudioSource>();
}

void PlaySound()
{
    _audioSource.Play();
}
```

### Debugging Tips

```csharp
// Check audio state
Debug.Log($"Audio playing: {audioSource.isPlaying}");
Debug.Log($"Volume: {audioSource.volume}");
Debug.Log($"Spatial Blend: {audioSource.spatialBlend}");

// Check video state
Debug.Log($"Video ready: {videoPlayer.IsReady}");
Debug.Log($"Video playing: {videoPlayer.IsPlaying}");
```

---

## Quick Reference

### VRC_SpatialAudioSource Defaults and Safe Additions

```text
Common/default starting points:
Gain: 10 dB
Near: 0 m
Far: 40 m common default, but prefer existing AudioSource.maxDistance or intended range
Volumetric Radius: 0 m
Enable Spatialization: true for 3D audio

Safe warning-only addition:
Gain: 0 dB
Enable Spatialization: keep the AudioSource intent (false for 2D/global, true for 3D)
Use AudioSource Volume Curve: true when preserving an authored 3D rolloff
Far: match existing AudioSource.maxDistance or intended range
Near: keep 0 m unless an existing minDistance/Near value was authored
```

### Video Player Events

```csharp
public override void OnVideoStart() { }
public override void OnVideoEnd() { }
public override void OnVideoError(VideoError error) { }
public override void OnVideoReady() { }
public override void OnVideoLoop() { }
```

### Audio Compression Quick Guide

| Type | Load Type | Format | Quality |
|------|-----------|--------|---------|
| BGM | Streaming | Vorbis | 70% |
| SFX | Decompress | Vorbis | 50-70% |
| Ambient | Compressed | Vorbis | 50% |

## See Also

- [components.md](components.md) - Full component reference including VRCAVProVideoPlayer and VRCUnityVideoPlayer setup
- [UdonSharp Video Player Patterns](../../unity-vrc-udon-sharp/references/patterns-video.md) - Advanced video player implementation patterns (state machine, playback sync, error retry, playlist management)
