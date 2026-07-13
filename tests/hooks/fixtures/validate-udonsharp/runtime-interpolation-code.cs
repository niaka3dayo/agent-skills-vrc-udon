using UdonSharp;

public class RuntimeInterpolationCode : UdonSharpBehaviour
{
    private string Build(string value)
    {
        string regular = $"literal async {Format("List<int> [UdonSynced]")} {Get<List<int>>()}";
        string verbatim = $@"literal try {{ {Format("System.IO [UdonSynced]")} }}";
        string raw = $$"""literal await {{ Format("StartCoroutine(", Get<List<int>>()) }} tail""";
        string nested = $"{Format($"literal async {Get<List<int>>()} ")}";
        string rawMixedBraces = $$"""literal {{{ Get<List<int>>() }}} tail""";
        return $"{regular}{verbatim}{raw}{nested}{rawMixedBraces}{value:List<int>}";
    }

    private T Get<T>()
    {
        return default(T);
    }

    private string Format(string value)
    {
        return value;
    }

    private string Format(string left, object right)
    {
        return left + right;
    }
}
