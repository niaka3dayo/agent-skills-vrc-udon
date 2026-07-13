using System.IO;
using UdonSharp;
using UnityEditor;

// UdonSharpBehaviour in a comment must not make an editor utility a Udon behaviour.
public class UdonSharpProgramAssetAutoGenerator : AssetPostprocessor
{
    private const string BaseDecoy = "class Fake : UdonSharpBehaviour { }";

    private static void OnPostprocessAllAssets()
    {
        try
        {
            File.Exists("Assets/Example.cs");
        }
        catch (IOException)
        {
        }
    }
}
