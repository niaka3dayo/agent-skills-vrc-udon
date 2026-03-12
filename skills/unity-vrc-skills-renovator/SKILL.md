---
name: unity-vrc-skills-renovator
description: >
    VRChat skill renovator for knowledge fill, refresh, and quality improvement.
    Use this skill when updating VRChat skills to new SDK versions, filling
    missing knowledge, fixing outdated information, or improving skill quality.
    Targets unity-vrc-udon-sharp and unity-vrc-world-sdk-3 skills.
    Triggers on: update skills, SDK latest, knowledge fill, skill maintenance,
    information audit, catch-up, renovate, refresh, improve skills, SDK update.
license: MIT
metadata:
    author: niaka3dayo
    version: "1.0.0"
    tags: skill-maintenance, sdk-update, knowledge-management
---

# VRC Skills Renovator

## Overview

A guide for renovating (filling knowledge, refreshing, and improving quality of) VRChat-related skills in this repository.

### Three Pillars of Renovation

| Pillar | Description | Examples |
|--------|-------------|---------|
| **Fill** | Adding missing knowledge | Undocumented APIs, patterns, tips |
| **Refresh** | Updating outdated information | New SDK version support, removing deprecated APIs |
| **Quality Improvement** | Improving accuracy and coverage of existing knowledge | Adding code examples, improving explanations |

## Target Skills

> **Path notation**: `skills/` refers to the `skills/` directory at the repository root.
> `rules/` refers to files under `skills/unity-vrc-udon-sharp/rules/`.

| Skill | Directory | Content |
|-------|-----------|---------|
| `unity-vrc-udon-sharp` | `skills/unity-vrc-udon-sharp/` | UdonSharp coding, networking, events |
| `unity-vrc-world-sdk-3` | `skills/unity-vrc-world-sdk-3/` | VRC components, layer settings, world optimization |

## Renovation Procedure

### Phase 1: Current State Analysis

1. **Check the current SDK version support for each skill**

```text
Read: skills/unity-vrc-udon-sharp/SKILL.md
Read: skills/unity-vrc-world-sdk-3/SKILL.md
→ Check the "Supported SDK version" line in each file
```

2. **Check the file list for each skill**

```text
Glob: skills/unity-vrc-udon-sharp/**/*
Glob: skills/unity-vrc-world-sdk-3/**/*
```

### Phase 2: Information Gathering

Execute the following search queries in parallel to collect the latest information:

```text
# Required searches (parallel execution recommended)
1. "VRChat SDK {current year} new features updates changelog"
2. "UdonSharp VRChat SDK 3.{next minor version} changes"
3. "VRChat Worlds SDK {current year} UdonSharp"
4. "VRChat World SDK components new features {current year}"

# Supplementary searches (as needed)
5. "VRChat SDK NetworkCallable parameters"
6. "VRChat SDK persistence PlayerData"
7. "VRChat SDK PhysBones Contacts worlds"
```

See `references/search-queries.md` for details.

### Phase 3: Renovation Plan

Classify collected information by the **3 pillars** and **target skills**:

#### Classification by Pillar

| Pillar | Content | Action |
|--------|---------|--------|
| **Fill** | Information not yet in the skill | Add new sections, add code examples |
| **Refresh** | Outdated information | Update version references, remove deprecated APIs |
| **Quality Improvement** | Inaccurate or insufficient descriptions | Improve explanations, add patterns |

#### Classification by Skill

| Category | Target Skill | Examples |
|----------|-------------|---------|
| C# API, networking, sync variables | `unity-vrc-udon-sharp` | NetworkCallable, new events |
| Components, layers, optimization | `unity-vrc-world-sdk-3` | New components, setting changes |
| Affects both | Both | SDK version references, Persistence |

### Phase 4: Update unity-vrc-udon-sharp

| Priority | File | Update Content |
|----------|------|----------------|
| 1 | SKILL.md | SDK version support, new feature summary |
| 2 | references/constraints.md | Newly available features |
| 3 | references/networking.md | New networking features |
| 4 | references/events.md | New events |
| 5 | references/api.md | New APIs |
| 6 | CHEATSHEET.md | Quick reference update |
| 7 | references/patterns.md | New feature usage patterns |
| 8 | references/troubleshooting.md | Troubleshooting |

### Phase 5: Update unity-vrc-world-sdk-3

| Priority | File | Update Content |
|----------|------|----------------|
| 1 | SKILL.md | SDK version support, new feature summary |
| 2 | references/components.md | New components, property changes |
| 3 | references/layers.md | Layer/collision changes |
| 4 | references/performance.md | New optimization guidelines |
| 5 | references/lighting.md | Lighting-related changes |
| 6 | references/audio-video.md | Audio/video-related changes |
| 7 | references/upload.md | Upload procedure changes |
| 8 | CHEATSHEET.md | Quick reference update |
| 9 | references/troubleshooting.md | Troubleshooting |

