# VRChat Persistence Reference

Comprehensive guide to persistent data storage in VRChat worlds (SDK 3.7.4+).

**Supported SDK Versions**: 3.7.4+ (2024 onward)

## Overview

VRChat Persistence allows saving data across sessions. There are two main systems:

| System | Purpose | Best for |
|--------|---------|----------|
| **PlayerData** | Key-value storage per player | Settings, scores, unlocks |
| **PlayerObject** | Synced UdonBehaviour per player | Complex player state, frequent updates |

## PlayerData

### Basic Concept

PlayerData is a key-value database for storing simple data per player:

- Each world can store up to **100 KB** of PlayerData per player
- Data persists across sessions and instances
- Only the local player can modify their own data
- Other players can read (but not write) your data

### Setup

1. Enable persistence on your UdonBehaviour in the Inspector
2. Wait for `OnPlayerRestored` before accessing data
3. Use `PlayerData` static methods to read/write

### Reading Data

```csharp
using UdonSharp;
using UnityEngine;
using VRC.SDKBase;
using VRC.SDK3.Persistence;

public class LoadPlayerData : UdonSharpBehaviour
{
    private bool dataReady = false;

    public override void OnPlayerRestored(VRCPlayerApi player)
    {
        if (!player.isLocal) return;

        dataReady = true;

        // TryGet pattern - returns false if key doesn't exist
        if (PlayerData.TryGetInt(player, "highScore", out int score))
        {
            Debug.Log($"Loaded high score: {score}");
        }
        else
        {
            Debug.Log("No saved high score found");
        }

        // Multiple values
        PlayerData.TryGetString(player, "username", out string name);
        PlayerData.TryGetFloat(player, "volume", out float vol);
        PlayerData.TryGetBool(player, "tutorialDone", out bool tutorial);
    }
}
```

### Writing Data

```csharp
public void SaveHighScore(int score)
{
    if (!dataReady)
    {
        Debug.LogWarning("Data not ready yet!");
        return;
    }

    VRCPlayerApi local = Networking.LocalPlayer;

    // Can only write to your own data
    PlayerData.SetInt(local, "highScore", score);
    PlayerData.SetString(local, "lastPlayed", System.DateTime.UtcNow.ToString());
}
```

### Supported Types

| Type | Methods | Size |
|------|--------|------|
| `bool` | `SetBool` / `TryGetBool` | 1 byte |
| `int` | `SetInt` / `TryGetInt` | 4 bytes |
| `float` | `SetFloat` / `TryGetFloat` | 4 bytes |
| `double` | `SetDouble` / `TryGetDouble` | 8 bytes |
| `string` | `SetString` / `TryGetString` | Variable |
| `byte[]` | `SetBytes` / `TryGetBytes` | Variable |
| `Vector2` | `SetVector2` / `TryGetVector2` | 8 bytes |
| `Vector3` | `SetVector3` / `TryGetVector3` | 12 bytes |
| `Vector4` | `SetVector4` / `TryGetVector4` | 16 bytes |
| `Quaternion` | `SetQuaternion` / `TryGetQuaternion` | 16 bytes |
| `Color` | `SetColor` / `TryGetColor` | 16 bytes |

### Utility Methods

```csharp
// Check if key exists
bool exists = PlayerData.HasKey(player, "keyName");

// Delete a key
PlayerData.DeleteKey(Networking.LocalPlayer, "oldKey");

// Get all keys (for debugging)
string[] keys = PlayerData.GetKeys(player);
```

### Checking Data Usage (SDK 3.10.0+)

