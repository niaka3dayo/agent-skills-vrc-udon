using UdonSharp;
using UnityEngine;

/// <summary>
/// Array utility helpers for UdonSharp.
///
/// UdonSharp does not support List&lt;T&gt;. These static-style helpers use
/// System.Array.Copy to provide list-like operations on plain arrays.
/// Each operation returns a new array; the original is never modified.
///
/// Performance warning: Every call allocates a new array and copies elements.
/// Do not call these in Update() or any hot path. Prefer pre-sized arrays with
/// a manual count variable for high-frequency code.
///
/// Note: UdonSharp does not support generic methods, so one copy per type is
/// required. This file provides GameObject variants as a starting point.
/// Duplicate signatures for UdonSharpBehaviour[], int[], etc. as needed.
/// </summary>
public class ArrayUtils : UdonSharpBehaviour
{
    // =========================================================================
    // GameObject variants
    // =========================================================================

    /// <summary>Append one element, return a new array one element longer.</summary>
    public GameObject[] AddGameObject(GameObject[] source, GameObject item)
    {
        GameObject[] result = new GameObject[source.Length + 1];
        System.Array.Copy(source, result, source.Length);
        result[source.Length] = item;
        return result;
    }

    /// <summary>Return true when the element is present.</summary>
    public bool ContainsGameObject(GameObject[] source, GameObject item)
    {
        for (int i = 0; i < source.Length; i++)
        {
            if (source[i] == item) return true;
        }
        return false;
    }

    /// <summary>Append only when the element is not already present.</summary>
    public GameObject[] AddUniqueGameObject(GameObject[] source, GameObject item)
    {
        if (ContainsGameObject(source, item)) return source;
        return AddGameObject(source, item);
    }

    /// <summary>
    /// Remove first occurrence, return a new array one element shorter.
    /// Returns the original array unchanged when the element is not found.
    /// </summary>
    public GameObject[] RemoveGameObject(GameObject[] source, GameObject item)
    {
        int removeIndex = -1;
        for (int i = 0; i < source.Length; i++)
        {
            if (source[i] == item)
            {
                removeIndex = i;
                break;
            }
        }
        if (removeIndex < 0) return source;
        return RemoveAtGameObject(source, removeIndex);
    }

    /// <summary>Remove the element at a given index.</summary>
    public GameObject[] RemoveAtGameObject(GameObject[] source, int index)
    {
        if (index < 0 || index >= source.Length) return source;
        GameObject[] result = new GameObject[source.Length - 1];
        System.Array.Copy(source, 0, result, 0, index);
        System.Array.Copy(source, index + 1, result, index, source.Length - index - 1);
        return result;
    }

    /// <summary>Insert an element before the given index.</summary>
    public GameObject[] InsertGameObject(GameObject[] source, int index, GameObject item)
    {
        if (index < 0) index = 0;
        if (index > source.Length) index = source.Length;
        GameObject[] result = new GameObject[source.Length + 1];
        System.Array.Copy(source, 0, result, 0, index);
        result[index] = item;
        System.Array.Copy(source, index, result, index + 1, source.Length - index);
        return result;
    }

    // =========================================================================
    // int variants
    // =========================================================================

    /// <summary>Find index in int array, returns -1 if not found.</summary>
    public int FindIndexInt(int[] array, int target)
    {
        for (int i = 0; i < array.Length; i++)
        {
            if (array[i] == target) return i;
        }
        return -1;
    }

    /// <summary>Shuffle int array in place (Fisher-Yates).</summary>
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

    /// <summary>Resize array by creating a new array and copying elements.</summary>
    public GameObject[] ResizeArray(GameObject[] original, int newSize)
    {
        GameObject[] newArray = new GameObject[newSize];
        int copyLength = Mathf.Min(original.Length, newSize);
        System.Array.Copy(original, newArray, copyLength);
        return newArray;
    }
}
