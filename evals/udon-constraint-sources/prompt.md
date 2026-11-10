---
name: udon-constraint-sources
tags: [udon, dynamics, sdk-3.10.6]
max_turns: 12
allowed_tools: [Read, Glob, Grep, Skill]
---

UdonSharp on VRChat SDK 3.10.6. A VRCParentConstraint in my world has two sources. Write a script with a public method that, each time it is called, moves all the weight to the other source: source 0 at weight 1 and source 1 at weight 0, then swapped on the next call.

Reply with the complete script in one C# code block, followed by a short note on anything the user must set up in the Inspector. Do not write files.
