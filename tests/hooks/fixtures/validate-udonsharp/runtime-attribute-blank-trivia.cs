using UdonSharp;

public class RuntimeAttributeBlankTrivia : UdonSharpBehaviour
{
    [UdonSynced]

    private float[] values;

    private void Save()
    {
        Networking.SetOwner(Networking.LocalPlayer, gameObject);
        RequestSerialization();
    }
}
