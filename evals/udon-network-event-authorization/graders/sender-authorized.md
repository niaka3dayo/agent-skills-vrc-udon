---
type: llm
---

PASS only if this holds: On receipt, the script checks who sent the network event (NetworkCalling.CallingPlayer, after confirming NetworkCalling.InNetworkCall) and ignores the request unless that sender is the owner of the GameManager object. It does not treat being the instance master as the security check. No method that performs the reset can be reached from the network without that sender check: this covers every [NetworkCallable] method, with or without parameters or a leading underscore, and every parameterless public method without a leading underscore. A player who is not the owner and presses the button does not run the reset on their own client either.

FAIL otherwise.
