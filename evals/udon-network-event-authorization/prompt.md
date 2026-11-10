---
name: udon-network-event-authorization
tags: [udon, networking, security]
max_turns: 12
allowed_tools: [Read, Glob, Grep, Skill]
---

UdonSharp, VRChat SDK 3.10.6. My game has a 'reset round' action. Only the player who currently owns the GameManager object may trigger it, and when they do, every client has to run the reset. If any other player tries, by pressing the button or by sending the network event themselves, nothing must happen. Write the GameManager script.

Reply with the complete script in one C# code block, followed by a short note on anything the user must set up in the Inspector. Do not write files.
