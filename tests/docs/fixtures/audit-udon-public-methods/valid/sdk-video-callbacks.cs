using UdonSharp;
using System;
using UnityEngine.ParticleSystemJobs;
using VRC.Udon.Common;
using CallbackBoolean = System.Boolean;

public class SdkVideoCallbacks : UdonSharpBehaviour
{
    public override void OnVideoLoop() { }
    public override void OnVideoPause() { }
    public override void OnVideoPlay() { }
    public override void OnPostSerialization(SerializationResult result) { }
    public void OnGUI() { }
    public void OnParticleSystemStopped() { }
    public void OnParticleUpdateJobScheduled(ParticleSystemJobData jobData) { }
}

public class QualifiedReturnCallback : UdonSharpBehaviour
{
    public override System.Boolean OnOwnershipRequest(
        VRC.SDKBase.VRCPlayerApi requester,
        VRC.SDKBase.VRCPlayerApi newOwner
    ) => true;
}

public class ImportedReturnCallback : UdonSharpBehaviour
{
    public override Boolean OnOwnershipRequest(
        VRC.SDKBase.VRCPlayerApi requester,
        VRC.SDKBase.VRCPlayerApi newOwner
    ) => true;
}

public class AliasedReturnCallback : UdonSharpBehaviour
{
    public override CallbackBoolean OnOwnershipRequest(
        VRC.SDKBase.VRCPlayerApi requester,
        VRC.SDKBase.VRCPlayerApi newOwner
    ) => true;
}
