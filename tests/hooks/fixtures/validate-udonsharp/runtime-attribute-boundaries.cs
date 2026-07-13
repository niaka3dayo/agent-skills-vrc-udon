using UdonSharp;

[type: UdonBehaviourSyncMode(BehaviourSyncMode.NoVariableSync)]
public class RuntimeAttributeBoundaries : UdonSharpBehaviour
{
    [field: UdonSynced]
    private int[] values;

    private int UdonSynced;

    private int Read()
    {
        return values[UdonSynced];
    }

    private void Save()
    {
        Networking.SetOwner(Networking.LocalPlayer, gameObject);
        RequestSerialization();
    }
}
