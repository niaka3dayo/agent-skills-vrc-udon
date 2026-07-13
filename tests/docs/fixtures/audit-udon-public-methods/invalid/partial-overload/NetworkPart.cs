using VRC.SDK3.UdonNetworkCalling;

namespace SharedPartial
{
    public partial class PartialReceiver
    {
        [NetworkCallable]
        public void _Remote(int value) { }
    }
}
