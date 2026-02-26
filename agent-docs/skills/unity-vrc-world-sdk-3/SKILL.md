---
name: unity-vrc-world-sdk-3
description: |
    VRChat World SDK 3 world setup & optimization guide (SDK 3.7.1 - 3.10.1).
    Covers scene setup, component placement, layers, performance optimization,
    lighting, and upload workflow.
    Keywords: VRChat world, VRC SDK, VRC_SceneDescriptor, spawn point,
    VRC_Pickup, VRC_Station, VRC_Mirror, VRC_ObjectSync, layer setup,
    optimization, Quest support, light baking, upload, FPS improvement
    Related: Use unity-vrc-udon-sharp for UdonSharp coding.
---

# VRChat World SDK 3 Guide

## Table of Contents

| Section                                    | Content                    | Reference                       |
| ------------------------------------------ | -------------------------- | ------------------------------- |
| [Scene Setup](#scene-setup)                | VRC_SceneDescriptor, Spawn | This file                       |
| [Components](#components)                  | Pickup, Station, Mirror    | `references/components.md`      |
| [Layers & Collision](#layers--collision)   | Layers, Collision Matrix   | `references/layers.md`          |
| [Performance](#performance)                | Optimization guide         | `references/performance.md`     |
| [Lighting](#lighting)                      | Lighting settings          | `references/lighting.md`        |
| [Audio & Video](#audio--video)             | Audio, Video players       | `references/audio-video.md`     |
| [World Upload](#world-upload)              | Upload workflow            | `references/upload.md`          |
| [Troubleshooting](#troubleshooting)        | Problem solving            | `references/troubleshooting.md` |
| [Cheatsheet](CHEATSHEET.md)               | Quick reference            | `CHEATSHEET.md`                 |

---

## SDK Versions

**対応バージョン**: SDK 3.7.1 - 3.10.1 (2026年2月時点)

| SDK    | 新機能                                                                  | 状態        |
| ------ | ----------------------------------------------------------------------- | ----------- |
| 3.7.1  | StringBuilder, Regex, System.Random                                     | ✅          |
| 3.7.4  | **Persistence API** (PlayerData/PlayerObject)                           | ✅          |
| 3.7.6  | **マルチプラットフォーム Build & Publish** (PC + Android 同時ビルド)     | ✅          |
| 3.8.0  | PhysBone 依存関係ソート, **Force Kinematic On Remote**, Drone API       | ✅          |
| 3.8.1  | **[NetworkCallable]** パラメータ付きイベント, `Others`/`Self` ターゲット | ✅          |
| 3.9.0  | **Camera Dolly API**, Auto Hold 簡素化, VRCCameraSettings               | ✅          |
| 3.10.0 | **Dynamics for Worlds** (PhysBones, Contacts, VRC Constraints)          | ✅          |
| 3.10.1 | バグ修正・安定性改善                                                    | ✅ 最新安定 |

> **重要**: SDK 3.9.0 未満は **2025年12月2日をもって非推奨**。新規ワールドのアップロードができません。

---

## Scene Setup

### VRC_SceneDescriptor (Required)

すべてのVRChatワールドに**1つだけ**必要。

```
[VRCWorld Prefab]
├── VRC_SceneDescriptor (Required)
├── VRC_PipelineManager (Auto-added)
├── VRCWorldSettings (Optional - 移動速度設定)
└── AvatarScalingSettings (Optional - アバタースケール制限)
```

#### All Properties

| プロパティ                      | 型          | 説明                     | デフォルト     |
| ------------------------------- | ----------- | ------------------------ | -------------- |
| **Spawns**                      | Transform[] | スポーン地点配列         | Descriptor位置 |
| **Spawn Order**                 | enum        | Sequential/Random/Demo   | Sequential     |
| **Respawn Height**              | float       | リスポーン高度(Y軸)      | -100           |
| **Object Behaviour At Respawn** | enum        | Respawn/Destroy          | Respawn        |
| **Reference Camera**            | Camera      | プレイヤーカメラ設定参照 | None           |
| **Forbid User Portals**         | bool        | ユーザーポータル禁止     | false          |
| **Voice Falloff Range**         | float       | ボイス減衰範囲           | -              |
| **Interact Passthrough**        | LayerMask   | インタラクト透過レイヤー | Nothing        |
| **Maximum Capacity**            | int         | 最大人数(ハードリミット) | -              |
| **Recommended Capacity**        | int         | 推奨人数(UI表示用)       | -              |

#### Spawn Order Behavior

```
Sequential: 0 → 1 → 2 → 0 → 1 → 2... (順番)
Random:     ランダム選択
Demo:       全員が Spawns[0] に出現
```

#### Reference Camera Usage

```csharp
// 用途:
// 1. Near/Far クリッピング調整 (VR用: 0.01 ~ 1000 推奨)
// 2. Post Processing エフェクト適用
// 3. Background 色設定

// 設定手順:
// 1. Camera を作成 (名前: "ReferenceCamera")
// 2. Camera コンポーネントの設定を調整
// 3. Camera を無効化 (チェックを外す)
// 4. VRC_SceneDescriptor の Reference Camera に設定
```

### Spawn Points Setup

```csharp
// 設定手順:
// 1. 空の GameObject を作成
// 2. 位置・回転を設定 (プレイヤーは Z+ 方向を向く)
// 3. VRC_SceneDescriptor の Spawns 配列に追加

// 推奨:
// - 最低 2-3 個のスポーン (同時参加対応)
// - 床から少し上 (0.1m程度)
// - 障害物のない場所
// - VRプレイヤーのガーディアン考慮
```

### Required Setup Checklist

```
□ VRCWorld Prefab がシーンに 1 つだけ存在
□ Spawns に最低 1 つの Transform を設定
□ Respawn Height を適切な値に設定 (床より十分下)
□ Reference Camera でクリッピング距離を調整 (VR用)
□ Layer/Collision Matrix が正しく設定
□ "Setup Layers for VRChat" を実行済み
```

---

## Components

| コンポーネント             | 必須要素             | 用途                     | SDK  |
| -------------------------- | -------------------- | ------------------------ | ---- |
| **VRC_SceneDescriptor**    | -                    | ワールド設定 (必須)      | -    |
| **VRC_Pickup**             | Collider + Rigidbody | 持てるオブジェクト       | -    |
| **VRC_Station**            | Collider             | 座れる場所               | -    |
| **VRC_ObjectSync**         | Rigidbody            | Transform/物理の自動同期 | -    |
| **VRC_MirrorReflection**   | -                    | ミラー (⚠️ 高負荷)      | -    |
| **VRC_PortalMarker**       | -                    | 他ワールドへのポータル   | -    |
| **VRC_SpatialAudioSource** | AudioSource          | 3Dオーディオ             | -    |
| **VRC_UIShape**            | Canvas (World Space) | Unity UI操作             | -    |
| **VRC_AvatarPedestal**     | -                    | アバター表示/変更        | -    |
| **VRC_CameraDolly**        | -                    | カメラドリー             | 3.9+ |

### VRC_ObjectSync vs UdonSynced

| シナリオ         | VRC_ObjectSync | UdonSynced変数 |
| ---------------- | -------------- | -------------- |
| 投げられる物・物理演算 | ✅ 推奨    | ❌             |
| 状態のみ・複雑なロジック | ❌       | ✅ 推奨        |

> **SDK 3.8.0+**: `Force Kinematic On Remote` — オーナー以外のクライアントで Rigidbody を Kinematic にし、予期しない物理挙動を防止。

**→ プロパティ詳細・Udon イベント・コード例は `references/components.md`**

---

## Layers & Collision

### VRChat Reserved Layers

| Layer #   | Name                | 用途                   |
| --------- | ------------------- | ---------------------- |
| 0         | Default             | 一般オブジェクト       |
| 9         | Player              | リモートプレイヤー     |
| 10        | PlayerLocal         | ローカルプレイヤー     |
| 11        | Environment         | 環境 (壁・床)          |
| 13        | Pickup              | 持てるオブジェクト     |
| 14        | PickupNoEnvironment | 環境と衝突しないPickup |
| 17        | Walkthrough         | 通り抜け可能           |
| 18        | MirrorReflection    | ミラー反射専用         |
| **22-31** | **User Layers**     | **自由に使用可能**     |

### Layer Setup Steps

```
1. VRChat SDK > Show Control Panel
2. Builder タブ
3. "Setup Layers for VRChat" をクリック
4. Collision Matrix が自動設定される
```

**→ 詳細は `references/layers.md`**

---

## Performance

### Target FPS

| Platform   | FPS目標 | 測定場所          |
| ---------- | ------- | ----------------- |
| PC VR      | 45+ FPS | スポーン地点、1人 |
| PC Desktop | 60+ FPS | スポーン地点、1人 |
| Quest      | 72 FPS  | スポーン地点、1人 |

### Critical Limits

| 項目               | 推奨               | 理由                  |
| ------------------ | ------------------ | --------------------- |
| ミラー             | 1つ、デフォルトOFF | シーン2倍レンダリング |
| ビデオプレイヤー   | 最大2つ            | デコード負荷          |
| リアルタイムライト | 0-1                | 動的シャドウが重い    |
| ライトマップ       | **必須**           | パフォーマンス基盤    |

### Quest/Android Restrictions

| コンポーネント     | PC  | Quest         |
| ------------------ | --- | ------------- |
| Dynamic Bones      | ✅  | ❌ 無効       |
| Cloth              | ✅  | ❌ 無効       |
| Post-Processing    | ✅  | ❌ 無効       |
| Unity Constraints  | ✅  | ❌ 無効       |
| リアルタイムライト | ✅  | ⚠️ 極力避ける |

**→ 詳細は `references/performance.md`**

---

## Lighting

### Baked Lighting (Required)

```
✅ 推奨設定:
├── Lightmapper: Progressive GPU
├── Lightmap Resolution: 10-20 texels/unit
├── Light Mode: Baked または Mixed
└── Light Probes: プレイヤー動線に配置

❌ 避ける:
├── Realtime ライト (動的シャドウ)
├── 高解像度ライトマップ (メモリ消費)
└── 過剰な Reflection Probes
```

**→ 詳細は `references/lighting.md`**

---

## Audio & Video

### VRC_SpatialAudioSource

| プロパティ            | 説明         | デフォルト      |
| --------------------- | ------------ | --------------- |
| Gain                  | 音量 (dB)    | 0 (ワールド+10) |
| Near                  | 減衰開始距離 | 0m              |
| Far                   | 減衰終了距離 | 40m             |
| Volumetric Radius     | 音源の広がり | 0m              |
| Enable Spatialization | 3D定位       | true            |

### Video Player Selection

| 機能               | AVPro | Unity Video |
| ------------------ | ----- | ----------- |
| ライブストリーム   | ✅    | ❌          |
| エディタプレビュー | ❌    | ✅          |
| YouTube/Twitch     | ✅    | ❌          |
| Quest対応          | ✅    | ✅          |

**→ 詳細は `references/audio-video.md`**

---

## World Upload

### Upload Steps

```
1. Validation 確認
   └── VRChat SDK > Build Panel > Validations

2. Build & Test (ローカルテスト)
   └── "Build & Test New Build"
   └── 複数クライアントテスト可能

3. Upload
   └── "Build and Upload"
   └── Content Warnings 設定
   └── Capacity 設定

4. 公開設定
   └── VRChat ウェブサイトで公開/非公開設定
```

### Pre-Upload Checklist

```
□ VRC_SceneDescriptor × 1
□ Spawns 設定済み
□ Respawn Height 適切
□ Layer/Collision Matrix 確認
□ ライトベイク完了
□ ミラーデフォルト OFF
□ VR で 45+ FPS
□ Validation エラーなし
□ Content Warnings 設定
□ Capacity 設定
```

**→ 詳細は `references/upload.md`**

---

## Troubleshooting

### Common Issues

| 問題                       | 原因                    | 解決策                |
| -------------------------- | ----------------------- | --------------------- |
| プレイヤーが壁を通り抜ける | 間違ったレイヤー        | Environment に設定    |
| Pickup が持てない          | Collider/Rigidbody なし | 両方追加              |
| Pickup が同期しない        | ObjectSync なし         | VRC_ObjectSync 追加   |
| Station に座れない         | Collider なし           | Collider 追加         |
| ミラーが映らない           | レイヤー設定            | MirrorReflection 確認 |
| ビルドエラー               | Validation失敗          | SDK Panel で確認      |

**→ 詳細は `references/troubleshooting.md`**

---

## Related Skills

| タスク                  | 使用スキル                |
| ----------------------- | ------------------------- |
| C# コード作成           | `unity-vrc-udon-sharp` |
| ネットワーク同期 (Udon) | `unity-vrc-udon-sharp` |
| イベント実装            | `unity-vrc-udon-sharp` |
| シーン設定              | **このスキル**            |
| コンポーネント配置      | **このスキル**            |
| パフォーマンス最適化    | **このスキル**            |

---

## Web Search

### Official Documentation (WebSearch)

```
# 公式ドキュメント検索
WebSearch: "調べたいコンポーネントや機能 site:creators.vrchat.com"
```

### Issue Investigation (WebSearch)

```
# Step 1: フォーラム検索
WebSearch:
  query: "問題 site:ask.vrchat.com"
  allowed_domains: ["ask.vrchat.com"]

# Step 2: 既知のバグ検索
WebSearch:
  query: "問題 site:feedback.vrchat.com"
  allowed_domains: ["feedback.vrchat.com"]

# Step 3: GitHub Issues
WebSearch:
  query: "問題 site:github.com/vrchat-community"
```

### Official Resources

| リソース          | URL                                   |
| ----------------- | ------------------------------------- |
| VRChat Creators   | https://creators.vrchat.com/worlds/   |
| VRChat Forums     | https://ask.vrchat.com/               |
| VRChat Canny      | https://feedback.vrchat.com/          |
| SDK Release Notes | https://creators.vrchat.com/releases/ |

---

## References

| ファイル                        | 内容                 | 行数目安 |
| ------------------------------- | -------------------- | -------- |
| `references/components.md`      | 全コンポーネント詳細 | 800+     |
| `references/layers.md`          | レイヤー・コリジョン | 400+     |
| `references/performance.md`     | パフォーマンス最適化 | 500+     |
| `references/lighting.md`        | ライティング設定     | 400+     |
| `references/audio-video.md`     | オーディオ・ビデオ   | 400+     |
| `references/upload.md`          | アップロード手順     | 300+     |
| `references/troubleshooting.md` | 問題解決ガイド       | 500+     |
| `CHEATSHEET.md`                 | クイックリファレンス | 200+     |
