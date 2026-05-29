# SDK Coverage Audit (maintainer procedure)

This directory holds the **how-to-run** for the binary-backed coverage audit.
The **policy** — what may and may not enter a skill, and how undocumented APIs
are labeled — lives in [`CONTRIBUTING.md`](../../CONTRIBUTING.md) under
"Content Scope". This file does not restate the policy; it only describes the
mechanics. Keep the two in their lanes to avoid drift (this repo has a
documentation-sync rule for exactly this reason).

## Why this exists

Skill coverage is derived from the official VRChat docs, which lag and sometimes
omit what the SDK binary ships (precedents: missing Udon events, #213/#214;
`VRCObjectPool.Shuffle()`, #190). Inspecting the SDK binary closes that blind
spot — but only as a **discovery / drift-detection** tool. Binary presence never
justifies inclusion on its own; see the policy.

## When to run

On each **SDK version bump**. Run the census against the new SDK, diff against
the previous run, and triage only what changed. Do not re-audit the full surface
every time — that is the treadmill this procedure is designed to avoid.

## Prerequisites

- A local SDK workspace as described in
  [`unity-project-for-sdk-search/README.md`](../../unity-project-for-sdk-search/README.md)
  (gitignored; the SDK is non-redistributable).
- `pip install dnfile pefile`
- Python 3.9+

## Pipeline

Run from the repo root. By default all three scripts read/write under
`.claude/audit/.generated/`, which is gitignored — the generated JSON is a
near-complete symbol listing we never commit; curated decisions go in the ledger.

```bash
# 1. Census: enumerate per-component Udon-callable methods from the wrapper DLL.
#    -> writes .claude/audit/.generated/census.json
python .claude/audit/scripts/census.py --dll <path-to>/VRC.Udon.VRCWrapperModules.dll

# 2. Diff: binary-minus-skill, split into Tier 1 (covered-but-incomplete) / Tier 2 (unmentioned).
#    -> reads .generated/census.json, writes .generated/diff.json
python .claude/audit/scripts/diff.py

# 3. Refine: reduce Tier 1 to missing non-accessor (verb) methods — the decision-relevant signal.
python .claude/audit/scripts/refine.py
```

## Triage (the editorial gate — by hand)

The pipeline output is "binary minus skill", **not** "binary minus official
docs". For each high-signal candidate:

1. **Documentation oracle** — apply the oracle defined in CONTRIBUTING.md
   "Content Scope" (documented = on a human-readable creators.vrchat.com /
   udonsharp.docs.vrchat.com page; Udon-graph exposure does not count).
   *Procedure note:* asymmetric rigor — marking something "undocumented" requires
   a thorough negative check of the decisive page(s); otherwise record
   "inconclusive", never "undocumented".
2. **Technical-relevance bar** — apply the existing "Content Scope" Reviewer
   test (the relevance axis, orthogonal to sourcing).
3. **Behavior verification** — per CONTRIBUTING.md "Never infer behavior from
   existence": verify runtime semantics (ownership, sync, late-joiner, return
   semantics) against official docs or hands-on multi-client testing before any
   behavioral claim enters a skill.

Record every decision — including skips and their reason — in
[`sdk-coverage-ledger.md`](sdk-coverage-ledger.md). Promote at most a few
verified, high-value candidates per release; everything else stays in the ledger.

## Files

| File | Purpose |
|------|---------|
| `scripts/census.py` | stage 1 — metadata parse, per-type method enumeration |
| `scripts/diff.py` | stage 2 — diff vs current skill text |
| `scripts/refine.py` | stage 3 — reduce to high-signal verb methods |
| `sdk-coverage-ledger.md` | decision ledger (candidates, verdicts, skips + why) |
