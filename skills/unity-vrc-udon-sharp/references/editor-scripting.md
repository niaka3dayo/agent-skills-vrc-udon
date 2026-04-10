# UdonSharp Editor Scripting Reference

Guide to editor scripts, custom inspectors, and working with the UdonSharp proxy system.

## Overview

UdonSharp uses a **proxy system** where C# `UdonSharpBehaviour` scripts act as proxies for the underlying `UdonBehaviour` components. Understanding this system is essential for editor scripting.

## Preprocessor Directives

Used for conditional compilation:

```csharp
#if UNITY_EDITOR
// Code only compiled in Unity Editor
using UnityEditor;
#endif

#if COMPILER_UDONSHARP
// Code compiled by UdonSharp compiler (for runtime)
#endif

#if !COMPILER_UDONSHARP
// Code NOT compiled by UdonSharp (editor-only utilities)
#endif
```

**Common Pattern:**

```csharp
using UdonSharp;
using UnityEngine;

#if UNITY_EDITOR && !COMPILER_UDONSHARP
using UnityEditor;
using UdonSharpEditor;
#endif

public class MyScript : UdonSharpBehaviour
{
    public float speed = 5f;

    void Update()
    {
        transform.Translate(Vector3.forward * speed * Time.deltaTime);
    }

#if UNITY_EDITOR && !COMPILER_UDONSHARP
    // Editor-only code here
    public void EditorOnlyMethod()
    {
        Debug.Log("This only exists in editor!");
    }
#endif
}
```

## Proxy System

### How It Works

1. Your `UdonSharpBehaviour` C# class is a **proxy**
2. The actual data lives in the `UdonBehaviour` component
3. Changes must be synchronized between proxy and underlying UdonBehaviour

### Proxy Extension Methods

From the `UdonSharpEditor` namespace:

```csharp
#if UNITY_EDITOR && !COMPILER_UDONSHARP
using UdonSharpEditor;
#endif

// Get the proxy C# object from UdonBehaviour
UdonBehaviour udonBehaviour = GetComponent<UdonBehaviour>();
MyScript proxy = UdonSharpEditorUtility.GetProxyBehaviour(udonBehaviour) as MyScript;

// Get UdonBehaviour from proxy
UdonBehaviour underlying = UdonSharpEditorUtility.GetBackingUdonBehaviour(proxy);
```

### Updating Proxy Values

When changing values in editor scripts, use the following pattern:

```csharp
#if UNITY_EDITOR && !COMPILER_UDONSHARP
// After modifying the proxy, sync to UdonBehaviour
proxy.speed = 10f;
UdonSharpEditorUtility.CopyProxyToUdon(proxy);

// After modifying UdonBehaviour directly, sync to proxy
UdonSharpEditorUtility.CopyUdonToProxy(proxy);
#endif
```

## Adding Components

### AddUdonSharpComponent

Use this instead of `AddComponent` when adding UdonSharpBehaviours in the editor:

```csharp
#if UNITY_EDITOR && !COMPILER_UDONSHARP
using UdonSharpEditor;

// Add UdonSharpBehaviour component
MyScript script = gameObject.AddUdonSharpComponent<MyScript>();

// This creates both the UdonBehaviour and the proxy
#endif
```

### GetUdonSharpComponent

Get a typed UdonSharpBehaviour from a GameObject:

```csharp
#if UNITY_EDITOR && !COMPILER_UDONSHARP
// In editor, this returns the proxy object
MyScript script = gameObject.GetUdonSharpComponent<MyScript>();

// Get all of a type
MyScript[] scripts = gameObject.GetUdonSharpComponentsInChildren<MyScript>();
#endif
```

## Custom Inspectors

### Basic Custom Inspector

