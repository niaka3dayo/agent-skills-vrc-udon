using UdonSharp;

public class GeneralUserMethodParameters : UdonSharpBehaviour
{
    private void UpdateByReference(ref int value)
    {
        value++;
    }

    private int ReadByReference(out int value)
    {
        value = 7;
        return value;
    }

    private void UseGeneralMethods()
    {
        int value = 0;
        UpdateByReference(ref value);
        ReadByReference(out value);
    }
}
