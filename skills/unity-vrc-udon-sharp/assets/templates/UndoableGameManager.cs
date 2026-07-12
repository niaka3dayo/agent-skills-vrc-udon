using UdonSharp;
using UnityEngine;
using VRC.SDKBase;
using VRC.SDK3.UdonNetworkCalling;
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
        _InitializeGame();
        _SaveStateToHistory(); // Initial state = history[0]
    }

    // --- Local request entry ---
    // The underscore prevents legacy SendCustomNetworkEvent calls. This method
    // is intentionally not [NetworkCallable].
    public void _RequestMove(int from, int to)
    {
        SendCustomNetworkEvent(
            NetworkEventTarget.Owner,
            nameof(_OwnerProcessMove),
            from,
            to
        );
    }

    // --- Owner only: process operations ---
    [NetworkCallable]
    public void _OwnerProcessMove(int from, int to)
    {
        if (!_IsAuthorizedNetworkCaller()) return;

        // Ownership authorizes where synced mutation happens. Caller
        // authorization is handled separately above.
        if (!Networking.IsOwner(gameObject)) return;
        if (!_IsValidMove(from, to)) return;

        _ExecuteMove(from, to);
        _SaveStateToHistory(); // Save once after the operation
        RequestSerialization();
    }

    // --- History management ---
    private void _SaveStateToHistory()
    {
        int offset = historyCount * stateSize;
        System.Array.Copy(currentState, 0, stateHistory, offset, stateSize);
        historyCount++;
    }

    public void _OnUndoClicked()
    {
        SendCustomNetworkEvent(NetworkEventTarget.Owner, nameof(_OwnerUndo));
    }

    [NetworkCallable]
    public void _OwnerUndo()
    {
        if (!_IsAuthorizedNetworkCaller()) return;
        if (!Networking.IsOwner(gameObject)) return;
        if (historyCount <= 1) return; // Cannot go before initial state
        historyCount--;
        int offset = (historyCount - 1) * stateSize;
        System.Array.Copy(stateHistory, offset, currentState, 0, stateSize);
        RequestSerialization();
    }

    public void _OnResetClicked()
    {
        SendCustomNetworkEvent(NetworkEventTarget.Owner, nameof(_OwnerReset));
    }

    [NetworkCallable]
    public void _OwnerReset()
    {
        if (!_IsAuthorizedNetworkCaller()) return;
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
        _UpdateDisplay();
    }

    // Example session policy: only the current instance master may mutate the
    // shared history. Replace this with the policy appropriate to your game.
    private bool _IsAuthorizedNetworkCaller()
    {
        if (!NetworkCalling.InNetworkCall) return false;

        VRCPlayerApi caller = NetworkCalling.CallingPlayer;
        if (caller == null || !caller.IsValid()) return false;

        return caller.isMaster;
    }

    // =========================================================================
    // Override these methods for your specific game logic
    // =========================================================================

    private void _InitializeGame()
    {
        // Initialize currentState to the starting game state
        // Example: fill with zeros or a specific starting arrangement
        for (int i = 0; i < currentState.Length; i++)
        {
            currentState[i] = 0;
        }
    }

    private bool _IsValidMove(int from, int to)
    {
        return from >= 0 && from < currentState.Length &&
               to >= 0 && to < currentState.Length;
    }

    private void _ExecuteMove(int from, int to)
    {
        // Apply the move to currentState
        // Example: move an element from index 'from' to index 'to'
        byte temp = currentState[from];
        currentState[from] = currentState[to];
        currentState[to] = temp;
    }

    private void _UpdateDisplay()
    {
        // Reflect currentState in UI/visuals
        // Override this method to update your specific game's display
        Debug.Log($"[UndoableGameManager] State updated, history count: {historyCount}");
    }
}
