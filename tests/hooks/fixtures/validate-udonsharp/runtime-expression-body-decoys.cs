using UdonSharp;

public class RuntimeExpressionBodyDecoys : UdonSharpBehaviour
{
    public int Value => 42;

    private int Count
    {
        get => 1;
    }

    private int Increment(int value) => value + 1;
}
