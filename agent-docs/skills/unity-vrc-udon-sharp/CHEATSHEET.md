# UdonSharp チートシート

**SDK 3.7.1 - 3.10.1 対応** (2026年2月時点)

## ブロック機能と代替手段

| ブロック対象 | 代替手段 |
|-------------|---------|
| `List<T>` | `T[]` または `DataList` |
| `Dictionary<K,V>` | `DataDictionary` |
| `async/await` | `SendCustomEventDelayedSeconds()` |
| `yield return` | `SendCustomEventDelayedSeconds()` |
| `try/catch` | Null チェック、バリデーション |
| LINQ | `for` ループ |
| `interface` | 基底クラス / `SendCustomEvent` |

## 利用可能な機能 (SDK 3.7.1+)

| 機能 | SDK | 備考 |
|---------|-----|-------|
| `StringBuilder` | 3.7.1 | 効率的な文字列結合 |
| `RegularExpressions` | 3.7.1 | パターンマッチング |
| `System.Random` | 3.7.1 | 決定論的乱数 |
| `GetComponent<T>()` (継承) | 3.8+ | UdonSharpBehaviour で動作 |
| `[NetworkCallable]` | 3.8.1 | パラメータ付きネットワークイベント |
| Persistence | 3.7.4 | PlayerData/PlayerObject |
| Dynamics for Worlds | 3.10.0 | PhysBones, Contacts |

---

## 同期モード

| モード | 用途 | 上限 | 同期方法 |
|--------|------|------|---------|
| `NoVariableSync` | イベントのみ | - | 同期なし |
| `Continuous` | 位置・回転 | ~200B | 自動 ~10Hz |
| `Manual` | 状態・スコア | 280KB | `RequestSerialization()` |

```csharp
[UdonBehaviourSyncMode(BehaviourSyncMode.Manual)]
public class MyScript : UdonSharpBehaviour { }
```

### 同期判断 (クイック)

| 質問 | No | Yes |
|----------|-----|------|
| 他プレイヤーに見える? | No sync | next |
| Late Joiner に必要? | Events only | next |
| 連続変化? | Manual sync | Continuous |

**目標**: 1 behaviour < 50 bytes (参考: 投票システム=9B, シューティング管理=38B)

---

## ネットワーキングパターン

```csharp
[UdonSynced, FieldChangeCallback(nameof(Value))]
private int _value;

public int Value {
    get => _value;
    set { _value = value; OnValueChanged(); }
}

public void SetValue(int newValue) {
    Networking.SetOwner(Networking.LocalPlayer, gameObject);
    Value = newValue;
    RequestSerialization();
}
```

---

## 主要イベント

| イベント | トリガー |
|---------|---------|
| `Interact()` | プレイヤーがインタラクト |
| `OnPickup()` / `OnDrop()` | ピックアップ取得/解放 |
| `OnPlayerJoined(VRCPlayerApi)` | プレイヤー参加 |
| `OnPlayerLeft(VRCPlayerApi)` | プレイヤー退出 |
| `OnPlayerTriggerEnter(VRCPlayerApi)` | プレイヤーがトリガーに入る |
| `OnDeserialization()` | 同期データ受信 |
| `OnOwnershipTransferred(VRCPlayerApi)` | オーナーシップ変更 |
| `OnPlayerRestored(VRCPlayerApi)` | **3.7.4+** 永続化データ読込 |
| `OnContactEnter(ContactEnterInfo)` | **3.10+** コンタクト開始 |
| `OnPhysBoneGrab(PhysBoneGrabInfo)` | **3.10+** PhysBone グラブ |

---

## 初期化パターン (非アクティブ対応)

