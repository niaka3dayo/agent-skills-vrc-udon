# UdonSharp / VRChat World Development

Agent Skills for VRChat world development using UdonSharp (C# → Udon Assembly).
**UdonSharp has significant constraints compared to standard C#. Always read the Rules before generating code.**

## Rules (Required Reading)

Read the following Rules before writing any UdonSharp code:

- **`skills/unity-vrc-udon-sharp/rules/udonsharp-constraints.md`** — Blocked Features, Code Generation Rules, Attributes, Syncable Types
- **`skills/unity-vrc-udon-sharp/rules/udonsharp-networking.md`** — Ownership, Sync Modes, RequestSerialization, NetworkCallable
- **`skills/unity-vrc-udon-sharp/rules/udonsharp-sync-selection.md`** — Sync Pattern Decision Tree, Data Budget, Minimization

Networking rule: a parameterless `public` method without a leading `_` is a legacy network entry. Prefix local-only/custom public methods with `_`, expose only intentional entries with `[NetworkCallable]`, confirm `NetworkCalling.InNetworkCall` before reading `NetworkCalling.CallingPlayer`, authorize the caller separately from receiver ownership, and never use instance master as a security or access-control boundary.

## Skills

| Skill | Purpose | Path |
|-------|---------|------|
| `unity-vrc-udon-sharp` | UdonSharp coding, networking, events, templates | `skills/unity-vrc-udon-sharp/SKILL.md` |
| `unity-vrc-world-sdk-3` | VRC component placement, layer configuration, world optimization | `skills/unity-vrc-world-sdk-3/SKILL.md` |

## SDK (active: 3.10.4)

**Active support / last verified**: SDK 3.10.4

From v4.0.0 onward, the policy is latest stable SDK only; support moves to a new stable release only after this repository verifies it. A new stable release is not supported automatically. Current last verified target: 3.10.4.

The table below keeps historical feature-introduction notes for migration. SDK 3.7.1-3.10.3 entries are not supported or validation targets for this Skill. This is the Skill's support boundary, not a statement about VRChat's own SDK policy.

| Version | Key Features |
|---------|--------------|
| 3.7.1 | StringBuilder, Regex, System.Random |
| 3.7.4 | Persistence API (PlayerData/PlayerObject) |
| 3.8.1 | `[NetworkCallable]` network events with parameters |
| 3.10.0 | VRChat Dynamics for Worlds (PhysBones, Contacts) |
| 3.10.1 | Bug fixes and stability improvements |
| 3.10.2 | EventTiming extensions, PhysBones fixes, shader time globals |
| 3.10.3 | `VRCPlayerApi.isVRCPlus`, VRCRaycast (avatar), Mirror render-order fix |
| 3.10.4 | VRCTween, Box Contacts, Global Avatar PhysBone Colliders, world `VRCPhysBoneCollider` Udon access, Data Container capacity APIs |

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

For complex synced systems, ownership-sensitive multi-file refactors, or work resumed after context compaction/handoff, consider the lightweight guide at `skills/unity-vrc-udon-sharp/references/context-preservation.md`.
Use it to preserve task-specific source of truth, sync strategy, ownership, late-joiner, owner-left, and validation decisions.
Skip it for small mechanical edits.
Keep secrets, private data, and raw transcripts out of any note.

## Hooks

PostToolUse auto-validation when editing `.cs` files:

- Windows: `skills/unity-vrc-udon-sharp/hooks/validate-udonsharp.ps1`
- Linux/macOS: `skills/unity-vrc-udon-sharp/hooks/validate-udonsharp.sh`
