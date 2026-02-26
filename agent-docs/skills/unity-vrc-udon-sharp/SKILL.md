---
name: unity-vrc-udon-sharp
description: |
    UdonSharp (C# → Udon) scripting skill (SDK 3.7.1 - 3.10.1).
    Covers network sync, persistence, Dynamics, Web Loading, compile constraints.
    Keywords: UdonSharp, Udon, VRC SDK, UdonSynced, NetworkCallable,
    FieldChangeCallback, VRCPlayerApi, SendCustomEvent, PlayerData,
    PhysBones, VRC, world development, synced variables, C# scripting
    Constraints: List<T>/async/await/try/catch blocked.
---

# UdonSharp Skill

## Overview

UdonSharp は C# を Udon Assembly にコンパイルするトランスレータ。標準 C# と大きく異なる制約がある。

**SDK対応**: 3.7.1 - 3.10.1 (2026年2月時点)

## Rules (Constraints & Networking)

コンパイル制約とネットワーキングルールは **常時ロードされる Rules** を参照:

| ルールファイル | 内容 |
|---------------|------|
| `rules/udonsharp-constraints.md` | ブロック機能、コード生成ルール、属性、同期可能な型 |
| `rules/udonsharp-networking.md` | オーナーシップ、同期モード、RequestSerialization、NetworkCallable |
| `rules/udonsharp-sync-selection.md` | 同期パターン選択、データバジェット、最小化原則 |

> エージェントからは `.claude/rules/`、`.agents/rules/` 等のシンボリックリンク経由で自動ロードされる。

## SDK Versions

| SDK バージョン | 主な機能 |
|-------------|--------------|
| 3.7.1 | `StringBuilder`, `RegularExpressions`, `System.Random` 追加 |
| 3.7.4 | **Persistence API** (PlayerData/PlayerObject) 追加 |
| 3.7.6 | マルチプラットフォーム Build & Publish (PC + Android 同時) |
| 3.8.0 | PhysBone 依存関係ソート、Drone API (VRCDroneInteractable) |
| 3.8.1 | **`[NetworkCallable]`** 属性、パラメータ付きネットワークイベント、`NetworkEventTarget.Others`/`.Self` |
| 3.9.0 | Camera Dolly API, Auto Hold ピックアップ簡素化 |
| 3.10.0 | **VRChat Dynamics for Worlds** (PhysBones, Contacts, VRC Constraints) |
| 3.10.1 | バグ修正・安定性改善 (最新安定版) |

> **注意**: SDK 3.9.0 未満は **2025年12月2日をもって非推奨**。新規ワールドアップロード不可。

## Web Search

### When to Search

| シナリオ | アクション |
|----------|-----------|
| 新SDKバージョン対応 | 公式ドキュメントで最新 API 確認 |
| 「できる？」の質問 | 公式ドキュメントで可否確認 |
| 不明エラー | 公式トラブルシューティング参照 |
| 新機能の使い方 | 最新コード例を取得 |

### Search Strategy

```
# 公式ドキュメント検索
WebSearch: "調べたい機能やAPI名 site:creators.vrchat.com"

# UdonSharp API リファレンス
WebSearch: "API名 site:udonsharp.docs.vrchat.com"

# エラー調査: VRChat公式フォーラム
WebSearch: "エラーメッセージ site:ask.vrchat.com"

# エラー調査: Canny (バグ報告/既知の問題)
WebSearch: "エラーメッセージ site:feedback.vrchat.com"

# エラー調査: GitHub Issues
WebSearch: "エラーメッセージ UdonSharp site:github.com"
```

### Official Resources

| リソース | URL | 内容 |
|----------|-----|------|
| VRChat Creators | creators.vrchat.com/worlds/udon/ | 公式 Udon / SDK ドキュメント |
| UdonSharp Docs | udonsharp.docs.vrchat.com | UdonSharp API リファレンス |
| VRChat Forums | ask.vrchat.com | Q&A、解決策 |
| VRChat Canny | feedback.vrchat.com | バグ報告、既知の問題 |
| GitHub | github.com/vrchat-community | サンプル・ライブラリ |

## References

| ファイル | 内容 |
|------|---------|
| `constraints.md` | C# 機能の UdonSharp 可否一覧 |
| `networking.md` | ネットワーキングパターン詳細 (NetworkCallable 含む) |
| `persistence.md` | PlayerData/PlayerObject (SDK 3.7.4+) |
| `dynamics.md` | PhysBones, Contacts, VRC Constraints (SDK 3.10.0+) |
| `patterns.md` | ボタン/ピックアップ/プレイヤー検知/オブジェクトプール等 |
| `web-loading.md` | String/Image ダウンロード、VRCJson、Trusted URL |
| `api.md` | VRCPlayerApi, Networking, enums リファレンス |
| `events.md` | 全 Udon イベント (OnPlayerRestored, OnContactEnter 含む) |
| `editor-scripting.md` | エディタスクリプティングとプロキシシステム |
| `sync-examples.md` | Sync pattern examples (Local/Events/SyncedVars) |
| `troubleshooting.md` | よくあるエラーと解決策 |

## Templates (`assets/templates/`)

| テンプレート | 用途 | パス |
|-------------|------|------|
| `BasicInteraction.cs` | インタラクティブオブジェクト | `assets/templates/BasicInteraction.cs` |
| `SyncedObject.cs` | ネットワーク同期オブジェクト | `assets/templates/SyncedObject.cs` |
| `PlayerSettings.cs` | プレイヤー移動設定 | `assets/templates/PlayerSettings.cs` |
| `CustomInspector.cs` | カスタムエディタインスペクター | `assets/templates/CustomInspector.cs` |

## Hooks

| フック | プラットフォーム | 用途 |
|--------|-----------------|------|
| `validate-udonsharp.ps1` | Windows (PowerShell) | PostToolUse 制約バリデーション |
| `validate-udonsharp.sh` | Linux/macOS (Bash) | PostToolUse 制約バリデーション |

## Quick Reference

- `CHEATSHEET.md` - 1ページクイックリファレンス
