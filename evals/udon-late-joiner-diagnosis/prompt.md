---
name: udon-late-joiner-diagnosis
tags: [udon, networking, review]
max_turns: 12
allowed_tools: [Read, Glob, Grep, Skill]
---

This UdonSharp script works for everyone who is in the instance when the lever is pulled, but players who join afterwards see the gate closed. Why, and how do I fix it? Show the fixed script.

```csharp
using UdonSharp;
using UnityEngine;
using VRC.Udon.Common.Interfaces;

public class GateLever : UdonSharpBehaviour
{
    public GameObject gate;

    public override void Interact()
    {
        SendCustomNetworkEvent(NetworkEventTarget.All, nameof(OpenGate));
    }

    public void OpenGate()
    {
        gate.SetActive(false);
    }
}
```

Reply with the explanation and the fixed script in one C# code block. Do not write files.
