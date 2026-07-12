public class PublicDeclarations
{
    public PublicDeclarations() { }
    public int Field;
    public int Property { get; set; }
    public int this[int index] => index;
    public event System.Action Changed;
    public delegate void Handler(int value);
    public class Nested { }
    public enum Mode { One }
    public static PublicDeclarations operator +(PublicDeclarations left, PublicDeclarations right) => left;
    public static implicit operator int(PublicDeclarations value) => value.Field;
    public int Parameterized(int value) => value;
}
