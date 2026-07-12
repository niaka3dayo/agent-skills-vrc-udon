```csharp
using VRC.SDK3.UdonNetworkCalling;
public class ReturnTarget
{
    [return: NetworkCallable]
    public void _Call() { }
}
```

```csharp
using VRC.SDK3.UdonNetworkCalling;
public class FieldTarget { [NetworkCallable] int value; }
```

```csharp
using VRC.SDK3.UdonNetworkCalling;
public class PropertyTarget { [NetworkCallable] int Value { get; set; } }
```

```csharp
using VRC.SDK3.UdonNetworkCalling;
[NetworkCallable]
class TypeTarget { }
```

```csharp
using VRC.SDK3.UdonNetworkCalling;
public class ExplicitFieldTarget { [field: NetworkCallable] int value; }
```

```csharp
using VRC.SDK3.UdonNetworkCalling;
public class ExplicitPropertyTarget { [property: NetworkCallable] int Value { get; set; } }
```

```csharp
using VRC.SDK3.UdonNetworkCalling;
[type: NetworkCallable]
class ExplicitTypeTarget { }
```
