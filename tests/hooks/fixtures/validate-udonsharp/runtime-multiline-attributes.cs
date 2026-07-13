using UdonSharp;

[
    type:
    UdonBehaviourSyncMode(
        BehaviourSyncMode.NoVariableSync
    )
]
public
class RuntimeMultilineAttributes : UdonSharpBehaviour
{
    [
        field:
        UdonSynced
    ]
    private
    int[]
    values;

    private void Save()
    {
        Networking.SetOwner(Networking.LocalPlayer, gameObject);
        RequestSerialization();
    }
}
