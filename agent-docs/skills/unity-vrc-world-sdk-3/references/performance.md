# VRChat ワールドパフォーマンス最適化

## パフォーマンス目標

### 最低要件

| プラットフォーム | FPS 目標 | 測定ポイント |
|-----------------|----------|-------------|
| PC VR | 45+ FPS | スポーン地点、1人 |
| PC Desktop | 60+ FPS | スポーン地点、1人 |
| Quest | 72 FPS | スポーン地点、1人 |

### パフォーマンスティア

```
Excellent: 90+ FPS (PC), 72 FPS stable (Quest)
Good: 60-90 FPS (PC), 60-72 FPS (Quest)
Acceptable: 45-60 FPS (PC), 45-60 FPS (Quest)
Poor: < 45 FPS - 改善必須
```

---

## 重要なパフォーマンス要因

### 1. ミラー

```
影響度: ⚠️ 非常に高い

問題:
- シーン全体を2回レンダリング
- VRでは4回（両目×2）
- 複数のミラーは指数的に負荷増加

対策:
□ ワールドに1つまで
□ デフォルトでOFF
□ トグルで有効化
□ 距離で自動無効化
□ 解像度を下げる
```

### 2. ビデオプレイヤー

```
影響度: ⚠️ 高い

問題:
- デコード処理が重い
- 複数同時再生で負荷増大

対策:
□ 最大2つまで
□ 同時再生を避ける
□ 低解像度オプションを用意
```

### 3. リアルタイムライト

```
影響度: ⚠️ 高い

問題:
- 動的シャドウは非常に重い
- 各ライトがオブジェクトを再計算

対策:
□ リアルタイムライトは0-1個
□ ライトをベイク
□ Light Probes で動的オブジェクト対応
□ どうしても必要な場合は範囲を限定
```

### 4. ドローコール

```
影響度: ⚠️ 中〜高

問題:
- 各マテリアル/メッシュがDraw Callを生成
- モバイルは特に敏感

対策:
□ マテリアルを統合
□ テクスチャアトラス使用
□ Static Batching 有効化
□ GPU Instancing 使用
```

---

## ライティング最適化

### ベイクドライティング (必須)

```
✅ 推奨設定:

Lighting Settings:
├── Lightmapper: Progressive GPU
├── Lightmap Resolution: 10-20 texels/unit
├── Lightmap Compression: Normal
└── Directional Mode: Non-Directional (Quest)

Light Settings:
├── Mode: Baked または Mixed
├── Indirect Multiplier: 1.0
└── Shadow Type: Soft Shadows (Baked)
```

### ライトプローブ

```
用途:
- 動的オブジェクト（プレイヤー、Pickup）に
  ベイクドライティングの影響を与える

配置:
□ プレイヤーが通る場所に配置
□ 明暗の境界に密に配置
□ 屋内外の境界に配置
□ 3D的に分散（床だけでなく高さも）
```

### リフレクションプローブ

```
用途:
- 反射の品質向上
- ベイクで負荷軽減

設定:
├── Type: Baked（リアルタイム避ける）
├── Resolution: 128-256
├── Box Projection: 必要な場合のみ
└── Importance: 適切に設定
```

---

## シェーダー最適化

### PC シェーダー

```text
✅ 推奨:
- Standard Shader
- VRChat 公式シェーダー
- シングルパスステレオ対応シェーダー

❌ 避ける:
- スクリーンスペースエフェクト
- 複雑なテッセレーション
- 過度なパス数
```

### Quest/Android シェーダー

```
✅ 必須:
- Mobile シェーダー使用
- Mobile/VRChat/Lightmapped (推奨)
- Mobile/Particles シリーズ

❌ 絶対避ける:
- 透明度（Alpha）の多用
- スクリーンスペースエフェクト
- 複雑な計算シェーダー
```

### 透明度の警告

```
⚠️ 透明度（Alpha）の問題:

モバイルGPUはAlpha fill rateに弱い:
- 透明オブジェクトは複数回描画される
- 重なると指数的に重くなる

対策:
□ 透明度を使わないデザイン
□ どうしても必要なら範囲を限定
□ Cutout > Transparent（可能なら）
```

---

## メッシュとジオメトリ

### ポリゴンガイドライン

| プラットフォーム | 推奨 | 最大 |
|-----------------|------|------|
| PC | 500K - 1M | 2M |
| Quest | 50K - 100K | 200K |

