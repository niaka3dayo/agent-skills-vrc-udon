# VRC Skill Update Checklist

## Phase 1: Current State Assessment

- [ ] Check SDK version support for each skill
  ```text
  Read: skills/unity-vrc-udon-sharp/SKILL.md
  Read: skills/unity-vrc-world-sdk-3/SKILL.md
  → Find the "Supported SDK version" line
  ```

- [ ] Check the file list for update targets
  ```text
  Glob: skills/unity-vrc-udon-sharp/**/*
  Glob: skills/unity-vrc-world-sdk-3/**/*
  ```

## Phase 2: Information Gathering

### Required Searches (Parallel Execution)

- [ ] Search 1: Latest release overview
  ```bash
  WebSearch: "VRChat SDK {current year} new features updates changelog"
  ```

- [ ] Search 2: Specific SDK version
  ```bash
  WebSearch: "VRChat Worlds SDK 3.{next version} changes"
  ```

- [ ] Search 3: UdonSharp-specific
  ```bash
  WebSearch: "UdonSharp VRChat SDK {current year}"
  ```

- [ ] Search 4: World SDK components
  ```bash
  WebSearch: "VRChat World SDK components new features {current year}"
  ```

### Feature-Specific Searches (As Needed)

- [ ] Networking updates
  ```bash
  WebSearch: "VRChat SDK NetworkCallable SendCustomNetworkEvent"
  ```

- [ ] Persistence updates
  ```bash
  WebSearch: "VRChat SDK persistence PlayerData PlayerObject"
  ```

- [ ] Dynamics updates
  ```bash
  WebSearch: "VRChat SDK PhysBones Contacts worlds Udon"
  ```

- [ ] New System namespaces
  ```bash
  WebSearch: "VRChat SDK Udon new namespaces exposed"
  ```

- [ ] World settings & components
  ```bash
  WebSearch: "VRChat SDK VRC_SceneDescriptor new settings"
  ```

## Phase 3: Create Diff List

Classify collected information:

- [ ] Create diff list for UdonSharp
  ```text
  Target: unity-vrc-udon-sharp
  - C# API, networking, sync variables, events
  ```

- [ ] Create diff list for World SDK
  ```text
  Target: unity-vrc-world-sdk-3
  - Components, layers, optimization, lighting
  ```

- [ ] Identify diffs affecting both skills
  ```text
  Target: Both
  - SDK version references, Persistence, etc.
  ```

## Phase 4: Update unity-vrc-udon-sharp

### Priority 1: SKILL.md
- [ ] Update SDK version support
- [ ] Add new feature summary
- [ ] Update resource list

### Priority 2: constraints.md
- [ ] Add newly available features
- [ ] Update relaxed constraints

### Priority 3: networking.md
- [ ] Add new networking features
- [ ] Reflect data limit changes

### Priority 4: events.md
- [ ] Add new events
- [ ] Reflect event parameter changes

### Priority 5: api.md
- [ ] Add new API classes/methods

### Priority 6: CHEATSHEET.md
- [ ] Update quick reference

### Priority 7: patterns.md
- [ ] Add patterns for new features

### Priority 8: troubleshooting.md
- [ ] Add troubleshooting for new features

## Phase 5: Update unity-vrc-world-sdk-3

### Priority 1: SKILL.md
- [ ] Update SDK version support
- [ ] Add new feature summary

### Priority 2: components.md
- [ ] Add new components
- [ ] Reflect property changes

### Priority 3: layers.md
- [ ] Reflect layer/collision changes

### Priority 4: performance.md
- [ ] Add new optimization guidelines

### Priority 5: lighting.md
- [ ] Reflect lighting-related changes

### Priority 6: audio-video.md
- [ ] Reflect audio/video-related changes

### Priority 7: upload.md
- [ ] Reflect upload procedure changes

### Priority 8: CHEATSHEET.md
- [ ] Update quick reference

### Priority 9: troubleshooting.md
- [ ] Add troubleshooting for new features

## Phase 6: New File Creation (If Applicable)

- [ ] Create reference files for major new features
  ```text
  Write: skills/{target skill}/references/{feature name}.md
  ```

- [ ] Add to the corresponding SKILL.md resource list

## Phase 7: Rules & Enforcement Layer Sync

Sync the Rules layer and Enforcement layer with Knowledge layer changes.

### 7a. Rules Layer — Update Auto-Loaded Rules (rules/)

- [ ] Compare `skills/unity-vrc-udon-sharp/rules/udonsharp-constraints.md` with Knowledge layer
  ```text
  Read: skills/unity-vrc-udon-sharp/rules/udonsharp-constraints.md
  → Verify blocked/available feature lists are up to date
  ```

