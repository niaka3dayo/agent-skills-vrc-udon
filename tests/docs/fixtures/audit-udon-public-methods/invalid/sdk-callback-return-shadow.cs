using UdonSharp;

namespace System
{
    public class Boolean { }
}

public class ShadowedCallbackReturn : UdonSharpBehaviour
{
    public override System.Boolean OnOwnershipRequest(
        VRC.SDKBase.VRCPlayerApi requester,
        VRC.SDKBase.VRCPlayerApi newOwner
    ) => null;
}
