# MCP Integration Research: UnityMCP-VRC Compatibility

**Issue**: #61
**Date**: 2026-03-24
**Status**: Research / Decision Pending

---

## 1. UnityMCP-VRC Overview

[UnityMCP-VRC](https://github.com/swax/UnityMCP-VRC) is a fork of [Arodoid/UnityMCP](https://github.com/Arodoid/UnityMCP) that adds VRChat-specific tooling on top of a general-purpose Unity MCP server.

### What It Does

UnityMCP-VRC exposes Unity Editor state to AI agents via the **Model Context Protocol (MCP)**. At runtime it provides:

- **MCP resources** — read-only snapshots of the Unity project (scene hierarchy, component data, console logs, compile errors)
- **MCP tools** — actions the AI can call (run scripts, read/write components, compile check)
- **Helper scripts** — bundled C# / UdonSharp examples that the AI can use as context when generating new code

The VRChat fork adds UdonSharp-specific helper scripts to increase the probability that AI-generated UdonSharp code compiles on the first try. The creator's own note is direct: *"Claude has trouble getting UdonSharp scripts to compile"* — which is precisely the problem this skills package addresses from the agent-side.

### How It Works (Architecture)

```
Unity Editor  <-->  UnityMCP-VRC (MCP Server, runs in Editor)
                         |
                    MCP Protocol (stdio / SSE)
                         |
                    AI Agent (Claude, Cursor, etc.)
```

The MCP server lives inside Unity as an Editor plugin. It surfaces live project state as resources that the AI reads before generating code, replacing the need for the AI to guess at API signatures or UdonSharp restrictions.

---

## 2. Compatibility Assessment

### Our Skill Format

This package delivers knowledge in a three-layer format:

| Layer | Files | Role |
|-------|-------|------|
| Always-loaded Rules | `rules/udonsharp-constraints.md`, `rules/udonsharp-networking.md`, `rules/udonsharp-sync-selection.md` | Hard compile constraints; loaded at agent startup, read before every code generation |
| On-demand References | `references/api.md`, `references/constraints.md`, `references/events.md`, etc. (~10,583 lines total across both skills) | Deep API docs; read when the relevant topic arises |
| Validation Hooks | `hooks/validate-udonsharp.sh` / `.ps1` | Post-generation compile-constraint check before handing code to the user |

### Where the Two Approaches Overlap

Both UnityMCP-VRC and this package are trying to solve the same root problem: **UdonSharp fails silently on legal-looking C# constructs**, and AI models have no way to know this without external knowledge injection.

UnityMCP-VRC solves it via **live project context at inference time** (MCP resources).
This package solves it via **pre-loaded constraint rules at agent startup** (SKILL.md / rules/).

The approaches are complementary rather than competing:

| Concern | UnityMCP-VRC | This Package |
|---------|--------------|--------------|
| Blocked C# features | Helper script examples (implicit) | Explicit enumerated constraints in rules/ |
| Live project state | Yes (scene, components, console) | No (static knowledge only) |
| Networking ownership rules | Not addressed | Explicit in rules/udonsharp-networking.md |
| SDK version table | Not tracked | Tracked in SKILL.md |
| Works without Unity open | Yes (knowledge is static) | No (MCP server requires Editor) |
| Works with any AI tool | Yes (SKILL.md/rules/ are plain markdown) | Requires MCP-capable client |

### Mapping Our Content to MCP Resources

Our rule files could in principle be exposed as MCP resources:

```
rules/udonsharp-constraints.md   -> resource://udonsharp/constraints
rules/udonsharp-networking.md    -> resource://udonsharp/networking
references/api.md                -> resource://udonsharp/api
references/troubleshooting.md    -> resource://udonsharp/troubleshooting
...
```

The content is already structured for machine reading (markdown with tables, code blocks, explicit BLOCKED/ALLOWED markers). The mapping is straightforward in concept.

---

## 3. Integration Approaches

### Option A: Expose Our Skills as MCP Resources

Build a standalone MCP server (Node.js, using the `@modelcontextprotocol/sdk` package) that serves the content of `skills/` as MCP resources and optionally as MCP prompts.

**How it would work:**

- The MCP server reads the `skills/` directory at startup
- Each `rules/*.md` and `references/*.md` is registered as a named resource
- AI agents that support MCP (Claude Desktop, Cursor, etc.) subscribe to the server and receive our constraint knowledge automatically, without requiring `npx agent-skills-vrc-udon` to be run first

**What it would look like for users:**

```json
// mcp.json / claude_desktop_config.json
{
  "mcpServers": {
    "vrc-udon-skills": {
      "command": "npx",
      "args": ["agent-skills-vrc-udon", "--mcp"]
    }
  }
}
```

**Effort estimate:**

| Task | Estimate |
|------|----------|
| Add `@modelcontextprotocol/sdk` dependency | 1h |
| Implement MCP server entry point in `bin/` | 4–6h |
| Register all rules/ and references/ as resources | 2h |
| Add `--mcp` flag to installer or new `bin/serve.mjs` | 2h |
| Write tests (pack test, resource listing smoke test) | 3h |
| Update README / templates | 2h |
| **Total** | **~14–16h** |

**Risks:**

- MCP spec is still evolving; resource API may require updates as clients change
- Adds a runtime dependency and a new execution mode that needs ongoing maintenance
- MCP support in AI tools is not universal; many users still rely on the current file-copy approach

---

### Option B: Create a Complementary MCP Server That Serves Constraint Rules

Rather than replacing the installer, create a separate, focused MCP server that serves only the constraint rules (not the full reference docs). This server could be used alongside UnityMCP-VRC — UnityMCP-VRC provides live Unity project state, our server provides the static UdonSharp constraint knowledge.

**How it would differ from Option A:**

- Smaller scope: rules/ only (3 files, ~600 lines), not all of references/
- Designed explicitly to complement UnityMCP-VRC, not to be a standalone solution
- Could be published as a separate package (`agent-skills-vrc-udon-mcp`) to avoid bloating the main package

**Effort estimate:**

| Task | Estimate |
|------|----------|
| Separate package scaffold | 2h |
| MCP server serving 3 rules files | 3–4h |
| Integration testing with UnityMCP-VRC | 4–6h (uncertain — requires Unity + VRC SDK) |
| Publish pipeline | 2h |
| **Total** | **~11–14h** (plus unknown integration testing time) |

**Risks:**

- Two packages to maintain in sync (version drift of constraint content)
- Integration testing requires a full Unity + VRChat SDK environment, which is not part of CI
- The audience for "MCP + UnityMCP-VRC" overlap is likely small today

---

### Option C: Partnership / Documentation Only

Document UnityMCP-VRC in our README and SKILL.md as a compatible tool. Recommend that users who run UnityMCP-VRC also install this package so the AI has both live project state (from UnityMCP-VRC) and static constraint rules (from our rules/).

**What this means in practice:**

- Add a "Works Well With" section to README.md mentioning UnityMCP-VRC
- Add a note in SKILL.md or templates/CLAUDE.md that if the user runs UnityMCP-VRC, the MCP resources complement but do not replace the constraint rules
- Potentially open a discussion or issue on the UnityMCP-VRC repo proposing that they link back

**Effort estimate:**

| Task | Estimate |
|------|----------|
| README update | 1h |
| SKILL.md / templates update | 1h |
| Outreach to UnityMCP-VRC maintainer (optional) | 1h |
| **Total** | **~2–3h** |

**Risks:**

- Minimal technical value added; purely discovery/documentation benefit

---

## 4. Summary of Effort

| Option | Effort | New Dependencies | Maintenance Burden |
|--------|--------|------------------|--------------------|
| A: Full MCP server | ~14–16h | `@modelcontextprotocol/sdk` | Medium (new execution mode) |
| B: Complementary server | ~11–14h + integration | Same + separate package | High (two packages) |
| C: Documentation only | ~2–3h | None | Low |

---

## 5. Recommendation

**Start with Option C; revisit Option A in 6 months.**

### Rationale

1. **The problem is already solved differently.** Our file-copy installer works today with every AI tool that supports project-local markdown context (Claude Code, Codex CLI, Gemini CLI, Cursor). MCP adds a new delivery mechanism but does not solve a problem users are currently blocked on.

2. **MCP adoption is still early.** The MCP spec reached 1.0 in late 2024 and client support is uneven. Option A would require ongoing updates as clients evolve. Taking this on now would mean maintaining an experimental interface while the main skills content needs attention.

3. **Option B is premature.** Integration testing with UnityMCP-VRC requires a full Unity + VRChat SDK environment. Our CI has no such environment. The maintenance surface of two packages synced across constraint updates is not worth the payoff for a niche within a niche (VRChat devs who also run a local MCP server).

4. **The creator's observation validates our content.** The UnityMCP-VRC creator's note that "Claude has trouble getting UdonSharp scripts to compile" is evidence that our constraint rules (which explicitly enumerate every blocked feature) are exactly the right kind of knowledge to inject. This is an argument for getting our existing content in front of more users via documentation, not for rewriting the delivery mechanism.

### Concrete Next Steps (Option C)

- [ ] Add a "Works Well With" section to `README.md` describing UnityMCP-VRC and how the two tools complement each other
- [ ] Note in `templates/CLAUDE.md` (the template distributed to users) that MCP-delivered project context and our static constraint rules are additive
- [ ] Open a GitHub Discussion or issue to track Option A as a future enhancement once MCP client support stabilizes

### When to Revisit Option A

Option A becomes worth the effort when:
- MCP resource support is stable and widely supported across Claude Code, Cursor, and Codex CLI
- There is user demand (e.g., issues requesting MCP support)
- The `@modelcontextprotocol/sdk` Node.js package reaches 1.x stable
