# VRChat SDK Build Panel Validation Alerts

SDK-backed catalog for world Build Panel alerts. Use this when a creator asks
about VRChat SDK validation, red/yellow/white warnings, Build Panel alerts,
"Auto Fix", or a warning message shown before Build & Test / Build & Upload.

## Scope and evidence

- **Last verified SDK**: VRChat Worlds SDK `3.10.4` and Base SDK `3.10.4`.
- **Primary source files**:
  - `Packages/com.vrchat.worlds/Editor/VRCSDK/SDK3/VRCSdkControlPanelWorldBuilder.cs`
  - `Packages/com.vrchat.base/Editor/VRCSDK/Dependencies/VRChat/ControlPanel/VRCSdkControlPanelBuilder.cs`
  - `Packages/com.vrchat.base/Runtime/VRCSDK/Dependencies/VRChat/Scripts/Validation/WorldValidation.cs`
  - `Packages/com.vrchat.base/Editor/VRCSDK/Dependencies/VRChat/Components/AutoAddSpatialAudioComponents.cs`
- **Build gating**: SDK 3.10.4 blocks the world build on `OnGUIError` entries.
  `OnGUIWarning` and `OnGUIInformation` entries are still shown in the Build
  Panel but are not red build blockers by themselves.
- **Builder availability errors**: some red Build Panel states are produced
  before the normal validation foldout, via `IsValidBuilder`,
  `CreateBuilderErrorGUI`, or the descriptor error block. Treat them as build
  blockers even when they are not emitted through `OnGUIError`.
- **Button labels**: Any alert with a fix callback is displayed with an
  **Auto Fix** button by the control panel, even when the message text says
  "Press 'fix'".

## Response policy

When answering a validation question:

1. Match the exact message first, then a distinctive substring, then the
   component/category.
2. Report **SDK severity** and **build consequence** separately.
3. Prefer the smallest safe manual fix. Do not apply broad Unity advice unless
   the SDK alert actually points to that setting.
4. Before bulk changes, list affected objects and preserve intentional authored
   values.
5. Treat SDK Auto Fix as a convenience, not as proof that the mutation is safe
   for every project.
6. If the warning comes from a newer SDK than `3.10.4`, re-check the local SDK
   source before presenting the catalog as complete.

### Fix-safety classes

| Class | Use when | Agent behavior |
|---|---|---|
| Additive-safe | A missing companion/component can be added without changing existing authored values | Recommend adding only the missing item and preserving current settings |
| Replacement-guarded | The fix replaces a known default/generated value | Apply only to values confirmed to be default; avoid custom materials/assets/settings |
| Behavior-changing | The fix can alter audio, visuals, physics, lighting, layer behavior, or imports | Explain impact and ask before changing a project |
| Destructive | The fix deletes components/assets or rewires serialized fields | Do not perform automatically; require backup and explicit review |
| Diagnostic-only | The SDK only selects objects or reports counts | Explain impact and give manual options |

## Quick severity guide

| SDK level | Build Panel color | Build consequence | Default response |
|---|---|---|---|
| `OnGUIError` | Red | Blocks Build & Test / Build & Upload | Must resolve before build |
| `OnGUIWarning` | Yellow | Does not block by color, but may affect runtime, compatibility, or upload quality | Explain and recommend a safe fix |
| `OnGUIInformation` | White / info | Does not block; usually readability, visual quality, or editor guidance | Explain and offer optional guarded fix |

## SDK 3.10.4 world alert catalog

### Red errors

