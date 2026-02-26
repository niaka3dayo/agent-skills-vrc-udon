# Web Loading (String / Image ダウンロード)

**対応SDKバージョン**: 3.7.1 - 3.10.1 (2026年2月時点)

UdonSharp では `System.Net` が使用不可のため、Web からデータを取得するには VRChat 専用の API を使用する。

## 概要

| API | 用途 | 名前空間 |
|-----|------|----------|
| `VRCStringDownloader` | テキスト/JSON ダウンロード | `VRC.SDK3.StringLoading` |
| `VRCImageDownloader` | 画像ダウンロード (Texture2D) | `VRC.SDK3.ImageLoading` |
| `VRCJson` | JSON パース (string → DataDictionary) | `VRC.SDK3.Data` |

## 共通制約

### レート制限

| 種別 | 制限 | 超過時の挙動 |
|------|------|-------------|
| String Loading | **5秒に1回** | キューに入り、ランダム順で処理 |
| Image Loading | **5秒に1回** (シーン全体で共有) | キューに入り、ランダム順で処理 |

### Trusted URL (信頼済みドメイン)

VRChat はセキュリティ上、外部 URL へのアクセスをドメインの許可リストで制限している。
許可リスト外の URL は、ユーザーが設定で **「Allow Untrusted URLs」** を有効にしない限りブロックされる。

**String Loading で信頼済みのドメイン:**

| ドメイン | サービス |
|---------|---------|
| `*.github.io` | GitHub Pages |
| `gist.githubusercontent.com` | GitHub Gist |
| `pastebin.com` | Pastebin |
| `*.vrcdn.cloud` | VRCDN |

**Image Loading で信頼済みのドメイン:**

| ドメイン | サービス |
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

