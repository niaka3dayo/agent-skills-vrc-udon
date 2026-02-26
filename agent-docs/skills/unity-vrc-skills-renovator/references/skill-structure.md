# VRCスキルの構造テンプレート

更新対象スキルのファイル構造と各ファイルの役割。

> **パス表記について**: 本ドキュメント内の `skills/` は `agent-docs/skills/` を指す。
> `rules/` は `skills/unity-vrc-udon-sharp/rules/` 配下に統合されている。
> エージェントからは `.claude/skills/`、`.claude/rules/` (シンボリックリンク) 経由でもアクセス可能。

## unity-vrc-udon-sharp

```text
unity-vrc-udon-sharp/
├── SKILL.md                    # メイン定義ファイル
├── CHEATSHEET.md               # 1ページクイックリファレンス
├── rules/                      # 常時ロードルール (Rules 層)
│   ├── udonsharp-constraints.md    # ブロック機能、コード生成ルール、属性、同期可能型
│   ├── udonsharp-networking.md     # オーナーシップ、同期モード、NetworkCallable
│   └── udonsharp-sync-selection.md # 同期パターン選択、データバジェット、最小化原則
├── hooks/                      # Enforcement 層 - バリデーションフック
│   ├── validate-udonsharp.sh   # PostToolUse バリデーションフック (Linux/macOS)
│   └── validate-udonsharp.ps1  # PostToolUse バリデーションフック (Windows)
├── assets/                     # Enforcement 層 - テンプレート
│   └── templates/
│       ├── BasicInteraction.cs # 基本インタラクションテンプレート
│       ├── SyncedObject.cs     # ネットワーク同期テンプレート
│       ├── PlayerSettings.cs   # プレイヤー設定テンプレート
│       └── CustomInspector.cs  # カスタムインスペクターテンプレート
└── references/                 # Knowledge 層 - リファレンスドキュメント
    ├── constraints.md          # C#機能の制約リスト
    ├── networking.md           # ネットワーキングガイド
    ├── events.md               # イベントリファレンス
    ├── api.md                  # VRChat APIリファレンス
    ├── patterns.md             # コードパターン集
    ├── troubleshooting.md      # トラブルシューティング
    ├── web-loading.md          # String/Image ダウンロード、VRCJson
    ├── editor-scripting.md     # エディタスクリプティング
    ├── persistence.md          # 永続化ガイド (SDK 3.7.4+)
    └── dynamics.md             # Dynamics ガイド (SDK 3.10.0+)
```

### 各ファイルの役割

#### Knowledge 層 (ドキュメント)

| ファイル | 目的 | 更新ポイント |
|----------|------|--------------|
| SKILL.md | エントリーポイント、SDK対応バージョン | バージョン番号、新機能サマリー |
| CHEATSHEET.md | クイックリファレンス | 新パターン、新イベント、新エラー |
| constraints.md | C# 機能の可否リスト | 使えるようになった機能を移動 |
| networking.md | ネットワーキング詳細 | 新ネットワーク機能、データ制限変更 |
| events.md | 全イベントリファレンス | 新イベント追加、パラメータ変更 |
| api.md | VRChat 固有 API 詳細 | 新 API クラス/メソッド |
| patterns.md | 実用コードパターン | 新機能のパターン |
| troubleshooting.md | エラーと解決策 | 新機能のトラブルシューティング |

#### Enforcement 層 (実行される検証・テンプレート)

