# Sync Pattern Selection (Always Loaded)

Always consult before generating code. A decision framework for WHAT to sync and WHEN to sync.
See `../references/sync-examples.md` for practical patterns and code examples.

## Decision Tree

```
Q1: Does it need to be visible to other players?
  No  -> No sync (no [UdonSynced], NoVariableSync)
  Yes -> Q2

Q2: Do late joiners need to know the current state?
  No  -> SendCustomNetworkEvent only (no synced variables needed)
  Yes -> Q3

Q3: Does the value change continuously? (position/rotation)
  Yes -> Continuous sync
  No  -> Manual sync + minimal [UdonSynced]
```

| Use Case | Pattern | Synced Variables | Example |
|----------|---------|-----------------|---------|
| Personal effects | No sync | 0 | Gun muzzle flash particles |
| Temporary action for all players | Events only | 0 | Sound effects, animation playback |
| Persistent shared state | Manual sync | Minimal | Score, game progression |
| Continuous tracking (position/rotation) | Continuous | Position-related only | Object movement |

## Data Budget

Estimate synced data volume before generating code.

| Type | Bytes | Usage |
|------|-------|-------|
| `bool` | 1 | Flags |
| `byte` | 1 | Small values 0-255 |
| `short` | 2 | 0-65535 |
| `int` | 4 | General purpose integer |
| `float` | 4 | Decimal values |
| `Vector3` | 12 | Position |
| `Quaternion` | 16 | Rotation |
| `string` | ~50B limit | Text (keep short) |

**Target**: < 50 bytes per behaviour

**Reference values** (typical world gimmicks):
- Voting system: `int + int + bool` = **9 bytes**
- Shooting manager: `bool + bool + string + int` = **~38 bytes**
- Global counter: **0** synced variables (SendCustomNetworkEvent only)
- Small to medium worlds total: typically **under 100 bytes**

**Bandwidth**: 11KB/sec -> ~0.1 sec latency for a 1KB payload

## Sync Minimization (6 Principles)

1. **Do not sync derivable values** (elapsed time = current time - syncedStartTime)
2. **Use the smallest type possible** (0-255 -> `byte`, 0-65535 -> `ushort`)
3. **Bit-pack boolean groups** (8 flags = `int` 4B vs `bool` x8 = 8B)
4. **Use SendCustomNetworkEvent for one-time effects** (no synced variable needed)
5. **Sync state, not actions** (sync gamePhase, use event for startGame)
6. **Single source of truth** (only owner modifies -> all clients update display in OnDeserialization)

## Anti-Pattern: Sync Bloat

| Bad Pattern | Improvement |
|-------------|-------------|
| Syncing display-derived values | Sync source data only, compute display locally |
| Using `int` when `byte` suffices | Choose the smallest type that fits |
| Syncing per-player data on a shared object | Consider PlayerData API (SDK 3.7.4+) |
| Marking all variables as `[UdonSynced]` | Only sync values that late joiners actually need |
| Syncing both state and actions | Sync state only, use events for actions |