> 最新のリストは [VRChat Wiki: Trusted URLs](https://wiki.vrchat.com/wiki/Trusted_URLs) を参照。
> ドメインは変更される可能性があるため、WebSearch で確認すること。

### VRCUrl の動的生成制約 (重要)

VRCUrl は **ランタイムで動的に生成できない**。
Udon VM がセキュリティ上の理由で意図的にブロックしている（データ漏洩・悪意ある URL 生成の防止）。

#### できること / できないこと

| 操作 | 可否 | 説明 |
|------|:----:|------|
| Inspector で VRCUrl フィールドを設定 | ✅ | ビルド時にシリアライズされる |
| `new VRCUrl("https://リテラル文字列")` | ✅ | リテラルが Udon Assembly に定数埋め込みされ、VM のセキュリティフィルタを通過 |
| `new VRCUrl(stringVariable)` | ❌ | **Udon VM がブロック** — ランタイム文字列からの生成不可 |
| 文字列連結で URL を組み立てて VRCUrl 化 | ❌ | 同上。`"base" + param` → VRCUrl は不可 |
| `VRCUrlInputField.GetUrl()` | ✅ | **ユーザーが手動入力/ペースト**した URL を VRCUrl として取得 |
| `VRCUrlInputField.SetUrl(vrcUrl)` | ✅ | 既存の VRCUrl を InputField に表示 (新規 URL の生成ではない) |

> **2026年2月時点**: Canny で 158+ 票の Feature Request が open のまま。
> VRChat は trusted domain 限定の部分的解決を検討中だが、完全な動的生成は未実装。

#### なぜ VRCUrlInputField を使う人が多いのか

VRCUrlInputField は「ユーザーの手動入力」を経由する唯一のランタイム URL 取得手段であり、
ビデオプレイヤーやカスタム API 呼び出しで「動的な URL」が必要なワールドでは事実上必須のコンポーネント。

> **注意**: VRCUrlInputField 経由で取得した URL も **Trusted URL チェックの対象**。
> 信頼済みドメイン外の URL を使う場合、ユーザーが「Allow Untrusted URLs」を有効にしている必要がある。

```csharp
// VRCUrlInputField パターン: ユーザーが URL を入力 → Udon で取得
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

    // UI ボタンの OnClick から呼ばれる
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

#### 動的 URL が必要な場合の設計パターン

| パターン | 説明 | 適用例 |
|---------|------|--------|
| **VRCUrlInputField** | ユーザーに URL を入力させる | ビデオプレイヤー、カスタム API |
| **VRCUrl 配列 + インデックス** | あらかじめ全候補を Inspector に設定し、インデックスで選択 | BGM リスト、画像ギャラリー |
| **サーバーサイドルーティング** | 固定 URL に対してサーバー側でパラメータを処理 | スコアボード (`/api/scores` 1本で返す) |

```csharp
// VRCUrl 配列パターン: 事前定義 + インデックス選択
[SerializeField] private VRCUrl[] imageUrls; // Inspector で複数 URL を設定
[SerializeField] private Material targetMaterial;
private VRCImageDownloader _downloader; // Start() で初期化
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
// サーバーサイドルーティングパターン: 固定 URL 1本でサーバー側がデータを返す
[SerializeField] private VRCUrl scoreBoardUrl; // "https://example.github.io/scores.json"

public void FetchScores()
{
    VRCStringDownloader.LoadUrl(scoreBoardUrl, (IUdonEventReceiver)this);
}
// → サーバー側で最新データを返す。URL 自体を変える必要がない設計。
```

#### アンチパターン

```csharp
// ❌ NG: ランタイム文字列から VRCUrl を生成 — Udon VM がブロック
string dynamicUrl = "https://api.example.com/data?id=" + playerId;
VRCUrl url = new VRCUrl(dynamicUrl); // コンパイルは通るが実行時に失敗

// ❌ NG: SetUrl → GetUrl で新しい動的 URL を生成しようとするパターン
//        SetUrl は既存の VRCUrl をフィールドに表示するだけ。
//        GetUrl() は SetUrl で渡したのと同じ VRCUrl を返すだけで、
//        動的な文字列から新しい VRCUrl を生成することにはならない。
// urlInputField.SetUrl(existingVRCUrl);   // 既存 VRCUrl をセット
// VRCUrl result = urlInputField.GetUrl(); // 同一オブジェクトが返るだけ
```

### URL リダイレクトの制限

| API | リダイレクト | 注意 |
|-----|:----------:|------|
| String Loading | ⚠️ 動作するが Trusted URL チェック対象 | リダイレクト先も trusted domain である必要がある |
| Image Loading | ❌ **不可** | 直接 URL が必須。短縮 URL やリダイレクト URL は使えない |

---

## VRCStringDownloader

### API

```csharp
using VRC.SDK3.StringLoading;

// 静的メソッド: URL からテキストをダウンロード
VRCStringDownloader.LoadUrl(VRCUrl url, IUdonEventReceiver udonBehaviour);
```

### IVRCStringDownload プロパティ

| プロパティ | 型 | 説明 |
|-----------|-----|------|
| `Result` | `string` | ダウンロードされた文字列 (UTF-8 デコード) |
| `ResultBytes` | `byte[]` | ダウンロードされた生バイトデータ |
| `Error` | `string` | エラーメッセージ (失敗時) |
| `ErrorCode` | `int` | HTTP エラーコード (失敗時) |
| `IsComplete` | `bool` | ダウンロード完了フラグ |
| `Url` | `VRCUrl` | リクエストした URL |
| `UdonBehaviour` | `UdonBehaviour` | イベント送信先 |

### イベント

| イベント | タイミング |
|---------|-----------|
| `OnStringLoadSuccess(IVRCStringDownload result)` | ダウンロード成功時 |
| `OnStringLoadError(IVRCStringDownload result)` | ダウンロード失敗時 |

### 基本パターン

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

// コンストラクタ: インスタンスを作成 (再利用可能)
VRCImageDownloader imageDownloader = new VRCImageDownloader();

// ダウンロード実行 (複数のオーバーロード)
IVRCImageDownload imageDownloader.DownloadImage(
    VRCUrl url,
    Material material,                    // テクスチャ適用先マテリアル
    IUdonEventReceiver udonBehaviour,     // イベント受信先
    TextureInfo textureInfo               // (省略可) テクスチャ設定
);
```

**注意 (UdonSharp)**: `udonBehaviour` パラメータを省略すると **イベントが受信されない**。
UdonGraph では省略時に現在の UdonBehaviour が使われるが、UdonSharp では明示的に指定が必要。

### IVRCImageDownload プロパティ

| プロパティ | 型 | 説明 |
|-----------|-----|------|
| `Result` | `Texture2D` | ダウンロードされたテクスチャ |
| `SizeInMemoryBytes` | `int` | テクスチャのメモリサイズ (bytes) |
| `Error` | `string` | エラーメッセージ (失敗時) |
| `ErrorCode` | `int` | HTTP エラーコード (失敗時) |
| `TextureInfo` | `TextureInfo` | 指定したテクスチャ設定 |
| `Material` | `Material` | 指定したマテリアル |

### TextureInfo プロパティ

| プロパティ | 型 | デフォルト | 説明 |
|-----------|-----|-----------|------|
| `GenerateMipmaps` | `bool` | `false` | ミップマップ生成 |
| `FilterMode` | `FilterMode` | `Trilinear` | テクスチャフィルタリング |
| `WrapModeU` | `TextureWrapMode` | `Repeat` | U軸ラップモード |
| `WrapModeV` | `TextureWrapMode` | `Repeat` | V軸ラップモード |
| `WrapModeW` | `TextureWrapMode` | `Repeat` | W軸ラップモード |
| `AnisoLevel` | `int` | `9` | 異方性フィルタリング (0=無効, 9-16=有効) |
| `MaterialProperty` | `string` | `null` | テクスチャ適用先プロパティ名のオーバーライド |

### 画像制約

| 制約 | 値 |
|------|-----|
| 最大解像度 | **2048 x 2048** (超過でエラー) |
| リダイレクト | **不可** (直接 URL 必須) |
| テクスチャ形式 | 自動選択: アルファあり → RGBA32/RGB64、なし → RGB24/RGB48 |

### イベント

| イベント | タイミング |
|---------|-----------|
| `OnImageLoadSuccess(IVRCImageDownload result)` | ダウンロード成功時 |
| `OnImageLoadError(IVRCImageDownload result)` | ダウンロード失敗時 |

### メモリ管理 (重要)

画像をダウンロードするたびにメモリが消費される。
古い画像を差し替える場合は **必ず `Dispose()` で解放** すること。放置するとメモリリークでクラッシュの原因になる。

```csharp
// 個別のダウンロード結果を解放
IVRCImageDownload oldDownload;
oldDownload.Dispose();

// ダウンローダー自体を破棄 (全テクスチャ解放)
imageDownloader.Dispose();
```

### 基本パターン

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
    public RawImage uiImage; // UI に表示する場合

    private VRCImageDownloader _downloader;
    private IVRCImageDownload _currentDownload;

    void Start()
    {
        _downloader = new VRCImageDownloader();
    }

    public void StartDownload()
    {
        // 前回のダウンロード結果を解放
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

        // UI に適用する場合
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
        // クリーンアップ: 全テクスチャをメモリから解放
        if (_downloader != null)
        {
            _downloader.Dispose();
        }
    }
}
```

---

## VRCJson (ダウンロードした文字列の JSON パース)

String Loading と組み合わせて、ダウンロードした JSON 文字列をパースする。

### API

```csharp
using VRC.SDK3.Data;

