# Web Loading — Advanced Packed Resource Patterns

**Supported SDK Versions**: 3.7.1 - 3.10.2 (as of March 2026)

Advanced techniques for embedding multiple textures in a single `VRCStringDownloader` response
to work around `VRCImageDownloader` limitations. For the base API reference see
[web-loading.md](web-loading.md). For VRAM lifecycle management see [image-loading-vram.md](image-loading-vram.md).

---

## Overview / Motivation

### Why Not Just Use VRCImageDownloader?

`VRCImageDownloader` is the simplest path for texture loading, but it carries constraints that
become bottlenecks in resource-heavy worlds:

| Constraint | Value | Impact |
|---|---|---|
| Rate limit | 1 image per 5 seconds, **shared across the entire scene** | 10 images = 50+ seconds to load |
| Resolution cap | 2048 × 2048 maximum | Server must pre-resize, or download is rejected |
| Trusted domain list | Separate, shorter list from string loading | Limits hosting options |
| Images per request | 1 | No way to batch a thumbnail strip into one download |
| Format | PNG / JPG / GIF only | Cannot use GPU-compressed formats (DXT, ETC2) directly |

`VRCStringDownloader` has its own 5-second rate limit, but it operates on a **separate
queue** from image loading. This opens an alternative path: encode texture data as Base64
inside a string payload and decode it manually in UdonSharp. One string download can carry
an entire pack of thumbnails, icons, or UI sprites.

### Trade-offs

| Concern | VRCImageDownloader | Packed String Approach |
|---|---|---|
| Download count for 8 textures | 8 requests × 5 s = 40+ s | 1 request (if all fit in one file) |
| CPU cost | None (GPU decode) | Moderate (Base64 decode + `LoadRawTextureData`) |
| File size | Compressed PNG/JPG | Base64 inflates raw data by ~33% |
| Complexity | Low | High |
| Platform format handling | Automatic | Manual (must serve DXT vs ETC2 per platform) |

Use this pattern when: you need many small textures quickly, you are on trusted-string domains
but not trusted-image domains, or you need GPU-compressed formats for Quest memory savings.

---

## Custom Binary-Mixed Text Format

### Design Goals

A single downloaded string must carry:
1. A version tag so future format changes do not break existing worlds
2. Metadata (dimensions, format, block positions) that can be parsed without reading the whole string
3. One or more Base64-encoded texture data blocks, each independently decodable

### Format Layout

```text
[VERSION_HEADER]\n[JSON_LENGTH_DECIMAL]\n[JSON_METADATA_BLOCK][BASE64_BLOCK_0][BASE64_BLOCK_1]...
```

| Field | Content | Example |
|---|---|---|
| `VERSION_HEADER` | ASCII version tag, terminated by `\n` | `PACK1\n` |
| `JSON_LENGTH_DECIMAL` | Decimal character count of the JSON block, terminated by `\n` | `312\n` |
| `JSON_METADATA_BLOCK` | Plain JSON — no terminator, length given above | `{"entries":[...]}` |
| `BASE64_BLOCK_N` | Raw Base64 string — no newlines, length in JSON | `AAAA...` |

### JSON Metadata Schema

```json
{
  "version": 1,
  "entries": [
    {
      "id": "thumb_0",
      "width": 128,
      "height": 128,
      "hasMipmaps": false,
      "dataStart": 0,
      "dataLength": 65536
    },
    {
      "id": "thumb_1",
      "width": 128,
      "height": 128,
      "hasMipmaps": false,
      "dataStart": 65536,
      "dataLength": 65536
    }
  ]
}
```

`dataStart` and `dataLength` are byte offsets **within the concatenated Base64 region**
(the portion of the string after the JSON block). The parser computes the absolute string
index as: `jsonBlockStart + jsonLength + dataStart`.

### Parsing the Format

