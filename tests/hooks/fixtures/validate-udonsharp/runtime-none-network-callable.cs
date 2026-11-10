using UdonSharp;
using VRC.SDK3.UdonNetworkCalling;

[UdonBehaviourSyncMode(BehaviourSyncMode.None)]
public class RuntimeNoneNetworkCallable : UdonSharpBehaviour
{
    [NetworkCallable]
    public void Reset()
    {
    }
}
