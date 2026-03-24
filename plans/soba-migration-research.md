# Soba (Udon 2) Migration Research

**Date**: 2026-03-24
**Issue**: #59 — Research Soba (Udon 2) migration readiness
**Branch**: `docs/soba-migration-research`

---

## 1. Current Status

### What Is Soba

Soba is VRChat's next-generation scripting system, formerly referred to as "Udon 2". Rather than
transpiling C# to Udon Assembly (via UdonSharp), Soba compiles C# directly to Microsoft CIL
(Common Intermediate Language) and runs it on a hosted .NET runtime inside the VRChat client.

The name change from "Udon 2" to "Soba" (another noodle) appears to be a deliberate branding
shift — likely to signal that it is not simply an incremental upgrade of UdonSharp/Udon, but
a ground-up runtime replacement.

### Timeline and Roadmap (as of March 2026)

- Soba has been on VRChat's public roadmap since at least 2024.
- The 2026 roadmap marks Soba as **"focus on polishing before release"** — meaning it is
  feature-complete internally but not yet in public beta or GA.
- No official public SDK drop date has been announced.
- VRChat has historically been conservative with SDK releases; expect months of closed testing
  before any public SDK ships.

**Confidence level**: Medium. Roadmap language ("polishing") suggests H1 2026 is optimistic for
a public beta. H2 2026 or 2027 for GA is plausible based on prior VRChat release cadences.

### Known Capabilities

| Capability | UdonSharp (Current) | Soba (Announced) |
|------------|---------------------|-----------------|
| Compile target | Udon Assembly (VM bytecode) | CIL (.NET runtime) |
| Generics (`List<T>`, `Dictionary<T,K>`) | Blocked | Expected to work |
| LINQ | Blocked | Expected to work |
| `async`/`await` | Blocked | Likely available (CIL native) |
| `try`/`catch`/`throw` | Blocked | Likely available |
| Delegates / lambda | Blocked | Likely available |
| `interface` | Blocked | Likely available |
| Method overloading | Blocked | Likely available |
| Networking model | UdonSynced / RequestSerialization | Unconfirmed; likely new API |
| Backward compatibility | — | Unconfirmed |

Sources: VRChat 2026 roadmap, community announcements, VRChat Discord Canny posts.

### What Is Not Yet Known

- Whether UdonSharp worlds continue to run unmodified under Soba (backward compat).
- The exact networking API (whether `[UdonSynced]`, `RequestSerialization`, `NetworkCallable`
  survive or are replaced).
- Whether the VRC SDK component model (`UdonBehaviour`, `UdonSharpBehaviour`) is retained.
- Performance characteristics vs. Udon Assembly.
- Whether unsafe code, threading, or reflection will be allowed (security sandboxing still applies).

---

## 2. Impact on UdonSharp Constraints

The constraints in `skills/unity-vrc-udon-sharp/rules/udonsharp-constraints.md` exist because
UdonSharp transpiles C# to Udon Assembly, a low-level bytecode with strict limitations.
Soba removes that intermediate step. The impact by category:

### Likely Fully Relaxed (CIL is the target)

These blocks are artifacts of Udon Assembly, not VRChat security policy:

| Constraint | Current Workaround | Soba Outlook |
|------------|-------------------|--------------|
| `List<T>`, `Dictionary<T,K>`, `HashSet<T>` | `T[]`, `DataList`/`DataDictionary` | Likely native |
| Generic type parameters | Concrete types only | Likely native |
| `interface` | Base class / `SendCustomEvent` | Likely native |
| Method overloading | Unique method names | Likely native |
| Lambda expressions | Named methods | Likely native |
| LINQ (`.Where`, `.Select`, etc.) | Manual for loops | Likely native |
| `try`/`catch`/`throw` | Defensive null checks + early return | Likely native |
| `async`/`await` | `SendCustomEventDelayedSeconds` | Likely (needs VRC async API) |
| Delegates / C# events | `SendCustomEvent` | Likely native |
| `yield return` / coroutines | `SendCustomEventDelayedSeconds` | Likely (Unity coroutines?) |
| Pattern matching | Traditional `if`/`switch` | Likely native |
| Local functions | Private methods | Likely native |
| Anonymous types | Explicit type definitions | Likely native |
| `Button.onClick.AddListener()` | Inspector `SendCustomEvent` | Likely native |

### Likely Retained (Security or VRChat Architecture)

These constraints are unlikely to change because they reflect VRChat's security sandbox,
not Udon Assembly limitations:

| Constraint | Reason | Soba Outlook |
|------------|--------|--------------|
| `System.IO`, `System.Net` | Security sandbox | Still blocked (use VRC loaders) |
| `System.Threading` | Security / determinism | Likely still blocked |
| `System.Reflection` | Security sandbox | Still blocked or heavily restricted |
| `unsafe` / pointers | Memory safety | Still blocked |
| `Networking.IsOwner` / ownership model | VRChat arch | Model retained, API may change |

### Uncertain (Depends on VRC API Design)

| Feature | Uncertainty |
|---------|------------|
| `async`/`await` semantics | Needs VRChat to provide awaitable VRC API types |
| Unity coroutines (`StartCoroutine`) | Depends on Unity integration model |
| `MonoBehaviour` base class | May still require `UdonSharpBehaviour` or Soba equivalent |
| Operator overloading | No inherent Udon reason to block; likely available |
| `System.Text.StringBuilder`, `Regex` | Already available in UdonSharp 3.7.1+; will continue |

### Behavioral Differences That Will Disappear

The following documented gotchas in `references/constraints.md` are artifacts of UdonVM, not C#:

- **Checked arithmetic by default**: Standard .NET is unchecked by default; overflow wrapping
  will behave normally.