| Alert family | Representative message | Trigger | Safe resolution | Auto Fix | Caution | Source |
|---|---|---|---|---|---|---|
| SDK not loaded or no compatible builder | `The SDK did not load properly. Try selecting VRChat SDK -> Reload SDK in the Unity menu bar.` | The control panel cannot select a valid SDK builder for the current compile symbols/packages. | Reload the SDK from the Unity menu, resolve compile/package errors, then reopen the SDK panel. | No. | Do not start deleting scene objects before confirming the SDK package and compile state are healthy. | `VRCSdkControlPanelBuilder.cs:690-713` |
| Missing scene descriptor / SDK content descriptor | `A VRCSceneDescriptor is required to build a World` / `A VRCSceneDescriptor or VRCAvatarDescriptor is required to build VRChat SDK Content` / `A VRCSceneDescriptor is required to build a VRChat World` | No active world builder descriptor is available for the selected world build. | Add exactly one `VRC_SceneDescriptor` / VRCWorld prefab to the scene, then configure spawn points and re-run validation. | Builder error UI can add the VRCWorld sample prefab; normal validation error has no Auto Fix. | Confirm the descriptor belongs to the upload scene, not to an inactive prefab or additive helper scene. | `VRCSdkControlPanelBuilder.cs:690-733`; `VRCSdkControlPanelWorldBuilder.cs:142-156, 1145-1189`; `VRCSdkControlPanelWorldBuilderV3.cs:43-55` |
| Multiple Pipeline Managers | `Multiple Pipeline Managers found in scene. Please remove all but one.` / `You can only have a single Pipeline Manager in a Scene` | More than one `PipelineManager` exists in the scene. | Keep the one that owns the intended world blueprint ID and remove or move extras. | No; builder error UI provides Select all PipelineManagers. | Destructive if the wrong blueprint owner is removed; inspect blueprint IDs before deleting. | `VRCSdkControlPanelWorldBuilder.cs:142-156, 1145-1173`; `VRCSdkControlPanelWorldBuilderV3.cs:43-55` |
| SDK V3 disabled | `SDK V3 is not enabled.` | The SDK3 world builder is present but V3 UI/pipeline support is disabled. | Re-enable SDK3/V3 support or reload/update the VRChat SDK package, then reopen the Build Panel. | No. | Usually indicates project/package state, not a scene-object problem. Fix SDK state before scene edits. | `VRCSdkControlPanelWorldBuilderV3.cs:43-48` |
| Multiple SDK pipelines present | `Multiple pipelines are present. V3 pipeline will take priority` | The older world builder detects that V3 pipeline UI is enabled and steps aside. | Use the SDK3/V3 world pipeline and remove stale SDK2 workflow assumptions. If no builder becomes valid, reload the SDK and resolve package conflicts. | No. | This is a builder-selection state; do not treat it as a scene validation object by itself. | `VRCSdkControlPanelWorldBuilder.cs:142-147`; `VRCSdkControlPanelBuilder.cs:672-731` |
| Multiple scene descriptors | `A Unity scene containing a VRChat Scene Descriptor should only contain one Scene Descriptor.` | More than one `VRC_SceneDescriptor` is found in the scene. | Keep exactly one descriptor for the world scene and remove or move extras. | No; Select only. | Check prefabs and disabled objects before deleting. | `VRCSdkControlPanelWorldBuilder.cs:224-234` |
| SDK2 event handlers in SDK3 world | `You have Event Handlers in your scene that are not allowed in this build configuration.` | One or more `VRC_EventHandler` components are present. | Replace SDK2 event-handler logic with Udon/UdonSharp or remove legacy components. | Yes; removes each `VRC_EventHandler` component. | Destructive: removing the component can remove behavior; inspect and migrate the old event setup first. | `VRCSdkControlPanelWorldBuilder.cs:435-450` |
| Object Sync with Manual Udon sync | `Object Sync cannot share an object with a manually synchronized Udon Behaviour` | A `VRCObjectSync` object also has a manually synchronized `UdonBehaviour`. | Split responsibilities: use `VRCObjectSync` for transform/physics and move manually synced state to another object/behaviour. | No; Select only. | Do not just change sync mode without checking late-joiner and ownership design. | `VRCSdkControlPanelWorldBuilder.cs:796-800` |
| Object Sync with Object Pool | `Object Sync cannot share an object with an object pool` | A GameObject has both `VRCObjectSync` and `VRCObjectPool`. | Put pool management and object sync on compatible separate objects, or redesign pooled prefab ownership. | No; Select only. | Avoid deleting either component until spawn/return flow is understood. | `VRCSdkControlPanelWorldBuilder.cs:796-803` |
| Missing valid spawn point | `You must add at least one valid spawn point to the spawns list in your scene descriptor.` | `VRC_SceneDescriptor.GetValidatedSpawnList()` returns empty. | Add at least one valid Transform to the descriptor Spawns list. | No; Select scene descriptor. | Confirm spawn is above respawn height and not inside geometry. | `VRCSdkControlPanelWorldBuilder.cs:867-888` |
| Layers/collision unresolved at build time | `You must address Layers and Collision Matrix issues before you can build.` | Build starts while VRChat layers or collision matrix are not configured. | Run the Build Panel layer and collision setup actions, then re-open Validations. | No direct error fix; setup buttons exist in scene setup UI. | Layer setup may move custom layers and requires reassignment review. | `VRCSdkControlPanelWorldBuilder.cs:366-427, 2574-2583` |
| SDK2 and SDK3 mixed components | `This scene contains components from the VRChat SDK version 2 and version 3...` | SDK2 and SDK3 components are both active in the scene. | Replace SDK2 components with SDK3/Udon equivalents. | No; Select SDK2 components. | Migration can change behavior; do it component-by-component. | `VRCSdkControlPanelBuilder.cs:554-566` |
| Android texture format not ASTC | `Default texture format on Android should be set to the newer ASTC format...` | Active build target is Android and `androidBuildSubtarget` is not ASTC. | Use the SDK Auto Fix or set Android default texture format to ASTC. | Yes; sets `EditorUserBuildSettings.androidBuildSubtarget = ASTC` and refreshes assets. | Reimport can take time and affects Android texture compression defaults. | `VRCSdkControlPanelBuilder.cs:569-581` |
| Unsupported iOS target | `iOS is not supported as a build target.` | Active build target is iOS for an account/platform that does not support iOS. | Switch to a supported build target. | No. | Do not attempt workaround uploads from an unsupported target. | `VRCSdkControlPanelBuilder.cs:584-593` |

