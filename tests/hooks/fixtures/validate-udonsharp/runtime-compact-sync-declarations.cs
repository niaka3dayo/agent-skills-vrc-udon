using UdonSharp;

[UdonBehaviourSyncMode(BehaviourSyncMode.NoVariableSync)]
public class RuntimeCompactSyncDeclarations : UdonSharpBehaviour { [UdonSynced] private int first; [UdonSynced] private int second; [UdonSynced] private int third; [UdonSynced] private int fourth; [UdonSynced] private int fifth; [UdonSynced] private int sixth; private void Save() { Networking.SetOwner(Networking.LocalPlayer, gameObject); RequestSerialization(); } }
