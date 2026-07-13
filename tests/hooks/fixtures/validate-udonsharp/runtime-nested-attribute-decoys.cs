using UdonSharp;

[Example]
public class RuntimeNestedAttributeDecoys : UdonSharpBehaviour
{
    [Example(1, UdonSynced, 2)]
    private int[] values;

    [property: UdonSynced]
    public int[] PropertyValues { get; set; }
}