### Yellow warnings

| Alert family | Representative message | Trigger | Safe resolution | Auto Fix | Caution | Source |
|---|---|---|---|---|---|---|
| Built-in Unity mesh referenced by Udon | `Udon Objects reference builtin Unity mesh assets, this won't work...` | Udon public variables reference built-in mesh assets. | Create project mesh assets and assign those clones to Udon variables. | Yes; clones meshes into `<scene>_MeshClones` and rewires Udon public variables. | Behavior-changing/destructive enough to review first: creates assets and changes serialized references. | `VRCSdkControlPanelWorldBuilder.cs:199-208, 1071-1136` |
| PostProcessVolume under Reference Camera | `Scene has a PostProcessVolume on the Reference Camera...` | Main Camera has a child `PostProcessVolume`; the reference camera is disabled at runtime. | Move the volume to a normal scene GameObject. | Yes; clones/moves volume content away from Main Camera. | Review resulting object hierarchy and component copies. | `VRCSdkControlPanelWorldBuilder.cs:210-218, 278-307` |
| Gravity has X/Z component | `Gravity vector is not straight down...` | `Physics.gravity.x` or `.z` is non-zero. | Use Project Settings > Physics and set gravity straight down unless nonstandard gravity is deliberate. | No; opens settings only. | Nonstandard gravity may be intentional, but player orientation remains upward. | `VRCSdkControlPanelWorldBuilder.cs:471-475` |
| Gravity points upward | `Gravity vector is not straight down, inverted or zero gravity will make walking extremely difficult.` | `Physics.gravity.y > 0`. | Use normal downward gravity unless the world is intentionally unusual. | No; opens settings only. | May make normal locomotion unusable. | `VRCSdkControlPanelWorldBuilder.cs:476-479` |
| Zero gravity | `Zero gravity will make walking extremely difficult...` | `Physics.gravity.y` is approximately zero. | Restore downward gravity or design explicit locomotion alternatives. | No; opens settings only. | Do not change if zero gravity is a core design without confirming. | `VRCSdkControlPanelWorldBuilder.cs:480-483` |
| Custom fog shader stripping | `Fog shader stripping is set to Custom...` | Fog shader stripping is Custom and keeps at least one fog mode. | Use Automatic unless the world changes fog mode at runtime. | Yes; sets fog stripping mode to Automatic. | If the world changes fog mode at runtime, Automatic may not preserve needed variants. | `VRCSdkControlPanelWorldBuilder.cs:485-495` |
| Deprecated Auto Spatialize Audio Sources | `Your scene previously used the 'Auto Spatialize Audio Sources' feature...` | `VRC_SceneDescriptor.autoSpatializeAudioSources` is enabled. | Disable the deprecated flag and intentionally add `VRC_SpatialAudioSource` to audio sources. | Yes; sets `autoSpatializeAudioSources = false`. | After disabling, audit all audio sources manually. | `VRCSdkControlPanelWorldBuilder.cs:498-504` |
| Rootless PhysBone | `One or more PhysBones in the scene have no parent...` | A PhysBone root transform has no parent. | Parent the PhysBone under another GameObject appropriate for the setup. | No; Select affected objects. | Preserve intended transform hierarchy and scale. | `VRCSdkControlPanelWorldBuilder.cs:507-524` |
| Too many PhysBones/PhysBone Colliders | `This scene contains a total of ... PhysBones and PhysBone Colliders...` | Combined PhysBone and PhysBone Collider count exceeds the client active world cap. | Reduce active world PhysBone/Collider count or split/disable optional interactions. | No. | The constant value comes from SDK runtime code; verify against current SDK when updating. | `VRCSdkControlPanelWorldBuilder.cs:527-535` |
| Too many Contacts | `This scene contains ... Contacts...` | Contact component count exceeds the client active world cap. | Reduce active Contacts or design fewer broad contact zones. | No. | Prefer fewer intentional contact volumes over many overlapping sensors. | `VRCSdkControlPanelWorldBuilder.cs:527-540` |
| Deprecated ONSP audio source | `Found audio source(s) using ONSP, this is deprecated...` | An `AudioSource` has an `ONSPAudioSource`. | Convert to `VRC_SpatialAudioSource` and verify audible range/loudness. | Yes; copies ONSP Gain/Near/Far/spatialization fields to VRC spatial audio and removes ONSP. | Listen in Build & Test; component replacement can alter spatial audio behavior. | `VRCSdkControlPanelWorldBuilder.cs:542-556`; `AutoAddSpatialAudioComponents.cs:126-154` |
| Missing `VRC_SpatialAudioSource` on 3D audio | `Found 3D audio source with no VRC Spatial Audio component...` | A non-2D `AudioSource` lacks `VRC_SpatialAudioSource`. | Add `VRC_SpatialAudioSource` deliberately. For warning-only additions, preserve `AudioSource` volume, rolloff, max distance, and custom curves; use Gain `0 dB`; match Far to the existing audible range. | Yes; adds component with SDK defaults. | Do not blindly use SDK defaults: they may change intended loudness/range. | `VRCSdkControlPanelWorldBuilder.cs:559-575`; `AutoAddSpatialAudioComponents.cs:198-220` |
| Missing disabled `VRC_SpatialAudioSource` on 2D audio | `Found 2D audio source with no VRC Spatial Audio component...` | A 2D/global `AudioSource` lacks `VRC_SpatialAudioSource`. | Add the companion component with `Enable Spatialization` off and Gain `0 dB`; keep 2D/global intent. | Yes; adds component and keeps spatialization disabled for 2D-like curves. | Do not force `spatialBlend = 1` unless the user wants 3D audio. | `VRCSdkControlPanelWorldBuilder.cs:559-575`; `AutoAddSpatialAudioComponents.cs:198-220` |
| Substance materials | `One or more scene objects have Substance materials...` | SDK detects Substance materials in the scene. | Bake Substances to regular materials. | No; Select affected objects. | Keep original Substance sources outside the upload scene if needed. | `VRCSdkControlPanelWorldBuilder.cs:579-584` |
| Reference Camera TAA | `The Reference Camera has a Post-process Layer component that uses Temporal Anti-Aliasing...` | Reference Camera Post-process Layer uses TAA. | Select another anti-aliasing mode for that camera. | Yes; sets anti-aliasing to None. | Confirm PC/Quest visual quality after the change. | `VRCSdkControlPanelWorldBuilder.cs:587-601` |
| AssetBundle over size limit | Dynamic message from `GetAssetBundleOverSizeLimitMessageSDKWarning(...)` | Compressed or uncompressed world bundle exceeds SDK size checks. | Reduce asset size: textures, meshes, audio, videos, baked data, or platform-specific variants. | No. | Requires profiling; do not delete assets blindly. | `VRCSdkControlPanelWorldBuilder.cs:604-619` |
| Unsupported mobile shader | `World uses unsupported shader 'X'...` | On Android/iOS builds, a root GameObject uses a shader outside the SDK world mobile whitelist. | Replace with supported VRChat Mobile/world shaders or platform-specific materials. | No. | May be PC-only acceptable but Quest/mobile incompatible. | `VRCSdkControlPanelWorldBuilder.cs:621-633`; `WorldValidation.cs:664-666` |
| Oversized textures | `This scene has textures bigger than 8192...` | Renderer materials use textures whose importer max size exceeds `8192`. | Lower texture importer max size and re-check memory. | Yes; sets importer max size to `8192`, reserializes, and refreshes assets. | Reimport changes assets globally; keep source textures backed up if needed. | `VRCSdkControlPanelWorldBuilder.cs:818-840`; `VRCSdkControlPanelBuilder.cs:65, 1129-1168` |
| Spawn too far from origin | `The spawn position is too far from the World Origin...` / `One of the spawn positions...` | Single or multi-spawn mode has a spawn outside ±1000 on any axis. | Move spawn transforms closer to world origin or redesign the origin/layout. | No; Select spawn. | Floating-origin and far-world designs need explicit review. | `VRCSdkControlPanelWorldBuilder.cs:891-899, 910-917` |
| Spawn below respawn height | `The spawn position at ... is below the respawn height...` / `A spawn position at ...` | A valid spawn Transform is below `VRC_SceneDescriptor.RespawnHeightY`. | Move the spawn above the respawn plane or lower Respawn Height safely below playable space. | No; Select scene. | This is often the cause of spawn/respawn loops. | `VRCSdkControlPanelWorldBuilder.cs:901-905, 920-925` |
| Unity version mismatch | `You are not using the recommended Unity version for the VRChat SDK...` | Remote SDK config recommends a different Unity version. | Use the VRChat-recommended Unity version for the installed SDK. | Yes; opens Unity download archive. | Do not change project Unity versions mid-work without source control backup. | `VRCSdkControlPanelBuilder.cs:540-551` |
| Automatic lightmap generation | `Automatic lightmap generation is enabled...` | `Lightmapping.giWorkflowMode == Iterative`. | Turn off Auto Generate and bake intentionally before upload. | Yes; sets GI workflow to On Demand. | If the world is still being laid out, decide when to bake rather than blindly toggling. | `VRCSdkControlPanelBuilder.cs:596-617` |

