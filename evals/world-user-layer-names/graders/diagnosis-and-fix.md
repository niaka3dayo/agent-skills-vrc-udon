---
type: llm
---

The answer says that the VRChat client replaces custom names of layers 22-31 with user0 to user9, so NameToLayer with the custom name fails at runtime (returns -1), and that the fix is to use the layer number (22) or a mask built from it instead of the custom name.
