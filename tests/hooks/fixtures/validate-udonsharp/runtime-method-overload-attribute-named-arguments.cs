using UdonSharp;

public class RuntimeMethodOverloadAttributeNamedArguments : UdonSharpBehaviour
{
    private int assignmentDecoy = Factory.Create();

    private void CallDecoy()
    {
        Factory.Run();
    }

    [Example(Name = "x")]
    public void Target(int value) { }

    public void Target(float value) { }
}
