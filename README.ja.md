[English](README.md) | **日本語** | [简体中文](README.zh-CN.md) | [繁體中文](README.zh-TW.md) | [한국어](README.ko.md)

<p align="center">
  <img src="https://img.shields.io/badge/VRChat_SDK-3.10.4-00b4d8?style=for-the-badge" alt="VRChat SDK" />
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

**UdonSharp**（C# &rarr; Udon Assembly）を使ったVRChatワールド開発には、通常のC#とは大きく異なる厳格なコンパイル制約があります。Udon runtimeで実行されるコードでは、`List<T>`、`async/await`、`try/catch`、LINQ、ラムダ式などは**コンパイルエラー**になります。一方、Editorで評価されるフィールド初期化子は別のC#実行コンテキストであり、最終的にUdonが保持できるフィールド値を生成するために一部の機能を使用できます。

このリポジトリは、AIコーディングエージェントが最初から正しいUdonSharpコードを生成できるよう、必要な知識を提供します。

| 問題 | 解決策 |
|---------|----------|
| AIがUdon runtimeコードに `List<T>`、`async/await` 等を生成してしまう | ルール + フックによる自動検出と警告 |
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

### 方法 3: git clone

```bash
git clone https://github.com/niaka3dayo/agent-skills-vrc-udon.git
```

### 特定バージョンのインストール

公開済みの全バージョンは npm と git タグの両方に恒久的に残ります。削除されることはありません。

```bash
# npm（v1.0.0 以降の任意の公開バージョン）
npm install agent-skills-vrc-udon@2.3.0

# git タグ
git clone --branch v2.3.0 https://github.com/niaka3dayo/agent-skills-vrc-udon.git
```

---

<h2 id="structure">構成</h2>

```
skills/                                  # すべてのスキル
  unity-vrc-udon-sharp/                 # UdonSharpコアスキル
    SKILL.md                              # スキル定義 + フロントマター
    LICENSE.txt                           # MITライセンス
    CHEATSHEET.md                         # クイックリファレンス（1ページ）
    rules/                               # 制約ルール
      udonsharp-constraints.md
      udonsharp-networking.md
      udonsharp-sync-selection.md
    hooks/                               # PostToolUseバリデーション
      validate-udonsharp.sh
      validate-udonsharp.ps1
    assets/templates/                    # コードテンプレート（17ファイル）
    references/                          # 詳細ドキュメント（25ファイル）
  unity-vrc-world-sdk-3/                # VRC World SDKスキル
    SKILL.md, LICENSE.txt, CHEATSHEET.md, references/（8ファイル）
templates/                               # AIツール設定テンプレート
  CLAUDE.md  AGENTS.md  GEMINI.md        # インストーラー経由でユーザーに配布
.claude-plugin/marketplace.json         # Claude Codeプラグイン登録
CLAUDE.md                               # 開発ガイド（このリポジトリ専用）
```

---

<h2 id="skills">スキル</h2>

### unity-vrc-udon-sharp

UdonSharpスクリプティングのコアスキルです。コンパイル制約、ネットワーキング、イベント、テンプレートをカバーします。

| 分野 | 内容 |
|------|---------|
| **制約** | Udon runtimeで使用不可なC#機能と代替手段（`List<T>` &rarr; `DataList`、`async` &rarr; `SendCustomEventDelayedSeconds`）、Editorで評価される初期化子との境界 |
| **ネットワーキング** | オーナーシップモデル、Manual/Continuousシンク、FieldChangeCallback、アンチパターン |
| **NetworkCallable** | SDK 3.8.1で導入されたパラメータ付きネットワークイベント（最大8引数） |
| **パーシスタンス** | SDK 3.7.4で導入されたPlayerData/PlayerObject API |
| **ダイナミクス** | SDK 3.10.0で導入されたPhysBones、Contacts、ワールド向けVRC Constraints |
| **Webローディング** | 文字列・画像ダウンロード、VRCJson、VRCUrlの制約 |
| **テンプレート** | 17種のテンプレート（インタラクション、同期パターン、永続化、エディタユーティリティなど） |

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

