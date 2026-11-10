---
type: llm
---

The explanation says that FieldChangeCallback is not a reliable signal for a synced array (changing an element does not go through the property setter, and receivers cannot count on the callback for array contents), and that receivers should redraw from OnDeserialization instead.
