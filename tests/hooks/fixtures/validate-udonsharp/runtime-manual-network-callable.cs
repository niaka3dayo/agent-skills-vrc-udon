using UdonSharp;
using VRC.SDK3.UdonNetworkCalling;
using VRC.Udon.Common.Interfaces;

[UdonBehaviourSyncMode(BehaviourSyncMode.Manual)]
public class RuntimeManualNetworkCallable : UdonSharpBehaviour
{
    public override void Interact()
    {
        SendCustomNetworkEvent(NetworkEventTarget.All, nameof(Reset));
    }

    [NetworkCallable]
    public void Reset()
    {
    }
}