```csharp
#if UNITY_EDITOR && !COMPILER_UDONSHARP
using UnityEditor;
using UdonSharpEditor;

[CustomEditor(typeof(MyScript))]
public class MyScriptEditor : Editor
{
    public override void OnInspectorGUI()
    {
        MyScript script = (MyScript)target;

        // REQUIRED: Draw the default UdonSharp header
        if (UdonSharpGUI.DrawDefaultUdonSharpBehaviourHeader(target))
        {
            return; // Returns true if the script is not valid
        }

        // Your custom inspector code here
        EditorGUILayout.Space();
        EditorGUILayout.LabelField("Custom Settings", EditorStyles.boldLabel);

        // Use SerializedProperty for proper Undo support
        SerializedProperty speedProp = serializedObject.FindProperty("speed");
        EditorGUILayout.PropertyField(speedProp);

        // Apply changes
        if (serializedObject.ApplyModifiedProperties())
        {
            // Sync changes to UdonBehaviour
            UdonSharpEditorUtility.CopyProxyToUdon(script);
        }

        // Custom buttons
        if (GUILayout.Button("Reset Speed"))
        {
            Undo.RecordObject(script, "Reset Speed");
            script.speed = 5f;
            UdonSharpEditorUtility.CopyProxyToUdon(script);
        }
    }
}
#endif
```

### Important: DrawDefaultUdonSharpBehaviourHeader

**Always call this at the beginning of the inspector.** It handles:
- Drawing the UdonSharp script reference field
- Displaying compile errors
- Showing the sync mode indicator
- Returning `true` when the component is invalid (skip drawing)

```csharp
if (UdonSharpGUI.DrawDefaultUdonSharpBehaviourHeader(target))
{
    return; // Don't draw the rest if invalid
}
```

## Scene Handles and Gizmos

### Custom Handles

```csharp
#if UNITY_EDITOR && !COMPILER_UDONSHARP
using UnityEditor;

[CustomEditor(typeof(TeleportPoint))]
public class TeleportPointEditor : Editor
{
    private void OnSceneGUI()
    {
        TeleportPoint point = (TeleportPoint)target;

        // Draw position handle
        EditorGUI.BeginChangeCheck();
        Vector3 newPosition = Handles.PositionHandle(
            point.targetPosition,
            Quaternion.identity
        );
        if (EditorGUI.EndChangeCheck())
        {
            Undo.RecordObject(point, "Move Teleport Target");
            point.targetPosition = newPosition;
            UdonSharpEditorUtility.CopyProxyToUdon(point);
        }

        // Draw label
        Handles.Label(point.targetPosition, "Teleport Target");

        // Draw line from object to target
        Handles.color = Color.cyan;
        Handles.DrawDottedLine(
            point.transform.position,
            point.targetPosition,
            5f
        );
    }
}
#endif
```

### Gizmos

```csharp
public class TriggerZone : UdonSharpBehaviour
{
    public float radius = 5f;

#if UNITY_EDITOR
    // Gizmos don't need COMPILER_UDONSHARP check
    private void OnDrawGizmos()
    {
        Gizmos.color = new Color(0, 1, 0, 0.3f);
        Gizmos.DrawSphere(transform.position, radius);
    }

    private void OnDrawGizmosSelected()
    {
        Gizmos.color = Color.green;
        Gizmos.DrawWireSphere(transform.position, radius);
    }
#endif
}
```

## Editor Windows

```csharp
#if UNITY_EDITOR && !COMPILER_UDONSHARP
using UnityEditor;
using UdonSharpEditor;

public class MyToolWindow : EditorWindow
{
    [MenuItem("Tools/My UdonSharp Tool")]
    public static void ShowWindow()
    {
        GetWindow<MyToolWindow>("My Tool");
    }

    private void OnGUI()
    {
        EditorGUILayout.LabelField("UdonSharp Tool", EditorStyles.boldLabel);

        if (GUILayout.Button("Find All MyScript Components"))
        {
            MyScript[] scripts = FindObjectsOfType<MyScript>();
            foreach (var script in scripts)
            {
                Debug.Log($"Found: {script.gameObject.name}");
            }
        }

        if (GUILayout.Button("Reset All Speeds"))
        {
            MyScript[] scripts = FindObjectsOfType<MyScript>();
            foreach (var script in scripts)
            {
                Undo.RecordObject(script, "Reset All Speeds");
                script.speed = 5f;
                UdonSharpEditorUtility.CopyProxyToUdon(script);
            }
        }
    }
}
#endif
```

