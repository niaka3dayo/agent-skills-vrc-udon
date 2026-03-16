# VRC Skill Structure Template

File structure and role of each file in the target skills.

> **Path notation**: `skills/` in this document refers to the `skills/` directory at the repository root.
> `rules/` is consolidated under `skills/unity-vrc-udon-sharp/rules/`.
> `unity-vrc-skills-renovator` itself is located at `.claude/skills/unity-vrc-skills-renovator/` (dev-only, not distributed via npm).

## unity-vrc-udon-sharp

```text
unity-vrc-udon-sharp/
├── SKILL.md                    # Main definition file
├── CHEATSHEET.md               # One-page quick reference
├── rules/                      # Auto-loaded rules (Rules layer)
│   ├── udonsharp-constraints.md    # Blocked features, code generation rules, attributes, syncable types
│   ├── udonsharp-networking.md     # Ownership, sync modes, NetworkCallable
│   └── udonsharp-sync-selection.md # Sync pattern selection, data budget, minimization principles
├── hooks/                      # Enforcement layer - Validation hooks
│   ├── validate-udonsharp.sh   # PostToolUse validation hook (Linux/macOS)
│   └── validate-udonsharp.ps1  # PostToolUse validation hook (Windows)
├── assets/                     # Enforcement layer - Templates
│   └── templates/
│       ├── BasicInteraction.cs # Basic interaction template
│       ├── SyncedObject.cs     # Network sync template
│       ├── PlayerSettings.cs   # Player settings template
│       └── CustomInspector.cs  # Custom inspector template
└── references/                 # Knowledge layer - Reference documents
    ├── constraints.md          # C# feature constraint list
    ├── networking.md           # Networking guide
    ├── events.md               # Event reference
    ├── api.md                  # VRChat API reference
    ├── patterns.md             # Code pattern collection
    ├── troubleshooting.md      # Troubleshooting
    ├── web-loading.md          # String/Image download, VRCJson
    ├── editor-scripting.md     # Editor scripting
    ├── persistence.md          # Persistence guide (SDK 3.7.4+)
    └── dynamics.md             # Dynamics guide (SDK 3.10.0+)
```

### Role of Each File

#### Knowledge Layer (Documents)

| File | Purpose | Update Points |
|------|---------|---------------|
| SKILL.md | Entry point, SDK version support | Version numbers, new feature summary |
| CHEATSHEET.md | Quick reference | New patterns, new events, new errors |
| constraints.md | C# feature availability list | Move newly available features |
| networking.md | Networking details | New network features, data limit changes |
| events.md | Full event reference | Add new events, parameter changes |
| api.md | VRChat-specific API details | New API classes/methods |
| patterns.md | Practical code patterns | Patterns for new features |
| troubleshooting.md | Errors and solutions | Troubleshooting for new features |

#### Enforcement Layer (Executed validation and templates)

| File | Purpose | Update Points |
|------|---------|---------------|
| hooks/validate-udonsharp.sh | PostToolUse auto-validation (Linux/macOS) | Add/remove rules on constraint changes |
| hooks/validate-udonsharp.ps1 | PostToolUse auto-validation (Windows) | Sync same rules as .sh |
| assets/templates/*.cs | Code generation sample templates | Reflect new API patterns, remove deprecated patterns |

## unity-vrc-world-sdk-3

```text
unity-vrc-world-sdk-3/
├── SKILL.md                    # Main definition file
├── CHEATSHEET.md               # One-page quick reference
└── references/
    ├── components.md           # VRC component details
    ├── layers.md               # Layer and collision matrix
    ├── performance.md          # Performance optimization
    ├── lighting.md             # Lighting settings
    ├── audio-video.md          # Audio and video settings
    ├── upload.md               # Upload procedure
    └── troubleshooting.md      # Troubleshooting
```

### Role of Each File

| File | Purpose | Update Points |
|------|---------|---------------|
| SKILL.md | Entry point, SDK version support | Version numbers, new feature summary |
| CHEATSHEET.md | Quick reference | New components, setting changes |
| components.md | VRC component details | New components, property changes |
| layers.md | Layers and collision | Layer changes, collision settings |
| performance.md | Optimization guide | New guidelines, limit value changes |
| lighting.md | Lighting settings | New lighting features |
| audio-video.md | Audio and video | New features, setting changes |
| upload.md | Upload procedure | Procedure changes, new requirements |
| troubleshooting.md | Problem solving | New error → solution entries |

## Auto-Loaded Rules (Rules Layer)

Auto-loaded rule files that are loaded into context are placed in `unity-vrc-udon-sharp/rules/`.
They are automatically loaded at conversation start via symlinks at `.claude/rules/`, `.agents/rules/`, etc.
Always sync these when updating skills.

| File | Purpose | Update Points |
|------|---------|---------------|
| udonsharp-constraints.md | Compilation constraint reference (always loaded) | Blocked feature additions/removals, new attributes |
| udonsharp-networking.md | Networking basic rules | New sync modes, limit value changes |
| udonsharp-sync-selection.md | Sync pattern decision criteria | Data budget changes, new patterns |

### 3-Layer Consistency Rules

Knowledge / Rules / Enforcement must always reflect the same facts:

| Change Example | Knowledge Layer | Rules Layer | Enforcement Layer |
|---------------|:---:|:---:|:---:|
| Feature unblocked | Update constraints.md | Update udonsharp-constraints.md | Remove rule from hooks |
| New constraint added | Add to constraints.md | Add to udonsharp-constraints.md | Add rule to hooks |
| New API pattern | Add to patterns.md | (Update if applicable) | Add/update template |
| Data limit value changed | Update networking.md | Update udonsharp-sync-selection.md | Update hook threshold |

## Common Rules

### Unified Version Notation

At the beginning of each file:

```markdown
**Supported SDK versions**: 3.7.1 - 3.X.X (as of XXXX-XX)
```

For SDK-specific features:

```markdown
### Feature Name (SDK 3.X.X+)
```

### Criteria for Creating New Files

Create a new file in the corresponding skill's `references/` in the following cases:

1. **Major new feature category** — e.g., Persistence (SDK 3.7.4), Dynamics (SDK 3.10.0)
2. **Multiple related components** — e.g., PhysBones + Contacts + Constraints → dynamics.md
3. **Independent setup/concept** — e.g., PlayerData vs PlayerObject → persistence.md

### Cross-References Between Files

Use relative paths when referencing:

```markdown
See `references/networking.md` for details.
```

When adding a new feature, add mentions in the following files:
1. SKILL.md (Resources section)
2. CHEATSHEET.md (related section)
3. Related existing reference files
4. Applicable files in rules/ (for constraint/networking-related changes)
5. Validation rules in hooks/ (for constraint changes, both .sh and .ps1)
6. Templates in assets/templates/ (for pattern changes)
