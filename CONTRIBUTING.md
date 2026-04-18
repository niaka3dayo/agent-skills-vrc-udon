# Contributing

Thank you for your interest in **agent-skills-vrc-udon**!

## Issue-Only Policy

This project accepts **Issues only**. Pull Requests are **not accepted**.

All fixes and updates are made by the maintainer. If you find an issue, please report it via GitHub Issues and the maintainer will address it.

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
