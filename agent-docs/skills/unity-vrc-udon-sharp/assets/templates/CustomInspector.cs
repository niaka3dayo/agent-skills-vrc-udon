using UdonSharp;
using UnityEngine;
using VRC.SDKBase;

#if UNITY_EDITOR && !COMPILER_UDONSHARP
using UnityEditor;
using UdonSharpEditor;
#endif

/// <summary>
/// Template demonstrating custom inspector creation for UdonSharp.
/// Shows proper use of UdonSharpGUI, Undo, and proxy synchronization.
/// 
/// This file contains both the runtime behaviour and the editor inspector.
/// </summary>
[UdonBehaviourSyncMode(BehaviourSyncMode.Manual)]
public class CustomInspectorExample : UdonSharpBehaviour
{
    [Header("Basic Settings")]
    public string displayName = "Example Object";
    public float speed = 5.0f;
    
    [Header("Advanced Settings")]
    [Range(0f, 100f)]
    public float health = 100f;
    
    public Color objectColor = Color.white;
    
    [Header("References")]
    public Transform targetPoint;
    public AudioSource audioSource;
    
    // Synced variable example
    [UdonSynced, FieldChangeCallback(nameof(IsActive))]
    private bool _isActive = false;
    
    public bool IsActive
    {
        get => _isActive;
        set
        {
            _isActive = value;
            OnActiveChanged();
        }
    }
    
    void Start()
    {
        OnActiveChanged();
    }
    
    public override void Interact()
    {
        if (!Networking.IsOwner(gameObject))
        {
            VRCPlayerApi localPlayer = Networking.LocalPlayer;
            if (localPlayer != null && localPlayer.IsValid())
            {
                Networking.SetOwner(localPlayer, gameObject);
            }
        }
        
        IsActive = !IsActive;
        RequestSerialization();
    }
    
    private void OnActiveChanged()
    {
        // Update visuals based on active state
        if (TryGetComponent(out Renderer renderer))
        {
            renderer.material.color = _isActive ? objectColor : Color.gray;
        }
    }
    
    /// <summary>
    /// Editor-only: Reset to default values.
    /// </summary>
    public void ResetToDefaults()
    {
        displayName = "Example Object";
        speed = 5.0f;
        health = 100f;
        objectColor = Color.white;
        OnActiveChanged();
    }

#if UNITY_EDITOR
    // Gizmos work without COMPILER_UDONSHARP check
    private void OnDrawGizmosSelected()
    {
        if (targetPoint != null)
        {
            Gizmos.color = objectColor;
            Gizmos.DrawLine(transform.position, targetPoint.position);
            Gizmos.DrawWireSphere(targetPoint.position, 0.5f);
        }
    }
#endif
}

// ============================================================================
// CUSTOM EDITOR (Editor-only code below)
// ============================================================================

#if UNITY_EDITOR && !COMPILER_UDONSHARP
[CustomEditor(typeof(CustomInspectorExample))]
public class CustomInspectorExampleEditor : Editor
{
    // Serialized properties for proper Undo support
    private SerializedProperty displayNameProp;
    private SerializedProperty speedProp;
    private SerializedProperty healthProp;
    private SerializedProperty objectColorProp;
    private SerializedProperty targetPointProp;
    private SerializedProperty audioSourceProp;
    
    // Foldout states
    private bool showBasicSettings = true;
    private bool showAdvancedSettings = true;
    private bool showReferences = true;
    private bool showDebugInfo = false;
    
    private void OnEnable()
    {
        // Cache serialized properties
        displayNameProp = serializedObject.FindProperty("displayName");
        speedProp = serializedObject.FindProperty("speed");
        healthProp = serializedObject.FindProperty("health");
        objectColorProp = serializedObject.FindProperty("objectColor");
        targetPointProp = serializedObject.FindProperty("targetPoint");
        audioSourceProp = serializedObject.FindProperty("audioSource");
    }
    
