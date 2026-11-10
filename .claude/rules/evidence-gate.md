# Evidence Gate

This rule applies whenever a change would alter a verified runtime observation, an observed
behavior, or a recorded difference from the official documentation, in either distributed skill.
It is the single copy of the gate: `CONTRIBUTING.md` and the renovator checklist link here.

## Evidence gate for conflicting runtime observations

Do not replace a documented runtime observation with official wording after a
history-free review. Before changing a verified runtime, observed behavior, or
official difference, reviewers and maintainers must:

1. Inspect `git blame` and `git log` for the claim and the surrounding edits.
2. Read every related Issue/PR, the upstream report, and the reproduction evidence
   before deciding that the claim is stale. Read the two evidence histories
   separately:
   - For user-layer names, read Issue [#286](https://github.com/niaka3dayo/agent-skills-vrc-udon/issues/286),
     PR [#287](https://github.com/niaka3dayo/agent-skills-vrc-udon/pull/287),
     the maintainer follow-up, the upstream report
     [vrchat-community/creator-docs#303](https://github.com/vrchat-community/creator-docs/issues/303),
     and its docs correction [creator-docs#319](https://github.com/vrchat-community/creator-docs/pull/319).
     Issue #286 and PR #287 record collision retention, but the attached
     layer-dump directly observes names only: its `LayerMask.LayerToName(0..31)`
     output does not measure collision pairs or the matrix.
     Use a separate collision reproduction for collision claims.
   - For built-in collision behavior, read Issue [#288](https://github.com/niaka3dayo/agent-skills-vrc-udon/issues/288)
     and PR [#294](https://github.com/niaka3dayo/agent-skills-vrc-udon/pull/294).
     #288 records that the then-current `layers.md` intentionally preserved
     VRChat-specific collision-matrix behavior without factual errors; #294
     records that the Environment/Pickup/PickupNoEnvironment facts and the
     default matrix were intentionally retained. Do not replace these claims
     from official docs alone: changes require independent runtime/SDK evidence
     for that target and a recorded observation scope.
3. Rank evidence in this order: a reproducible runtime observation from the
   same target version, shipped SDK/source, then official docs. Official docs
   still describe intended behavior, but official docs alone must not erase a
   reproducible difference.
4. Record the verified boundary. Do not generalize beyond the verified observation.

Issue #286 and PR #287 record that, for layers 22-31, custom layer names are
overwritten by the live client to `user0`-`user9` while the collision matrix is
retained. The official docs were corrected to match in creator-docs#319, so
older official wording is no longer an official difference to preserve; change
this only on new runtime evidence. Do not use #286 to alter a built-in layer
collision claim or mix built-in layer collision behavior into this user-layer
observation. A name dump is not collision evidence; a built-in collision
change still needs an independent runtime/SDK reproduction for that target.

## Where this applies

- Reviews and edits of `skills/unity-vrc-world-sdk-3/references/layers.md`, which carries both
  evidence histories above.
- Any renovation pass (`.claude/skills/unity-vrc-skills-renovator/`) that would restore official
  wording over a recorded observation.
- A new claim of the same kind: record what was observed, on which SDK and client, and what was
  not observed, so that the next reviewer can apply this gate to it.
