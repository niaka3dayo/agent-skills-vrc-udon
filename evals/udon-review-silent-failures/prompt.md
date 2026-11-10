---
name: udon-review-silent-failures
tags: [udon, review]
max_turns: 12
allowed_tools: [Read, Glob, Grep, Skill]
---

Please review this UdonSharp script before I upload my world. List every problem that would stop it compiling or make it misbehave in VRChat, most serious first. Do not rewrite it.

```csharp
using System.Collections.Generic;
using UdonSharp;
using UnityEngine;
using VRC.SDKBase;

[UdonBehaviourSyncMode(BehaviourSyncMode.Manual)]
public class ScoreBoard : UdonSharpBehaviour
{
    [UdonSynced] private int score;
    private List<string> history = new List<string>();

    public override void Interact()
    {
        try
        {
            score += 1;
            history.Add(Networking.LocalPlayer.displayName);
        }
        catch (System.Exception e)
        {
            Debug.LogError(e.Message);
        }
    }
}
```

Do not write files.
