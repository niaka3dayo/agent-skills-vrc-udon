using UdonSharp;

[UdonBehaviourSyncMode(BehaviourSyncMode.NoVariableSync)]
public class RuntimeMaskBoundaries : UdonSharpBehaviour
{
    private string unterminatedRegular = "decoy [UdonSynced]
    private char unterminatedChar = 'x
    [UdonSynced] private int actualValue;

    private void Save()
    {
        Networking.SetOwner(Networking.LocalPlayer, gameObject);
        RequestSerialization();
    }
}
