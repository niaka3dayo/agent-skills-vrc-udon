using System.Collections.Generic;
using System.Linq;
using UdonSharp;

public class ContextUdonRuntime : UdonSharpBehaviour
{
    private void BuildAtRuntime()
    {
        List<int> values = new List<int>();
        string[] labels = values
            .Select(value => value.ToString())
            .ToArray();
    }
}
