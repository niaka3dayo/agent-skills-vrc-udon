# Image Loading — VRAM & Memory Management

**Supported SDK Versions**: 3.7.1+ (image loading), 3.7.1 - 3.10.3 (SDK coverage: 3.7.1 - 3.10.3)

Extended memory management guide for `VRCImageDownloader`. Covers GPU memory lifecycle,
safe texture cleanup, double-buffer fade, stock vs. streaming mode, mipmap bias control,
and multi-instance staggering. For the base API reference see [web-loading.md](web-loading.md).

## Overview

| Topic | Summary |
|-------|---------|
| **VRAM accumulation** | Why textures stay in GPU memory and how leaks occur |
| **Dispose vs Destroy** | What each frees, when to use which |
| **Double-buffer fade** | Smooth crossfade between images without destroying visible textures |
| **Stock vs streaming mode** | Cache-all vs download-every-cycle tradeoff |
| **Mipmap bias control** | Distance-based sharpness tuning to reduce VRAM at range |
| **Multi-instance staggering** | Spreading download start times to avoid rate-limit pile-ups |
| **Anti-patterns** | Common mistakes and their correct alternatives |

---

## VRAM Accumulation Mechanism

### Managed Memory vs GPU Memory

C# memory is managed by the .NET garbage collector (GC). When you stop holding a reference
to a C# object, the GC can reclaim it. However, `Texture2D` is a **Unity engine object**:
it has a small C# wrapper, but the actual pixel data lives in **unmanaged GPU memory** (VRAM).
The GC sees only the tiny C# wrapper and cannot reclaim the GPU allocation.

```
C# heap (managed):                  GPU VRAM (unmanaged):
┌──────────────────────────┐        ┌───────────────────────────────┐
│ Texture2D wrapper  (40 B)│──────> │ Pixel data  (width×height×bpp)│
└──────────────────────────┘        └───────────────────────────────┘
  GC can free this                    GC cannot touch this
```

When `Texture2D` goes out of scope in C#, the wrapper is eventually collected, but the
GPU allocation persists until `UnityEngine.Object.Destroy(texture)` is explicitly called.

### What Happens Without Cleanup

Each call to `VRCImageDownloader.DownloadImage()` creates a new `Texture2D` in VRAM.
If you overwrite a reference without destroying the old texture, the old VRAM allocation
is silently abandoned:

```csharp
// This creates a leak every time a new image loads
public override void OnImageLoadSuccess(IVRCImageDownload result)
{
    // result.Result is a NEW Texture2D in VRAM.
    // The texture that was in targetMaterial.mainTexture before is still in VRAM
    // and now has no reference — it will never be freed.
    targetMaterial.mainTexture = result.Result;
}
```

Over time, VRAM grows without bound. In a world that cycles images every 30 seconds,
a 2048x2048 RGBA32 texture consumes about 16 MB per download. After 20 cycles:
**320 MB of leaked VRAM**. This causes degraded performance and eventually crashes.

### VRAM Cost Reference

| Resolution | Format | VRAM (no mipmaps) | VRAM (with mipmaps) |
|------------|--------|-------------------|---------------------|
| 512 x 512 | RGBA32 | ~1 MB | ~1.3 MB |
| 1024 x 1024 | RGBA32 | ~4 MB | ~5.3 MB |
| 2048 x 2048 | RGBA32 | ~16 MB | ~21.3 MB |
| 2048 x 2048 | RGB24 | ~12 MB | ~16 MB |

> Mipmaps add approximately 33% to the base texture size.

---

## `Dispose()` vs `Destroy()` — Critical Distinction

These two operations are often confused. They free **different things**.

| Operation | What It Frees | What It Does NOT Free |
|-----------|--------------|----------------------|
| `IVRCImageDownload.Dispose()` | The download result wrapper and its internal state | The `Texture2D` already assigned to a material |
| `VRCImageDownloader.Dispose()` | All pending and completed download result wrappers | Textures already assigned to materials |
| `UnityEngine.Object.Destroy(texture)` | The GPU VRAM allocation for that `Texture2D` | Nothing else — only this one texture |

### The Golden Rule

