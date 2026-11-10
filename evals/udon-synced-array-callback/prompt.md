---
name: udon-synced-array-callback
tags: [udon, networking, review]
max_turns: 12
allowed_tools: [Read, Glob, Grep, Skill]
---

My UdonSharp scoreboard syncs an int array. When the owner changes one team's score, the other players' boards do not update, although the owner's board does. What is wrong, and what should the script look like?

```csharp
using UdonSharp;
using UnityEngine;
using VRC.SDKBase;

[UdonBehaviourSyncMode(BehaviourSyncMode.Manual)]
public class TeamScores : UdonSharpBehaviour
{
    [UdonSynced, FieldChangeCallback(nameof(Scores))]
    private int[] _scores = new int[4];

    public int[] Scores
    {
        get => _scores;
        set { _scores = value; Redraw(); }
    }

    public void _AddPoint(int team)
    {
        if (!Networking.IsOwner(gameObject)) return;
        _scores[team] += 1;
        RequestSerialization();
        Redraw();
    }

    private void Redraw() { /* updates the labels */ }
}
```

Reply with the explanation and the corrected script in one C# code block. Do not write files.
