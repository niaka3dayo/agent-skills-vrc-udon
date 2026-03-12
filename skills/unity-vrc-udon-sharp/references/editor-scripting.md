# UdonSharp エディタースクリプティングリファレンス

エディタースクリプト、カスタムインスペクター、UdonSharp プロキシシステムの操作ガイド。

## 概要

UdonSharp は**プロキシシステム**を使用しており、C# の `UdonSharpBehaviour` スクリプトが基盤となる `UdonBehaviour` コンポーネントのプロキシとして機能する。このシステムの理解はエディタースクリプティングに不可欠。

## プリプロセッサディレクティブ

条件付きコンパイルに使用:

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

**よくあるパターン:**

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

## プロキシシステム

### 仕組み

1. Your `UdonSharpBehaviour` C# class is a **proxy**
2. The actual data lives in the `UdonBehaviour` component
3. Changes must be synchronized between proxy and underlying UdonBehaviour

### プロキシ拡張メソッド

`UdonSharpEditor` 名前空間から:

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

### プロキシ値の更新

エディタースクリプトで値を変更する際は、以下のパターンを使用:

```csharp
#if UNITY_EDITOR && !COMPILER_UDONSHARP
// After modifying the proxy, sync to UdonBehaviour
proxy.speed = 10f;
UdonSharpEditorUtility.CopyProxyToUdon(proxy);

// After modifying UdonBehaviour directly, sync to proxy
UdonSharpEditorUtility.CopyUdonToProxy(proxy);
#endif
```

## コンポーネントの追加

### AddUdonSharpComponent

エディターで UdonSharpBehaviour を追加する際は `AddComponent` の代わりにこれを使用:

```csharp
#if UNITY_EDITOR && !COMPILER_UDONSHARP
using UdonSharpEditor;

// Add UdonSharpBehaviour component
MyScript script = gameObject.AddUdonSharpComponent<MyScript>();

// This creates both the UdonBehaviour and the proxy
#endif
```

### GetUdonSharpComponent

GameObject から型付き UdonSharpBehaviour を取得:

```csharp
#if UNITY_EDITOR && !COMPILER_UDONSHARP
// In editor, this returns the proxy object
MyScript script = gameObject.GetUdonSharpComponent<MyScript>();

// Get all of a type
MyScript[] scripts = gameObject.GetUdonSharpComponentsInChildren<MyScript>();
#endif
```

## カスタムインスペクター

### 基本的なカスタムインスペクター

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

### 重要: DrawDefaultUdonSharpBehaviourHeader

**インスペクターの最初に必ずこれを呼び出すこと。** 以下を処理する:
- UdonSharp スクリプト参照フィールドの描画
- コンパイルエラーの表示
- 同期モードインジケーターの表示
- コンポーネントが無効な場合に `true` を返す（描画をスキップ）

```csharp
if (UdonSharpGUI.DrawDefaultUdonSharpBehaviourHeader(target))
{
    return; // Don't draw the rest if invalid
}
```

## シーンハンドルとギズモ

### カスタムハンドル

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

### ギズモ

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

## エディターウィンドウ

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

## プロパティドロワー

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

## ベストプラクティス

### 1. 常に Undo を使用する

```csharp
Undo.RecordObject(target, "Description of change");
// Make changes
UdonSharpEditorUtility.CopyProxyToUdon(target);
```

### 2. Null プロキシのチェック

```csharp
MyScript script = target as MyScript;
if (script == null) return;
```

### 3. 可能な限り SerializedProperty を使用する

```csharp
SerializedProperty prop = serializedObject.FindProperty("fieldName");
EditorGUILayout.PropertyField(prop);
serializedObject.ApplyModifiedProperties();
```

### 4. プロキシ更新のバッチ処理

```csharp
// Don't call CopyProxyToUdon after every change
script.value1 = 1;
script.value2 = 2;
script.value3 = 3;
UdonSharpEditorUtility.CopyProxyToUdon(script); // Once at the end
```

### 5. 必要に応じてシーンを Dirty にマークする

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

## よくある問題

### 変更が保持されない

カスタムインスペクターで行った変更が保持されない場合:

1. `UdonSharpEditorUtility.CopyProxyToUdon()` を呼び出しているか確認
2. 変更前に `Undo.RecordObject()` を使用しているか確認
3. ターゲットに対して `EditorUtility.SetDirty()` を呼び出しているか確認

### シリアライゼーションエラー

"SerializedObject target has been destroyed" が表示される場合:

```csharp
if (serializedObject == null || serializedObject.targetObject == null)
{
    return;
}
```

### プレイモードでの変更が失われる

プレイモード中に行った変更は終了時に失われる。これは Unity の仕様。テスト用には以下を使用:

```csharp
[ExecuteInEditMode]
public class MyScript : UdonSharpBehaviour
{
    // Script runs in edit mode too
}
```

注意: `ExecuteInEditMode` は UdonSharp で問題を起こすことがある。慎重に使用すること。
