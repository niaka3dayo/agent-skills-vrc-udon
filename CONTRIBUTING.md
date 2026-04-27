# Contributing

Thank you for your interest in **agent-skills-vrc-udon**!

## Issue-Only Policy

This project accepts **Issues only**. Pull Requests are **not accepted**.

All fixes and updates are made by the maintainer. If you find an issue, please report it via GitHub Issues and the maintainer will address it.

## Content Scope — Technical Truth, Not Design Prescription

**The skills teach technical truth and present options. They do NOT prescribe what users should build, and they do NOT forbid design choices based on community norms, ethics, or platform policy that lacks mechanical enforcement.**

Users of the skills decide what to build and are responsible for how they use them. The skill's job is to make sure those users have accurate technical information and a working menu of options.

### In scope (the skill rejects it → something technically breaks)

Rules, patterns, and NEVER entries are in scope when the failure is **technical or mechanically enforced**:

- Silent failures (API call ignored, state desync, ownership not transferred)
- Compile errors (UdonSharp whitelist violations, unsupported language features)
- Runtime bugs (null reference, index out of range, networking race conditions)
- Data corruption / desync (late joiner inconsistency, sync var overflow, unsynced state drift)
- Memory leaks, GC pressure, VRAM blowout, frame-rate pathologies
- **Platform policy with mechanical enforcement** — VRChat TOS violations that trigger world deletion, account restrictions, or automated takedowns. These have real, measurable consequences and belong in the skill.

### Out of scope (the skill does NOT prescribe this)

Design preferences, community aesthetics, and ethics **without mechanical consequence** are out of scope:

- "VRChat+ gameplay-gating is bad for the community" (design preference — no mechanical failure)
- "Players shouldn't be able to do X because it feels unfair" (UX preference — no platform enforcement)
- "Avoid Y because it's considered rude" (community norm — no technical or platform consequence)

Contributors are free to raise these as discussions, but they are not valid grounds for a skill rule. Users make these calls in their own projects.

### Reviewer test

> **Is the failure technical (or platform-enforced), or is it social?** Only technical and platform-enforced failures earn rule slots, NEVER entries, or anti-pattern coverage.

If the only reason "this is bad" is "the community dislikes it" or "it's ethically questionable," the rule belongs in the user's project guidelines, not in this skill.

### Historical reference

**NEVER #19** (removed in v1.7.1 via [PR #157](https://github.com/niaka3dayo/agent-skills-vrc-udon/pull/157)) prescribed against VRChat+ gameplay-gating. It was removed because the failure mode was a community/design preference, not a technical or platform-enforced one. That removal is the precedent for this policy: rules whose justification collapses to "social consequence only" are rejected going forward.

## What to Report

- **Incorrect constraints**: A rule says something is blocked but it actually works (or vice versa)
- **Outdated information**: SDK updates that make existing rules inaccurate
- **Missing patterns**: Common UdonSharp patterns not covered by the skills
- **Broken hooks**: Validation hooks that produce false positives/negatives
- **Installer issues**: Problems with `npx agent-skills-vrc-udon`

## How to Report

1. **Search existing Issues** to avoid duplicates
2. Use the appropriate Issue template (Bug Report or Knowledge Request)
3. Include a **link to official VRChat documentation** when possible
4. Provide a **reproducible code example** if applicable

## Branch Policy (for maintainer)

- Default branch: **`dev`** (integration)
- Release branch: **`main`** (npm publish via GitHub Release)
- Maintainer PRs target `dev`. `main` is updated only via release PRs from `dev`.
- Both branches are protected: no direct push, CI must pass.

## Fork & Modify

This project is MIT licensed. You are free to:

- Fork and modify for your own use
- Create derivative works
- Distribute your modified version

See [LICENSE](LICENSE) for details.

## VRChat SDK Versions

When reporting issues, please specify the SDK version. This project covers SDK 3.7.1 - 3.10.3.

## Language

Issues may be written in **Japanese or English**.
