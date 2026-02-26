# UdonSharp ネットワーキングルール (常時ロード)

ネットワーキングの基本ルールと制約。詳細パターンは `../references/networking.md` を参照。

**SDK対応**: 3.7.1 - 3.10.1 (2026年2月時点)

## オーナーシップモデル

- 各 GameObject に 1 人のネットワークオーナー
- **synced 変数を変更できるのはオーナーのみ**
- オーナー変更: `Networking.SetOwner(Networking.LocalPlayer, gameObject)`
- オーナー確認: `Networking.IsOwner(gameObject)`

```csharp
// 標準パターン: チェック → 取得 → 変更 → 送信
if (!Networking.IsOwner(gameObject))
    Networking.SetOwner(Networking.LocalPlayer, gameObject);
syncedValue = newValue;
RequestSerialization();
```

## 同期モード

| モード | 属性値 | 特徴 | データ上限 |
|------|--------|------|-----------|
| **NoVariableSync** | `BehaviourSyncMode.NoVariableSync` | 変数同期なし、イベントのみ | - |
| **Continuous** | `BehaviourSyncMode.Continuous` | 自動同期 ~10Hz | ~200 bytes |
| **Manual** | `BehaviourSyncMode.Manual` | `RequestSerialization()` で明示同期 | ~282KB |

### Continuous (連続同期)

- `RequestSerialization()` 不要 (自動送信)
- 位置・回転など連続値向き
- データ量制限に注意 (~200 bytes)

### Manual (手動同期)

- `RequestSerialization()` 必須
- ゲーム状態・スコアなど低頻度更新向き
- 大容量データ対応

```csharp
[UdonBehaviourSyncMode(BehaviourSyncMode.Manual)]
public class GameState : UdonSharpBehaviour
{
    [UdonSynced] private int score;

    public void AddScore(int points)
    {
        Networking.SetOwner(Networking.LocalPlayer, gameObject);
        score += points;
        RequestSerialization();
    }
}
```

## RequestSerialization パターン

Manual sync 手順: オーナーシップ取得 → synced 変数更新 → `RequestSerialization()` → 受信側 `OnDeserialization()` で反応

## 文字列同期の制限

- synced string の最大長: **~50文字**
- 長いデータは分割送信するか、別の手段を検討

## NetworkCallable (SDK 3.8.1+)

パラメータ付きネットワークイベント。最大8個のパラメータを送信可能。

```csharp
[NetworkCallable]
public void TakeDamage(int damage, int attackerId)
{
    health -= damage;
    Debug.Log($"Player {attackerId} dealt {damage} damage");
}

// 呼び出し
SendCustomNetworkEvent(NetworkEventTarget.All, nameof(TakeDamage), damage, attackerId);
```

### NetworkCallable 制約

| 制約 | 説明 |
|------|------|
| アクセス修飾子 | `public` 必須 |
| 属性 | `[NetworkCallable]` 必須 |
| `static` / `virtual` / `override` | 使用不可 |
| オーバーロード | 不可 (UdonSharp 全体の制約) |
| レート制限 | デフォルト 5回/秒/イベント (最大 100回/秒に設定可) |
| パラメータ数 | 最大 8個 |

## FieldChangeCallback パターン

synced 変数の変更をプロパティ setter で検知するパターン:

```csharp
[UdonSynced, FieldChangeCallback(nameof(Health))]
private float _health = 100f;

public float Health
{
    get => _health;
    set
    {
        _health = value;
        // ローカルでもリモートでも呼ばれる
        OnHealthChanged();
    }
}

private void OnHealthChanged()
{
    healthBar.value = _health;
}
```

## 重要な原則

1. **「同期のコツは同期しないこと」**: 最小限のデータのみ同期し、ローカル計算を活用
2. **動的インスタンス化不可**: オブジェクトプーリングを使用
3. **Late Joiner 対応**: synced 変数は自動的に Late Joiner に送信される
4. **テスト**: 複数プレイヤーでの早期テストが重要
5. **VRCPlayerApi の有効性**: 常に `player != null && player.IsValid()` を確認

## よくあるアンチパターン (重要)

### アンチパターン 1: uGUI コールバックで Owner チェック → 非 Owner のボタンが無反応

uGUI の OnClick は**全クライアントのローカルで発火**する。Owner チェックで弾くと非 Owner はボタンが効かない。

```csharp
// NG: Owner 以外はボタンが無反応になる
public void OnButtonClicked()
{
    if (!Networking.IsOwner(gameObject)) return; // 非Ownerは何も起きない!
    score += 10;
    RequestSerialization();
}

// OK パターンA: Owner に委譲 (低頻度操作向き)
public void OnButtonClicked()
{
    SendCustomNetworkEvent(NetworkEventTarget.Owner, nameof(OwnerAddScore));
}
public void OwnerAddScore()
{
    score += 10;
    RequestSerialization();
}

// OK パターンB: Ownership を取得してから実行 (即時レスポンス向き)
public void OnButtonClicked()
{
    Networking.SetOwner(Networking.LocalPlayer, gameObject);
    score += 10;
    RequestSerialization();
}
```

### アンチパターン 2: 全クライアントで Update() ゲームロジック実行 → Owner 競合

条件判定が全員で同時に true になると、全員が SetOwner + 変更して競合する。

```csharp
// NG: 全員が監視・状態変更 → Owner 競合
void Update()
{
    if (detectSomeCondition) // 全クライアントで true
    {
        Networking.SetOwner(Networking.LocalPlayer, gameObject);
        syncedState = newState; // 全員が同時に変更
        RequestSerialization();
    }
}

// OK: Owner のみロジック実行、他は表示のみ
void Update()
{
    if (!Networking.IsOwner(gameObject)) return;

    if (detectSomeCondition)
    {
        syncedState = newState;
        RequestSerialization();
    }
}

public override void OnDeserialization()
{
    UpdateDisplay(); // 全員: 受信した状態を表示に反映
}
```

## ネットワーキングチェックリスト

- [ ] synced 変数変更前にオーナーシップを確認/取得しているか
- [ ] Manual sync で `RequestSerialization()` を呼んでいるか
- [ ] synced string が 50文字以内か
- [ ] `VRCPlayerApi` の有効性チェックをしているか
- [ ] Late Joiner でも正しく動作するか
- [ ] NetworkCallable のレート制限を考慮しているか
