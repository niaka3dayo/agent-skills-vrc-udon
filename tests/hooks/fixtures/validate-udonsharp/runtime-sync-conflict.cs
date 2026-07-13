using UdonSharp;

[Example, UdonBehaviourSyncMode(BehaviourSyncMode.NoVariableSync)]
public class RuntimeSyncConflict : UdonSharpBehaviour
{
    [Example, UdonSyncedAttribute, Another] private int syncedValue;

    private void Save()
    {
        Networking.SetOwner(Networking.LocalPlayer, gameObject);
        RequestSerialization();
    }
}
