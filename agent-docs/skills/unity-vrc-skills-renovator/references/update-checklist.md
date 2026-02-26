# VRCスキル更新チェックリスト

## フェーズ 1: 現状把握

- [ ] 各スキルのSDK対応バージョンを確認
  ```text
  Read: skills/unity-vrc-udon-sharp/SKILL.md
  Read: skills/unity-vrc-world-sdk-3/SKILL.md
  → 「対応SDKバージョン」の行を探す
  ```

- [ ] 更新対象ファイル一覧を確認
  ```text
  Glob: skills/unity-vrc-udon-sharp/**/*
  Glob: skills/unity-vrc-world-sdk-3/**/*
  ```

## フェーズ 2: 情報収集

### 必須検索（並列実行）

- [ ] 検索1: 最新リリース概要
  ```bash
  WebSearch: "VRChat SDK {現在年} new features updates changelog"
  ```

- [ ] 検索2: 具体的なSDKバージョン
  ```bash
  WebSearch: "VRChat Worlds SDK 3.{次のバージョン} changes"
  ```

- [ ] 検索3: UdonSharp固有
  ```bash
  WebSearch: "UdonSharp VRChat SDK {現在年}"
  ```

- [ ] 検索4: World SDK コンポーネント
  ```bash
  WebSearch: "VRChat World SDK components new features {現在年}"
  ```

### 機能別検索（必要に応じて）

- [ ] ネットワーキング更新
  ```bash
  WebSearch: "VRChat SDK NetworkCallable SendCustomNetworkEvent"
  ```

- [ ] 永続化更新
  ```bash
  WebSearch: "VRChat SDK persistence PlayerData PlayerObject"
  ```

- [ ] Dynamics更新
  ```bash
  WebSearch: "VRChat SDK PhysBones Contacts worlds Udon"
  ```

- [ ] 新しいSystem名前空間
  ```bash
  WebSearch: "VRChat SDK Udon new namespaces exposed"
  ```

- [ ] ワールド設定・コンポーネント
  ```bash
  WebSearch: "VRChat SDK VRC_SceneDescriptor new settings"
  ```

## フェーズ 3: 差分リスト作成

収集した情報を分類:

- [ ] UdonSharp 向けの差分リストを作成
  ```text
  対象: unity-vrc-udon-sharp
  - C# API、ネットワーキング、同期変数、イベント
  ```

- [ ] World SDK 向けの差分リストを作成
  ```text
  対象: unity-vrc-world-sdk-3
  - コンポーネント、レイヤー、最適化、ライティング
  ```

- [ ] 両スキルに影響する差分を特定
  ```text
  対象: 両方
  - SDKバージョン表記、Persistence 等
  ```

## フェーズ 4: unity-vrc-udon-sharp の更新

### 優先度1: SKILL.md
- [ ] SDK対応バージョンを更新
- [ ] 新機能サマリーを追加
- [ ] リソースリストを更新

### 優先度2: constraints.md
- [ ] 新たに使えるようになった機能を追加
- [ ] 制約が緩和された項目を更新

### 優先度3: networking.md
- [ ] 新しいネットワーキング機能を追加
- [ ] データ制限の変更を反映

### 優先度4: events.md
- [ ] 新しいイベントを追加
- [ ] イベントパラメータの変更を反映

### 優先度5: api.md
- [ ] 新しいAPIクラス/メソッドを追加

### 優先度6: CHEATSHEET.md
- [ ] クイックリファレンスを更新

### 優先度7: patterns.md
- [ ] 新機能のパターンを追加

### 優先度8: troubleshooting.md
- [ ] 新機能のトラブルシューティングを追加

## フェーズ 5: unity-vrc-world-sdk-3 の更新

### 優先度1: SKILL.md
- [ ] SDK対応バージョンを更新
- [ ] 新機能サマリーを追加

### 優先度2: components.md
- [ ] 新コンポーネントを追加
- [ ] プロパティ変更を反映

### 優先度3: layers.md
- [ ] レイヤー・コリジョン変更を反映

### 優先度4: performance.md
- [ ] 新しい最適化ガイドラインを追加

### 優先度5: lighting.md
- [ ] ライティング関連の変更を反映

### 優先度6: audio-video.md
- [ ] オーディオ/ビデオ関連の変更を反映

### 優先度7: upload.md
- [ ] アップロード手順の変更を反映

### 優先度8: CHEATSHEET.md
- [ ] クイックリファレンスを更新

### 優先度9: troubleshooting.md
- [ ] 新機能のトラブルシューティングを追加

## フェーズ 6: 新規ファイル作成（該当する場合）

- [ ] 大きな新機能用のリファレンスファイルを作成
  ```text
  Write: skills/{対象スキル}/references/{機能名}.md
  ```

- [ ] 対応する SKILL.md のリソースリストに追加

## フェーズ 7: Rules・Enforcement 層の同期

Knowledge 層の変更に合わせて、Rules 層・Enforcement 層も同期する。

### 7a. Rules 層 — 常時ロードルール (rules/) の更新

