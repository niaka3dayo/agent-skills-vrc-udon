using System.Collections.Generic;
using System.IO;
using UdonSharp;

[UdonBehaviourSyncMode(BehaviourSyncMode.NoVariableSync)]
public class RuntimeAllRules : UdonSharpBehaviour
{
    private List<int> genericValues;
    [UdonSynced] private int[] largeValues;
    [UdonSynced] private int syncedA;
    [UdonSynced] private int syncedB;
    [UdonSynced] private int syncedC;
    [UdonSynced] private int syncedD;
    [UdonSynced] private int syncedE;

    public interface NestedInterface
    {
    }

    private async void RunAsync()
    {
        await Example.Task();
    }

    private void UseTryCatch()
    {
        try { File.Exists("example"); }
        catch (IOException) { }
    }

    private void UseLinq()
    {
        genericValues.Where(value => value > 0);
    }

    private IEnumerable<int> UseYield()
    {
        yield return 1;
    }

    private void UseCoroutine()
    {
        StartCoroutine(Example.Run());
    }

    private void UseListener()
    {
        Example.Button.onClick.AddListener(OnClicked);
    }

    private void UseLambda()
    {
        System.Func<int, int> map = (value) => value + 1;
    }

    private void UsePlayer()
    {
        VRCPlayerApi player = Networking.LocalPlayer;
    }

    public override void OnTriggerEnter(Collider other)
    {
    }

    private void UseGetComponent()
    {
        GetComponent<UdonBehaviour>();
    }

    private void UseRef(ref int value)
    {
    }

    private void UseOut(out int value)
    {
        value = 0;
    }

    private void UseMultidimensional(int[,] values)
    {
    }

    private void Duplicate()
    {
    }

    private void Duplicate(int value)
    {
    }

    private void OnClicked()
    {
    }
}
