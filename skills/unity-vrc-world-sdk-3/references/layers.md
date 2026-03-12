# VRChat レイヤーとコリジョンリファレンス

## 概要

VRChat は Unity のレイヤーシステムを使用して、GameObject の整理、コリジョン制御、選択的レンダリングを行います。VRChat SDK でプロジェクトを作成すると、レイヤーは自動的に設定されます。

**重要**: VRChat予約レイヤー（0-21）の名前変更・削除は、アップロード時に上書きされます。

---

## VRChat 予約レイヤー (0-21)

### システムレイヤー

| レイヤー番号 | 名前 | 用途 |
|-------------|------|------|
| 0 | Default | 一般オブジェクト |
| 1 | TransparentFX | 透明エフェクト |
| 2 | Ignore Raycast | Raycast無視 |
| 3 | - | 未使用 |
| 4 | Water | 水面 |
| 5 | UI | Unity UI |

### VRChat 固有レイヤー

| レイヤー番号 | 名前 | 用途 |
|-------------|------|------|
| 8 | Interactive | インタラクト可能オブジェクト |
| 9 | Player | リモートプレイヤー |
| 10 | PlayerLocal | ローカルプレイヤー |
| 11 | Environment | 環境オブジェクト（壁・床） |
| 12 | UiMenu | VRChat UIメニュー |
| 13 | Pickup | 持てるオブジェクト |
| 14 | PickupNoEnvironment | 環境と衝突しないPickup |
| 15 | StereoLeft | ステレオ左目 |
| 16 | StereoRight | ステレオ右目 |
| 17 | Walkthrough | 通り抜け可能 |
| 18 | MirrorReflection | ミラー反射用 |
| 19 | reserved2 | 予約済み |
| 20 | reserved3 | 予約済み |
| 21 | reserved4 | 予約済み |

---

## ユーザーレイヤー (22-31)

**自由に使用可能**: 名前変更・コリジョン設定が保持される。

| レイヤー番号 | 推奨用途 |
|-------------|----------|
| 22 | カスタム用途1 |
| 23 | カスタム用途2 |
| 24 | カスタム用途3 |
| 25 | カスタム用途4 |
| 26 | カスタム用途5 |
| 27 | カスタム用途6 |
| 28 | カスタム用途7 |
| 29 | カスタム用途8 |
| 30 | カスタム用途9 |
| 31 | カスタム用途10 |

### よく使われるカスタムレイヤー

```
Layer 22: "Intangible" - 衝突しないデコレーション
Layer 23: "LocalOnly" - ローカル専用オブジェクト
Layer 24: "TriggerZone" - トリガーゾーン専用
Layer 25: "Projectiles" - 発射物
```

---

## レイヤー使用ガイドライン

### Default (レイヤー 0)

```
用途:
- 一般的なオブジェクト
- 特別な処理が不要なもの

注意:
- プレイヤーと衝突する
- Raycastで検出される
```

### Environment (レイヤー 11)

```
用途:
- 壁、床、天井
- 歩行可能な地形
- 障害物

特徴:
- プレイヤーと確実に衝突
- Pickup も衝突
```

### Pickup (レイヤー 13)

```
用途:
- VRC_Pickup を持つオブジェクト

特徴:
- プレイヤーと衝突
- 環境と衝突
- 他のPickupとの衝突は設定次第
```

### PickupNoEnvironment (レイヤー 14)

```
用途:
- 環境を通り抜けるPickup
- 壁越しに渡せるオブジェクト

特徴:
- プレイヤーと衝突
- 環境と衝突しない
```

### Walkthrough (レイヤー 17)

```
用途:
- 通り抜け可能なオブジェクト
- 視覚的な障壁
- エフェクト用コライダー

特徴:
- プレイヤーが通り抜けられる
- トリガーイベントは発火可能
```

### MirrorReflection (レイヤー 18)

```
用途:
- ミラーに映すオブジェクト
- ミラー専用レイヤー

注意:
- 通常のカメラには映らない
- ミラーのみに表示
```

---

## コリジョンマトリックス

### 現在のマトリックス確認

