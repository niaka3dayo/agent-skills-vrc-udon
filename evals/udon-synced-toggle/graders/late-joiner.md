---
type: llm
---

PASS only if this holds: The script keeps the door's open/closed state in an [UdonSynced] field and applies that state to the door when synced data arrives (OnDeserialization or a FieldChangeCallback property), so a player who joins later sees the current state. It must not rely only on a network event such as SendCustomNetworkEvent to carry the state.

FAIL otherwise.
