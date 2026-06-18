# VRCTween Patterns (SDK 3.10.4+)

Route animation and cancelable-delay questions here when a project can use SDK 3.10.4 or newer.

## When to Use VRCTween

Use `VRCTween` for local animation and delayed callbacks instead of writing per-frame interpolation by hand:

- Transform animation: `TweenPosition`, `TweenLocalPosition`, `TweenRotation`, `TweenLocalRotation`, `TweenScale`
- UI / renderer / light / audio animation: `TweenFade`, `TweenColor`, `TweenIntensity`, `TweenVolume`, `TweenPitch`
- Timers: `VRCTween.DelayedCall`
- Delayed active toggles: `VRCTween.DelayedSetActive`

All creation methods return a `VRCTweenHandle` for cleanup and control.

```csharp
using UdonSharp;
using UnityEngine;
using VRC.SDK3.Components;

[UdonBehaviourSyncMode(BehaviourSyncMode.NoVariableSync)]
public class TweenedDoor : UdonSharpBehaviour
{
    [SerializeField] private GameObject _door;
    [SerializeField] private AudioSource _motor;

    private VRCTweenHandle _doorTween;
    private VRCTweenHandle _pitchTween;
    private VRCTweenHandle _autoCloseTimer;

    public override void Interact()
    {
        OpenLocal();
    }

    public void OpenLocal()
    {
        _doorTween.Kill(); // invalid/default handles no-op
        _pitchTween.Kill();
        _autoCloseTimer.Kill();

        _doorTween = _door.TweenLocalPosition(new Vector3(0f, 3f, 0f), 0.4f, VRCTweenEase.OutCubic);
        _pitchTween = _motor.TweenPitch(1.25f, 0.2f, VRCTweenEase.OutQuad);
        _autoCloseTimer = VRCTween.DelayedCall(this, nameof(CloseLocal), 5f);
    }

    public void CloseLocal()
    {
        _doorTween.Kill();
        _pitchTween.Kill();
        _autoCloseTimer.Kill();

        _doorTween = _door.TweenLocalPosition(Vector3.zero, 0.4f, VRCTweenEase.InCubic);
        _pitchTween = _motor.TweenPitch(0.8f, 0.2f, VRCTweenEase.InQuad);
    }

    void OnDestroy()
    {
        _door.KillAllTweens();
        _pitchTween.Kill();
        _autoCloseTimer.Kill();
    }
}
```

## Cancelable Delays

Prefer `VRCTween.DelayedCall` over `SendCustomEventDelayedSeconds` helper-`GameObject` cancellation workarounds on SDK 3.10.4+:

```csharp
private VRCTweenHandle _timer;

public void Schedule()
{
    _timer.Kill();
    _timer = VRCTween.DelayedCall(this, nameof(OnTimer), 2f);
}

public void Cancel()
{
    _timer.Kill();
}
```

Keep the helper-`GameObject` workaround only for projects pinned to older SDKs where `VRCTween.DelayedCall` is unavailable.

Use `VRCTween.DelayedSetActive(target, active, seconds)` for a simple delayed local active-state change. Store the returned `VRCTweenHandle` if the toggle may need cancellation.

## Cleanup Rules

- Store `VRCTweenHandle` when you need to cancel, pause, restart, retarget, or test creation success.
- Call `handle.Kill()` before replacing a still-running one-shot tween on the same target/property.
- Call `gameObject.KillAllTweens()` in `OnDestroy` for long-running, looped, or externally owned tweens on that object.
- Invalid/default handles are safe no-ops for control calls such as `Kill()`. Use `handle.IsValid` only when code must branch on whether creation succeeded.

## Local-Only Networking Rule

VRCTween does **not** sync automatically. Each client creates and controls its own tween.

For networked effects, sync intent rather than the handle:

1. Send a network event or synced state such as `doorOpen = true`.
2. Each client starts the local tween in response.
3. For late joiners or deterministic timing, sync the authoritative state/time and use `Goto(...)` or recreate the tween at the correct local state.

Never put `VRCTweenHandle` in synced variables; handles are scene-local control tokens, not network state.

## High-Frequency Reuse

For one-shot interaction polish, simple kill-and-create code is usually clearer. For hot paths where a tween is redirected often, create a reusable paused handle and retarget it instead:

```csharp
private VRCTweenHandle _moveHandle;

void Start()
{
    _moveHandle = gameObject.TweenPosition(transform.position, 0f, VRCTweenEase.Linear)
        .SetLoops(-1, VRCTweenLoopType.Restart)
        .Pause();
}

public void MoveToward(Vector3 target, float duration)
{
    _moveHandle.ChangeEndValue(target, true)
        .SetDuration(duration)
        .SetEase(VRCTweenEase.OutCubic)
        .Restart();
}
```

Use this pattern for frequent retargeting such as local UI follow effects, aim indicators, or many-object controllers. Avoid it for simple button/door/audio effects where readability matters more than allocation reduction.
