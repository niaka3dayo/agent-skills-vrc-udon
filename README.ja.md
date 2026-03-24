[English](README.md) | **日本語** | [简体中文](README.zh-CN.md) | [繁體中文](README.zh-TW.md) | [한국어](README.ko.md)

<p align="center">
  <img src="https://img.shields.io/badge/VRChat_SDK-3.7.1--3.10.2-00b4d8?style=for-the-badge" alt="VRChat SDK" />
  <img src="https://img.shields.io/badge/UdonSharp-C%23_%E2%86%92_Udon-5C2D91?style=for-the-badge&logo=csharp&logoColor=white" alt="UdonSharp" />
  <img src="https://img.shields.io/badge/AI_Agent-Skills_%26_Rules-ff6b35?style=for-the-badge" alt="Agent Skills" />
  <img src="https://img.shields.io/github/license/niaka3dayo/agent-skills-vrc-udon?style=for-the-badge" alt="License" />
</p>

<p align="center">
  <img src="https://img.shields.io/npm/v/agent-skills-vrc-udon?style=flat-square&label=npm" alt="npm version" />
  <img src="https://img.shields.io/npm/dm/agent-skills-vrc-udon?style=flat-square&label=downloads" alt="npm downloads" />
  <img src="https://img.shields.io/github/actions/workflow/status/niaka3dayo/agent-skills-vrc-udon/ci.yml?branch=dev&style=flat-square&label=CI" alt="CI" />
</p>

<h1 align="center">Agent Skills for VRChat UdonSharp</h1>

<p align="center">
  <b>AIコーディングエージェントが正しいUdonSharpコードを生成できるようにするスキル・ルール・バリデーションフック集</b>
</p>

<p align="center">
  <a href="#about">概要</a> &bull;
  <a href="#install">インストール</a> &bull;
  <a href="#structure">構成</a> &bull;
  <a href="#skills">スキル</a> &bull;
  <a href="#rules">ルール</a> &bull;
  <a href="#hooks">フック</a> &bull;
  <a href="#contributing">コントリビュート</a> &bull;
  <a href="#disclaimer">免責事項</a>
</p>

---

<h2 id="about">概要</h2>

**UdonSharp**（C# &rarr; Udon Assembly）を使ったVRChatワールド開発には、通常のC#とは大きく異なる厳格なコンパイル制約があります。`List<T>`、`async/await`、`try/catch`、LINQ、ラムダ式などは**コンパイルエラー**になります。

このリポジトリは、AIコーディングエージェントが最初から正しいUdonSharpコードを生成できるよう、必要な知識を提供します。

| 問題 | 解決策 |
|---------|----------|
| AIが `List<T>`、`async/await` 等を生成してしまう | ルール + フックによる自動検出と警告 |
| 同期変数の肥大化 | デシジョンツリー + データバジェット |
| 誤ったネットワーキングパターン | パターンライブラリ + アンチパターン集 |
| SDKバージョンごとの機能差異 | バージョンテーブルと機能マッピング |
| 遅延参加者への状態不整合 | 同期パターン選択フレームワーク |

