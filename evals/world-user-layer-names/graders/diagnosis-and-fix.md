---
type: llm
---

PASS only if this holds: The answer says that the VRChat client replaces custom names of layers 22-31 with user0 to user9, so NameToLayer with the custom name fails at runtime (returns -1), and that the fix is to use the layer number (22) instead of the custom name. If the answer shows a raycast layer mask, the mask is built from the layer number (for example 1 << 22), not the bare number 22.

FAIL otherwise.
