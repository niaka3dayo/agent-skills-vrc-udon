using UdonSharp;

public class RuntimeMethodOverloadSupported : UdonSharpBehaviour
{
    [System.NonSerialized] public int intResult;
    [System.NonSerialized] public string stringResult;
    [System.NonSerialized] public int typeResult;
    [System.NonSerialized] public int arityResult;
    [System.NonSerialized] public int eventResult;

    public void _Run()
    {
        _DoSomething(7);
        _DoSomething("overload");
        typeResult = Pick("text");
        arityResult = Pick(1, 2);
    }

    public void _DoSomething(int value) { intResult = value; }
    public void _DoSomething(string value) { stringResult = value; }

    private int Pick(int value) { return value; }
    private int Pick(string value) { return Pick(202); }
    private int Pick(int first, int second) { return 303; }

    public void _Event() { eventResult = 365; }
    public void _Event(int value) { eventResult = value; }
}
