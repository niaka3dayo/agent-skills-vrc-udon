using NetworkCallable = Example.NotTheVrcAttribute;
using VRC.SDK3.UdonNetworkCalling;

public class AttributeBinding
{
    [Example(nameof(VRC.SDK3.UdonNetworkCalling.NetworkCallableAttribute), typeof(VRC.SDK3.UdonNetworkCalling.NetworkCallableAttribute))]
    public int ArgumentDecoy(int value) => value;

    [NetworkCallable]
    public int ShadowedAlias(int value) => value;

    [NetworkCallableAttribute(1)]
    public void _ExplicitAttributeNameStillBinds(int value) { }

    [VRC.SDK3.UdonNetworkCalling.NetworkCallable]
    public void _PreviousMember(int value) { }

    public int PreviousMemberDoesNotBleed(int value) => value;
}