Since SDK 3.10.0, VRChat exposes runtime APIs to query storage usage programmatically via
`VRCPlayerApi` methods and the `OnPersistenceUsageUpdated` event. See
[Persistence Storage Information API](#persistence-storage-information-api-sdk-3100) for the
full API reference and a complete monitoring example.

## PlayerObject

### Basic Concept

PlayerObject is a more powerful system for per-player state management. When a player joins a world, VRChat automatically instantiates one copy of a designated prefab for each player and assigns that instance to them:

- Each player gets their own auto-instantiated instance of the PlayerObject prefab
- Instances are **owned by the player they belong to**
- Supports **synced variables** (`[UdonSynced]`) for real-time visibility to all players
- Supports **multiple UdonBehaviours** on the same prefab (combines toward the 100 KB limit)
- Better for **frequently changing data** that must also be visible to others
- Up to **100 KB** per player (separate quota from PlayerData's 100 KB)
- Data stored on VRChat servers and is accessible cross-platform and cross-instance

### Required Components

All three components must be on the same root GameObject of your prefab:

| Component | Purpose |
|-----------|---------|
| `VRCPlayerObject` | Marks the prefab as a per-player object; triggers auto-instantiation |
| `UdonBehaviour` | Holds `[UdonSynced]` variables and logic |
| `VRCEnablePersistence` | Opts the UdonBehaviour's synced data into cloud persistence |

> Note: `VRCEnablePersistence` must be placed on the **same GameObject** as each `UdonBehaviour` whose data you want persisted. A PlayerObject prefab with no `VRCEnablePersistence` still instantiates per-player but does not persist data.

### Setup

1. Create a prefab in your project
2. Add `VRC Player Object` component to the root of the prefab
3. Add your `UdonSharpBehaviour` script as an `UdonBehaviour` component
4. Add `VRC Enable Persistence` component to the same root GameObject
5. Place **one instance** of the prefab in the scene — VRChat handles instantiation for all players automatically

### OnPlayerRestored on PlayerObjects

`OnPlayerRestored` fires on the PlayerObject's UdonBehaviour when that player's persistent data has been loaded from the cloud. It fires **once per player** and is your signal that the `[UdonSynced]` fields contain the restored values.

Key behaviors:
- Fires on **all PlayerObject instances** in the scene, not just the local player's
- `player` argument identifies which player's data was loaded
- The instance is **not valid for gameplay use** until `OnPlayerRestored` has fired for it
- Late-joining players will have `OnPlayerRestored` fire for all already-present players

### Usage Example: Basic PlayerObject with Persistence

```csharp
using UdonSharp;
using UnityEngine;
using VRC.SDKBase;

// VRCPlayerObject + VRCEnablePersistence must be on this same GameObject in Inspector
// Note: Networking.SetOwner() is NOT needed here — VRChat automatically assigns
// ownership of each PlayerObject instance to the player it belongs to.
[UdonBehaviourSyncMode(BehaviourSyncMode.Manual)]
public class PlayerStats : UdonSharpBehaviour
{
    [UdonSynced] public int level = 1;
    [UdonSynced] public int experience = 0;
    [UdonSynced] public int gold = 100;

    private bool dataRestored = false;
    private VRCPlayerApi ownerPlayer;

    // Fires when this player's persistent data has been loaded from the cloud
    public override void OnPlayerRestored(VRCPlayerApi player)
    {
        // Each PlayerObject instance only holds data for its own player.
        // Networking.GetOwner returns the player this instance belongs to.
        if (!Networking.IsOwner(player, gameObject)) return;

        ownerPlayer = player;
        dataRestored = true;

        if (player.isLocal)
        {
            Debug.Log($"My stats loaded: Level {level}, XP {experience}, Gold {gold}");
        }
    }

    // Only the owning player should modify their own synced variables
    public void AddExperience(int xp)
    {
        if (!Networking.IsOwner(gameObject)) return;
        if (!dataRestored) return;

        experience += xp;

        // Simple level threshold: 100 XP per level
        int threshold = level * 100;
        if (experience >= threshold)
        {
            level++;
            experience -= threshold;
            Debug.Log($"Level up! Now level {level}");
        }

        RequestSerialization(); // Sync to all clients and persist to cloud
    }

    public void SpendGold(int amount)
    {
        if (!Networking.IsOwner(gameObject)) return;
        if (!dataRestored) return;
        if (gold < amount) return;

        gold -= amount;
        RequestSerialization();
    }
}
```

### Usage Example: OnPlayerRestored with Late-Joiner Safety

A late joiner receives `OnPlayerRestored` for **all** players already in the instance. Guard
against acting on other players' data if you only care about the local player.

```csharp
using UdonSharp;
using UnityEngine;
using VRC.SDKBase;

// VRChat automatically assigns ownership of each PlayerObject to its player.
// Networking.SetOwner() is not required for PlayerObject behaviours.
[UdonBehaviourSyncMode(BehaviourSyncMode.Manual)]
public class PlayerBadge : UdonSharpBehaviour
{
    [UdonSynced] public int prestigeRank = 0;
    [UdonSynced] public bool hasBetaBadge = false;

    private bool initialized = false;

    public override void OnPlayerRestored(VRCPlayerApi player)
    {
        // This fires for every player's PlayerObject, not just the local one.
        // Always check ownership so you don't act on another player's instance.
        if (!Networking.IsOwner(player, gameObject)) return;

        initialized = true;

        if (player.isLocal)
        {
            // Safe to read own restored data here
            Debug.Log($"Badge loaded — Prestige: {prestigeRank}, Beta: {hasBetaBadge}");
            ApplyBadgeVisuals();
        }
        else
        {
            // Another player's object was restored; update their visible badge
            ApplyBadgeVisuals();
        }
    }

    // Called by world logic when the local player earns prestige
    public void GrantPrestige()
    {
        if (!Networking.IsOwner(gameObject)) return;
        if (!initialized) return;

        prestigeRank++;
        RequestSerialization();
        ApplyBadgeVisuals();
    }

    private void ApplyBadgeVisuals()
    {
        // Update badge renderer, UI, etc. based on current field values
        Debug.Log($"Applying badge visuals: rank={prestigeRank}");
    }
}
```

## PlayerData vs PlayerObject

| Aspect | PlayerData | PlayerObject |
|--------|-----------|-------------|
| Type | Key-value store | Synced UdonBehaviour on auto-instantiated prefab |
| Storage quota | 100 KB per player | 100 KB per player (separate from PlayerData) |
| API access | `PlayerData.SetInt()` / `TryGetInt()` static methods | Direct `[UdonSynced]` field access |
| Visibility to others | Not synced (local read of others' data via API) | Fully synced via `[UdonSynced]` + `RequestSerialization()` |
| Data format | Typed key-value pairs | Arbitrary serializable fields |
| Update cost | Per-write cloud write | Normal UdonSynced bandwidth (~11 KB/s total) |
| Complexity | Low — simple method calls | Higher — requires prefab setup and ownership logic |
| Best for | Settings, scores, unlocks that rarely change | Per-player game state visible to all, frequent updates |
| Requires `OnPlayerRestored` guard | Yes | Yes |
| Available since | SDK 3.7.4 | SDK 3.7.4 |

### Selection Guidelines

**Use PlayerData when:**
- Storing player preferences (volume, graphics quality)
- Recording one-time unlocks (achievements, cosmetics)
- Saving high scores and statistics
- Data changes infrequently (not every frame)
- You do not need other players to see the values in real time

**Use PlayerObject when:**
- Managing real-time player stats (health, inventory, currency)
- Data must be visible and synced to other players
- State is complex enough to benefit from full UdonBehaviour logic
- You need multiple tightly-coupled variables updated together atomically

## Persistence Storage Information API (SDK 3.10.0+)

Since SDK 3.10.0, VRChat exposes methods to query how much persistence storage each player is using. This applies to **both** PlayerData and PlayerObject data combined.

### API Methods

| Method | Returns | Description |
|--------|---------|-------------|
| `player.GetPlayerDataStorageUsage()` | `int` (bytes) | Current persistence bytes used by this player |
| `player.GetPlayerDataStorageLimit()` | `int` (bytes) | Maximum bytes allowed (typically 102400 = 100 KB) |
| `player.RequestStorageUsageUpdate()` | `void` | Requests a fresh usage value from the server |

### OnPersistenceUsageUpdated Event

`OnPersistenceUsageUpdated` fires on the local player's UdonBehaviours when updated storage
usage data is available (e.g., after a `RequestStorageUsageUpdate()` call or after a write).
The event signature takes the player whose usage changed.

### Storage Monitoring Example

```csharp
using UdonSharp;
using UnityEngine;
using VRC.SDKBase;
using VRC.SDK3.Persistence;

public class StorageMonitor : UdonSharpBehaviour
{
    [SerializeField] private UnityEngine.UI.Text usageLabel;

    // How often (seconds) to request a fresh usage figure
    private const float RefreshInterval = 30f;

    private bool dataReady = false;

    public override void OnPlayerRestored(VRCPlayerApi player)
    {
        if (!player.isLocal) return;

        dataReady = true;

        // Show initial usage and schedule periodic refresh
        ShowUsage(player);
        SendCustomEventDelayedSeconds(nameof(RequestRefresh), RefreshInterval);
    }

    // Called by VRChat when fresh storage usage data is available for a player
    public override void OnPersistenceUsageUpdated(VRCPlayerApi player)
    {
        if (!player.isLocal) return;
        ShowUsage(player);
    }

    // Periodic refresh event
    public void RequestRefresh()
    {
        VRCPlayerApi local = Networking.LocalPlayer;
        if (local == null || !local.IsValid()) return;

        local.RequestStorageUsageUpdate();

        // Schedule next refresh
        SendCustomEventDelayedSeconds(nameof(RequestRefresh), RefreshInterval);
    }

    private void ShowUsage(VRCPlayerApi player)
    {
        if (player == null || !player.IsValid()) return;

        int used = player.GetPlayerDataStorageUsage();
        int limit = player.GetPlayerDataStorageLimit();
        float percent = limit > 0 ? (used / (float)limit) * 100f : 0f;

        string text = $"Storage: {used} / {limit} bytes ({percent:F1}%)";
        Debug.Log(text);

        if (usageLabel != null)
        {
            usageLabel.text = text;
        }

        if (used > limit * 0.9f)
        {
            Debug.LogWarning("[StorageMonitor] Approaching persistence storage limit!");
        }
    }
}
```

### When to Use the Storage API

- Display a storage usage meter in a settings or debug UI
- Warn players before they hit the 100 KB limit
- Gate "save" actions if usage is critically high
- Debug storage growth during development

## Storage Limits

### PlayerData Limits

| Limit | Value |
|-------|-------|
| Total per player per world | 100 KB |
| String max length | ~50 characters |
| Key name max length | 128 characters |

### PlayerObject Limits

| Limit | Value |
|-------|-------|
| Total per player per world | 100 KB |
| Per UdonBehaviour with VRC Enable Persistence | 108 bytes per variable type |

### Bandwidth Considerations

- PlayerData writes are **not rate-limited** but should be used sparingly
- PlayerObject uses normal sync bandwidth (~11 KB/s total)
- Avoid saving every frame; throttle to significant changes

## Error Handling

```csharp
public void SafeSaveData(string key, int value)
{
    VRCPlayerApi local = Networking.LocalPlayer;

    if (local == null || !local.IsValid())
    {
        Debug.LogError("Local player not valid");
        return;
    }

    // Check if we've restored yet
    if (!dataReady)
    {
        Debug.LogWarning("Waiting for OnPlayerRestored");
        return;
    }

    PlayerData.SetInt(local, key, value);
}
```

## Common Patterns

### Settings Manager

```csharp
public class SettingsManager : UdonSharpBehaviour
{
    [SerializeField] private UnityEngine.UI.Slider volumeSlider;
    [SerializeField] private UnityEngine.UI.Toggle musicToggle;

    private bool initialized = false;

    public override void OnPlayerRestored(VRCPlayerApi player)
    {
        if (!player.isLocal) return;

        // Load settings
        if (PlayerData.TryGetFloat(player, "musicVolume", out float vol))
        {
            volumeSlider.value = vol;
        }

        if (PlayerData.TryGetBool(player, "musicEnabled", out bool enabled))
        {
            musicToggle.isOn = enabled;
        }

        initialized = true;
    }

    // Called by UI events
    public void OnVolumeChanged()
    {
        if (!initialized) return;
        PlayerData.SetFloat(Networking.LocalPlayer, "musicVolume", volumeSlider.value);
    }

    public void OnMusicToggled()
    {
        if (!initialized) return;
        PlayerData.SetBool(Networking.LocalPlayer, "musicEnabled", musicToggle.isOn);
    }
}
```

### Daily Login Reward

```csharp
public class DailyReward : UdonSharpBehaviour
{
    public int rewardAmount = 100;

    public override void OnPlayerRestored(VRCPlayerApi player)
    {
        if (!player.isLocal) return;

        string today = System.DateTime.UtcNow.ToString("yyyy-MM-dd");

        if (PlayerData.TryGetString(player, "lastLogin", out string lastLogin))
        {
            if (lastLogin != today)
            {
                // New day - give reward
                GiveReward(player);
                PlayerData.SetString(player, "lastLogin", today);
            }
            else
            {
                Debug.Log("Already claimed today's reward");
            }
        }
        else
        {
            // First time player
            GiveReward(player);
            PlayerData.SetString(player, "lastLogin", today);
        }
    }

    private void GiveReward(VRCPlayerApi player)
    {
        if (PlayerData.TryGetInt(player, "gold", out int gold))
        {
            PlayerData.SetInt(player, "gold", gold + rewardAmount);
        }
        else
        {
            PlayerData.SetInt(player, "gold", rewardAmount);
        }

        Debug.Log($"Daily reward: +{rewardAmount} gold!");
    }
}
```

### Data Aging / Pruning

When using PlayerData to accumulate records over time (visit logs, event history, activity
timestamps), the stored JSON can grow unbounded and eventually hit the **100 KB per-player
storage limit**. A date-based pruning strategy trims old entries on each session start so
the data footprint stays predictable.

**Algorithm overview:**

1. Read the JSON dictionary from PlayerData in `OnPlayerRestored`
2. Group entries by calendar date (derived from Unix-timestamp keys)
3. Sort the date groups in descending order (newest first)
4. Keep only the most recent N days of data (e.g., 7 days)
5. Rebuild the dictionary with retained entries only
6. Write the pruned JSON back to PlayerData

```csharp
using System;
using UdonSharp;
using UnityEngine;
using VRC.SDK3.Data;
using VRC.SDK3.Persistence;
using VRC.SDKBase;

/// <summary>
/// Demonstrates date-based pruning of accumulated PlayerData entries.
/// Each entry is keyed by a Unix timestamp (seconds). On restore, entries
/// older than <see cref="retainDays"/> calendar days are discarded.
/// </summary>
[UdonBehaviourSyncMode(BehaviourSyncMode.NoVariableSync)]
public class DataAgingExample : UdonSharpBehaviour
{
    /// <summary>How many calendar days of data to keep.</summary>
    [SerializeField] private int retainDays = 7;

    // Use a GUID suffix in real projects to avoid key collisions
    private const string DataKey = "AppName_ActivityLog_a1b2c3d4";

    private bool dataReady = false;

    public override void OnPlayerRestored(VRCPlayerApi player)
    {
        if (!player.isLocal) return;

        dataReady = true;

        // Initialize with an empty JSON object if no data exists yet
        if (!PlayerData.HasKey(player, DataKey))
        {
            PlayerData.SetString(player, DataKey, "{}");
            return;
        }

        if (!PlayerData.TryGetString(player, DataKey, out string json))
        {
            return;
        }

        PruneOldEntries(player, json);
    }

    /// <summary>
    /// Groups entries by local calendar date, keeps the most recent
    /// <see cref="retainDays"/> days, and writes the trimmed data back.
    /// </summary>
    private void PruneOldEntries(VRCPlayerApi player, string json)
    {
        if (!VRCJson.TryDeserializeFromJson(json, out DataToken rootToken))
        {
            Debug.LogWarning("[DataAging] Failed to parse stored JSON");
            return;
        }

        DataDictionary allEntries = rootToken.DataDictionary;
        DataList entryKeys = allEntries.GetKeys();

        if (entryKeys.Count == 0) return;

        // --- Step 1: Group entry keys by calendar date ---
        // dateGroups maps "date-as-unix-string" -> DataList of original keys
        DataDictionary dateGroups = new DataDictionary();

        for (int i = 0; i < entryKeys.Count; i++)
        {
            string keyStr = entryKeys[i].String;

            if (!long.TryParse(keyStr, out long unixSeconds))
            {
                continue;
            }

            // Normalize to midnight of that calendar day using arithmetic.
            // Avoids fragile DateTime-to-DateTimeOffset explicit cast in UdonSharp.
            // Note: this produces a UTC-midnight bucket; all entries use the same
            // reference frame so date grouping remains consistent.
            long dayStartSeconds = (unixSeconds / 86400L) * 86400L;
            string dateKey = dayStartSeconds.ToString();

            if (!dateGroups.ContainsKey(dateKey))
            {
                dateGroups[dateKey] = new DataList();
            }

            dateGroups[dateKey].DataList.Add(entryKeys[i]);
        }

        // --- Step 2: Sort dates descending (newest first) ---
        DataList dateList = dateGroups.GetKeys().DeepClone();
        dateList.Sort();
        dateList.Reverse();

        // Account for whether today's date is already present in the data.
        // If today is included, keep retainDays entries; otherwise keep
        // retainDays - 1 so that today (once recorded) stays within budget.
        // Compute today's midnight Unix timestamp using arithmetic (avoids cast fragility)
        long nowSeconds = DateTimeOffset.UtcNow.ToUnixTimeSeconds();
        long todayStartSeconds = (nowSeconds / 86400L) * 86400L;
        string todayKey = todayStartSeconds.ToString();

        bool todayPresent = dateGroups.ContainsKey(todayKey);
        int safeRetainDays = Mathf.Max(1, retainDays);
        int keepCount = Mathf.Max(1, todayPresent ? safeRetainDays : safeRetainDays - 1);

        // No pruning needed if the date count is within limits
        if (dateList.Count <= keepCount) return;

        // --- Step 3: Rebuild dictionary with only the retained days ---
        DataDictionary pruned = new DataDictionary();

        for (int d = 0; d < keepCount; d++)
        {
            DataList keys = dateGroups[dateList[d].String].DataList;

            for (int k = 0; k < keys.Count; k++)
            {
                string origKey = keys[k].String;
                pruned[origKey] = allEntries[origKey];
            }
        }

        // --- Step 4: Serialize and write back ---
        if (VRCJson.TrySerializeToJson(pruned, JsonExportType.Minify, out DataToken result))
        {
            PlayerData.SetString(player, DataKey, result.String);

            int removed = entryKeys.Count - pruned.Count;
            Debug.Log($"[DataAging] Pruned {removed} entries, kept {pruned.Count}");
        }
    }

    // ----- Public helpers for adding new entries -----

    /// <summary>
    /// Records the current UTC time as a new entry with the given payload.
    /// Call this from gameplay logic to accumulate data over sessions.
    /// </summary>
    public void RecordEntry(string payload)
    {
        if (!dataReady) return;

        VRCPlayerApi local = Networking.LocalPlayer;
        if (local == null || !local.IsValid()) return;

        if (!PlayerData.TryGetString(local, DataKey, out string json))
        {
            json = "{}";
        }

        if (!VRCJson.TryDeserializeFromJson(json, out DataToken token))
        {
            return;
        }

        DataDictionary dict = token.DataDictionary;
        string nowKey = DateTimeOffset.UtcNow.ToUnixTimeSeconds().ToString();
        dict[nowKey] = payload;

        if (VRCJson.TrySerializeToJson(dict, JsonExportType.Minify, out DataToken updated))
        {
            PlayerData.SetString(local, DataKey, updated.String);
        }
    }
}
```

**When to use:**

- Visit/session logs that accumulate one or more entries per day
- Activity history (e.g., items collected, quests completed) stored as timestamped JSON
- Any PlayerData string that grows with each session and risks hitting the 100 KB limit

**Key considerations:**

- PlayerData has a **100 KB total limit per player per world** -- pruning prevents silent write failures when the budget is exhausted
- Prune in `OnPlayerRestored` (session start) so the cost is paid once, not on every write
- Use **GUID-suffixed key names** (`"MyApp_DataKey_<guid>"`) to avoid collisions with other scripts in the same world
- The retain window is measured in **calendar days**, not a rolling 24-hour period, so partial days at the boundary are kept intact
- Combine with the [Persistence Storage Information API](#persistence-storage-information-api-sdk-3100) to monitor actual byte usage at runtime

## Debugging

### Checking Saved Data

```csharp
public void DebugPrintAllData()
{
    VRCPlayerApi local = Networking.LocalPlayer;
    string[] keys = PlayerData.GetKeys(local);

    Debug.Log($"=== PlayerData for {local.displayName} ===");
    foreach (string key in keys)
    {
        Debug.Log($"  {key}");
    }
    Debug.Log($"=== Total: {keys.Length} keys ===");
}
```

### Common Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| Data not saving | Writing before `OnPlayerRestored` | Wait for event |
| Data not loading | Key doesn't exist | Use `TryGet` pattern |
| Data size exceeded | Too much data | Compress or split data |
| Wrong player's data | Writing to non-local player | Check `player.isLocal` |

## Best Practices

1. **Always wait for `OnPlayerRestored`** before accessing PlayerData
2. **Use TryGet pattern** to handle missing keys gracefully
3. **Throttle saves** - don't save every frame
4. **Keep keys short** - they count against storage limit
5. **Test with fresh data** - clear persistence during development
6. **Document your keys** - maintain a list of all used keys
7. **Version your data** - include a version key for migration

## See Also

- [sync-examples.md](sync-examples.md) - Practical patterns for syncing persistent state with other players
- [networking.md](networking.md) - Ownership and serialization needed for PlayerObject sync
- [events.md](events.md) - `OnPlayerRestored` and `OnPersistenceUsageUpdated` event reference
