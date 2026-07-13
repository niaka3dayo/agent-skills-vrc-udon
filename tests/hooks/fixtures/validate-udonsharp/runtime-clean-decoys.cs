using UdonSharp;

public class RuntimeCleanDecoys : UdonSharpBehaviour
{
    private string regular = "escaped quote: \" [UdonSynced] RequestSerialization() Networking.SetOwner() NoVariableSync";
    private string verbatim = @"escaped quote: "" [UdonSynced] RequestSerialization() Networking.SetOwner() NoVariableSync";
    private string interpolated = $"sync decoys: {[UdonSynced]} RequestSerialization() Networking.SetOwner() NoVariableSync";
    private string interpolatedVerbatimA = $@"sync decoys: "" [UdonSynced] RequestSerialization() Networking.SetOwner() NoVariableSync";
    private string interpolatedVerbatimB = @$"sync decoys: "" [UdonSynced] RequestSerialization() Networking.SetOwner() NoVariableSync";
    private string raw = """sync decoys: " [UdonSynced] RequestSerialization() Networking.SetOwner() NoVariableSync""";
    private string longRaw = """"sync decoys: """ [UdonSynced] RequestSerialization() Networking.SetOwner() NoVariableSync"""";
    private string interpolatedRaw = $$"""sync decoys: {{[UdonSynced]}} RequestSerialization() Networking.SetOwner() NoVariableSync""";
    private char escapedQuote = '\'';
    private char escapedSlash = '\\';

    // [UdonSynced] RequestSerialization() Networking.SetOwner() NoVariableSync
    /*
       [UdonSynced]
       RequestSerialization()
       Networking.SetOwner()
       NoVariableSync
    */
}