After you assign `result.Result` to a material, the `VRCImageDownloader` no longer owns
that texture — **you do**. Calling `Dispose()` on the downloader or the download result
does not free a texture you have applied to a material. You must call
`UnityEngine.Object.Destroy(oldTexture)` yourself.

### Correct Cleanup Sequence

```csharp
using UdonSharp;
using UnityEngine;
using VRC.SDKBase;
using VRC.SDK3.ImageLoading;
using VRC.Udon.Common.Interfaces;

[UdonBehaviourSyncMode(BehaviourSyncMode.NoVariableSync)]
public class SafeImageLoader : UdonSharpBehaviour
{
    [SerializeField] private VRCUrl imageUrl;
    [SerializeField] private Renderer targetRenderer;

    private VRCImageDownloader _downloader;
    private IVRCImageDownload _currentDownload;

    /** Texture currently displayed on the renderer — we own this VRAM allocation */
    private Texture2D _activeTexture;

    void Start()
    {
        _downloader = new VRCImageDownloader();
    }

    public void LoadImage()
    {
        // Dispose the previous download result wrapper (frees VRC internal state)
        if (_currentDownload != null)
        {
            _currentDownload.Dispose();
            _currentDownload = null;
        }

        TextureInfo info = new TextureInfo();
        info.GenerateMipmaps = true;
        info.FilterMode = FilterMode.Trilinear;

        _currentDownload = _downloader.DownloadImage(
            imageUrl,
            null,                       // pass null — we apply the texture manually
            (IUdonEventReceiver)this,
            info
        );
    }

    public override void OnImageLoadSuccess(IVRCImageDownload result)
    {
        // Step 1: Destroy the OLD texture to free its VRAM
        if (_activeTexture != null)
        {
            Destroy(_activeTexture);
            _activeTexture = null;
        }

        // Step 2: Take ownership of the new texture
        _activeTexture = result.Result;

        // Step 3: Apply to renderer
        if (targetRenderer != null)
        {
            targetRenderer.material.mainTexture = _activeTexture;
        }
    }

    public override void OnImageLoadError(IVRCImageDownload result)
    {
        Debug.LogError($"[SafeImageLoader] Error {result.ErrorCode}: {result.Error}");
    }

    void OnDestroy()
    {
        // Clean up everything when this behaviour is destroyed
        if (_downloader != null)
        {
            _downloader.Dispose();
        }

        // The downloader.Dispose() above freed the VRC wrappers.
        // We still need to destroy the texture we own separately.
        if (_activeTexture != null)
        {
            Destroy(_activeTexture);
            _activeTexture = null;
        }
    }
}
```

---

## Double-Buffer Fade Pattern

### Why a Single Texture Is Not Enough

When you want a smooth crossfade between images, you cannot destroy the old texture the
moment the new one arrives — it is still visible on screen during the fade animation.
Destroying it mid-fade produces a black flash or missing texture.

The solution is a **double-buffer**: two Renderer slots (A and B) that alternate roles.
The new image loads into the "back" slot, a fade animation plays, and once the fade is
complete the old texture is safe to destroy.

```
State 0 — Image X is displayed on Renderer A (front)
           Renderer B is idle (back)

State 1 — Download Image Y completes
           Apply Image Y to Renderer B (back)
           Begin fade: A fades out, B fades in

State 2 — Fade complete
           Renderer B is now front; Renderer A is back
           NOW safe to Destroy Image X texture
           Swap front/back references for next cycle
```

### Important: No Coroutines in UdonSharp

UdonSharp does not support C# coroutines (`IEnumerator` / `yield return`). For
time-delayed operations, use `SendCustomEventDelayedSeconds(nameof(MethodName), delay)`.

### Full Double-Buffer Implementation

