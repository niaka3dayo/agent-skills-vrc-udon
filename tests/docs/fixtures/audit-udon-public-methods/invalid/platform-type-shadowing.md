```csharp
using UnityEngine;
using VRC.SDK3.UdonNetworkCalling;
namespace LocalVector
{
    public class Vector2 { }
    public class Vector3 { }
    public class Vector4 { }
    public class Quaternion { }
    public class Receiver
    {
        [NetworkCallable]
        public void _Remote(Vector2 two, Vector3 three, Vector4 four, Quaternion rotation) { }
    }
}
```

```csharp
using UnityEngine;
using VRC.SDK3.UdonNetworkCalling;
namespace NestedColor
{
    public class Receiver
    {
        public class Color { }
        public class Color32 { }
        [NetworkCallable]
        public void _Remote(Color color, Color32 packedColor) { }
    }
}
```

```csharp
using VRC.SDK3.UdonNetworkCalling;
using VRC.SDKBase;
namespace LocalUrl
{
    public class VRCUrl { }
public class Receiver
{
    [NetworkCallable]
    public void _Remote(VRCUrl value) { }
}
}
```

```csharp
using VRC.SDK3.UdonNetworkCalling;
namespace UnityEngine
{
    public class Vector3 { }
    public class SameQualifiedName
    {
        [NetworkCallable]
        public void _Remote(global::UnityEngine.Vector3 value) { }
    }
}
```
