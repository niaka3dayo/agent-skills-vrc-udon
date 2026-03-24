using UdonSharp;
using UnityEngine;
using VRC.SDKBase;
using VRC.Udon.Common.Interfaces;

/// <summary>
/// History/Undo sync pattern for multiplayer games.
///
/// History is shared among all players as synced variables.
/// The initial state is saved as history entry 0; resetting returns to history[0]
/// (no separate variable for initial state).
///
/// Rules:
/// - 1 logical operation = 1 history save (do not save twice on sender and receiver)
/// - Save the state AFTER the operation, not before
/// - History saving is done only within the owner's operation processing method
/// - Do NOT add to history in OnDeserialization (causes double-saving)
/// </summary>
[UdonBehaviourSyncMode(BehaviourSyncMode.Manual)]
public class UndoableGameManager : UdonSharpBehaviour
{
    // --- Synced data ---
    [UdonSynced] private byte[] currentState;     // Current game state
    [UdonSynced] private byte[] stateHistory;     // All history (flat array)
    [UdonSynced] private int historyCount;        // Number of saved history entries
    private int stateSize;                        // Size per state

    void Start()
    {
        stateSize = 40; // Example: 40 elements. Adjust to your game's state size.
        currentState = new byte[stateSize];
        stateHistory = new byte[stateSize * 100]; // Max 100 moves
        InitializeGame();
        SaveStateToHistory(); // Initial state = history[0]
    }

    // --- Owner only: process operations ---
    [NetworkCallable]
    public void OwnerProcessMove(int from, int to, int playerId)
    {
        // Validation: check ownership, game phase, turn, etc.
        if (!Networking.IsOwner(gameObject)) return;

        ExecuteMove(from, to);
        SaveStateToHistory(); // Save once after the operation
        RequestSerialization();
    }

    // --- History management ---
    private void SaveStateToHistory()
    {
        int offset = historyCount * stateSize;
        System.Array.Copy(currentState, 0, stateHistory, offset, stateSize);
        historyCount++;
    }

    public void OnUndoClicked()
    {
        SendCustomNetworkEvent(NetworkEventTarget.Owner, nameof(OwnerUndo));
    }

    [NetworkCallable]
    public void OwnerUndo()
    {
        if (!Networking.IsOwner(gameObject)) return;
        if (historyCount <= 1) return; // Cannot go before initial state
        historyCount--;
        int offset = (historyCount - 1) * stateSize;
        System.Array.Copy(stateHistory, offset, currentState, 0, stateSize);
        RequestSerialization();
    }

    public void OnResetClicked()
    {
        SendCustomNetworkEvent(NetworkEventTarget.Owner, nameof(OwnerReset));
    }

    [NetworkCallable]
    public void OwnerReset()
    {
        if (!Networking.IsOwner(gameObject)) return;
        // Return to history[0] = initial state (no separate variable for initial state)
        System.Array.Copy(stateHistory, 0, currentState, 0, stateSize);
        historyCount = 1;
        RequestSerialization();
    }

    // --- All clients: update display ---
    public override void OnDeserialization()
    {
        // Do NOT add to history in OnDeserialization! (causes double-saving)
        UpdateDisplay();
    }

    // =========================================================================
    // Override these methods for your specific game logic
    // =========================================================================

    private void InitializeGame()
    {
        // Initialize currentState to the starting game state
        // Example: fill with zeros or a specific starting arrangement
        for (int i = 0; i < currentState.Length; i++)
        {
            currentState[i] = 0;
        }
    }

    private void ExecuteMove(int from, int to)
    {
        // Apply the move to currentState
        // Example: move an element from index 'from' to index 'to'
        if (from >= 0 && from < currentState.Length &&
            to >= 0 && to < currentState.Length)
        {
            byte temp = currentState[from];
            currentState[from] = currentState[to];
            currentState[to] = temp;
        }
    }

    private void UpdateDisplay()
    {
        // Reflect currentState in UI/visuals
        // Override this method to update your specific game's display
        Debug.Log($"[UndoableGameManager] State updated, history count: {historyCount}");
    }
}
