---
type: llm
---

PASS only if this holds: the script uses Manual sync and calls RequestSerialization() after it changes the synced state. Continuous sync for this on/off state does not pass.

FAIL otherwise.