### White / informational alerts

| Alert family | Representative message | Trigger | Safe resolution | Auto Fix | Caution | Source |
|---|---|---|---|---|---|---|
| No current validation issues | `Everything looks good` | The SDK validation pass has no current issues for the selected world scene. | No action. Continue with normal Build & Test / Build & Upload checks. | No. | Treat this as a current SDK panel result, not as proof that play-mode behavior or platform-specific content is correct. | `VRCSdkControlPanelWorldBuilder.cs:252-258` |
| Native Unity text without TextMeshPro | `Your world contains one or more Unity text components, but no TextMeshPro components...` | `UnityEngine.UI.Text` or `TextMesh` exists and no TMP text/dropdown/input field is found. | Consider TextMeshPro for clearer text, especially world-space UI. | No. | Not every decorative text element needs migration; weigh prefab/style cost. | `VRCSdkControlPanelWorldBuilder.cs:453-468` |
| Unity built-in UI shader on uGUI graphics | `Found one or more UI graphics using Unity's built-in UI shader...` | A `UnityEngine.UI.Graphic` uses `UI/Default` while the VRChat supersampled UI shader exists. | Assign `Packages/com.vrchat.worlds/Editor/VRCSDK/SDK3/VRCSuperSampledUIMaterial.mat` to affected default-material uGUI graphics, or use a material with shader `VRChat/Mobile/Worlds/Supersampled UI`. | Yes; for built-in default material, replaces the graphic material with `VRCSuperSampledUIMaterial.mat`; for project material assets, changes the material shader in place. | Replacement-guarded: do not replace intentional custom UI materials or shader-driven UI effects. Inspect affected objects first. | `VRCSdkControlPanelWorldBuilder.cs:635-747` |
| Billboard particles allow roll | `Found one or more particle systems set to roll with the camera...` | A `ParticleSystemRenderer` is Billboard mode and `allowRoll` is enabled. | Disable `allowRoll` when camera-facing roll looks uncomfortable in VR. | Yes; sets `allowRoll = false` on all matching renderers. | Some stylized particles may intentionally roll; preview before bulk changes. | `VRCSdkControlPanelWorldBuilder.cs:749-793` |
| Box mipmap filtering | `This scene uses textures with 'Box' mipmap filtering...` | Renderer texture importers use Box mipmap filtering on Unity 2021+. | Switch affected texture importers to Kaiser for sharper distant textures. | Yes; sets `TextureImporter.mipmapFilter = KaiserFilter`, reserializes, and refreshes assets. | Texture reimport changes asset output. If DPID mipmaps are enabled, the SDK notes they may override this. | `VRCSdkControlPanelWorldBuilder.cs:843-865` |

