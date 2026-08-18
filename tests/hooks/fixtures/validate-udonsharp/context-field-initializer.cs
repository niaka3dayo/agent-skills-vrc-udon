using System.Collections.Generic;
using System.Linq;
using UdonSharp;

public class ContextFieldInitializer : UdonSharpBehaviour
{
    private readonly string[] labels = Enumerable.Range(0, 4)
        .Select(value => value.ToString())
        .ToArray();

    private readonly int[] squares = CreateSquares(4);

    private static int[] CreateSquares(int count)
    {
        List<int> values = new List<int>();
        for (int index = 0; index < count; index++)
        {
            values.Add(index * index);
        }

        return values.ToArray();
    }
}
