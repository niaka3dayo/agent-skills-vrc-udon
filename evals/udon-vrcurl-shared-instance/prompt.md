---
name: udon-vrcurl-shared-instance
tags: [udon, web, review]
max_turns: 12
allowed_tools: [Read, Glob, Grep, Skill]
---

Two video screens in my VRChat world use the same UdonSharp script. When I type a URL into the Default Url field of one screen in the Inspector, the other screen's field changes to the same URL. Why does this happen, and what should I change?

```csharp
using UdonSharp;
using UnityEngine;
using VRC.SDKBase;

public class ScreenConfig : UdonSharpBehaviour
{
    [SerializeField] private VRCUrl defaultUrl = VRCUrl.Empty;
    [SerializeField] private VRCUrl[] playlist = { VRCUrl.Empty, VRCUrl.Empty };
}
```

Do not write files.
