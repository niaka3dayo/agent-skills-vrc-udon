using UdonSharp;

[UdonBehaviourSyncMode(BehaviourSyncMode.Manual)]
public class RuntimeRealCalls : UdonSharpBehaviour
{
    [UdonSynced] private int syncedValue;

    private void Save()
    {
        Networking.SetOwner(Networking.LocalPlayer, gameObject);
        RequestSerialization();
    }
}
