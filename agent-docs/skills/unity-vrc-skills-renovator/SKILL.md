---
name: unity-vrc-skills-renovator
description: |
    VRChat skill renovator (knowledge fill, refresh, quality improvement).
    Used for SDK update support, knowledge completion, and fixing outdated info.
    Targets: unity-vrc-udon-sharp, unity-vrc-world-sdk-3
    Keywords: update, SDK latest, knowledge fill, skill maintenance,
    information audit, catch-up, renovate, refresh, improve
---

# VRC Skills Renovator

## Overview

本リポジトリ内の VRChat 関連スキルをリノベーション（知識充填・刷新・品質向上）するためのガイドです。

### Three Pillars of Renovation

| 柱 | 内容 | 例 |
|----|------|-----|
| **充填** | 不足している知識の追加 | 未記載のAPI、パターン、Tips |
| **刷新** | 古くなった情報の更新 | SDK新バージョン対応、非推奨API除去 |
| **品質向上** | 既存知識の精度・網羅性向上 | コード例の追加、説明の改善 |

## Target Skills

> **パス表記**: `skills/` は `agent-docs/skills/` 配下を指す。
> `rules/` は `skills/unity-vrc-udon-sharp/rules/` 配下を指す。
> エージェントからは `.claude/skills/`、`.claude/rules/` (シンボリックリンク) 経由でもアクセス可能。

| スキル | ディレクトリ | 内容 |
|--------|-------------|------|
| `unity-vrc-udon-sharp` | `skills/unity-vrc-udon-sharp/` | UdonSharp コーディング、ネットワーキング、イベント |
| `unity-vrc-world-sdk-3` | `skills/unity-vrc-world-sdk-3/` | VRC コンポーネント、レイヤー設定、ワールド最適化 |

## Renovation Procedure

### Phase 1: Current State Analysis

1. **各スキルの現在のSDK対応バージョンを確認**

```text
Read: skills/unity-vrc-udon-sharp/SKILL.md
Read: skills/unity-vrc-world-sdk-3/SKILL.md
→ 各ファイルの「対応SDKバージョン」を確認
```

2. **各スキルのファイル一覧を確認**

```text
Glob: skills/unity-vrc-udon-sharp/**/*
Glob: skills/unity-vrc-world-sdk-3/**/*
```

### Phase 2: Information Gathering

以下の検索クエリを並列実行して最新情報を収集:

```text
# 必須検索（並列実行推奨）
1. "VRChat SDK {現在年} new features updates changelog"
2. "UdonSharp VRChat SDK 3.{次のマイナーバージョン} changes"
3. "VRChat Worlds SDK {現在年} UdonSharp"
4. "VRChat World SDK components new features {現在年}"

# 補足検索（必要に応じて）
5. "VRChat SDK NetworkCallable parameters"
6. "VRChat SDK persistence PlayerData"
7. "VRChat SDK PhysBones Contacts worlds"
```

詳細は `references/search-queries.md` を参照。

### Phase 3: Renovation Plan

収集した情報を **3つの柱** と **対象スキル** で分類:

#### Classification by Pillar

| 柱 | 内容 | アクション |
|----|------|-----------|
| **充填** | スキルに未記載の情報 | 新規セクション追加、コード例追加 |
| **刷新** | 古くなった情報 | バージョン表記更新、非推奨API除去 |
| **品質向上** | 不正確・不十分な記述 | 説明改善、パターン追加 |

#### Classification by Skill

| カテゴリ | 対象スキル | 例 |
|----------|-----------|-----|
| C# API、ネットワーキング、同期変数 | `unity-vrc-udon-sharp` | NetworkCallable、新イベント |
| コンポーネント、レイヤー、最適化 | `unity-vrc-world-sdk-3` | 新コンポーネント、設定変更 |
| 両方に影響 | 両方 | SDK バージョン表記、Persistence |

### Phase 4: Update unity-vrc-udon-sharp

| 優先度 | ファイル | 更新内容 |
|--------|----------|----------|
| 1 | SKILL.md | SDK対応バージョン、新機能サマリー |
| 2 | references/constraints.md | 新たに使えるようになった機能 |
| 3 | references/networking.md | ネットワーク関連の新機能 |
| 4 | references/events.md | 新しいイベント |
| 5 | references/api.md | 新しいAPI |
| 6 | CHEATSHEET.md | クイックリファレンス更新 |
| 7 | references/patterns.md | 新機能の使用パターン |
| 8 | references/troubleshooting.md | トラブルシューティング |

### Phase 5: Update unity-vrc-world-sdk-3

| 優先度 | ファイル | 更新内容 |
|--------|----------|----------|
| 1 | SKILL.md | SDK対応バージョン、新機能サマリー |
| 2 | references/components.md | 新コンポーネント、プロパティ変更 |
| 3 | references/layers.md | レイヤー・コリジョン変更 |
| 4 | references/performance.md | 新しい最適化ガイドライン |
| 5 | references/lighting.md | ライティング関連の変更 |
| 6 | references/audio-video.md | オーディオ/ビデオ関連の変更 |
| 7 | references/upload.md | アップロード手順の変更 |
| 8 | CHEATSHEET.md | クイックリファレンス更新 |
| 9 | references/troubleshooting.md | トラブルシューティング |

