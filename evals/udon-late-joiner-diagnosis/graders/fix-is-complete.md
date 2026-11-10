---
type: llm
---

PASS only if this holds: in the fixed script the synced field is only written on the object's owner. Either the acting player takes ownership with Networking.SetOwner before writing, or the action is forwarded to the owner and the owner writes. A non-owner never writes the synced field. Also the script uses Manual sync and calls RequestSerialization() after it changes the synced state. Continuous sync for this on/off state does not pass. And the received value is applied to the gate when synced data arrives (OnDeserialization or a FieldChangeCallback property).

FAIL otherwise.
