# VRChat ワールドライティングガイド

VRChat ワールドのライティング設定と最適化ガイド。

## 目次

- [Lighting Fundamentals](#lighting-fundamentals)
- [Baked Lighting](#baked-lighting)
- [Light Probes](#light-probes)
- [Reflection Probes](#reflection-probes)
- [Quest Optimization](#quest-optimization)
- [Common Issues](#common-issues)

---

## ライティングの基礎

### ライトモード

| モード | パフォーマンス | 動的オブジェクト | 用途 |
|------|----------------|------------------|------|
| **Baked** | ✅ 最高 | ❌ 影響なし | 静的環境 |
| **Mixed** | ⚠️ 中程度 | ✅ 影響あり | 動的影が必要 |
| **Realtime** | ❌ 重い | ✅ 完全対応 | 極力避ける |

### 推奨アプローチ

```
✅ 推奨:
1. 環境ライト → Baked
2. Light Probes → 動的オブジェクト用
3. Reflection Probes → 反射品質向上

❌ 避ける:
1. Realtime ライト (動的シャドウ)
2. 過度なライトマップ解像度
3. 多数の Mixed ライト
```

---

## ベイクドライティング

### ライトマップ設定

```
Window > Rendering > Lighting

推奨設定:
├── Lightmapper: Progressive GPU (高速)
├── Lightmap Resolution: 10-20 texels/unit
├── Lightmap Padding: 2
├── Lightmap Size: 1024 (Quest) / 2048 (PC)
├── Compress Lightmaps: ✅
├── Ambient Occlusion: ✅
│   ├── Max Distance: 1-3
│   └── Indirect/Direct Contribution: 0.5-1
└── Directional Mode: Non-Directional (Quest)
```

### オブジェクト設定

```
静的オブジェクト (Static):
├── Inspector > Static チェック
├── Contribute GI: ✅
└── Receive GI: Lightmaps

動的オブジェクト:
├── Contribute GI: ❌
└── Receive GI: Light Probes
```

### ベイク手順

```
1. すべてのライトを Baked/Mixed に設定
2. 静的オブジェクトを Static に設定
3. Light Probes を配置
4. Lighting ウィンドウで "Generate Lighting"
5. 完了を待つ（数分〜数時間）
6. 結果を確認、必要に応じて調整
```

---

## ライトプローブ

### 目的

```
Light Probes は:
- 動的オブジェクト（プレイヤー、Pickup）に
  ベイクドライティングの影響を与える
- Lightmap を使えないオブジェクト用
- 低負荷で動的ライティング効果を実現
```

### 配置ガイドライン

```
配置場所:
✅ プレイヤーが通る場所
✅ 明暗の境界
✅ 色が変わる場所
✅ 屋内外の境界
✅ 高さ方向にも分散

配置しない場所:
❌ 壁の中
❌ 到達不可能な場所
❌ 静的オブジェクトのみの場所
```

### 作成手順

```
1. GameObject > Light > Light Probe Group
2. Edit Light Probes ボタン
3. Probe を追加/移動
4. 3D的に配置（床だけでなく高さも）
5. Generate Lighting で更新
```

### 配置密度

```
推奨密度:
├── 屋内通路: 2-3m 間隔
├── 広い空間: 3-5m 間隔
├── 明暗境界: 1m 以下
└── 高さ: 0.5m, 1.5m, 3m など複数レベル
```

---

## リフレクションプローブ

### 目的

```
Reflection Probes は:
- 環境反射を提供
- 金属・光沢表面の品質向上
- リアルタイム反射の代替
```

### 設定

```
推奨設定:
├── Type: Baked (リアルタイム避ける)
├── Resolution: 128-256
├── HDR: ✅ (品質重視時)
├── Box Projection: 必要時のみ
├── Importance: 1 (デフォルト)
└── Blend Distance: 1-3
```

### 配置

```
配置場所:
├── 各部屋に 1 つ
├── 屋外に大きな 1 つ
├── 特殊な反射が必要な場所
└── 重なりを考慮

注意:
- 多すぎると負荷増加
- 適切な Bounds 設定が重要
```

---

## Quest 最適化

### Quest 専用設定

```
必須:
├── すべてのライトを Baked に
├── Directional Mode: Non-Directional
├── Lightmap Size: 512-1024
├── Compress Lightmaps: ✅
└── リアルタイムライト: 0

推奨シェーダー:
├── Mobile/VRChat/Lightmapped
├── Mobile/Diffuse
└── Mobile/Particles
```

### Quest ライティング手順

```
1. Platform を Android に切り替え
2. すべての Realtime ライトを削除
3. Mixed → Baked に変更
4. Lightmap 解像度を下げる
5. Light Probes を配置
6. Generate Lighting
7. Quest 実機でテスト
```

---

## よくある問題

### ライトマップがぼやける

**解決策**:
```
1. Lightmap Resolution を上げる (10→20)
2. Lightmap Size を上げる (1024→2048)
3. オブジェクトの UV2 を確認
4. Generate Lightmap UVs を有効化
```

### 継ぎ目が目立つ

**解決策**:
```
1. Lightmap Padding を増やす (2→4)
2. オブジェクトのスケールを確認
3. UV2 の継ぎ目を調整
```

### 動的オブジェクトが暗い

**解決策**:
```
1. Light Probes を配置
2. Receive GI: Light Probes に設定
3. Generate Lighting を再実行
```

### ベイクが遅い

**解決策**:
```
1. Progressive GPU を使用
2. Lightmap Resolution を下げる
3. 不要なオブジェクトを Static から外す
4. Bounces を減らす (2-3)
```

---

## シェーダーグローバル変数

```csharp
// ライティング関連のシェーダー変数
// _VRChatCameraMode:
//   0 = 通常
//   1 = VR ハンドヘルド
//   2 = Desktop ハンドヘルド
//   3 = スクリーンショット

// カスタムシェーダーで使用可能
```

---

## クイックリファレンス

### 設定チェックリスト

```
□ すべてのライトが Baked/Mixed
□ 静的オブジェクトが Static 設定
□ Light Probes が配置済み
□ Reflection Probes が配置済み
□ Lightmap がベイク済み
□ Quest: Realtime ライト 0
□ Quest: Directional Mode = Non-Directional
```

### パフォーマンス目安

| 設定項目 | PC | Quest |
|------|-----|-------|
| Lightmap Resolution | 20 | 10 |
| Lightmap Size | 2048 | 1024 |
| Reflection Probe Res | 256 | 128 |
| Realtime Lights | 0-1 | 0 |