- [ ] `skills/unity-vrc-udon-sharp/rules/udonsharp-constraints.md` を Knowledge 層と照合
  ```text
  Read: skills/unity-vrc-udon-sharp/rules/udonsharp-constraints.md
  → ブロック機能リスト・利用可能機能リストが最新か確認
  ```

- [ ] `skills/unity-vrc-udon-sharp/rules/udonsharp-networking.md` を Knowledge 層と照合
  ```text
  Read: skills/unity-vrc-udon-sharp/rules/udonsharp-networking.md
  → 同期モード・制限値・アンチパターンが最新か確認
  ```

- [ ] `skills/unity-vrc-udon-sharp/rules/udonsharp-sync-selection.md` を Knowledge 層と照合
  ```text
  Read: skills/unity-vrc-udon-sharp/rules/udonsharp-sync-selection.md
  → データバジェット・デシジョンツリーが最新か確認
  ```

### 7b. Enforcement 層 — バリデーションフック (hooks/) の更新

- [ ] バリデーションフックのルール一覧を Knowledge 層と照合
  ```text
  Read: skills/unity-vrc-udon-sharp/hooks/validate-udonsharp.sh
  Read: skills/unity-vrc-udon-sharp/hooks/validate-udonsharp.ps1
  → 各 grep パターンが現在の制約と一致しているか確認
  ```

- [ ] ブロック解除された機能のルールを削除
  ```text
  例: List<T> が解禁 → "List<" の grep パターンを削除
  ```

- [ ] 新しい制約のルールを追加
  ```text
  例: 新しいブロック機能 → 新しい grep パターンを .sh と .ps1 の両方に追加
  ```

- [ ] 閾値・制限値の更新
  ```text
  例: synced 変数の推奨上限変更 → synced_count の閾値を更新
  ```

- [ ] `.sh` と `.ps1` のルールが同一か確認

### 7c. Enforcement 層 — テンプレート (assets/templates/) の更新

- [ ] 各テンプレートが現在のベストプラクティスに準拠しているか確認
  ```text
  Read: skills/unity-vrc-udon-sharp/assets/templates/BasicInteraction.cs
  Read: skills/unity-vrc-udon-sharp/assets/templates/SyncedObject.cs
  Read: skills/unity-vrc-udon-sharp/assets/templates/PlayerSettings.cs
  Read: skills/unity-vrc-udon-sharp/assets/templates/CustomInspector.cs
  ```

- [ ] 非推奨パターンをテンプレートから除去
- [ ] 新しい推奨パターンをテンプレートに反映
- [ ] テンプレートがバリデーションフックに引っかからないか確認

## フェーズ 8: 検証

- [ ] 全ファイルのSDKバージョン表記を確認
- [ ] 両スキル間の相互参照リンクを確認
- [ ] コードサンプルの構文を確認
- [ ] **3層整合性チェック**:
  - [ ] 制約一覧が Knowledge / Rules / Enforcement で一致
  - [ ] 制限値（synced 変数数、string 長等）が3層で一致
  - [ ] テンプレートがブロック機能を使用していない
  - [ ] フックの全ルールが現在の制約を正しく反映

## フェーズ 9: 完了報告

- [ ] 更新サマリーを作成
  ```markdown
  ## 更新サマリー

  ### unity-vrc-udon-sharp (Knowledge)
  - file1.md: 変更内容

  ### unity-vrc-world-sdk-3 (Knowledge)
  - file2.md: 変更内容

  ### rules/ (Rules)
  - udonsharp-constraints.md: 変更内容

  ### hooks/ (Enforcement)
  - validate-udonsharp.sh: ルール追加/削除
  - validate-udonsharp.ps1: .sh と同期

  ### templates/ (Enforcement)
  - SyncedObject.cs: パターン更新

  ### 新規作成
  - newfile.md: 内容

  ### 主な変更点
  - 変更1
  - 変更2

  ### 3層整合性: OK / NG (詳細)
  ```

## クイックコマンド

### 現在のスキル状態確認
```text
Read: skills/unity-vrc-udon-sharp/SKILL.md
Read: skills/unity-vrc-world-sdk-3/SKILL.md
Glob: skills/unity-vrc-udon-sharp/**/*
Glob: skills/unity-vrc-world-sdk-3/**/*
```

### Enforcement 層の状態確認
```text
Read: skills/unity-vrc-udon-sharp/hooks/validate-udonsharp.sh
Read: skills/unity-vrc-udon-sharp/hooks/validate-udonsharp.ps1
Read: skills/unity-vrc-udon-sharp/rules/udonsharp-constraints.md
Read: skills/unity-vrc-udon-sharp/rules/udonsharp-networking.md
Read: skills/unity-vrc-udon-sharp/rules/udonsharp-sync-selection.md
```

### 最新SDK検索（並列）
```bash
WebSearch: "VRChat SDK 2026 new features updates changelog"
WebSearch: "UdonSharp VRChat SDK 3.11 changes"
WebSearch: "VRChat Worlds SDK 2026 UdonSharp"
WebSearch: "VRChat World SDK components new features 2026"
```
