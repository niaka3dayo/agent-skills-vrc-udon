# 効果的な検索クエリ集

VRChat SDK (UdonSharp + World SDK) の最新情報を収集するための検索クエリ集。

## 基本検索（毎回実行）

### リリース情報

```
VRChat SDK {年} new features updates changelog
```
例: `VRChat SDK 2025 new features updates changelog`

```
UdonSharp VRChat SDK 3.{バージョン} changes
```
例: `UdonSharp VRChat SDK 3.11 changes`

```
VRChat Worlds SDK {年} UdonSharp
```
例: `VRChat Worlds SDK 2025 UdonSharp`

### バージョン固有

```
VRChat SDK Release 3.{major}.{minor}
```
例: `VRChat SDK Release 3.10.0`

## World SDK コンポーネント検索

### コンポーネント変更

```
VRChat World SDK components new features {年}
VRChat SDK VRC_SceneDescriptor new settings
VRChat SDK VRC_Pickup VRC_Station changes
```

### ワールド最適化

```
VRChat world optimization guidelines {年}
VRChat SDK performance limits draw calls
```

### ライティング・オーディオ

```
VRChat world lighting baked lightmap {年}
VRChat SDK audio video player changes
```

### レイヤー・コリジョン

```
VRChat world layer collision matrix changes
VRChat SDK new layers {年}
```

## UdonSharp 機能別検索

### ネットワーキング

```
VRChat SDK NetworkCallable parameters UdonSharp
VRChat SDK SendCustomNetworkEvent parameters
VRChat Udon network events with parameters
```

### 永続化

```
VRChat SDK persistence PlayerData world data
VRChat PlayerObject PlayerData difference
VRChat OnPlayerRestored event
```

### Dynamics（PhysBones/Contacts）

```
VRChat SDK PhysBones Contacts Udon API worlds
VRChat SDK 3.10 dynamics worlds
VRChat OnContactEnter OnPhysBoneGrab
```

### 新しいSystem名前空間

```
VRChat SDK System.Random StringBuilder RegularExpressions Udon
VRChat Udon new namespaces exposed
```

### GetComponent/ジェネリック

```
VRChat SDK GetComponent UdonSharpBehaviour inheritance generic
UdonSharp GetComponent fix generic
```

## 日本語検索（補足）

```
VRChat SDK 最新 変更点
UdonSharp 新機能 {年}
VRChat ワールド開発 SDK更新
```

## 検索のコツ

### 効果的なキーワード

| 目的 | キーワード例 |
|------|-----------|
| リリースノート | "release", "changelog", "what's new" |
| 新機能 | "new feature", "added", "now supports" |
| 変更点 | "changed", "updated", "improved" |
| 修正 | "fixed", "resolved", "bugfix" |
| 非推奨 | "deprecated", "removed", "breaking change" |

### 検索順序

1. **まず公式リリースノート検索**
   ```
   VRChat SDK Releases {バージョン}
   ```

2. **次にUdonSharp固有の変更**
   ```
   UdonSharp {バージョン} release
   ```

3. **機能別の詳細検索**
   ```
   VRChat SDK {機能名} {年}
   ```

### 並列検索の推奨

以下の検索は依存関係がないため、並列実行可能:

```
// 並列実行グループ1（リリース情報）
- VRChat SDK {年} new features updates changelog
- UdonSharp VRChat SDK 3.{バージョン} changes

// 並列実行グループ2（機能別）
- VRChat SDK NetworkCallable parameters
- VRChat SDK persistence PlayerData
- VRChat SDK PhysBones Contacts worlds
```

## 検索結果の評価

### 信頼度の高いソース

| ソース | 信頼度 | 備考 |
|--------|--------|------|
| creators.vrchat.com | 最高 | 公式ドキュメント |
| udonsharp.docs.vrchat.com | 最高 | UdonSharp公式 |
| feedback.vrchat.com | 高 | 公式フィードバック |
| github.com/vrchat-community | 高 | 公式GitHub |
| qiita.com (VRChat タグ) | 中 | 日本語コミュニティ |
| zenn.dev | 中 | 日本語技術記事 |

### 情報の鮮度確認

- 記事の日付を確認
- 言及されているSDKバージョンを確認
- 「beta」「preview」の情報は正式リリースを待つ

## WebFetch が使えない場合

VRChat公式サイト（creators.vrchat.com）は403を返すことがあるため:

1. **WebSearchで概要を把握**
2. **検索結果のスニペットから情報を抽出**
3. **複数の検索結果を組み合わせて情報を補完**

代替情報源:
- GitHub Issues/Discussions
- VRChat Ask Forum (ask.vrchat.com)
- Discord（検索不可だが参考）
