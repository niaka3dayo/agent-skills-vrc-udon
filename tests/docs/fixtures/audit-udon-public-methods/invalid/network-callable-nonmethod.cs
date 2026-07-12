using VRC.SDK3.UdonNetworkCalling;

public class NetworkCallableNonMethod
{
    [NetworkCallable]
    public static NetworkCallableNonMethod operator +(
        NetworkCallableNonMethod left,
        NetworkCallableNonMethod right) => left;
}
