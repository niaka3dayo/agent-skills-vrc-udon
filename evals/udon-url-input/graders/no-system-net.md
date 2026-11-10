---
type: regex
match: not_contains
pattern: 'using\s+System\.Net|UnityWebRequest\.\w+\s*\(|new\s+(HttpClient|WebClient|WWW)\b'
---

System.Net and UnityWebRequest are not available in Udon.
