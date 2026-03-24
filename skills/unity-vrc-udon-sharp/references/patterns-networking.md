# UdonSharp Networking Patterns

Object pooling, synced game state management, NetworkCallable patterns, persistence, dynamics interactions, and delayed event debouncing.

## Object Pooling

### Simple Object Pooling

```csharp
public class SimplePool : UdonSharpBehaviour
{
    public GameObject prefab;
    public int poolSize = 10;
    public Transform poolParent;

    private GameObject[] pool;
    private int nextIndex = 0;

    void Start()
    {
        pool = new GameObject[poolSize];
        for (int i = 0; i < poolSize; i++)
        {
            pool[i] = VRCInstantiate(prefab);
            pool[i].transform.SetParent(poolParent);
            pool[i].SetActive(false);
        }
    }

    public GameObject Get()
    {
        GameObject obj = pool[nextIndex];
        obj.SetActive(true);
        nextIndex = (nextIndex + 1) % poolSize;
        return obj;
    }

    public void Return(GameObject obj)
    {
        obj.SetActive(false);
    }
}
```

## Master-Managed Player Object Pool

A networked pattern that assigns a unique pool object to each player present in the world.
The instance master owns all assignment logic; other clients react to synced state via `OnDeserialization`.

**When to use this pattern:**
- Each player needs a dedicated, persistent object (nameplate, avatar attachment, scoreboard slot, etc.)
- Pool size is fixed and known at design time (set `_poolObjects` in the Inspector)
- Assignment authority must be centralised to avoid conflicts

### Architecture

| Member | Kind | Purpose |
|---|---|---|
| `_assignments` | `[UdonSynced] int[]` | Maps pool index → VRC player ID (0 = unassigned) |
| `_poolObjects` | `UdonSharpBehaviour[]` | Inspector-assigned pool object references |
| `_freeQueue` | `int[]` (local) | FIFO ring buffer of free slot indices (master only) |
| `_freeHead/Tail` | `int` (local) | Ring-buffer pointers for O(1) enqueue / dequeue |
| `_previousAssignments` | `int[]` (local) | Snapshot used in `OnDeserialization` for change detection |

**Template:** [assets/templates/MasterManagedPlayerPool.cs](../assets/templates/MasterManagedPlayerPool.cs)

The implementation uses `Manual` sync mode. On `Start`, it allocates `_assignments[]` (synced) and the local `_freeQueue` ring buffer. Only the master initialises the free queue. `OnPlayerJoined`/`OnPlayerLeft` (master only) dequeue/enqueue slots and call `RequestSerialization`. `OnDeserialization` diffs against `_previousAssignments` and calls `_ActivateSlot`/`_DeactivateSlot` only for changed entries. `OnMasterClientSwitched` rebuilds the free queue and schedules a deferred `VerifyAssignments` call to close the race-condition window.


### Key Design Decisions

**Why master-only assignment?**
Centralising writes to the master eliminates the need for distributed conflict resolution. Only one client ever calls `RequestSerialization`, so the synced array is always consistent.

**Why a FIFO queue instead of a linear scan?**
`OnPlayerJoined` runs on every join event. A ring-buffer dequeue is O(1) regardless of pool size, keeping join latency predictable.

**`_previousAssignments` change detection**
`OnDeserialization` fires whenever *any* synced variable changes. Diffing against the previous snapshot means only genuinely modified slots trigger `_ActivateSlot` / `_DeactivateSlot`, avoiding redundant work.

**Late-joiner initialisation**
When a late joiner receives their first `OnDeserialization`, `_previousAssignments` is all-zeros, so every occupied slot in `_assignments` is detected as a new assignment and the corresponding pool objects are activated automatically.

**Master handoff race condition**
There is a brief window between the old master leaving and the new master being elected where join/leave events may be dropped. The 2-second deferred `VerifyAssignments` call reconciles the assignment table against the live player list to close this gap.

