using UdonSharp;

public class RuntimeMethodOverloadMultilineOnly : UdonSharpBehaviour
{
    public void Split
    (int value) { }

    public void Split
    (float value) { }
}
