# VRChat Persistence リファレンス

Comprehensive guide to persistent data storage in VRChat worlds (SDK 3.7.4+).

**対応SDKバージョン**: 3.7.4+ (2024年〜)

## 概要

VRChat Persistence により、セッションをまたいでデータを保存できる。主に2つのシステムがある:

| システム | 用途 | 最適な用途 |
|--------|---------|----------|
| **PlayerData** | Key-value storage per player | Settings, scores, unlocks |
| **PlayerObject** | Synced UdonBehaviour per player | Complex player state, frequent updates |

## PlayerData

### 基本コンセプト

PlayerData はプレイヤーに関するシンプルなデータを保存するキーバリューデータベース:

- Each world can store up to **100 KB** of PlayerData per player
- Data persists across sessions and instances
- Only the local player can modify their own data
- Other players can read (but not write) your data

### セットアップ

1. Enable persistence on your UdonBehaviour in the Inspector
2. Wait for `OnPlayerRestored` before accessing data
3. Use `PlayerData` static methods to read/write

### データの読み取り

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

### データの書き込み

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

### サポートされる型

| 型 | メソッド | サイズ |
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

### ユーティリティメソッド

```csharp
// Check if key exists
bool exists = PlayerData.HasKey(player, "keyName");

// Delete a key
PlayerData.DeleteKey(Networking.LocalPlayer, "oldKey");

// Get all keys (for debugging)
string[] keys = PlayerData.GetKeys(player);
```

### データ使用量の確認 (SDK 3.10.0+)

SDK 3.10.0 以降、PlayerData のデータ使用量情報が公開されました。ワールドのデバッグパネルや SDK ツールを通じて、各プレイヤーが使用している Persistence データ量を確認できます。100 KB の上限に対してどの程度使用しているかを監視し、上限超過によるデータ書き込み失敗を防止してください。

## PlayerObject

### 基本コンセプト

PlayerObject はプレイヤーごとの状態管理のためのより強力なシステム:

- Each player gets their own instance of a prefab
- Supports **synced variables** (`[UdonSynced]`)
- Supports **multiple UdonBehaviours** (more storage)
- Better for **frequently changing data**
- Up to **100 KB** per player

### セットアップ

1. Create a prefab with UdonBehaviour(s)
2. Add `VRC Player Object` component to the prefab
3. Enable `VRC Enable Persistence` on each UdonBehaviour
4. Place the prefab in the scene (it will be instantiated per player)

### 使用例: プレイヤーステータス

```csharp
using UdonSharp;
using UnityEngine;
using VRC.SDKBase;

[UdonBehaviourSyncMode(BehaviourSyncMode.Manual)]
public class PlayerStats : UdonSharpBehaviour
{
    // Owner of this PlayerObject
    public VRCPlayerApi Owner { get; private set; }

    // Persisted synced variables
    [UdonSynced] public int level = 1;
    [UdonSynced] public int experience = 0;
    [UdonSynced] public int gold = 100;

    // Called when the PlayerObject is assigned to a player
    public override void OnPlayerRestored(VRCPlayerApi player)
    {
        Owner = player;

        if (player.isLocal)
        {
            Debug.Log($"My stats loaded: Level {level}, XP {experience}");
        }
    }

    public void AddExperience(int xp)
    {
        if (!Networking.IsOwner(gameObject)) return;

        experience += xp;

        // Level up check
        while (experience >= GetXPForLevel(level + 1))
        {
            level++;
            Debug.Log($"Level up! Now level {level}");
        }

        RequestSerialization(); // Sync and persist
    }

    private int GetXPForLevel(int lvl)
    {
        return lvl * 100;
    }
}
```

## PlayerData vs PlayerObject

| 機能 | PlayerData | PlayerObject |
|---------|------------|--------------|
| Storage limit | 100 KB | 100 KB |
| Sync mode | No auto-sync | Synced variables |
| Update frequency | On-demand | Continuous/Manual |
| Complexity | Simple key-value | Full UdonBehaviour |
| Use case | Settings, unlocks | Active game state |
| Access pattern | Static methods | Component on prefab |

### 使い分けの指針

**Use PlayerData:**
- Player preferences (volume, graphics)
- One-time unlocks (achievements, skins)
- High scores and statistics
- Data rarely changes during play

**Use PlayerObject:**
- Real-time player stats (health, inventory)
- Frequently synced data
- Complex state with multiple variables
- Data that needs to be visible to others

## ストレージ制限

### PlayerData の制限

| 制限項目 | 値 |
|-------|-------|
| Total per player per world | 100 KB |
| String max length | ~50 characters |
| Key name max length | 128 characters |

### PlayerObject の制限

| 制限項目 | 値 |
|-------|-------|
| Total per player per world | 100 KB |
| Per UdonBehaviour with VRC Enable Persistence | 108 bytes per variable type |

### 帯域幅に関する考慮事項

- PlayerData writes are **not rate-limited** but should be used sparingly
- PlayerObject uses normal sync bandwidth (~11 KB/s total)
- Avoid saving every frame; throttle to significant changes

## エラーハンドリング

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

## よくあるパターン

### 設定マネージャー

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

### デイリーログインリワード

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

## デバッグ

### 保存データの確認

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

### よくある問題

| 問題 | 原因 | 解決策 |
|-------|-------|----------|
| Data not saving | Writing before `OnPlayerRestored` | Wait for event |
| Data not loading | Key doesn't exist | Use `TryGet` pattern |
| Data size exceeded | Too much data | Compress or split data |
| Wrong player's data | Writing to non-local player | Check `player.isLocal` |

## ベストプラクティス

1. **Always wait for `OnPlayerRestored`** before accessing PlayerData
2. **Use TryGet pattern** to handle missing keys gracefully
3. **Throttle saves** - don't save every frame
4. **Keep keys short** - they count against storage limit
5. **Test with fresh data** - clear persistence during development
6. **Document your keys** - maintain a list of all used keys
7. **Version your data** - include a version key for migration
