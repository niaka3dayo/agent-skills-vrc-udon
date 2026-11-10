---
type: llm
---

PASS only if this holds: The click handler is not left as an unprefixed parameterless public method without comment. Either its name starts with an underscore (for example _OnButtonClicked), or the answer explicitly explains that an unprefixed public method can be called by other players as a network event.

FAIL otherwise.
