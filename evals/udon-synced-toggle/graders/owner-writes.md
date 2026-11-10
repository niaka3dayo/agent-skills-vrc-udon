---
type: llm
---

PASS only if this holds: the synced field is only written on the object's owner. Either the acting player takes ownership with Networking.SetOwner before writing, or the action is forwarded to the owner and the owner writes. A non-owner never writes the synced field.

FAIL otherwise.
