public class InvalidNetworkCallableReturn
{
    [NetworkCallable(1)]
    public int _InvalidReturn(int value) => value;
}