## Property Drawers

```csharp
#if UNITY_EDITOR && !COMPILER_UDONSHARP
using UnityEditor;

// Custom attribute
public class MinMaxAttribute : PropertyAttribute
{
    public float min;
    public float max;

    public MinMaxAttribute(float min, float max)
    {
        this.min = min;
        this.max = max;
    }
}

// Property drawer
[CustomPropertyDrawer(typeof(MinMaxAttribute))]
public class MinMaxDrawer : PropertyDrawer
{
    public override void OnGUI(Rect position, SerializedProperty property, GUIContent label)
    {
        MinMaxAttribute attr = (MinMaxAttribute)attribute;

        if (property.propertyType == SerializedPropertyType.Float)
        {
            property.floatValue = EditorGUI.Slider(
                position,
                label,
                property.floatValue,
                attr.min,
                attr.max
            );
        }
    }
}
#endif

// Usage in UdonSharpBehaviour
public class MyScript : UdonSharpBehaviour
{
    [MinMax(0f, 100f)]
    public float health = 100f;
}
```

## DefaultExecutionOrder

The `[DefaultExecutionOrder]` attribute controls the order in which Unity calls `Awake`, `OnEnable`, and `Start` across different `MonoBehaviour` (and `UdonSharpBehaviour`) scripts.

Lower numbers run **earlier**. The default order is `0`. Use negative values for scripts that must initialize before everything else, and positive values for scripts that should run last.

```csharp
// Runs before all default-order scripts — ideal for world settings and global state
[DefaultExecutionOrder(-1000)]
public class WorldSettingsInitializer : UdonSharpBehaviour
{
    [SerializeField] private float gravityScale = 0.5f;

    void Start()
    {
        // Apply world-wide gravity before any other script reads it
        Networking.LocalPlayer.SetGravityStrength(gravityScale);
    }
}

// Runs after default-order scripts — safe to read values set by initializers
[DefaultExecutionOrder(100)]
public class PlayerController : UdonSharpBehaviour
{
    void Start()
    {
        // WorldSettingsInitializer.Start() has already run
        Debug.Log("Player controller initialized");
    }
}
```

**When to use `[DefaultExecutionOrder]`:**

| Scenario | Recommended Order |
|----------|-------------------|
| World configuration (gravity, spawn zones, global flags) | `-1000` or lower |
| Managers that other scripts depend on | `-500` to `-100` |
| Default scripts | `0` (omit the attribute) |
| Scripts that consume manager output | `100` to `1000` |

> **Note**: `Awake()` is not available in UdonSharp. `Start()` is the first lifecycle hook; `[DefaultExecutionOrder]` controls when `Start()` runs relative to other behaviours.

## Best Practices

### 1. Always Use Undo

```csharp
Undo.RecordObject(target, "Description of change");
// Make changes
UdonSharpEditorUtility.CopyProxyToUdon(target);
```

### 2. Check for Null Proxy

```csharp
MyScript script = target as MyScript;
if (script == null) return;
```

### 3. Use SerializedProperty When Possible

```csharp
SerializedProperty prop = serializedObject.FindProperty("fieldName");
EditorGUILayout.PropertyField(prop);
serializedObject.ApplyModifiedProperties();
```

### 4. Batch Proxy Updates

```csharp
// Don't call CopyProxyToUdon after every change
script.value1 = 1;
script.value2 = 2;
script.value3 = 3;
UdonSharpEditorUtility.CopyProxyToUdon(script); // Once at the end
```

### 5. Mark Scene Dirty When Needed

```csharp
if (GUI.changed)
{
    EditorUtility.SetDirty(target);
    if (!Application.isPlaying)
    {
        UnityEditor.SceneManagement.EditorSceneManager.MarkSceneDirty(
            UnityEditor.SceneManagement.EditorSceneManager.GetActiveScene()
        );
    }
}
```

