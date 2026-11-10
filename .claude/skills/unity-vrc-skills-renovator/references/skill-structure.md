# VRC Skill Structure

How the two distributed skills are laid out, and which file to touch for which kind of change.

File lists are not copied into this document, because a copy goes stale. List the directory to see what exists:

```text
Glob: skills/unity-vrc-udon-sharp/**/*
Glob: skills/unity-vrc-world-sdk-3/**/*
```

> **Path notation**: `skills/` is the directory at the repository root. This skill itself lives at
> `.claude/skills/unity-vrc-skills-renovator/` (maintainer-only, not distributed).

## unity-vrc-udon-sharp

```text
skills/unity-vrc-udon-sharp/
├── SKILL.md            # Entry point: NEVER list, decision guides, routing tables, SDK Versions
├── CHEATSHEET.md       # Quick reference
├── rules/              # Rules layer: three compact rule sheets
├── hooks/              # Enforcement layer: validate-udonsharp.sh and validate-udonsharp.ps1
├── assets/templates/   # Enforcement layer: C# starting points
└── references/         # Knowledge layer: one file per topic, each with a table of contents
```

### Knowledge Layer (references/)

| Files | Purpose | Update Points |
|-------|---------|---------------|
| `constraints.md` | C# feature availability | Move newly available features |
| `networking.md`, `networking-antipatterns.md`, `networking-bandwidth.md`, `sync-examples.md` | Sync, ownership, network events | New network features, data limit changes |
| `events.md` | Udon events | New events, parameter changes |
| `api.md` | VRChat-specific API details | New classes and methods |
| `patterns-*.md` (core, networking, performance, ui, utilities, video) | Practical code patterns | Patterns for new features |
| `dynamics.md`, `persistence.md`, `vrctween.md`, `web-loading.md`, `web-loading-advanced.md`, `image-loading-vram.md` | One feature area each | New APIs and behaviour in that area |
| `sdk-migration.md` | Version summary table and upgrade steps | One table row and one migration section per SDK |
| `troubleshooting.md`, `testing.md` | Errors and test procedure | New error and solution entries |
| `editor-scripting.md`, `assembly-definitions.md`, `context-preservation.md` | Editor tooling and workflow | Tooling changes |

`SKILL.md` routes to these files through its Reference Loading Guide, Pattern Selection Guide, and References table. A new reference needs a row in each table that applies.

### Rules Layer (rules/)

Three rule sheets hold the compact, checkable form of the constraints. They are not loaded automatically by any install method; `SKILL.md` tells the agent when to read each one.

| File | Purpose | Update Points |
|------|---------|---------------|
| `udonsharp-constraints.md` | Compile constraints | Blocked feature additions and removals, new attributes |
| `udonsharp-networking.md` | Networking rules | New sync modes, limit value changes |
| `udonsharp-sync-selection.md` | Sync pattern decision criteria | Data budget changes, new patterns |

### Enforcement Layer (hooks/, assets/templates/)

| Files | Purpose | Update Points |
|-------|---------|---------------|
| `hooks/validate-udonsharp.sh` | Validator for `.cs` edits (Bash) | Add or remove rules when constraints change |
| `hooks/validate-udonsharp.ps1` | Validator for `.cs` edits (PowerShell) | Keep the same rule set as the `.sh` |
| `assets/templates/*.cs` | Code generation starting points | Reflect new API patterns, remove deprecated ones |

The validators reply to the agent with `hookSpecificOutput.additionalContext` on stdout. `tests/hooks/` holds the shared fixtures that both implementations must satisfy.

## unity-vrc-world-sdk-3

```text
skills/unity-vrc-world-sdk-3/
├── SKILL.md            # Entry point: NEVER list, routing table, scene setup, SDK Versions
├── CHEATSHEET.md       # Quick reference, including the SDK Version Features table
├── assets/templates/   # C# starting points for component patterns
└── references/         # components, layers, performance, lighting, audio-video,
                        # build-validation, upload, troubleshooting
```

| File | Purpose | Update Points |
|------|---------|---------------|
| `SKILL.md` | Entry point | Active SDK target, new components in the Components table |
| `CHEATSHEET.md` | Quick reference | New components, setting changes, one version-table row per SDK |
| `components.md` | VRC component details | New components, property changes |
| `layers.md` | Layers and collision | Follow `.claude/rules/evidence-gate.md` before changing a claim |
| `performance.md` | Optimization guide | New guidelines, limit value changes |
| `lighting.md` | Lighting settings | New lighting features |
| `audio-video.md` | Audio and video | New features, setting changes |
| `build-validation.md` | Build Panel alert catalog | Re-verify against the SDK it names |
| `upload.md` | Upload procedure | Procedure changes, new requirements |
| `troubleshooting.md` | Problem solving | New error and solution entries |

## 3-Layer Consistency Rules

Knowledge, Rules, and Enforcement must always reflect the same facts:

| Change Example | Knowledge Layer | Rules Layer | Enforcement Layer |
|---------------|:---:|:---:|:---:|
| Feature unblocked | Update `constraints.md` | Update `udonsharp-constraints.md` | Remove the rule from both hooks |
| New constraint added | Add to `constraints.md` | Add to `udonsharp-constraints.md` | Add the rule to both hooks |
| New API pattern | Add to the matching `patterns-*.md` | Update if applicable | Add or update a template |
| Data limit value changed | Update `networking.md` | Update `udonsharp-sync-selection.md` | Update the hook threshold |

## Common Rules

### Version Notation

The active SDK target is declared once per skill: the bold line in the `## SDK Versions` section of its `SKILL.md`, plus the frontmatter description.

```markdown
**Active support / last verified**: SDK X.Y.Z
```

No other file under `skills/` declares or restates the active number. References, rule sheets, and cheatsheets carry one line that links to `SKILL.md#sdk-versions`, and `tests/docs/sdk-support-policy.test.sh` fails when a file repeats the number. Do not add a support banner to a new reference.

Keep accurate feature-introduction versions in the body, using the marker forms defined under "Version markers" in `references/sdk-migration.md`:

```markdown
### Feature Name (SDK 3.X.X+)
```

Never present a historical version as an active support promise. This boundary describes the Skill, not VRChat's own SDK policy. From v4.0.0 onward, select the latest stable SDK only after this repository verifies it; a new stable release does not change the active target automatically.

### Tables of Contents

Every reference of 100 lines or more starts with a table of contents of its `##` headings. After adding, renaming, or removing a section, refresh it:

```bash
python3 tests/docs/reference-toc.py --write
```

The same script checks that every link to a heading under `skills/` resolves.

### Criteria for Creating New Files

Create a new file in the corresponding skill's `references/` in the following cases:

1. **Major new feature category** — e.g., Persistence (SDK 3.7.4), Dynamics (SDK 3.10.0)
2. **Multiple related components** — e.g., PhysBones + Contacts + Constraints → `dynamics.md`
3. **Independent setup or concept** — e.g., PlayerData vs PlayerObject → `persistence.md`

### Cross-References Between Files

Use relative paths when referencing:

```markdown
See `references/networking.md` for details.
```

When adding a new feature, add mentions in the following places:

1. `SKILL.md` (the routing tables, and a NEVER row when the failure is silent)
2. `CHEATSHEET.md` (related section)
3. Related existing reference files
4. Applicable files in `rules/` (for constraint or networking changes)
5. Validation rules in `hooks/` (for constraint changes, both `.sh` and `.ps1`)
6. Templates in `assets/templates/` (for pattern changes)
7. An eval case under `evals/` when the fact is one a model would not know without the skill
