using UdonSharp;
using UnityEngine;
using VRC.SDKBase;

/// <summary>
/// Demonstrates packing three independent game-state values into one Vector3
/// synced variable, reducing per-variable overhead.
///
/// Each [UdonSynced] variable consumes sync budget independently. A behaviour
/// with many small values wastes budget on per-variable overhead.
///
/// Key constraints:
/// - float has 24-bit mantissa precision — integers up to 16,777,216 round-trip
///   exactly through Vector3.
/// - Use Mathf.RoundToInt on unpack to absorb any floating-point noise.
/// - Do not use this technique for values that need interpolation; use separate
///   synced floats for those.
/// </summary>
[UdonBehaviourSyncMode(BehaviourSyncMode.Manual)]
public class PackedStateSync : UdonSharpBehaviour
{
    // --- Three logically independent state values ---
    private int _questionIndex; // 0-255 range is safe as a float mantissa value
    private int _gameType;      // small enum (0-15)
    private int _category;      // small enum (0-31)

    /// <summary>Single synced variable carries all three values.</summary>
    [UdonSynced] private Vector3 _packedState;

    // -----------------------------------------------
    // Packing: owner writes local values into Vector3
    // -----------------------------------------------

    private void PackState()
    {
        // Each component holds one value; cast to float is exact for small integers
        _packedState = new Vector3(_questionIndex, _gameType, _category);
    }

    // -----------------------------------------------
    // Unpacking: non-owners read from Vector3
    // -----------------------------------------------

    private void UnpackState()
    {
        _questionIndex = Mathf.RoundToInt(_packedState.x);
        _gameType      = Mathf.RoundToInt(_packedState.y);
        _category      = Mathf.RoundToInt(_packedState.z);
    }

    // -----------------------------------------------
    // Serialization hooks
    // -----------------------------------------------

    public override void OnPreSerialization()
    {
        PackState();
    }

    public override void OnDeserialization()
    {
        UnpackState();
        ApplyStateLocally();
    }

    // -----------------------------------------------
    // Public API — owner calls these to change state
    // -----------------------------------------------

    public void SetQuestion(int index, int gameType, int category)
    {
        if (!Networking.IsOwner(gameObject)) return;

        _questionIndex = index;
        _gameType      = gameType;
        _category      = category;
        RequestSerialization();
    }

    private void ApplyStateLocally()
    {
        // React to the newly unpacked values (update UI, enable objects, etc.)
        Debug.Log($"[PackedStateSync] Q={_questionIndex} Type={_gameType} Cat={_category}");
    }
}