**ネットワーク規則:** 先頭が `_` でない引数なしの `public` メソッドは、従来方式のネットワーク呼び出し対象になります。ローカル専用や独自の `public` メソッドには `_` を付け、`[NetworkCallable]` で必要な入口だけを明示的に公開してください。送信者の権限を判定するときは、まず `NetworkCalling.InNetworkCall` を確認してから `NetworkCalling.CallingPlayer` を読み、受信側の所有権とは分けて確認します。インスタンスマスターをセキュリティやアクセス制御の境界にしてはいけません。

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
| 文脈依存の機能 | `List<T>`、LINQ、ラムダ式（Udon runtimeでは使用不可。Editorで評価されるフィールド初期化子では有効な場合あり） | WARNING |
| Runtime使用禁止機能 | `async/await`、`try/catch`、コルーチン | ERROR |
| 使用禁止パターン | `AddListener()`、`StartCoroutine()` | ERROR |
| ネットワーキング | `RequestSerialization()` なしの `[UdonSynced]` | WARNING |
| ネットワーキング | `Networking.SetOwner()` なしの `[UdonSynced]` | WARNING |
| 同期の肥大化 | ビヘイビアあたり6つ以上の同期変数 | WARNING |
| 同期の肥大化 | `int[]`/`float[]` 同期（より小さい型を推奨） | WARNING |
| 設定の不整合 | `NoVariableSync` モードと `[UdonSynced]` フィールドの併用 | ERROR |

**Bash**（`validate-udonsharp.sh`）と **PowerShell**（`validate-udonsharp.ps1`）の両方に対応しています。

Bash版の検証には `jq` が必要です。利用できない場合は入力を変更せずに通し、
検証済みとは扱わず `VALIDATOR-WARNING: validation skipped
(JQ_UNAVAILABLE)` を出力します。

---

## SDKバージョン

**現在のサポート対象 / 最終検証済み**: VRChat SDK 3.10.4

v4.0.0以降は最新の安定版SDKのみをサポートし、新しい安定版への切り替えはこのリポジトリで検証してから行います。安定版になっただけで自動的にサポート対象へ追加することはありません。現在の最終検証済みは3.10.4です。

以下の表には、移行時の参考になる機能追加の履歴を残しています。SDK 3.7.1〜3.10.3は履歴情報のみで、このSkillのサポート対象・検証対象ではありません。これはSkill自身のサポート範囲であり、VRChatのSDK方針を示すものではありません。

| SDKバージョン | 主な機能 | ステータス |
|:-----------:|:-------------|:------:|
| **3.7.1** | `StringBuilder`、`Regex`、`System.Random` | 履歴 |
| **3.7.4** | Persistence API（PlayerData / PlayerObject） | 履歴 |
| **3.7.6** | マルチプラットフォームビルド＆パブリッシュ（PC + Android） | 履歴 |
| **3.8.0** | PhysBone依存関係ソート、Force Kinematic On Remote | 履歴 |
| **3.8.1** | `[NetworkCallable]` パラメータ付きイベント、`Others`/`Self` ターゲット | 履歴 |
| **3.9.0** | Camera Dolly API、Auto Hold Pickup | 履歴 |
| **3.10.0** | ワールド向けVRChat Dynamics（PhysBones、Contacts、VRC Constraints） | 履歴 |
| **3.10.1** | バグ修正、安定性の向上 | 履歴 |
| **3.10.2** | EventTiming.PostLateUpdate/FixedUpdate、PhysBones修正、シェーダー時間グローバル | 履歴 |
| **3.10.3** | `VRCPlayerApi.isVRCPlus`、VRCRaycast（アバター）、Mirror 描画タイミング修正 | 履歴 |
| **3.10.4** | VRCTween、Box形状のContacts、Global Avatar PhysBone Colliders、ワールドの`VRCPhysBoneCollider` Udonアクセス、DataList/DataDictionary容量API | 現行サポート / 最終検証済み |