### Usage Notes

- Set `_poolObjects` in the Inspector before entering Play mode. Pool size equals `_poolObjects.Length`.
- Pool objects should handle their own visual/audio state inside `SetActive`. The manager only toggles `gameObject.SetActive`.
- If your pool objects need the assigned player at enable time, store the player reference via `SetProgramVariable("assignedPlayer", player)` before calling `SetActive(true)`, as shown in `_ActivateSlot`.
- This pattern does not support runtime pool growth. Size the pool to the world's maximum player count.

### Array Helpers

```csharp
public class ArrayHelpers : UdonSharpBehaviour
{
    // Find index in array
    public int FindIndex(GameObject[] array, GameObject target)
    {
        for (int i = 0; i < array.Length; i++)
        {
            if (array[i] == target) return i;
        }
        return -1;
    }

    // Shuffle array (Fisher-Yates)
    public void ShuffleArray(int[] array)
    {
        for (int i = array.Length - 1; i > 0; i--)
        {
            int j = Random.Range(0, i + 1);
            int temp = array[i];
            array[i] = array[j];
            array[j] = temp;
        }
    }

    // Resize array (create new)
    public GameObject[] ResizeArray(GameObject[] original, int newSize)
    {
        GameObject[] newArray = new GameObject[newSize];
        int copyLength = Mathf.Min(original.Length, newSize);
        System.Array.Copy(original, newArray, copyLength);
        return newArray;
    }
}
```

## NetworkCallable Patterns (SDK 3.8.1+)

### Basic Parameterized RPC

```csharp
using UdonSharp;
using UnityEngine;
using VRC.SDKBase;
using VRC.Udon.Common.Interfaces;

[UdonBehaviourSyncMode(BehaviourSyncMode.Manual)]
public class NetworkCallableBasic : UdonSharpBehaviour
{
    public TextMeshProUGUI messageText;

    [NetworkCallable]
    public void ShowMessage(string message, int senderId)
    {
        VRCPlayerApi sender = VRCPlayerApi.GetPlayerById(senderId);
        string senderName = sender != null ? sender.displayName : "Unknown";
        messageText.text = $"{senderName}: {message}";
    }

    public void BroadcastMessage(string message)
    {
        SendCustomNetworkEvent(
            NetworkEventTarget.All,
            nameof(ShowMessage),
            message,
            Networking.LocalPlayer.playerId
        );
    }
}
```

### Damage System with NetworkCallable

```csharp
[UdonBehaviourSyncMode(BehaviourSyncMode.Manual)]
public class DamageReceiver : UdonSharpBehaviour
{
    [UdonSynced] private int health = 100;
    public TextMeshProUGUI healthText;

    [NetworkCallable]
    public void TakeDamage(int damage, Vector3 hitPosition, int attackerId)
    {
        // Only owner processes damage
        if (!Networking.IsOwner(gameObject))
        {
            // Forward to owner
            SendCustomNetworkEvent(
                NetworkEventTarget.Owner,
                nameof(TakeDamage),
                damage, hitPosition, attackerId
            );
            return;
        }

        health -= damage;
        RequestSerialization();

        // Notify all players of hit effect
        SendCustomNetworkEvent(
            NetworkEventTarget.All,
            nameof(ShowHitEffect),
            hitPosition
        );

        if (health <= 0)
        {
            SendCustomNetworkEvent(
                NetworkEventTarget.All,
                nameof(OnDeath)
            );
        }
    }

    [NetworkCallable]
    public void ShowHitEffect(Vector3 position)
    {
        // Spawn particle at hit position
        SpawnHitParticle(position);
    }

    [NetworkCallable]
    public void OnDeath()
    {
        // Play death animation/sound
        Debug.Log("Target destroyed!");
    }

    public override void OnDeserialization()
    {
        healthText.text = $"HP: {health}";
    }
}
```

### Chat System

