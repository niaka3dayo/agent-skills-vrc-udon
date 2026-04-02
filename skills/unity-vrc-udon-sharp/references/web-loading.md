# Web Loading (String / Image Download)

**Supported SDK Versions**: 3.7.1 - 3.10.2 (as of March 2026)

Since `System.Net` is unavailable in UdonSharp, VRChat-specific APIs must be used to retrieve data from the web.

## Overview

| API | Purpose | Namespace |
|-----|------|----------|
| `VRCStringDownloader` | Text/JSON download | `VRC.SDK3.StringLoading` |
| `VRCImageDownloader` | Image download (Texture2D) | `VRC.SDK3.ImageLoading` |
| `VRCJson` | JSON parsing (string -> DataDictionary) | `VRC.SDK3.Data` |

## Common Constraints

### Rate Limiting

| Type | Limit | Behavior when exceeded |
|------|------|-------------|
| String Loading | **Once per 5 seconds** | Queued and processed in random order |
| Image Loading | **Once per 5 seconds** (shared across the entire scene) | Queued and processed in random order |

### Trusted URLs (Allowed Domains)

VRChat restricts access to external URLs through a domain allow list for security purposes.
URLs outside the allow list are blocked unless the user enables **"Allow Untrusted URLs"** in their settings.

**Trusted domains for String Loading:**

| Domain | Service |
|---------|---------|
| `*.github.io` | GitHub Pages |
| `gist.githubusercontent.com` | GitHub Gist |
| `pastebin.com` | Pastebin |
| `*.vrcdn.cloud` | VRCDN |

**Trusted domains for Image Loading:**

| Domain | Service |
|---------|---------|
| `i.imgur.com` | Imgur |
| `cdn.discordapp.com` | Discord CDN |
| `*.github.io` | GitHub Pages |
| `dl.dropboxusercontent.com` | Dropbox |
| `i.postimg.cc` | Postimages |
| `i.ibb.co` | ImgBB |
| `images2.imgbox.com` | imgbox |
| `i.redd.it` | Reddit |
| `pbs.twimg.com` | Twitter/X |
| `api.vrchat.cloud` | VRChat API |

