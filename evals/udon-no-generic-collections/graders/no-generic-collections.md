---
type: regex
match: not_contains
pattern: 'new\s+(List|Dictionary|HashSet|Queue|Stack)\s*<|\b(List|Dictionary|HashSet|Queue|Stack)<[^>\n]+>\s+\w+\s*[=;]'
---

Generic collections do not compile in Udon runtime code.
