---
type: llm
---

PASS only if this holds: The answer wires the button in the Inspector: the Button's OnClick list targets the UdonBehaviour and calls SendCustomEvent with the method name as a string. It does not tell the user to register a listener from code.

FAIL otherwise.
