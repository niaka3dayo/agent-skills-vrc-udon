# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [1.2.0] - 2026-03-16

### Added

- Japanese README (`README.ja.md`)
- Quick Feedback Issue template for lower contribution barrier
- Blank issues now enabled for freeform feedback
- `type: feedback` label for lightweight contributions
- Core Principles section in `unity-vrc-udon-sharp` SKILL.md

### Changed

- Moved `unity-vrc-skills-renovator` from `skills/` to `.claude/skills/` (dev-only, no longer distributed via npm)
- Separated development `CLAUDE.md` from distribution templates
- npm migration notice added to README

### Security

- Pinned all GitHub Actions to SHA hashes
- Hardened CI pipeline configuration

### Infrastructure

- Branch policy documented in CLAUDE.md and CONTRIBUTING.md

## [1.0.0] - 2026-03-12

### Added

- **unity-vrc-udon-sharp** skill: compile constraints, networking patterns, sync selection, 4 code templates
- **unity-vrc-world-sdk-3** skill: scene setup, components, layers, performance, lighting, upload
- **unity-vrc-skills-renovator** meta-skill: self-maintenance framework
- Auto-loaded rules: `udonsharp-constraints`, `udonsharp-networking`, `udonsharp-sync-selection`
- PostToolUse validation hooks (Bash + PowerShell) with 14 checks
- NPX installer: `npx agent-skills-vrc-udon`
- CI/CD: symlink integrity, markdown link validation, npm pack test, Release Drafter, npm publish
- GitHub Issue templates (Bug Report, Knowledge Request)
- Support for Claude Code, Codex CLI, Gemini CLI
- SDK 3.7.1 - 3.10.2 coverage

[1.2.0]: https://github.com/niaka3dayo/agent-skills-vrc-udon/releases/tag/v1.2.0
[1.0.0]: https://github.com/niaka3dayo/agent-skills-vrc-udon/releases/tag/v1.0.0
