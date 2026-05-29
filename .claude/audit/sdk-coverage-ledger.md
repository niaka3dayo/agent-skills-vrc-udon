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

> **Nothing in this ledger is in the skill yet.** A `candidate` is a discovery
> pending behavior verification (gate 3), not an inclusion decision.

## Audit: SDK 3.10.3 (initial)

### Candidates — undocumented-but-shipped, pending behavior verification

| API | methods | doc status (oracle) | AI-relevance | status | notes |
|-----|---------|---------------------|--------------|--------|-------|
| VRCPlayerApi voice getters | `GetVoiceGain`, `GetVoiceDistanceNear`, `GetVoiceDistanceFar`, `GetVoiceLowpass`, `GetVoiceVolumetricRadius` | undocumented — player-audio page documents all 5 **setters**, getters absent there + on players + udonsharp api pages (decisive page checked) | high — clean setter/getter asymmetry; agents know the documented setters but not these | `candidate` | strongest, lowest-risk candidate. Gate 3: confirm getter return semantics (current vs last-set; local vs remote) before any claim |
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