```csharp
using UdonSharp;
using UnityEngine;
using VRC.SDKBase;
using VRC.SDK3.StringLoading;
using VRC.SDK3.Data;
using VRC.Udon.Common.Interfaces;

[UdonBehaviourSyncMode(BehaviourSyncMode.NoVariableSync)]
public class PackFormatParser : UdonSharpBehaviour
{
    private const string SupportedVersion = "PACK1";

    // Parsed header state — set by FindJsonStart, read by callers
    private int _parsedJsonStart  = -1;
    private int _parsedJsonLength = -1;

    /**
     * Parses the version header and JSON length prefix.
     * Returns the JSON start index on success, or -1 on parse failure.
     * Also stores the JSON length in _parsedJsonLength for use by the caller.
     * UdonSharp blocks out parameters in user-defined methods; use fields instead.
     */
    private int FindJsonStart(string raw)
    {
        _parsedJsonStart  = -1;
        _parsedJsonLength = -1;

        // Line 1: version
        int firstNewline = raw.IndexOf('\n');
        if (firstNewline < 0) return -1;

        string version = raw.Substring(0, firstNewline);
        if (version != SupportedVersion) return -1;

        // Line 2: JSON length as decimal string
        int secondNewline = raw.IndexOf('\n', firstNewline + 1);
        if (secondNewline < 0) return -1;

        string lengthStr = raw.Substring(firstNewline + 1, secondNewline - firstNewline - 1);
        if (!int.TryParse(lengthStr, out int parsedLength) || parsedLength <= 0) return -1;

        _parsedJsonStart  = secondNewline + 1;
        _parsedJsonLength = parsedLength;
        return _parsedJsonStart;
    }

    /** Extract the Base64 sub-string for one entry using pre-parsed offsets */
    private string ExtractBase64Block(string raw, int jsonStart, int jsonLength, int dataStart, int dataLength)
    {
        int blockRegionStart = jsonStart + jsonLength;
        int absoluteStart    = blockRegionStart + dataStart;
        return raw.Substring(absoluteStart, dataLength);
    }
}
```

The key insight is that `Substring()` is called **with pre-computed absolute indices** from
the JSON metadata — the parser never re-scans the string character by character.

---

## Base64 Texture Embedding

### Encoding Pipeline (Server Side)

The server compresses raw pixel data into GPU-ready format, Base64-encodes each texture
block, serialises the metadata JSON, then assembles the pack string and serves it over HTTPS.

### Decoding in UdonSharp

`System.Convert` is available in UdonSharp (verified in SDK 3.7.1+; not explicitly listed in the official allowlist but confirmed working in production worlds). Raw GPU texture data is loaded with `LoadRawTextureData`, which bypasses PNG/JPG decompression and writes the bytes directly into GPU memory.

```csharp
using UdonSharp;
using UnityEngine;
using System;
using VRC.SDKBase;

[UdonBehaviourSyncMode(BehaviourSyncMode.NoVariableSync)]
public class Base64TextureDecoder : UdonSharpBehaviour
{
    /**
     * Decodes a Base64 string into a Texture2D using raw GPU data.
     * format must match the compression used when the data was prepared on the server.
     * Caller is responsible for calling Destroy() on the returned texture when done.
     */
    public Texture2D DecodeTexture(string base64Data, int width, int height,
                                   TextureFormat format, bool hasMipmaps)
    {
        if (string.IsNullOrEmpty(base64Data)) return null;

        byte[] rawBytes = Convert.FromBase64String(base64Data);
        if (rawBytes == null || rawBytes.Length == 0) return null;

        Texture2D tex = new Texture2D(width, height, format, hasMipmaps);
        tex.LoadRawTextureData(rawBytes);
        tex.Apply();
        return tex;
    }

    /**
     * Creates a Sprite from a decoded Texture2D for use with UnityEngine.UI.Image.
     * pixelsPerUnit controls how the sprite scales in UI layouts.
     */
    public Sprite TextureToSprite(Texture2D tex, float pixelsPerUnit = 100f)
    {
        if (tex == null) return null;
        Rect rect = new Rect(0f, 0f, tex.width, tex.height);
        Vector2 pivot = new Vector2(0.5f, 0.5f);
        return Sprite.Create(tex, rect, pivot, pixelsPerUnit);
    }
}
```

### `LoadRawTextureData` vs `LoadImage`

| Method | Input | GPU format | Decode cost |
|---|---|---|---|
| `LoadRawTextureData(byte[])` | Pre-compressed GPU bytes (DXT, ETC2, uncompressed) | Whatever you specify in `TextureFormat` | None — bytes go straight to GPU |
| `LoadImage(byte[])` | PNG or JPG file bytes | Always `RGBA32` or `RGB24` | CPU decode from PNG/JPG, then re-upload |

Use `LoadRawTextureData` when you have GPU-compressed data from the server.
Use `LoadImage` only as a fallback when serving PNG/JPG via string download.