### Phase 6: New File Creation (if needed)

大きな新機能が追加された場合:
- 対応するスキルの `references/` に専用リファレンスファイルを作成
- 対応する SKILL.md の Resources セクションにリンクを追加

### Phase 7: Rules & Enforcement Layer Sync

Knowledge 層 (references/*.md) の変更に合わせて、Rules 層・Enforcement 層も必ず同期する。

#### 7a. Rules Layer — Auto-loaded Rules (skills/unity-vrc-udon-sharp/rules/)

```text
Read: skills/unity-vrc-udon-sharp/rules/udonsharp-constraints.md
Read: skills/unity-vrc-udon-sharp/rules/udonsharp-networking.md
Read: skills/unity-vrc-udon-sharp/rules/udonsharp-sync-selection.md
→ Knowledge 層との差分を確認し、同じ事実を反映
```

| 変更タイプ | 対象ルールファイル | アクション |
|-----------|-------------------|-----------|
| ブロック機能の追加/解除 | udonsharp-constraints.md | ブロックリスト・利用可能リスト更新 |
| ネットワーキング変更 | udonsharp-networking.md | 同期モード・制限値・パターン更新 |
| データ予算の変更 | udonsharp-sync-selection.md | バジェット値・デシジョンツリー更新 |

#### 7b. Enforcement Layer — Validation Hooks (hooks/)

```text
Read: skills/unity-vrc-udon-sharp/hooks/validate-udonsharp.sh
Read: skills/unity-vrc-udon-sharp/hooks/validate-udonsharp.ps1
→ 制約変更に応じてルールを追加/削除/修正
```

| 変更タイプ | フック側のアクション |
|-----------|-------------------|
| 機能がブロック解除 | 該当する grep パターンを削除 |
| 新しい制約追加 | 新しい grep パターンを追加 |
| 制限値の変更 | 閾値 (synced_count 等) を更新 |
| 新しいアンチパターン | 新しい警告ルールを追加 |

**重要**: `.sh` と `.ps1` は同じルールセットを維持すること（片方だけ更新しない）。

#### 7c. Enforcement Layer — Templates (assets/templates/)

```text
Read: skills/unity-vrc-udon-sharp/assets/templates/BasicInteraction.cs
Read: skills/unity-vrc-udon-sharp/assets/templates/SyncedObject.cs
Read: skills/unity-vrc-udon-sharp/assets/templates/PlayerSettings.cs
Read: skills/unity-vrc-udon-sharp/assets/templates/CustomInspector.cs
→ 非推奨パターンを排除し、新しいベストプラクティスを反映
```

| 変更タイプ | テンプレート側のアクション |
|-----------|--------------------------|
| 新 API が推奨に | テンプレートで新 API を使用する例に更新 |
| パターンが非推奨に | 該当パターンを推奨パターンに書き換え |
| 新しいベストプラクティス | 該当テンプレートに反映、または新テンプレート作成 |

### Phase 8: Validation

1. 各ファイルのSDKバージョン表記を統一
2. 両スキル間の相互参照リンクを確認
3. コードサンプルの構文確認
4. **3層整合性チェック**: Knowledge / Rules / Enforcement が同じ事実を反映しているか
   - 制約一覧が3層で一致しているか
   - 制限値（synced 変数数、string 長等）が3層で一致しているか
   - テンプレートがブロック機能を使っていないか

## Official Sources

詳細は `references/changelog-sources.md` を参照。

### Primary Sources

| ソース | URL | 内容 |
|--------|-----|------|
| SDK Releases | creators.vrchat.com/releases/ | 公式リリースノート |
| UdonSharp Blog | udonsharp.docs.vrchat.com/news/ | UdonSharp固有の更新 |
| VRChat Canny | feedback.vrchat.com/udon | 機能リクエスト・完了情報 |

### WebSearch for Official Documentation

```text
# 公式ドキュメント検索
WebSearch: "調べたいAPI名や機能 site:creators.vrchat.com"

# UdonSharp API リファレンス
WebSearch: "API名 site:udonsharp.docs.vrchat.com"
```

### Search Notes

- VRChat公式サイトは403エラーを返すことがあるため、WebFetchではなくWebSearchを使用
- 日本語情報（Qiita等）も参考になるが、公式情報を優先
- GitHubのUdonSharpリリースページも確認

## Renovation History Template

リノベーション実施時は以下の形式で記録:

```markdown
## Renovation History

### YYYY-MM-DD - Summary (e.g., SDK X.Y.Z support / knowledge fill / quality improvement)

**Fill (New additions):**
- Added knowledge / sections

**Refresh (Updates / Fixes):**
- Updated info / corrections

**Quality Improvement:**
- Improved descriptions / added examples

**Rules Layer Sync:**
- unity-vrc-udon-sharp/rules/udonsharp-constraints.md: changes
- unity-vrc-udon-sharp/rules/udonsharp-networking.md: changes

**Enforcement Layer Sync:**
- hooks/validate-udonsharp.sh: rules added/removed
- hooks/validate-udonsharp.ps1: synced with .sh
- assets/templates/SyncedObject.cs: pattern updated

**Changed Files:**
- unity-vrc-udon-sharp/file.md: changes
- unity-vrc-world-sdk-3/file.md: changes

**3-Layer Consistency**: OK / NG (details)
```