## Special handling notes

### AudioSource and `VRC_SpatialAudioSource`

The SDK Auto Fix for bare `AudioSource` adds `VRC_SpatialAudioSource` with SDK
room/avatar defaults. That is useful for clearing the warning, but it can make
an existing sound louder or audible at a different distance than the author
intended.

For warning-only additions:

- Use Gain `0 dB` unless the creator explicitly wants a volume boost.
- Preserve `AudioSource.volume`, `spatialBlend`, `rolloffMode`, `minDistance`,
  `maxDistance`, and custom curves.
- For intentionally 2D/global audio, keep `Enable Spatialization` off.
- For tuned 3D audio, enable `Use AudioSource Volume Curve` when preserving an
  authored rolloff curve, and set Far to the existing `maxDistance` or intended
  audible range.
- Do not overwrite an existing `VRC_SpatialAudioSource`; explain its current
  values and ask before changing them.

### Super-sampled UI material

The white uGUI warning is actionable but not a build blocker. The guarded fix is
only for affected graphics that are actually using Unity's default `UI/Default`
material/shader.

Recommended manual fix:

1. Select the affected `Graphic` (`Image`, `RawImage`, `Text`, or derived uGUI
   component) shown by the SDK.
2. If it uses the built-in/default UI material, assign
   `Packages/com.vrchat.worlds/Editor/VRCSDK/SDK3/VRCSuperSampledUIMaterial.mat`.