### VRAM Ownership

A texture created with `new Texture2D(...)` and `LoadRawTextureData` is owned by your
code — not by any downloader. You must call `Destroy(texture)` when done.
See [image-loading-vram.md](image-loading-vram.md) for the full lifecycle and the
Dispose/Destroy distinction.

---

## Cross-Platform Texture Compression

### Why Compression Format Matters

`LoadRawTextureData` requires the bytes to be in a format the GPU natively supports.
PC (DirectX) and Android/Quest (OpenGL ES / Vulkan) support different compressed formats:

| Platform | Opaque format | With-alpha format | Notes |
|---|---|---|---|
| PC (Windows / Mac) | `TextureFormat.DXT1` | `TextureFormat.DXT5` | DXT1 = BC1, DXT5 = BC3 |
| Android / Quest | `TextureFormat.ETC2_RGB` | `TextureFormat.ETC2_RGBA8` | ETC2 is standard on GLES 3.0+ |

> **Important:** Use the non-Crunched formats (`DXT1`, `DXT5`, `ETC2_RGB`, `ETC2_RGBA8`) with `LoadRawTextureData`. Crunched variants (`DXT1Crunched`, `ETC_RGB4Crunched`, etc.) require Unity's additional decompression step and cannot be loaded via raw byte upload.

Loading DXT data on Quest or ETC2 data on PC will produce garbled visuals or a Unity error.

### Compile-Time Platform Selection

Use the `#if UNITY_ANDROID` preprocessor directive to choose the correct format and URL
at build time. The world is compiled separately for PC and Android, so the correct branch
is baked in.

```csharp
using UdonSharp;
using UnityEngine;
using VRC.SDKBase;

[UdonBehaviourSyncMode(BehaviourSyncMode.NoVariableSync)]
public class PlatformFormatSelector : UdonSharpBehaviour
{
    // Inspector fields: assign both sets; only the platform-appropriate one is used
    [Header("PC pack URLs")]
    [SerializeField] private VRCUrl[] _packUrlsPC;

    [Header("Android/Quest pack URLs")]
    [SerializeField] private VRCUrl[] _packUrlsAndroid;

    /** Returns the URL array for the current build platform */
    public VRCUrl[] GetPlatformUrls()
    {
#if UNITY_ANDROID
        return _packUrlsAndroid;
#else
        return _packUrlsPC;
#endif
    }

    /** Returns the opaque texture format for the current build platform */
    public TextureFormat GetOpaqueFormat()
    {
#if UNITY_ANDROID
        return TextureFormat.ETC2_RGB;
#else
        return TextureFormat.DXT1;
#endif
    }

    /** Returns the alpha-capable texture format for the current build platform */
    public TextureFormat GetAlphaFormat()
    {
#if UNITY_ANDROID
        return TextureFormat.ETC2_RGBA8;
#else
        return TextureFormat.DXT5;
#endif
    }
}
```

### Server-Side Requirements

The server must maintain separate pack files per platform:

```text
data_pc.bin       — DXT1/DXT5-compressed texture data
data_android.bin  — ETC2-compressed texture data
```

Both files share the same format header and JSON metadata schema; only the `BASE64_BLOCK`
bytes differ. The `TextureFormat` field in each entry's JSON should indicate the stored
format so the decoder does not need to infer it from the URL.

---

## URL Index Double-Key Pattern

### The Problem

A world may need hundreds of small resources (thumbnails, icons, UI sprites). Packing them
all into a single URL file would make that file enormous. But downloading every file upfront
wastes bandwidth and time. The solution is to **spread resources across multiple URL files**
and only download the file that contains the resource currently needed.

### Double-Key Addressing

Each resource is identified by two integers:
- `urlIndex` — which pack file to download (index into the `VRCUrl[]` array)
- `innerIndex` — position of the resource within that pack file

The JSON metadata maps resource IDs to these pairs:

```json
{
  "resources": {
    "avatar_0": { "urlIndex": 0, "innerIndex": 0 },
    "avatar_1": { "urlIndex": 0, "innerIndex": 1 },
    "avatar_2": { "urlIndex": 1, "innerIndex": 0 },
    "avatar_3": { "urlIndex": 1, "innerIndex": 1 }
  }
}
```

### UdonSharp Lookup (Parallel Arrays)

UdonSharp has no Dictionary. Use parallel arrays to simulate a map from resource ID strings
to `(urlIndex, innerIndex)` pairs. Populate these arrays from JSON at startup.

