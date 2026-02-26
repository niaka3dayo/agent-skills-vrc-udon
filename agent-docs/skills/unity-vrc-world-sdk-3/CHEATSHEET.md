# VRC World SDK 3 チートシート

**SDK 3.7.x - 3.10.x 対応** (2026年2月時点)

---

## 目次

| セクション | 内容 |
|-----------|------|
| [シーンセットアップ](#シーンセットアップ) | VRCWorld、スポーン、リスポーン |
| [コンポーネント](#コンポーネント) | Pickup, Station, ObjectSync |
| [レイヤー](#レイヤー) | レイヤー番号と用途 |
| [パフォーマンス](#パフォーマンス) | 制限値と最適化 |
| [ライティング](#ライティング) | ベイク設定 |
| [オーディオ/ビデオ](#オーディオビデオ) | オーディオ・ビデオ |
| [アップロード](#アップロード) | アップロード手順 |

---

## シーンセットアップ

### チェックリスト

```
□ VRCWorld prefab × 1
□ Spawns 設定済み
□ Respawn Height 設定済み (床より下)
□ "Setup Layers for VRChat" 実行
□ ライトベイク完了
□ 45+ FPS (VR)
```

### VRC_SceneDescriptor

| プロパティ | 説明 | デフォルト |
|-----------|------|-----------|
| Spawns | スポーン地点配列 | Descriptor位置 |
| Spawn Order | Sequential/Random/Demo | Sequential |
| Respawn Height | リスポーンY座標 | -100 |
| Reference Camera | カメラ設定参照 | None |
| Maximum Capacity | 最大人数 | - |
| Recommended Capacity | 推奨人数 | - |

### スポーン順序

```
Sequential: 0 → 1 → 2 → 0 → 1 (順番)
Random:     ランダム選択
Demo:       全員が Spawns[0]
```

---

## コンポーネント

### 必須要素

| コンポーネント | Collider | Rigidbody | 用途 |
|--------------|----------|-----------|------|
| VRC_SceneDescriptor | - | - | ワールド設定 |
| VRC_Pickup | 必須 | 必須 | 持てる |
| VRC_Station | 必須 | - | 座れる |
| VRC_ObjectSync | - | 必須 | 物理同期 |
| VRC_Mirror | - | - | 鏡 |

### VRC_Pickup セットアップ

```
[GameObject]
├── Collider (IsTrigger推奨)
├── Rigidbody
├── VRC_Pickup
│   ├── Auto Hold: Yes/No/AutoDetect
│   ├── Pickupable: true
│   └── Allow Theft: true
└── VRC_ObjectSync (同期時)
```

**イベント:**
```csharp
OnPickup()           // 持った時
OnDrop()             // 離した時
OnPickupUseDown()    // トリガー押下
OnPickupUseUp()      // トリガー解放
```

### VRC_Station セットアップ

```
[GameObject]
├── Collider
└── VRC_Station
    ├── Player Mobility: Mobile/Immobilize
    ├── Disable Station Exit: false
    └── Entry/Exit Transform
```

**Udon:**
```csharp
Networking.LocalPlayer.UseAttachedStation();

OnStationEntered(VRCPlayerApi player)
OnStationExited(VRCPlayerApi player)
```

### VRC_ObjectSync

```csharp
VRCObjectSync sync = (VRCObjectSync)GetComponent(typeof(VRCObjectSync));

sync.Respawn();           // 初期位置にリセット
sync.SetGravity(true);    // 重力設定
sync.SetKinematic(false); // 物理設定
sync.FlagDiscontinuity(); // 瞬間移動時（補間スキップ）
```

### VRC_Mirror

```csharp
// デフォルトOFF + トグル
void Start() => mirrorObject.SetActive(false);

public override void Interact()
{
    mirrorObject.SetActive(!mirrorObject.activeSelf);
}
```

---

## レイヤー

### VRChat 予約レイヤー

| # | 名前 | 用途 |
|---|------|-----|
| 0 | Default | 一般オブジェクト |
| 9 | Player | リモートプレイヤー |
| 10 | PlayerLocal | ローカルプレイヤー |
| 11 | Environment | 壁・床 |
| 13 | Pickup | 持てる物 |
| 14 | PickupNoEnvironment | 壁通過Pickup |
| 17 | Walkthrough | 通り抜け可能 |
| 18 | MirrorReflection | ミラー専用 |
| **22-31** | **User** | **自由に使用可** |

### レイヤーマスク (Udon)

```csharp
// レイヤーマスク取得
int playerMask = 1 << 9;
int envMask = 1 << LayerMask.NameToLayer("Environment");

// 複数レイヤー
int combined = (1 << 9) | (1 << 11);

// 除外
int exceptPlayer = ~(1 << 9);

// Raycast
Physics.Raycast(origin, dir, out hit, distance, playerMask);
```

---

## パフォーマンス

### 制限値

| 項目 | PC | Quest |
|------|-----|-------|
| FPS Target | 45+ VR, 60+ Desktop | 72 |
| Mirrors | 1 (デフォルトOFF) | 0-1 |
| Video Players | 2 | 1 |
| Realtime Lights | 0-1 | 0 |
| Polygons | 500K-1M | 50K-100K |
| Materials | 制限なし | 25以下 |
| Texture Size | 制限なし | 1024以下 |

### Quest 制限

| 機能 | PC | Quest |
|---------|-----|-------|
| Dynamic Bones | ✅ | ❌ |
| Cloth | ✅ | ❌ |
| Post-Processing | ✅ | ❌ |
| Unity Constraints | ✅ | ❌ |
| Realtime Shadows | ✅ | ⚠️ |

### 最適化チェックリスト

```
□ ライトベイク完了
□ リアルタイムライト ≤ 1
□ ミラー デフォルトOFF
□ ビデオプレイヤー ≤ 2
□ Static Batching 有効
□ Occlusion Culling 設定
□ LOD 設定
```

---

## ライティング

### クイックセットアップ

```
✅ DO:
├── Lightmapper: Progressive GPU
├── Light Mode: Baked / Mixed
├── Light Probes 配置
└── Reflection Probes 配置

❌ DON'T:
├── Realtime ライト多用
├── 高解像度ライトマップ
└── 動的シャドウ多用
```

### ライトマップ設定

| 設定 | PC | Quest |
|---------|-----|-------|
| Resolution | 20 texels/unit | 10 |
| Size | 2048 | 1024 |
| Directional | Directional | Non-Directional |
| Compress | ✅ | ✅ |

### ライトプローブ

```
配置場所:
✅ プレイヤーが通る場所
✅ 明暗の境界
✅ 屋内外の境界
✅ 高さ方向にも分散

配置しない場所:
❌ 壁の中
❌ 到達不可能な場所
```

---

## オーディオ/ビデオ

### VRC_SpatialAudioSource

| プロパティ | デフォルト | 範囲 |
|-----------|-----------|------|
| Gain | 0 dB | -24 ~ +24 |
| Near | 0 m | 減衰開始 |
| Far | 40 m | 減衰終了 |
| Volumetric Radius | 0 m | 音源の広がり |

### ビデオプレイヤー比較

| 機能 | AVPro | Unity |
|---------|-------|-------|
| YouTube/Twitch | ✅ | ❌ |
| Live Stream | ✅ | ❌ |
| Editor Preview | ❌ | ✅ |
| Quest | ✅ | ✅ |

### ビデオイベント

```csharp
OnVideoStart()
OnVideoEnd()
OnVideoError(VideoError error)
OnVideoReady()
```

### オーディオ圧縮

| 種類 | ロード方式 | 品質 |
|------|----------|------|
| BGM | Streaming | 70% |
| SFX | Decompress | 50-70% |
| Ambient | Compressed | 50% |

---

## アップロード

### アップロード前チェックリスト

```
□ VRC_SceneDescriptor × 1
□ Spawns 設定
□ Respawn Height 適切
□ Layer/Collision 確認
□ Lights ベイク済
□ Mirror OFF デフォルト
□ 45+ FPS (VR)
□ Validation エラーなし
```

### アップロード手順

```
1. VRChat SDK > Show Control Panel
2. Builder タブ
3. Validations 確認 & 修正
4. Build & Test (ローカルテスト)
5. Build & Upload
6. World Settings 設定
   - Name / Description
   - Content Warnings
   - Capacity
7. Upload
8. VRChat ウェブで確認
```

### キャパシティガイドライン

| ワールド規模 | 推奨 | 最大 |
|-------------|------|------|
| 小規模 | 8-16 | 20-32 |
| 中規模 | 20-32 | 40-64 |
| 大規模 | 40-80 | 80+ |

### コンテンツ警告

```
□ Adult Language
□ Blood/Gore
□ Fear/Horror
□ Nudity/Suggestive
□ Substance Use
□ Violence
```

---

## トラブルシューティング早見表

| 問題 | 解決策 |
|-------|----------|
| プレイヤーが壁を通り抜ける | Layer → Environment |
| Pickup が持てない | Collider + Rigidbody 追加 |
| Pickup が同期しない | VRC_ObjectSync 追加 |
| Station に座れない | Collider 追加 |
| ミラーが映らない | Layer 確認 |
| FPS が低い | ミラーOFF、ライトベイク |
| Quest で動かない | Mobile シェーダー使用 |
| ビルドエラー | Validation 確認 |
| アップロード後見つからない | Public に変更 |

---

## 公式ドキュメント・問題調査 (WebSearch)

```bash
# VRChat フォーラム
site:ask.vrchat.com "問題キーワード"

# バグ報告・要望
site:feedback.vrchat.com "問題キーワード"

# GitHub
site:github.com/vrchat-community "問題キーワード"
```

---

## SDK バージョン別機能

| SDK | 主な機能 |
|-----|---------|
| 3.7.4 | Persistence API |
| 3.8.1 | [NetworkCallable] |
| 3.9.0 | Camera Dolly, Auto Hold |
| 3.10.0 | Dynamics (PhysBones) |

