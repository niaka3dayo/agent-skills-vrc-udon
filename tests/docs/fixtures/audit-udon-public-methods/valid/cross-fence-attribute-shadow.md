```csharp
using System;
namespace FenceShadow
{
    public sealed class NetworkCallableAttribute : Attribute { }
}
```

```csharp
namespace FenceShadow
{
    public class Consumer
    {
        [NetworkCallable]
        public int OrdinaryMethod(int value) => value;
        public void _LocalOnly() { }
    }
}
```
