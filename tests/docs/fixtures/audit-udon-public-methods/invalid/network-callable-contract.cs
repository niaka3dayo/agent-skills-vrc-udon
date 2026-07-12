using UnityEngine;
using VRC.SDK3.UdonNetworkCalling;

public abstract class NetworkCallableContract
{
    [NetworkCallable]
    public static void _Static(int value) { }

    [NetworkCallable]
    public virtual void _Virtual(int value) { }

    [NetworkCallable]
    public override void _Override(int value) { }

    [NetworkCallable]
    public abstract void _Abstract(int value);

    [NetworkCallable]
    public extern void _Extern(int value);

    [NetworkCallable]
    public async void _Async(int value) { }

    [NetworkCallable]
    public void _NineParameters(
        int one,
        int two,
        int three,
        int four,
        int five,
        int six,
        int seven,
        int eight,
        int nine) { }

    [NetworkCallable]
    public void _Params(params int[] values) { }

    [NetworkCallable]
    public void _DefaultValue(int value = 1) { }

    [NetworkCallable]
    public void _Generic<T>(T value) { }

    [NetworkCallable]
    public void _Ref(ref int value) { }

    [NetworkCallable]
    public void _Overloaded(int value) { }

    private void _Overloaded(string value) { }

    [NetworkCallable]
    private void _Private(int value) { }

    [NetworkCallable]
    void _ImplicitPrivate(int value) { }

    [NetworkCallable]
    public void _UnsupportedType(GameObject value) { }
}
