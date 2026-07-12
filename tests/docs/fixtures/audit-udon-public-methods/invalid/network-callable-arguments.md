```csharp
using VRC.SDK3.UdonNetworkCalling;
public class ZeroRate { [NetworkCallable(0)] public void _Call() { } }
```

```csharp
using VRC.SDK3.UdonNetworkCalling;
public class ExcessRate { [NetworkCallable(101)] public void _Call() { } }
```

```csharp
using VRC.SDK3.UdonNetworkCalling;
public class StringRate { [NetworkCallable("5")] public void _Call() { } }
```

```csharp
using VRC.SDK3.UdonNetworkCalling;
public class UnknownRate { [NetworkCallable(notTheRate: 5)] public void _Call() { } }
```

```csharp
using VRC.SDK3.UdonNetworkCalling;
public class TwoRates { [NetworkCallable(1, 2)] public void _Call() { } }
```

```csharp
using VRC.SDK3.UdonNetworkCalling;
public class DuplicateRate
{
    [NetworkCallable]
    [NetworkCallable(1)]
    public void _Call() { }
}
```
