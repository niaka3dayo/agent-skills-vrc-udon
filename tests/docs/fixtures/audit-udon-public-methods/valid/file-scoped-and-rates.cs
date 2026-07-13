using UnityEngine;
using VRC.SDK3.UdonNetworkCalling;
using VRC.SDKBase;

namespace General.Valid;

public partial class FileScopedExample
{
    [NetworkCallable]
    public void _NoRate(Vector2 position) { }
}

public partial class FileScopedExample
{
    [NetworkCallable(maxEventsPerSecond: 100)]
    public void _MaxRate(global::UnityEngine.Vector3 position, VRCUrl url) { }

    [method: System.Obsolete, NetworkCallable]
    public void _MethodTarget() { }
}
