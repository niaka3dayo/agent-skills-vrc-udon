---
type: regex
match: not_contains
pattern: 'PlayerPrefs\.\w+\s*\(|using\s+System\.IO|\bFile\.\w+\s*\('
---

PlayerPrefs and file IO do not persist data in VRChat worlds.
