using System;

namespace Unrelated
{
    public sealed class NetworkCallableAttribute : Attribute { }
}

namespace ActualSdkConsumer
{
    using VRC.SDK3.UdonNetworkCalling;

    public class UnrelatedShadowMustNotBypass
    {
        [NetworkCallable]
        public int _InvalidReturn(int value) => value;
    }
}
