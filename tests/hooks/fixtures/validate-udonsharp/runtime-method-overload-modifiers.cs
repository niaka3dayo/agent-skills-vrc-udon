using UdonSharp;

public class RuntimeMethodOverloadModifiers : UdonSharpBehaviour
{
    void Plain(int value) { }
    void Plain(float value) { }

    protected internal virtual void Layered(int value) { }
    protected internal virtual void Layered(float value) { }

    private new void Hidden(int value) { }
    private new void Hidden(float value) { }

    public sealed override void SealedLayer(int value) { }
    public sealed override void SealedLayer(float value) { }
}