| ファイル | 目的 | 更新ポイント |
|----------|------|--------------|
| hooks/validate-udonsharp.sh | PostToolUse 自動バリデーション (Linux/macOS) | 制約変更時にルール追加/削除 |
| hooks/validate-udonsharp.ps1 | PostToolUse 自動バリデーション (Windows) | .sh と同じルールを同期 |
| assets/templates/*.cs | コード生成の見本テンプレート | 新APIパターン反映、非推奨パターン除去 |

## unity-vrc-world-sdk-3

```text
unity-vrc-world-sdk-3/
├── SKILL.md                    # メイン定義ファイル
├── CHEATSHEET.md               # 1ページクイックリファレンス
└── references/
    ├── components.md           # VRCコンポーネント詳細
    ├── layers.md               # レイヤー・コリジョンマトリックス
    ├── performance.md          # パフォーマンス最適化
    ├── lighting.md             # ライティング設定
    ├── audio-video.md          # オーディオ・ビデオ設定
    ├── upload.md               # アップロード手順
    └── troubleshooting.md      # トラブルシューティング
```

### 各ファイルの役割

| ファイル | 目的 | 更新ポイント |
|----------|------|--------------|
| SKILL.md | エントリーポイント、SDK対応バージョン | バージョン番号、新機能サマリー |
| CHEATSHEET.md | クイックリファレンス | 新コンポーネント、設定変更 |
| components.md | VRCコンポーネント詳細 | 新コンポーネント、プロパティ変更 |
| layers.md | レイヤー・コリジョン | レイヤー変更、コリジョン設定 |
| performance.md | 最適化ガイド | 新ガイドライン、制限値変更 |
| lighting.md | ライティング設定 | 新ライティング機能 |
| audio-video.md | オーディオ・ビデオ | 新機能、設定変更 |
| upload.md | アップロード手順 | 手順変更、新要件 |
| troubleshooting.md | 問題解決 | 新エラー→解決策 |

## 常時ロードルール (Rules 層)

常時コンテキストにロードされるルールファイルは `unity-vrc-udon-sharp/rules/` に配置されている。
`.claude/rules/`、`.agents/rules/` 等のシンボリックリンク経由で会話開始時に自動ロードされる。
スキル更新時はこれらも必ず同期すること。

| ファイル | 目的 | 更新ポイント |
|----------|------|--------------|
| udonsharp-constraints.md | コンパイル制約の常時参照 | ブロック機能の追加/解除、新属性 |
| udonsharp-networking.md | ネットワーキング基本ルール | 新同期モード、制限値変更 |
| udonsharp-sync-selection.md | 同期パターン判断基準 | データバジェット変更、新パターン |

### 3層の整合性ルール

Knowledge / Rules / Enforcement の3層は必ず同じ事実を反映すること:

| 変更例 | Knowledge 層 | Rules 層 | Enforcement 層 |
|--------|:---:|:---:|:---:|
| 機能がブロック解除 | constraints.md 更新 | udonsharp-constraints.md 更新 | フックからルール削除 |
| 新しい制約追加 | constraints.md 追加 | udonsharp-constraints.md 追加 | フックにルール追加 |
| 新 API パターン | patterns.md 追加 | (該当あれば更新) | テンプレート追加/更新 |
| データ制限値変更 | networking.md 更新 | udonsharp-sync-selection.md 更新 | フックの閾値更新 |

## 共通ルール

### バージョン表記の統一

各ファイルの冒頭に:

```markdown
**対応SDKバージョン**: 3.7.1 - 3.X.X (20XX年X月時点)
```

SDK固有機能には:

```markdown
### 機能名 (SDK 3.X.X+)
```

### 新規ファイル作成の基準

以下の場合は対応するスキルの `references/` に新ファイルを作成:

1. **大きな新機能カテゴリ** — 例: Persistence (SDK 3.7.4), Dynamics (SDK 3.10.0)
2. **複数の関連コンポーネント** — 例: PhysBones + Contacts + Constraints → dynamics.md
3. **独立した設定/概念** — 例: PlayerData vs PlayerObject → persistence.md

### ファイル間の相互参照

参照時は相対パスを使用:

```markdown
詳細は `references/networking.md` を参照。
```

新機能を追加した場合、以下のファイルで言及を追加:
1. SKILL.md (Resources セクション)
2. CHEATSHEET.md (関連セクション)
3. 関連する既存リファレンスファイル
4. rules/ の該当ファイル (制約・ネットワーキング関連の場合)
5. hooks/ のバリデーションルール (制約変更の場合、.sh と .ps1 の両方)
6. assets/templates/ のテンプレート (パターン変更の場合)
