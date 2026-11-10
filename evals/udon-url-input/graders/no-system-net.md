---
type: llm
---

PASS only if this holds: the code in the reply does not use System.Net (also fully qualified), HttpClient, WebClient, WWW, or UnityWebRequest. Naming it in prose or in a code comment to say it is unavailable is fine. Only an actual use in the code fails.

FAIL otherwise.