## Common Issues

### Changes Not Persisting

If changes made in a custom inspector are not persisting:

1. Verify you are calling `UdonSharpEditorUtility.CopyProxyToUdon()`
2. Verify you are using `Undo.RecordObject()` before making changes
3. Verify you are calling `EditorUtility.SetDirty()` on the target

### Serialization Errors

If you see "SerializedObject target has been destroyed":

```csharp
if (serializedObject == null || serializedObject.targetObject == null)
{
    return;
}
```

### Play Mode Changes Lost

Changes made during Play Mode are lost when exiting. This is standard Unity behavior. For testing purposes, use:

```csharp
[ExecuteInEditMode]
public class MyScript : UdonSharpBehaviour
{
    // Script runs in edit mode too
}
```

Note: `ExecuteInEditMode` can cause issues with UdonSharp. Use with caution.

## See Also

- [api.md](api.md) - VRChat API reference including types used in editor scripts
- [constraints.md](constraints.md) - C# feature constraints that affect editor-time validation
- [patterns-performance.md](patterns-performance.md) - DefaultExecutionOrder and performance patterns

## UdonSharpProgramAsset Auto-Generation

### The Problem

When AI creates a new `.cs` UdonSharp script file, the corresponding `.asset` (UdonSharpProgramAsset) is **not auto-generated**. Without this asset file, Unity cannot associate the C# script with an UdonBehaviour, resulting in "The associated script cannot be loaded" errors.

### The `.cs` to `.asset` Relationship

Every UdonSharp script requires a paired UdonSharpProgramAsset:

```text
MyScript.cs          → Source code (UdonSharpBehaviour)
MyScript.asset       → UdonSharpProgramAsset (links script to Udon compiler)
```

