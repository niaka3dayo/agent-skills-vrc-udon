// MIT License
// Copyright (c) 2026 nemurigi
// Based on: https://gist.github.com/nemurigi/dea7c0a1fb94f7b9cf1c36481a459ded

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
///
/// Place this file in an Editor folder (e.g., Assets/Editor/).
/// When a .cs file that inherits UdonSharpBehaviour is imported after a domain reload,
/// this processor checks if a corresponding .asset file exists and creates one if missing.
///
/// This solves the common problem where AI-generated or externally created .cs files
/// lack the required .asset (UdonSharpProgramAsset), causing "The associated script
/// cannot be loaded" errors.
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
            Type settingsType = udonSharpEditorAssembly.GetType("UdonSharpEditor.UdonSharpSettings");
            if (settingsType == null)
                return false;

            MethodInfo getSettingsMethod = settingsType.GetMethod(
                "GetSettings", BindingFlags.Public | BindingFlags.Static);
            if (getSettingsMethod == null)
                return false;

            object settingsInstance = getSettingsMethod.Invoke(null, null);
            if (settingsInstance == null)
                return false;

            FieldInfo autoCompileField = settingsType.GetField(
                "autoCompileOnModify",
                BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance);
            if (autoCompileField == null)
                return false;

            object fieldValue = autoCompileField.GetValue(settingsInstance);
            return fieldValue is bool enabled && enabled;
        }
        catch (Exception ex)
        {
            Debug.LogError(
                $"[UdonSharp AutoGenerator] Failed to read autoCompileOnModify setting.\n{ex}");
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
        // Only run after domain reload to avoid processing on every asset import
        if (!didDomainReload)
            return;

        bool createdAny = false;

        foreach (string importedAssetPath in importedAssets)
        {
            if (string.IsNullOrEmpty(importedAssetPath))
                continue;

            MonoScript script = AssetDatabase.LoadAssetAtPath<MonoScript>(importedAssetPath);
            if (script == null)
                continue;

            Type scriptClass = script.GetClass();

            // Skip null (compile errors), abstract classes, and non-UdonSharpBehaviour types
            if (scriptClass == null
                || scriptClass.IsAbstract
                || !typeof(UdonSharpBehaviour).IsAssignableFrom(scriptClass))
                continue;

            // Check if a UdonSharpProgramAsset is already registered for this type
            if (UdonSharpEditorUtility.GetUdonSharpProgramAsset(scriptClass) != null)
                continue;

            string programAssetPath = Path.ChangeExtension(importedAssetPath, ".asset")
                ?.Replace('\\', '/');
            if (string.IsNullOrEmpty(programAssetPath)
                || !programAssetPath.StartsWith("Assets/", StringComparison.Ordinal))
                continue;

            // Avoid overwriting an existing asset file at the same path
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

                if (AssetDatabase.LoadAssetAtPath<UdonSharpProgramAsset>(programAssetPath) == null)
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

        if (!createdAny)
            return;

        AssetDatabase.Refresh();

        // Trigger UdonSharp compilation if auto-compile is enabled
        if (!GetAutoCompileOnModify())
            return;

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
