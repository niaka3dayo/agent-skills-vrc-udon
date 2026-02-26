<p align="center">
  <img src="https://img.shields.io/badge/VRChat_SDK-3.7.1--3.10.1-00b4d8?style=for-the-badge" alt="VRChat SDK" />
  <img src="https://img.shields.io/badge/UdonSharp-C%23_%E2%86%92_Udon-5C2D91?style=for-the-badge&logo=csharp&logoColor=white" alt="UdonSharp" />
  <img src="https://img.shields.io/badge/AI_Agent-Skills_%26_Rules-ff6b35?style=for-the-badge" alt="Agent Skills" />
  <img src="https://img.shields.io/github/license/niaka3dayo/agent-skills-vrc-udon?style=for-the-badge" alt="License" />
</p>

<h1 align="center">Agent Skills for VRChat UdonSharp</h1>

<p align="center">
  <b>AI エージェントが UdonSharp コードを正しく生成するためのスキル・ルール・バリデーションフック集</b>
</p>

<p align="center">
  <a href="#このリポジトリについて">About</a> &bull;
  <a href="#概要">概要</a> &bull;
  <a href="#対応-ai-ツール">対応ツール</a> &bull;
  <a href="#リポジトリ構成">構成</a> &bull;
  <a href="#スキル一覧">スキル</a> &bull;
  <a href="#ルール自動ロード">ルール</a> &bull;
  <a href="#バリデーションフック">フック</a> &bull;
  <a href="#免責事項">免責</a>
</p>

<details>
<summary><b>English Summary</b> (click to expand)</summary>

This repository provides **skills, rules, and validation hooks** for AI coding agents (Claude Code, Codex CLI, Gemini CLI, etc.) to generate correct **UdonSharp** code for VRChat world development.

UdonSharp compiles C# to Udon Assembly but blocks many standard C# features (`List<T>`, `async/await`, `try/catch`, LINQ, lambdas, etc.). The included rules and hooks automatically detect these violations and guide the AI toward correct alternatives.

**Key features:**
- 3 skills: UdonSharp coding, VRC World SDK setup, skill self-maintenance
- 3 auto-loaded rule files: compile constraints, networking patterns, sync selection
- PostToolUse validation hooks (Bash + PowerShell)
- SDK 3.7.1 - 3.10.1 coverage
- Single source of truth in `agent-docs/`, symlinked to each AI tool directory

**License:** MIT -- free to fork and modify. This is a personal project; Issues and PRs are not accepted.

**Disclaimer:** Not affiliated with VRChat Inc. Content is provided "AS IS" and may contain errors. Always verify against official VRChat documentation.

</details>

---

## このリポジトリについて

本リポジトリは **Zenn 記事の補助資料** として公開している個人プロジェクトです。

> Zenn 記事 URL は記事公開後に追記予定です。

**このリポジトリは、つまり何？**
- 記事用のサンプルリポジトリです
- 個人プロジェクトとして公開しています
- **フォーク・改変は MIT License の範囲で自由** にどうぞ

