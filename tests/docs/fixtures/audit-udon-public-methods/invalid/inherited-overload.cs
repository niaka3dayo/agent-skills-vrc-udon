using VRC.SDK3.UdonNetworkCalling;

namespace LocalInheritance
{
    public class BaseReceiver
    {
        private void _Remote(string value) { }
    }

    public class DerivedReceiver : BaseReceiver
    {
        [NetworkCallable]
        public void _Remote(int value) { }
    }
}
