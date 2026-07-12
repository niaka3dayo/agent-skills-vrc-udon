This prose is not C# and must not create an exposure: public void ProseDecoy().

```text
public void NonCSharpFenceDecoy() { }
```

```csharp
using UnityEditor;

public class InspectorExampleEditor : UnityEditor.Editor
{
    public override void OnInspectorGUI() { }
}

public class BuildHook : MonoBehaviour, IEditorOnly, IPreprocessCallbackBehaviour
{
    public bool OnPreprocess() => true;
}
```
