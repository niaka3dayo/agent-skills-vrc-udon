---
type: llm
---

The answer says that VRCUrl.Empty is a single shared instance, so fields and array elements initialised with it share Inspector data across objects that use the same program, and that each field and each array element needs its own new VRCUrl("").
