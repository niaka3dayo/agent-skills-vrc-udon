using UdonSharp;

public class RuntimeMethodOverloadModifiers : UdonSharpBehaviour
{
    void Plain(int value) { }
    void Plain(float value) { }

    protected internal virtual void Layered(int value) { }
    protected internal virtual void Layered(float value) { }
}
