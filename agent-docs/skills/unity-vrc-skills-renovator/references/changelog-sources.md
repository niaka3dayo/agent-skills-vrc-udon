# 公式情報ソース一覧

VRChat SDK (UdonSharp + World SDK) の公式情報ソースとアクセス方法。

## 主要公式ソース

### VRChat Creator Docs

| ページ | URL | 内容 |
|--------|-----|------|
| SDK リリース一覧 | `creators.vrchat.com/releases/` | 全SDKリリースノート |
| 最新リリース | `creators.vrchat.com/releases/release-3-{version}/` | 個別リリース詳細 |
| Udon | `creators.vrchat.com/worlds/udon/` | Udon 公式ドキュメント |
| ネットワーキング | `creators.vrchat.com/worlds/udon/networking/` | ネットワーキング |
| 永続化 | `creators.vrchat.com/worlds/udon/persistence/` | 永続化 |
| コンポーネント | `creators.vrchat.com/worlds/components/` | ワールドコンポーネント |
| レイヤー | `creators.vrchat.com/worlds/layers/` | レイヤー設定 |
| 許可 URL リスト | `creators.vrchat.com/worlds/udon/string-loading/` | 許可URLリスト |

**注意**: 403エラーが返る場合があるため、WebSearchで検索してスニペットから情報を取得。

### UdonSharp Docs

| ページ | URL | 内容 |
|--------|-----|------|
| ブログ/ニュース | `udonsharp.docs.vrchat.com/news/` | UdonSharp 更新情報 |
| リリースタグ | `udonsharp.docs.vrchat.com/news/tags/release/` | リリース一覧 |
| コード例 | `udonsharp.docs.vrchat.com/examples/` | コード例 |

### VRChat Feedback (Canny)

| ページ | URL | 内容 |
|--------|-----|------|
| Udon フィードバック | `feedback.vrchat.com/udon` | Udon 機能リクエスト |
| 実装済み | `feedback.vrchat.com/udon?status=complete` | 実装済み機能 |
| 永続化 | `feedback.vrchat.com/persistence` | 永続化関連 |

### GitHub

| リポジトリ | URL | 内容 |
|-----------|-----|------|
| UdonSharp リリース | `github.com/MerlinVR/UdonSharp/releases` | リリース履歴 |
| Creator Companion | `github.com/vrchat-community/creator-companion` | VCC 関連 |

## バージョン履歴の追跡

### SDK バージョン体系

```
SDK 3.{major}.{minor}
例: SDK 3.10.0

major: 大きな機能追加
minor: バグ修正、小さな変更
```

### 主要マイルストーン

| バージョン | 日付 | 主な変更点 |
|-----------|------|----------|
| 3.7.1 | 2024 | StringBuilder, Regex, System.Random |
| 3.7.4 | 2024 | Persistence API |
| 3.7.6 | 2024 | マルチプラットフォーム Build & Publish |
| 3.8.0 | 2025 | PhysBone 依存関係ソート, Force Kinematic On Remote |
| 3.8.1 | 2025 | NetworkCallable, パラメータ付きイベント, Others/Self ターゲット |
| 3.9.0 | 2025 | Camera Dolly API, Auto Hold 簡素化 |
| 3.10.0 | 2025 | Dynamics for Worlds |
| 3.10.1 | 2025 | バグ修正・安定性改善 (最新安定版) |

### 次回更新時の確認ポイント

1. **各スキルの最終対応バージョン確認**
   ```
   unity-vrc-udon-sharp/SKILL.md の「対応SDKバージョン」
   unity-vrc-world-sdk-3/SKILL.md の「対応SDKバージョン」
   ```

2. **公式リリースページで新バージョン確認**
   ```
   WebSearch: "VRChat SDK Releases"
   ```

3. **差分バージョンのリリースノート確認**
   ```
   例: 3.10.0 → 3.11.0 の場合
   WebSearch: "VRChat SDK Release 3.11.0"
   ```

4. **差分をスキル別に分類**
   ```
   UdonSharp関連 → unity-vrc-udon-sharp
   ワールド設定関連 → unity-vrc-world-sdk-3
   ```

## 情報収集フロー

```
┌─────────────────────────────────────────────────────────┐
│ 1. WebSearch: "VRChat SDK {年} releases changelog"      │
│    → 最新バージョン番号を特定                            │
└──────────────────────────┬──────────────────────────────┘
                           ▼
┌─────────────────────────────────────────────────────────┐
│ 2. WebSearch: "VRChat SDK Release 3.{新バージョン}"     │
│    → リリースノートの概要を取得                          │
└──────────────────────────┬──────────────────────────────┘
                           ▼
┌─────────────────────────────────────────────────────────┐
│ 3. WebSearch: 機能別クエリ（並列実行）                   │
│    - NetworkCallable                                     │
│    - Persistence                                         │
│    - Dynamics                                            │
│    → 各機能の詳細を取得                                  │
└──────────────────────────┬──────────────────────────────┘
                           ▼
┌─────────────────────────────────────────────────────────┐
│ 4. 情報の統合と差分リスト作成                            │
│    → 更新すべきファイルと内容を決定                      │
└─────────────────────────────────────────────────────────┘
```

## 補助情報源

### 日本語コミュニティ

| ソース | 検索クエリ例 |
|--------|-------------|
| Qiita | `site:qiita.com VRChat SDK {バージョン}` |
| Zenn | `site:zenn.dev VRChat UdonSharp` |
| note | `site:note.com VRChat SDK 更新` |

### VRChat Ask フォーラム

```
ask.vrchat.com
- Developer Update カテゴリ
- SDK関連の質問と回答
```

### Twitter/X (SNS)

```
検索: "VRChat SDK" OR "UdonSharp" 新機能
アカウント: @VRChat, @MerlinVR
```

## アクセス制限への対処

### 403 エラーの場合

1. **WebSearchでキャッシュ/スニペットを活用**
2. **GitHubのミラー/関連リポジトリを確認**
3. **フォーラム/コミュニティの議論を参照**

### 情報が見つからない場合

1. **異なるキーワードで再検索**
2. **日本語/英語を切り替え**
3. **日付範囲を広げる**
4. **関連する機能名で検索**

## 定期更新のタイミング

### 推奨更新頻度

| 状況 | 推奨頻度 |
|------|------|
| 新メジャーバージョン | 即時更新 |
| マイナー更新（.1, .2等） | 1-2週間以内 |
| 定期確認 | 月1回 |

### 更新が必要なシグナル

- VRChat公式Twitterでリリース告知
- Creator Companionで新バージョン通知
- ユーザーからの「情報が古い」フィードバック
- 既知の制約が解消されたという報告
