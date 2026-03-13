# UdonSharp / VRChat World Development

Agent Skills for VRChat world development using UdonSharp (C# → Udon Assembly).
**UdonSharp has significant constraints compared to standard C#. Always read the Rules before generating code.**

## Skills

| Skill | Purpose | Path |
|-------|---------|------|
| `unity-vrc-udon-sharp` | UdonSharp coding, networking, events, templates | `skills/unity-vrc-udon-sharp/SKILL.md` |
| `unity-vrc-world-sdk-3` | VRC component placement, layer configuration, world optimization | `skills/unity-vrc-world-sdk-3/SKILL.md` |
| `unity-vrc-skills-renovator` | Skill renovation (knowledge updates, quality improvements) | `skills/unity-vrc-skills-renovator/SKILL.md` |

## Rules

Located in `skills/unity-vrc-udon-sharp/rules/`:

- **udonsharp-constraints.md** — Blocked Features, Code Generation Rules, Attributes, Syncable Types
- **udonsharp-networking.md** — Ownership, Sync Modes, RequestSerialization, NetworkCallable
- **udonsharp-sync-selection.md** — Sync Pattern Decision Tree, Data Budget, Minimization

## SDK (3.7.1 - 3.10.2)

| Version | Key Features |
|---------|--------------|
| 3.7.1 | StringBuilder, Regex, System.Random |
| 3.7.4 | Persistence API (PlayerData/PlayerObject) |
| 3.8.1 | `[NetworkCallable]` network events with parameters |
| 3.10.0 | VRChat Dynamics for Worlds (PhysBones, Contacts) |
| 3.10.1 | Bug fixes and stability improvements |
| 3.10.2 | EventTiming extensions, PhysBones fixes, shader time globals |

## Docs Reference

Use web search to reference official documentation and community resources:

| Site | Purpose | Search Example |
|------|---------|----------------|
| `site:creators.vrchat.com` | Official Udon / SDK documentation | `site:creators.vrchat.com UdonSharp networking` |
| `site:udonsharp.docs.vrchat.com` | UdonSharp API reference | `site:udonsharp.docs.vrchat.com synced variables` |
| `site:ask.vrchat.com` | Community Q&A and troubleshooting | `site:ask.vrchat.com PlayerData persistence` |
| `site:feedback.vrchat.com` | Known bugs and feature requests | `site:feedback.vrchat.com PhysBones worlds` |
| `site:github.com/vrchat-community` | Samples and libraries | `site:github.com/vrchat-community ClientSim` |

## Hooks

PostToolUse auto-validation when editing `.cs` files:

- Windows: `skills/unity-vrc-udon-sharp/hooks/validate-udonsharp.ps1`
- Linux/macOS: `skills/unity-vrc-udon-sharp/hooks/validate-udonsharp.sh`
