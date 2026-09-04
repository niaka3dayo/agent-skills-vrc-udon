# SDK Coverage Ledger

Decision log for the binary-backed coverage audit. Records candidates, verdicts,
and **skip reasons** — the skips matter as much as the inclusions, so the same
proposal does not get re-litigated later. This is not an API dump; it lists only
triaged items.

Policy: [`CONTRIBUTING.md`](../../CONTRIBUTING.md) "Content Scope". Procedure:
[`README.md`](README.md).

Status values: `candidate` (found, not yet behavior-verified) · `verified`
(behavior confirmed, eligible for inclusion) · `included` (in a skill) ·
`skip` (decided against — reason required) · `inconclusive` (doc status unresolved).

> A `candidate` is a discovery pending behavior verification (gate 3), not an
> inclusion decision. Rows marked `included` have shipped to a skill — see the
> status column. An item may go `candidate → included` without a `verified`
> stop when it ships as a reference-gap entry: documented signatures with
> runtime behavior explicitly disclaimed in its notes (gate-3 verification
> recorded as out-of-scope).

## Audit: SDK 3.10.3 (initial)

### Included

| API | methods | doc status (oracle) | AI-relevance | status | notes |
|-----|---------|---------------------|--------------|--------|-------|
| VRCPlayerApi voice getters | `GetVoiceGain`, `GetVoiceDistanceNear`, `GetVoiceDistanceFar`, `GetVoiceLowpass`, `GetVoiceVolumetricRadius` | release-noted, reference-missing — named in [SDK 3.6.1 release notes](https://creators.vrchat.com/releases/release-3-6-1/) (added to VRCPlayerApi, exposed to Udon); absent from player-audio / players / udonsharp-api pages (15/15 cells verified absent) | high — clean setter/getter asymmetry; agents know the documented setters but not these | `included` | Shipped in api.md (Issue #230). Reclassified from `undocumented` during verification: the 3.6.1 release note names them, so this is a reference-gap, not a binary-only discovery. Behavior edge-cases (value-before-set, last-set vs effective, local vs remote read) intentionally NOT asserted — out of scope without hands-on. Voice Audio Rework (#209) verified not to touch this surface. |

### Candidates — undocumented-but-shipped, pending behavior verification

| API | methods | doc status (oracle) | AI-relevance | status | notes |
|-----|---------|---------------------|--------------|--------|-------|
| VRCPlayerApi Combat | `CombatSetup`, `CombatSetMaxHitpoints`, `CombatGetCurrentHitpoints`, `CombatSetCurrentHitpoints`, `CombatSetDamageGraphic`, `CombatSetRespawn`, `CombatGetDestructible` | undocumented — absent from players page, udonsharp api; no combat-system doc page exists | high (existence) | `candidate` | purest undocumented-but-shipped, but **legacy** (SDK2-era). Inclusion is a value call: is it used enough today to warrant skill space? |
| VRCPlayerApi voice moderation | `ClearSilence`, `SetSilencedToTagged`, `SetSilencedToUntagged` | undocumented — absent from player-audio (canonical), players, api | med-high | `candidate` | framing-sensitive (moderation). Behavior unverified |
| PlayerData | `IsType` | undocumented — absent from player-data page, persistence overview, api; documented siblings are `GetType`/`TryGetType` | med-high — agents confuse it with the documented siblings | `candidate` | lower-confidence negative; re-verify independently before inclusion |
| Economy Store | `OpenGroupListing` | undocumented — release-3-5-1 notes only, no signature; absent from economy/sdk/udon-documentation | med — confused with `OpenListing` / `OpenGroupStorePage` | `candidate` | lower-confidence negative; re-verify independently before inclusion |

### Candidates — low value / probable skip

| API | method | reason |
|-----|--------|--------|
| Networking | `GetEventDispatcher` | undocumented but internal-sounding; low agent value. `skip` unless a use case appears |

### Notable skips (documented → not the skill's job)

The audit's raw Tier-1 looked large (e.g. VRCUrlInputField 69, VRCPhysBone 68)
but most of that was Unity-inherited methods and property accessors. After
removing noise and checking the docs, the following high-signal items were all
confirmed **documented** and therefore skipped:

- VRCPlayerApi: locomotion getters (`GetWalkSpeed`/`GetRunSpeed`/`GetStrafeSpeed`/`GetJumpImpulse`/`GetGravityStrength`), `GetPlayerId`, `IsPlayerGrounded`, `GetPlayerObjects`, `GetPlayersWithTag`, avatar-scaling get/set, all `SetVoice*` setters
- Networking: `GetNetworkDateTime`, `IsObjectReady`, `GetUniqueName`, `CalculateServerDeltaTime`, `SimulationTime`, `InstanceOwner`/`IsInstanceOwner`/`IsNetworkSettled`, `GetPlayerObjectStorageLimit`/`Usage`
- PlayerData: all typed `Get`/`Set`/`TryGet` accessors except `IsType`
- DataList / DataDictionary: all 12 methods (note: `RemoveAll` takes a value not a `Predicate<T>`; `ShallowClone` has no C# analog — documented, but a "differs from C#" skill note may have independent merit)
- Constraints: `ActivateConstraint`, `ZeroConstraint`
- Economy: 12 of 13 (all but `OpenGroupListing`)
- Pickup / Contacts: `PlayHaptics` (udonsharp api only — discoverability gap, but documented), `CalculateProximity`, `UpdateCollisionTags`

Reversed during review: `GetPlayerObjectStorageLimit`/`Usage` were briefly flagged
as undocumented by name-mismatch inference; the player-object page documents them.
Inference is not a negative check — record `inconclusive`, never `undocumented`.

## Audit: SDK 3.10.4

Source release note: https://creators.vrchat.com/releases/release-3-10-4/

Local package versions:

- `com.vrchat.base` `3.10.4`
- `com.vrchat.worlds` `3.10.4`

Binary discovery command:

```bash
python3 .claude/audit/scripts/census.py \
  --dll /home/natsuki/workspaces/agent-skills-vrc-udon/unity-project-for-sdk-search/TestProject/Packages/com.vrchat.worlds/Runtime/Udon/External/VRC.Udon.VRCWrapperModules.dll \
  --out .claude/audit/.generated/census-3.10.4.json
python3 .claude/audit/scripts/diff.py \
  --census .claude/audit/.generated/census-3.10.4.json \
  --out .claude/audit/.generated/diff-3.10.4.json
python3 .claude/audit/scripts/refine.py \
  --diff .claude/audit/.generated/diff-3.10.4.json
```

### Included / release-noted stable facts

These are 3.10.4 release-note-backed authoring or Udon surfaces. Binary-backed
rows list the local wrapper types found in `VRC.Udon.VRCWrapperModules.dll`;
release-only rows are not treated as binary discoveries.

| API / feature | release-note status | binary evidence | AI-relevance | status | notes |
|---------------|---------------------|-----------------|--------------|--------|-------|
| VRCTween / VRCTweenHandle | release-noted — 3.10.4 adds VRCTween, virtual tweens, cancelable delayed calls, UdonSharp and Graph compatibility; beta notes add `DelayedSetActive` and `TweenPitch` | `ExternVRCSDK3ComponentsVRCTween`: `DelayedCall`, `DelayedSetActive`, `KillAll`, `KillAllTweens`, `TweenAnchorPos`, `TweenColor`, `TweenFade`, `TweenFloat`, `TweenInt`, `TweenIntensity`, `TweenLocalPath`, `TweenLocalPosition`, `TweenLocalRotation`, `TweenPath`, `TweenPitch`, `TweenPosition`, `TweenRotation`, `TweenScale`, `TweenSizeDelta`, `TweenValue`, `TweenVector3`, `TweenVolume`; `ExternVRCSDK3ComponentsVRCTweenHandle`: `ChangeEndValue`, `Complete`, `Flip`, `From`, `Goto`, `Kill`, `OnComplete`, `OnRewind`, `Pause`, `Play`, `PlayBackwards`, `PlayForwards`, `Restart`, `SetDelay`, `SetDuration`, `SetEase`, `SetLoops`, `SetSpeedBased`, `SetUpdate`, plus state accessors | high — new animation API likely to be requested directly | `included` | Stable 3.10.4 fact. Do not infer DOTween parity beyond the documented/select exposed surface. |
| Contacts: box shape / `size` / face proximity option | release-noted — contact senders and receivers can be box-shaped; width, height and depth are independently adjustable; proximity can use center distance or box-face distance | wrapper confirms `get_size`/`set_size` and existing shape/transform accessors on `ExternVRCSDK3DynamicsContactComponentsVRCContactReceiver` and `ExternVRCSDK3DynamicsContactComponentsVRCContactSender`; no separate `Use Face Proximity` Udon wrapper member surfaced in this DLL census | high — prevents agents from assuming sphere/capsule-only contacts | `included` | Treat `Use Face Proximity` as release-noted authoring behavior, not as a wrapper method. `CalculateProximity` / `UpdateCollisionTags` are related wrapper methods but are not new 3.10.4 inclusions; see related/gap rows below. |
| World `VRCPhysBoneCollider` Udon access | release-noted — world PhysBone colliders are exposed to Udon and require `ApplyConfigurationChanges()` after property edits | `ExternVRCSDK3DynamicsPhysBoneComponentsVRCPhysBoneCollider`: `ApplyConfigurationChanges`, `get_height`/`set_height`, `get_position`/`set_position`, `get_radius`/`set_radius`, `get_rotation`/`set_rotation`, `get_shapeType`/`set_shapeType` | high — dynamic world collider edits need the apply call | `included` | Release note also mentions avatar global PhysBone colliders; this row is specifically the world Udon wrapper surface. |
| Data Container capacity / `EnsureCapacity` | release-noted — `VRCDataList` and `VRCDataDictionary` can be constructed with custom capacity; `VRCDataDictionary` exposes `EnsureCapacity()` | `ExternVRCSDK3DataDataList`: `get_Capacity`, `set_Capacity`; `ExternVRCSDK3DataDataDictionary`: `EnsureCapacity` | medium-high — useful for performance-sensitive data structures and avoids confusing DataList capacity with Dictionary capacity | `included` | Constructor support is release-note-backed but not visible as a Udon wrapper method in this census. |

### Related / gaps — not new 3.10.4 inclusions

| API | methods | doc status (oracle) | AI-relevance | status | notes |
|-----|---------|---------------------|--------------|--------|-------|
| VRCContactReceiver / VRCContactSender related wrappers | `CalculateProximity`, `UpdateCollisionTags` | related wrapper confirmation, not a 3.10.4 new-feature fact | medium | `candidate` | Already listed under the 3.10.3 documented-skip review as Pickup / Contacts coverage. Keep separate from the 3.10.4 box-contact / size / face-proximity feature. |
| Binary-only candidates carried forward from 3.10.3 | VRCPlayerApi Combat, VRCPlayerApi voice moderation, PlayerData `IsType`, Economy Store `OpenGroupListing`, Networking `GetEventDispatcher` | binary-only or lower-confidence reference gaps from the prior audit | varies | `candidate` | Remain candidates. The 3.10.4 release note does not promote them to release-noted stable facts. |

### No-change / not adopted

| Item | status | notes |
|------|--------|-------|
| Voice Audio Rework | `skip` | Not shipped in the audited release; do not add or reframe voice-audio guidance for this audit. |
| Runtime Texture Compression | `skip` | No authoring wrapper surface found in the 3.10.4 wrapper DLL census; not adopted into skill coverage from this audit. |
| World Preloading | `skip` | No authoring wrapper surface found in the 3.10.4 wrapper DLL census; not adopted into skill coverage from this audit. |

## Audit: SDK 3.10.5

Scope: [implementation Issue #360](https://github.com/niaka3dayo/agent-skills-vrc-udon/issues/360),
superseding [preview tracker #329](https://github.com/niaka3dayo/agent-skills-vrc-udon/issues/329).
The final stable Base/Worlds packages, not the beta feature list, define this release.

### Artifact and documentation evidence

- [Official release notes](https://creators.vrchat.com/releases/release-3-10-5/),
  [package release](https://github.com/vrchat/packages/releases/tag/3.10.5), and
  [VPM index](https://vrchat.github.io/packages/index.json), checked 2026-09-05 JST (2026-09-04 UTC).
  Package release timestamp: 2026-09-04 17:06:34 UTC (2026-09-05 02:06:34 JST).
- Official ZIP SHA-256: Base
  `fbfb3e7a38778dcb55d7a860286819e6f0726d10d5039f61474bd1b9c629029e`;
  Worlds `51fbd4812ca9216b91d4a242319f8a29058222f2819ecebc3bce086093ffda7c`.
  Downloaded archive hashes matched the official index. All 3,795 installed
  Base/Worlds files in the verification project matched the archives before testing.
- Re-censused official 3.10.4 and final 3.10.5 wrapper DLLs: 81 extern types in
  each; raw members 2,442 → 2,449, seven additions and no removals across three
  types. This counts raw wrapper symbols, not seven new user-facing APIs.
- The live [quality settings reference](https://creators.vrchat.com/worlds/udon/vrc-graphics/vrc-quality-settings/)
  already lists both properties; the live [Pickup reference](https://creators.vrchat.com/worlds/components/vrc_pickup/)
  already documents Outline Renderers. Neither is a reference-missing discovery.
  The quality page's “read-only” introduction conflicts with the new setters;
  the included guidance resolves that ambiguity rather than duplicating the page.

### Decisions

| Item | Evidence and expert delta | Status / destination |
|---|---|---|
| WorldQualitySettings | New SDK UdonSharp script + custom Inspector; script GUID appears in VRCWorld prefab and default scene. Startup always assigns Shadowmask Mode, while probes/shadow distance have separate overrides. Updating a package does not prove an existing scene gained it. | `included` — World components, lighting and routing; inspect existing serialized values before adding another controller. |
| VRCQualitySettings | Four new wrapper accessors: `RealtimeReflectionProbes` bool get/set and `ShadowmaskMode` UnityEngine.ShadowmaskMode get/set. Release notes allow realtime probes on all platforms; Distance Shadowmask is PC-only. | `included` — Udon api.md, routing and cheatsheet. Signature/compile evidence; effective renderer state, user-setting precedence and hardware performance are not inferred. |
| Assembly Version Defines | Compiler uses each Unity script assembly's defines; U# Assembly Definition is still required. Unknown `VRC_ENABLE_*` defines are filtered. | `included` — assembly-definitions.md and a short constraints rule. No source-grep hook for project-wide define state. |
| UdonSharp script creation in Assets/Packages | Final source fixes creation in both locations; beta.2 supersedes the earlier Assets-only restriction. | `included` — package authoring note; existing AutoGenerator left intact. |
| Pipeline Manager validation | WorldBuilder adds two `OnGUIError` call sites (6 → 8; warnings 22 and information 5 unchanged). Duplicate Auto Fix only preserves a manager on the descriptor object; none there means all managers are removed. Built-scene validator and upload guards also reject invalid counts. | `included` — build-validation.md, safe identity-preserving procedure and source anchors. No unrelated layer-policy changes. |
| Pickup Outline Renderers | Two new wrapper accessors; official component page documents renderer selection, supported types and fallback. | `skip` duplicate reference — official-page route and SDK summary only; no duplicate property table or sample. |
| Build & Reload | Release/source fix `VRC_SdkBuilder.ActiveBuildType` to `Test`, along with build callback/UI feedback. | `included` — brief editor-scripting/testing guidance; build export failure propagation remains source/history evidence. |
| ClientSim Play → Edit events | Official fix suppresses Udon Unity events such as OnDisable when leaving Play Mode. | `included` — testing boundary; do not treat Editor shutdown as gameplay callback evidence. |
| PhysBone Reset When Disabled | Official fix also resets animator parameters and Udon state. | `included` — short Dynamics debugging note; no new callback claim. |
| VRCJson nested braces / DataToken int-to-long | Official bug fixes, no new authoring contract requiring another recipe. | `skip` — release history; preserve existing Data Container guidance. |
| Contacts offset sphere / domain reload / ClientSim persistence | Official correctness fixes. | `skip` — release history; no new runtime API or unmeasured workaround. |
| Constraint Activate/Zero Undo and dirty state | Editor fix for existing operations. | `skip` — release history; no expanded constraint API table. |
| VRCInputMethod.Embodied | One new wrapper enum getter, absent from release-note contract. | `candidate` — existence only; no device mapping or runtime semantics asserted. |
| Internal C# parser version change | Source uses C# 9 parsing. Parser configuration does not prove Udon supports every C# 9 feature. | `candidate` — no general language-support expansion. |
| VRCBillboard / AttachTransformToBone / DetachTransformFromBone | Exact searches across final Base/Worlds files and wrapper census found none. | `skip` for 3.10.5; deferred preview history from #329, not a support promise or blocker for this final-artifact scope. |
| VRCRaycast RootTransform / avatar-only changes | Avatar authoring scope. | `skip` — outside both distributed world/Udon Skills. |
| AudioLink / Toon Standard changes | Shader/package integration release history, outside the selected scene/Udon expert delta. | `skip` — no new tutorial or dependency. |
| Layers runtime observations | Existing discrepancy in #295 remains separate; upstream documentation proposal is still open. | `skip` change — preserve measured observations and current guidance. |

Raw archives, SDK sources, census dumps and Unity probe artifacts stay in the
ignored SDK workspace and are excluded from npm. The recorded inclusion scope
does not claim live-client rendering or actual device performance was measured.

Unity 2022.3.22f1 with resolved Base/Worlds 3.10.5 generated three real Udon
programs: the public quality example (including enum/bool logging) contained all
four getter/setter externs; the same Version Define with expressions `3.10.5`
and `99.0.0` selected the expected opposite branches in compiled Udon heaps.
Unity also confirmed both shipped scene/prefab assets' nine quality values,
program asset links, and custom-editor registration/OnEnable. Inspector drawing,
clicks and live-client rendering were not tested. No regression of existing
local Unity assets was accepted: all 3,828 pre-existing files matched their
pre-test SHA-256 after the dedicated probe completed.
