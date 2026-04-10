---
name: unity-vrc-udon-sharp
description: >
    UdonSharp (C# to Udon Assembly) scripting skill for VRChat world development.
    Use this skill when writing, reviewing, or debugging UdonSharp C# code.
    Covers compile constraints (List<T>/async/await/try/catch/LINQ blocked),
    network sync (UdonSynced, RequestSerialization, FieldChangeCallback, NetworkCallable),
    persistence (PlayerData/PlayerObject), Dynamics (PhysBones, Contacts),
    Web Loading, VRAM management (texture lifecycle, Dispose vs Destroy),
    and event handling. SDK 3.7.1 - 3.10.2 coverage.
    Triggers on: UdonSharp, Udon, VRC SDK, UdonBehaviour, UdonSynced,
    NetworkCallable, VRCPlayerApi, SendCustomEvent, PlayerData, PhysBones,
    synced variables, VRChat world scripting, C# to Udon.
license: MIT
metadata:
    author: niaka3dayo
    version: "1.2.1"
    tags: vrchat, udonsharp, udon, networking, sync, persistence, dynamics
---

# UdonSharp Skill

## Why This Skill Matters

UdonSharp looks like regular Unity C# scripting — until you hit its hidden walls. Many standard C# features (`List<T>`, `async/await`, `try/catch`, LINQ, generics) **silently fail or refuse to compile** in Udon. Networking is even more treacherous: modifying a synced variable without ownership produces no error — it just does nothing. Forgetting `RequestSerialization` means your state changes never leave your machine. Standard single-player local testing gives zero signal about these networking bugs because there is only one player.

Every rule in this skill exists because UdonSharp's default behavior is to **fail silently**. Read the Rules before generating any code.

## Core Principles

1. **Constraints First** — Assume standard C# features are blocked until verified. Check `udonsharp-constraints.md` before using any API.
2. **Ownership Before Mutation** — Only the owner of an object can modify its synced variables. Always `SetOwner` → modify → `RequestSerialization`.
3. **Late Joiner Correctness** — State must be correct for players who join after events have occurred. Design for re-serialization, not just live updates.
4. **Sync Minimization** — Every synced variable costs bandwidth (see data budget in `udonsharp-sync-selection.md`). Derive what you can locally; sync only the source of truth.
5. **Event-Driven, Not Polling** — Use `OnDeserialization`, `[FieldChangeCallback]`, and `SendCustomEvent` instead of checking state in `Update()`.

## Common Mistakes (NEVER List)

These constraints cause **silent failures** — no compiler error, no runtime exception, just broken behavior. Check this list before writing any UdonSharp code.

| # | NEVER do this | Why it fails silently | Use instead |
|---|---------------|----------------------|-------------|
| 1 | Use `List<T>`, `Dictionary<T,K>`, or any generic collection | Compile error — blocked by Udon compiler | `T[]` arrays, `DataList`, `DataDictionary` |
| 2 | Use `async`/`await`, `System.Threading`, or coroutines | Udon is single-threaded; these features do not exist | `SendCustomEventDelayedSeconds()` |
| 3 | Modify `[UdonSynced]` fields without owning the object | Change appears local but is **silently reverted** on next deserialization | `Networking.SetOwner()` before modify, then `RequestSerialization()` |
| 4 | Forget `RequestSerialization()` after modifying synced fields (Manual sync) | State changes never leave the local client — no error, no warning | Always call `RequestSerialization()` after modifying `[UdonSynced]` fields |
| 5 | Use `try`/`catch`/`finally`/`throw` | Compile error — exception handling is blocked | Defensive null checks + early return |
| 6 | Access `Networking.LocalPlayer` in field initializers | Field initializers run at compile time — `LocalPlayer` is null | Initialize in `Start()` or use lazy-init guard |
| 7 | Use `static` fields for per-instance state | Static fields are shared across all instances on the same client and are not synced | Instance fields with `[UdonSynced]` if sync is needed |
| 8 | Call `RequestSerialization()` every frame in Manual sync | Floods the ~11 KB/s network budget, causing congestion for the entire world | Throttle to 1-10 Hz with change detection; check `Networking.IsClogged` |
| 9 | Use LINQ (`.Where`, `.Select`, etc.) or lambda expressions | Compile error — not supported by Udon compiler | Manual `for` loops with named methods |
| 10 | Use `Button.onClick.AddListener()` | Not available in Udon — no runtime delegate support | Configure `SendCustomEvent` via Inspector OnClick |
| 11 | Mix Continuous and Manual sync concerns on one behaviour | Wastes bandwidth (discrete values in Continuous) or loses control (redundant `RequestSerialization` in Continuous) | Separate behaviours: Continuous for position/rotation, Manual for discrete state |
| 12 | Write synced variables before `OnOwnershipTransferred` confirms ownership | `SetOwner` is async — writes before confirmation are silently discarded | Store intent locally, write + serialize in `OnOwnershipTransferred` callback |
| 13 | Use `[NetworkCallable]` on SDK < 3.8.1 | Attribute compiles but is **silently ignored** — methods never receive network calls | Verify SDK >= 3.8.1; on older SDKs use synced variables + `SendCustomNetworkEvent` |
| 14 | Use PhysBones/Contacts API (`OnPhysBoneGrab`, `OnContactEnter`, etc.) on SDK < 3.10.0 | Events and components do not exist for worlds — code compiles but callbacks never fire | Verify SDK >= 3.10.0; Dynamics for Worlds was added in 3.10.0 |
| 15 | Use `PlayerData` persistence API on SDK < 3.7.4 | `PlayerData`, `PlayerObject`, `OnPlayerRestored` do not exist — compile or silent runtime failure | Verify SDK >= 3.7.4; persistence was added in 3.7.4 |
| 16 | Create a `.cs` script without a corresponding `.asset` file | Script is not recognized as UdonBehaviour — "The associated script cannot be loaded", no Udon compilation | Install `UdonSharpProgramAssetAutoGenerator.cs` template in an `Editor` folder, or create scripts via Unity's Assets > Create > U# Script |

## Sync Mode Quick Decision

```
Changing every frame (position, rotation)?    -> Continuous sync
Changing on user action (toggle, score)?      -> Manual sync + RequestSerialization()
No sync needed (local UI, effects)?           -> NoVariableSync
Need reliable one-shot calls with params?     -> [NetworkCallable] (SDK 3.8.1+)
Temporary effect for all players, no state?   -> SendCustomNetworkEvent (no synced vars)
```

> For detailed decision trees, data budget, and minimization principles, see `rules/udonsharp-sync-selection.md`.

## Reference Loading Guide

Load only what you need. Over-loading wastes tokens; under-loading causes critical mistakes.

| Task | MANDATORY READ | Optional | Do NOT Load |
|------|---------------|----------|-------------|
| Writing networking/sync code | `networking.md`, `networking-antipatterns.md` | `networking-bandwidth.md`, `sync-examples.md` | `dynamics.md`, `web-loading.md`, `image-loading-vram.md` |
| Building UI/menus | `patterns-ui.md`, `events.md` | `patterns-core.md`, `api.md` | `networking-bandwidth.md`, `dynamics.md`, `web-loading.md` |
| Implementing persistence (save/load) | `persistence.md` | `patterns-networking.md`, `events.md` | `dynamics.md`, `web-loading.md`, `image-loading-vram.md` |
| Downloading strings/images from web | `web-loading.md` | `web-loading-advanced.md`, `image-loading-vram.md` | `dynamics.md`, `persistence.md`, `networking-bandwidth.md` |
| Using PhysBones/Contacts/Constraints | `dynamics.md`, `events.md` | `patterns-networking.md`, `api.md` | `web-loading.md`, `image-loading-vram.md`, `persistence.md` |
| Optimizing performance (Update loops) | `patterns-performance.md` | `patterns-utilities.md`, `api.md` | `dynamics.md`, `web-loading.md`, `persistence.md` |
| Building a video player | `patterns-video.md` | `events.md`, `web-loading.md` | `dynamics.md`, `persistence.md`, `image-loading-vram.md` |
| Debugging/troubleshooting | `troubleshooting.md` | `constraints.md`, `networking.md` | `patterns-*.md`, `dynamics.md`, `web-loading.md` |
| Creating new UdonSharp scripts | `editor-scripting.md` | `troubleshooting.md` | `networking.md`, `dynamics.md` |

## Pattern Selection Guide

Six pattern files cover different domains. Use this quick routing to pick the right one:

```
Building a UI, menu, or HUD?           -> patterns-ui.md
VR finger/touch interaction on Canvas? -> patterns-ui.md
Modular app with multiple screens?     -> patterns-ui.md
Syncing state across players?           -> patterns-networking.md
Optimizing Update() or heavy loops?     -> patterns-performance.md
Heavy rebuild, replay, or reset/cancel?  -> patterns-performance.md
Playing or streaming video?             -> patterns-video.md
Need array helpers, event bus, or       -> patterns-utilities.md
  pseudo-delegates?
Basic interactions, timers, audio,      -> patterns-core.md
  pickups, or teleportation?
Station + trigger zone detection?       -> troubleshooting.md
```

> Multiple concerns? Load the primary pattern file plus its dependencies. For example, a synced video player needs both `patterns-video.md` and `patterns-networking.md`.

## Template Selection Guide

17 templates cover common starting points. Pick the closest match and adapt:

| Starting Point | Template | Key Feature |
|---|---|---|
| **Interaction & Objects** | | |
| Interactive object (click/use) | `BasicInteraction.cs` | Cooldown, toggle, audio feedback |
| Synced toggle / shared object | `SyncedObject.cs` | Ownership guard, FieldChangeCallback, late-joiner init |
| Per-player movement settings | `PlayerSettings.cs` | Walk/run/jump speed via trigger zone |
| Contact-based collision detection | `ContactReceiver.cs` | OnContactEnter/Exit, avatar vs world, debounce (SDK 3.10.0+) |
| **State & Game Logic** | | |
| State machine / game flow | `StateMachine.cs` | Timed transitions, synced state, late-joiner safety |
| Game with undo/history | `UndoableGameManager.cs` | byte[] history, NetworkCallable OwnerProcessMove/Undo/Reset |
| Object pool (player slots) | `MasterManagedPlayerPool.cs` | FIFO ring buffer, master-managed, OnPlayerJoined/Left |
| **Persistence & Data** | | |
| Save/load player data | `DataPersistence.cs` | PlayerData API, OnPlayerRestored, auto-save (SDK 3.7.4+) |
| **Networking Patterns** | | |
| Rate-limited sync (slider drag) | `RateLimitedSync.cs` | 0.15s cooldown, last-write-wins |
| Batched sync (rapid events) | `BatchedSync.cs` | Idempotent schedule, 0.2s delay, single packet |
| Congestion-aware retry | `CloggedRetrySync.cs` | IsClogged check, linear back-off, MaxRetries |
| Dual local+synced copy | `DualCopySync.cs` | Local working copy + synced transport, dirty flag |
| Pack multiple values into one field | `PackedStateSync.cs` | 3 ints in one Vector3, reduced sync overhead |
| **Utilities** | | |
| Array helpers (List\<T\> alternative) | `ArrayUtils.cs` | Add, Remove, Contains, FindIndex, Shuffle for arrays |
| Event bus (pub/sub) | `EventBus.cs` | Subscriber list (max 32), RegisterListener/RaiseEvent |
| Custom editor inspector | `CustomInspector.cs` | UdonSharpGUI, Undo, proxy sync |
| Auto-generate .asset for new scripts | `UdonSharpProgramAssetAutoGenerator.cs` | AssetPostprocessor, domain-reload-only, auto-compile |

> **Multiple needs?** Start with the template closest to your primary concern, then pull patterns from others. For example, a synced game with undo needs `UndoableGameManager.cs` as the base plus patterns from `RateLimitedSync.cs` for throttling.

## Overview

**SDK Coverage**: 3.7.1 - 3.10.2 (as of March 2026)

## Rules (Constraints & Networking)

Compile constraints and networking rules are defined in **always-loaded Rules**:

| Rule File | Contents |
|-----------|----------|
| `rules/udonsharp-constraints.md` | Blocked features, code generation rules, attributes, syncable types |
| `rules/udonsharp-networking.md` | Ownership, sync modes, RequestSerialization, NetworkCallable |
| `rules/udonsharp-sync-selection.md` | Sync pattern selection, data budget, minimization principles |

> After installation, place these in the agent's rules directory for automatic loading.

## SDK Versions

| SDK Version | Key Features |
|-------------|--------------|
| 3.7.1 | Added `StringBuilder`, `RegularExpressions`, `System.Random` |
| 3.7.4 | Added **Persistence API** (PlayerData/PlayerObject) |
| 3.7.6 | Multi-platform Build & Publish (PC + Android simultaneously) |
| 3.8.0 | PhysBone dependency sorting, Drone API (VRCDroneInteractable) |
| 3.8.1 | **`[NetworkCallable]`** attribute, parameterized network events, `NetworkEventTarget.Others`/`.Self` |
| 3.9.0 | Camera Dolly API, Auto Hold pickup simplification |
| 3.10.0 | **VRChat Dynamics for Worlds** (PhysBones, Contacts, VRC Constraints) |
| 3.10.1 | Bug fixes and stability improvements |
| 3.10.2 | EventTiming extensions, PhysBones fixes, shader time globals |

> **Note**: SDK versions below 3.9.0 are **deprecated as of December 2, 2025**. New world uploads are no longer possible.

## Web Search

### When to Search

| Scenario | Action |
|----------|--------|
| New SDK version support | Check official docs for latest API |
| "Is this possible?" questions | Verify feasibility in official docs |
| Unknown errors | Refer to official troubleshooting |
| New feature usage | Retrieve latest code examples |

### Search Strategy

```
# Official documentation search
WebSearch: "feature or API name site:creators.vrchat.com"

# UdonSharp API reference
WebSearch: "API name site:udonsharp.docs.vrchat.com"

# Error investigation: VRChat official forums
WebSearch: "error message site:ask.vrchat.com"

# Error investigation: Canny (bug reports / known issues)
WebSearch: "error message site:feedback.vrchat.com"

# Error investigation: GitHub Issues
WebSearch: "error message UdonSharp site:github.com"
```

### Official Resources

| Resource | URL | Contents |
|----------|-----|----------|
| VRChat Creators | creators.vrchat.com/worlds/udon/ | Official Udon / SDK documentation |
| UdonSharp Docs | udonsharp.docs.vrchat.com | UdonSharp API reference |
| VRChat Forums | ask.vrchat.com | Q&A, solutions |
| VRChat Canny | feedback.vrchat.com | Bug reports, known issues |
| GitHub | github.com/vrchat-community | Samples and libraries |

## References

| File | Contents | Search Hints |
|------|----------|--------------|
| `constraints.md` | C# feature availability in UdonSharp; blocked features; syncable types; attributes; DataList vs array decision guidance; advanced workarounds (object array pseudo-struct, VRCUrl array sync) | List, async, try/catch, LINQ, generics, DataList, DataDictionary, DataList vs array, when to use DataList, VRCUrl array, VRCUrl sync, pseudo-struct, object array cast, multi-field state container |
| `networking.md` | Ownership model, sync modes, RequestSerialization, NetworkCallable, network events, data limits | UdonSynced, SetOwner, BehaviourSyncMode, FieldChangeCallback, OnDeserialization, master leave, ownership cascade |
| `networking-bandwidth.md` | Bandwidth throttling, bit packing, synced data size examples, debugging, owner-centric architecture | IsClogged, bandwidth, throttle, bit packing, data budget, IsMaster |
| `networking-antipatterns.md` | 6 anti-patterns to avoid; 5 advanced sync patterns with template links | anti-pattern, race condition, ownership fight, late-joiner, PackedStateSync, BatchedSync |
| `persistence.md` | Storage layer decision tree (local/synced/PlayerData/PlayerObject); PlayerData/PlayerObject API (SDK 3.7.4+); per-player save data; storage usage query API (SDK 3.10.0+) | storage layer, decision tree, local variable, PlayerData, PlayerObject, OnPlayerRestored, SetInt, TryGetInt, GetPlayerDataStorageUsage, GetPlayerDataStorageLimit, RequestStorageUsageUpdate, OnPersistenceUsageUpdated, storage quota, storage usage, which storage, when to use PlayerData |
| `dynamics.md` | PhysBones, Contacts, VRC Constraints (SDK 3.10.0+) | PhysBone, ContactReceiver, ContactSender, VRCConstraint, OnContactEnter |
| `patterns-core.md` | Initialization, interaction, player detection, timer, audio, pickup, animation, UI, teleportation, lazy init guard | Interact, OnEnable, Initialize, AudioSource, VRCPickup, Animator, UI, TeleportTo |
| `patterns-networking.md` | Object pooling, NetworkCallable patterns, persistence integration, dynamics integration, synced game state, delayed event debounce, string join for array sync | pool, MasterManagedPlayerPool, NetworkCallable, DamageReceiver, game state, debounce, state machine, string join, array sync, paragraph separator, U+2029 |
| `patterns-performance.md` | Partial class pattern, update handler, PostLateUpdate, spatial query, platform optimization, frame budget Stopwatch, heavy processing architecture (rebuild, replay, reset/cancel), rate limit resolver | Update, PostLateUpdate, Bounds, AnimatorHash, performance, mobile, PC, Stopwatch, frame budget, SendCustomEventDelayedFrames, heavy processing, rebuild, replay, reset, cancel, operation log, authoritative data, derived state, cursor rebuild, rate limit, URL scheduler, video load queue |
| `patterns-utilities.md` | Array helpers (List alternatives), event bus, GameObject relay communication, pseudo-struct double-cast, abstract class callback, cancellable delayed event, re-entrance guard, UdonEvent pseudo-delegate | ArrayUtils, EventBus, relay, subscriber, FindIndex, ShuffleArray, object array, pseudo struct, double cast, abstract class, callback, interface alternative, cancellable timer, re-entrance, emitting guard, UdonEvent, pseudo delegate |
| `patterns-ui.md` | UI/Canvas patterns: immobilize guard, avatar-scale-aware UI, FOV-responsive positioning, platform-adaptive layout, dynamic player list, scroll input abstraction, lookup-table localization, toggle-animator bridge, settings persistence via PlayerObject, listener-based menu events, finger touch interaction, modular app architecture | Canvas, UI, menu, Immobilize, avatar scale, FOV, platform, Quest, VR, desktop, player list, scroll, localization, language, Toggle, Animator, PlayerObject, settings, persistence, listener, broadcast, finger touch, fingertip, haptic, FingerPointer, FingerTouchCanvas, touch canvas, app architecture, AppModule, AppManager, plugin lifecycle, CanvasGroup transition |
| `patterns-video.md` | Video player state machine, server-time playback sync, late joiner sync, AVPro Blit buffering, error retry with fallback, synced playlist/queue, platform URL selection | video player, AVPro, VRCUnityVideoPlayer, BaseVRCVideoPlayer, playback sync, server time, GetServerTimeInMilliseconds, late joiner, VRCGraphics.Blit, OnVideoReady, OnVideoError, retry, fallback, playlist, queue, shuffle, repeat, Quest URL |
| `web-loading.md` | String/Image downloading, VRCJson, Trusted URLs | VRCStringDownloader, VRCImageDownloader, VRCJson, DataDictionary, VRCUrl |
| `image-loading-vram.md` | Advanced VRAM management for image loading: Destroy vs Dispose, double-buffer fade, stock mode, mipmap bias | VRAM, texture memory, memory leak, Destroy, Dispose, double buffer, fade, mipmap, TextureInfo |
| `web-loading-advanced.md` | Advanced data loading: Base64 texture embedding via StringDownloader, cross-platform compression, URL double-key indexing, LRU decode cache | Base64, LoadRawTextureData, StringDownloader texture, DXT1, ETC_RGB4, UNITY_ANDROID, LRU cache, packed resources, binary format |
| `api.md` | VRCPlayerApi, Networking, enums reference | GetPlayers, playerId, isMaster, isLocal, GetPosition, SetVelocity, Drone, VRCDroneApi |
| `events.md` | All Udon events (including OnPlayerRestored, OnContactEnter) | OnPlayerJoined, OnPlayerLeft, OnPlayerTriggerEnter, OnOwnershipTransferred |
| `editor-scripting.md` | Editor scripting, proxy system, and UdonSharpProgramAsset auto-generation | UdonSharpEditor, UdonSharpBehaviourProxy, SerializedObject, UdonSharpProgramAsset, auto-generate, AssetPostprocessor, .asset missing |
| `sync-examples.md` | Sync pattern examples (Local/Events/SyncedVars) | Continuous, Manual, NoVariableSync, sync example |
| `troubleshooting.md` | Common errors and solutions | NullReference, compile error, sync not working, FieldChangeCallback, VRCStation, seated player, trigger zone, OnPlayerTriggerEnter not firing, station collider, position polling, OnStationEntered |
| `sdk-migration.md` | SDK migration guide (3.7 to 3.10), version-by-version changes and checklists | migration, deprecated, upgrade, 3.7, 3.8, 3.9, 3.10 |

## Templates (`assets/templates/`)

| Template | Purpose |
|----------|---------|
| `BasicInteraction.cs` | Interactive object with `Interact()` handler |
| `SyncedObject.cs` | Network-synced object (Manual sync, ownership guard, late-joiner init flag) |
| `PlayerSettings.cs` | Per-player movement settings (walk/run/jump speed) |
| `StateMachine.cs` | State machine with synced state and transitions |
| `DataPersistence.cs` | PlayerData save/load with OnPlayerRestored (SDK 3.7.4+) |
| `ContactReceiver.cs` | Contact receiver for world-side collision detection (SDK 3.10.0+) |
| `CustomInspector.cs` | Custom editor inspector with UdonSharpEditor |
| `MasterManagedPlayerPool.cs` | Master-managed player object pool; FIFO ring buffer; OnPlayerJoined/Left; VerifyAssignments after master handoff |
| `EventBus.cs` | Subscriber list event bus (max 32 listeners); RegisterListener/UnregisterListener/RaiseEvent; in-place compaction |
| `ArrayUtils.cs` | List\<T\> alternatives: Add, Contains, AddUnique, Remove, RemoveAt, Insert for GameObject[]; FindIndex/ShuffleArray for int[] |
| `UndoableGameManager.cs` | History/undo sync with byte[] state history; NetworkCallable OwnerProcessMove/OwnerUndo/OwnerReset |
| `PackedStateSync.cs` | Pack 3 ints into one Vector3 UdonSynced field; OnPreSerialization/OnDeserialization |
| `RateLimitedSync.cs` | 0.15s sync cooldown with _syncLocked/_changeCounter; _OnSyncUnlock callback |
| `DualCopySync.cs` | Local + synced copy with _dirty flag; strict OnPreSerialization/OnDeserialization separation |
| `BatchedSync.cs` | Idempotent ScheduleBatchedSync with 0.2s BatchDelay; _FlushBatch delayed callback |
| `CloggedRetrySync.cs` | Networking.IsClogged check; linear back-off (RetryDelay * retryCount); MaxRetries=5 |
| `UdonSharpProgramAssetAutoGenerator.cs` | AssetPostprocessor that auto-creates UdonSharpProgramAsset for new scripts |

## Hooks

| Hook | Platform | Purpose |
|------|----------|---------|
| `validate-udonsharp.ps1` | Windows (PowerShell) | PostToolUse constraint validation |
| `validate-udonsharp.sh` | Linux/macOS (Bash) | PostToolUse constraint validation |

## Quick Reference

- `CHEATSHEET.md` - One-page quick reference