```csharp
[UdonBehaviourSyncMode(BehaviourSyncMode.None)]
public class ChatSystem : UdonSharpBehaviour
{
    public TextMeshProUGUI chatLog;
    public UnityEngine.UI.InputField inputField;

    private string[] messages = new string[50];
    private int messageIndex = 0;

    [NetworkCallable(10)] // Allow 10 messages/sec
    public void ReceiveMessage(string message, string senderName)
    {
        messages[messageIndex] = $"[{senderName}] {message}";
        messageIndex = (messageIndex + 1) % messages.Length;
        UpdateChatDisplay();
    }

    public void SendMessage()
    {
        string msg = inputField.text;
        if (string.IsNullOrEmpty(msg)) return;

        inputField.text = "";

        SendCustomNetworkEvent(
            NetworkEventTarget.All,
            nameof(ReceiveMessage),
            msg,
            Networking.LocalPlayer.displayName
        );
    }

    private void UpdateChatDisplay()
    {
        System.Text.StringBuilder sb = new System.Text.StringBuilder();
        for (int i = 0; i < messages.Length; i++)
        {
            if (!string.IsNullOrEmpty(messages[i]))
            {
                sb.AppendLine(messages[i]);
            }
        }
        chatLog.text = sb.ToString();
    }
}
```

## Persistence Patterns (SDK 3.7.4+)

### Settings Manager

```csharp
using UdonSharp;
using UnityEngine;
using VRC.SDKBase;
using VRC.SDK3.Persistence;

public class SettingsManager : UdonSharpBehaviour
{
    [Header("UI References")]
    public UnityEngine.UI.Slider volumeSlider;
    public UnityEngine.UI.Toggle musicToggle;
    public UnityEngine.UI.Dropdown qualityDropdown;

    private bool initialized = false;

    public override void OnPlayerRestored(VRCPlayerApi player)
    {
        if (!player.isLocal) return;

        // Load all settings
        if (PlayerData.TryGetFloat(player, "volume", out float vol))
            volumeSlider.value = vol;

        if (PlayerData.TryGetBool(player, "musicEnabled", out bool music))
            musicToggle.isOn = music;

        if (PlayerData.TryGetInt(player, "quality", out int quality))
            qualityDropdown.value = quality;

        initialized = true;
    }

    public void OnVolumeChanged()
    {
        if (!initialized) return;
        PlayerData.SetFloat(Networking.LocalPlayer, "volume", volumeSlider.value);
        ApplyVolume(volumeSlider.value);
    }

    public void OnMusicToggled()
    {
        if (!initialized) return;
        PlayerData.SetBool(Networking.LocalPlayer, "musicEnabled", musicToggle.isOn);
        ApplyMusic(musicToggle.isOn);
    }

    public void OnQualityChanged()
    {
        if (!initialized) return;
        PlayerData.SetInt(Networking.LocalPlayer, "quality", qualityDropdown.value);
        ApplyQuality(qualityDropdown.value);
    }
}
```

### Unlock System

```csharp
public class UnlockSystem : UdonSharpBehaviour
{
    [Header("Unlock Objects")]
    public GameObject[] unlockableObjects;
    public string[] unlockKeys;

    private bool dataReady = false;

    public override void OnPlayerRestored(VRCPlayerApi player)
    {
        if (!player.isLocal) return;
        dataReady = true;

        // Check all unlocks
        for (int i = 0; i < unlockableObjects.Length; i++)
        {
            if (PlayerData.TryGetBool(player, unlockKeys[i], out bool unlocked))
            {
                unlockableObjects[i].SetActive(unlocked);
            }
        }
    }

    public void Unlock(int index)
    {
        if (!dataReady) return;
        if (index < 0 || index >= unlockKeys.Length) return;

        PlayerData.SetBool(Networking.LocalPlayer, unlockKeys[index], true);
        unlockableObjects[index].SetActive(true);

        Debug.Log($"Unlocked: {unlockKeys[index]}");
    }

    public void ResetAllUnlocks()
    {
        if (!dataReady) return;

        for (int i = 0; i < unlockKeys.Length; i++)
        {
            PlayerData.DeleteKey(Networking.LocalPlayer, unlockKeys[i]);
            unlockableObjects[i].SetActive(false);
        }
    }
}
```

