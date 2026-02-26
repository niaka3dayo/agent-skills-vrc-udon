# UdonSharp トラブルシューティングガイド

VRChat UdonSharp 開発における一般的なエラー、原因、解決策。

**対応SDKバージョン**: 3.7.1 - 3.10.1 (2026年2月時点)

## 目次

- [コンパイルエラー](#コンパイルエラー)
- [ランタイムエラー](#ランタイムエラー)
- [ネットワーキングの問題](#ネットワーキングの問題)
- [NetworkCallable の問題 (SDK 3.8.1+)](#networkcallable-の問題-sdk-381)
- [Persistence の問題 (SDK 3.7.4+)](#persistence-の問題-sdk-374)
- [Dynamics の問題 (SDK 3.10.0+)](#dynamics-の問題-sdk-3100)
- [エディターの問題](#エディターの問題)
- [パフォーマンスの問題](#パフォーマンスの問題)
- [よくある落とし穴](#よくある落とし穴)

---

## コンパイルエラー

### "UdonSharp does not support X"

**症状:**
```
UdonSharpException: UdonSharp does not currently support [feature]
```

**よくある非対応機能:**
| 機能 | 代替手段 |
|---------|-------------|
| `async/await` | `SendCustomEventDelayedSeconds()` |
| `yield return` / coroutines | `SendCustomEventDelayedSeconds()` |
| Generics `List<T>` | Arrays `T[]` or `DataList` |
| LINQ | Manual loops |
| `dynamic` | Explicit types |
| `ref`/`out` parameters | Return values or class fields |
| Multi-dimensional arrays `T[,]` | Jagged arrays `T[][]` |
| Delegates / Events | `SendCustomEvent()` |
| `nameof()` on external types | String literals |
| `try/catch/finally` | Validate inputs, null checks |

**解決策:**
ドキュメントに記載された代替手段を使用する。完全なリストは `constraints.md` を参照。

---

### "The type or namespace 'X' could not be found"

**症状:**
```
CS0246: The type or namespace name 'List' could not be found
```

**原因:**
1. 非対応の System 型を使用している
2. `using` ディレクティブが不足している
3. アセンブリ定義の問題

**解決策:**

```csharp
// ❌ Wrong - List<T> not supported
using System.Collections.Generic;
List<int> numbers = new List<int>();

// ✅ Correct - Use arrays
int[] numbers = new int[10];

// ✅ Or use DataList for dynamic sizing
DataList list = new DataList();
list.Add(new DataToken(42));
```

---

### "'UdonSharpBehaviour' does not contain a definition for 'X'"

**症状:**
```
CS1061: 'UdonSharpBehaviour' does not contain a definition for 'StartCoroutine'
```

**原因:** Udon に公開されていない MonoBehaviour メソッドを使用しようとしている。

**よくある非公開メソッドと代替手段:**

| 非公開メソッド | 代替手段 |
|----------------|-------------|
| `StartCoroutine()` | `SendCustomEventDelayedSeconds()` |
| `StopCoroutine()` | Boolean flag check |
| `Invoke()` | `SendCustomEvent()` |
| `InvokeRepeating()` | `SendCustomEventDelayedSeconds()` loop |
| `GetComponentsInChildren<T>()` | Inspector references or manual search |
| `FindObjectOfType<T>()` | Inspector references |

---

### "Field 'X' is not serializable"

**症状:**
```
UdonSharp: Field 'X' is not serializable
```

**原因:** 非対応の型を同期しようとしている。

**同期可能な型:**
- Primitives: `bool`, `byte`, `sbyte`, `short`, `ushort`, `int`, `uint`, `long`, `ulong`, `float`, `double`, `char`
- Strings: `string`
- Unity types: `Vector2`, `Vector3`, `Vector4`, `Quaternion`, `Color`, `Color32`
- Arrays of above types

**同期不可:**
- Custom classes/structs
- `GameObject`, `Transform`
- `VRCPlayerApi`

**解決策:**
```csharp
// ❌ Wrong - Cannot sync VRCPlayerApi
[UdonSynced] private VRCPlayerApi targetPlayer;

// ✅ Correct - Sync player ID instead
[UdonSynced] private int targetPlayerId;

public VRCPlayerApi GetTargetPlayer()
{
    return VRCPlayerApi.GetPlayerById(targetPlayerId);
}
```

---

## ランタイムエラー

### "NullReferenceException"

**症状:**
```
NullReferenceException: Object reference not set to an instance of an object
```

**よくある原因:**
1. Inspector の参照が未設定
2. 間違ったオブジェクトで `GetComponent()` を呼んでいる
3. 操作中にプレイヤーが退出した
4. オブジェクトが破棄された

**解決策:**

```csharp
// Always validate Inspector references
void Start()
{
    if (targetObject == null)
    {
        Debug.LogError($"[{gameObject.name}] targetObject is not assigned!");
        enabled = false;
        return;
    }
}

// Always check player validity
public override void OnPlayerTriggerEnter(VRCPlayerApi player)
{
    if (player == null || !player.IsValid())
    {
        return;
    }
    // Safe to use player
}

// Check before accessing synced player
public void DoSomethingWithPlayer()
{
    VRCPlayerApi player = VRCPlayerApi.GetPlayerById(syncedPlayerId);
    if (player == null || !player.IsValid())
    {
        Debug.LogWarning("Player no longer valid");
        return;
    }
    // Safe to use player
}
```

---

### "SendCustomEvent: Method 'X' not found"

**症状:**
```
[UdonBehaviour] SendCustomEvent: Method 'MyMethod' not found
```

**原因:**
1. メソッド名のタイポ
2. メソッドが private（public でなければならない）
3. メソッドにパラメータがある（非対応）

**解決策:**

```csharp
// ❌ Wrong - Method is private
private void MyMethod() { }

// ❌ Wrong - Method has parameters
public void MyMethod(int value) { }

// ✅ Correct - Public, parameterless
public void MyMethod() { }

// ✅ For passing data, use SetProgramVariable first
otherScript.SetProgramVariable("inputValue", 42);
otherScript.SendCustomEvent("ProcessInput");
```

---

### "Heap ran out of memory"

**症状:**
```
Udon heap ran out of memory
```

**原因:**
1. ループ内で大量のオブジェクトを生成している
2. 大きすぎる配列
3. ループ内での文字列連結
4. クリアされていない配列によるメモリリーク

**解決策:**

```csharp
// ❌ Wrong - Creates new array every frame
void Update()
{
    VRCPlayerApi[] players = new VRCPlayerApi[VRCPlayerApi.GetPlayerCount()];
    VRCPlayerApi.GetPlayers(players);
}

// ✅ Correct - Reuse array, resize when needed
private VRCPlayerApi[] _playerCache;
private int _lastPlayerCount = 0;

void Update()
{
    int currentCount = VRCPlayerApi.GetPlayerCount();
    if (_playerCache == null || _playerCache.Length < currentCount)
    {
        _playerCache = new VRCPlayerApi[currentCount + 10]; // Buffer
    }
    VRCPlayerApi.GetPlayers(_playerCache);
}

// ❌ Wrong - String concatenation creates garbage
string result = "";
for (int i = 0; i < 100; i++)
{
    result += i.ToString(); // Creates new string each iteration
}

// ✅ Correct - Use char array or limit concatenation
// For display purposes, just show final result
```

---

### "ArrayIndexOutOfRangeException"

**症状:**
```
IndexOutOfRangeException: Index was outside the bounds of the array
```

**よくある原因:**
1. 配列が初期化されていない
2. Off-by-one エラー
3. イテレーション中にプレイヤー数が変化した

**解決策:**

```csharp
// Always check array bounds
public void ProcessArray(int[] data)
{
    if (data == null || data.Length == 0)
    {
        return;
    }
    
    for (int i = 0; i < data.Length; i++)
    {
        // Safe access
    }
}

// Be careful with player arrays
public override void OnPlayerLeft(VRCPlayerApi player)
{
    // GetPlayers() count has already changed!
    // Cache count before iteration if needed
}
```

---

## ネットワーキングの問題

### 変数が同期されない

**症状:**
- `[UdonSynced]` 変数が他のクライアントで更新されない
- プレイヤー間で状態が異なる

**チェックリスト:**

1. **Is the variable properly marked?**
```csharp
// ✅ Correct
[UdonSynced] private int myValue;
```

2. **Is the type syncable?** (See syncable types above)

3. **Did you call RequestSerialization()?**
```csharp
public void ChangeValue()
{
    myValue = 42;
    RequestSerialization(); // ← Required for Manual sync mode!
}
```

4. **Do you have ownership?**
```csharp
public void ChangeValue()
{
    if (!Networking.IsOwner(gameObject))
    {
        Networking.SetOwner(Networking.LocalPlayer, gameObject);
    }
    myValue = 42;
    RequestSerialization();
}
```

5. **Check sync mode:**
```csharp
// For infrequent changes (buttons, toggles)
[UdonBehaviourSyncMode(BehaviourSyncMode.Manual)]

// For continuous changes (position, rotation)
[UdonBehaviourSyncMode(BehaviourSyncMode.Continuous)]
```

---

### FieldChangeCallback が発火しない

**症状:** 同期時にプロパティのセッターが呼ばれない。

**チェックリスト:**

1. **Correct attribute syntax?**
```csharp
// ✅ Correct - nameof() points to PROPERTY
[UdonSynced, FieldChangeCallback(nameof(MyProperty))]
private int _myValue;

public int MyProperty
{
    get => _myValue;
    set
    {
        _myValue = value;
        OnValueChanged();
    }
}
```

2. **Using property everywhere locally?**
```csharp
// ❌ Wrong - Bypasses callback
_myValue = 10;

// ✅ Correct - Uses property
MyProperty = 10;
```

3. **Sync mode compatibility:**
   - Works with `Manual` sync mode
   - May have timing issues with `Continuous`

---

### オーナーシップ移転の競合状態

**問題:** 複数のプレイヤーが同時にオーナーシップを取得しようとしている。

**症状:**
- 予期しないオーナーシップの変更
- 状態の非同期
- 状態間の「フリッカリング」

**解決策:**
```csharp
// Use ownership request pattern
public override void Interact()
{
    if (Networking.IsOwner(gameObject))
    {
        // Already owner, proceed
        DoAction();
    }
    else
    {
        // Request ownership, wait for transfer
        _pendingAction = true;
        Networking.SetOwner(Networking.LocalPlayer, gameObject);
    }
}

public override void OnOwnershipTransferred(VRCPlayerApi player)
{
    if (player.isLocal && _pendingAction)
    {
        _pendingAction = false;
        DoAction();
    }
}

private void DoAction()
{
    // Modify synced variables here
    RequestSerialization();
}
```

---

### 後から参加したプレイヤーの状態の問題

**問題:** 後から参加したプレイヤーに正しい状態が表示されない。

**解決策:**
```csharp
public override void OnPlayerJoined(VRCPlayerApi player)
{
    // Only owner needs to sync
    if (Networking.IsOwner(gameObject))
    {
        RequestSerialization();
    }
}

// Or use Start() for initial state
void Start()
{
    // This runs after OnDeserialization for late joiners
    ApplyState();
}
```

---

## NetworkCallable の問題 (SDK 3.8.1+)

### "Method 'X' is not network callable"

**症状:**
```
Method 'X' cannot be called as a network event
```

**原因:**
1. `[NetworkCallable]` 属性がない
2. メソッドが `public` でない
3. メソッドが `static`、`virtual`、または `override`
4. メソッドのパラメータが 8 個を超えている

**解決策:**
```csharp
// WRONG
public void MyMethod(int value) { } // Missing attribute

private void MyMethod(int value) { } // Private

// CORRECT
[NetworkCallable]
public void MyMethod(int value) { }
```

---

### NetworkCallable のパラメータが受信されない

**症状:** パラメータがデフォルト値（0、null など）で届く

**原因:**
1. パラメータの型が同期不可
2. レートリミット超過
3. SDK バージョンの不一致

**チェックリスト:**
1. パラメータの型が同期可能か確認（int、float、string、Vector3 など）
2. レートリミットを確認（デフォルト 5/秒、最大 100/秒）
3. すべてのクライアントが SDK 3.8.1+ であることを確認

```csharp
// WRONG - VRCPlayerApi is not syncable
[NetworkCallable]
public void SetTarget(VRCPlayerApi player) { }

// CORRECT - Use player ID instead
[NetworkCallable]
public void SetTarget(int playerId) { }
```

---

### NetworkCallable のレートリミット超過

**症状:** イベントがドロップされ、すべてのクライアントに届かない

**解決策:**
```csharp
// Increase rate limit (max 100/sec)
[NetworkCallable(100)]
public void HighFrequencyEvent(float value) { }

// Or throttle on sender side
private float lastSendTime;
private const float SEND_INTERVAL = 0.1f;

public void SendIfReady(int value)
{
    if (Time.time - lastSendTime < SEND_INTERVAL) return;
    lastSendTime = Time.time;
    SendCustomNetworkEvent(NetworkEventTarget.All, nameof(MyEvent), value);
}
```

---

## Persistence の問題 (SDK 3.7.4+)

### PlayerData が読み込まれない

**症状:** `TryGet` が常に false を返し、データが空に見える

**原因:**
1. `OnPlayerRestored` より前にアクセスしている
2. キーが存在しない
3. 間違ったプレイヤー参照

**解決策:**
```csharp
private bool dataReady = false;

public override void OnPlayerRestored(VRCPlayerApi player)
{
    if (!player.isLocal) return;
    dataReady = true;

    // NOW safe to access
    if (PlayerData.TryGetInt(player, "score", out int score))
    {
        Debug.Log($"Loaded score: {score}");
    }
}

public void SaveScore(int score)
{
    if (!dataReady)
    {
        Debug.LogWarning("Data not ready!");
        return;
    }
    PlayerData.SetInt(Networking.LocalPlayer, "score", score);
}
```

---

### PlayerData が保存されない

**症状:** セッション間でデータが永続化されない

**原因:**
1. 間違ったプレイヤー（ローカルプレイヤーでない）に書き込んでいる
2. ストレージ制限（100 KB）を超えている
3. キー名が長すぎる（最大 128 文字）

**解決策:**
```csharp
// WRONG - Trying to write to other player's data
PlayerData.SetInt(otherPlayer, "score", 100); // Will fail silently

// CORRECT - Write to local player only
PlayerData.SetInt(Networking.LocalPlayer, "score", 100);

// Debug storage usage
string[] keys = PlayerData.GetKeys(Networking.LocalPlayer);
Debug.Log($"Using {keys.Length} keys");
```

---

### OnPlayerRestored が発火しない

**症状:** イベントが呼ばれず、データが読み込まれない

**原因:**
1. UdonBehaviour で VRC Enable Persistence が有効になっていない
2. ロード時にスクリプトがシーンに存在しない
3. プレイヤーデータが破損している

**解決策:**
1. Inspector で "VRC Enable Persistence" チェックボックスを確認
2. スクリプトがシーン階層内でアクティブであることを確認
3. 新しいインスタンス（保存データなし）でテスト

---

## Dynamics の問題 (SDK 3.10.0+)

### OnContactEnter が発火しない

**症状:** コンタクトイベントが一切トリガーされない

**原因:**
1. UdonBehaviour が Contact Receiver と同じ GameObject にない
2. コンテンツタイプが一致しない
3. Allow Self/Allow Others が無効

**チェックリスト:**
1. VRC Contact Receiver と UdonBehaviour が同じ GameObject にあること
2. Sender のコンテンツタイプが Receiver の許可タイプと一致すること
3. Allow Self/Allow Others の設定を確認（アバターコンタクトにのみ適用）

```csharp
// Verify receiver is on this GameObject
void Start()
{
    VRCContactReceiver receiver = GetComponent<VRCContactReceiver>();
    if (receiver == null)
    {
        Debug.LogError("No VRCContactReceiver on this GameObject!");
    }
}
```

---

### コンタクトイベントが多発する

**症状:** OnContactEnter が繰り返し呼ばれ、ログにスパムが発生

**原因:**
1. Sender に複数のコライダーがある
2. コンタクトが高速に出入りを繰り返している
3. デバウンスロジックがない

**解決策:**
```csharp
private float lastContactTime;
private const float DEBOUNCE = 0.1f;

public override void OnContactEnter(ContactEnterInfo info)
{
    if (Time.time - lastContactTime < DEBOUNCE) return;
    lastContactTime = Time.time;

    // Handle contact
}
```

---

### PhysBone のグラブが動作しない

**症状:** PhysBone をグラブできず、イベントも発火しない

**原因:**
1. VRC Phys Bone コンポーネントでグラブが無効
2. プレイヤーの手がグラブポイントから遠すぎる
3. グラブ半径が小さすぎる

**解決策:**
1. VRC Phys Bone の "Allow Grabbing" を確認
2. "Grab Movement" の値を増やす
3. 異なる値でグラブ半径をテスト

---

### Contact/PhysBone の Player が Null

**症状:** アクセス時に `info.player` が null

**原因:** コンタクトがアバターからではなく、ワールドオブジェクトからのもの

**解決策:**
```csharp
public override void OnContactEnter(ContactEnterInfo info)
{
    if (info.isAvatar)
    {
        // From avatar - player is valid
        if (info.player != null && info.player.IsValid())
        {
            Debug.Log($"Contact from: {info.player.displayName}");
        }
    }
    else
    {
        // From world object - player is null
        Debug.Log("Contact from world object");
    }
}
```

---

## エディターの問題

### Inspector で UdonSharpBehaviour が UdonBehaviour として表示される

**原因:** プロキシシステムが正しく同期されていない。

**解決策:**

1. **スクリプトを再インポート:**
   - `.cs` ファイルを右クリック → Reimport

2. **強制同期:**
   - UdonBehaviour コンポーネントをクリック
   - 三点メニュー → "Refresh UdonSharp Component"

3. **解決しない場合は Unity を再起動**

---

### Prefab に変更が保存されない

**原因:** UdonSharp はプロキシシステムを使用しており、プロキシへの変更は自動保存されない。

**解決策:**
```csharp
#if UNITY_EDITOR
// In custom editor or after programmatic changes
UdonSharpEditorUtility.CopyProxyToUdon(behaviour);
EditorUtility.SetDirty(behaviour);
#endif
```

---

### "The associated script cannot be loaded"

**原因:**
1. スクリプトにコンパイルエラーがある
2. スクリプトの GUID が不一致
3. UdonSharpProgramAsset が欠落している

**解決策:**
1. すべてのコンパイルエラーを修正する
2. UdonBehaviour を削除し、UdonSharpBehaviour を再追加する
3. Console で詳細なエラーメッセージを確認する

---

## パフォーマンスの問題

### 大量の UdonBehaviour による FPS 低下

**チェックリスト:**

1. **Disable Update() when not needed:**
```csharp
// Don't do this
void Update()
{
    if (!isActive) return;
    // Processing
}

// Do this instead
public void Activate()
{
    enabled = true;
}

public void Deactivate()
{
    enabled = false;
}

void Update()
{
    // Only runs when enabled
}
```

2. **Reduce cross-script calls:**
```csharp
// Cross-script calls have ~1.5x overhead
// Use partial classes for large scripts instead
```

3. **Cache component references:**
```csharp
// ❌ Wrong - GetComponent every frame
void Update()
{
    GetComponent<Renderer>().material.color = newColor;
}

// ✅ Correct - Cache in Start()
private Renderer _renderer;

void Start()
{
    _renderer = GetComponent<Renderer>();
}

void Update()
{
    _renderer.material.color = newColor;
}
```

4. **Use spatial partitioning:**
   - Only process objects near players
   - Use trigger zones to activate/deactivate

---

### ネットワーク帯域幅の超過

**症状:**
- "Network rate limited" 警告
- すべてのプレイヤーで同期が遅延

**解決策:**

1. **Reduce sync frequency:**
```csharp
// Don't sync every frame
private float _lastSyncTime;
private const float SYNC_INTERVAL = 0.1f; // 10 times per second

void Update()
{
    if (Time.time - _lastSyncTime > SYNC_INTERVAL)
    {
        RequestSerialization();
        _lastSyncTime = Time.time;
    }
}
```

2. **Use smaller data types:**
```csharp
// byte = 1 byte, int = 4 bytes
[UdonSynced] private byte smallValue; // 0-255 range

// short = 2 bytes
[UdonSynced] private short mediumValue; // -32768 to 32767
```

3. **Use Continuous sync mode for smoothly changing values:**
```csharp
[UdonBehaviourSyncMode(BehaviourSyncMode.Continuous)]
public class SmoothSync : UdonSharpBehaviour
{
    [UdonSynced(UdonSyncMode.Smooth)] // Interpolated locally
    private Vector3 position;
}
```

---

## よくある落とし穴

### 非アクティブなオブジェクトで Start() が呼ばれない

**問題:**
```csharp
// ❌ 非アクティブ状態で配置されたGameObjectでは Start() が呼ばれない
public class BrokenGimmick : UdonSharpBehaviour
{
    private AudioSource audioSource;

    void Start()
    {
        // GameObjectが非アクティブだと、ここに到達しない！
        audioSource = GetComponent<AudioSource>();
    }

    public void PlaySound()
    {
        audioSource.Play(); // NullReferenceException!
    }
}
```

**症状:**
- ギミックが非アクティブ状態で配置されている
- アクティブ化後に NullReferenceException が発生
- 「動くはずなのに動かない」状態

**解決策:**
```csharp
// ✅ OnEnable + 初期化フラグパターン
public class RobustGimmick : UdonSharpBehaviour
{
    private AudioSource audioSource;
    private bool _initialized = false;

    void OnEnable()
    {
        Initialize();
    }

    void Start()
    {
        Initialize();
    }

    private void Initialize()
    {
        if (_initialized) return;
        _initialized = true;

        audioSource = GetComponent<AudioSource>();
    }

    public void PlaySound()
    {
        Initialize(); // 外部から呼ばれる可能性に備える
        if (audioSource != null)
        {
            audioSource.Play();
        }
    }
}
```

**発生するケース:**
- ギミックがパフォーマンス最適化のため非アクティブで配置されている
- 条件付きで表示されるUIやオブジェクト
- プールされたオブジェクト（Object Pooling）
- トリガーで有効化されるギミック

---

### フィールド初期化子が機能しない

**問題:**
```csharp
// This doesn't work as expected
public int maxHealth = 100; // Serialized value from Inspector wins
```

**解決策:**
```csharp
// Use Start() or explicit initialization
private int _maxHealth;

void Start()
{
    if (_maxHealth == 0)
    {
        _maxHealth = 100;
    }
}
```

---

### GetComponent が UdonSharpBehaviour ではなくプロキシを返す

**問題:**
```csharp
// Returns UdonBehaviour, not your type
var myScript = other.GetComponent<MyScript>();
```

**解決策（ランタイム）:**
```csharp
// Cast works at runtime in VRChat
var myScript = (MyScript)other.GetComponent(typeof(UdonBehaviour));
```

**解決策（エディター）:**
```csharp
#if UNITY_EDITOR
var myScript = other.GetUdonSharpComponent<MyScript>();
#else
var myScript = (MyScript)other.GetComponent(typeof(UdonBehaviour));
#endif
```

---

### 構造体の変更が保持されない

**問題:**
```csharp
transform.position.x = 5; // Doesn't work!
```

**解決策:**
```csharp
// Assign full struct
Vector3 pos = transform.position;
pos.x = 5;
transform.position = pos;
```

---

### SendCustomEventDelayedSeconds をキャンセルできない

**問題:** 遅延イベントをキャンセルする組み込みの方法がない。

**解決策:**
```csharp
private bool _shouldExecute = true;

public void ScheduleAction()
{
    _shouldExecute = true;
    SendCustomEventDelayedSeconds(nameof(DelayedAction), 5f);
}

public void CancelAction()
{
    _shouldExecute = false;
}

public void DelayedAction()
{
    if (!_shouldExecute) return;
    // Do action
}
```

---

### VRCPlayerApi が無効になる

**問題:** `VRCPlayerApi` の参照を保持しているが、プレイヤーが退出した。

**解決策:**
```csharp
// ❌ Wrong - Storing reference
private VRCPlayerApi _targetPlayer;

// ✅ Correct - Store ID, get player when needed
private int _targetPlayerId = -1;

public void SetTarget(VRCPlayerApi player)
{
    _targetPlayerId = player.playerId;
}

public VRCPlayerApi GetTarget()
{
    if (_targetPlayerId < 0) return null;
    
    VRCPlayerApi player = VRCPlayerApi.GetPlayerById(_targetPlayerId);
    if (player == null || !player.IsValid())
    {
        _targetPlayerId = -1;
        return null;
    }
    return player;
}
```

---

## デバッグ技法

### ログ出力のベストプラクティス

```csharp
// Use consistent format
private void Log(string message)
{
    Debug.Log($"[{GetType().Name}:{gameObject.name}] {message}");
}

// Conditional logging
[SerializeField] private bool _debugMode = false;

private void LogDebug(string message)
{
    if (_debugMode)
    {
        Debug.Log($"[DEBUG:{gameObject.name}] {message}");
    }
}
```

### 状態の可視化

```csharp
// Show state in world using TextMeshPro
public TextMeshProUGUI debugText;

void Update()
{
    if (debugText != null)
    {
        debugText.text = $"State: {_currentState}\n" +
                        $"Owner: {Networking.GetOwner(gameObject)?.displayName}\n" +
                        $"IsLocal: {Networking.IsOwner(gameObject)}";
    }
}
```

### ネットワークデバッグ

```csharp
public override void OnPreSerialization()
{
    LogDebug($"Sending: value={_syncedValue}");
}

public override void OnDeserialization()
{
    LogDebug($"Received: value={_syncedValue}");
}

public override void OnOwnershipTransferred(VRCPlayerApi player)
{
    LogDebug($"Ownership → {player.displayName}");
}
```

---

## クイックリファレンス: エラー → 解決策

| エラー | 応急処置 |
|-------|-----------|
| "does not support X" | Check constraints.md for alternative |
| NullReferenceException | Add null checks, validate Inspector refs |
| Method not found | Make method public, remove parameters |
| Variables not syncing | SetOwner → change → RequestSerialization |
| FieldChangeCallback silent | Use property setter locally, check nameof() |
| Heap out of memory | Reuse arrays, avoid string concat in loops |
| Proxy issues | Reimport script, refresh component |
| Low FPS | Disable unused Update(), cache components |
| **NetworkCallable not working** | Add `[NetworkCallable]`, make public |
| **PlayerData empty** | Wait for `OnPlayerRestored` first |
| **OnContactEnter not firing** | UdonBehaviour must be on same GameObject |
| **Contact player is null** | Check `info.isAvatar` before accessing |

---

## リソース

- [Official UdonSharp Docs](https://udonsharp.docs.vrchat.com/)
- [VRChat Creator Docs](https://creators.vrchat.com/worlds/udon/)
- [UdonSharp GitHub Issues](https://github.com/vrchat-community/UdonSharp/issues)
- [VRChat Forums](https://ask.vrchat.com/) - Q&A、解決策
- [VRChat Canny](https://feedback.vrchat.com/) - バグ報告、既知の問題

---

## 未知のエラー調査手順

このドキュメントでカバーされていないエラーに遭遇した場合の調査手順：

### Step 1: 公式ドキュメント検索 (WebSearch)

```
WebSearch: "エラーメッセージやキーワード site:creators.vrchat.com"
```

### Step 2: VRChat Forums 検索 (WebSearch)

```
WebSearch:
  query: "エラーメッセージ site:ask.vrchat.com"
  allowed_domains: ["ask.vrchat.com"]
```

コミュニティで同じ問題に遭遇した人の解決策を探す。

### Step 3: Canny (既知のバグ) 検索

```
WebSearch:
  query: "エラーメッセージ site:feedback.vrchat.com"
  allowed_domains: ["feedback.vrchat.com"]
```

VRChat公式が認識しているバグかどうか、ワークアラウンドがあるか確認。

### Step 4: GitHub Issues 検索

```
WebSearch:
  query: "エラーメッセージ site:github.com/vrchat-community/UdonSharp"
  allowed_domains: ["github.com"]
```

UdonSharp固有のバグや修正状況を確認。

### 検索のコツ

| テクニック | 例 |
|------------|-----|
| 完全一致 | `"The type or namespace could not be found"` |
| SDKバージョン指定 | `SDK 3.10 error` |
| 解決済みフィルタ | `solved` または Cannyのステータス確認 |
| 日付フィルタ | 最新の情報を優先（古い解決策は動かないことも）|