```csharp
using UdonSharp;
using UnityEngine;
using VRC.SDKBase;
using VRC.SDK3.Data;

[UdonBehaviourSyncMode(BehaviourSyncMode.NoVariableSync)]
public class ResourceIndex : UdonSharpBehaviour
{
    /** Parallel arrays: _resourceIds[i] maps to (_urlIndices[i], _innerIndices[i]) */
    private string[] _resourceIds  = new string[0];
    private int[]    _urlIndices   = new int[0];
    private int[]    _innerIndices = new int[0];
    private int      _count        = 0;

    /** Populate the index from a parsed DataDictionary (the "resources" object) */
    public void BuildIndex(DataDictionary resourcesDict)
    {
        _count = resourcesDict.Count;
        _resourceIds  = new string[_count];
        _urlIndices   = new int[_count];
        _innerIndices = new int[_count];

        DataList keys = resourcesDict.GetKeys();
        for (int i = 0; i < _count; i++)
        {
            string id = keys[i].String;
            DataDictionary entry = resourcesDict[id].DataDictionary;
            _resourceIds[i]  = id;
            _urlIndices[i]   = (int)entry["urlIndex"].Double;
            _innerIndices[i] = (int)entry["innerIndex"].Double;
        }
    }

    // Result fields written by GetUrlIndex / GetInnerIndex — read immediately after the call
    // UdonSharp blocks out parameters in user-defined methods; use fields instead.
    [HideInInspector] public int LastUrlIndex   = -1;
    [HideInInspector] public int LastInnerIndex = -1;

    /**
     * Searches for resourceId and returns true if found.
     * On success, LastUrlIndex and LastInnerIndex are set to the resolved address.
     * On failure, both fields are set to -1.
     */
    public bool TryGetAddress(string resourceId)
    {
        for (int i = 0; i < _count; i++)
        {
            if (_resourceIds[i] == resourceId)
            {
                LastUrlIndex   = _urlIndices[i];
                LastInnerIndex = _innerIndices[i];
                return true;
            }
        }
        LastUrlIndex   = -1;
        LastInnerIndex = -1;
        return false;
    }
}
```

When a resource is requested, check `TryGetAddress` to find `urlIndex`, then check the
LRU cache (next section) for that `urlIndex`. If the pack is not cached, download it;
otherwise, decode `innerIndex` from the cached data immediately.

---

## LRU-Style Decode Cache

### Why Cache Decoded Packs

Downloading and Base64-decoding a pack file is expensive. If the player navigates through
resource pages that share pack files, you want the second visit to return instantly without
a network round-trip.

### Fixed-Capacity Buffer with FIFO Eviction

UdonSharp has no Dictionary. A fixed-size parallel-array buffer tracks which pack files
have been decoded. When the buffer is full, the **oldest entry** (index 0) is evicted —
all remaining entries shift down by one slot. This is a simple queue-based LRU approximation
suitable for small capacities (2–5 entries).

```csharp
using UdonSharp;
using UnityEngine;
using VRC.SDKBase;

[UdonBehaviourSyncMode(BehaviourSyncMode.NoVariableSync)]
public class PackedResourceCache : UdonSharpBehaviour
{
    private const int CacheCapacity = 3;

    /**
     * Parallel arrays for the cache.
     * _cacheKeys[i]   = urlIndex of the cached pack (-1 = empty slot)
     * _cacheData[i]   = decoded string[] of Base64 blocks for that pack
     */
    private int[]      _cacheKeys     = new int[CacheCapacity];
    private string[][] _cacheData     = new string[CacheCapacity][];
    private int        _cacheCount    = 0;

    void Start()
    {
        for (int i = 0; i < CacheCapacity; i++)
        {
            _cacheKeys[i] = -1;
        }
    }

    /** Returns true if the pack for urlIndex is already cached */
    public bool Contains(int urlIndex)
    {
        for (int i = 0; i < _cacheCount; i++)
        {
            if (_cacheKeys[i] == urlIndex) return true;
        }
        return false;
    }

    /**
     * Returns the decoded Base64 block array for the given urlIndex.
     * Returns null if not in cache.
     */
    public string[] Get(int urlIndex)
    {
        for (int i = 0; i < _cacheCount; i++)
        {
            if (_cacheKeys[i] == urlIndex) return _cacheData[i];
        }
        return null;
    }

    /**
     * Adds a decoded pack to the cache.
     * If at capacity, evicts the oldest entry (index 0) first.
     */
    public void Add(int urlIndex, string[] decodedBlocks)
    {
        if (_cacheCount >= CacheCapacity)
        {
            EvictOldest();
        }

        _cacheKeys[_cacheCount]  = urlIndex;
        _cacheData[_cacheCount]  = decodedBlocks;
        _cacheCount++;
    }

    /** Shifts all entries down by one, dropping index 0 */
    private void EvictOldest()
    {
        for (int i = 0; i < CacheCapacity - 1; i++)
        {
            _cacheKeys[i] = _cacheKeys[i + 1];
            _cacheData[i] = _cacheData[i + 1];
        }
        _cacheKeys[CacheCapacity - 1] = -1;
        _cacheData[CacheCapacity - 1] = null;
        _cacheCount                   = CacheCapacity - 1;
    }
}
```