```csharp
using UdonSharp;
using UnityEngine;
using VRC.SDKBase;
using VRC.SDK3.ImageLoading;
using VRC.Udon.Common.Interfaces;

[UdonBehaviourSyncMode(BehaviourSyncMode.NoVariableSync)]
public class DoubleBufferImageDisplay : UdonSharpBehaviour
{
    [Header("Renderers (A/B double buffer)")]
    [SerializeField] private Renderer rendererA;
    [SerializeField] private Renderer rendererB;

    [Header("Fade settings")]
    [SerializeField] private float fadeDuration = 1.0f;
    [SerializeField] private string alphaProperty = "_Alpha";

    [Header("Image URLs")]
    [SerializeField] private VRCUrl[] imageUrls;
    [SerializeField] private float displayDuration = 10.0f;

    private VRCImageDownloader _downloader;
    private IVRCImageDownload _pendingDownload;

    /** Index into imageUrls for the next image to load */
    private int _nextUrlIndex = 0;

    /** Which renderer is currently showing (front) */
    private bool _frontIsA = true;

    /** Textures we own; must be Destroyed when no longer needed */
    private Texture2D _textureA;
    private Texture2D _textureB;

    /** Texture scheduled for destruction after fade completes */
    private Texture2D _textureToDispose;

    /** True while a fade animation is in progress */
    private bool _isFading = false;

    /** Elapsed seconds since fade started — driven by Update */
    private float _fadeElapsed = 0f;

    void Start()
    {
        _downloader = new VRCImageDownloader();

        // Initialize both renderers fully transparent
        SetRendererAlpha(rendererA, 0f);
        SetRendererAlpha(rendererB, 0f);

        // Load the first image
        LoadNextImage();
    }

    // ── Download ────────────────────────────────────────────────────────────

    private void LoadNextImage()
    {
        if (imageUrls == null || imageUrls.Length == 0) return;

        // Dispose previous pending download result wrapper
        if (_pendingDownload != null)
        {
            _pendingDownload.Dispose();
            _pendingDownload = null;
        }

        TextureInfo info = new TextureInfo();
        info.GenerateMipmaps = true;
        info.FilterMode = FilterMode.Trilinear;

        _pendingDownload = _downloader.DownloadImage(
            imageUrls[_nextUrlIndex],
            null,
            (IUdonEventReceiver)this,
            info
        );

        _nextUrlIndex = (_nextUrlIndex + 1) % imageUrls.Length;
    }

    public override void OnImageLoadSuccess(IVRCImageDownload result)
    {
        if (_isFading) return; // Ignore if a fade is already running

        Texture2D newTexture = result.Result;

        // Apply new texture to the BACK renderer
        Renderer backRenderer = _frontIsA ? rendererB : rendererA;
        backRenderer.material.mainTexture = newTexture;
        SetRendererAlpha(backRenderer, 0f);

        // Store reference so we can track which slot gets the new texture
        if (_frontIsA)
        {
            // New texture goes to B; remember current A texture for later disposal
            _textureToDispose = _textureA;
            _textureB = newTexture;
        }
        else
        {
            _textureToDispose = _textureB;
            _textureA = newTexture;
        }

        // Start the fade animation
        _isFading = true;
        _fadeElapsed = 0f;
    }

    public override void OnImageLoadError(IVRCImageDownload result)
    {
        Debug.LogError($"[DoubleBuffer] Error {result.ErrorCode}: {result.Error}");
        // Retry after display duration to keep cycling
        SendCustomEventDelayedSeconds(nameof(LoadNextImage), displayDuration);
    }

    // ── Fade animation via Update ────────────────────────────────────────────

    void Update()
    {
        if (!_isFading) return;

        _fadeElapsed += Time.deltaTime;
        float t = Mathf.Clamp01(_fadeElapsed / fadeDuration);

        Renderer front = _frontIsA ? rendererA : rendererB;
        Renderer back  = _frontIsA ? rendererB : rendererA;

        SetRendererAlpha(front, 1f - t); // front fades out
        SetRendererAlpha(back,  t);       // back fades in

        if (t >= 1f)
        {
            OnFadeComplete();
        }
    }

    private void OnFadeComplete()
    {
        _isFading = false;

        // Swap front/back
        _frontIsA = !_frontIsA;

        // Hide the (now back) old renderer
        Renderer newBack = _frontIsA ? rendererB : rendererA;
        SetRendererAlpha(newBack, 0f);

        // The old texture is no longer visible — safe to destroy VRAM now
        // Use a small delay to ensure the render frame has fully committed
        SendCustomEventDelayedSeconds(nameof(DestroyOldTexture), 0.1f);

        // Schedule the next download after the display duration
        SendCustomEventDelayedSeconds(nameof(LoadNextImage), displayDuration);
    }

    /** Called via SendCustomEventDelayedSeconds after the fade is complete.
     *  Must be public because SendCustomEventDelayedSeconds requires a public method.
     *  Do not call directly from other behaviours. */
    public void DestroyOldTexture()
    {
        if (_textureToDispose != null)
        {
            Destroy(_textureToDispose);
            _textureToDispose = null;
        }
    }

    // ── Helpers ──────────────────────────────────────────────────────────────

    private void SetRendererAlpha(Renderer r, float alpha)
    {
        if (r == null) return;
        r.material.SetFloat(alphaProperty, alpha);
    }

    void OnDestroy()
    {
        if (_downloader != null) _downloader.Dispose();
        if (_textureA != null)   Destroy(_textureA);
        if (_textureB != null)   Destroy(_textureB);
        if (_textureToDispose != null) Destroy(_textureToDispose);
    }
}
```