3. If it uses a project material intentionally, do not replace it silently;
   consider changing that material's shader to `VRChat/Mobile/Worlds/Supersampled UI`
   only after checking the material's visual role.
4. Reopen the SDK Build Panel and confirm the alert is gone, then check UI
   readability in Build & Test.

### Layer and collision setup

Layer setup and collision matrix setup are project-wide mutations. They are
required for predictable VRChat physics and unresolved setup blocks builds, but
the layer setup dialog warns that custom layers may move down the list. After
running setup, re-check custom layer assignments and any hard-coded layer masks.

## Extraction commands used

Run these from the repository root that contains the local SDK search project:

```bash
cat unity-project-for-sdk-search/TestProject/Packages/com.vrchat.worlds/package.json
cat unity-project-for-sdk-search/TestProject/Packages/com.vrchat.base/package.json

grep -RIn --include='*.cs' \
  -E 'OnGUIError|OnGUIWarning|OnGUIInformation|CreateSceneSetupGUI|Auto Fix' \
  unity-project-for-sdk-search/TestProject/Packages/com.vrchat.worlds \
  unity-project-for-sdk-search/TestProject/Packages/com.vrchat.base

grep -RIn --include='*.cs' \
  -E 'VRC_SpatialAudioSource|VRCSuperSampledUIMaterial|UI/Default|allowRoll|mipmapFilter|RespawnHeightY' \
  unity-project-for-sdk-search/TestProject/Packages/com.vrchat.worlds \
  unity-project-for-sdk-search/TestProject/Packages/com.vrchat.base
```

Coverage rule: every SDK 3.10.4 world Build Panel `OnGUIError`,
`OnGUIWarning`, and actionable `OnGUIInformation` found by these searches must
be either cataloged above or tracked as an unresolved SDK finding before the
skill claims current coverage.
