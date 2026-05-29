# Context Preservation for UdonSharp Agent Work

Lightweight guide for keeping task-specific design intent available across long or resumed UdonSharp work.

**Applies to:** all supported SDK versions

This guide is optional and intended for complex work only. Use the format as a reusable note inside an existing task note, issue comment, scratchpad, or other user-approved location; it is not needed for trivial edits, and it does not ask for a new project file.

## Table of Contents

- [Why this exists](#why-this-exists)
- [Rule loss vs design-context loss](#rule-loss-vs-design-context-loss)
- [When to use a context-preservation note](#when-to-use-a-context-preservation-note)
- [When not to use one](#when-not-to-use-one)
- [Minimal task context note](#minimal-task-context-note)
- [Concrete example](#concrete-example)
- [Privacy notes](#privacy-notes)
- [Resume checklist after compaction](#resume-checklist-after-compaction)
- [See Also](#see-also)

---

## Why this exists

The reusable UdonSharp constraints already live in rules, references, cheatsheets, templates, and validation hooks. Those files preserve shared knowledge: which APIs are available, how ownership works, what late joiners receive, and how to test networking behavior.

Long agent tasks can lose a different kind of context: why this particular design was chosen. A later pass may remember that networking matters, yet miss that this door state is owner-written, restored from a synced variable, and intentionally not replayed from an event. The note below preserves that task-specific reasoning so resumed work does not rely only on conversation memory.

The goal is small and practical. Capture the few decisions that would be expensive to rediscover: source of truth, event transport, sync mode, storage, ownership behavior, late joiner behavior, and validation status.

---

## Rule loss vs design-context loss

### Rule loss

Rule loss happens when an agent forgets reusable UdonSharp facts already documented elsewhere.

Examples:

- Treating a non-owner write to a synced field as authoritative.
- Calling `RequestSerialization()` for Continuous sync, where automatic transmission is already expected.
- Reading PlayerData or PlayerObject values before `OnPlayerRestored` has fired.
- Expecting a network event to rebuild state for a player who joined after the event.

Use the existing references for this class of problem. This note format is not a replacement for `networking.md`, `persistence.md`, or `testing.md`.

### Design-context loss

Design-context loss happens when the reusable rules are remembered, but the task-specific reason is gone.

Examples:

- A synced field exists, but the next pass cannot tell whether it is the source of truth or a transport copy.
- A non-owner request path exists, but the ownership-transfer trigger is unclear.
- A PlayerObject is involved, but the note does not say which reads wait for `OnPlayerRestored`.
- A late-joiner bug was fixed, but the validation that proved it is not recorded.

Use a context-preservation note to keep this local reasoning visible during complex work.

---

## When to use a context-preservation note

Consider a note for work that includes any of these traits:

- New synced systems or changes to existing synced state.
- Ownership-sensitive interactions, late-joiner-sensitive behavior, or PlayerData/PlayerObject persistence.
- Complex multi-file refactors where the design reason is easy to lose.
- Work resumed after context compaction, restart, handoff, or split across multiple agent runs.

---

## When not to use one

Skip the note for work where the design context is obvious from the diff:

- Typo fixes.
- Small documentation edits or formatting-only changes.
- One-file mechanical updates or metadata-only maintenance.

---

## Minimal task context note

This is a lightweight prompt, not a heavy planning framework. Keep only the fields that help the next pass continue safely.

### Goal

- Behavior being added, fixed, or preserved.
- Existing behavior that should remain unchanged.

### Relevant files

- Edited files, reference files, validation files, scenes, or assets.

### UdonSharp constraints relevant to this task

- Constraints that shaped this task: ownership writes, sync mode, restore timing, unsupported APIs, or unsupported language features.

### Source of truth

Choose the authoritative state holder for this task:

- Local-only state, scene object owner, instance master, or per-player owner.
- PlayerObject state with automatic per-player ownership, PlayerData storage, or derived state.
- Hybrid model; name the authoritative field or object for each part.

Why this was chosen:

- Record the reason this source is authoritative, and note which state is only cached or derived locally.

### Transport (events)

Choose how one-shot messages are transported, if any:

- No network event, or local-only `SendCustomEvent`.
- `SendCustomNetworkEvent`, `[NetworkCallable]`, or a hybrid event path.

Why this was chosen:

- Record whether the event is a request, notification, effect trigger, or convenience call.
- Capture that network events are not replayed to late joiners; persistent state should be restored from synced or stored state instead.

### Sync mode (Manual vs Continuous)

Choose how state replication works, if any:

- No synced variables.
- `[UdonSynced]` with Manual sync, Continuous sync, or a mixed split.
- Synced transport copy with local derived presentation state.

Why this was chosen:

- For Manual sync, record where `RequestSerialization()` is called after changed synced fields.
- For Continuous sync, record why automatic transmission fits and why `RequestSerialization()` is not part of the path.
- Capture that synced variables are automatically sent to late joiners.

### Storage & persistence

Choose whether state persists beyond the current instance:

- No persistence, synced state only for the live instance, PlayerData, or PlayerObject.
- Hybrid storage; list which fields persist and which reset.

Why this was chosen:

- Record the lifecycle: per-session, per-player, per-object, or durable player preference.
- For PlayerObject, note that ownership is auto-assigned and `Networking.SetOwner()` is not needed for the PlayerObject itself.
- For PlayerData or PlayerObject reads, record which code waits for `OnPlayerRestored`.

### Ownership model

- Record the initial owner, ownership transfer trigger, non-owner request path, owner-left behavior, and concurrent interaction behavior.

Capture owner-left handling as an observable design choice. Ownership transfers automatically; if state needs to be re-broadcast or presentation needs to be re-applied, record the `OnOwnershipTransferred` follow-up.

### Late joiner behavior

- Record what the late joiner should see, which synced fields or stored values restore that state, which event-only effects are intentionally not replayed, and which callback applies the received state locally.

### Synced fields & bandwidth

- List synced fields, derived-locally fields, intentionally-not-synced fields, and throttling, batching, or packing decisions.

### Decisions & rejected alternatives

- Record the decision made, the alternative considered, and the reason the alternative was left out for this task.

### Validation

- Repo checks run and validation hooks triggered.
- Unity Editor, ClientSim, Build & Test multi-client, late-joiner, and owner-left checks planned or completed.

---

## Concrete example

```text
Task context note: shared door controller

Goal:
- Preserve open/closed state for all players.

Relevant files:
- DoorController.cs
- references/networking.md
- references/testing.md

Source of truth:
- Door object's synced bool.
- Why: late joiners need open/closed state without replaying past events.

Transport (events):
- SendCustomNetworkEvent only for the click sound.
- Why: sound is momentary and does not need late-joiner replay.

Sync mode (Manual vs Continuous):
- Manual sync for the open/closed bool.
- Why: value changes only on interaction; owner writes the bool and requests serialization.

Storage & persistence:
- No PlayerData or PlayerObject storage.
- Why: the door resets between instances.

Ownership model:
- Default scene owner initially; non-owner interaction requests ownership before changing the bool.
- OnOwnershipTransferred reapplies the current bool and re-serializes if this client became owner after a handoff.

Late joiner behavior:
- Late joiners receive the synced bool and apply the animator state from it.

Validation:
- Multi-client interaction test.
- Late-joiner test after opening and closing.
- Owner-left test while open.
```

---

## Privacy notes

Keep the note focused on decisions and evidence. Avoid storing secrets, API keys, tokens, private URLs, private client information, raw private email contents, full conversation transcripts, or unnecessary personal data.

Summarize the relevant decision, file, test, or observed behavior instead.

---

## Resume checklist after compaction

1. Re-read the current user instruction or task issue.
2. Re-read the relevant UdonSharp rules for the edited file type.
3. Read the existing context-preservation note.
4. Re-open every file named in the note's Relevant files section.
5. Confirm the recorded source of truth and transport path against the current code.
6. Confirm whether any event-only behavior affects late joiners.
7. Confirm the sync mode and the current `RequestSerialization()` or Continuous-sync path.
8. Confirm PlayerData or PlayerObject reads wait for `OnPlayerRestored` when persistence is involved.
9. Confirm ownership transfer and owner-left behavior in the current code.
10. Confirm late-joiner restoration from synced or stored state.
11. Confirm the validation status by reading the most recent command output or running the next listed check.
12. Update the note when a design decision changes.

---

## See Also

- [networking.md](networking.md) - Ownership, network events, sync modes, late joiners, and owner-left behavior
- [persistence.md](persistence.md) - PlayerData and PlayerObject restore timing
- [testing.md](testing.md) - ClientSim, Build & Test, multi-client, late-joiner, and owner-left validation
