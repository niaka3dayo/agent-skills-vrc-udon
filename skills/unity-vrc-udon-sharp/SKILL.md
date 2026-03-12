---
name: unity-vrc-udon-sharp
description: >
    UdonSharp (C# to Udon Assembly) scripting skill for VRChat world development.
    Use this skill when writing, reviewing, or debugging UdonSharp C# code.
    Covers compile constraints (List<T>/async/await/try/catch/LINQ blocked),
    network sync (UdonSynced, RequestSerialization, FieldChangeCallback, NetworkCallable),
    persistence (PlayerData/PlayerObject), Dynamics (PhysBones, Contacts),
    Web Loading, and event handling. SDK 3.7.1 - 3.10.2 coverage.
    Triggers on: UdonSharp, Udon, VRC SDK, UdonBehaviour, UdonSynced,
    NetworkCallable, VRCPlayerApi, SendCustomEvent, PlayerData, PhysBones,
    synced variables, VRChat world scripting, C# to Udon.
license: MIT
metadata:
    author: niaka3dayo
    version: "1.0.0"
    tags: vrchat, udonsharp, udon, networking, sync, persistence, dynamics
---

# UdonSharp Skill

## Overview

UdonSharp is a translator that compiles C# into Udon Assembly. It has significant constraints that differ from standard C#.

**SDK Coverage**: 3.7.1 - 3.10.2 (as of March 2026)

## Rules (Constraints & Networking)

Compile constraints and networking rules are defined in **always-loaded Rules**:

| Rule File | Contents |
|-----------|----------|
| `rules/udonsharp-constraints.md` | Blocked features, code generation rules, attributes, syncable types |
| `rules/udonsharp-networking.md` | Ownership, sync modes, RequestSerialization, NetworkCallable |
| `rules/udonsharp-sync-selection.md` | Sync pattern selection, data budget, minimization principles |

> After installation, place these in the agent's rules directory for automatic loading.

## SDK Versions

| SDK Version | Key Features |
|-------------|--------------|
| 3.7.1 | Added `StringBuilder`, `RegularExpressions`, `System.Random` |
| 3.7.4 | Added **Persistence API** (PlayerData/PlayerObject) |
| 3.7.6 | Multi-platform Build & Publish (PC + Android simultaneously) |
| 3.8.0 | PhysBone dependency sorting, Drone API (VRCDroneInteractable) |
| 3.8.1 | **`[NetworkCallable]`** attribute, parameterized network events, `NetworkEventTarget.Others`/`.Self` |
| 3.9.0 | Camera Dolly API, Auto Hold pickup simplification |
| 3.10.0 | **VRChat Dynamics for Worlds** (PhysBones, Contacts, VRC Constraints) |
| 3.10.1 | Bug fixes and stability improvements |
| 3.10.2 | EventTiming extensions, PhysBones fixes, shader time globals |

> **Note**: SDK versions below 3.9.0 are **deprecated as of December 2, 2025**. New world uploads are no longer possible.

## Web Search

### When to Search

| Scenario | Action |
|----------|--------|
| New SDK version support | Check official docs for latest API |
| "Is this possible?" questions | Verify feasibility in official docs |
| Unknown errors | Refer to official troubleshooting |
| New feature usage | Retrieve latest code examples |

### Search Strategy

```
# Official documentation search
WebSearch: "feature or API name site:creators.vrchat.com"

# UdonSharp API reference
WebSearch: "API name site:udonsharp.docs.vrchat.com"

# Error investigation: VRChat official forums
WebSearch: "error message site:ask.vrchat.com"

# Error investigation: Canny (bug reports / known issues)
WebSearch: "error message site:feedback.vrchat.com"

# Error investigation: GitHub Issues
WebSearch: "error message UdonSharp site:github.com"
```

### Official Resources

| Resource | URL | Contents |
|----------|-----|----------|
| VRChat Creators | creators.vrchat.com/worlds/udon/ | Official Udon / SDK documentation |
| UdonSharp Docs | udonsharp.docs.vrchat.com | UdonSharp API reference |
| VRChat Forums | ask.vrchat.com | Q&A, solutions |
| VRChat Canny | feedback.vrchat.com | Bug reports, known issues |
| GitHub | github.com/vrchat-community | Samples and libraries |

## References

| File | Contents |
|------|----------|
| `constraints.md` | C# feature availability in UdonSharp |
| `networking.md` | Networking pattern details (including NetworkCallable) |
| `persistence.md` | PlayerData/PlayerObject (SDK 3.7.4+) |
| `dynamics.md` | PhysBones, Contacts, VRC Constraints (SDK 3.10.0+) |
| `patterns.md` | Buttons, pickups, player detection, object pools, etc. |
| `web-loading.md` | String/Image downloading, VRCJson, Trusted URLs |
| `api.md` | VRCPlayerApi, Networking, enums reference |
| `events.md` | All Udon events (including OnPlayerRestored, OnContactEnter) |
| `editor-scripting.md` | Editor scripting and proxy system |
| `sync-examples.md` | Sync pattern examples (Local/Events/SyncedVars) |
| `troubleshooting.md` | Common errors and solutions |

## Templates (`assets/templates/`)

| Template | Purpose | Path |
|----------|---------|------|
| `BasicInteraction.cs` | Interactive object | `assets/templates/BasicInteraction.cs` |
| `SyncedObject.cs` | Network-synced object | `assets/templates/SyncedObject.cs` |
| `PlayerSettings.cs` | Player movement settings | `assets/templates/PlayerSettings.cs` |
| `CustomInspector.cs` | Custom editor inspector | `assets/templates/CustomInspector.cs` |

## Hooks

| Hook | Platform | Purpose |
|------|----------|---------|
| `validate-udonsharp.ps1` | Windows (PowerShell) | PostToolUse constraint validation |
| `validate-udonsharp.sh` | Linux/macOS (Bash) | PostToolUse constraint validation |

## Quick Reference

- `CHEATSHEET.md` - One-page quick reference