> **Shader requirement**: The `_Alpha` property used above must exist in the material's
> shader. Standard transparent shaders expose `_Color.a`. For an opaque material you
> would typically use two stacked renderers whose `_Color.a` or a custom blend parameter
> is animated. Adjust `alphaProperty` to match your shader.

---

## Stock Mode vs Streaming Mode

### Streaming Mode (Low VRAM, Repeated Bandwidth)

Download the next image each cycle. After the fade, destroy the old texture. VRAM holds
at most two textures at once regardless of how many images are in the playlist.

```
Cycle 1: Download A  → display A  → VRAM: A
Cycle 2: Download B  → fade A→B  → Destroy A  → VRAM: B
Cycle 3: Download C  → fade B→C  → Destroy B  → VRAM: C
...
```

**VRAM cost**: constant at 2× texture size (front + back during fade).
**Bandwidth cost**: one download per cycle, every display cycle.

### Stock Mode (High VRAM, No Repeat Downloads)

Download all images once, store the textures in a `Material[]` array. On repeat visits
to the same image, use the cached texture — no download, instant transition.

```
Startup: Download A, B, C, D  → VRAM: A + B + C + D
Runtime: Cycle through cached textures  → no further downloads
```

**VRAM cost**: N × texture size, fixed.
**Bandwidth cost**: one download per image, ever.

### Decision Table

| Criterion | Use Streaming | Use Stock |
|-----------|:------------:|:---------:|
| Playlist has many images (10+) | Yes | |
| Playlist is small (2–6 images) | | Yes |
| VRAM budget is tight (Quest) | Yes | |
| VRAM budget is generous (PC) | | Yes |
| Transitions must feel instant | | Yes |
| Bandwidth conservation matters | | Yes |
| Images change frequently (daily) | Yes | |
| Users will revisit images repeatedly | | Yes |

### Stock Mode Implementation