- [ ] Compare `skills/unity-vrc-udon-sharp/rules/udonsharp-networking.md` with Knowledge layer
  ```text
  Read: skills/unity-vrc-udon-sharp/rules/udonsharp-networking.md
  → Verify sync modes, limits, anti-patterns are up to date
  ```

- [ ] Compare `skills/unity-vrc-udon-sharp/rules/udonsharp-sync-selection.md` with Knowledge layer
  ```text
  Read: skills/unity-vrc-udon-sharp/rules/udonsharp-sync-selection.md
  → Verify data budget and decision tree are up to date
  ```

### 7b. Enforcement Layer — Update Validation Hooks (hooks/)

- [ ] Compare validation hook rule list with Knowledge layer
  ```text
  Read: skills/unity-vrc-udon-sharp/hooks/validate-udonsharp.sh
  Read: skills/unity-vrc-udon-sharp/hooks/validate-udonsharp.ps1
  → Verify each grep pattern matches current constraints
  ```

- [ ] Remove rules for unblocked features
  ```text
  Example: List<T> unblocked → remove "List<" grep pattern
  ```

- [ ] Add rules for new constraints
  ```text
  Example: New blocked feature → add new grep pattern to both .sh and .ps1
  ```

- [ ] Update thresholds and limit values
  ```text
  Example: Synced variable recommended limit changed → update synced_count threshold
  ```

- [ ] Verify `.sh` and `.ps1` rules are identical

### 7c. Enforcement Layer — Update Templates (assets/templates/)

- [ ] Verify each template follows current best practices
  ```text
  Read: skills/unity-vrc-udon-sharp/assets/templates/BasicInteraction.cs
  Read: skills/unity-vrc-udon-sharp/assets/templates/SyncedObject.cs
  Read: skills/unity-vrc-udon-sharp/assets/templates/PlayerSettings.cs
  Read: skills/unity-vrc-udon-sharp/assets/templates/CustomInspector.cs
  ```

- [ ] Remove deprecated patterns from templates
- [ ] Reflect new recommended patterns in templates
- [ ] Verify templates don't trigger validation hook warnings

## Phase 8: Verification

- [ ] Check SDK version references across all files
- [ ] Verify cross-reference links between both skills
- [ ] Check code sample syntax
- [ ] **3-layer consistency check**:
  - [ ] Constraint lists are consistent across Knowledge / Rules / Enforcement
  - [ ] Limit values (synced variable count, string length, etc.) are consistent across all 3 layers
  - [ ] Templates do not use blocked features
  - [ ] All hook rules correctly reflect current constraints

## Phase 9: Completion Report

- [ ] Create update summary
  ```markdown
  ## Update Summary

  ### unity-vrc-udon-sharp (Knowledge)
  - file1.md: changes

  ### unity-vrc-world-sdk-3 (Knowledge)
  - file2.md: changes

  ### rules/ (Rules)
  - udonsharp-constraints.md: changes

  ### hooks/ (Enforcement)
  - validate-udonsharp.sh: rules added/removed
  - validate-udonsharp.ps1: synced with .sh

  ### templates/ (Enforcement)
  - SyncedObject.cs: pattern updated

  ### Newly Created
  - newfile.md: content

  ### Key Changes
  - Change 1
  - Change 2

  ### 3-Layer Consistency: OK / NG (details)
  ```

## Quick Commands

### Check Current Skill State
```text
Read: skills/unity-vrc-udon-sharp/SKILL.md
Read: skills/unity-vrc-world-sdk-3/SKILL.md
Glob: skills/unity-vrc-udon-sharp/**/*
Glob: skills/unity-vrc-world-sdk-3/**/*
```

### Check Enforcement Layer State
```text
Read: skills/unity-vrc-udon-sharp/hooks/validate-udonsharp.sh
Read: skills/unity-vrc-udon-sharp/hooks/validate-udonsharp.ps1
Read: skills/unity-vrc-udon-sharp/rules/udonsharp-constraints.md
Read: skills/unity-vrc-udon-sharp/rules/udonsharp-networking.md
Read: skills/unity-vrc-udon-sharp/rules/udonsharp-sync-selection.md
```

### Latest SDK Search (Parallel)
```bash
WebSearch: "VRChat SDK 2026 new features updates changelog"
WebSearch: "UdonSharp VRChat SDK 3.11 changes"
WebSearch: "VRChat Worlds SDK 2026 UdonSharp"
WebSearch: "VRChat World SDK components new features 2026"
```
