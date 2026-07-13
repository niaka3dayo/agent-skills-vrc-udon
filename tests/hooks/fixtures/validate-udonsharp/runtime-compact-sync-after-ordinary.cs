using UdonSharp;
using VRC.SDKBase;

[UdonBehaviourSyncMode(BehaviourSyncMode.NoVariableSync)]
public class CompactSyncAfterOrdinary : UdonSharpBehaviour
{
    private int ordinary; [UdonSynced] private int first; [UdonSynced] private int second; [UdonSynced] private int third; [UdonSynced] private int fourth; [UdonSynced] private int fifth; [UdonSynced] private int sixth;

    private void Save()
    {
        if (Networking.IsOwner(gameObject))
        {
            RequestSerialization();
        }
    }
}
