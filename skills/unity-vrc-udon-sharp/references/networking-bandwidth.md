# UdonSharp Network Bandwidth and Data Optimization

Bandwidth throttling, request serialization patterns, bit packing, data size optimization, owner-centric architecture, and network debugging.

## Network Bandwidth and Throttling

### Bandwidth Limits

> Udon scripts can send out about **11 kilobytes** per second.
> — [VRChat Creator Docs](https://creators.vrchat.com/worlds/udon/networking/network-details)

Exceeding this limit causes sync delays known as "Death Runs." This is particularly problematic when:
- Multiple UI elements are operated rapidly
- Many synced variables are updated simultaneously
- Players spam operations repeatedly

### Detecting Network Congestion

Use `Networking.IsClogged` to check for network queue backup:

```csharp
if (Networking.IsClogged)
{
    // Network is congested - defer synchronization
    SendCustomEventDelayedSeconds(nameof(RetrySync), 1.0f);
    return;
}
RequestSerialization();
```

### RequestSerialization Throttling Pattern

For high-frequency updates, wrap `RequestSerialization()` with interval control:

**Key principles:**
1. Enforce minimum interval between syncs (e.g., 1 second)
2. Auto-retry during network congestion
3. Prevent scheduling duplicate delayed events
4. Always sync the latest state (not intermediate states)

```csharp
private const float SyncInterval = 1.0f;
private const float RetryInterval = 1.0f;
private bool isPendingSync = false;
private double lastSyncTime = double.MinValue;

/// <summary>
/// Call this instead of RequestSerialization() for throttled sync.
/// </summary>
private void RequestSync()
{
    if (isPendingSync) return;
    if (!Networking.IsOwner(gameObject)) return;

    double now = Time.timeAsDouble;

    if (now >= lastSyncTime + SyncInterval)
    {
        ExecuteSync();
    }
    else
    {
        float delay = (float)(lastSyncTime + SyncInterval - now) + 0.001f;
        SendCustomEventDelayedSeconds(nameof(ExecuteSync), delay);
        isPendingSync = true;
    }
}

public void ExecuteSync()
{
    isPendingSync = false;
    if (!Networking.IsOwner(gameObject)) return;

    if (Networking.IsClogged)
    {
        SendCustomEventDelayedSeconds(nameof(ExecuteSync), RetryInterval);
        isPendingSync = true;
        return;
    }

    RequestSerialization();
    lastSyncTime = Time.timeAsDouble;
}
```

**Advantages:**
- Prevents network overload from rapid operations
- Auto-retries during congestion
- Always syncs the latest state
- No duplicate delayed events

**Trade-offs:**
- Up to `SyncInterval` seconds of latency
- Individual sync requests may be merged (syncing state, not events)

Reference template: `assets/templates/ThrottledSync.cs`

### Periodic Sync Pattern

Continuous synchronization at controlled intervals:

```csharp
private const float PeriodicSyncInterval = 10.0f;
private bool isPendingPeriodicSync = false;
private bool loopNeeded = false;

private void StartPeriodicSync()
{
    if (!Networking.IsOwner(gameObject)) return;
    loopNeeded = true;
    RequestPeriodicSync();
}

private void StopPeriodicSync()
{
    loopNeeded = false;
}

private void RequestPeriodicSync()
{
    if (isPendingPeriodicSync) return;
    if (!Networking.IsOwner(gameObject)) return;

    SendCustomEventDelayedSeconds(nameof(ExecutePeriodicSync), PeriodicSyncInterval);
    isPendingPeriodicSync = true;
}

public void ExecutePeriodicSync()
{
    isPendingPeriodicSync = false;
    if (!Networking.IsOwner(gameObject)) return;

    RequestSync(); // Uses throttled sync

    if (loopNeeded)
    {
        RequestPeriodicSync();
    }
}
```

## Data Size Optimization

Minimize synced data size to stay within VRChat's ~11KB/sec bandwidth budget.

### Sync Overhead

Each synced variable has header overhead (metadata to identify the variable). This means:

| Approach | Variable count | Sync data |
|-----------|--------|-----------|
| 8 separate `byte` | 8 | ~16 bytes (8 data + 8 overhead) |
| 1 packed `ulong` | 1 | ~9 bytes (8 data + 1 overhead) |

**Key point**: Reducing the number of variables is often more effective than reducing data size.

### Bit Packing

Pack multiple small values into fewer variables:

**Bit count and max value reference:**

| Bits | Max value | Common uses |
|---------|--------|-------------|
| 1 | 1 | Boolean flags |
| 2 | 3 | 4-state enum |
| 3 | 7 | Dice (d6), small indices |
| 4 | 15 | Hex digits, small counters |
| 5 | 31 | Days (of month) |
| 6 | 63 | Minutes, seconds |
| 7 | 127 | ASCII characters |
| 8 | 255 | Full byte |

**Example: Pack 8 bools into 1 byte (87.5% reduction)**

```csharp
// Pack
byte packed = 0;
if (flag0) packed |= 1;      // bit 0
if (flag1) packed |= 2;      // bit 1
if (flag2) packed |= 4;      // bit 2
if (flag3) packed |= 8;      // bit 3
if (flag4) packed |= 16;     // bit 4
if (flag5) packed |= 32;     // bit 5
if (flag6) packed |= 64;     // bit 6
if (flag7) packed |= 128;    // bit 7

// Unpack
bool flag0 = (packed & 1) != 0;
bool flag1 = (packed & 2) != 0;
bool flag2 = (packed & 4) != 0;
// ...
```

**Example: Pack array of 3-bit values into ulong**

```csharp
// Pack 20 values (0-7 each) into single ulong (60 bits used)
public void PackValues(byte[] values, out ulong packed)
{
    packed = 0;
    for (int i = 0; i < 20 && i < values.Length; i++)
    {
        ulong threeBits = (ulong)(values[i] & 0b111);
        packed |= threeBits << (i * 3);
    }
}

// Unpack
public void UnpackValues(ulong packed, byte[] values)
{
    for (int i = 0; i < 20 && i < values.Length; i++)
    {
        values[i] = (byte)((packed >> (i * 3)) & 0b111);
    }
}
```

Reference template: `assets/templates/BitPacking.cs`

### Range Shifting

For values with a limited range, shift to minimize bit count:

```csharp
// Value range: 200-210 (requires 8 bits as-is)
// Shifted range: 0-10 (requires only 4 bits)

// Pack
byte packed = (byte)(value - 200);

// Unpack
int value = packed + 200;
```

**Signed values**: Add an offset before packing to convert to unsigned:

```csharp
// Range: -50 to +50 (requires signed handling)
// Shifted: 0 to 100 (7 bits, unsigned)

byte packed = (byte)(signedValue + 50);
int signedValue = packed - 50;
```

### When to Use Bit Packing

| Scenario | Recommendation |
|---------|------|
| Few variables, full range used | No packing needed - not worth the overhead |
| Many bools | Pack into bytes/ints |
| Array of small integers | Pack into ulong arrays |
| Bandwidth is critical | Pack aggressively |
| Large state sync for late joiners | Consider packing |

**Caveats:**
- `FieldChangeCallback` doesn't work directly with packed variables
- Adds complexity - only use when bandwidth is a concern
- Call pack before `RequestSerialization()`, unpack in `OnDeserialization()`

## Synced Data Size — Application Examples

VRChat's transmission bandwidth is approximately **11KB/sec**. Large synced data causes severe lag.

### Data Size Estimation

| Data | Size | Sync delay (11KB/sec) |
|--------|--------|---------------------|
| `int[40]` | 160 bytes | Instant |
| `int[400]` | 1,600 bytes | ~0.15 sec |
| `int[4000]` | 16,000 bytes | ~1.5 sec (NG) |
| `byte[100]` | 100 bytes | Instant |

### Optimization Techniques

#### 1. Use Smaller Types

```csharp
// NG: Using int (4 bytes) when values are 0-255
[UdonSynced] private int[] bottleColors; // 40 elements = 160 bytes

// OK: byte (1 byte) is sufficient
[UdonSynced] private byte[] bottleColors; // 40 elements = 40 bytes (75% reduction)
```
#### 2. Bit Packing (Many Small Values)

Pack multiple small values into fewer variables to reduce sync overhead.
See [Bit Packing](#bit-packing) above for the complete bit-count reference table and pack/unpack examples.

Quick example — 40 color IDs (0-7, 3 bits each) into 15 bytes:

```csharp
// 40 colors x 3 bits = 120 bits = 15 bytes (160 bytes from int[40] -> 93% reduction)
[UdonSynced] private byte[] packedColors; // 15 bytes stores 40 colors

private byte GetColor(int index)
{
    int byteIdx = (index * 3) / 8;
    int bitOffset = (index * 3) % 8;
    int raw = packedColors[byteIdx] | (packedColors[byteIdx + 1] << 8);
    return (byte)((raw >> bitOffset) & 0x07);
}
```

#### 3. Delta Sync (Send Only Changes)

Sync only changes instead of the full state. Send full state initially, then only deltas.

```csharp
// Instead of syncing full state every time, sync only the latest operation
[UdonSynced] private int lastMoveFrom;
[UdonSynced] private int lastMoveTo;
[UdonSynced] private int moveCounter; // For change detection

public override void OnDeserialization()
{
    // Re-apply the operation locally on the receiving side
    ApplyMove(lastMoveFrom, lastMoveTo);
}
```

**Note:** Delta sync does not handle late joiners. If full state restoration is needed for initial connections, maintain full state in a synced array as well.

---

## Debugging Network Issues

1. **Check Ownership**: `Debug.Log($"Owner: {Networking.GetOwner(gameObject).displayName}")`
2. **Verify Sync**: Log before and after `RequestSerialization()`
3. **Test Late Join**: Have player join mid-game to verify `OnDeserialization`
4. **Monitor Bandwidth**: Keep sync frequency low (max 10/sec per object)
5. **Test Edge Cases**: Player leaving while owning objects, rapid ownership transfers
6. **Check Congestion**: Log `Networking.IsClogged` to detect network issues
7. **Measure Data Size**: Use `OnPostSerialization(SerializationResult result)` to check `result.byteCount`

## Owner-Centric Architecture (Recommended Design)

For multiplayer games, the recommended design is **"only the owner modifies state, others receive the results."**

### Design Principles

1. **One GameManager** holds all game state synced variables (Manual sync)
2. **Only the owner** runs game logic in `Update()`
3. **Non-owners** only update display in `OnDeserialization()`
4. **UI operations** notify the owner via `SendCustomNetworkEvent(Owner)`

### Code Example: Owner-Centric GameManager

```csharp
[UdonBehaviourSyncMode(BehaviourSyncMode.Manual)]
public class GameManager : UdonSharpBehaviour
{
    [UdonSynced] private int[] boardState;
    [UdonSynced] private int currentTurn;
    [UdonSynced] private int gamePhase; // 0=Lobby, 1=Playing, 2=Result

    // --- Input from UI (fires on all clients) ---
    public void OnCellClicked(int cellIndex)
    {
        // Delegate to owner (works even if self is owner)
        SendCustomNetworkEvent(
            NetworkEventTarget.Owner,
            nameof(OwnerProcessMove),
            cellIndex,
            Networking.LocalPlayer.playerId
        );
    }

    // --- Owner only ---
    [NetworkCallable]
    public void OwnerProcessMove(int cellIndex, int playerId)
    {
        if (gamePhase != 1) return;           // Ignore if not in game
        if (playerId != GetCurrentPlayerId()) return; // Ignore if not their turn
        if (boardState[cellIndex] != 0) return;       // Already occupied

        boardState[cellIndex] = currentTurn;
        currentTurn = (currentTurn % 2) + 1;
        RequestSerialization();
    }

    // --- All clients: update display ---
    public override void OnDeserialization()
    {
        UpdateBoardDisplay();
        UpdateTurnIndicator();
    }

    private int GetCurrentPlayerId() { /* ... */ return 0; }
    private void UpdateBoardDisplay() { /* Reflect boardState in UI */ }
    private void UpdateTurnIndicator() { /* Display currentTurn */ }
}
```

**Key points:**
- UI callback -> `SendCustomNetworkEvent(Owner)` -> Owner validates and modifies -> `RequestSerialization()` -> Everyone receives via `OnDeserialization()`
- Non-owners can still press buttons (delegated to owner)
- Invalid operations can be rejected by the owner (design similar to server authority)


## See Also

- [networking.md](networking.md) - Sync modes, ownership, network events, data limits
- [networking-antipatterns.md](networking-antipatterns.md) - Anti-patterns and advanced networking patterns
- [patterns-networking.md](patterns-networking.md) - Object pooling, game state, NetworkCallable
- [sync-examples.md](sync-examples.md) - Concrete synced gimmick patterns with data budget reference
- [troubleshooting.md](troubleshooting.md) - Debugging networking issues
