---
type: llm
---

On receipt, the script checks who sent the network event (NetworkCalling.CallingPlayer, after confirming NetworkCalling.InNetworkCall) and ignores the request unless that sender is the owner of the GameManager object. It does not treat being the instance master as the security check, and it does not leave an unprefixed parameterless public method that performs the reset without any sender check.