## Dynamics Patterns (SDK 3.10.0+)

### Interactive Button

```csharp
public class ContactButton : UdonSharpBehaviour
{
    [Header("Visual Feedback")]
    public Transform buttonTop;
    public Material normalMaterial;
    public Material pressedMaterial;
    public Renderer buttonRenderer;

    [Header("Audio")]
    public AudioSource pressSound;
    public AudioSource releaseSound;

    [Header("Settings")]
    public float pressDepth = 0.02f;
    public float pressSpeed = 10f;
    public float cooldown = 0.5f;

    private bool isPressed = false;
    private float lastPressTime;
    private Vector3 originalPos;
    private Vector3 pressedPos;

    void Start()
    {
        originalPos = buttonTop.localPosition;
        pressedPos = originalPos - new Vector3(0, pressDepth, 0);
    }

    void Update()
    {
        Vector3 target = isPressed ? pressedPos : originalPos;
        buttonTop.localPosition = Vector3.Lerp(
            buttonTop.localPosition, target, Time.deltaTime * pressSpeed);
    }

    public override void OnContactEnter(ContactEnterInfo info)
    {
        if (isPressed) return;
        if (Time.time - lastPressTime < cooldown) return;

        isPressed = true;
        lastPressTime = Time.time;
        buttonRenderer.material = pressedMaterial;
        pressSound.Play();

        OnButtonPressed(info);
    }

    public override void OnContactExit(ContactExitInfo info)
    {
        isPressed = false;
        buttonRenderer.material = normalMaterial;
        releaseSound.Play();
    }

    private void OnButtonPressed(ContactEnterInfo info)
    {
        if (info.isAvatar && info.player != null)
        {
            Debug.Log($"Button pressed by: {info.player.displayName}");
        }
        // Add your button action here
    }
}
```

### Touch Piano

```csharp
public class TouchPiano : UdonSharpBehaviour
{
    public AudioSource[] noteAudioSources;
    public int noteIndex;

    private bool isPlaying = false;

    public override void OnContactEnter(ContactEnterInfo info)
    {
        if (isPlaying) return;
        isPlaying = true;

        if (noteIndex >= 0 && noteIndex < noteAudioSources.Length)
        {
            noteAudioSources[noteIndex].Play();
        }
    }

    public override void OnContactExit(ContactExitInfo info)
    {
        isPlaying = false;

        if (noteIndex >= 0 && noteIndex < noteAudioSources.Length)
        {
            noteAudioSources[noteIndex].Stop();
        }
    }
}
```

### Grabbable Rope (Physics)

```csharp
public class GrabbableRope : UdonSharpBehaviour
{
    [Header("Sync")]
    [UdonSynced] private bool isGrabbed = false;
    [UdonSynced] private int grabberId = -1;

    [Header("Audio")]
    public AudioSource grabSound;
    public AudioSource releaseSound;

    public override void OnPhysBoneGrab(PhysBoneGrabInfo info)
    {
        Networking.SetOwner(info.player, gameObject);
        isGrabbed = true;
        grabberId = info.player.playerId;
        RequestSerialization();

        grabSound.Play();
    }

    public override void OnPhysBoneRelease(PhysBoneReleaseInfo info)
    {
        isGrabbed = false;
        grabberId = -1;
        RequestSerialization();

        releaseSound.Play();
    }

    public bool IsGrabbed() => isGrabbed;

    public VRCPlayerApi GetGrabber()
    {
        if (grabberId < 0) return null;
        return VRCPlayerApi.GetPlayerById(grabberId);
    }
}
```

## Synced Game State Management

