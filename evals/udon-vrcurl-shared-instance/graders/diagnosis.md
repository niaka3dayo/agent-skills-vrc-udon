---
type: llm
---

PASS only if this holds: The answer says that VRCUrl.Empty is a single shared instance, so fields and array elements initialised with it share Inspector data across objects that use the same program, and that each field and each array element needs its own new VRCUrl(""). Any corrected code in the reply no longer assigns VRCUrl.Empty to the field or to an array element.

FAIL otherwise.