**Note**: The cache stores Base64 strings, not decoded `Texture2D` objects. Decoded textures
are created on demand and must be managed by the caller using `Destroy()`.
Caching raw `Texture2D` objects would consume VRAM indefinitely; caching Base64 strings
only uses CPU-side managed memory, which the GC can reclaim.

---

## Complete Example

The following `PackedResourceLoader` ties together all patterns: format parsing, platform
format selection, Base64 decoding, double-key addressing, and LRU caching.

```csharp
using UdonSharp;
using UnityEngine;
using UnityEngine.UI;
using System;
using VRC.SDKBase;
using VRC.SDK3.StringLoading;
using VRC.SDK3.Data;
using VRC.Udon.Common.Interfaces;

[UdonBehaviourSyncMode(BehaviourSyncMode.NoVariableSync)]
public class PackedResourceLoader : UdonSharpBehaviour
{
    // ── Inspector ────────────────────────────────────────────────────────────

    [Header("Pack file URLs — PC build")]
    [SerializeField] private VRCUrl[] _packUrlsPC;

    [Header("Pack file URLs — Android/Quest build")]
    [SerializeField] private VRCUrl[] _packUrlsAndroid;

    [Header("Index file URL (JSON resource map)")]
    [SerializeField] private VRCUrl _indexUrl;

    [Header("UI slots to fill (one Image per slot)")]
    [SerializeField] private Image[] _uiSlots;

    [Header("Resource IDs to load into the UI slots")]
    [SerializeField] private string[] _slotResourceIds;

    // ── Private state ────────────────────────────────────────────────────────

    private const string PackVersion    = "PACK1";
    private const int    CacheCapacity  = 3;

    // Platform-selected URL array (set in Start)
    private VRCUrl[] _packUrls;

    // Resource index (populated after index file download)
    private string[] _resIds     = new string[0];
    private int[]    _resUrlIdx  = new int[0];
    private int[]    _resInnerIdx = new int[0];
    private int      _resCount   = 0;

    // LRU cache: parallel arrays (urlIndex -> decoded Base64 string blocks)
    private int[]      _cacheKeys  = new int[CacheCapacity];
    private string[][] _cacheData  = new string[CacheCapacity][];
    private int        _cacheCount = 0;

    // Download state
    private bool _indexReady        = false;
    private int  _pendingUrlIndex   = -1;   // which pack we are currently downloading
    // Note: _pendingSlotIndex tracks only ONE pending slot. This simplified example assumes
    // at most one in-flight download at a time. A production implementation should use an
    // array to track all pending slots that share the same urlIndex, since multiple UI slots
    // may reference resources from the same pack file.
    private int  _pendingSlotIndex  = -1;   // which UI slot triggered the download

    // Tracks which UI slots have a runtime-loaded sprite (vs. an Inspector-assigned sprite).
    // Only destroy the old texture when _hasRuntimeSprite[slot] is true, to avoid
    // destroying Inspector-assigned or shared textures that this script did not create.
    private bool[] _hasRuntimeSprite = new bool[0];

    // ── Lifecycle ────────────────────────────────────────────────────────────

    void Start()
    {
#if UNITY_ANDROID
        _packUrls = _packUrlsAndroid;
#else
        _packUrls = _packUrlsPC;
#endif

        for (int i = 0; i < CacheCapacity; i++)
        {
            _cacheKeys[i] = -1;
        }

        _hasRuntimeSprite = new bool[_uiSlots.Length];

        // Download resource index first
        VRCStringDownloader.LoadUrl(_indexUrl, (IUdonEventReceiver)this);
    }

    // ── Download callbacks ───────────────────────────────────────────────────

    public override void OnStringLoadSuccess(IVRCStringDownload result)
    {
        if (!_indexReady)
        {
            // First download is always the index file
            ParseIndexFile(result.Result);
            _indexReady = true;
            // Begin loading all UI slots
            SendCustomEvent(nameof(LoadNextSlot));
            return;
        }

        // Subsequent downloads are pack files
        if (_pendingUrlIndex < 0) return;
        ParseAndCachePack(result.Result, _pendingUrlIndex);

        // Apply the texture for the slot that triggered this download
        if (_pendingSlotIndex >= 0)
        {
            ApplySlotTexture(_pendingSlotIndex);
        }

        _pendingUrlIndex  = -1;
        _pendingSlotIndex = -1;
    }

    public override void OnStringLoadError(IVRCStringDownload result)
    {
        Debug.LogError($"[PackedResourceLoader] Download error {result.ErrorCode}: {result.Error}");
        _pendingUrlIndex  = -1;
        _pendingSlotIndex = -1;
    }

    // ── Index parsing ────────────────────────────────────────────────────────

    private void ParseIndexFile(string json)
    {
        if (!VRCJson.TryDeserializeFromJson(json, out DataToken root)) return;

        DataDictionary rootDict = root.DataDictionary;
        if (!rootDict.TryGetValue("resources", out DataToken resToken)) return;

        DataDictionary resDict = resToken.DataDictionary;
        DataList keys = resDict.GetKeys();
        int count = keys.Count;

        _resIds      = new string[count];
        _resUrlIdx   = new int[count];
        _resInnerIdx = new int[count];
        _resCount    = count;

        for (int i = 0; i < count; i++)
        {
            string id = keys[i].String;
            DataDictionary entry = resDict[id].DataDictionary;
            _resIds[i]      = id;
            _resUrlIdx[i]   = (int)entry["urlIndex"].Double;
            _resInnerIdx[i] = (int)entry["innerIndex"].Double;
        }
    }

    // ── Slot loading ─────────────────────────────────────────────────────────

    private int _slotLoadCursor = 0;

    public void LoadNextSlot()
    {
        if (_slotLoadCursor >= _uiSlots.Length) return;
        int slotIdx = _slotLoadCursor;
        _slotLoadCursor++;

        if (slotIdx >= _slotResourceIds.Length) return;
        string resId = _slotResourceIds[slotIdx];

        // Resolve address
        int urlIdx = -1, innerIdx = -1;
        for (int i = 0; i < _resCount; i++)
        {
            if (_resIds[i] == resId)
            {
                urlIdx   = _resUrlIdx[i];
                innerIdx = _resInnerIdx[i];
                break;
            }
        }
        if (urlIdx < 0) return;

        // Cache hit: apply immediately, then continue to next slot without rate-limit delay
        for (int i = 0; i < _cacheCount; i++)
        {
            if (_cacheKeys[i] == urlIdx)
            {
                ApplyTextureFromCache(slotIdx, _cacheData[i], innerIdx);
                SendCustomEvent(nameof(LoadNextSlot));
                return;
            }
        }

        // Cache miss: download pack
        if (urlIdx >= _packUrls.Length) return;
        _pendingUrlIndex  = urlIdx;
        _pendingSlotIndex = slotIdx;
        VRCStringDownloader.LoadUrl(_packUrls[urlIdx], (IUdonEventReceiver)this);
        // Rate limit: next slot after 5.5 s
        SendCustomEventDelayedSeconds(nameof(LoadNextSlot), 5.5f);
    }

    // ── Pack parsing ─────────────────────────────────────────────────────────

    private void ParseAndCachePack(string raw, int urlIdx)
    {
        // Validate version header
        int firstNl = raw.IndexOf('\n');
        if (firstNl < 0) return;
        if (raw.Substring(0, firstNl) != PackVersion) return;

        // Read JSON length
        int secondNl = raw.IndexOf('\n', firstNl + 1);
        if (secondNl < 0) return;
        string lenStr = raw.Substring(firstNl + 1, secondNl - firstNl - 1);
        if (!int.TryParse(lenStr, out int jsonLen) || jsonLen <= 0) return;

        int jsonStart = secondNl + 1;
        if (jsonStart + jsonLen > raw.Length) return;
        string jsonText = raw.Substring(jsonStart, jsonLen);

        if (!VRCJson.TryDeserializeFromJson(jsonText, out DataToken metaToken)) return;
        DataDictionary meta = metaToken.DataDictionary;

        if (!meta.TryGetValue("entries", out DataToken entriesToken)) return;
        DataList entries = entriesToken.DataList;
        int entryCount   = entries.Count;

        string[] blocks = new string[entryCount];
        int blockRegionStart = jsonStart + jsonLen;

        for (int i = 0; i < entryCount; i++)
        {
            DataDictionary entry = entries[i].DataDictionary;
            int dataStart  = (int)entry["dataStart"].Double;
            int dataLength = (int)entry["dataLength"].Double;
            if (dataStart < 0 || blockRegionStart + dataStart + dataLength > raw.Length) return;
            blocks[i] = raw.Substring(blockRegionStart + dataStart, dataLength);
        }

        // Store into LRU cache
        if (_cacheCount >= CacheCapacity)
        {
            // Evict oldest
            for (int i = 0; i < CacheCapacity - 1; i++)
            {
                _cacheKeys[i] = _cacheKeys[i + 1];
                _cacheData[i] = _cacheData[i + 1];
            }
            _cacheKeys[CacheCapacity - 1] = -1;
            _cacheData[CacheCapacity - 1] = null;
            _cacheCount                   = CacheCapacity - 1;
        }

        _cacheKeys[_cacheCount] = urlIdx;
        _cacheData[_cacheCount] = blocks;
        _cacheCount++;
    }

    // ── Texture application ───────────────────────────────────────────────────

    private void ApplySlotTexture(int slotIdx)
    {
        string resId = _slotResourceIds[slotIdx];
        int urlIdx = -1, innerIdx = -1;
        for (int i = 0; i < _resCount; i++)
        {
            if (_resIds[i] == resId)
            {
                urlIdx   = _resUrlIdx[i];
                innerIdx = _resInnerIdx[i];
                break;
            }
        }
        if (urlIdx < 0) return;

        for (int i = 0; i < _cacheCount; i++)
        {
            if (_cacheKeys[i] == urlIdx)
            {
                ApplyTextureFromCache(slotIdx, _cacheData[i], innerIdx);
                return;
            }
        }
    }

    private void ApplyTextureFromCache(int slotIdx, string[] blocks, int innerIdx)
    {
        if (innerIdx < 0 || innerIdx >= blocks.Length) return;
        if (_uiSlots[slotIdx] == null) return;

        // Validate Base64 string before decoding.
        // UdonSharp does not support try/catch, so FormatException from Convert.FromBase64String
        // cannot be caught. A minimal guard: valid Base64 length must be a multiple of 4.
        string base64String = blocks[innerIdx];
        if (base64String.Length == 0 || base64String.Length % 4 != 0) return;

        // Decode Base64 to raw bytes
        byte[] rawBytes = Convert.FromBase64String(base64String);
        if (rawBytes == null || rawBytes.Length == 0) return;

        // Select platform-appropriate raw GPU format for LoadRawTextureData
#if UNITY_ANDROID
        TextureFormat fmt = TextureFormat.ETC2_RGB;
#else
        TextureFormat fmt = TextureFormat.DXT1;
#endif

        // Decode at fixed 128×128 for this example (real code reads width/height from JSON)
        Texture2D tex = new Texture2D(128, 128, fmt, false);
        tex.LoadRawTextureData(rawBytes);
        tex.Apply();

        // Destroy old texture only if it was created at runtime by this script.
        // Destroying Inspector-assigned or shared textures would break other references.
        if (_hasRuntimeSprite.Length > slotIdx && _hasRuntimeSprite[slotIdx])
        {
            Sprite oldSprite = _uiSlots[slotIdx].sprite;
            if (oldSprite != null)
            {
                Destroy(oldSprite.texture);
            }
        }

        _uiSlots[slotIdx].sprite = Sprite.Create(
            tex,
            new Rect(0f, 0f, tex.width, tex.height),
            new Vector2(0.5f, 0.5f),
            100f
        );

        // Mark this slot as owning a runtime sprite so future updates can safely destroy it.
        if (_hasRuntimeSprite.Length > slotIdx)
        {
            _hasRuntimeSprite[slotIdx] = true;
        }
    }
}
```