```csharp
// ❌ Start() は非アクティブ状態だと呼ばれない
void Start() { audioSource = GetComponent<AudioSource>(); }

// ✅ OnEnable + フラグパターン
private bool _initialized = false;

void OnEnable() => Initialize();
void Start() => Initialize();

private void Initialize() {
    if (_initialized) return;
    _initialized = true;
    audioSource = GetComponent<AudioSource>();
}

public void PlaySound() {
    Initialize(); // 外部呼び出しに備える
    audioSource.Play();
}
```

| シナリオ | パターン |
|----------|----------|
| 常にアクティブ | `Start()` のみでOK |
| 非アクティブで配置 | `OnEnable()` + `Initialize()` |
| Synced変数あり | `OnDeserialization()` でも `Initialize()` |

---

## Player API クイックリファレンス

```csharp
// Get players
VRCPlayerApi local = Networking.LocalPlayer;
VRCPlayerApi[] all = new VRCPlayerApi[VRCPlayerApi.GetPlayerCount()];
VRCPlayerApi.GetPlayers(all);

// Check validity (ALWAYS do this before accessing VRCPlayerApi)
VRCPlayerApi player = Networking.LocalPlayer;
if (player != null && player.IsValid()) { }

// Properties
player.displayName    // string
player.playerId       // int
player.isLocal        // bool
player.isMaster       // bool
player.IsUserInVR()   // bool

// Position
player.GetPosition()  // Vector3
player.GetRotation()  // Quaternion
player.TeleportTo(pos, rot)

// Movement
player.SetVelocity(velocity)
player.GetVelocity()
player.Immobilize(true/false)
```

---

## 遅延実行

```csharp
// Instead of coroutines
SendCustomEventDelayedSeconds(nameof(MyMethod), 2.0f);
SendCustomEventDelayedFrames(nameof(MyMethod), 1);

// Repeating
public void StartLoop() {
    _running = true;
    DoLoop();
}
public void DoLoop() {
    if (!_running) return;
    // ... action ...
    SendCustomEventDelayedSeconds(nameof(DoLoop), 1.0f);
}
```

---

## スクリプト間通信

```csharp
// Call method on another script
otherScript.SendCustomEvent("MethodName");

// Pass data
otherScript.SetProgramVariable("fieldName", value);
otherScript.SendCustomEvent("ProcessData");

// Network event (legacy - no params)
SendCustomNetworkEvent(NetworkEventTarget.All, "MethodName");
SendCustomNetworkEvent(NetworkEventTarget.Owner, "MethodName");
```

---

## NetworkCallable (SDK 3.8.1+)

```csharp
// Method must have [NetworkCallable] attribute
[NetworkCallable]
public void TakeDamage(int damage, int attackerId) {
    health -= damage;
}

// Call with up to 8 parameters
SendCustomNetworkEvent(
    NetworkEventTarget.All,
    nameof(TakeDamage),
    damage, attackerId
);
```

**制約:** `public`, no `static`/`virtual`/`override`, max 8 params, syncable types only

---

## Persistence (SDK 3.7.4+)

```csharp
using VRC.SDK3.Persistence;

// Wait for data to load
public override void OnPlayerRestored(VRCPlayerApi player) {
    if (!player.isLocal) return;
    if (PlayerData.TryGetInt(player, "score", out int s)) {
        score = s;
    }
}

// Save data
PlayerData.SetInt(Networking.LocalPlayer, "score", 100);
```

**制限:** 100KB per player per world

---

## Dynamics (SDK 3.10.0+)

```csharp
// Contact events
public override void OnContactEnter(ContactEnterInfo info) {
    if (info.isAvatar) {
        Debug.Log($"Touched by: {info.player?.displayName}");
    }
}

// PhysBone events
public override void OnPhysBoneGrab(PhysBoneGrabInfo info) {
    Debug.Log($"Grabbed by: {info.player?.displayName}");
}
```

---

## 同期可能な型

