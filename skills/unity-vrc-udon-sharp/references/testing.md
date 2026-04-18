# UdonSharp Testing and Debugging Guide

Practical guide for testing and debugging UdonSharp worlds in VRChat.

**Supported SDK Versions**: 3.7.1 - 3.10.3 (SDK coverage: 3.7.1 - 3.10.3)

## Table of Contents

- [ClientSim — Editor Testing](#clientsim--editor-testing)
- [Build and Test — Runtime Testing](#build-and-test--runtime-testing)
- [Multi-Client Testing](#multi-client-testing)
- [Debug.Log Usage](#debuglog-usage)
- [Testing Checklist](#testing-checklist)

---

## ClientSim — Editor Testing

ClientSim (Client Simulator) replicates VRChat client behavior in the Unity Editor without requiring a live VRChat build. It is included in the VRChat Worlds SDK — no separate installation is needed.

### Starting a ClientSim Session

1. Open your world scene in the Unity Editor.
2. Press **Play** in the Editor.

ClientSim starts automatically. Use **Mouse + Keyboard** or a **Gamepad** to control the local player.

### Disabling ClientSim

Open **VRChat SDK > ClientSim Settings** and uncheck **Enable ClientSim**.

### What ClientSim Simulates

- Local player movement, pickups, interactions, UI, and station usage
- Udon variable inspection during Play Mode
- `OnDeserialization` events for the local player
- `OnPlayerRestored` when spawning simulated remote players (event fires only; these simulated players do not perform real network synchronization)
- Basic server-time simulation

### What ClientSim Does NOT Simulate

| Not Simulated | Why This Matters |
|---|---|
| Real networked remote players (ClientSim can add simulated remote players that fire join/restore events, but they do not perform actual network synchronization) | Ownership transfers, sync conflicts, and `OnDeserialization` from a real remote client are not testable |
| Full networking serialization | `OnPostSerialization` and `OnDeserialization` data structures differ from live VRChat |
| Network congestion (`Networking.IsClogged`) | Rate limiting and congestion behavior cannot be tested |
| Multi-user sync conflicts | Race conditions and ownership fights are invisible |
| Camera dolly animations | Camera dolly has no ClientSim preview support |

> **Critical**: Always test your world in VRChat before publishing. ClientSim catches logic bugs but cannot validate networking behavior.

---

## Build and Test — Runtime Testing

Build and Test launches your world in actual VRChat clients from the Unity Editor, giving full runtime fidelity.

### Prerequisites

1. Sign in via **VRChat SDK > Show Control Panel > Authentication**.
2. In **VRChat SDK > Show Control Panel > Settings**, specify your VRChat installation path.
3. In the **Builder** tab, click **Setup Layers for VRChat** and apply the collision matrix.

### Single-Client Build and Test

1. In the **Builder** tab, set **Number of Clients** to `1`.
2. Click **Build & Test**.

VRChat launches with your world loaded. The local client is the **instance master** and owns all GameObjects by default.

### Build and Reload

Set **Number of Clients** to `0`. This rebuilds the world and moves the already-running client into the new instance — significantly faster for iteration since no login sequence is required.

---

## Multi-Client Testing

Networking bugs (ownership, sync, late joiners) require multiple clients. Build and Test supports this natively.

### Setup

1. Set **Number of Clients** to `2` or higher.
2. Click **Build & Test**.

Unity launches the specified number of VRChat clients simultaneously. Switch between windows to control each client independently.

### Client Roles

- **First client to load** → instance master and default object owner
- **Subsequent clients** → non-master; cannot modify objects they do not own

### What to Test with Multiple Clients

| Scenario | What to Verify |
|---|---|
| **Ownership transfer** | Call `Networking.SetOwner()` on client A; verify client B sees the update |
| **Synced variable propagation** | Modify a `[UdonSynced]` field and call `RequestSerialization()`; verify all clients reflect the new value |
| **NetworkCallable events** | Trigger a `[NetworkCallable]` method from one client; verify it fires on all clients |
| **SendCustomNetworkEvent** | Send `NetworkEventTarget.All` event; verify it fires on each client |
| **Late joiner state** | Connect a third client after state has changed; verify the new client receives the current state via `OnDeserialization` |
| **Master handoff** | Close the master client; verify non-master clients elect a new master and ownership cascades correctly |
| **Pool behavior** | Call `TryToSpawn()` on the pool owner client; verify spawned objects appear on all clients |

### Late Joiner Testing Procedure

1. Start with 2 clients and modify world state (e.g., toggle a synced bool, change a score).
2. Without resetting, open a **third** client.
3. Verify the new client immediately sees the current state — not the initial state.

This is the most reliable way to catch missing `RequestSerialization()` calls and incorrect late-joiner initialization.

---

## Debug.Log Usage

### Basic Logging

```csharp
using UdonSharp;
using UnityEngine;
using VRC.SDKBase;

public class ExampleScript : UdonSharpBehaviour
{
    void Start()
    {
        Debug.Log("[ExampleScript] Start() called");
        Debug.Log($"[ExampleScript] Local player: {Networking.LocalPlayer.displayName}");
    }

    public override void Interact()
    {
        Debug.Log("[ExampleScript] Interact() triggered");
    }

    public override void OnDeserialization()
    {
        Debug.Log($"[ExampleScript] OnDeserialization — syncedValue: {syncedValue}");
    }

    [UdonSynced] private int syncedValue;
}
```

### Where Logs Appear

| Environment | Location |
|---|---|
| Unity Editor | **Console** window; UdonSharp's runtime exception watcher also highlights the exact line that threw |
| VRChat client | Output log at `%AppData%\..\LocalLow\VRChat\VRChat\output_log_HH-MM-SS.txt` |
| VRChat in-game | Press **RShift + Backtick + 3** to open the debug GUI overlay |

### Prefixing Logs

Add a unique prefix to every `Debug.Log` call so you can filter by script in the Console:

```csharp
// Easy to filter in Console using the search box
Debug.Log("[MyScriptName] message here");
Debug.LogWarning("[MyScriptName] unexpected state");
Debug.LogError("[MyScriptName] critical failure");
```

### Logging Synced State

Log both the local value and the sync event to diagnose deserialization issues:

```csharp
[UdonSynced] private bool _isOpen;

public void SetOpen(bool value)
{
    if (!Networking.IsOwner(gameObject))
    {
        Debug.LogWarning("[Door] SetOpen called but not owner — ignoring");
        return;
    }
    _isOpen = value;
    RequestSerialization();
    Debug.Log($"[Door] SetOpen({value}) — RequestSerialization called");
}

public override void OnDeserialization()
{
    Debug.Log($"[Door] OnDeserialization — _isOpen: {_isOpen}");
    ApplyState();
}
```

### Pre-Release Cleanup

Remove or disable all `Debug.Log` calls before publishing:

- Excessive logging reduces runtime performance.
- Log strings allocate memory on every call, increasing GC pressure.
- Leaving logs in can expose internal world logic to players who inspect their output files.

**Recommended pattern**: Guard logs behind a serialized flag so you can toggle them from the Inspector without modifying code:

```csharp
[SerializeField] private bool _debugMode = false;

private void Log(string message)
{
    if (_debugMode) Debug.Log(message);
}
```

Set `_debugMode = false` on all behaviours before building for release.

---

## Testing Checklist

Run through this checklist before publishing any world.

### Ownership and Sync

- [ ] All `[UdonSynced]` modifications are preceded by `Networking.IsOwner()` checks
- [ ] All Manual-sync behaviours call `RequestSerialization()` after modifying synced fields
- [ ] Ownership transfer (`Networking.SetOwner()`) is confirmed via `OnOwnershipTransferred` before writing synced state
- [ ] No ownership fights: two scripts do not compete for ownership of the same object

### Late Joiner Correctness

- [ ] A player joining after world state has changed sees the current state (not initial defaults)
- [ ] `OnDeserialization` correctly restores all derived local state from synced variables
- [ ] Objects managed by `VRCObjectPool` show correct active/inactive state to late joiners
- [ ] `PlayerData`/`PlayerObject` data is loaded before being read (use `OnPlayerRestored`)

### Network Sync

- [ ] Synced variables reflect changes on all clients within a few seconds
- [ ] `SendCustomNetworkEvent` fires correctly on `NetworkEventTarget.All` and `NetworkEventTarget.Owner`
- [ ] `[NetworkCallable]` methods (SDK 3.8.1+) receive correct parameters on all clients
- [ ] No per-frame `RequestSerialization()` calls that could flood the network budget

### Multi-User Interaction

- [ ] Two players interacting with the same object simultaneously does not corrupt state
- [ ] Master handoff (closing the master client) does not break world functionality
- [ ] Ownership transfers complete without leaving objects in an unowned or double-owned state

### Performance

- [ ] No per-frame networking calls (`RequestSerialization`, `SendCustomNetworkEvent`) without throttling
- [ ] `Debug.Log` calls removed or guarded behind a `_debugMode` flag set to `false`
- [ ] No `Update()` loops that could be replaced with event-driven callbacks

## See Also

- [api.md](api.md) - VRCObjectPool API, VRCPlayerApi methods, and Camera Dolly API reference
- [networking.md](networking.md) - Ownership model, sync modes, and RequestSerialization
- [networking-antipatterns.md](networking-antipatterns.md) - Common networking mistakes and how to avoid them
- [troubleshooting.md](troubleshooting.md) - Common errors and solutions
- [events.md](events.md) - Complete event list including OnDeserialization and OnPlayerRestored
