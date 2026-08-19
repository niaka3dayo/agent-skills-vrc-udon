using UdonSharp;

public class RuntimeHardBlockers : UdonSharpBehaviour
{
    private async void WaitAtRuntime()
    {
    }

    private void CatchAtRuntime()
    {
        try
        {
        }
        catch (System.Exception)
        {
        }
    }
}
