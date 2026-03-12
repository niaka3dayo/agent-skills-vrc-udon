# UdonSharp / VRChat World Development

UdonSharp (C# → Udon Assembly) を使った VRChat ワールド開発用 Agent Skills。
**標準 C# と大きく異なる制約がある。コード生成前に必ず Rules を読むこと。**

## Skills

| Skill | 用途 | 参照パス |
|-------|------|----------|
| `unity-vrc-udon-sharp` | UdonSharp コーディング、ネットワーキング、イベント、テンプレート | `skills/unity-vrc-udon-sharp/SKILL.md` |
| `unity-vrc-world-sdk-3` | VRC コンポーネント配置、レイヤー設定、ワールド最適化 | `skills/unity-vrc-world-sdk-3/SKILL.md` |
| `unity-vrc-skills-renovator` | スキルのリノベーション（知識充填・刷新・品質向上） | `skills/unity-vrc-skills-renovator/SKILL.md` |

## Rules

`skills/unity-vrc-udon-sharp/rules/` に格納:

- **udonsharp-constraints.md** — Blocked Features, Code Generation Rules, Attributes, Syncable Types
- **udonsharp-networking.md** — Ownership, Sync Modes, RequestSerialization, NetworkCallable
- **udonsharp-sync-selection.md** — Sync Pattern Decision Tree, Data Budget, Minimization

## SDK (3.7.1 - 3.10.2)

| Version | Key Features |
|---------|--------------|
| 3.7.1 | StringBuilder, Regex, System.Random |
| 3.7.4 | Persistence API (PlayerData/PlayerObject) |
| 3.8.1 | `[NetworkCallable]` パラメータ付きネットワークイベント |
| 3.10.0 | VRChat Dynamics for Worlds (PhysBones, Contacts) |
| 3.10.1 | バグ修正・安定性改善 |
| 3.10.2 | EventTiming 拡張, PhysBones 修正, シェーダー時間グローバル |

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

- Windows: `skills/unity-vrc-udon-sharp/hooks/validate-udonsharp.ps1`
- Linux/macOS: `skills/unity-vrc-udon-sharp/hooks/validate-udonsharp.sh`
