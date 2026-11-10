---
name: world-user-layer-names
tags: [world, layers]
max_turns: 12
allowed_tools: [Read, Glob, Grep, Skill]
---

In my VRChat world project I renamed layer 22 to Projectiles in Unity's Tags and Layers. My script calls LayerMask.NameToLayer("Projectiles") to set up a raycast. It works in the Unity editor, but in the VRChat client the raycast hits nothing. What is going on, and how do I fix it? Do not write files.
