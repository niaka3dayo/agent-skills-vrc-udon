using UdonSharp;

public class RuntimeSplitLambdaLines : UdonSharpBehaviour
{
    private void FirstHalf() => Select(
        value
        => value + 1);
}
