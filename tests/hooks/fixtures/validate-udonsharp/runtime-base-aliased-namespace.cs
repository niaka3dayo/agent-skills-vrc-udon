using UdonAlias = global::UdonSharp;

public class RuntimeAliasedNamespaceBase:UdonAlias.UdonSharpBehaviour
{
    private ExampleEnumerable Run()
    {
        yield return Example.Value;
    }
}
