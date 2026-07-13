using UdonSharp;
using UnityEngine;

public class ConstructorReturnDecoys : UdonSharpBehaviour
{
    private Vector3 First()
    {
        return new Vector3(1f, 2f, 3f);
    }

    private Vector3 Second()
    {
        return new Vector3(4f, 5f, 6f);
    }
}