```csharp
using UdonSharp;
using UnityEngine;
using VRC.SDKBase;
using VRC.SDK3.ImageLoading;
using VRC.Udon.Common.Interfaces;

[UdonBehaviourSyncMode(BehaviourSyncMode.NoVariableSync)]
public class StockModeGallery : UdonSharpBehaviour
{
    [Header("Gallery URLs (all downloaded at startup)")]
    [SerializeField] private VRCUrl[] imageUrls;

    [Header("Materials — one per image slot")]
    [SerializeField] private Material[] galleryMaterials;

    [Header("Display renderer")]
    [SerializeField] private Renderer displayRenderer;

    private VRCImageDownloader _downloader;

    /** Number of valid slots (min of imageUrls.Length and galleryMaterials.Length) */
    private int _count = 0;

    /** Which downloads have completed (cached flag per slot) */
    private bool[] _loaded;

    /** How many downloads are complete */
    private int _loadedCount = 0;

    /** Which slot is currently displayed */
    private int _displayIndex = 0;

    /** Whether startup downloads are still in progress */
    private bool _isLoading = true;

    /** Index of the next image to download in the sequential chain */
    private int _nextDownloadIndex = 0;

    void Start()
    {
        if (imageUrls == null || galleryMaterials == null) return;

        int count = Mathf.Min(imageUrls.Length, galleryMaterials.Length);
        _count = count;
        _loaded = new bool[count];
        _downloader = new VRCImageDownloader();

        // Start the sequential download chain (no loop — UdonSharp has no closures)
        DownloadNext();
    }

    public void DownloadNext()
    {
        int idx = _nextDownloadIndex;
        if (idx < 0 || idx >= _count) return;

        TextureInfo info = new TextureInfo();
        info.GenerateMipmaps = true;
        info.FilterMode = FilterMode.Trilinear;

        _downloader.DownloadImage(
            imageUrls[idx],
            galleryMaterials[idx],      // downloader applies texture to this material
            (IUdonEventReceiver)this,
            info
        );

        _nextDownloadIndex++;

        // Schedule the next download 5.5 s later to respect the 5-second rate limit
        if (_nextDownloadIndex < _count)
        {
            SendCustomEventDelayedSeconds(nameof(DownloadNext), 5.5f);
        }
    }

    public override void OnImageLoadSuccess(IVRCImageDownload result)
    {
        // Find which slot matches the material the downloader filled
        for (int i = 0; i < _count; i++)
        {
            if (galleryMaterials[i] == result.Material)
            {
                _loaded[i] = true;
                _loadedCount++;
                break;
            }
        }

        if (_loadedCount >= _count)
        {
            _isLoading = false;
            Debug.Log("[StockGallery] All images cached");
        }
    }

    public override void OnImageLoadError(IVRCImageDownload result)
    {
        Debug.LogError($"[StockGallery] Load error: {result.Error}");
        // Note: the failed slot remains unloaded (_loaded[idx] stays false).
        // A production implementation should track and retry failed indices.
    }

    /** Show the image at the given index (instant swap from cache) */
    public void ShowImage(int index)
    {
        if (index < 0 || index >= _count) return;
        if (!_loaded[index]) return; // Not ready yet

        _displayIndex = index;
        displayRenderer.material = galleryMaterials[index];
    }

    public void ShowNext()
    {
        int next = (_displayIndex + 1) % _count;
        ShowImage(next);
    }

    public void ShowPrev()
    {
        int prev = (_displayIndex - 1 + _count) % _count;
        ShowImage(prev);
    }

    public bool IsLoading => _isLoading;

    void OnDestroy()
    {
        // Note: textures are owned by the materials, not by us directly.
        // Dispose the downloader to release VRC wrapper objects.
        if (_downloader != null) _downloader.Dispose();
    }
}
```

> **Quest note**: On Quest, each 2048x2048 RGBA texture costs ~16 MB of VRAM.
> Caching 6 such textures consumes ~96 MB — test on Quest hardware before shipping stock mode.

---

## Distance-Based Mipmap Bias Control

### What Is Mipmap Bias?

Mipmaps are pre-generated lower-resolution copies of a texture (1/2, 1/4, 1/8 ... size).
The GPU selects a mip level based on how many screen pixels the texture covers. A
**mipmap bias** shifts that selection:

| Bias | Effect | VRAM impact |
|------|--------|-------------|
| Negative (e.g. −2) | Forces a sharper (larger) mip level | Higher bandwidth, more cache pressure |
| 0 | Default automatic selection | Neutral |
| Positive (e.g. +2) | Forces a blurrier (smaller) mip level | Lower bandwidth, less cache pressure |

By computing bias from player distance you can save GPU memory and bandwidth when the
player is far from an image display, while keeping it sharp up close.

### Distance-to-Bias Mapping

A logarithmic curve gives a natural feel: the bias increases slowly near the object
and accelerates as distance grows.

```
bias = log2(distance / sharpDistance)
```

Clamped to a useful range: −1 (slightly sharper than default) to +4 (very blurry).

### When Update() Polling Is Acceptable

Generally, polling in `Update()` is an anti-pattern (use events instead). Mipmap bias is
an **exception**: it must track the player's continuous movement through space, and there
is no VRChat event that fires on position change. The operation is cheap (one distance
calculation and one material property set per frame), so per-frame polling is acceptable here.