### History/Undo Sync Pattern

When implementing undo functionality in a game, **history is shared among all players as synced variables**.
The initial state is saved as history entry 0, and resetting returns to history 0 (no separate variable for initial state).

**Important notes:**
- **1 logical operation = 1 history save** (do not save twice on both sender and receiver)
- Save the state **after** the operation, not before
- History saving is done only within the owner's operation processing method

**Template:** [assets/templates/UndoableGameManager.cs](../assets/templates/UndoableGameManager.cs)

Syncs `currentState` (byte[]), `stateHistory` (flat byte[] of N×stateSize), and `historyCount` as `[UdonSynced]` variables. `OwnerProcessMove` (owner-only `[NetworkCallable]`) applies the move then calls `SaveStateToHistory`. `OwnerUndo` decrements `historyCount` and restores the previous snapshot. `OwnerReset` resets to `stateHistory[0]`. `OnDeserialization` only calls `UpdateDisplay` — never saves to history.

**Common mistakes:**

| Mistake | Problem | Correct approach |
|--------|------|-----------|
| Saving history in OnDeserialization | Double-saving on sender + receiver | Save only in owner's operation method |
| Managing initial state in a separate variable | Inconsistency on reset | history[0] = initial state |
| Saving state before the operation | Undo goes back 2 steps instead of 1 | Save state after the operation |
| Not making history synced | Undo results differ between players | Share history as synced variables |

## Delayed Event Debounce

### Problem

`SendCustomEventDelayedSeconds` schedules a future event, but there is no cancellation API. If the same event is scheduled multiple times in quick succession (e.g., a rapid button tap), all enqueued callbacks fire.

### Solution

Use an integer generation counter. Each new schedule increments the counter and captures the current value. The callback checks whether the counter has advanced; if so, a newer schedule exists and this invocation is a no-op.

```csharp
public class DebouncedSearch : UdonSharpBehaviour
{
    [SerializeField] private float debounceDelay = 0.5f;

    // Monotonically increasing; each new schedule captures the current value.
    private int _scheduleGeneration = 0;

    /// <summary>
    /// Call this whenever input changes. Only the callback scheduled after the
    /// last call within debounceDelay seconds will actually execute.
    /// </summary>
    public void OnInputChanged()
    {
        _scheduleGeneration++;
        // Pass the current generation as a serialized field so the callback can read it.
        // UdonSharp does not support lambda captures, so store in a member variable.
        _pendingGeneration = _scheduleGeneration;
        SendCustomEventDelayedSeconds(nameof(ExecuteSearch), debounceDelay);
    }

    // Captured generation for the most recently scheduled callback.
    private int _pendingGeneration = 0;

    public void ExecuteSearch()
    {
        // If _scheduleGeneration has moved past _pendingGeneration, a newer
        // schedule supersedes this one — bail out.
        if (_scheduleGeneration != _pendingGeneration) return;

        // Safe to execute: this is the most recent scheduled callback.
        PerformSearch();
    }

    private void PerformSearch()
    {
        Debug.Log("Executing debounced search");
        // ... actual search logic
    }
}
```

> **Note:** This pattern ensures only the *last* scheduled event executes. It does not prevent intermediate callbacks from running their guard check — it only makes them return immediately.

---


## See Also

- [patterns-core.md](patterns-core.md) - Initialization, interaction, timer, audio, pickup, animation, UI
- [patterns-performance.md](patterns-performance.md) - Partial class, update handler, PostLateUpdate, spatial query
- [patterns-utilities.md](patterns-utilities.md) - Array helpers, event bus, relay communication
- [networking.md](networking.md) - Sync modes, ownership, bandwidth throttling, anti-patterns
- [persistence.md](persistence.md) - PlayerData/PlayerObject full reference (SDK 3.7.4+)
- [dynamics.md](dynamics.md) - PhysBones, Contacts, VRC Constraints full reference (SDK 3.10.0+)
