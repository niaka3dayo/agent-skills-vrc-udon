using UdonSharp;
using VRC.Udon.Common.Interfaces;

[UdonBehaviourSyncMode(BehaviourSyncMode.None)]
public class RuntimeNoneNetworkEventDecoys : UdonSharpBehaviour
{
    public UdonSharpBehaviour syncedTarget;

    // [NetworkCallable] and SendCustomNetworkEvent(...) in a comment are not code.
    private string note = "[NetworkCallable] SendCustomNetworkEvent(";

    public override void Interact()
    {
        syncedTarget.SendCustomNetworkEvent(NetworkEventTarget.All, "Play");
        syncedTarget. SendCustomNetworkEvent(NetworkEventTarget.All, "Play");
        syncedTarget
            .SendCustomNetworkEvent(NetworkEventTarget.All, "Play");
        syncedTarget.
            SendCustomNetworkEvent(NetworkEventTarget.All, "Play");
        SendCustomEvent(nameof(_Local));
    }

    public void _Local()
    {
    }
}
