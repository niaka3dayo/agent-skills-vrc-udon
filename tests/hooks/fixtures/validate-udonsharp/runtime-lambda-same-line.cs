using UdonSharp;

public class RuntimeLambdaSameLine : UdonSharpBehaviour
{
    private void Run()
    {
        Select(value => value + 1);
        Select((value)	=>	value + 1);
    }
}
