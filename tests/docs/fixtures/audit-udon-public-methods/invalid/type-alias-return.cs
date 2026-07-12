using NC = VRC.SDK3.UdonNetworkCalling.NetworkCallableAttribute;

public class TypeAliasReturn
{
    [NC(1)]
    public int _Bad(int value) => value;
}