| 型 | バイト数 | 備考 |
|----|---------|------|
| `bool` | 1 | |
| `byte` | 1 | 0-255 |
| `short` | 2 | |
| `int` | 4 | |
| `float` | 4 | |
| `string` | 可変 | 同期バッファサイズの制限あり |
| `Vector3` | 12 | |
| `Quaternion` | 16 | |
| `Color` | 16 | |
| `T[]` | 可変 | 上記の型の配列 |

**同期不可:** `GameObject`, `Transform`, `VRCPlayerApi`, カスタムクラス

---

## デバッグテンプレート

```csharp
[SerializeField] private bool _debug = false;

private void Log(string msg) {
    if (_debug) Debug.Log($"[{gameObject.name}] {msg}");
}
```

---

## よくある修正

| エラー | 修正方法 |
|--------|---------|
| 同期が動かない | `SetOwner()` → 変更 → `RequestSerialization()` |
| プレイヤーで NullReference | `player != null && player.IsValid()` を確認 |
| メソッドが見つからない | メソッドを `public` にし、パラメータを除去 |
| FieldChangeCallback が無反応 | ローカルでもプロパティセッターを使う |
| 構造体が変更できない | `var v = struct; v.x = 1; struct = v;` |
| Start() not called | 非アクティブ対応: `OnEnable()` + `Initialize()` |

---

## Web Loading (String / Image ダウンロード)

詳細は `references/web-loading.md` を参照。

```csharp
using VRC.SDK3.StringLoading;  // String Loading
using VRC.SDK3.ImageLoading;   // Image Loading
using VRC.SDK3.Data;           // VRCJson

// String download
VRCStringDownloader.LoadUrl(url, (IUdonEventReceiver)this);
// → OnStringLoadSuccess(IVRCStringDownload) / OnStringLoadError

// Image download (Dispose 必須!)
var dl = new VRCImageDownloader();
dl.DownloadImage(url, material, (IUdonEventReceiver)this, textureInfo);
// → OnImageLoadSuccess(IVRCImageDownload) / OnImageLoadError

// JSON parse (string download 後)
if (VRCJson.TryDeserializeFromJson(result.Result, out DataToken json))
{
    DataDictionary dict = json.DataDictionary;
    // 数値は Double で格納される: (int)token.Double
}
```

| 制約 | String Loading | Image Loading |
|------|:---:|:---:|
| レート制限 | 5秒/1回 | 5秒/1回 (シーン全体) |
| 最大サイズ | - | 2048x2048 |
| リダイレクト | ⚠️ trusted 限定 | ❌ 不可 |
| Trusted URL | 別ドメインリスト | 別ドメインリスト |
| メモリ管理 | 不要 | `Dispose()` 必須 |

**VRCUrl 動的生成: 不可** — `new VRCUrl(stringVar)` はランタイムで Udon VM がブロック。
動的 URL が必要な場合: (1) `VRCUrlInputField`（ユーザー手入力）, (2) `VRCUrl[]` 配列（事前定義）, (3) サーバー側ルーティング

---

## 公式ドキュメント・エラー調査 (WebSearch)

最新情報やエラー調査が必要な場合:

```text
# 公式ドキュメント検索
WebSearch: "調べたいAPI名や機能 site:creators.vrchat.com"

# UdonSharp API リファレンス
WebSearch: "API名 site:udonsharp.docs.vrchat.com"

# フォーラム検索
WebSearch: "エラーメッセージ site:ask.vrchat.com"

# 既知のバグ検索
WebSearch: "エラーメッセージ site:feedback.vrchat.com"

# GitHub Issues
WebSearch: "エラーメッセージ site:github.com/vrchat-community/UdonSharp"
```

| サイト | 用途 |
|--------|------|
| creators.vrchat.com | 公式 Udon / SDK ドキュメント |
| udonsharp.docs.vrchat.com | UdonSharp API リファレンス |
| ask.vrchat.com | Q&A、解決策 |
| feedback.vrchat.com | バグ報告、ステータス |
| GitHub | UdonSharp固有のバグ |