Consider the Update Handler Pattern from [patterns-performance.md](patterns-performance.md)
to disable this Update loop when no players are in range.

### Shader Requirement

Standard Unity shaders respect `material.mipMapBias` on sampler state, but `tex2Dlod`
in a custom shader gives explicit per-sample mip control. A minimal custom surface shader:

```hlsl
// Minimal custom shader supporting manual mipmap level via _MipmapBias
Shader "Custom/MipmapBiasDisplay"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _MipmapBias ("Mipmap Bias", Range(-4, 8)) = 0
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100
        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

            sampler2D _MainTex;
            float4 _MainTex_ST;
            float _MipmapBias;

            struct appdata { float4 vertex : POSITION; float2 uv : TEXCOORD0; };
            struct v2f    { float4 pos : SV_POSITION; float2 uv : TEXCOORD0; };

            v2f vert(appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv  = TRANSFORM_TEX(v.uv, _MainTex);
                return o;
            }

            fixed4 frag(v2f i) : SV_Target
            {
                // tex2Dlod: explicit mip level selection via w component
                float mip = clamp(_MipmapBias, -4, 8);
                return tex2Dlod(_MainTex, float4(i.uv, 0, mip));
            }
            ENDCG
        }
    }
}
```

### UdonSharp Behaviour

```csharp
using UdonSharp;
using UnityEngine;
using VRC.SDKBase;

[UdonBehaviourSyncMode(BehaviourSyncMode.NoVariableSync)]
public class MipmapBiasController : UdonSharpBehaviour
{
    [Header("Display to control")]
    [SerializeField] private Renderer displayRenderer;

    [Header("Bias curve settings")]
    [Tooltip("Distance at which bias = 0 (full sharpness)")]
    [SerializeField] private float sharpDistance = 3.0f;

    [Tooltip("Minimum bias (never go sharper than this)")]
    [SerializeField] private float minBias = -1.0f;

    [Tooltip("Maximum bias applied at extreme distance")]
    [SerializeField] private float maxBias = 4.0f;

    [Tooltip("Object scale factor — larger objects need a higher sharpDistance")]
    [SerializeField] private float objectScaleFactor = 1.0f;

    private static readonly int MipmapBiasId = Shader.PropertyToID("_MipmapBias");

    private Material _material;

    void Start()
    {
        if (displayRenderer != null)
        {
            // Instance the material so we do not affect other renderers sharing it
            _material = displayRenderer.material;
        }
    }

    void Update()
    {
        if (_material == null) return;

        VRCPlayerApi localPlayer = Networking.LocalPlayer;
        if (localPlayer == null || !localPlayer.IsValid()) return;

        // Use head bone position for accurate VR head distance
        Vector3 headPos = localPlayer.GetBonePosition(HumanBodyBones.Head);
        if (headPos == Vector3.zero)
        {
            // Fallback: tracking data position
            headPos = localPlayer.GetTrackingData(VRCPlayerApi.TrackingDataType.Head).position;
        }

        float distance = Vector3.Distance(headPos, displayRenderer.transform.position);

        // Account for object scale — a large display panel is "closer" perceptually
        float scaledSharp = sharpDistance * objectScaleFactor;

        // Logarithmic mapping: bias = log2(distance / scaledSharp)
        float rawBias = scaledSharp > 0f
            ? Mathf.Log(distance / scaledSharp, 2f)
            : 0f;

        float bias = Mathf.Clamp(rawBias, minBias, maxBias);
        _material.SetFloat(MipmapBiasId, bias);
    }
}
```

> **Mipmap prerequisite**: `TextureInfo.GenerateMipmaps = true` must be set when calling
> `DownloadImage`. A texture without mipmaps has only mip level 0; applying a positive
> bias on a non-mipmapped texture has no visible effect and wastes shader cycles.

---

## Multi-Instance Delay Staggering

### The Problem

VRChat's image download rate limit is **one download per 5 seconds, shared across the
entire scene**. When multiple image loaders in the same world all call `DownloadImage()`
at startup (or on world join), they compete for the same slot. All but the first are
queued. Worse, if all loaders retry on error simultaneously, they create a burst pattern
that keeps them competing forever.