// JSON → DataToken (成功で true)
bool VRCJson.TryDeserializeFromJson(string json, out DataToken result);

// DataToken → JSON 文字列 (成功で true)
bool VRCJson.TrySerializeToJson(DataToken token, JsonExportType exportType, out DataToken result);
```

### 注意事項

| 注意点 | 詳細 |
|--------|------|
| **遅延パース** | トップレベルのみ即時パース。ネストした無効 JSON は `TryGetValue` 時に `DataError.UnableToParse` |
| **数値型の変換** | デシリアライズ時、すべての数値は `Double` に変換される (`int` → `Double`) |
| **Object Reference 不可** | オブジェクト参照を含む DataToken のシリアライズは不可 (`DataError.TypeUnsupported`) |

### String Loading + JSON パースパターン

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
        // JSON パース
        if (!VRCJson.TryDeserializeFromJson(result.Result, out DataToken jsonData))
        {
            Debug.LogError("[JsonDownload] JSON parse failed");
            return;
        }

        // DataDictionary として使用
        DataDictionary dict = jsonData.DataDictionary;

        // 値の取得 (数値は Double として格納される)
        if (dict.TryGetValue("name", out DataToken nameToken))
        {
            string name = nameToken.String;
            Debug.Log($"[JsonDownload] name = {name}");
        }

        if (dict.TryGetValue("score", out DataToken scoreToken))
        {
            // 注意: JSON の数値は Double で格納される
            int score = (int)scoreToken.Double;
            Debug.Log($"[JsonDownload] score = {score}");
        }

        // DataList (配列) の取得
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

## 設計パターン

### リトライパターン (レート制限対応)

```csharp
public VRCUrl dataUrl;
private int _retryCount = 0;
private const int MAX_RETRIES = 3;
private const float RETRY_DELAY = 6.0f; // 5秒制限 + マージン

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

### 複数 URL の順次ダウンロード

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
    // レート制限を考慮して遅延
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

## トラブルシューティング

| 症状 | 原因 | 解決策 |
|------|------|--------|
| `new VRCUrl(変数)` が実行時に失敗 | VRCUrl のランタイム動的生成は不可 | VRCUrlInputField (ユーザー入力) か VRCUrl[] 配列 (事前定義) を使用 |
| ダウンロードが一切動かない | Trusted URL リストにないドメイン | 信頼済みドメインを使用するか、ユーザーに「Allow Untrusted URLs」を案内 |
| Image download エラー | 画像が 2048x2048 を超えている | 画像を事前にリサイズ |
| Image download エラー | URL がリダイレクトしている | 直接 URL を使用 (短縮 URL 不可) |
| 5秒より速くダウンロードしたい | レート制限 | 不可。キューに入るだけ。処理順はランダム |
| UdonSharp で Image イベントが来ない | `udonBehaviour` パラメータ未指定 | `(IUdonEventReceiver)this` を明示的に渡す |
| JSON の数値が `int` でない | VRCJson の仕様 | `(int)token.Double` でキャスト |
| メモリ使用量が増え続ける | 古いテクスチャを Dispose していない | `IVRCImageDownload.Dispose()` で解放 |
| JSON パース成功後に内部でエラー | 遅延パース仕様 | ネスト値の `TryGetValue` で false チェック必須 |

---

## 参考リンク

| リソース | URL |
|---------|-----|
| String Loading 公式 | creators.vrchat.com/worlds/udon/string-loading/ |
| Image Loading 公式 | creators.vrchat.com/worlds/udon/image-loading/ |
| External URLs 公式 | creators.vrchat.com/worlds/udon/external-urls/ |
| VRCJson 公式 | creators.vrchat.com/worlds/udon/data-containers/vrcjson/ |
| Trusted URLs Wiki | wiki.vrchat.com/wiki/Trusted_URLs |
| Image Loading サンプル | github.com/vrchat-community/examples-image-loading |