- **Struct method mutation**: Struct-by-value semantics change; `v.Normalize()` will work.
- **Field initializers at compile time**: Normal C# runtime evaluation will apply.
- **Public method lookup cost**: `SendCustomEvent` string lookup overhead is Udon-specific.
  In Soba, event dispatch is likely direct method reference.

---

## 3. Migration Strategy for the Skill Package

### The Dual-Reality Problem

There is a long overlap period ahead:
- Existing UdonSharp worlds will remain on Udon Assembly for years.
- New Soba worlds cannot be written until the SDK ships and is stable.
- Creators will need to maintain existing UdonSharp worlds while starting new Soba worlds.

This means we need **parallel support**, not a hard cutover.

### Option A: Versioned Skill Separation (Recommended)

Create a separate skill tree for Soba alongside the existing UdonSharp skill:

```
skills/
  unity-vrc-udon-sharp/     # Existing — no changes
  unity-vrc-soba/           # New — Soba-specific constraints and patterns
```

**Pros**:
- Zero risk to existing UdonSharp users.
- Clear mental model: install one or both depending on project type.
- Can launch Soba skill as "experimental" without destabilizing the UdonSharp skill.

**Cons**:
- Overlapping content (VRChat API, SDK components, VRCPlayerApi) needs deduplication or shared references.
- Installer changes needed to offer the choice.

### Option B: Conditional Rules Within Existing Skill

Add a frontmatter flag or a separate rules file that toggles Soba mode:

```
skills/unity-vrc-udon-sharp/rules/
  udonsharp-constraints.md       # Existing (UdonSharp / Udon Assembly)
  soba-constraints.md            # New — "these constraints are lifted in Soba"
```

Users would load `soba-constraints.md` instead of or in addition to the UdonSharp rules.

**Pros**: Less duplication of VRChat-specific content.
**Cons**: Confusing to have "Soba rules" inside an "UdonSharp" skill. Naming friction.

### Option C: Shared Base + Layered Overrides

Create a shared `unity-vrc-world-sdk-3` base (already exists) and layer runtime-specific rules:

```
skills/unity-vrc-world-sdk-3/   # Shared VRChat SDK — already exists
skills/unity-vrc-udon-sharp/    # UdonSharp layer — existing
skills/unity-vrc-soba/          # Soba layer — new, overrides constraints
```

**Pros**: Cleanest long-term architecture; no duplication of VRCPlayerApi docs.
**Cons**: Requires refactoring the existing UdonSharp skill to factor out shared content.

### Recommendation

**Short term (now to Soba public beta)**: Implement Option A — begin building `unity-vrc-soba/`
as a separate skill with a clear `[EXPERIMENTAL]` status label. This lets us document Soba
constraints as they become known without touching the stable UdonSharp skill.

**Long term (post-GA)**: Migrate to Option C once the Soba API is stable, factoring shared
VRChat SDK content into the existing `unity-vrc-world-sdk-3` skill and creating thin,
runtime-specific constraint layers.

---

## 4. Recommendations

### When to Start Soba-Specific Content

**Do not create user-facing Soba skill content until a public SDK is available.**

The risk of documenting pre-release behavior is high — constraints documented now may not
match the shipped API. Any content created pre-GA should be:
- Marked `[EXPERIMENTAL — pre-release, subject to change]`
- Placed in `plans/` or an internal tracking document (not in `skills/`)
- Not distributed via npm until confirmed against a real SDK

### Trigger Conditions for Starting a Soba Skill

Start active skill development when any of the following occurs:

1. **Public SDK beta drops** — even if `[EXPERIMENTAL]`, we can validate against real behavior.
2. **VRChat publishes Soba documentation** on `creators.vrchat.com`.
3. **Community projects ship Soba worlds** — real-world constraint data becomes available.

### Pre-Work to Do Now

These tasks can be done without a Soba SDK and will reduce lead time:

1. **Audit which UdonSharp constraints map to which category** (done above in Section 2).
   Convert this into a tracked issue for the future Soba skill scaffold.

2. **Document the `unity-vrc-soba/` skill skeleton** — SKILL.md frontmatter, directory structure,
   and placeholder rules files — so the structure is agreed on before the rush of SDK launch.

3. **Refactor `unity-vrc-world-sdk-3/` to extract VRCPlayerApi and SDK-common content**
   into a shared reference layer. This reduces duplication when both skills exist.
   (See Option C rationale above.)

4. **Watch VRChat Canny / creators.vrchat.com** for Soba SDK announcements. Recommended
   search: `"soba" site:creators.vrchat.com` and `"udon 2" OR "soba" site:feedback.vrchat.com`.

### Impact on Validation Hooks

The `validate-udonsharp.sh` / `.ps1` hooks check for UdonSharp-specific constraint violations
(e.g., `List<T>`, `async`, LINQ). These hooks:
- Are entirely specific to UdonSharp / Udon Assembly.
- Will not be applicable to Soba code.
- Should remain as-is for UdonSharp; a new `validate-soba.sh` should be written once
  the Soba constraint surface is known.

---

## Summary Table

| Topic | Conclusion |
|-------|-----------|
| Soba timeline | Roadmap polishing phase as of March 2026; GA likely H2 2026 or later |
| Key capability gain | Generics, LINQ, lambda, `try/catch`, method overloading, interfaces |
| Constraints that remain | Security sandbox: `System.IO`, reflection, threading, unsafe |
| Behavioral gotchas removed | Checked arithmetic, struct mutation, compile-time field init |
| Package strategy | Separate `unity-vrc-soba/` skill; keep UdonSharp skill unchanged |
| When to start | On public SDK beta drop or official VRChat Soba documentation |
| Pre-work | Constraint audit (done), skill skeleton, `unity-vrc-world-sdk-3` refactor plan |
