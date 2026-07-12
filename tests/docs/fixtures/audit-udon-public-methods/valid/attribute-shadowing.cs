using System;
using VRC.SDK3.UdonNetworkCalling;

namespace SameNamespace
{
    public sealed class NetworkCallableAttribute : Attribute { }

    public class SameNamespaceShadow
    {
        [NetworkCallable]
        public int ParameterizedHelper(int value) => value;
    }

    public class Outer
    {
        public sealed class NetworkCallableAttribute : Attribute { }

        public class Nested
        {
            [NetworkCallable]
            public int NestedParameterizedHelper(int value) => value;
        }
    }
}

namespace ExplicitAlias
{
    using VrcCallable = VRC.SDK3.UdonNetworkCalling.NetworkCallableAttribute;

    public class AliasStillBinds
    {
        [VrcCallable]
        public void _ExplicitVrcAlias(int value) { }
    }
}
