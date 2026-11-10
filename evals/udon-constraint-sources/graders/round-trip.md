---
type: llm
---

The script reads each source with GetSource(index), changes the Weight on that VRCConstraintSource value, and writes it back with SetSource(index, source). It does not modify the constraint's Sources list directly, and it does not assume that changing the struct returned by GetSource updates the constraint without writing it back.
