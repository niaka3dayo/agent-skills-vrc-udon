using Direct = VRC.SDK3.UdonNetworkCalling.NetworkCallableAttribute;
using Network = VRC.SDK3.UdonNetworkCalling;

public class UnicodeAndAliases
{
    public int _危険() => 1;
    public int _é() => 2;
    public int _join‿name() => 3;

    [Direct(1)]
    public void _Direct(int value) { }

    [Network.NetworkCallable(1)]
    public void _Namespace(int value) { }

    [VRC.SDK3.UdonNetworkCalling.NetworkCallableAttribute(1)]
    public void _Qualified(int value) { }

    [global::VRC.SDK3.UdonNetworkCalling.NetworkCallable(1)]
    public void _Global(int value) { }

    private int @public;
    private int p\u0075blic;
}
