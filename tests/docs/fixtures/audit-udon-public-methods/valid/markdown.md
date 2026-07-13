This prose is not C# and must not create an exposure: public void ProseDecoy().

`````text
public void NonCSharpFenceDecoy() { }

````csharp
public void NestedCSharpFenceDecoy() { }
````
`````

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

````cs
public class MixedFenceLengths
{
    public int _Safe() => 1;
    private string marker = "```";
}
````

~~~markdown
```csharp
public void NestedInTildeFenceDecoy() { }
```
~~~
