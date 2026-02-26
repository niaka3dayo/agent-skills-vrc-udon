# VRChat ワールドアップロードガイド

ワールドアップロードの完全手順とベストプラクティス。

## 目次

- [Pre-Upload Checklist](#pre-upload-checklist)
- [Build & Test](#build--test)
- [Validation](#validation)
- [Upload Process](#upload-process)
- [World Settings](#world-settings)
- [Content Warnings](#content-warnings)
- [Capacity Settings](#capacity-settings)
- [Post-Upload](#post-upload)
- [Troubleshooting](#troubleshooting)

---

## アップロード前チェックリスト

### 必須チェック項目

```
□ Scene Setup
  □ VRC_SceneDescriptor が 1 つだけ存在
  □ Spawns に Transform が設定済み
  □ Respawn Height が適切（床より十分下）
  □ Reference Camera 設定（必要な場合）

□ Layers & Collision
  □ "Setup Layers for VRChat" 実行済み
  □ Collision Matrix 確認済み
  □ オブジェクトが適切なレイヤーに配置

□ Components
  □ VRC_Pickup に Collider + Rigidbody
  □ VRC_Station に Collider
  □ VRC_ObjectSync に Rigidbody
  □ ミラーがデフォルトで OFF

□ Performance
  □ VR で 45+ FPS
  □ ライトマップがベイク済み
  □ リアルタイムライト最小限

□ Content
  □ 著作権侵害コンテンツなし
  □ 規約違反コンテンツなし
  □ Content Warnings 設定
```

### 推奨チェック項目

```
□ Build & Test でローカル確認済み
□ 複数プレイヤーテスト実施
□ Quest 対応（必要な場合）
□ ワールドサムネイル準備
□ ワールド説明文作成
```

---

## ビルドとテスト

### ローカルテスト手順

```
1. VRChat SDK > Show Control Panel
2. Builder タブ
3. "Build & Test New Build" セクション
4. Number of Clients: テストしたいクライアント数
5. Force Non-VR: Desktop モード強制（オプション）
6. "Build & Test" ボタン
```

### テスト項目

```
Single Player Test:
□ スポーン位置が正しい
□ Respawn Height で正しくリスポーン
□ 壁・床のコリジョンが正しい
□ Pickup が持てる/離せる
□ Station に座れる/降りれる
□ ミラーが動作する（有効化時）
□ オーディオが正しく再生
□ ビデオプレイヤーが動作

Multi-Player Test (複数クライアント):
□ スポーン位置が分散される
□ Pickup の同期が正しい
□ Station の同期が正しい
□ UdonSynced 変数が同期
□ Late Joiner に状態が同期
□ Ownership 転送が正しく動作
```

### Number of Clients 設定

```
テスト目的別推奨:

基本動作確認: 1 クライアント
同期テスト: 2 クライアント
多人数テスト: 3-4 クライアント

注意:
- 各クライアントは独立した VRChat インスタンス
- PC リソースを消費
- 初回ビルドは時間がかかる
```

---

## バリデーション

### バリデーション確認手順

```
1. VRChat SDK > Show Control Panel
2. Builder タブ
3. Validations セクションを確認
4. エラー (赤) を解決
5. 警告 (黄) を確認
```

### よくあるバリデーションエラー

| エラー | 原因 | 解決策 |
|-------|-------|----------|
| Missing SceneDescriptor | VRCWorld がない | VRCWorld Prefab 追加 |
| Layer setup required | レイヤー未設定 | "Setup Layers" クリック |
| Build size too large | ビルドが大きすぎ | アセット削減 |
| Script errors | コンパイルエラー | スクリプト修正 |
| Missing references | 参照エラー | 参照を修正 |

### 自動修正機能

```
一部の問題は自動修正可能:

"Auto Fix" ボタンが表示される項目:
- Layer collision matrix
- Project settings
- Quality settings

自動修正できない項目:
- スクリプトエラー
- Missing references
- コンポーネント設定ミス
```

---

## アップロードプロセス

### アップロード手順

```
1. Validation エラーがないことを確認

2. VRChat SDK > Show Control Panel

3. Builder タブ

4. "Build and Upload" ボタンをクリック

5. 初回アップロードの場合:
   - World Name 入力
   - Description 入力
   - Content Warnings 設定
   - Capacity 設定

6. 更新の場合:
   - 変更内容を確認
   - 必要に応じて設定変更

7. "Upload" をクリック

8. アップロード完了を待つ
```

### ブループリント ID

```
Blueprint ID:
- ワールドの一意識別子
- VRC_PipelineManager に保存
- 同じIDで上書き更新

新規作成:
- "Attach a New Blueprint ID" をクリック
- または新規シーンでアップロード

既存ワールド更新:
- 同じ Blueprint ID を維持
- 設定のみ変更可能
```

### ワールドサムネイル

```
サムネイル設定:

方法1: Screenshot
- アップロード画面で "Take Screenshot"
- 現在のシーンビューをキャプチャ

方法2: 外部画像
- PNG/JPG をインポート
- サムネイルとして選択

推奨仕様:
- 解像度: 1200x900 以上
- アスペクト比: 4:3
- ファイルサイズ: < 10MB
```

---

## ワールド設定

### 基本設定

| 設定 | 説明 | 推奨 |
|---------|-------------|----------------|
| Name | ワールド名 | 検索しやすい名前 |
| Description | 説明文 | 機能・注意事項を記載 |
| Tags | タグ | 適切なタグを選択 |
| Release Status | 公開状態 | Private → Public |

### 公開ステータス

```
Private:
- 自分と招待した人のみアクセス可
- テスト・開発用

Friends:
- フレンドのみアクセス可
- 限定公開用

Friends+:
- フレンドのフレンドもアクセス可

Public:
- 全員がアクセス可
- 検索に表示される
```

---

## コンテンツ警告

### 必須設定

```
該当する場合は必ず設定:

□ Adult Language
  - 成人向け言語が含まれる

□ Blood/Gore
  - 血液・グロテスク表現

□ Fear/Horror
  - ホラー・恐怖要素

□ Nudity/Suggestive
  - 裸体・性的示唆

□ Substance Use
  - 薬物・アルコール表現

□ Violence
  - 暴力表現
```

### 警告設定の重要性

```
⚠️ 警告:

設定しない場合:
- 規約違反でワールド削除の可能性
- アカウント制限の可能性

誤設定の場合:
- ユーザー体験に影響
- 不適切なフラグはユーザーを遠ざける

ベストプラクティス:
- 該当するものはすべて選択
- 疑わしい場合は選択する
```

---

## キャパシティ設定

### キャパシティの種類

| 設定 | 目的 | 動作 |
|---------|---------|----------|
| **Recommended Capacity** | 推奨人数 | UI表示、検索フィルター |
| **Maximum Capacity** | 最大人数 | ハードリミット |

### 設定ガイドライン

```
Recommended Capacity:
- 快適にプレイできる人数
- パフォーマンスが維持される人数
- UI に表示される

Maximum Capacity:
- 技術的に対応可能な最大人数
- これ以上は参加不可
- 通常は Recommended の 2-4 倍

例:
- 小規模ワールド: 8-16 人
- 中規模ワールド: 20-32 人
- 大規模ワールド: 40-80 人
```

### Capacity 設定のベストプラクティス

```
✅ 推奨:

1. パフォーマンステストで決定
   - 実際に複数人でテスト
   - FPS を確認

2. ネットワーク負荷を考慮
   - 同期オブジェクトが多い → 少なめ
   - 静的ワールド → 多め

3. ワールドの目的を考慮
   - イベント用 → 多め
   - 少人数向け → 少なめ

❌ 避ける:

- 根拠なく最大に設定
- テストせずに決定
- パフォーマンス無視
```

---

## アップロード後

### 確認事項

```
1. VRChat ウェブサイトで確認
   - https://vrchat.com/home/
   - "My Worlds" セクション

2. ゲーム内で確認
   - ワールド検索
   - 正しく表示されるか

3. 設定確認
   - 公開状態
   - サムネイル
   - 説明文
```

### 更新後の注意

```
更新後:
- 既存インスタンスは古いバージョン
- 新規インスタンスのみ新バージョン
- キャッシュクリアが必要な場合あり

反映時間:
- 通常数分で反映
- 検索インデックスは数時間かかる場合
```

### ワールドの管理

```
VRChat ウェブサイトで:

□ Release Status 変更
□ 説明文の更新
□ タグの変更
□ Capacity の変更
□ Content Warnings の変更
□ サムネイルの変更
□ ワールドの削除
```

---

## トラブルシューティング

### アップロードエラー

| エラー | 原因 | 解決策 |
|-------|-------|----------|
| "Build failed" | ビルドエラー | Console でエラー確認 |
| "Upload failed" | ネットワークエラー | 再試行 |
| "File too large" | サイズ超過 | アセット削減 |
| "Not logged in" | ログインしていない | SDK Panel でログイン |
| "Validation failed" | Validation エラー | エラーを修正 |

### よくある問題

#### ワールドが見つからない

```
原因:
1. Private 設定のまま
2. 検索インデックス未反映
3. ワールド名が一般的すぎる

解決策:
1. Public に変更
2. 数時間待つ
3. ユニークな名前に変更
4. 直接URLでアクセス
```

#### アップロードに時間がかかる

```
原因:
1. ビルドサイズが大きい
2. ネットワークが遅い
3. サーバー混雑

解決策:
1. アセットを最適化
2. 安定したネット接続
3. 時間をおいて再試行
```

#### 変更が反映されない

```
原因:
1. 古いインスタンスに参加
2. キャッシュの問題
3. Blueprint ID の問題

解決策:
1. 新規インスタンスを作成
2. VRChat キャッシュクリア
3. Blueprint ID を確認
```

### デバッグチェックリスト

```
□ Console にエラーがないか
□ Validation がすべてパスか
□ Blueprint ID が正しいか
□ ログイン状態か
□ ネット接続が安定しているか
□ ディスク容量が十分か
```

---

## プラットフォーム別アップロード

### PC + Quest クロスプラットフォーム

```
手順:

1. PC 向けビルド
   - Platform: Windows
   - Build & Upload

2. Quest 向けビルド
   - Platform: Android に切り替え
   - Quest 向け最適化
   - Build & Upload (同じ Blueprint ID)

3. 両プラットフォームで確認

注意:
- 同じ Blueprint ID を使用
- 両プラットフォームで機能が異なる場合あり
- Quest では一部機能が無効化される
```

### Quest 専用ワールド

```
設定:

1. Platform: Android
2. Quest 向け最適化を適用
3. Build & Upload

注意:
- PC ユーザーはアクセス不可
- Quest 最適化必須
```

---

## クイックリファレンス

### アップロードチェックリスト (最小)

```
□ VRC_SceneDescriptor × 1
□ Spawns 設定
□ Validation パス
□ Build & Test 確認
□ Content Warnings 設定
□ Upload
```

### SDK パネルショートカット

```
VRChat SDK > Show Control Panel

Builder タブ:
- Build & Test
- Build & Upload
- Validations

Content Manager タブ:
- アップロード済みコンテンツ管理

Settings タブ:
- SDK 設定
```

### 主要 URL

| 目的 | URL |
|---------|-----|
| VRChat Home | https://vrchat.com/home/ |
| My Worlds | https://vrchat.com/home/worlds |
| World Detail | https://vrchat.com/home/world/{worldId} |

