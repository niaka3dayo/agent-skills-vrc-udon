using UdonSharp;

public class RuntimeSyncInitializerCommas : UdonSharpBehaviour
{
    [UdonSynced]
    private int first = Mix(1, 2, 3, 4, 5, 6),
        second = new int[] { 1, 2, 3, 4, 5, 6 }[0];

    private int Mix(int a, int b, int c, int d, int e, int f)
    {
        return a + b + c + d + e + f;
    }

    private void Save()
    {
        Networking.SetOwner(Networking.LocalPlayer, gameObject);
        RequestSerialization();
    }
}
