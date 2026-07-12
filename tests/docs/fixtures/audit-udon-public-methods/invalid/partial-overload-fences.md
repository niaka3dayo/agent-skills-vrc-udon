```csharp
using VRC.SDK3.UdonNetworkCalling;
namespace FencePartial
{
    public partial class Receiver
    {
        [NetworkCallable]
        public void _Remote(int value) { }
    }
}
```

```csharp
namespace FencePartial
{
    public partial class Receiver
    {
        private void _Remote(string value) { }
    }
}
```
