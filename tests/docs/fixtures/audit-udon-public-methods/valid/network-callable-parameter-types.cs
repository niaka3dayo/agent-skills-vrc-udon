using VrcUrl = VRC.SDKBase.VRCUrl;
using Vec3 = UnityEngine.Vector3;
using VRC.SDK3.UdonNetworkCalling;

public class NetworkCallableParameterTypes
{
    [NetworkCallable]
    public void _SupportedTypes(
        bool enabled,
        System.Int32 count,
        global::System.String message,
        Vec3 position,
        UnityEngine.Color32 color,
        VrcUrl url,
        VRC.SDKBase.VRCUrl[] mirrors,
        byte[] payload) { }
}
