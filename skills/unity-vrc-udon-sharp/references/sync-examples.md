# 同期パターン例

同期ギミック実践パターン集。
パターン選択の判断基準は `../rules/udonsharp-sync-selection.md` の Decision Tree を参照。

---

## パターン 1: 同期なし (ローカルのみ)

**判断基準**: 他プレイヤーに影響しない操作。`[UdonSynced]` 不要。

```csharp
// LocalCounter: ローカルカウンター (synced 変数 0, 0 bytes)
[UdonBehaviourSyncMode(BehaviourSyncMode.Manual)]
public class LocalCounter : UdonSharpBehaviour
{
    [SerializeField] Text CounterText;
    int buttonCount; // ローカルのみ、同期不要

    public override void Interact()
    {
        ++buttonCount;
        CounterText.text = buttonCount.ToString();
    }
}
```

**適用場面**:
- 個人設定 (音量、表示切替)
- ローカルエフェクト (銃の発射パーティクル)
- プレイヤー個人のUI表示

---

## パターン 2: イベントのみ (synced 変数なし)

**判断基準**: 他プレイヤーに見えるが、Late Joiner に状態共有が不要。

### 2a. 全員でエフェクト再生

```csharp
// HitTarget: ターゲットヒット (synced 変数 0, 0 bytes)
// SendCustomNetworkEvent(All) で全員に一時的なアクションを実行
[UdonBehaviourSyncMode(BehaviourSyncMode.Manual)]
public class HitTarget : UdonSharpBehaviour
{
    public void OnParticleCollision(GameObject other)
    {
        if (!Utilities.IsValid(other)) return;
        if (!other.GetComponent<ShootGun>()) return;
        if (Networking.LocalPlayer != Networking.GetOwner(other)) return;

        // 全員にヒット処理を通知
        SendCustomNetworkEvent(NetworkEventTarget.All, "Hit");
    }

    public void Hit()
    {
        if (!gameObject.activeSelf) return;
        gameObject.SetActive(false);
        SendCustomEventDelayedSeconds("Respawn", 5.0f);
    }

    public void Respawn()
    {
        gameObject.SetActive(true);
    }
}
```

**注意**: Late Joiner はヒット済みかどうかを知らない。一時的なエフェクトにのみ使用。

### 2b. Owner 委譲パターン

```csharp
// VoteYesButton: 非Owner → Owner にイベント送信
// ボタン側は synced 変数を持たない
[UdonBehaviourSyncMode(BehaviourSyncMode.Manual)]
public class VoteYesButton : UdonSharpBehaviour
{
    [SerializeField] VoteSystemCore voteSystemCore;
    [SerializeField] AudioSource audioSource;

    public override void Interact()
    {
        if (voteSystemCore.voted) return;

        // Owner に投票を委譲 (Owner のみが synced 変数を変更)
        voteSystemCore.SendCustomNetworkEvent(
            NetworkEventTarget.Owner, "VoteToYes");
        voteSystemCore.voted = true;
        audioSource.PlayOneShot(audioSource.clip);
    }
}
```

**ポイント**: voted はローカルフラグ (二重投票防止)。同期データは VoteSystemCore 側に集約。

### 2c. Owner のみ状態管理 + 全員イベント

```csharp
// EventOnlyLock: Owner が判定 → 全員に broadcast (synced 変数 0, 0 bytes)
// Late Joiner は開錠状態を知らない (一時的なギミック向き)
[UdonBehaviourSyncMode(BehaviourSyncMode.Manual)]
public class EventOnlyLock : UdonSharpBehaviour
{
    [SerializeField] GameObject KeyObject;

    public void OnTriggerEnter(Collider other)
    {
        if (Networking.LocalPlayer != Networking.GetOwner(gameObject)) return;
        if (other.gameObject != KeyObject) return;

        SendCustomNetworkEvent(NetworkEventTarget.All, "Unlock");
    }

    public void Unlock()
    {
        gameObject.SetActive(false);
    }
}
```

**EventOnlyLock vs SyncedLock の違い**:

