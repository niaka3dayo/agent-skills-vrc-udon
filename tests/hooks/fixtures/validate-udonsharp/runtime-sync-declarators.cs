using UdonSharp;

public class RuntimeSyncDeclarators : UdonSharpBehaviour
{
    [UdonSynced]
    private int[] @event, 値, third, fourth, fifth, sixth;

    private void Save()
    {
        Networking.SetOwner(Networking.LocalPlayer, gameObject);
        RequestSerialization();
    }
}
