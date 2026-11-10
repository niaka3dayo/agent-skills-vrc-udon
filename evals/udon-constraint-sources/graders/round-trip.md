---
type: llm
---

PASS only if this holds: The script reads each source with GetSource(index), changes the Weight on that VRCConstraintSource value, and writes it back with SetSource(index, source). It does not modify the constraint's Sources list directly, and it does not assume that changing the struct returned by GetSource updates the constraint without writing it back. After the sources are written back it calls ApplyConfigurationChanges(). Successive calls alternate which of the two sources has weight 1.

FAIL otherwise.
