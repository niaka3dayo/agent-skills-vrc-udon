---
name: udon-network-event-authorization
tags: [udon, networking, security]
max_turns: 12
allowed_tools: [Read, Glob, Grep, Skill]
---

UdonSharp, VRChat SDK 3.10.6. My game has a 'reset round' action. Any player may request it, but the reset must only happen when the request comes from the player who currently owns the GameManager object, and every client has to run the reset. Other players must not be able to trigger the reset by sending the event themselves. Write the GameManager script.

Reply with the complete script in one C# code block, followed by a short note on anything the user must set up in the Inspector. Do not write files.