**このリポジトリは以下ではありません:**
- VRChat SDK または UdonSharp の配布物
- Unityプロジェクト（実行可能なコードは含みません）
- [VRChat公式ドキュメント](https://creators.vrchat.com/) の代替
- AIの全動作を保証するもの

> **Issues**: バグ報告や知識リクエストは [GitHub Issues](https://github.com/niaka3dayo/agent-skills-vrc-udon/issues) からお気軽にどうぞ。
> **PR**: Pull Requestは受け付けていません。詳細は [CONTRIBUTING.md](CONTRIBUTING.md) をご覧ください。

---

<h2 id="install">インストール</h2>

> **フォーク・クローンからの移行をお考えの方へ** &mdash; v1.0.0 以降、このプロジェクトは **npm パッケージ** として配布されています。リポジトリをフォークやクローンする必要はなくなりました。VRChat の Unity プロジェクト内で、以下のいずれかのインストールコマンドを実行するだけで使用できます。以前にこのリポジトリをクローンしていた場合は、クローンしたディレクトリを削除して npm ベースのインストールに切り替えていただけます。

### 方法 1: skills CLI（推奨）

```bash
npx skills add niaka3dayo/agent-skills-vrc-udon
```

[skills.sh](https://skills.sh) エコシステムを使用して、プロジェクトにスキルをインストールします。

### 方法 2: Claude Code プラグイン

```bash
claude plugin add niaka3dayo/agent-skills-vrc-udon
```

### 方法 3: npx 直接インストール

```bash
npx agent-skills-vrc-udon
```

オプション:
```bash
npx agent-skills-vrc-udon --force    # Overwrite existing files
npx agent-skills-vrc-udon --list     # Preview files to install (dry run)
```

### 方法 4: git clone

```bash
git clone https://github.com/niaka3dayo/agent-skills-vrc-udon.git
```

---

<h2 id="structure">構成</h2>

```
skills/                                  # All skills
  unity-vrc-udon-sharp/                 # UdonSharp core skill
    SKILL.md                              # Skill definition + frontmatter
    LICENSE.txt                           # MIT License
    CHEATSHEET.md                         # Quick reference (1 page)
    rules/                               # Constraint rules
      udonsharp-constraints.md
      udonsharp-networking.md
      udonsharp-sync-selection.md
    hooks/                               # PostToolUse validation
      validate-udonsharp.sh
      validate-udonsharp.ps1
    assets/templates/                    # Code templates (4 files)
    references/                          # Detailed documentation (11 files)
  unity-vrc-world-sdk-3/                # VRC World SDK skill
    SKILL.md, LICENSE.txt, CHEATSHEET.md, references/ (7 files)
templates/                               # AI tool config templates
  CLAUDE.md  AGENTS.md  GEMINI.md        # Distributed to users via installer
.claude-plugin/marketplace.json         # Claude Code plugin registration
CLAUDE.md                               # Development guide (this repo only)
```

---

<h2 id="skills">スキル</h2>

### unity-vrc-udon-sharp

UdonSharpスクリプティングのコアスキルです。コンパイル制約、ネットワーキング、イベント、テンプレートをカバーします。

| 分野 | 内容 |
|------|---------|
| **制約** | 使用不可なC#機能と代替手段（`List<T>` &rarr; `DataList`、`async` &rarr; `SendCustomEventDelayedSeconds`） |
| **ネットワーキング** | オーナーシップモデル、Manual/Continuousシンク、FieldChangeCallback、アンチパターン |
| **NetworkCallable** | SDK 3.8.1以降のパラメータ付きネットワークイベント（最大8引数） |
| **パーシスタンス** | SDK 3.7.4以降のPlayerData/PlayerObject API |
| **ダイナミクス** | SDK 3.10.0以降のPhysBones、Contacts、ワールド向けVRC Constraints |
| **Webローディング** | 文字列・画像ダウンロード、VRCJson、VRCUrlの制約 |
| **テンプレート** | スターターテンプレート4種（BasicInteraction、SyncedObject、PlayerSettings、CustomInspector） |

### unity-vrc-world-sdk-3

ワールドレベルのシーン設定、コンポーネント配置、最適化を扱うスキルです。

| 分野 | 内容 |
|------|---------|
| **シーン設定** | VRC_SceneDescriptor、スポーンポイント、Reference Camera |
| **コンポーネント** | VRC_Pickup、Station、ObjectSync、Mirror、Portal、CameraDolly |
| **レイヤー** | VRChat予約レイヤーとコリジョンマトリクス |
| **パフォーマンス** | FPS目標値、Quest/Android制限、最適化チェックリスト |
| **ライティング** | ベイクドライティングのベストプラクティス |
| **オーディオ/ビデオ** | 空間オーディオ、ビデオプレイヤー選択（AVPro vs Unity） |
| **アップロード** | ビルドとアップロードのワークフロー、アップロード前チェックリスト |

---

<h2 id="rules">ルール</h2>

ルールは、AIエージェントがコードを生成する前に参照する制約ファイルです。

| ルールファイル | 内容 |
|-----------|---------|
| `udonsharp-constraints` | 使用不可なC#機能、コード生成ルール、属性、同期可能な型 |
| `udonsharp-networking` | オーナーシップモデル、シンクモード、アンチパターン、NetworkCallableの制約 |
| `udonsharp-sync-selection` | 同期デシジョンツリー、データバジェット目標値、6つの最小化原則 |

### 同期デシジョンツリー

```
Q1: 他プレイヤーから見える必要がありますか？
    No  --> 同期不要（0バイト）
    Yes --> Q2

Q2: 遅延参加者が現在の状態を知る必要がありますか？
    No  --> イベントのみ（0バイト）
    Yes --> Q3

Q3: 継続的に変化しますか？（位置・回転など）
    Yes --> Continuous同期
    No  --> Manual同期（最小限の [UdonSynced]）
```

**目標値**: ビヘイビアあたり50バイト未満。小〜中規模のワールド全体では100バイト未満。

---

<h2 id="hooks">バリデーションフック</h2>

`.cs` ファイルを編集した際に自動実行される PostToolUse フックです。

| カテゴリ | チェック内容 | 重大度 |
|----------|-------|----------|
| 使用禁止機能 | `List<T>`、`async/await`、`try/catch`、LINQ、コルーチン、ラムダ式 | ERROR |
| 使用禁止パターン | `AddListener()`、`StartCoroutine()` | ERROR |
| ネットワーキング | `RequestSerialization()` なしの `[UdonSynced]` | WARNING |
| ネットワーキング | `Networking.SetOwner()` なしの `[UdonSynced]` | WARNING |
| 同期の肥大化 | ビヘイビアあたり6つ以上の同期変数 | WARNING |
| 同期の肥大化 | `int[]`/`float[]` 同期（より小さい型を推奨） | WARNING |
| 設定の不整合 | `NoVariableSync` モードと `[UdonSynced]` フィールドの併用 | ERROR |

**Bash**（`validate-udonsharp.sh`）と **PowerShell**（`validate-udonsharp.ps1`）の両方に対応しています。

---

## SDKバージョン

| SDKバージョン | 主な機能 | ステータス |
|:-----------:|:-------------|:------:|
| **3.7.1** | `StringBuilder`、`Regex`、`System.Random` | サポート済み |
| **3.7.4** | Persistence API（PlayerData / PlayerObject） | サポート済み |
| **3.7.6** | マルチプラットフォームビルド＆パブリッシュ（PC + Android） | サポート済み |
| **3.8.0** | PhysBone依存関係ソート、Force Kinematic On Remote | サポート済み |
| **3.8.1** | `[NetworkCallable]` パラメータ付きイベント、`Others`/`Self` ターゲット | サポート済み |
| **3.9.0** | Camera Dolly API、Auto Hold Pickup | サポート済み |
| **3.10.0** | ワールド向けVRChat Dynamics（PhysBones、Contacts、VRC Constraints） | サポート済み |
| **3.10.1** | バグ修正、安定性の向上 | サポート済み |
| **3.10.2** | EventTiming.PostLateUpdate/FixedUpdate、PhysBones修正、シェーダー時間グローバル | 最新安定版 |

> **注意**: SDK 3.9.0未満は2025年12月2日に非推奨となりました。新規ワールドのアップロードには3.9.0以上が必要です。

---

## 公式リソース

| リソース | URL |
|----------|-----|
| VRChat クリエイターズドキュメント | https://creators.vrchat.com/ |
| UdonSharp APIリファレンス | https://udonsharp.docs.vrchat.com/ |
| VRChatフォーラム（Q&A） | https://ask.vrchat.com/ |
| VRChat Canny（バグ・機能要望） | https://feedback.vrchat.com/ |
| VRChat コミュニティGitHub | https://github.com/vrchat-community |

---

<h2 id="contributing">コントリビュート</h2>

**Issuesは歓迎します** -- バグ報告や知識リクエストはプロジェクトの改善に役立ちます。

**Pull Requestは受け付けていません** -- すべての修正と更新はメンテナーが行います。

詳細は [CONTRIBUTING.md](CONTRIBUTING.md) をご覧ください。

---

<h2 id="disclaimer">免責事項</h2>

> **このプロジェクトはVRChat Inc.とは一切関係なく、公式の推薦・パートナーシップ・関連性を示すものではありません。**
>
> 「VRChat」「UdonSharp」「Udon」および関連する名称・ロゴはVRChat Inc.の商標です。すべての商標はそれぞれの権利者に帰属します。
>
> このリポジトリは、AIコーディングエージェントが正しいUdonSharpコードを生成するための**個人的なナレッジベース**です。VRChat SDKやUdonSharpコンパイラのいかなる部分も配布しません。

### 正確性について

- コンテンツは**「現状のまま」**提供されており、いかなる保証もありません。[LICENSE](LICENSE) をご確認ください。
- これは個人プロジェクトです。**誤り、古くなった情報、または不完全な内容が含まれる可能性があります。** 常に[VRChat公式ドキュメント](https://creators.vrchat.com/)で確認してください。
- このリポジトリが原因で生じた問題（ビルドエラー、アップロード拒否、予期しないワールドの動作など）について、作者は一切責任を負いません。
- SDKカバレッジ（3.7.1〜3.10.2）は最終更新時点のものです。新しいVRChatリリースで動作が変わる可能性があります。

### AI支援による作成

このナレッジベースはAIツール（Claude、Gemini、Codex）の支援を受けて作成・メンテナンスされています。すべてのコンテンツはレビュー済みですが、AI生成部分に微妙な誤りが含まれる可能性があります。自己責任でご利用ください。

---

## ライセンス

このプロジェクトは **MIT ライセンス** の下で提供されています。詳細は [LICENSE](LICENSE) をご覧ください。

MIT ライセンスの条件のもとで、自由にフォーク・改変・再配布していただけます。このライセンスはリポジトリ内のドキュメント、ルール、テンプレート、フックに適用されます。VRChat の SDK、UdonSharp コンパイラ、またはその他の VRChat 知的財産に対するいかなる権利も付与しません。
