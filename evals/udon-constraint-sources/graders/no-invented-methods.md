---
type: llm
---

PASS only if this holds: the code in the reply does not use GetSourceCount() or SetSourceWeight(), which do not exist. Naming it in prose or in a code comment to say it is unavailable is fine. Only an actual use in the code fails.

FAIL otherwise.