### The Solution: Inspector-Assigned Delay Order

Give each instance a serialized `_delayOrder` field. Each instance multiplies its order
by a base delay to stagger when it first downloads.

```csharp
using UdonSharp;
using UnityEngine;
using VRC.SDKBase;
using VRC.SDK3.ImageLoading;
using VRC.Udon.Common.Interfaces;

[UdonBehaviourSyncMode(BehaviourSyncMode.NoVariableSync)]
public class StaggeredImageLoader : UdonSharpBehaviour
{
    [Header("Image URL")]
    [SerializeField] private VRCUrl imageUrl;

    [Header("Target material")]
    [SerializeField] private Material targetMaterial;

    [Header("Stagger settings")]
    [Tooltip("Set to 0 for the first loader, 1 for the second, 2 for the third, etc.")]
    [SerializeField] private int _delayOrder = 0;

    [Tooltip("Seconds between each loader's first download (must be >= 5.0)")]
    [SerializeField] private float _baseDelaySeconds = 5.5f;

    [Tooltip("How often to refresh the image (seconds)")]
    [SerializeField] private float _refreshInterval = 60.0f;

    private VRCImageDownloader _downloader;
    private IVRCImageDownload _currentDownload;
    private Texture2D _activeTexture;

    void Start()
    {
        _downloader = new VRCImageDownloader();

        // Stagger initial download by order × base delay
        float initialDelay = _delayOrder * _baseDelaySeconds;
        SendCustomEventDelayedSeconds(nameof(BeginDownload), initialDelay);
    }

    public void BeginDownload()
    {
        if (_currentDownload != null)
        {
            _currentDownload.Dispose();
            _currentDownload = null;
        }

        TextureInfo info = new TextureInfo();
        info.GenerateMipmaps = true;
        info.FilterMode = FilterMode.Trilinear;

        _currentDownload = _downloader.DownloadImage(
            imageUrl,
            null,
            (IUdonEventReceiver)this,
            info
        );
    }

    public override void OnImageLoadSuccess(IVRCImageDownload result)
    {
        // Swap textures and free old VRAM
        Texture2D previousTexture = _activeTexture;
        _activeTexture = result.Result;

        if (targetMaterial != null)
        {
            targetMaterial.mainTexture = _activeTexture;
        }

        if (previousTexture != null)
        {
            Destroy(previousTexture);
        }

        // Schedule next refresh — staggered so each instance refreshes at its own offset
        SendCustomEventDelayedSeconds(nameof(BeginDownload), _refreshInterval);
    }

    public override void OnImageLoadError(IVRCImageDownload result)
    {
        Debug.LogError($"[StaggeredLoader #{_delayOrder}] Error {result.ErrorCode}: {result.Error}");
        // Retry after a full base delay to avoid colliding with other instances
        SendCustomEventDelayedSeconds(nameof(BeginDownload), _baseDelaySeconds);
    }

    void OnDestroy()
    {
        if (_downloader != null) _downloader.Dispose();
        if (_activeTexture != null) Destroy(_activeTexture);
    }
}
```

### Inspector Setup for Three Loaders

| Instance | `_delayOrder` | First download at |
|----------|:-------------:|:-----------------:|
| Loader A | 0 | 0.0 s |
| Loader B | 1 | 5.5 s |
| Loader C | 2 | 11.0 s |

> Choose `_baseDelaySeconds` of at least **5.5 s** (the 5 s rate limit plus 0.5 s margin).
> Reduce the margin to 0.1 s only if you have verified the rate limit in your specific SDK version.

---

## Anti-Patterns