    public override void OnInspectorGUI()
    {
        CustomInspectorExample script = (CustomInspectorExample)target;
        
        // REQUIRED: Always draw the UdonSharp header first!
        // This handles compile errors, sync mode display, etc.
        if (UdonSharpGUI.DrawDefaultUdonSharpBehaviourHeader(target))
        {
            return; // Don't draw rest if component is invalid
        }
        
        serializedObject.Update();
        
        EditorGUILayout.Space();
        
        // Basic Settings Section
        showBasicSettings = EditorGUILayout.Foldout(showBasicSettings, "Basic Settings", true);
        if (showBasicSettings)
        {
            EditorGUI.indentLevel++;
            EditorGUILayout.PropertyField(displayNameProp);
            EditorGUILayout.PropertyField(speedProp);
            EditorGUI.indentLevel--;
        }
        
        EditorGUILayout.Space();
        
        // Advanced Settings Section
        showAdvancedSettings = EditorGUILayout.Foldout(showAdvancedSettings, "Advanced Settings", true);
        if (showAdvancedSettings)
        {
            EditorGUI.indentLevel++;
            
            // Custom slider with value display
            EditorGUILayout.BeginHorizontal();
            EditorGUILayout.PropertyField(healthProp);
            if (GUILayout.Button("Max", GUILayout.Width(50)))
            {
                healthProp.floatValue = 100f;
            }
            EditorGUILayout.EndHorizontal();
            
            EditorGUILayout.PropertyField(objectColorProp);
            
            // Preview color
            EditorGUILayout.BeginHorizontal();
            EditorGUILayout.PrefixLabel("Color Preview");
            EditorGUI.DrawRect(
                GUILayoutUtility.GetRect(50, 20),
                objectColorProp.colorValue
            );
            EditorGUILayout.EndHorizontal();
            
            EditorGUI.indentLevel--;
        }
        
        EditorGUILayout.Space();
        
        // References Section
        showReferences = EditorGUILayout.Foldout(showReferences, "References", true);
        if (showReferences)
        {
            EditorGUI.indentLevel++;
            EditorGUILayout.PropertyField(targetPointProp);
            EditorGUILayout.PropertyField(audioSourceProp);
            
            // Auto-find button
            if (GUILayout.Button("Auto-Find Audio Source"))
            {
                AudioSource found = script.GetComponent<AudioSource>();
                if (found != null)
                {
                    audioSourceProp.objectReferenceValue = found;
                }
                else
                {
                    EditorUtility.DisplayDialog(
                        "Not Found",
                        "No AudioSource component found on this GameObject.",
                        "OK"
                    );
                }
            }
            
            EditorGUI.indentLevel--;
        }
        
        EditorGUILayout.Space();
        
        // Debug Info Section
        showDebugInfo = EditorGUILayout.Foldout(showDebugInfo, "Debug Info", true);
        if (showDebugInfo)
        {
            EditorGUI.indentLevel++;
            EditorGUI.BeginDisabledGroup(true);
            EditorGUILayout.Toggle("Is Active (Synced)", script.IsActive);
            EditorGUILayout.LabelField("Instance ID", script.GetInstanceID().ToString());
            EditorGUI.EndDisabledGroup();
            EditorGUI.indentLevel--;
        }
        
        EditorGUILayout.Space();
        EditorGUILayout.LabelField("", GUI.skin.horizontalSlider);
        
        // Action Buttons
        EditorGUILayout.BeginHorizontal();
        
        if (GUILayout.Button("Reset to Defaults"))
        {
            Undo.RecordObject(script, "Reset to Defaults");
            script.ResetToDefaults();
            // Sync proxy to UdonBehaviour
            UdonSharpEditorUtility.CopyProxyToUdon(script);
        }
        
        if (GUILayout.Button("Select Target"))
        {
            if (script.targetPoint != null)
            {
                Selection.activeTransform = script.targetPoint;
            }
        }
        
        EditorGUILayout.EndHorizontal();
        
        // Apply changes
        if (serializedObject.ApplyModifiedProperties())
        {
            // Sync any changes to the underlying UdonBehaviour
            UdonSharpEditorUtility.CopyProxyToUdon(script);
        }
    }
    
    /// <summary>
    /// Draw handles in scene view.
    /// </summary>
    private void OnSceneGUI()
    {
        CustomInspectorExample script = (CustomInspectorExample)target;
        
        if (script.targetPoint == null)
        {
            return;
        }
        
        // Draw position handle for target point
        EditorGUI.BeginChangeCheck();
        Vector3 newTargetPosition = Handles.PositionHandle(
            script.targetPoint.position,
            script.targetPoint.rotation
        );
        
        if (EditorGUI.EndChangeCheck())
        {
            Undo.RecordObject(script.targetPoint, "Move Target Point");
            script.targetPoint.position = newTargetPosition;
        }
        
        // Draw label
        Handles.Label(
            script.targetPoint.position + Vector3.up * 0.5f,
            "Target Point"
        );
        
        // Draw distance
        float distance = Vector3.Distance(
            script.transform.position,
            script.targetPoint.position
        );
        
        Handles.color = script.objectColor;
        Handles.DrawDottedLine(
            script.transform.position,
            script.targetPoint.position,
            5f
        );
        
        Vector3 midPoint = (script.transform.position + script.targetPoint.position) / 2f;
        Handles.Label(midPoint, $"Distance: {distance:F2}m");
    }
}
#endif