---

## Anti-Patterns

| Anti-Pattern | Problem | Correct Approach |
|---|---|---|
| Not caching decoded packs | Each request re-downloads and re-decodes the same file; 5-second rate-limit delay on every access | Store decoded Base64 blocks in an LRU buffer keyed by `urlIndex` |
| Using `TextureFormat.DXT1` on Quest / Android | DXT is a DirectX format; GLES/Vulkan hardware cannot decode it — result is garbled pixels or a Unity error | Use `#if UNITY_ANDROID` to select `ETC2_RGB` / `ETC2_RGBA8` |
| Forgetting `Destroy()` on decoded textures | Every `new Texture2D` + `LoadRawTextureData` allocates VRAM; without `Destroy()` this accumulates until the world crashes | Before replacing a texture slot, call `Destroy(oldTexture)` (see [image-loading-vram.md](image-loading-vram.md)) |
| Scanning the full string with repeated `Substring()` calls | `O(n²)` string allocation; on a 200 KB pack string with 32 entries this creates hundreds of MB of garbage | Compute `dataStart` + `dataLength` from JSON metadata and call `Substring` once per block with pre-computed absolute indices |
| Hardcoding texture dimensions in the decoder | Breaks silently when the server changes texture sizes; width/height mismatch produces corrupted images | Store `width` and `height` per entry in the JSON metadata; read them at decode time |
| Not handling `OnStringLoadError` | A failed download leaves `_pendingUrlIndex` set; the next download response is misattributed to the wrong pack slot | Always implement `OnStringLoadError`; reset `_pendingUrlIndex` and `_pendingSlotIndex` to `-1` |
| Downloading all pack files at startup regardless of which resources are needed | Wastes bandwidth and saturates the rate-limit queue; especially costly on Quest with slow mobile connections | Use double-key addressing — download a pack file only when a resource from that `urlIndex` is actually requested |