> **注意**: 公開前に、VRChatが現在サポートしているSDKバージョンをプロジェクトで使用していることを確認してください。

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

<h2 id="community-contributors">コミュニティからの貢献</h2>

具体的なIssueを立て、検証や修正方針まで一緒に詰めてくださった皆さんに感謝します。

- [@KatanoShingo](https://github.com/KatanoShingo) — GameObject検索の代替、パフォーマンスの使い分け、疑似複数部屋のパターン、イベントの記載、ネットワークイベントの認可 ([#181](https://github.com/niaka3dayo/agent-skills-vrc-udon/issues/181), [#182](https://github.com/niaka3dayo/agent-skills-vrc-udon/issues/182), [#189](https://github.com/niaka3dayo/agent-skills-vrc-udon/issues/189), [#199](https://github.com/niaka3dayo/agent-skills-vrc-udon/issues/199), [#213](https://github.com/niaka3dayo/agent-skills-vrc-udon/issues/213), [#302](https://github.com/niaka3dayo/agent-skills-vrc-udon/issues/302))
- [@Guribo](https://github.com/Guribo) — オーナーシップ移譲のタイミングとネットワークのアンチパターン検証 ([#171](https://github.com/niaka3dayo/agent-skills-vrc-udon/issues/171))
- [@haru0416-dev](https://github.com/haru0416-dev) — インストーラーの更新整合性とjqなし環境での検証 ([#164](https://github.com/niaka3dayo/agent-skills-vrc-udon/issues/164), [#165](https://github.com/niaka3dayo/agent-skills-vrc-udon/issues/165))
- [@Yodokoro](https://github.com/Yodokoro) — レイヤーの挙動、NetworkCallableの案内、空間音声の設定 ([#267](https://github.com/niaka3dayo/agent-skills-vrc-udon/issues/267), [#286](https://github.com/niaka3dayo/agent-skills-vrc-udon/issues/286), [#297](https://github.com/niaka3dayo/agent-skills-vrc-udon/issues/297))
- [@tetradice](https://github.com/tetradice) — Agent Skillのメタデータ互換性 ([#281](https://github.com/niaka3dayo/agent-skills-vrc-udon/issues/281))
- [@owlboy](https://github.com/owlboy) — Steam Audioのドキュメント修正 ([#324](https://github.com/niaka3dayo/agent-skills-vrc-udon/issues/324))
- [@nomlasvrc](https://github.com/nomlasvrc) — 非推奨のVRCInstantiateの整理 ([#333](https://github.com/niaka3dayo/agent-skills-vrc-udon/issues/333))
- [@ureishi](https://github.com/ureishi) — UdonSharpのフィールド・シリアライズ挙動とSDK 3.10.4の知識 ([#337](https://github.com/niaka3dayo/agent-skills-vrc-udon/issues/337), [#338](https://github.com/niaka3dayo/agent-skills-vrc-udon/issues/338), [#341](https://github.com/niaka3dayo/agent-skills-vrc-udon/issues/341), [#342](https://github.com/niaka3dayo/agent-skills-vrc-udon/issues/342))

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
- 現在のSDKサポート対象は、最終検証済みの3.10.4のみです。古いバージョンの行は移行時の履歴情報であり、そのSDKの検証や修正を約束するものではありません。新しいVRChatリリースで動作が変わる可能性があります。

### AI支援による作成

このナレッジベースはAIツール（Claude、Gemini、Codex）の支援を受けて作成・メンテナンスされています。すべてのコンテンツはレビュー済みですが、AI生成部分に微妙な誤りが含まれる可能性があります。自己責任でご利用ください。

---

## ライセンス

このプロジェクトは **MIT ライセンス** の下で提供されています。詳細は [LICENSE](LICENSE) をご覧ください。

MIT ライセンスの条件のもとで、自由にフォーク・改変・再配布していただけます。このライセンスはリポジトリ内のドキュメント、ルール、テンプレート、フックに適用されます。VRChat の SDK、UdonSharp コンパイラ、またはその他の VRChat 知的財産に対するいかなる権利も付与しません。