**注意点**
- VRChat SDK や UdonSharp の配布物ではありません
- Unity プロジェクトではありません
- [公式 VRChat ドキュメント](https://creators.vrchat.com/) の代替ではありません
- すべてのAIの動作を完全に保証するものではありません。

> **Issue / PR について**: 本リポジトリでは **Issue・Pull Request は受け付けていません**。
> 誤りを見つけた場合は、フォークして修正するか、記事のコメント欄でお知らせください。

---

## 概要

VRChat のワールド開発で使われる **UdonSharp** (C# &rarr; Udon Assembly) は、標準 C# と大きく異なる制約があります。
通常の C# では問題ない `List<T>`、`async/await`、`try/catch`、LINQ、ラムダ式などが **コンパイルエラー** になります。

このリポジトリは、AI コーディングエージェントがこれらの制約を理解し、**最初から正しいコードを生成する** ためのスキル・ルール・バリデーションフックを提供します。

### 解決する課題

| 課題 | 解決策 |
|------|--------|
| AI が `List<T>`, `async/await` 等を生成してしまう | ルール + フックで自動検出・警告 |
| 同期変数の肥大化 (Sync Bloat) | デシジョンツリー + データバジェット |
| 不適切なネットワークパターン | パターンライブラリとアンチパターン集 |
| SDK バージョンごとの機能差 | バージョンテーブルで機能対応を明示 |
| Late Joiner の状態不整合 | 同期パターン選択フレームワーク |

---

## 使い方

### 1. VRChat Unity プロジェクトに clone する (推奨)

```bash
# Unity プロジェクトのルートで実行
git clone https://github.com/niaka3dayo/agent-skills-vrc-udon.git .agent-skills
```

AI ツールの設定ディレクトリをシンボリックリンクで配置するか、必要なファイルをコピーしてください。

### 2. 単体リファレンスとして使う

```bash
git clone https://github.com/niaka3dayo/agent-skills-vrc-udon.git
cd agent-skills-vrc-udon
```

`agent-docs/` が唯一の正本です。各 AI ツールのディレクトリ (`.claude/`, `.agents/`, `.gemini/`, `.codex/`) はすべて `agent-docs/` へのシンボリックリンクです。

---

## 対応 AI ツール

`agent-docs/` を唯一の正本とし、各ツールへシンボリックリンクで配信しています。

| AI ツール | 設定ファイル | ルール | スキル |
|-----------|-------------|--------|--------|
| **Claude Code** | `CLAUDE.md` | `.claude/rules/` | `.claude/skills/` |
| **Codex CLI** | `AGENTS.md` | `.agents/rules/` | `.agents/skills/` |
| **Gemini CLI** | `GEMINI.md` | `.gemini/rules/` | `.gemini/skills/` |
| **その他** | `AGENTS.md` | `.codex/rules/` | `.codex/skills/` |

---

## リポジトリ構成

```
agent-docs/                              # 正本 (Single Source of Truth)
  skills/
    unity-vrc-udon-sharp/               # UdonSharp コアスキル
      SKILL.md                            # スキル定義・エントリーポイント
      CHEATSHEET.md                       # クイックリファレンス (1ページ)
      rules/                             # 自動ロードルール
        udonsharp-constraints.md           # ブロック機能、属性、同期可能な型
        udonsharp-networking.md            # オーナーシップ、同期モード、NetworkCallable
        udonsharp-sync-selection.md        # 同期パターンデシジョンツリー、データバジェット
      hooks/                             # PostToolUse バリデーション
        validate-udonsharp.sh              # Linux / macOS
        validate-udonsharp.ps1             # Windows (PowerShell)
      assets/templates/                  # コードテンプレート
        BasicInteraction.cs
        SyncedObject.cs
        PlayerSettings.cs
        CustomInspector.cs
      references/                        # 詳細リファレンス
        constraints.md                     # C# 機能の互換性リスト
        networking.md                      # ネットワーキングパターン (NetworkCallable 含む)
        persistence.md                     # PlayerData / PlayerObject (SDK 3.7.4+)
        dynamics.md                        # PhysBones, Contacts (SDK 3.10.0+)
        web-loading.md                     # String/Image ダウンロード、VRCJson、VRCUrl
        events.md                          # 全 Udon イベント
        api.md                             # VRCPlayerApi, Networking, enums
        patterns.md                        # コードパターン集
        sync-examples.md                   # 同期パターン例
        editor-scripting.md                # エディタスクリプティング
        troubleshooting.md                 # よくあるエラーと解決策
    unity-vrc-world-sdk-3/              # VRC World SDK スキル
      SKILL.md
      CHEATSHEET.md
      references/
        components.md, layers.md, performance.md,
        lighting.md, audio-video.md, upload.md, troubleshooting.md
    unity-vrc-skills-renovator/         # スキル自己メンテナンス用メタスキル
      SKILL.md
      references/
        changelog-sources.md, search-queries.md,
        skill-structure.md, update-checklist.md

.claude/  .agents/  .codex/  .gemini/   # agent-docs/ へのシンボリックリンク
  rules/   -> agent-docs/skills/unity-vrc-udon-sharp/rules/
  skills/  -> agent-docs/skills/

CLAUDE.md   AGENTS.md   GEMINI.md        # 各ツール用プロジェクト設定
```

---

## スキル一覧

### unity-vrc-udon-sharp

UdonSharp スクリプティングのコアスキル。コンパイル制約、ネットワーキング、イベント、テンプレートを網羅。

| 領域 | 内容 |
|------|------|
| **制約** | ブロックされる C# 機能と代替手段 (`List<T>` &rarr; `DataList`, `async` &rarr; `SendCustomEventDelayedSeconds` 等) |
| **ネットワーキング** | オーナーシップモデル、Manual / Continuous 同期、FieldChangeCallback、アンチパターン |
| **NetworkCallable** | SDK 3.8.1+ パラメータ付きネットワークイベント (最大 8 引数) |
| **永続化** | SDK 3.7.4+ PlayerData / PlayerObject API |
| **Dynamics** | SDK 3.10.0+ PhysBones, Contacts, VRC Constraints for Worlds |
| **Web Loading** | String / Image ダウンロード、VRCJson、VRCUrl の制約 |
| **テンプレート** | 4 種のスターターテンプレート (BasicInteraction, SyncedObject, PlayerSettings, CustomInspector) |

### unity-vrc-world-sdk-3

ワールドレベルのシーン設定、コンポーネント配置、最適化。

| 領域 | 内容 |
|------|------|
| **シーン設定** | VRC_SceneDescriptor、スポーン地点、Reference Camera |
| **コンポーネント** | VRC_Pickup, Station, ObjectSync, Mirror, Portal, CameraDolly |
| **レイヤー** | VRChat 予約レイヤーとコリジョンマトリックス |
| **パフォーマンス** | FPS 目標、Quest/Android 制限、最適化チェックリスト |
| **ライティング** | ベイクドライティングのベストプラクティス |
| **オーディオ/ビデオ** | 空間オーディオ、ビデオプレイヤー選択 (AVPro vs Unity) |
| **アップロード** | ビルド・アップロード手順、事前チェックリスト |

### unity-vrc-skills-renovator

スキル自体をメンテナンスするためのメタスキル。3 つの柱で知識を最新に保つ。

| 柱 | 目的 |
|----|------|
| **充填** | 不足している知識の追加 (新 SDK の API、パターン、Tips) |
| **刷新** | 古くなった情報の更新 (バージョン表記、非推奨 API の除去) |
| **品質向上** | 既存の記述の改善 (コード例の追加、説明の明確化) |

---

## ルール（自動ロード）

ルールは AI エージェントのコンテキストに**自動的にロード**され、コード生成前のガードレールとして機能します。

| ルールファイル | 内容 |
|---------------|------|
| `udonsharp-constraints` | ブロックされる C# 機能、コード生成ルール、属性、同期可能な型 |
| `udonsharp-networking` | オーナーシップモデル、同期モード、アンチパターン、NetworkCallable の制約 |
| `udonsharp-sync-selection` | 同期デシジョンツリー、データバジェット目標、6 つの最小化原則 |

### 同期デシジョンツリー

```
Q1: 他プレイヤーに見える?
    No  --> 同期なし (0 bytes)
    Yes --> Q2

Q2: Late Joiner に現在の状態が必要?
    No  --> イベントのみ (0 bytes)
    Yes --> Q3

Q3: 連続的に変化する? (位置・回転)
    Yes --> Continuous sync
    No  --> Manual sync (最小限の [UdonSynced])
```

**目標**: 1 behaviour あたり 50 bytes 未満。小〜中規模ワールドの合計: 100 bytes 未満が一般的。

---

## バリデーションフック

`.cs` ファイル編集時に自動実行される PostToolUse バリデーションフック。

| カテゴリ | チェック内容 | 深刻度 |
|----------|-------------|--------|
| ブロック機能 | `List<T>`, `async/await`, `try/catch`, LINQ, コルーチン, ラムダ | ERROR |
| ブロックパターン | `AddListener()`, `StartCoroutine()` | ERROR |
| ネットワーキング | `[UdonSynced]` に `RequestSerialization()` がない | WARNING |
| ネットワーキング | `[UdonSynced]` に `Networking.SetOwner()` がない | WARNING |
| 同期肥大化 | 1 behaviour に 6 個以上の synced 変数 | WARNING |
| 同期肥大化 | `int[]`/`float[]` の同期 (より小さい型を推奨) | WARNING |
| 設定矛盾 | `NoVariableSync` モードで `[UdonSynced]` フィールドを使用 | ERROR |

**Bash** (`validate-udonsharp.sh`) と **PowerShell** (`validate-udonsharp.ps1`) の両方に対応。

---

## SDK 対応バージョン

| SDK バージョン | 主な機能 | 状態 |
|:-------------:|:---------|:----:|
| **3.7.1** | `StringBuilder`, `Regex`, `System.Random` | 対応 |
| **3.7.4** | Persistence API (PlayerData / PlayerObject) | 対応 |
| **3.7.6** | マルチプラットフォーム Build & Publish (PC + Android) | 対応 |
| **3.8.0** | PhysBone 依存関係ソート、Force Kinematic On Remote | 対応 |
| **3.8.1** | `[NetworkCallable]` パラメータ付きイベント、`Others`/`Self` ターゲット | 対応 |
| **3.9.0** | Camera Dolly API、Auto Hold ピックアップ | 対応 |
| **3.10.0** | VRChat Dynamics for Worlds (PhysBones, Contacts, VRC Constraints) | 対応 |
| **3.10.1** | バグ修正・安定性改善 | 最新安定 |

> **注意**: SDK 3.9.0 未満は **2025 年 12 月 2 日をもって非推奨** になりました。新規ワールドのアップロードには 3.9.0 以上が必要です。

---

## 公式リソース

| リソース | URL |
|----------|-----|
| VRChat Creators Docs | https://creators.vrchat.com/ |
| UdonSharp API Reference | https://udonsharp.docs.vrchat.com/ |
| VRChat Forums (Q&A) | https://ask.vrchat.com/ |
| VRChat Canny (バグ/機能リクエスト) | https://feedback.vrchat.com/ |
| VRChat Community GitHub | https://github.com/vrchat-community |

---

## 免責事項

> **本プロジェクトは VRChat Inc. とは一切関係ありません。公式の承認・提携・関連はありません。**
>
> 「VRChat」「UdonSharp」「Udon」およびその関連名称・ロゴは VRChat Inc. の商標または登録商標です。すべての商標はそれぞれの所有者に帰属します。
>
> 本リポジトリは、AI コーディングエージェントが正しい UdonSharp コードを生成するための **個人制作のナレッジベース** です。VRChat SDK や UdonSharp コンパイラの一部を配布するものではありません。

### 正確性について

- 本リポジトリの情報は **「現状のまま (AS IS)」** 提供されており、いかなる保証もありません。[LICENSE](LICENSE) を参照してください。
- 個人プロジェクトのため、**誤り・古い情報・不完全な記述が含まれる可能性があります**。必ず [公式 VRChat ドキュメント](https://creators.vrchat.com/) で確認してください。
- 本リポジトリの利用に起因する問題（ビルドエラー、ワールドアップロードの拒否、ワールド内での想定外の挙動など）について、著者は一切の責任を負いません。
- SDK 対応バージョン (3.7.1 - 3.10.1) は最終更新時点の情報です。VRChat が新バージョンをリリースした場合、挙動が変わる可能性があります。

### AI による作成支援について

本ナレッジベースは AI ツール (Claude, Gemini, Codex) の支援を受けて作成・メンテナンスしています。すべての内容をレビューしていますが、AI が生成した部分に微細な誤りが含まれる可能性があります。ご利用は自己責任でお願いします。

---

## ライセンス

本プロジェクトは **MIT License** で公開しています。詳細は [LICENSE](LICENSE) を参照してください。

フォーク・改変・再配布は MIT License の条件の下で自由です。このライセンスは本リポジトリ内のドキュメント・ルール・テンプレート・フックに適用されます。VRChat の SDK、UdonSharp コンパイラ、その他 VRChat の知的財産に対する権利を付与するものでは **ありません**。
