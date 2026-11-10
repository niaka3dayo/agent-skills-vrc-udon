# UdonSharp / VRChat World Development

This project uses the VRChat UdonSharp agent skills (C# → Udon Assembly).
**UdonSharp has significant constraints compared to standard C#. Load the `unity-vrc-udon-sharp` skill and read its rules before generating code.**

## Rules (Required Reading)

Before writing any UdonSharp code, read the three rule sheets in the `rules/` directory of the `unity-vrc-udon-sharp` skill, next to its `SKILL.md`:

- **`udonsharp-constraints.md`** — Blocked Features, Code Generation Rules, Attributes, Syncable Types
- **`udonsharp-networking.md`** — Ownership, Sync Modes, RequestSerialization, NetworkCallable
- **`udonsharp-sync-selection.md`** — Sync Pattern Decision Tree, Data Budget, Minimization

Networking rule: a parameterless `public` method without a leading `_` is a legacy network entry. Prefix local-only/custom public methods with `_`, expose only intentional entries with `[NetworkCallable]`, confirm `NetworkCalling.InNetworkCall` before reading `NetworkCalling.CallingPlayer`, authorize the caller separately from receiver ownership, and never use instance master as a security or access-control boundary.

## Skills

| Skill | Purpose |
|-------|---------|
| `unity-vrc-udon-sharp` | UdonSharp coding, networking, events, templates |
| `unity-vrc-world-sdk-3` | VRC component placement, layer configuration, world optimization |

## SDK

Each skill declares its active and verified SDK target in the `SDK Versions` section of its `SKILL.md`. From v4.0.0 onward, the policy is latest stable SDK only; support moves to a new stable release only after the skills repository verifies it. A new stable release is not supported automatically.

Other SDK versions named in the skills are historical feature-introduction notes. They are not supported or validation targets. This is the skills' support boundary, not a statement about VRChat's own SDK policy.

## Docs Reference

Use web search to reference official documentation and community resources:

| Site | Purpose | Search Example |
|------|---------|----------------|
| `site:creators.vrchat.com` | Official Udon / SDK documentation | `site:creators.vrchat.com UdonSharp networking` |
| `site:udonsharp.docs.vrchat.com` | UdonSharp API reference | `site:udonsharp.docs.vrchat.com synced variables` |
| `site:ask.vrchat.com` | Community Q&A and troubleshooting | `site:ask.vrchat.com PlayerData persistence` |
| `site:feedback.vrchat.com` | Known bugs and feature requests | `site:feedback.vrchat.com PhysBones worlds` |
| `site:github.com/vrchat-community` | Samples and libraries | `site:github.com/vrchat-community ClientSim` |

## Context Preservation

For complex synced systems, ownership-sensitive multi-file refactors, or work resumed after context compaction/handoff, consider the lightweight guide at `references/context-preservation.md` in the `unity-vrc-udon-sharp` skill.
Use it to preserve task-specific source of truth, sync strategy, ownership, late-joiner, owner-left, and validation decisions.
Skip it for small mechanical edits.
Keep secrets, private data, and raw transcripts out of any note.