```
Edit > Project Settings > Physics > Layer Collision Matrix
```

### VRChat デフォルトコリジョンマトリックス

```
重要な衝突ペア:

✅ 衝突する:
- Player ↔ Environment
- Player ↔ Pickup
- PlayerLocal ↔ Environment
- Pickup ↔ Environment

❌ 衝突しない:
- Player ↔ Player (VRChat制御)
- Player ↔ PlayerLocal
- PickupNoEnvironment ↔ Environment
- Walkthrough ↔ Player
```

### カスタムレイヤーコリジョン設定

```csharp
// スクリプトでレイヤーコリジョンを設定（エディタ専用）
#if UNITY_EDITOR
Physics.IgnoreLayerCollision(22, 11, true); // Layer 22 と Environment の衝突を無効化
#endif
```

---

## Udon でのレイヤーマスク

### レイヤーマスクの取得

```csharp
// レイヤー番号からマスクを取得
int playerLayer = LayerMask.NameToLayer("Player");
int layerMask = 1 << playerLayer;

// 複数レイヤーのマスク
int mask = (1 << LayerMask.NameToLayer("Player")) |
           (1 << LayerMask.NameToLayer("Environment"));
```

### レイヤーマスクを使った Raycast

```csharp
// 特定レイヤーのみにRaycast
int playerMask = 1 << 9; // Player layer

RaycastHit hit;
if (Physics.Raycast(origin, direction, out hit, maxDistance, playerMask))
{
    // Player にヒット
}

// 特定レイヤーを除外
int everythingExceptPlayer = ~(1 << 9);
```

### よく使うレイヤーマスク

```csharp
// よく使うマスク
private int _environmentMask;
private int _playerMask;
private int _pickupMask;

void Start()
{
    _environmentMask = 1 << LayerMask.NameToLayer("Environment");
    _playerMask = 1 << LayerMask.NameToLayer("Player");
    _pickupMask = 1 << LayerMask.NameToLayer("Pickup");
}
```

---

## レイヤーのベストプラクティス

### 推奨事項

```
✅ 適切なレイヤーを選択:
- 床・壁 → Environment
- 持てる物 → Pickup
- 装飾（衝突不要） → User Layer + 衝突無効

✅ User Layers を活用:
- カスタム衝突設定が必要な場合
- 特定のRaycastフィルタリング
```

### 禁止事項

```
❌ 避けること:
- VRChat予約レイヤーの名前変更
- Player/PlayerLocal レイヤーの使用（VRChat専用）
- 不要な衝突の有効化
```

---

## トラブルシューティング

### よくある問題

| 問題 | 原因 | 解決策 |
|------|------|--------|
| プレイヤーが壁を通り抜ける | 間違ったレイヤー | Environment に設定 |
| Pickupが床を通り抜ける | PickupNoEnvironment使用 | Pickup に変更 |
| オブジェクトがミラーに映らない | レイヤー設定 | MirrorReflection確認 |
| Raycastが検出しない | レイヤーマスク | 正しいマスクを使用 |

### レイヤー問題のデバッグ

```csharp
// オブジェクトのレイヤーを確認
Debug.Log($"Layer: {gameObject.layer} ({LayerMask.LayerToName(gameObject.layer)})");

// コリジョンマトリックス確認
bool willCollide = !Physics.GetIgnoreLayerCollision(layerA, layerB);
Debug.Log($"Layers {layerA} and {layerB} collision: {willCollide}");
```

---

## クイックリファレンス

### レイヤー番号一覧

```
0  = Default
9  = Player
10 = PlayerLocal
11 = Environment
13 = Pickup
14 = PickupNoEnvironment
17 = Walkthrough
18 = MirrorReflection
22-31 = User Layers (自由)
```

### よく使う操作

```csharp
// レイヤー設定
gameObject.layer = LayerMask.NameToLayer("Pickup");

// レイヤー確認
if (gameObject.layer == LayerMask.NameToLayer("Environment")) { }

// 子オブジェクト含めて変更
foreach (Transform child in transform.GetComponentsInChildren<Transform>())
{
    child.gameObject.layer = newLayer;
}
```
