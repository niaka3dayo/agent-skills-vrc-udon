public class RuntimeQualifiedBase:UdonSharp.UdonSharpBehaviour
{
    private async void Run()
    {
        await Example.Task();
    }
}
