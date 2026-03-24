**English** | [日本語](README.ja.md) | [简体中文](README.zh-CN.md) | [繁體中文](README.zh-TW.md) | [한국어](README.ko.md)

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
  <b>Skills, rules, and validation hooks that teach AI coding agents to generate correct UdonSharp code</b>
</p>

<p align="center">
  <a href="#about">About</a> &bull;
  <a href="#install">Install</a> &bull;
  <a href="#structure">Structure</a> &bull;
  <a href="#skills">Skills</a> &bull;
  <a href="#rules">Rules</a> &bull;
  <a href="#hooks">Hooks</a> &bull;
  <a href="#contributing">Contributing</a> &bull;
  <a href="#disclaimer">Disclaimer</a>
</p>

---

<h2 id="about">About</h2>

VRChat world development with **UdonSharp** (C# &rarr; Udon Assembly) has strict compile constraints that differ significantly from standard C#. Features like `List<T>`, `async/await`, `try/catch`, LINQ, and lambdas cause **compile errors**.

This repository provides AI coding agents with the knowledge to generate correct UdonSharp code from the start.

| Problem | Solution |
|---------|----------|
| AI generates `List<T>`, `async/await`, etc. | Rules + hooks auto-detect and warn |
| Sync variable bloat | Decision tree + data budget |
| Incorrect networking patterns | Pattern library + anti-patterns |
| SDK version feature differences | Version table with feature mapping |
| Late Joiner state inconsistency | Sync pattern selection framework |

**This is NOT:**
- A VRChat SDK or UdonSharp distribution
- A Unity project (no executable code)
- A replacement for [official VRChat documentation](https://creators.vrchat.com/)
- A guarantee of all AI behaviors

> **Issues**: Bug reports and knowledge requests are welcome via [GitHub Issues](https://github.com/niaka3dayo/agent-skills-vrc-udon/issues).
> **PRs**: Pull Requests are not accepted. See [CONTRIBUTING.md](CONTRIBUTING.md) for details.

---

<h2 id="install">Install</h2>

> **Migrating from fork/clone?** &mdash; Since v1.0.0, this project is distributed as an **npm package**. You no longer need to fork or clone the repository. Simply run one of the install commands below inside your VRChat Unity project. If you previously cloned this repo, you can safely delete the cloned directory and switch to the npm-based install.

### Method 1: skills CLI (recommended)

```bash
npx skills add niaka3dayo/agent-skills-vrc-udon
```

This uses the [skills.sh](https://skills.sh) ecosystem to install skills into your project.

### Method 2: Claude Code plugin

```bash
claude plugin add niaka3dayo/agent-skills-vrc-udon
```

### Method 3: npx direct install

```bash
npx agent-skills-vrc-udon
```

Options:
```bash
npx agent-skills-vrc-udon --force    # Overwrite existing files
npx agent-skills-vrc-udon --list     # Preview files to install (dry run)
```

### Method 4: git clone

```bash
git clone https://github.com/niaka3dayo/agent-skills-vrc-udon.git
```

---

<h2 id="structure">Structure</h2>

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

<h2 id="skills">Skills</h2>

### unity-vrc-udon-sharp

UdonSharp scripting core skill. Covers compile constraints, networking, events, and templates.

| Area | Content |
|------|---------|
| **Constraints** | Blocked C# features and alternatives (`List<T>` &rarr; `DataList`, `async` &rarr; `SendCustomEventDelayedSeconds`) |
| **Networking** | Ownership model, Manual/Continuous sync, FieldChangeCallback, anti-patterns |
| **NetworkCallable** | SDK 3.8.1+ parameterized network events (up to 8 args) |
| **Persistence** | SDK 3.7.4+ PlayerData/PlayerObject API |
| **Dynamics** | SDK 3.10.0+ PhysBones, Contacts, VRC Constraints for Worlds |
| **Web Loading** | String/Image download, VRCJson, VRCUrl constraints |
| **Templates** | 4 starter templates (BasicInteraction, SyncedObject, PlayerSettings, CustomInspector) |

### unity-vrc-world-sdk-3

World-level scene setup, component placement, and optimization.

| Area | Content |
|------|---------|
| **Scene Setup** | VRC_SceneDescriptor, spawn points, Reference Camera |
| **Components** | VRC_Pickup, Station, ObjectSync, Mirror, Portal, CameraDolly |
| **Layers** | VRChat reserved layers and collision matrix |
| **Performance** | FPS targets, Quest/Android limits, optimization checklist |
| **Lighting** | Baked lighting best practices |
| **Audio/Video** | Spatial audio, video player selection (AVPro vs Unity) |
| **Upload** | Build and upload workflow, pre-upload checklist |

---

<h2 id="rules">Rules</h2>

Rules are constraint files that guide AI agents before code generation.

| Rule File | Content |
|-----------|---------|
| `udonsharp-constraints` | Blocked C# features, code generation rules, attributes, syncable types |
| `udonsharp-networking` | Ownership model, sync modes, anti-patterns, NetworkCallable constraints |
| `udonsharp-sync-selection` | Sync decision tree, data budget targets, 6 minimization principles |

### Sync Decision Tree

```
Q1: Visible to other players?
    No  --> No sync (0 bytes)
    Yes --> Q2

Q2: Late Joiner needs current state?
    No  --> Events only (0 bytes)
    Yes --> Q3

Q3: Continuous change? (position/rotation)
    Yes --> Continuous sync
    No  --> Manual sync (minimal [UdonSynced])
```

**Target**: < 50 bytes per behaviour. Small-medium worlds: < 100 bytes total.

---

<h2 id="hooks">Validation Hooks</h2>

PostToolUse hooks that auto-run when `.cs` files are edited.

| Category | Check | Severity |
|----------|-------|----------|
| Blocked Features | `List<T>`, `async/await`, `try/catch`, LINQ, coroutines, lambdas | ERROR |
| Blocked Patterns | `AddListener()`, `StartCoroutine()` | ERROR |
| Networking | `[UdonSynced]` without `RequestSerialization()` | WARNING |
| Networking | `[UdonSynced]` without `Networking.SetOwner()` | WARNING |
| Sync Bloat | 6+ synced variables per behaviour | WARNING |
| Sync Bloat | `int[]`/`float[]` sync (recommend smaller types) | WARNING |
| Config Mismatch | `NoVariableSync` mode with `[UdonSynced]` fields | ERROR |

Supports both **Bash** (`validate-udonsharp.sh`) and **PowerShell** (`validate-udonsharp.ps1`).

---

## SDK Versions

| SDK Version | Key Features | Status |
|:-----------:|:-------------|:------:|
| **3.7.1** | `StringBuilder`, `Regex`, `System.Random` | Supported |
| **3.7.4** | Persistence API (PlayerData / PlayerObject) | Supported |
| **3.7.6** | Multi-platform Build & Publish (PC + Android) | Supported |
| **3.8.0** | PhysBone dependency sorting, Force Kinematic On Remote | Supported |
| **3.8.1** | `[NetworkCallable]` parameterized events, `Others`/`Self` targets | Supported |
| **3.9.0** | Camera Dolly API, Auto Hold pickup | Supported |
| **3.10.0** | VRChat Dynamics for Worlds (PhysBones, Contacts, VRC Constraints) | Supported |
| **3.10.1** | Bug fixes, stability improvements | Supported |
| **3.10.2** | EventTiming.PostLateUpdate/FixedUpdate, PhysBones fixes, shader time globals | Latest Stable |

> **Note**: SDK < 3.9.0 was deprecated on December 2, 2025. New world uploads require 3.9.0+.

---

## Official Resources

| Resource | URL |
|----------|-----|
| VRChat Creators Docs | https://creators.vrchat.com/ |
| UdonSharp API Reference | https://udonsharp.docs.vrchat.com/ |
| VRChat Forums (Q&A) | https://ask.vrchat.com/ |
| VRChat Canny (Bugs/Features) | https://feedback.vrchat.com/ |
| VRChat Community GitHub | https://github.com/vrchat-community |

---

<h2 id="contributing">Contributing</h2>

**Issues are welcome** -- bug reports and knowledge requests help improve this project.

**Pull Requests are not accepted** -- all fixes and updates are made by the maintainer.

See [CONTRIBUTING.md](CONTRIBUTING.md) for details.

---

<h2 id="disclaimer">Disclaimer</h2>

> **This project is not affiliated with VRChat Inc. No official endorsement, partnership, or association is implied.**
>
> "VRChat", "UdonSharp", "Udon" and related names/logos are trademarks of VRChat Inc. All trademarks belong to their respective owners.
>
> This repository is a **personal knowledge base** for AI coding agents to generate correct UdonSharp code. It does not distribute any part of the VRChat SDK or UdonSharp compiler.

### Accuracy

- Content is provided **"AS IS"** without warranty. See [LICENSE](LICENSE).
- This is a personal project. **Errors, outdated information, or incomplete content may exist.** Always verify against [official VRChat documentation](https://creators.vrchat.com/).
- The author assumes no liability for issues caused by this repository (build errors, upload rejections, unexpected world behavior, etc.).
- SDK coverage (3.7.1 - 3.10.2) reflects the last update. Behavior may change with new VRChat releases.

### AI-Assisted Creation

This knowledge base was created and maintained with AI tool assistance (Claude, Gemini, Codex). All content has been reviewed, but AI-generated portions may contain subtle errors. Use at your own risk.

---

## License

This project is licensed under the **MIT License**. See [LICENSE](LICENSE) for details.

Fork, modify, and redistribute freely under MIT License terms. This license applies to the documentation, rules, templates, and hooks in this repository. It does **not** grant any rights to VRChat's SDK, UdonSharp compiler, or other VRChat intellectual property.