---

## Troubleshooting

| Symptom | Likely Cause | Solution |
|---|---|---|
| `Convert.FromBase64String` throws at runtime | `System.Convert` unavailable in older SDK | Requires SDK 3.7.1+; check SDK version in `ProjectSettings` |
| Decoded texture is entirely black or garbled | Texture format mismatch (DXT on Quest, or ETC2 on PC) | Verify `#if UNITY_ANDROID` selects the correct `TextureFormat`; confirm server served the right platform file |
| `LoadRawTextureData` produces corrupt image | Wrong byte count — `dataLength` in JSON does not match actual encoded data | Re-validate the server pack builder; log `rawBytes.Length` vs the expected `width * height * bpp` |
| VRAM grows after repeated resource loads | `Destroy()` not called on old textures before creating new ones | In `ApplyTextureFromCache`, call `Destroy(oldSprite.texture)` before assigning the new sprite |
| Second request for same pack re-downloads | LRU cache lookup logic has an off-by-one or key mismatch | Add a `Debug.Log` at cache hit/miss; confirm `_cacheKeys[i] == urlIndex` comparison is correct |
| Index file parses but `TryGetAddress` always returns false | Resource ID string case mismatch between JSON and `_slotResourceIds` inspector values | Ensure exact string match; JSON keys are case-sensitive |
| Pack parses but inner texture is blank | `innerIndex` out of range for the decoded `blocks` array | Log `blocks.Length` and `innerIdx`; confirm JSON `entries` array length matches the pack |
| All downloads stall after one error | `_pendingUrlIndex` is not reset in `OnStringLoadError`; next callback is misrouted | Reset `_pendingUrlIndex = -1` and `_pendingSlotIndex = -1` in `OnStringLoadError` |
| UI slots load slowly even with cache hits | `LoadNextSlot` delays 5.5 s between all slots, including cache hits | Skip the 5.5 s delay when dispatching `LoadNextSlot` for a cache hit; only delay when a network download is initiated |

---

## See Also

- [web-loading.md](web-loading.md) — Base `VRCStringDownloader` / `VRCImageDownloader` API, rate limits, trusted URL list
- [image-loading-vram.md](image-loading-vram.md) — VRAM management: `Destroy` vs `Dispose`, double-buffer fade, VRAM cost table
- [patterns-performance.md](patterns-performance.md) — Frame-budget `Stopwatch` pattern for heavy decode operations in `Update`
