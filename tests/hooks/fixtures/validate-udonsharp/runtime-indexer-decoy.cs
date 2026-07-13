using UdonSharp;

public class RuntimeIndexerDecoy : UdonSharpBehaviour
{
    private int UdonSynced;
    private int[] values;

    private int Read()
    {
        return values[UdonSynced];
    }
}