| | EventOnlyLock | SyncedLock |
|---|-----------|-------------|
| synced 変数 | 0 (0B) | `bool` 1個 (1B) |
| Late Joiner | 状態不明 | 正しい状態を受信 |
| 用途 | 一時的な演出 | 永続的なギミック |

---

## パターン 3: 同期変数 (Late Joiner 対応)

**判断基準**: 途中参加者が現在の状態を受け取る必要がある。

### 3a. 最小状態 (1-2 変数)

```csharp
// SyncedCounter: synced int 1個 (4 bytes)
// 非Owner → Owner にイベント送信 → Owner が synced 変数更新
[UdonBehaviourSyncMode(BehaviourSyncMode.Manual)]
public class SyncedCounter : UdonSharpBehaviour
{
    [SerializeField] Text CounterText;
    [UdonSynced] int SyncedButtonCount; // 唯一の synced 変数

    void Start() => ShowCount();

    public override void Interact()
    {
        // 非Owner は Owner に委譲
        SendCustomNetworkEvent(NetworkEventTarget.Owner, "AddCount");
    }

    public void AddCount() // Owner のみ実行
    {
        ++SyncedButtonCount;
        RequestSerialization();
        ShowCount();
    }

    public override void OnDeserialization() => ShowCount();

    void ShowCount()
    {
        CounterText.text = SyncedButtonCount.ToString();
    }
}
```

```csharp
// SyncedLock: synced bool 1個 (1 byte)
// EventOnlyLock と同じ鍵ギミックだが、Late Joiner 対応
[UdonBehaviourSyncMode(BehaviourSyncMode.Manual)]
public class SyncedLock : UdonSharpBehaviour
{
    [SerializeField] GameObject KeyObject;
    [SerializeField] GameObject DoorObject;
    [UdonSynced] bool SyncedIsUnlocked; // 唯一の synced 変数

    void Start()
    {
        // Late Joiner 対応: 少し待ってから同期済み状態を反映
        SendCustomEventDelayedSeconds("RefreshDoor", 5.0f);
    }

    public void RefreshDoor()
    {
        if (SyncedIsUnlocked) Unlock();
    }

    public void OnTriggerEnter(Collider other)
    {
        if (SyncedIsUnlocked) return;
        if (Networking.LocalPlayer != Networking.GetOwner(gameObject)) return;
        if (other.gameObject != KeyObject) return;

        SendCustomNetworkEvent(NetworkEventTarget.All, "Unlock");
        SyncedIsUnlocked = true;
        RequestSerialization();
    }

    public void Unlock()
    {
        DoorObject.SetActive(false);
    }
}
```

### 3b. ゲーム状態機械

```csharp
// ShootingGameCore: 4つの synced 変数でゲーム全体を管理
[UdonBehaviourSyncMode(BehaviourSyncMode.Manual)]
public class ShootingGameCore : UdonSharpBehaviour
{
    // --- synced 変数 (合計 ~38 bytes) ---
    [UdonSynced] public bool SyncedInGame;              // 1B: ゲーム進行中
    [UdonSynced] public bool SyncedInBattle;            // 1B: バトル中
    [UdonSynced] public string SyncedHighScorePlayerName; // ~32B: ハイスコア者名
    [UdonSynced] public int SyncedHighScore;            // 4B: ハイスコア

    // --- ローカル変数 (同期しない) ---
    int score;           // 各プレイヤーのローカルスコア
    float GameLength;    // 定数 (同期不要)
    float startGameTime; // ローカル計算用
    bool lateJoined;     // ローカルフラグ
    // ...
}
```

**設計ポイント**:
- `score` はローカル (各プレイヤー個別) → 同期不要
- `GameLength` は定数 → 同期不要
- `startGameTime` は `Time.time` からローカル計算 → 同期不要
- ハイスコアのみ永続的な共有状態 → synced

### 3c. 集計/投票パターン

