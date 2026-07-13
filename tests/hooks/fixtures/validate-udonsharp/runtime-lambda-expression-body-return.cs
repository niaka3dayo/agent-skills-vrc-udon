using UdonSharp;

public class RuntimeLambdaExpressionBodyReturn : UdonSharpBehaviour
{
    public Func<int, int> Transform => value => value + 1;
}
