using VRC.SDK3.UdonNetworkCalling;

public class PublicOverload
{
    [NetworkCallable]
    public void _Remote(int value) { }

    public void _Remote(string value) { }
}
