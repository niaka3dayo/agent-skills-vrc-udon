---
type: llm
---

PASS only if this holds: The review states that the synced score is modified without the local player owning the object, so a non-owner's change is not synced (it needs Networking.SetOwner or an ownership check before writing).

FAIL otherwise.
