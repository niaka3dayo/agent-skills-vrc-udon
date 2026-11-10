using UdonSharp;
using VRC.Udon.Common.Interfaces;

[Example, UdonBehaviourSyncMode(UdonSharp.BehaviourSyncMode.None)]
public class RuntimeNoneSelfNetworkEvent : UdonSharpBehaviour
{
    public override void Interact()
    {
        this . SendCustomNetworkEvent(NetworkEventTarget.All, nameof(Play));
    }

    public void Play()
    {
    }
}