> For the latest list, refer to [VRChat Wiki: Trusted URLs](https://wiki.vrchat.com/wiki/Trusted_URLs).
> Domains may change, so verify via WebSearch.

### VRCUrl Dynamic Generation Constraints (Important)

VRCUrl **cannot be dynamically generated at runtime**.
The Udon VM intentionally blocks this for security reasons (preventing data leaks and malicious URL generation).

#### What you can and cannot do

| Operation | Possible | Description |
|------|:----:|------|
| Set VRCUrl field in Inspector | Yes | Serialized at build time |
| `new VRCUrl("https://literal-string")` | Yes | The literal is embedded as a constant in Udon Assembly and passes the VM's security filter |
| `new VRCUrl(stringVariable)` | No | **Blocked by Udon VM** - cannot generate from runtime strings |
| Build URL via string concatenation then convert to VRCUrl | No | Same as above. `"base" + param` -> VRCUrl is not possible |
| `VRCUrlInputField.GetUrl()` | Yes | Retrieves a URL **manually entered/pasted by the user** as VRCUrl |
| `VRCUrlInputField.SetUrl(vrcUrl)` | Yes | Displays an existing VRCUrl in the InputField (does not generate a new URL) |

> **As of March 2026**: A Feature Request with 158+ votes on Canny remains open.
> VRChat is considering a partial solution limited to trusted domains, but full dynamic generation is not yet implemented.

#### Why VRCUrlInputField is widely used

VRCUrlInputField is the only way to obtain a URL at runtime through "user manual input",
and is effectively a required component for worlds that need "dynamic URLs" such as video players or custom API calls.

> **Note**: URLs obtained via VRCUrlInputField are also **subject to Trusted URL checks**.
> If using URLs outside trusted domains, the user must have "Allow Untrusted URLs" enabled.

```csharp
// VRCUrlInputField pattern: User enters URL -> retrieve in Udon
using UdonSharp;
using UnityEngine;
using VRC.SDKBase;
using VRC.SDK3.Components;
using VRC.SDK3.StringLoading;
using VRC.Udon.Common.Interfaces;

[UdonBehaviourSyncMode(BehaviourSyncMode.NoVariableSync)]
public class UserUrlLoader : UdonSharpBehaviour
{
    [SerializeField] private VRCUrlInputField urlInputField;

    // Called from UI button's OnClick
    public void OnLoadButtonClicked()
    {
        VRCUrl url = urlInputField.GetUrl();
        VRCStringDownloader.LoadUrl(url, (IUdonEventReceiver)this);
    }

    public override void OnStringLoadSuccess(IVRCStringDownload result)
    {
        Debug.Log($"Loaded: {result.Result.Length} chars");
    }

    public override void OnStringLoadError(IVRCStringDownload result)
    {
        Debug.LogError($"Error: {result.Error}");
    }
}
```

#### Design Patterns When Dynamic URLs Are Needed

| Pattern | Description | Example use |
|---------|------|--------|
| **VRCUrlInputField** | Have the user enter the URL | Video players, custom APIs |
| **VRCUrl array + index** | Pre-set all candidates in Inspector, select by index | BGM lists, image galleries |
| **Server-side routing** | Server processes parameters against a fixed URL | Scoreboards (return via a single `/api/scores`) |

```csharp
// VRCUrl array pattern: Pre-defined + index selection
[SerializeField] private VRCUrl[] imageUrls; // Set multiple URLs in Inspector
[SerializeField] private Material targetMaterial;
private VRCImageDownloader _downloader; // Initialize in Start()
private int _currentIndex = 0;

public void LoadNext()
{
    if (_currentIndex >= imageUrls.Length) _currentIndex = 0;
    _downloader.DownloadImage(
        imageUrls[_currentIndex],
        targetMaterial,
        (IUdonEventReceiver)this,
        new TextureInfo()
    );
    _currentIndex++;
}
```

```csharp
// Server-side routing pattern: Fixed single URL, server returns the data
[SerializeField] private VRCUrl scoreBoardUrl; // "https://example.github.io/scores.json"

public void FetchScores()
{
    VRCStringDownloader.LoadUrl(scoreBoardUrl, (IUdonEventReceiver)this);
}
// -> The server returns the latest data. No need to change the URL itself.
```

#### Anti-Patterns

```csharp
// NG: Generating VRCUrl from a runtime string - blocked by Udon VM
string dynamicUrl = "https://api.example.com/data?id=" + playerId;
VRCUrl url = new VRCUrl(dynamicUrl); // Compiles but fails at runtime

// NG: Attempting to generate a new dynamic URL via SetUrl -> GetUrl
//     SetUrl only displays an existing VRCUrl in the field.
//     GetUrl() returns the same VRCUrl that was passed to SetUrl,
//     and does not generate a new VRCUrl from a dynamic string.
// urlInputField.SetUrl(existingVRCUrl);   // Sets an existing VRCUrl
// VRCUrl result = urlInputField.GetUrl(); // Returns the same object
```

### URL Redirect Limitations

| API | Redirects | Notes |
|-----|:----------:|------|
| String Loading | Supported but subject to Trusted URL checks | Redirect destination must also be a trusted domain |
| Image Loading | **Not supported** | Direct URLs required. Short URLs and redirect URLs cannot be used |

---

## VRCStringDownloader

### API

```csharp
using VRC.SDK3.StringLoading;

// Static method: Download text from URL
VRCStringDownloader.LoadUrl(VRCUrl url, IUdonEventReceiver udonBehaviour);
```

### IVRCStringDownload Properties

| Property | Type | Description |
|-----------|-----|------|
| `Result` | `string` | Downloaded string (UTF-8 decoded) |
| `ResultBytes` | `byte[]` | Downloaded raw byte data |
| `Error` | `string` | Error message (on failure) |
| `ErrorCode` | `int` | HTTP error code (on failure) |
| `IsComplete` | `bool` | Download completion flag |
| `Url` | `VRCUrl` | Requested URL |
| `UdonBehaviour` | `UdonBehaviour` | Event receiver target |

### Events

| Event | Timing |
|---------|-----------|
| `OnStringLoadSuccess(IVRCStringDownload result)` | On successful download |
| `OnStringLoadError(IVRCStringDownload result)` | On download failure |

### Basic Pattern

```csharp
using UdonSharp;
using UnityEngine;
using VRC.SDKBase;
using VRC.SDK3.StringLoading;
using VRC.Udon.Common.Interfaces;

[UdonBehaviourSyncMode(BehaviourSyncMode.NoVariableSync)]
public class StringDownloadExample : UdonSharpBehaviour
{
    public VRCUrl dataUrl;

    public void StartDownload()
    {
        VRCStringDownloader.LoadUrl(dataUrl, (IUdonEventReceiver)this);
    }

    public override void OnStringLoadSuccess(IVRCStringDownload result)
    {
        string data = result.Result;
        Debug.Log($"[StringDownload] Success: {data.Length} chars");
    }

    public override void OnStringLoadError(IVRCStringDownload result)
    {
        Debug.LogError($"[StringDownload] Error {result.ErrorCode}: {result.Error}");
    }
}
```

---

## VRCImageDownloader

### API

```csharp
using VRC.SDK3.ImageLoading;

// Constructor: Create an instance (reusable)
VRCImageDownloader imageDownloader = new VRCImageDownloader();

// Execute download (multiple overloads)
IVRCImageDownload imageDownloader.DownloadImage(
    VRCUrl url,
    Material material,                    // Material to apply texture to
    IUdonEventReceiver udonBehaviour,     // Event receiver target
    TextureInfo textureInfo               // (Optional) Texture settings
);
```

**Note (UdonSharp)**: If the `udonBehaviour` parameter is omitted, **events will not be received**.
In UdonGraph, the current UdonBehaviour is used when omitted, but in UdonSharp it must be explicitly specified.

### IVRCImageDownload Properties

| Property | Type | Description |
|-----------|-----|------|
| `Result` | `Texture2D` | Downloaded texture |
| `SizeInMemoryBytes` | `int` | Texture memory size (bytes) |
| `Error` | `string` | Error message (on failure) |
| `ErrorCode` | `int` | HTTP error code (on failure) |
| `TextureInfo` | `TextureInfo` | Specified texture settings |
| `Material` | `Material` | Specified material |

### TextureInfo Properties

| Property | Type | Default | Description |
|-----------|-----|-----------|------|
| `GenerateMipmaps` | `bool` | `false` | Mipmap generation |
| `FilterMode` | `FilterMode` | `Trilinear` | Texture filtering |
| `WrapModeU` | `TextureWrapMode` | `Repeat` | U-axis wrap mode |
| `WrapModeV` | `TextureWrapMode` | `Repeat` | V-axis wrap mode |
| `WrapModeW` | `TextureWrapMode` | `Repeat` | W-axis wrap mode |
| `AnisoLevel` | `int` | `9` | Anisotropic filtering (0=disabled, 9-16=enabled) |
| `MaterialProperty` | `string` | `null` | Override for texture target property name |

### Image Constraints

| Constraint | Value |
|------|-----|
| Maximum resolution | **2048 x 2048** (error if exceeded) |
| Redirects | **Not supported** (direct URL required) |
| Texture format | Auto-selected: with alpha -> RGBA32/RGB64, without -> RGB24/RGB48 |

### Events

| Event | Timing |
|---------|-----------|
| `OnImageLoadSuccess(IVRCImageDownload result)` | On successful download |
| `OnImageLoadError(IVRCImageDownload result)` | On download failure |

### Memory Management (Important)

Memory is consumed each time an image is downloaded.
When replacing old images, **always release with `Dispose()`** to free VRC internal state.

> **Important**: `Dispose()` only frees the VRC download wrapper — it does NOT release the GPU memory
> (VRAM) of textures already applied to materials. To free VRAM, call `Destroy(texture)` on the old
> texture before applying a new one. For detailed guidance on VRAM management, double-buffer fading,
> and other advanced patterns, see [image-loading-vram.md](image-loading-vram.md).

```csharp
// Dispose individual download results
IVRCImageDownload oldDownload;
oldDownload.Dispose();

// Dispose the downloader itself (releases all textures)
imageDownloader.Dispose();
```

### Basic Pattern

```csharp
using UdonSharp;
using UnityEngine;
using UnityEngine.UI;
using VRC.SDKBase;
using VRC.SDK3.ImageLoading;
using VRC.Udon.Common.Interfaces;

[UdonBehaviourSyncMode(BehaviourSyncMode.NoVariableSync)]
public class ImageDownloadExample : UdonSharpBehaviour
{
    public VRCUrl imageUrl;
    public Material targetMaterial;
    public RawImage uiImage; // For displaying in UI

    private VRCImageDownloader _downloader;
    private IVRCImageDownload _currentDownload;

    void Start()
    {
        _downloader = new VRCImageDownloader();
    }

    public void StartDownload()
    {
        // Dispose previous download result
        if (_currentDownload != null)
        {
            _currentDownload.Dispose();
        }

        TextureInfo info = new TextureInfo();
        info.GenerateMipmaps = false;
        info.FilterMode = FilterMode.Bilinear;

        _currentDownload = _downloader.DownloadImage(
            imageUrl,
            targetMaterial,
            (IUdonEventReceiver)this,
            info
        );
    }

    public override void OnImageLoadSuccess(IVRCImageDownload result)
    {
        Debug.Log($"[ImageDownload] Success: {result.SizeInMemoryBytes} bytes");

        // Apply to UI
        if (uiImage != null)
        {
            uiImage.texture = result.Result;
        }
    }

    public override void OnImageLoadError(IVRCImageDownload result)
    {
        Debug.LogError($"[ImageDownload] Error {result.ErrorCode}: {result.Error}");
    }

    private void OnDestroy()
    {
        // Cleanup: release all textures from memory
        if (_downloader != null)
        {
            _downloader.Dispose();
        }
    }
}
```

---

## VRCJson (JSON Parsing of Downloaded Strings)

Used in combination with String Loading to parse downloaded JSON strings.

### API

```csharp
using VRC.SDK3.Data;

// JSON -> DataToken (returns true on success)
bool VRCJson.TryDeserializeFromJson(string json, out DataToken result);

// DataToken -> JSON string (returns true on success)
bool VRCJson.TrySerializeToJson(DataToken token, JsonExportType exportType, out DataToken result);
```

### Important Notes

| Note | Details |
|--------|------|
| **Lazy parsing** | Only the top level is parsed immediately. Invalid nested JSON returns `DataError.UnableToParse` on `TryGetValue` |
| **Numeric type conversion** | During deserialization, all numbers are converted to `Double` (`int` -> `Double`) |
| **Object references not supported** | DataTokens containing object references cannot be serialized (`DataError.TypeUnsupported`) |

### String Loading + JSON Parsing Pattern

```csharp
using UdonSharp;
using UnityEngine;
using VRC.SDKBase;
using VRC.SDK3.StringLoading;
using VRC.SDK3.Data;
using VRC.Udon.Common.Interfaces;

[UdonBehaviourSyncMode(BehaviourSyncMode.NoVariableSync)]
public class JsonDownloadExample : UdonSharpBehaviour
{
    [Header("Data Source")]
    public VRCUrl jsonUrl;

    [Header("Display")]
    public UnityEngine.UI.Text statusText;

    public void FetchData()
    {
        VRCStringDownloader.LoadUrl(jsonUrl, (IUdonEventReceiver)this);
    }

    public override void OnStringLoadSuccess(IVRCStringDownload result)
    {
        // Parse JSON
        if (!VRCJson.TryDeserializeFromJson(result.Result, out DataToken jsonData))
        {
            Debug.LogError("[JsonDownload] JSON parse failed");
            return;
        }

        // Use as DataDictionary
        DataDictionary dict = jsonData.DataDictionary;

        // Get values (numbers are stored as Double)
        if (dict.TryGetValue("name", out DataToken nameToken))
        {
            string name = nameToken.String;
            Debug.Log($"[JsonDownload] name = {name}");
        }

        if (dict.TryGetValue("score", out DataToken scoreToken))
        {
            // Note: JSON numbers are stored as Double
            int score = (int)scoreToken.Double;
            Debug.Log($"[JsonDownload] score = {score}");
        }

        // Get DataList (arrays)
        if (dict.TryGetValue("items", out DataToken itemsToken))
        {
            DataList items = itemsToken.DataList;
            for (int i = 0; i < items.Count; i++)
            {
                Debug.Log($"[JsonDownload] item[{i}] = {items[i].String}");
            }
        }

        if (statusText != null)
        {
            statusText.text = "Data loaded successfully";
        }
    }

    public override void OnStringLoadError(IVRCStringDownload result)
    {
        Debug.LogError($"[JsonDownload] Error {result.ErrorCode}: {result.Error}");
        if (statusText != null)
        {
            statusText.text = $"Error: {result.Error}";
        }
    }
}
```

---

## Design Patterns

### Retry Pattern (Rate Limit Handling)

```csharp
public VRCUrl dataUrl;
private int _retryCount = 0;
private const int MAX_RETRIES = 3;
private const float RETRY_DELAY = 6.0f; // 5-second limit + margin

public void StartDownload()
{
    _retryCount = 0;
    VRCStringDownloader.LoadUrl(dataUrl, (IUdonEventReceiver)this);
}

public override void OnStringLoadError(IVRCStringDownload result)
{
    if (_retryCount < MAX_RETRIES)
    {
        _retryCount++;
        Debug.LogWarning($"[Download] Retry {_retryCount}/{MAX_RETRIES}");
        SendCustomEventDelayedSeconds(nameof(RetryDownload), RETRY_DELAY);
    }
    else
    {
        Debug.LogError($"[Download] Failed after {MAX_RETRIES} retries: {result.Error}");
    }
}

public void RetryDownload()
{
    VRCStringDownloader.LoadUrl(dataUrl, (IUdonEventReceiver)this);
}
```

### Sequential Download of Multiple URLs

```csharp
public VRCUrl[] urls;
private int _currentIndex = 0;
private string[] _results;

void Start()
{
    _results = new string[urls.Length];
}

public void StartBatchDownload()
{
    _currentIndex = 0;
    _results = new string[urls.Length];
    DownloadNext();
}

private void DownloadNext()
{
    if (_currentIndex >= urls.Length)
    {
        OnAllDownloadsComplete();
        return;
    }
    VRCStringDownloader.LoadUrl(urls[_currentIndex], (IUdonEventReceiver)this);
}

public override void OnStringLoadSuccess(IVRCStringDownload result)
{
    _results[_currentIndex] = result.Result;
    _currentIndex++;
    // Delay to respect rate limiting
    SendCustomEventDelayedSeconds(nameof(DownloadNext), 5.5f);
}

public override void OnStringLoadError(IVRCStringDownload result)
{
    Debug.LogError($"[Batch] Error at index {_currentIndex}: {result.Error}");
    _results[_currentIndex] = null;
    _currentIndex++;
    SendCustomEventDelayedSeconds(nameof(DownloadNext), 5.5f);
}

private void OnAllDownloadsComplete()
{
    Debug.Log("[Batch] All downloads complete");
}
```

---

## Troubleshooting

| Symptom | Cause | Solution |
|------|------|--------|
| `new VRCUrl(variable)` fails at runtime | Runtime dynamic generation of VRCUrl is not possible | Use VRCUrlInputField (user input) or VRCUrl[] array (pre-defined) |
| Download does not work at all | Domain not in Trusted URL list | Use a trusted domain, or instruct users to enable "Allow Untrusted URLs" |
| Image download error | Image exceeds 2048x2048 | Pre-resize the image |
| Image download error | URL redirects | Use a direct URL (short URLs not supported) |
| Want to download faster than every 5 seconds | Rate limiting | Not possible. Requests are only queued. Processing order is random |
| Image events not received in UdonSharp | `udonBehaviour` parameter not specified | Explicitly pass `(IUdonEventReceiver)this` |
| JSON numbers are not `int` | VRCJson specification | Cast with `(int)token.Double` |
| Memory usage keeps growing | Old textures not Disposed | Release with `IVRCImageDownload.Dispose()` |
| Error inside JSON after successful parse | Lazy parsing specification | Check for false on `TryGetValue` for nested values |

---

## Reference Links

| Resource | URL |
|---------|-----|
| String Loading Official | creators.vrchat.com/worlds/udon/string-loading/ |
| Image Loading Official | creators.vrchat.com/worlds/udon/image-loading/ |
| External URLs Official | creators.vrchat.com/worlds/udon/external-urls/ |
| VRCJson Official | creators.vrchat.com/worlds/udon/data-containers/vrcjson/ |
| Trusted URLs Wiki | wiki.vrchat.com/wiki/Trusted_URLs |
| Image Loading Sample | github.com/vrchat-community/examples-image-loading |

## See Also

- [api.md](api.md) - `VRCUrl`, `VRCStringDownloader`, and `VRCImageDownloader` API quick reference
- [troubleshooting.md](troubleshooting.md) - Web loading error table and debugging tips
- [image-loading-vram.md](image-loading-vram.md) - Advanced VRAM management: Destroy vs Dispose, double-buffer fade, stock mode, mipmap bias
