using VRC.SDK3.UdonNetworkCalling;

public class NetworkCallableUnityBuiltin
{
    [NetworkCallable]
    public void OnMouseDown() { }

    [NetworkCallable]
    public void OnGUI() { }
}
