---
type: regex
match: not_contains
pattern: '\basync\b|\bawait\b|IEnumerator|StartCoroutine|WaitForSeconds|Task\.Delay|Invoke\s*\('
---

async/await, coroutines and Invoke are unavailable in Udon.
