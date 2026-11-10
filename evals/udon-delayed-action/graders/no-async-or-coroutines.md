---
type: regex
match: not_contains
pattern: '\basync\s+\w+\s+\w+\s*\(|\bawait\s+\w|StartCoroutine\s*\(|yield\s+return|new\s+WaitForSeconds|Task\.Delay\s*\(|\bInvoke\s*\(\s*(nameof|\")'
---

async/await, coroutines and Invoke are unavailable in Udon.