### 最適化テクニック

```
□ LOD (Level of Detail) を設定
□ Occlusion Culling を有効化
□ 見えないメッシュを削除
□ 遠景は低ポリ + ベイクドシャドウ
```

### スタティックバッチング

```csharp
// 動かないオブジェクトは Static に設定

Inspector:
[✓] Static
  [✓] Batching Static
  [✓] Occludee Static
  [✓] Occluder Static
```

---

## オクルージョンカリング

### セットアップ

```
1. Window > Rendering > Occlusion Culling
2. 静的オブジェクトを Occluder/Occludee に設定
3. Bake

設定:
├── Smallest Occluder: 5-10m（大きいほど高速）
├── Smallest Hole: 0.25m
└── Backface Threshold: 100
```

### ベストプラクティス

```
□ 壁・床・天井を Occluder に
□ 小さなオブジェクトは Occludee のみ
□ 透明オブジェクトは Occluder にしない
□ 複雑な形状は簡略化
```

---

## オーディオ最適化

### 圧縮設定

```text
BGM:
├── Load Type: Streaming
├── Compression Format: Vorbis
└── Quality: 70%

効果音:
├── Load Type: Decompress On Load（短い音）
├── Load Type: Compressed In Memory（長い音）
└── Quality: 50-70%
```

### 空間オーディオ

```
□ 不要な音源は無効化
□ Max Distance を適切に設定
□ 遠くの音源は2Dにフォールバック
```

---

## スクリプト最適化

### Update() の最適化

```csharp
// ❌ 毎フレームの処理は避ける
void Update()
{
    player = Networking.LocalPlayer; // 毎フレーム取得
}

// ✅ キャッシュを使用
private VRCPlayerApi _localPlayer;

void Start()
{
    _localPlayer = Networking.LocalPlayer;
}

void Update()
{
    // _localPlayer を使用
}
```

### SendCustomEventDelayedSeconds

```csharp
// 頻繁な処理は間隔を空ける
void Start()
{
    SendCustomEventDelayedSeconds(nameof(SlowUpdate), 0.5f);
}

public void SlowUpdate()
{
    // 0.5秒ごとの処理
    DoHeavyCalculation();
    SendCustomEventDelayedSeconds(nameof(SlowUpdate), 0.5f);
}
```

---

## プラットフォーム別最適化

### Quest 最適化チェックリスト

```
□ ポリゴン数 < 100K
□ マテリアル数 < 25
□ テクスチャ解像度 ≤ 1024x1024
□ Mobile シェーダー使用
□ ライト完全ベイク
□ リアルタイムライト = 0
□ ミラーなし or 極小
□ ビデオプレイヤー ≤ 1
□ Post Processing なし
```

### PC 最適化チェックリスト

```
□ VR で 45+ FPS
□ リアルタイムライト最小限
□ ミラー = デフォルトOFF
□ ライトベイク完了
□ Occlusion Culling 設定
□ LOD 設定
□ Post Processing は控えめ
```

---

## プロファイリングツール

### Unity プロファイラー

```
Window > Analysis > Profiler

確認項目:
- CPU Usage: 16ms以下（60FPS）
- Rendering: Draw Calls, Tris, Batches
- Memory: テクスチャ使用量
```

### フレームデバッガー

```
Window > Analysis > Frame Debugger

用途:
- Draw Call の内訳確認
- バッチングの効果確認
- 重複描画の発見
```

### VRChat デバッグメニュー

```
インゲームで確認:
- FPS
- Network stats
- Avatar performance
```

---

## よくあるパフォーマンス問題

| 問題 | 原因 | 解決策 |
|------|------|--------|
| 低FPS | ミラー常時ON | デフォルトOFF |
| 低FPS | リアルタイムライト | ベイク |
| カクつき | GC Allocation | オブジェクトプール |
| ロード遅い | 大きなテクスチャ | 圧縮・解像度下げ |
| Quest で動かない | 重いシェーダー | Mobile シェーダー |

---

## クイック最適化チェックリスト

```
□ 45+ FPS (VR) 達成
□ ライトベイク完了
□ リアルタイムライト ≤ 1
□ ミラー デフォルトOFF
□ ビデオプレイヤー ≤ 2
□ Static Batching 有効
□ Occlusion Culling 設定
□ LOD 設定（大きなオブジェクト）
□ テクスチャ圧縮
□ モバイル対応（必要な場合）
```
