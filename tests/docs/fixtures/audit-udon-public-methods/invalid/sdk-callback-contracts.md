```csharp
using UdonSharp;
public class InvalidPostSerialization : UdonSharpBehaviour
{
    public override void OnPostSerialization() { }
}
```

```csharp
using UdonSharp;
public class InvalidPlayerJoined : UdonSharpBehaviour
{
    public void OnPlayerJoined(int slotIndex) { }
}
```

```csharp
using UdonSharp;
using UnityEngine;
public class InvalidDroneTrigger : UdonSharpBehaviour
{
    public override void OnDroneTriggerEnter(Collider other) { }
}
```

```csharp
using UdonSharp;
namespace CallbackShadow
{
    public class VRCPlayerApi { }
public class InvalidShadowedPlayer : UdonSharpBehaviour
{
    public override void OnPlayerJoined(VRCPlayerApi player) { }
}
}
```

```csharp
using UdonSharp;
using VRC.SDKBase;
public class InvalidRefPlayer : UdonSharpBehaviour
{
    public override void OnPlayerJoined(ref VRCPlayerApi player) { }
}
```

```csharp
using UdonSharp;
using VRC.SDKBase;
public class InvalidGenericPlayer : UdonSharpBehaviour
{
    public override void OnPlayerJoined<T>(VRCPlayerApi player) { }
}
```

```csharp
using UdonSharp;
using VRC.SDKBase;
public class InvalidStaticPlayer : UdonSharpBehaviour
{
    public static override void OnPlayerJoined(VRCPlayerApi player) { }
}
```

```csharp
using UdonSharp;
public class InvalidGui : UdonSharpBehaviour
{
    public void OnGUI(int windowId) { }
}
```

```csharp
using UdonSharp;
public class InvalidParticleStopped : UdonSharpBehaviour
{
    public void OnParticleSystemStopped(bool stopped) { }
}
```

```csharp
using UdonSharp;
using UnityEngine;
public class InvalidParticleJob : UdonSharpBehaviour
{
    public void OnParticleUpdateJobScheduled(ParticleSystem system) { }
}
```
