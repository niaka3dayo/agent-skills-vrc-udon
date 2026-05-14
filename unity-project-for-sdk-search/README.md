# SDK Verification Workspace

This directory is a **gitignored** workspace for verifying VRChat SDK APIs against the actual shipped SDK binary. Drop a Unity project with the VRChat World SDK installed here, then `grep` the SDK DLLs to confirm whether a specific API exists.

Only this `README.md` is tracked. Anything else placed under `unity-project-for-sdk-search/` is gitignored — see the repo root `.gitignore` for the rule.

## Why this exists

Public VRChat documentation lags behind the shipped SDK. While triaging knowledge-request Issues we have repeatedly hit cases where:

- `creators.vrchat.com/worlds/udon/networking/network-components/` omits a method that exists in the SDK,
- `vrchat-community/UdonSharp` API page (the canonical `udonsharp.docs.vrchat.com/vrchat-api/`) does not yet list newly added methods,
- third-party tutorials echo the stale public docs.

The authoritative source is the SDK DLL itself. This directory makes that source one `grep` away.

**Reference precedent**: Issue #190 (VRCObjectPool ownership patterns) — the maintainer reported a `Shuffle()` method that every public source omitted; verification required SDK DLL inspection, which confirmed the method exists.

## Setup

1. Open Unity Hub. Create a new Unity project here, for example:

   ```
   unity-project-for-sdk-search/sdk-search-project/
   ```

2. Install the VRChat World SDK via VPM (VRChat Creator Companion).

3. The SDK lands at:

   ```
   unity-project-for-sdk-search/sdk-search-project/Packages/com.vrchat.worlds/
   ```

4. Optional: install UdonSharp via VPM (already a dependency of Worlds SDK).

## Verification commands

The two most useful DLLs are under `Packages/com.vrchat.worlds/Runtime/`. The Udon wrapper DLL is the highest-signal source because it lists every API that Udon (and therefore UdonSharp) can call.

```bash
# Set this once per shell session — adjust the project subdirectory name if you used a different one.
SDK="unity-project-for-sdk-search/sdk-search-project/Packages/com.vrchat.worlds"

# 1. Does method `X` exist on `VRCSomeComponent`? Inspect the Udon wrapper symbols.
strings -a "$SDK/Runtime/Udon/External/VRC.Udon.VRCWrapperModules.dll" \
  | grep -E "VRCSomeComponent|__X__"

# 2. Or scan the main SDK assembly for the raw method name.
strings -a "$SDK/Runtime/VRCSDK/Plugins/VRCSDK3.dll" | grep X

# 3. Open SDK source files where present (some integrations ship as .cs).
grep -rn "VRCSomeComponent" "$SDK/" --include="*.cs"
```

## Udon wrapper symbol legend

Symbols inside `VRC.Udon.VRCWrapperModules.dll` follow this format:

```
# Method with no arguments
__<MethodName>__<ReturnType>

# Method with arguments — ArgTypes come BEFORE ReturnType
__<MethodName>__<ArgType1>[_<ArgType2>...]__<ReturnType>
```

The ordering matters: **arg types precede the return type**, separated by `__`. Multiple arg types within the args segment are joined by a single `_`.

> This format is **observed empirically** in SDK 3.10.3's `VRC.Udon.VRCWrapperModules.dll`. It is not a documented public contract — VRChat could change Udon's symbol naming in a future SDK release. If a grep against a newer SDK starts returning surprising results, re-derive the format from a known method (e.g. `__TryToSpawn__UnityEngineGameObject` for `GameObject TryToSpawn()`) and update this legend.

Examples (taken from `ExternVRCSDK3ComponentsVRCObjectPool` block, SDK 3.10.3):

| Symbol | Decoded signature |
|---|---|
| `__TryToSpawn__UnityEngineGameObject` | `GameObject TryToSpawn()` — no args, return = GameObject |
| `__Shuffle__SystemVoid` | `void Shuffle()` — no args, return = void |
| `__Return__UnityEngineGameObject__SystemVoid` | `void Return(GameObject)` — one arg = GameObject, return = void |

Hypothetical multi-arg form: `__Foo__SystemInt32_UnityEngineTransform__SystemVoid` would decode to `void Foo(int, Transform)`.

Note that other shorter tokens (e.g. a plain `Return` string with no `__` framing) sometimes also appear in the DLL — those are unrelated symbols (property names, enum values, etc.) and are not the method wrapper. The `__<Method>__...` form is the only authoritative signal that Udon can dispatch to that method.

## What NOT to do

- Do not commit the SDK or any Unity-generated files. The `.gitignore` rule blocks them automatically; do not bypass with `git add -f`.
- Do not redistribute the SDK contents. VRChat's SDK license is non-redistribution.
- Do not symlink this directory into another location that gets packed into npm. The `npm Pack Test` CI catches this, but avoid the round-trip.
- Do not assume "Shuffle exists in the wrapper DLL" means the method is publicly supported. It only means Udon can call it. Confirm runtime behavior (owner-only? network-synced?) by additional means (Unity Editor IntelliSense, SDK release notes, hands-on test) before documenting it in the skill.
- Do not infer **runtime semantics** (ownership rules, event scoping, sync timing, side effects, silent-failure modes) from method existence alone. `strings | grep` confirms whether a method is callable via Udon — it does NOT confirm whether the method is owner-only, what client receives a network event, what state syncs and when, or what happens when called in an invalid context. Runtime contracts must be verified against [creators.vrchat.com](https://creators.vrchat.com/) or hands-on **multi-client** testing in Unity. Precedent: PR #194 (Issue #190) shipped an initially-broken `NetworkEventTarget.Owner` example because the DLL confirmed method existence while the runtime target-resolution rule lived only in the public docs — caught pre-merge by independent reviewers (CodeRabbit + Codex Connector) citing creators.vrchat.com.

## Updating SDK versions

When VRChat ships a new SDK release, update the local project via VPM (Creator Companion → "Update" on the World SDK package). No repo change is required — re-run the same `grep` commands against the new DLL.