```csharp
// VoteSystemCore: 投票集計 (9 bytes)
[UdonBehaviourSyncMode(BehaviourSyncMode.Manual)]
public class VoteSystemCore : UdonSharpBehaviour
{
    // --- synced 変数 (合計 9 bytes) ---
    [UdonSynced] int SyncedYesCount;    // 4B
    [UdonSynced] int SyncedNoCount;     // 4B
    [UdonSynced] bool SyncedOpenResult; // 1B

    // --- ローカル変数 ---
    public bool voted; // 二重投票防止 (ローカル、同期不要)

    public void VoteToYes() // Owner のみ実行
    {
        ++SyncedYesCount;
        RequestSerialization();
        RefreshCount();
    }

    public override void OnDeserialization()
    {
        RefreshCount(); // 全員: 受信した状態を表示に反映
    }
}
```

---

## パターン 4: FieldChangeCallback で複数値管理

```csharp
// DualCounterSync: FieldChangeCallback で変更を個別検知 (8 bytes)
[UdonBehaviourSyncMode(BehaviourSyncMode.Manual)]
public class DualCounterSync : UdonSharpBehaviour
{
    [SerializeField] Text InteractCountText;
    [SerializeField] Text TriggerEnterCountText;

    [UdonSynced][FieldChangeCallback(nameof(InteractCount))]
    int _interactCount;     // 4B

    [UdonSynced][FieldChangeCallback(nameof(TriggerEnterCount))]
    int _triggerEnterCount; // 4B

    public int InteractCount
    {
        get => _interactCount;
        set { _interactCount = value; ShowInteractCount(); }
    }

    public int TriggerEnterCount
    {
        get => _triggerEnterCount;
        set { _triggerEnterCount = value; ShowTriggerEnterCount(); }
    }
}
```

**OnDeserialization vs FieldChangeCallback**:

| 方式 | 利点 | 欠点 |
|------|------|------|
| `OnDeserialization()` | シンプル、全体更新 | どの変数が変わったか不明 |
| `FieldChangeCallback` | 個別変数の変更を検知 | プロパティ定義が必要 |

**使い分け**: 変数 1-2個 → OnDeserialization で十分。3個以上で個別反応が必要 → FieldChangeCallback。

---

## パターン比較表

| パターン | synced 変数 | バイト数 | Late Joiner | 適用場面 |
|---------|------------|---------|-------------|---------|
| 1. 同期なし | 0 | 0 | N/A | 個人エフェクト、ローカルUI |
| 2. イベントのみ | 0 | 0 | 状態不明 | 一時的アクション、エフェクト |
| 3a. 最小状態 | 1-2 | 1-4 | 対応 | カウンター、トグル |
| 3b. ゲーム状態 | 3-5 | ~38 | 対応 | ゲーム進行管理 |
| 3c. 集計 | 2-3 | ~9 | 対応 | 投票、スコア集計 |
| 4. FieldChange | 2+ | 8+ | 対応 | 複数値の個別検知 |

---

## データバジェットリファレンス (パターン別参考値)

以下は上記パターンの synced データ量を一覧にした参考値。ワールド設計時のデータ予算見積もりに使用。

| パターン | 用途例 | synced 変数 | 型 | Bytes |
|---------|--------|------------|-----|-------|
| No Sync (Pattern 1) | ローカルカウンター | 0 | - | 0 |
| Events Only (Pattern 2a) | 全員エフェクト再生 | 0 | - | 0 |
| Events Only (Pattern 2c) | 一時的なロック解除 | 0 | - | 0 |
| 最小状態 (Pattern 3a) | カウンター | 1 | int | 4 |
| 最小状態 (Pattern 3a) | ロック (Late Joiner対応) | 1 | bool | 1 |
| FieldChange (Pattern 4) | 複数値管理 | 2 | int x2 | 8 |
| 集計 (Pattern 3c) | 投票システム | 3 | int x2 + bool | 9 |
| ゲーム状態 (Pattern 3b) | シューティング管理 | 4 | bool x2 + string + int | ~38 |

> **目安**: 小〜中規模のワールドでは、全 behaviour 合計で **100 bytes 未満** に収まるケースがほとんど。
