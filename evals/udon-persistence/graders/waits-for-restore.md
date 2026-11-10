---
type: llm
---

PASS only if this holds: The script reads the stored best time only after OnPlayerRestored has fired for the local player (not in Start), and writes with PlayerData for the local player.

FAIL otherwise.
