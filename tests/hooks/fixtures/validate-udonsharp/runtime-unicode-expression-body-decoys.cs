using UdonSharp;

public class UnicodeExpressionBodyDecoys : UdonSharpBehaviour
{
    private int 計算(int value) => value + 1; private int @event(int value) => value + 2;
    protected internal static int 変換(int value) => value + 3;
}
