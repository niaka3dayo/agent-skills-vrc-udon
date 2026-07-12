using UdonSharp;
using VRC.SDK3.UdonNetworkCalling;

public class ValidDeclarations : UdonSharpBehaviour
{
    public ValidDeclarations() { }

    public static int StaticValue() => 1;

    static public int ReorderedStaticValue() => 2;

    public void Update() { }

    public override void OnDeserialization() { }

    [NetworkCallable(1)]
    public void _RemoteAction(int value) { }

    public int _AttributeStateDoesNotBleed() => 3;

    public int _LocalValue() => 1;

    private string text = "public void StringDecoy() { }";
    private string interpolated = $"public int InterpolatedDecoy() => {StaticValue()};";
    private string verbatim = @"public bool VerbatimDecoy() { return true; }";
    private string raw = """
        public void RawStringDecoy() { }
        """;
    private char brace = '}';

    // public void LineCommentDecoy() { }
    /* public bool BlockCommentDecoy() => true; */
}
