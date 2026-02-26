# UdonSharp / VRChat World Development

UdonSharp (C# → Udon Assembly) を使った VRChat ワールド開発リポジトリ。
**標準 C# と大きく異なる制約がある。コード生成前に必ず Rules を読むこと。**

## Rules (必読)

UdonSharp コードを書く前に、以下の Rules を必ず参照:

- **`.agents/rules/udonsharp-constraints.md`** — Blocked Features, Code Generation Rules, Attributes, Syncable Types
- **`.agents/rules/udonsharp-networking.md`** — Ownership, Sync Modes, RequestSerialization, NetworkCallable
- **`.agents/rules/udonsharp-sync-selection.md`** — Sync Pattern Decision Tree, Data Budget, Minimization

## Skills

UdonSharp / VRC ワールド関連の作業時に、該当スキルの SKILL.md を読み込んでから着手すること。

| Skill | 用途 | 参照パス |
|-------|------|----------|
| `unity-vrc-udon-sharp` | UdonSharp コーディング、ネットワーキング、イベント、テンプレート | `.agents/skills/unity-vrc-udon-sharp/SKILL.md` |
| `unity-vrc-world-sdk-3` | VRC コンポーネント配置、レイヤー設定、ワールド最適化 | `.agents/skills/unity-vrc-world-sdk-3/SKILL.md` |
| `unity-vrc-skills-renovator` | スキルのリノベーション（知識充填・刷新・品質向上） | `.agents/skills/unity-vrc-skills-renovator/SKILL.md` |

## SDK (3.7.1 - 3.10.1)

| Version | Key Features |
|---------|--------------|
| 3.7.1 | StringBuilder, Regex, System.Random |
| 3.7.4 | Persistence API (PlayerData/PlayerObject) |
| 3.8.1 | `[NetworkCallable]` パラメータ付きネットワークイベント |
| 3.10.0 | VRChat Dynamics for Worlds (PhysBones, Contacts) |
| 3.10.1 | バグ修正・安定性改善 (最新安定版) |

## Docs Reference

公式ドキュメント・コミュニティを Web 検索で参照:

| サイト | 用途 | 検索例 |
|--------|------|--------|
| `site:creators.vrchat.com` | 公式 Udon / SDK ドキュメント | `site:creators.vrchat.com UdonSharp networking` |
| `site:udonsharp.docs.vrchat.com` | UdonSharp API リファレンス | `site:udonsharp.docs.vrchat.com synced variables` |
| `site:ask.vrchat.com` | コミュニティ Q&A・トラブルシュート | `site:ask.vrchat.com PlayerData persistence` |
| `site:feedback.vrchat.com` | 既知バグ・機能リクエスト | `site:feedback.vrchat.com PhysBones worlds` |
| `site:github.com/vrchat-community` | サンプル・ライブラリ | `site:github.com/vrchat-community ClientSim` |

## Hooks

PostToolUse で `.cs` ファイル編集時に自動バリデーション:

- Windows: `hooks/validate-udonsharp.ps1`
- Linux/macOS: `hooks/validate-udonsharp.sh`
