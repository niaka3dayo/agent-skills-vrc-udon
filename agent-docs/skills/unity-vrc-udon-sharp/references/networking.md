# UdonSharp ネットワーキングリファレンス

UdonSharp におけるネットワーキングと同期の包括的ガイド。

**対応SDKバージョン**: 3.7.1 - 3.10.1 (2026年2月時点)

> **Warning**: Networking in Udon is a work in progress and can be fragile. Keep implementations simple and test thoroughly with multiple players.
>
> **Best Practice**: 「同期のコツは、同期しないこと」— The key to sync is NOT to sync. Minimize synced data and use local calculation where possible.
>
> **SDK 3.8.1+ New Feature**: `[NetworkCallable]` 属性により、**パラメータ付きネットワークイベント**が利用可能になりました。詳細は [Network Events with Parameters](#network-events-with-parameters-sdk-381) を参照。

## 同期メソッド (BehaviourSyncMode)

VRChat が提供する3つの同期モード。`UdonBehaviourSyncMode` 属性で指定する:

```csharp
using UdonSharp;
using UnityEngine;
using VRC.SDKBase;

[UdonBehaviourSyncMode(BehaviourSyncMode.Manual)] // Specify sync mode
public class MySyncedScript : UdonSharpBehaviour
{
    // ...
}
```

### Continuous (連続同期)

約 **10Hz** (毎秒10回) での自動同期。

**特徴:**
- Auto-transmits synced variables without calling `RequestSerialization()`
- Data limit: approximately **200 bytes** per UdonBehaviour
- Best for: Positions, rotations, continuously changing values

```csharp
[UdonBehaviourSyncMode(BehaviourSyncMode.Continuous)]
public class ContinuousSyncExample : UdonSharpBehaviour
{
    [UdonSynced] public Vector3 position;    // 12 bytes
    [UdonSynced] public Quaternion rotation; // 16 bytes
    [UdonSynced] public float speed;         // 4 bytes
    // Total: 32 bytes (within 200 byte limit)

    void Update()
    {
        if (Networking.IsOwner(gameObject))
        {
            position = transform.position;
            rotation = transform.rotation;
            // No RequestSerialization() needed!
        }
        else
        {
            // Apply synced values
            transform.position = position;
            transform.rotation = rotation;
        }
    }
}
```

**制限事項:**
- データ容量が限定的 (~200 bytes)
- 常時送信によるネットワークオーバーヘッドが高い
- 大規模データや低頻度更新には不向き

### Manual (手動同期)

`RequestSerialization()` 呼び出しによる明示的同期。

**特徴:**
- Only syncs when `RequestSerialization()` is called
- Data limit: **65KB → 280KB** (see release notes for details)
- Best for: Game state, scores, settings, infrequent updates

```csharp
[UdonBehaviourSyncMode(BehaviourSyncMode.Manual)]
public class ManualSyncExample : UdonSharpBehaviour
{
    [UdonSynced] public int score;
    [UdonSynced] public int gameState; // Use int/enum for multiple flags
    [UdonSynced] public string playerName;

    public void UpdateScore(int newScore)
    {
        if (!Networking.IsOwner(gameObject))
        {
            Networking.SetOwner(Networking.LocalPlayer, gameObject);
        }

        score = newScore;
        RequestSerialization(); // Explicit sync required!
    }
}
```

**利点:**
- 同期タイミングの完全な制御
- はるかに大きいデータ容量
- 低頻度更新でのネットワークオーバーヘッドが低い

### None (変数同期なし)

変数同期を完全に無効化。通信にはネットワークイベントを使用。

**特徴:**
- No synced variables supported (`[UdonSynced]` will error)
- Must use `SendCustomNetworkEvent()` for communication
- Best for: Local-only logic, event-driven communication, reducing network overhead

```csharp
[UdonBehaviourSyncMode(BehaviourSyncMode.NoVariableSync)]
public class NoSyncExample : UdonSharpBehaviour
{
    // Cannot use [UdonSynced] with NoVariableSync mode!
    // [UdonSynced] private int score; // ERROR!

    public void TriggerGlobalEvent()
    {
        SendCustomNetworkEvent(
            VRC.Udon.Common.Interfaces.NetworkEventTarget.All,
            nameof(OnGlobalEvent)
        );
    }

    public void OnGlobalEvent()
    {
        // All players execute this
        Debug.Log("Event received!");
    }
}
```

**NoVariableSync の使いどころ:**
- 純粋なイベントベースのシステム (ボタン、トリガー)
- 状態同期ではなく通知のみが必要なオブジェクト
- 複雑なワールドでのネットワークオーバーヘッド削減

### モード選択ガイド

| モード | データサイズ | 頻度 | ユースケース |
|--------|-------------|------|-------------|
| Continuous | ~200 bytes | 高 (10Hz) | 位置/回転の追跡 |
| Manual | 280KB | オンデマンド | ゲーム状態、スコア、設定 |
| None | N/A | N/A | イベントのみの通信 |

## VRC_ObjectSync に関する警告

> **Critical**: When using `VRC_ObjectSync` component alongside `UdonBehaviour`, be aware of sync freezing!

When a physics object with `VRC_ObjectSync` stops moving (becomes stationary), the sync system stops transmitting. **This also affects coexisting UdonBehaviour synced variables!**

```csharp
// PROBLEM: Object stops → Udon sync also freezes
public class ProblematicPickup : UdonSharpBehaviour
{
    [UdonSynced] public int useCount; // May stop syncing when object is stationary!

    public override void OnPickupUseDown()
    {
        useCount++;
        RequestSerialization(); // Might not transmit if object is still!
    }
}
```

**回避策:**
1. **UdonBehaviour を分離**: VRC_ObjectSync のない別の GameObject に同期ロジックを配置
2. **ネットワークイベントを使用**: 重要な更新には `SendCustomNetworkEvent()` を使用
3. **強制的な移動**: 同期を維持するために微小な速度を適用 (非推奨)

```csharp
// SOLUTION: Separate synced logic from physics object
public class SeparatedSyncLogic : UdonSharpBehaviour
{
    // This script is on a SEPARATE GameObject without VRC_ObjectSync
    [UdonSynced] public int useCount;

    public void IncrementUse()
    {
        if (!Networking.IsOwner(gameObject))
        {
            Networking.SetOwner(Networking.LocalPlayer, gameObject);
        }
        useCount++;
        RequestSerialization(); // Now works reliably
    }
}
```

## 途中参加者 (Late Joiner) への考慮

セッション途中でプレイヤーが参加した場合、同期データの挙動が異なる:

### 同期変数 (自動)

同期変数は途中参加者に**自動的に送信**される:

```csharp
[UdonSynced] private int gameScore;     // ✅ Auto-synced to late joiners
[UdonSynced] private bool isGameActive; // ✅ Auto-synced to late joiners

// Late joiners receive current values via OnDeserialization
public override void OnDeserialization()
{
    UpdateGameDisplay();
}
```

### ネットワークイベント (手動対応が必要)

ネットワークイベントは途中参加者に**再送されない**:

```csharp
// PROBLEM: Late joiners miss this event
public void StartGame()
{
    SendCustomNetworkEvent(NetworkEventTarget.All, "OnGameStarted");
}

public void OnGameStarted()
{
    // Late joiners never receive this!
    ShowGameUI();
}
```

**解決策: 状態には同期変数を使用する**

```csharp
[UdonSynced, FieldChangeCallback(nameof(GamePhase))]
private int _gamePhase = 0;

public int GamePhase
{
    get => _gamePhase;
    set
    {
        _gamePhase = value;
        OnGamePhaseChanged(); // Called for late joiners via OnDeserialization
    }
}

private void OnGamePhaseChanged()
{
    switch (_gamePhase)
    {
        case 0: ShowLobbyUI(); break;
        case 1: ShowGameUI(); break;
        case 2: ShowResultsUI(); break;
    }
}

public void StartGame()
{
    if (!Networking.IsOwner(gameObject)) return;
    GamePhase = 1;
    RequestSerialization();
}
```

## 最適化のヒント

### 複数フラグには整数/Enum を使用

複数の bool を同期する代わりに、単一の整数にパックする:

```csharp
// BAD: Multiple synced bools
[UdonSynced] private bool hasKey;
[UdonSynced] private bool hasSword;
[UdonSynced] private bool hasShield;
[UdonSynced] private bool hasPotion;

// GOOD: Single synced integer with bit flags
[UdonSynced] private int inventory;

private const int FLAG_KEY = 1;
private const int FLAG_SWORD = 2;
private const int FLAG_SHIELD = 4;
private const int FLAG_POTION = 8;

public bool HasKey => (inventory & FLAG_KEY) != 0;
public bool HasSword => (inventory & FLAG_SWORD) != 0;

public void AddItem(int flag)
{
    inventory |= flag;
    RequestSerialization();
}
```

### 同期よりローカル計算を優先

可能な場合はローカルで計算する:

```csharp
// BAD: Syncing calculated value
[UdonSynced] private float elapsedTime;

void Update()
{
    if (Networking.IsOwner(gameObject))
    {
        elapsedTime += Time.deltaTime;
        RequestSerialization(); // Too frequent!
    }
}

// GOOD: Sync start time, calculate locally
[UdonSynced] private double startServerTime;

void Update()
{
    if (startServerTime > 0)
    {
        float elapsed = (float)(Networking.GetServerTimeInSeconds() - startServerTime);
        timerDisplay.text = elapsed.ToString("F1");
    }
}
```

## 基本概念

### オーナーシップモデル

UdonBehaviour を持つすべての GameObject にはネットワークオーナーが存在する:

- **デフォルトオーナー**: インスタンスマスター (最初に参加したプレイヤー)
- **オブジェクトごとに1オーナー**: オーナーシップはコンポーネント単位ではなく GameObject 単位
- **オーナーのみ変更可能**: 同期変数を変更できるのはオーナーのみ

```csharp
// Check if local player is owner
if (Networking.IsOwner(gameObject))
{
    // Safe to modify synced variables
}

// Get current owner
VRCPlayerApi owner = Networking.GetOwner(gameObject);
Debug.Log($"Owner: {owner.displayName}");
```

### オーナーシップの移譲

```csharp
// Request ownership for local player
Networking.SetOwner(Networking.LocalPlayer, gameObject);

// Note: Ownership transfer is not instant!
// The previous owner must acknowledge the transfer
```

**重要なタイミング問題**: `SetOwner` の後、新しいオーナーはすぐには同期変数を変更できない。旧オーナーの確認応答を待つ必要がある:

```csharp
// WRONG - May fail due to timing
Networking.SetOwner(Networking.LocalPlayer, gameObject);
syncedValue = 10; // Might not sync!
RequestSerialization();

// CORRECT - Wait for ownership confirmation
public void RequestOwnershipAndUpdate(int newValue)
{
    pendingValue = newValue;
    Networking.SetOwner(Networking.LocalPlayer, gameObject);
    // Value will be set in OnOwnershipTransferred
}

public override void OnOwnershipTransferred(VRCPlayerApi player)
{
    if (player.isLocal)
    {
        syncedValue = pendingValue;
        RequestSerialization();
    }
}
```

### オーナーシップ移譲タイミング図

```text
Player A (current owner) | Player B (requesting)
-------------------------|------------------------
                        | SetOwner(B, obj)
                        | [Cannot sync yet!]
Receives request         |
Acknowledges transfer   |
                        | OnOwnershipTransferred(B)
                        | [Now safe to sync]
                        | RequestSerialization()
```

**競合状態の警告**: 複数のプレイヤーが同時に `SetOwner` を呼び出した場合、最後に処理されたものが優先される。組み込みの競合解決機能はない。

## 同期変数

### 基本的な同期

`[UdonSynced]` 属性を使用してフィールドを同期する:

```csharp
[UdonSynced] private int score;
[UdonSynced] private float health;
[UdonSynced] private bool isActive;
[UdonSynced] private Vector3 position;
[UdonSynced] private string playerName; // Max ~50 characters!
```

### 同期モード

```csharp
// Default: Sync when changed (no interpolation)
[UdonSynced]
private int normalSync;

// Linear interpolation for continuous values
[UdonSynced(UdonSyncMode.Linear)]
private Vector3 linearPosition; // Interpolates between updates

// Smooth damped interpolation
[UdonSynced(UdonSyncMode.Smooth)]
private Quaternion smoothRotation; // Smoothly interpolates

// With FieldChangeCallback (called on value change)
[UdonSynced, FieldChangeCallback(nameof(SmoothPosition))]
private Vector3 _smoothPosition;
public Vector3 SmoothPosition
{
    get => _smoothPosition;
    set
    {
        _smoothPosition = value;
        // Handle smooth interpolation here
    }
}
```

**UdonSyncMode の値:**

| モード | 説明 | 最適な用途 |
|--------|------|-----------|
| `UdonSyncMode.None` | 補間なし (デフォルト) | 離散値、フラグ、状態 |
| `UdonSyncMode.Linear` | 更新間の線形補間 | 位置、回転、連続値 |
| `UdonSyncMode.Smooth` | スムーズな減衰補間 | カメラ、低速移動、UI要素 |

**重要:** 補間モードは受信側クライアントがネットワーク更新間で値を適用する方法にのみ影響する。同期頻度は BehaviourSyncMode (Continuous ~10Hz、Manual オンデマンド) で決定される。

### シリアライゼーションの要求

同期変数を変更した後、`RequestSerialization()` を呼び出す:

```csharp
public void IncrementScore()
{
    if (!Networking.IsOwner(gameObject))
    {
        Networking.SetOwner(Networking.LocalPlayer, gameObject);
        return; // Wait for OnOwnershipTransferred
    }

    score += 10;
    RequestSerialization(); // Broadcast to all players
}
```

### 変更の検知

`OnDeserialization` または `FieldChangeCallback` を使用:

```csharp
// Method 1: OnDeserialization
[UdonSynced] private int score;

public override void OnDeserialization()
{
    // Called when synced data is received
    UpdateScoreDisplay();
}

// Method 2: FieldChangeCallback (more granular)
[UdonSynced, FieldChangeCallback(nameof(Health))]
private float _health;

public float Health
{
    get => _health;
    set
    {
        _health = value;
        OnHealthChanged();
    }
}

private void OnHealthChanged()
{
    healthBar.value = _health;
}
```

## ネットワークイベント

### SendCustomNetworkEvent (レガシー)

全プレイヤーまたはオーナーのみにイベントを送信 (パラメータなし):

```csharp
// Send to ALL players (including self)
SendCustomNetworkEvent(VRC.Udon.Common.Interfaces.NetworkEventTarget.All, "OnButtonPressed");

// Send to OWNER only
SendCustomNetworkEvent(VRC.Udon.Common.Interfaces.NetworkEventTarget.Owner, "ProcessOwnerAction");

// The receiving method (must be public)
public void OnButtonPressed()
{
    Debug.Log("Button pressed!");
}
```

**NetworkEventTarget の選択肢**:

| ターゲット | SDK | 説明 |
|-----------|-----|------|
| `NetworkEventTarget.All` | 全バージョン | 自分を含む全プレイヤー |
| `NetworkEventTarget.Owner` | 全バージョン | オブジェクトオーナーのみ |
| `NetworkEventTarget.Others` | **3.8.1+** | 自分以外の全プレイヤー |
| `NetworkEventTarget.Self` | **3.8.1+** | 自分自身のみ（ローカル実行と同等） |

> **SDK 3.8.1+ 新ターゲット**: `NetworkEventTarget.Others` は「送信者以外全員」に送信でき、エフェクトやサウンドの重複再生を防止できます。`NetworkEventTarget.Self` はローカルのみの処理に使えます。

**制限事項 (レガシー)**:
- ネットワークイベントでパラメータを送信できない
- 特定のプレイヤーを直接ターゲットできない (Others/Self は SDK 3.8.1+ で追加)
- イベントが同期変数の更新より先に到着する場合がある (race condition!)
- イベントはキューイングされず、到着順序も保証されない

---

## パラメータ付きネットワークイベント (SDK 3.8.1+)

**SDK 3.8.1** で追加された `[NetworkCallable]` 属性により、**最大8個のパラメータ**をネットワークイベントで送信できるようになりました。

### [NetworkCallable] 属性

ネットワーク経由で呼び出し可能なメソッドには `[NetworkCallable]` 属性が必要です:

```csharp
using UdonSharp;
using UnityEngine;
using VRC.SDKBase;
using VRC.Udon.Common.Interfaces;

[UdonBehaviourSyncMode(BehaviourSyncMode.Manual)]
public class NetworkCallableExample : UdonSharpBehaviour
{
    [NetworkCallable]
    public void TakeDamage(int damage, int attackerId)
    {
        Debug.Log($"Received {damage} damage from player {attackerId}");
    }

    public void Attack(VRCPlayerApi target, int damage)
    {
        // パラメータ付きでネットワークイベントを送信
        SendCustomNetworkEvent(
            NetworkEventTarget.All,
            nameof(TakeDamage),
            damage,
            Networking.LocalPlayer.playerId
        );
    }
}
```

### [NetworkCallable] の制約

| 制約 | 詳細 |
|------|------|
| `public` 必須 | メソッドは public である必要がある |
| `[NetworkCallable]` 必須 | 属性がないとパラメータを受け取れない |
| `static` 禁止 | 静的メソッドは使用不可 |
| `virtual`/`override` 禁止 | 仮想メソッドは使用不可 |
| オーバーロード禁止 | 同名メソッドの複数定義は不可 |
| 最大8パラメータ | 9個以上のパラメータは不可 |
| Syncable型のみ | パラメータは同期可能な型に限定 |

### レート制限 (Rate Limiting)

`[NetworkCallable]` にはレート制限オプションがあります:

```csharp
// デフォルト: 5回/秒/イベント
[NetworkCallable]
public void NormalEvent(int value) { }

// カスタムレート: 100回/秒（最大）
[NetworkCallable(100)]
public void HighFrequencyEvent(float value) { }

// 低レート: 1回/秒
[NetworkCallable(1)]
public void RareBroadcast(string message) { }
```

**注意**: レート制限を超えるとイベントはドロップされます。レート制限は**イベントごと・プレイヤーごと**に適用されます。デフォルトは **5回/秒**、最大 **100回/秒** まで設定可能です。

### パラメータとして使用可能な型

`[UdonSynced]` で同期可能な型のみパラメータとして使用可能:

| 型 | サイズ | 備考 |
|------|------|-------|
| `bool` | 1 byte | |
| `byte`, `sbyte` | 1 byte | |
| `short`, `ushort` | 2 bytes | |
| `int`, `uint` | 4 bytes | |
| `long`, `ulong` | 8 bytes | |
| `float` | 4 bytes | |
| `double` | 8 bytes | |
| `string` | variable | ~50 char limit |
| `Vector2/3/4` | 8/12/16 bytes | |
| `Quaternion` | 16 bytes | |
| `Color`, `Color32` | 16/4 bytes | |
| Arrays of above | variable | |

**使用不可**: `GameObject`, `Transform`, `VRCPlayerApi`, カスタムクラス

### 実用パターン: ダメージシステム

```csharp
[UdonBehaviourSyncMode(BehaviourSyncMode.Manual)]
public class DamageSystem : UdonSharpBehaviour
{
    [UdonSynced] private int health = 100;

    [NetworkCallable]
    public void ApplyDamage(int damage, Vector3 hitPosition, int attackerId)
    {
        if (!Networking.IsOwner(gameObject))
        {
            // オーナーでない場合、オーナーに転送
            SendCustomNetworkEvent(
                NetworkEventTarget.Owner,
                nameof(ApplyDamage),
                damage, hitPosition, attackerId
            );
            return;
        }

        // オーナーのみが実際のダメージ処理
        health -= damage;
        RequestSerialization();

        // 全員にエフェクト表示
        SendCustomNetworkEvent(
            NetworkEventTarget.All,
            nameof(ShowDamageEffect),
            hitPosition
        );
    }

    [NetworkCallable]
    public void ShowDamageEffect(Vector3 position)
    {
        // パーティクルやサウンドを再生
        SpawnDamageParticle(position);
    }
}
```

### レガシー vs NetworkCallable 比較

| 機能 | レガシー | NetworkCallable (3.8.1+) |
|------|--------|--------------------------|
| パラメータ送信 | ❌ 不可 | ✅ 最大8個 |
| 属性 | 不要 | `[NetworkCallable]` 必須 |
| レート制限 | なし | 設定可能 (1-100/秒) |
| 後方互換性 | ✅ 全バージョン | SDK 3.8.1+ のみ |

### マイグレーションガイド

**Before (Legacy):**

```csharp
[UdonSynced] private int pendingDamage;
[UdonSynced] private int pendingAttackerId;

public void Attack(int damage, int attackerId)
{
    Networking.SetOwner(Networking.LocalPlayer, gameObject);
    pendingDamage = damage;
    pendingAttackerId = attackerId;
    RequestSerialization();
    SendCustomNetworkEvent(NetworkEventTarget.All, "OnAttack");
}

public void OnAttack()
{
    // pendingDamage がまだ古い値の可能性あり（race condition）
    ProcessDamage(pendingDamage, pendingAttackerId);
}
```

**After (NetworkCallable):**

```csharp
[NetworkCallable]
public void Attack(int damage, int attackerId)
{
    // パラメータが確実に渡される（race condition なし）
    ProcessDamage(damage, attackerId);
}

public void TriggerAttack(int damage)
{
    SendCustomNetworkEvent(
        NetworkEventTarget.All,
        nameof(Attack),
        damage,
        Networking.LocalPlayer.playerId
    );
}
```

### ネットワークイベントと同期変数の競合状態

**重大な問題**: ネットワークイベントの送信と同期変数の更新を同時に行うと、イベントが同期変数の更新より先に到着する場合がある:

```csharp
// PROBLEM: Event may arrive before syncedData is updated on remote clients
public void SendDataWithEvent()
{
    syncedData = "important data";
    RequestSerialization();
    SendCustomNetworkEvent(NetworkEventTarget.All, "ProcessData");
}

public void ProcessData()
{
    // syncedData might still be the OLD value here!
    Debug.Log(syncedData); // Might print old data!
}
```

**解決策: イベントの代わりに FieldChangeCallback を使用する**

```csharp
[UdonSynced, FieldChangeCallback(nameof(SyncedData))]
private string _syncedData;

public string SyncedData
{
    get => _syncedData;
    set
    {
        _syncedData = value;
        ProcessData(); // Called after data is actually updated
    }
}

public void SendData()
{
    SyncedData = "important data";
    RequestSerialization();
    // No need for network event - FieldChangeCallback handles it
}

private void ProcessData()
{
    // syncedData is guaranteed to be the new value here
    Debug.Log(_syncedData);
}
```

### 回避策: 特定プレイヤーへのターゲティング

直接的なプレイヤーターゲティングが利用できないため、同期変数を使用する:

```csharp
[UdonSynced] private int targetPlayerId;
[UdonSynced] private string message;

public void SendMessageToPlayer(VRCPlayerApi player, string msg)
{
    if (!Networking.IsOwner(gameObject))
    {
        Networking.SetOwner(Networking.LocalPlayer, gameObject);
    }

    targetPlayerId = player.playerId;
    message = msg;
    RequestSerialization();

    SendCustomNetworkEvent(NetworkEventTarget.All, "CheckMessage");
}

public void CheckMessage()
{
    if (Networking.LocalPlayer.playerId == targetPlayerId)
    {
        ProcessMessage(message);
    }
}
```

## データ制限

### 文字列長

同期文字列には固定の文字数制限はない。実用上の制限は同期バッファサイズと UTF-16 エンコーディング (1文字あたり2バイト) に依存する:
- **Continuous**: ~200 bytes per serialization
- **Manual**: ~280KB per serialization

```csharp
// Keep synced strings short to conserve sync buffer
[UdonSynced] private string status; // "ready", "waiting", etc.

// For longer data, split across multiple variables
[UdonSynced] private string data1;
[UdonSynced] private string data2;
[UdonSynced] private string data3;
```

### 帯域幅制限

VRChat はネットワークデータレートを制限している。過度な同期は "Death Runs" (データ損失) を引き起こす:

```csharp
// WRONG - Too frequent updates
void Update()
{
    position = transform.position;
    RequestSerialization(); // Every frame = bad!
}

// CORRECT - Throttle updates
private float lastSyncTime;
private const float SYNC_INTERVAL = 0.1f; // 10 times per second max

void Update()
{
    if (Time.time - lastSyncTime > SYNC_INTERVAL)
    {
        if (HasPositionChanged())
        {
            position = transform.position;
            RequestSerialization();
            lastSyncTime = Time.time;
        }
    }
}
```

## オブジェクトプーリング

動的インスタンス化はネットワーク対応していない。オブジェクトプーリングを使用する:

```csharp
public class ObjectPool : UdonSharpBehaviour
{
    public GameObject[] pooledObjects;
    [UdonSynced] private int[] objectStates; // 0 = inactive, 1 = active

    void Start()
    {
        objectStates = new int[pooledObjects.Length];
    }

    public GameObject GetObject()
    {
        if (!Networking.IsOwner(gameObject))
        {
            Networking.SetOwner(Networking.LocalPlayer, gameObject);
        }

        for (int i = 0; i < pooledObjects.Length; i++)
        {
            if (objectStates[i] == 0)
            {
                objectStates[i] = 1;
                pooledObjects[i].SetActive(true);
                RequestSerialization();
                return pooledObjects[i];
            }
        }
        return null; // Pool exhausted
    }

    public void ReturnObject(GameObject obj)
    {
        if (!Networking.IsOwner(gameObject))
        {
            Networking.SetOwner(Networking.LocalPlayer, gameObject);
        }

        for (int i = 0; i < pooledObjects.Length; i++)
        {
            if (pooledObjects[i] == obj)
            {
                objectStates[i] = 0;
                pooledObjects[i].SetActive(false);
                RequestSerialization();
                return;
            }
        }
    }

    public override void OnDeserialization()
    {
        // Sync object states for late joiners
        for (int i = 0; i < pooledObjects.Length; i++)
        {
            pooledObjects[i].SetActive(objectStates[i] == 1);
        }
    }
}
```

## プレイヤーイベント

```csharp
public override void OnPlayerJoined(VRCPlayerApi player)
{
    if (player == null || !player.IsValid()) return;

    Debug.Log($"{player.displayName} joined");

    // Sync state for new player if we're owner
    if (Networking.IsOwner(gameObject))
    {
        RequestSerialization();
    }
}

public override void OnPlayerLeft(VRCPlayerApi player)
{
    if (player == null || !player.IsValid()) return;

    Debug.Log($"{player.displayName} left");

    // Handle ownership transfer if the owner left
    // VRChat automatically assigns a new owner
}

public override void OnOwnershipTransferred(VRCPlayerApi player)
{
    if (player == null || !player.IsValid()) return;

    Debug.Log($"New owner: {player.displayName}");

    if (player.isLocal)
    {
        // We are now the owner, can modify synced variables
    }
}
```

## 共通パターン

### マスター限定アクション

```csharp
public void DoMasterAction()
{
    if (Networking.IsMaster)
    {
        // Only instance master executes this
        PerformAction();
        SendCustomNetworkEvent(NetworkEventTarget.All, "OnActionPerformed");
    }
}
```

### ローカルプレイヤーの検出

```csharp
public void OnInteract()
{
    VRCPlayerApi localPlayer = Networking.LocalPlayer;

    if (localPlayer != null)
    {
        interactingPlayerId = localPlayer.playerId;
        interactingPlayerName = localPlayer.displayName;
        RequestSerialization();
    }
}
```

### 同期タイマー

```csharp
[UdonSynced] private float gameStartTime;
[UdonSynced] private bool gameRunning;

public void StartGame()
{
    if (!Networking.IsMaster) return;

    gameStartTime = (float)Networking.GetServerTimeInSeconds();
    gameRunning = true;
    RequestSerialization();
}

void Update()
{
    if (!gameRunning) return;

    float elapsed = (float)Networking.GetServerTimeInSeconds() - gameStartTime;
    timerDisplay.text = elapsed.ToString("F1");
}
```

## ネットワーク帯域幅とスロットリング

### 帯域幅制限

> Udon scripts can send out about **11 kilobytes** per second.
> — [VRChat Creator Docs](https://creators.vrchat.com/worlds/udon/networking/network-details)

この制限を超えると "Death Runs" と呼ばれる同期遅延が発生する。特に以下の場合に問題になる:
- 複数のUI要素が高速に操作される場合
- 多数の同期変数が同時に更新される場合
- プレイヤーが操作を連打する場合

### ネットワーク混雑の検出

`Networking.IsClogged` を使用してネットワークキューのバックアップを確認する:

```csharp
if (Networking.IsClogged)
{
    // Network is congested - defer synchronization
    SendCustomEventDelayedSeconds(nameof(RetrySync), 1.0f);
    return;
}
RequestSerialization();
```

### RequestSerialization スロットリングパターン

高頻度更新の場合、`RequestSerialization()` をインターバル制御でラップする:

**主要原則:**
1. 同期間の最小間隔を強制 (例: 1秒)
2. ネットワーク混雑時に自動リトライ
3. 重複する遅延イベントのスケジューリングを防止
4. 常に最新の状態を同期 (中間状態ではなく)

```csharp
private const float SyncInterval = 1.0f;
private const float RetryInterval = 1.0f;
private bool isPendingSync = false;
private double lastSyncTime = double.MinValue;

/// <summary>
/// Call this instead of RequestSerialization() for throttled sync.
/// </summary>
private void RequestSync()
{
    if (isPendingSync) return;
    if (!Networking.IsOwner(gameObject)) return;

    double now = Time.timeAsDouble;

    if (now >= lastSyncTime + SyncInterval)
    {
        ExecuteSync();
    }
    else
    {
        float delay = (float)(lastSyncTime + SyncInterval - now) + 0.001f;
        SendCustomEventDelayedSeconds(nameof(ExecuteSync), delay);
        isPendingSync = true;
    }
}

public void ExecuteSync()
{
    isPendingSync = false;
    if (!Networking.IsOwner(gameObject)) return;

    if (Networking.IsClogged)
    {
        SendCustomEventDelayedSeconds(nameof(ExecuteSync), RetryInterval);
        isPendingSync = true;
        return;
    }

    RequestSerialization();
    lastSyncTime = Time.timeAsDouble;
}
```

**利点:**
- 高速な操作によるネットワーク過負荷を防止
- 混雑時に自動リトライ
- 常に最新の状態を同期
- 遅延イベントの重複なし

**トレードオフ:**
- 最大 `SyncInterval` 秒のレイテンシ
- 個々の同期リクエストがマージされる可能性あり (状態の同期であり、イベントではない)

Reference template: `assets/templates/ThrottledSync.cs`

### 定期同期パターン

制御されたインターバルでの連続同期:

```csharp
private const float PeriodicSyncInterval = 10.0f;
private bool isPendingPeriodicSync = false;
private bool loopNeeded = false;

private void StartPeriodicSync()
{
    if (!Networking.IsOwner(gameObject)) return;
    loopNeeded = true;
    RequestPeriodicSync();
}

private void StopPeriodicSync()
{
    loopNeeded = false;
}

private void RequestPeriodicSync()
{
    if (isPendingPeriodicSync) return;
    if (!Networking.IsOwner(gameObject)) return;

    SendCustomEventDelayedSeconds(nameof(ExecutePeriodicSync), PeriodicSyncInterval);
    isPendingPeriodicSync = true;
}

public void ExecutePeriodicSync()
{
    isPendingPeriodicSync = false;
    if (!Networking.IsOwner(gameObject)) return;

    RequestSync(); // Uses throttled sync

    if (loopNeeded)
    {
        RequestPeriodicSync();
    }
}
```

## データサイズ最適化

### 同期オーバーヘッド

各同期変数にはヘッダーオーバーヘッド (変数を識別するメタデータ) がかかる。つまり:

| アプローチ | 変数数 | 同期データ |
|-----------|--------|-----------|
| 8 separate `byte` | 8 | ~16 bytes (8 data + 8 overhead) |
| 1 packed `ulong` | 1 | ~9 bytes (8 data + 1 overhead) |

**ポイント**: 変数数を減らすことは、データサイズを減らすよりも効果的な場合が多い。

### ビットパッキング

複数の小さな値をより少ない変数にパックする:

**ビット数と最大値の参考:**

| ビット数 | 最大値 | 一般的な用途 |
|---------|--------|-------------|
| 1 | 1 | ブールフラグ |
| 2 | 3 | 4状態 enum |
| 3 | 7 | サイコロ (d6)、小さなインデックス |
| 4 | 15 | 16進数字、小さなカウンター |
| 5 | 31 | 日 (月の中の) |
| 6 | 63 | 分、秒 |
| 7 | 127 | ASCII 文字 |
| 8 | 255 | フルバイト |

**Example: Pack 8 bools into 1 byte (87.5% reduction)**

```csharp
// Pack
byte packed = 0;
if (flag0) packed |= 1;      // bit 0
if (flag1) packed |= 2;      // bit 1
if (flag2) packed |= 4;      // bit 2
if (flag3) packed |= 8;      // bit 3
if (flag4) packed |= 16;     // bit 4
if (flag5) packed |= 32;     // bit 5
if (flag6) packed |= 64;     // bit 6
if (flag7) packed |= 128;    // bit 7

// Unpack
bool flag0 = (packed & 1) != 0;
bool flag1 = (packed & 2) != 0;
bool flag2 = (packed & 4) != 0;
// ...
```

**Example: Pack array of 3-bit values into ulong**

```csharp
// Pack 20 values (0-7 each) into single ulong (60 bits used)
public void PackValues(byte[] values, out ulong packed)
{
    packed = 0;
    for (int i = 0; i < 20 && i < values.Length; i++)
    {
        ulong threeBits = (ulong)(values[i] & 0b111);
        packed |= threeBits << (i * 3);
    }
}

// Unpack
public void UnpackValues(ulong packed, byte[] values)
{
    for (int i = 0; i < 20 && i < values.Length; i++)
    {
        values[i] = (byte)((packed >> (i * 3)) & 0b111);
    }
}
```

Reference template: `assets/templates/BitPacking.cs`

### レンジシフト

限定的な範囲の値の場合、シフトしてビット数を最小化する:

```csharp
// Value range: 200-210 (requires 8 bits as-is)
// Shifted range: 0-10 (requires only 4 bits)

// Pack
byte packed = (byte)(value - 200);

// Unpack
int value = packed + 200;
```

**符号付き値**: パッキング前にオフセットを加えて符号なしに変換する:

```csharp
// Range: -50 to +50 (requires signed handling)
// Shifted: 0 to 100 (7 bits, unsigned)

byte packed = (byte)(signedValue + 50);
int signedValue = packed - 50;
```

### ビットパッキングの使いどころ

| シナリオ | 推奨 |
|---------|------|
| 変数が少なく、フルレンジ使用 | パッキング不要 - オーバーヘッドに見合わない |
| 多数の bool | bytes/ints にパック |
| 小さな整数の配列 | ulong 配列にパック |
| 帯域幅が重要 | 積極的にパック |
| Late Joiner の大きな状態同期 | パッキングを検討 |

**注意事項:**
- `FieldChangeCallback` doesn't work directly with packed variables
- Adds complexity - only use when bandwidth is a concern
- Call pack before `RequestSerialization()`, unpack in `OnDeserialization()`

## ネットワーク問題のデバッグ

1. **Check Ownership**: `Debug.Log($"Owner: {Networking.GetOwner(gameObject).displayName}")`
2. **Verify Sync**: Log before and after `RequestSerialization()`
3. **Test Late Join**: Have player join mid-game to verify `OnDeserialization`
4. **Monitor Bandwidth**: Keep sync frequency low (max 10/sec per object)
5. **Test Edge Cases**: Player leaving while owning objects, rapid ownership transfers
6. **Check Congestion**: Log `Networking.IsClogged` to detect network issues
7. **Measure Data Size**: Use `OnPostSerialization(SerializationResult result)` to check `result.byteCount`

## Owner-Centric Architecture (推奨設計)

マルチプレイヤーゲームでは**「Owner のみが状態を変更し、他は結果を受信する」**設計を推奨。

### 設計原則

1. **1つの GameManager** が全ゲーム状態の synced 変数を持つ (Manual sync)
2. **Owner のみ** が `Update()` でゲームロジック実行
3. **非 Owner** は `OnDeserialization()` で表示更新のみ
4. **UI 操作**は `SendCustomNetworkEvent(Owner)` で Owner に通知

### コード例: Owner-Centric GameManager

```csharp
[UdonBehaviourSyncMode(BehaviourSyncMode.Manual)]
public class GameManager : UdonSharpBehaviour
{
    [UdonSynced] private int[] boardState;
    [UdonSynced] private int currentTurn;
    [UdonSynced] private int gamePhase; // 0=Lobby, 1=Playing, 2=Result

    // --- UI からの入力 (全クライアントで発火) ---
    public void OnCellClicked(int cellIndex)
    {
        // Owner に委譲 (自分が Owner でも動く)
        SendCustomNetworkEvent(
            NetworkEventTarget.Owner,
            nameof(OwnerProcessMove),
            cellIndex,
            Networking.LocalPlayer.playerId
        );
    }

    // --- Owner のみ実行 ---
    [NetworkCallable]
    public void OwnerProcessMove(int cellIndex, int playerId)
    {
        if (gamePhase != 1) return;           // ゲーム中でなければ無視
        if (playerId != GetCurrentPlayerId()) return; // 手番でなければ無視
        if (boardState[cellIndex] != 0) return;       // 既に埋まっている

        boardState[cellIndex] = currentTurn;
        currentTurn = (currentTurn % 2) + 1;
        RequestSerialization();
    }

    // --- 全クライアント: 表示更新 ---
    public override void OnDeserialization()
    {
        UpdateBoardDisplay();
        UpdateTurnIndicator();
    }

    private int GetCurrentPlayerId() { /* ... */ return 0; }
    private void UpdateBoardDisplay() { /* boardState を UI に反映 */ }
    private void UpdateTurnIndicator() { /* currentTurn を表示 */ }
}
```

**ポイント:**
- UI コールバック → `SendCustomNetworkEvent(Owner)` → Owner が検証・変更 → `RequestSerialization()` → 全員 `OnDeserialization()`
- 非 Owner がボタンを押しても動作する（Owner に委譲されるため）
- 不正な操作は Owner 側で弾ける（サーバー権限に近い設計）

## 同期データサイズ最適化

VRChat の送信帯域は約 **11KB/sec**。大きな同期データは深刻なラグを引き起こす。

### データサイズ見積もり

| データ | サイズ | 同期遅延 (11KB/sec) |
|--------|--------|---------------------|
| `int[40]` | 160 bytes | 即時 |
| `int[400]` | 1,600 bytes | ~0.15 sec |
| `int[4000]` | 16,000 bytes | ~1.5 sec (NG) |
| `byte[100]` | 100 bytes | 即時 |

### 最適化テクニック

#### 1. 小さい型を使う

```csharp
// NG: 値が 0-255 なのに int (4 bytes) を使用
[UdonSynced] private int[] bottleColors; // 40要素 = 160 bytes

// OK: byte (1 byte) で十分
[UdonSynced] private byte[] bottleColors; // 40要素 = 40 bytes (75%削減)
```

#### 2. ビットパッキング (大量の小さな値)

色ID (0-7) は 3bit。1 byte に 2色格納可能。詳細は Data Size Optimization セクション参照。

```csharp
// 40色 × 3bit = 120bit = 15 bytes (int[40] の 160 bytes → 93%削減)
[UdonSynced] private byte[] packedColors; // 15 bytes で40色格納

private byte GetColor(int index)
{
    int byteIdx = (index * 3) / 8;
    int bitOffset = (index * 3) % 8;
    int raw = packedColors[byteIdx] | (packedColors[byteIdx + 1] << 8);
    return (byte)((raw >> bitOffset) & 0x07);
}
```

#### 3. 差分同期 (変更部分のみ送信)

全状態ではなく変更部分のみ同期。初回は全状態、以降は差分のみ。

```csharp
// 全状態を毎回同期する代わりに、最新の操作のみ同期
[UdonSynced] private int lastMoveFrom;
[UdonSynced] private int lastMoveTo;
[UdonSynced] private int moveCounter; // 変更検知用

public override void OnDeserialization()
{
    // 受信側でローカルに操作を再適用
    ApplyMove(lastMoveFrom, lastMoveTo);
}
```

**注意:** 差分同期は Late Joiner に対応できない。初回接続時の全状態復元が必要な場合は、synced 配列で全状態も持つ。
