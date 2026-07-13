public class AttributeBleedExample
{
    [NetworkCallable(1)]
    public void _BoundToThisMethod(int value) { }

    public void AttributeBleed() { }
}
