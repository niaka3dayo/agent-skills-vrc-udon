# UdonSharp Assembly Definitions and VPM Package Workflows

## Beginner-Friendly Default

For ordinary, world-only, simple one-off UdonSharp scripts, **do not add an asmdef by default**. Keep the script under `Assets/` without a Unity assembly definition unless there is a concrete package, compile-boundary, or editor/runtime separation need. This keeps the script in Unity's default `Assembly-CSharp` path and avoids extra UdonSharp assembly wiring for beginners.

Reach for assembly definitions only when the project needs a deliberate boundary, such as a reusable VPM package, shared runtime API, faster package compilation, or explicit dependency control.

## Two Different Assembly Assets

Unity and UdonSharp use two related but different assets:

| Asset | File / type | Purpose |
|-------|-------------|---------|
| Unity assembly definition | `.asmdef` JSON asset | Tells Unity to compile scripts in that folder tree into a named C# assembly and controls references such as Auto Referenced. |
| U# Assembly Definition | UdonSharp `.asset` | Tells UdonSharp which Unity assembly contains UdonSharp scripts that should be compiled to Udon. |

A Unity `.asmdef` alone changes the C# assembly. It does **not** automatically register that assembly with UdonSharp.

## UdonSharpBehaviour Under an `.asmdef`

If an `UdonSharpBehaviour` lives under a Unity `.asmdef`, create a corresponding **U# Assembly Definition** asset for that assembly. In the U# Assembly Definition, set **Source Assembly** to the Unity Assembly Definition asset (`.asmdef`) that owns those scripts.

Without that corresponding U# asset, UdonSharp can compile the C# assembly in Unity but still refuse to treat the behaviour as part of a UdonSharp assembly. A common symptom is:

```text
[UdonSharp] Script ... does not belong to a U# assembly ...
```

Fix the assembly relationship before moving files: verify the script's containing `.asmdef`, create or update the U# Assembly Definition, and point its Source Assembly at the Unity Assembly Definition asset.

## Assembly Version Defines (SDK 3.10.5)

SDK 3.10.5 passes each Unity assembly's defines to UdonSharp, including
**Version Defines**. Use this for package-version-dependent Udon code when an
asmdef boundary already makes sense; it does not replace the matching U#
Assembly Definition above.

1. Select the script's Unity `.asmdef` and add a Version Define for
   `com.vrchat.worlds` with Expression `3.10.5` and Define
   `WORLD_SDK_3_10_5_OR_NEWER` (Unity's single-version expression means that
   version or later).
2. Keep the matching U# Assembly Definition's Source Assembly pointed at this
   `.asmdef`. A define in another assembly does not configure this script.
3. Guard the version-sensitive calls, then compile with UdonSharp; a successful
   Unity C# compilation alone does not prove that a Udon program was generated.

```csharp
#if WORLD_SDK_3_10_5_OR_NEWER
VRC.SDK3.Rendering.VRCQualitySettings.RealtimeReflectionProbes = false;
#else
// Do not reference APIs missing from this package version.
#endif
```

The expression is a package compatibility guard, not a promise that this Skill
supports future SDKs. Verify the defined and undefined branches when maintaining
a package. UdonSharp's Version Defines support itself starts in 3.10.5; do not
assume Unity and Udon choose the same branch on an older compiler merely because
the new API is guarded. Avoid custom names starting with `VRC_ENABLE_`: the SDK filters unknown
defines with that reserved prefix. Do not broaden the supported C# language
surface merely because an internal parser version changed.

SDK 3.10.5 also fixes UdonSharp script creation in both **Assets and Packages**.
The final release supersedes the beta's Assets-only restriction. For editable
package sources, verify the destination, generated script/program assets, and
assembly relationship after creation; do not edit a read-only package cache.

Sources: [SDK 3.10.5 release notes](https://creators.vrchat.com/releases/release-3-10-5/),
[Unity Version Defines](https://docs.unity3d.com/2022.3/Documentation/Manual/ScriptCompilationAssemblyDefinitionFiles.html#version-defines),
SDK `Integrations/UdonSharp/Editor/Compiler/CompilationContext.cs` and
`Integrations/UdonSharp/Editor/UdonSharpUtils.cs`.

## VPM Package Layout Is a Design Choice

Do not force a single folder layout on every package. Choose the boundary from how creators consume the package:

| Package style | Typical choice | Why |
|---------------|----------------|-----|
| **prefab-first** | Keep public runtime scripts easy to reference from default world scripts; often leave package runtime assembly Auto Referenced ON. | Creators drag prefabs into a world and may add small `Assembly-CSharp` scripts that talk to package components. |
| **code-integration API** | Expose a small stable runtime assembly/API; document whether user scripts need their own asmdef reference. | Creators intentionally call package APIs from their code. The package boundary is part of the integration contract. |
| **internal runtime code** | Hide or minimize direct references; consider Auto Referenced OFF only when the package expects explicit assembly references. | Package internals should not become accidental public API. |

Use `Runtime/` for code that can compile into player/world assemblies. Use `Editor/` folders or editor-only assemblies for custom inspectors, importers, generators, and build tools.

Editor-only scripts should not be UdonSharpBehaviours. Use plain `MonoBehaviour` setup helpers with `IEditorOnly` when a scene component is needed, or editor classes under an `Editor` folder/assembly when no runtime component is needed.

## Auto Referenced Tradeoff

Unity `.asmdef` **Auto Referenced** is a compile reference policy, **not build inclusion**. It controls whether predefined assemblies such as `Assembly-CSharp` automatically reference the assembly.

- **Auto Referenced ON**: beginner- and prefab-friendly; also useful for code-integration APIs that support `Assembly-CSharp` consumers. Default world scripts can reference package runtime types without requiring the creator to create their own `.asmdef` or manual assembly reference.
- **Auto Referenced OFF**: stricter explicit boundary. User scripts must live under an `.asmdef` that references the package assembly, or they cannot compile against the package runtime types.

Do not globally force Auto Referenced OFF for all VPM packages. Use it when the package deliberately requires explicit integration boundaries; leave it ON when the package is meant to be easy to consume from simple world scripts.

## Runtime/Editor Separation Checklist

- Put UdonSharp runtime behaviours and runtime helper types in runtime folders/assemblies.
- Put custom inspectors, asset postprocessors, build gates, and generator code in `Editor/` folders or editor-only assemblies.
- Do not make editor-only tooling inherit `UdonSharpBehaviour`.
- If an editor tool creates or moves UdonSharp scripts under a Unity `.asmdef`, also ensure the corresponding U# Assembly Definition exists and points Source Assembly at that `.asmdef`.
- For package samples, state whether consumers can call runtime types from `Assembly-CSharp` or must create their own `.asmdef` reference.

## Primary Evidence

- UdonSharp migration docs: <https://udonsharp.docs.vrchat.com/migration/>
- Unity assembly definition file format: <https://docs.unity3d.com/Manual/assembly-definition-file-format.html>