When creating scripts through the Unity Editor (Assets > Create > U# Script), both files are generated automatically. However, when AI creates `.cs` files directly on the filesystem, the `.asset` file is missing.

### Auto-Generation via AssetPostprocessor

Use `AssetPostprocessor.OnPostprocessAllAssets()` to detect newly imported UdonSharp scripts and auto-generate their program assets. The implementation below handles edge cases such as abstract classes, compile errors, and concurrent asset creation:

```csharp
#if UNITY_EDITOR
using System;
using System.IO;
using System.Reflection;
using UdonSharp;
using UdonSharp.Compiler;
using UdonSharpEditor;
using UnityEditor;
using UnityEngine;

/// <summary>
/// Automatically generates UdonSharpProgramAsset for newly imported UdonSharpBehaviour scripts.
/// Place this file in an Editor folder (e.g., Assets/Editor/).
/// </summary>
public class UdonSharpProgramAssetAutoGenerator : AssetPostprocessor
{
    /// <summary>
    /// Reads UdonSharpSettings.autoCompileOnModify via reflection
    /// to avoid hard dependency on internal editor types.
    /// </summary>
    private static bool GetAutoCompileOnModify()
    {
        try
        {
            Assembly udonSharpEditorAssembly = typeof(UdonSharpEditorUtility).Assembly;
            Type settingsType = udonSharpEditorAssembly.GetType(
                "UdonSharpEditor.UdonSharpSettings");
            if (settingsType == null) return false;

            MethodInfo getSettingsMethod = settingsType.GetMethod(
                "GetSettings", BindingFlags.Public | BindingFlags.Static);
            if (getSettingsMethod == null) return false;

            object settingsInstance = getSettingsMethod.Invoke(null, null);
            if (settingsInstance == null) return false;

            FieldInfo autoCompileField = settingsType.GetField(
                "autoCompileOnModify",
                BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance);
            if (autoCompileField == null) return false;

            object fieldValue = autoCompileField.GetValue(settingsInstance);
            return fieldValue is bool enabled && enabled;
        }
        catch (Exception ex)
        {
            Debug.LogError(
                $"[UdonSharp AutoGenerator] Failed to read autoCompileOnModify.\n{ex}");
            return false;
        }
    }

    private static void OnPostprocessAllAssets(
        string[] importedAssets,
        string[] deletedAssets,
        string[] movedAssets,
        string[] movedFromAssetPaths,
        bool didDomainReload)
    {
        // Only run after domain reload (avoids running on every asset import)
        if (!didDomainReload) return;

        bool createdAny = false;

        foreach (string importedAssetPath in importedAssets)
        {
            if (string.IsNullOrEmpty(importedAssetPath)) continue;

            MonoScript script =
                AssetDatabase.LoadAssetAtPath<MonoScript>(importedAssetPath);
            if (script == null) continue;

            Type scriptClass = script.GetClass();

            // Skip null (compile errors), abstract classes, non-UdonSharpBehaviour
            if (scriptClass == null
                || scriptClass.IsAbstract
                || !typeof(UdonSharpBehaviour).IsAssignableFrom(scriptClass))
                continue;

            // Check Udon registration (not just file existence)
            if (UdonSharpEditorUtility.GetUdonSharpProgramAsset(scriptClass) != null)
                continue;

            string programAssetPath = Path.ChangeExtension(importedAssetPath, ".asset")
                ?.Replace('\\', '/');
            if (string.IsNullOrEmpty(programAssetPath)
                || !programAssetPath.StartsWith("Assets/", StringComparison.Ordinal))
                continue;

            if (AssetDatabase.LoadMainAssetAtPath(programAssetPath) != null)
                continue;

            UdonSharpProgramAsset programAsset =
                ScriptableObject.CreateInstance<UdonSharpProgramAsset>();
            programAsset.sourceCsScript = script;

            try
            {
                AssetDatabase.CreateAsset(programAsset, programAssetPath);
                AssetDatabase.ImportAsset(
                    programAssetPath, ImportAssetOptions.ForceSynchronousImport);

                if (AssetDatabase.LoadAssetAtPath<UdonSharpProgramAsset>(
                    programAssetPath) == null)
                {
                    Debug.LogError(
                        $"[UdonSharp AutoGenerator] Failed to create asset at " +
                        $"'{programAssetPath}' for '{importedAssetPath}'.");
                    continue;
                }

                Debug.Log(
                    $"[UdonSharp AutoGenerator] Created ProgramAsset: {programAssetPath}");
            }
            catch (Exception ex)
            {
                Debug.LogError(
                    $"[UdonSharp AutoGenerator] Exception creating asset at " +
                    $"'{programAssetPath}' for '{importedAssetPath}'.\n{ex}");
                continue;
            }

            createdAny = true;
        }

        if (!createdAny) return;

        AssetDatabase.Refresh();

        // Trigger UdonSharp compilation if auto-compile is enabled
        if (!GetAutoCompileOnModify()) return;

        try
        {
            UdonSharpCompilerV1.CompileSync();
        }
        catch (Exception ex)
        {
            Debug.LogError(
                $"[UdonSharp AutoGenerator] Compile failed after generating assets.\n{ex}");
        }
    }
}
#endif
```

> **Credit**: Based on [nemurigi's AssetPostprocessor pattern](https://gist.github.com/nemurigi/dea7c0a1fb94f7b9cf1c36481a459ded) (MIT License).
> **Template**: A ready-to-use version is available at `assets/templates/UdonSharpProgramAssetAutoGenerator.cs`.

### Setup Instructions

1. Create an `Editor` folder in your Unity project (e.g., `Assets/Editor/`)
2. Copy `UdonSharpProgramAssetAutoGenerator.cs` into the `Editor` folder
3. New UdonSharp scripts will automatically get their `.asset` files after domain reload
4. If `autoCompileOnModify` is enabled in UdonSharp settings, compilation triggers automatically

### Limitations

- The script must compile successfully before the asset can be generated (`GetClass()` returns `null` for scripts with compile errors)
- Abstract classes are intentionally skipped (they cannot have their own UdonSharpProgramAsset)
- The `Editor` folder placement is required (scripts in `Editor` are not compiled by UdonSharp)
- Generation only runs after domain reload (`didDomainReload`), not on every asset import