### Phase 6: New File Creation (if needed)

When major new features are added:
- Create a dedicated reference file in the corresponding skill's `references/`
- Add a link in the corresponding SKILL.md Resources section

### Phase 7: Rules & Enforcement Layer Sync

When the Knowledge layer (references/*.md) changes, always sync the Rules layer and Enforcement layer as well.

#### 7a. Rules Layer — Auto-loaded Rules (skills/unity-vrc-udon-sharp/rules/)

```text
Read: skills/unity-vrc-udon-sharp/rules/udonsharp-constraints.md
Read: skills/unity-vrc-udon-sharp/rules/udonsharp-networking.md
Read: skills/unity-vrc-udon-sharp/rules/udonsharp-sync-selection.md
→ Check for differences with the Knowledge layer and reflect the same facts
```

| Change Type | Target Rule File | Action |
|-------------|-----------------|--------|
| Blocked feature added/removed | udonsharp-constraints.md | Update block list / available list |
| Networking changes | udonsharp-networking.md | Update sync modes, limits, patterns |
| Data budget changes | udonsharp-sync-selection.md | Update budget values, decision tree |

#### 7b. Enforcement Layer — Validation Hooks (hooks/)

```text
Read: skills/unity-vrc-udon-sharp/hooks/validate-udonsharp.sh
Read: skills/unity-vrc-udon-sharp/hooks/validate-udonsharp.ps1
→ Add/remove/modify rules based on constraint changes
```

| Change Type | Hook-side Action |
|-------------|-----------------|
| Feature unblocked | Remove the corresponding grep pattern |
| New constraint added | Add a new grep pattern |
| Limit value changed | Update threshold (synced_count, etc.) |
| New anti-pattern | Add a new warning rule |

**Important**: `.sh` and `.ps1` must maintain the same rule set (don't update only one).

#### 7c. Enforcement Layer — Templates (assets/templates/)

```text
Read: skills/unity-vrc-udon-sharp/assets/templates/BasicInteraction.cs
Read: skills/unity-vrc-udon-sharp/assets/templates/SyncedObject.cs
Read: skills/unity-vrc-udon-sharp/assets/templates/PlayerSettings.cs
Read: skills/unity-vrc-udon-sharp/assets/templates/CustomInspector.cs
→ Remove deprecated patterns and reflect new best practices
```

| Change Type | Template-side Action |
|-------------|---------------------|
| New API becomes recommended | Update template to use the new API |
| Pattern becomes deprecated | Rewrite to the recommended pattern |
| New best practice | Reflect in the relevant template, or create a new template |

### Phase 8: Validation

1. Unify SDK version references across all files
2. Verify cross-reference links between both skills
3. Check code sample syntax
4. **3-layer consistency check**: Verify that Knowledge / Rules / Enforcement reflect the same facts
   - Constraint lists are consistent across all 3 layers
   - Limit values (synced variable count, string length, etc.) are consistent across all 3 layers
   - Templates do not use blocked features

## Official Sources

See `references/changelog-sources.md` for details.

### Primary Sources

| Source | URL | Content |
|--------|-----|---------|
| SDK Releases | creators.vrchat.com/releases/ | Official release notes |
| UdonSharp Blog | udonsharp.docs.vrchat.com/news/ | UdonSharp-specific updates |
| VRChat Canny | feedback.vrchat.com/udon | Feature requests and completion status |

### WebSearch for Official Documentation

```text
# Search official documentation
WebSearch: "API name or feature site:creators.vrchat.com"

# UdonSharp API reference
WebSearch: "API name site:udonsharp.docs.vrchat.com"
```

### Search Notes

- The VRChat official site may return 403 errors, so use WebSearch instead of WebFetch
- Japanese sources (Qiita, etc.) can be helpful but prioritize official information
- Also check the UdonSharp releases page on GitHub

## Renovation History Template

Record renovations in the following format:

```markdown
## Renovation History

### YYYY-MM-DD - Summary (e.g., SDK X.Y.Z support / knowledge fill / quality improvement)

**Fill (New additions):**
- Added knowledge / sections

**Refresh (Updates / Fixes):**
- Updated info / corrections

**Quality Improvement:**
- Improved descriptions / added examples

**Rules Layer Sync:**
- unity-vrc-udon-sharp/rules/udonsharp-constraints.md: changes
- unity-vrc-udon-sharp/rules/udonsharp-networking.md: changes

**Enforcement Layer Sync:**
- hooks/validate-udonsharp.sh: rules added/removed
- hooks/validate-udonsharp.ps1: synced with .sh
- assets/templates/SyncedObject.cs: pattern updated

**Changed Files:**
- unity-vrc-udon-sharp/file.md: changes
- unity-vrc-world-sdk-3/file.md: changes

**3-Layer Consistency**: OK / NG (details)
```