| Anti-Pattern | Problem | Correct Approach |
|---|---|---|
| `new VRCImageDownloader()` every download | Each new downloader is never disposed; creates a permanent leak of VRC internal state and any completed textures it still holds | Create one downloader in `Start()` and reuse it for all downloads |
| Overwriting `_currentDownload` without `Dispose()` | The old `IVRCImageDownload` wrapper leaks; its internal state is never freed | Call `_currentDownload.Dispose()` before overwriting the reference |
| Relying on `Dispose()` to free a texture applied to a material | `Dispose()` only frees VRC wrapper objects; the `Texture2D` GPU allocation survives | After assigning a texture to a material, track it separately and call `Destroy(texture)` when done |
| Destroying a texture while it is still visible during a fade | Causes a black flash or missing-texture visual artifact | Store a reference to the old texture, delay `Destroy()` until after the fade completes using `SendCustomEventDelayedSeconds` |
| Not handling `OnImageLoadError` | Failures are silent; `_currentDownload` may be in an undefined state; the refresh cycle stops permanently | Always implement `OnImageLoadError`, log the error, and schedule a retry |
| Polling download status in `Update()` | `IVRCImageDownload` does not expose a reliable completion flag for polling; this is fragile and wastes CPU every frame | Use the `OnImageLoadSuccess` / `OnImageLoadError` callbacks that VRChat provides |
| Starting all loaders at the same time in a multi-loader world | All instances compete for the shared 5 s rate limit slot; downloads queue unpredictably and initial load time balloons | Assign each instance a `delayOrder` and stagger their start times by `delayOrder × 5.5f` seconds |
| Using mipmaps without enabling `GenerateMipmaps = true` | Applying mipmap bias or `FilterMode.Trilinear` to a non-mipmapped texture has no effect; the image appears the same regardless of distance or bias settings | Set `TextureInfo.GenerateMipmaps = true` whenever you intend to use mipmaps |

---

## Troubleshooting

| Symptom | Likely Cause | Solution |
|---------|-------------|---------|
| VRAM grows without bound over time | Old textures are not being destroyed after each image swap | Track the previous texture reference; call `Destroy(oldTexture)` in `OnImageLoadSuccess` before storing the new one |
| Black flash or missing texture during crossfade | Texture destroyed while still visible (before fade completes) | Delay `Destroy()` using `SendCustomEventDelayedSeconds` until after `fadeDuration` has elapsed |
| Textures appear blurry even at close range | Mipmaps not generated, or positive mipmap bias applied at short distance | Set `TextureInfo.GenerateMipmaps = true`; review your bias curve — ensure bias is near 0 at close range |
| Texture is sharp far away but crashes GPU memory on Quest | Negative mipmap bias forcing high-resolution mip at distance | Clamp minimum bias to 0 or higher on Quest; disable the bias controller on mobile platforms |
| World crashes after many image cycles | VRAM exhausted from accumulated undestroyed textures | Audit every `OnImageLoadSuccess` callback; verify `Destroy(oldTexture)` is called before the new texture is stored |
| Images in a multi-loader world load very slowly | All loaders downloading simultaneously, saturating the shared rate limit | Assign staggered `delayOrder` values to each loader |
| `Dispose()` call does not seem to free memory | `Dispose()` frees VRC wrappers, not GPU texture memory | Call `Destroy(texture)` explicitly on textures you own; `Dispose()` is not a substitute |
| Download cycle stops after an error | `OnImageLoadError` not implemented; no retry scheduled | Implement `OnImageLoadError` and call `SendCustomEventDelayedSeconds(nameof(BeginDownload), retryDelay)` |
| Texture pop-in visible when switching display images | New texture not fully applied before fade begins | Apply texture to back renderer first, then start the fade in the same callback frame |
| Material instance shared between objects causes unexpected texture changes | Using `renderer.sharedMaterial` instead of `renderer.material` | Use `renderer.material` to get an instanced material; always apply textures to the instance |

---

## See Also

- [web-loading.md](web-loading.md) — `VRCImageDownloader` API overview, rate limits, trusted URL list, and basic pattern
- [api.md](api.md) — Quick reference for `VRCUrl`, `TextureInfo`, `IVRCImageDownload` properties
- [troubleshooting.md](troubleshooting.md) — Web loading error table and HTTP error code reference
- [patterns-performance.md](patterns-performance.md) — Update Handler Pattern (disable per-frame polling when not needed)
- [web-loading-advanced.md](web-loading-advanced.md) - Advanced data loading via StringDownloader with Base64 textures
