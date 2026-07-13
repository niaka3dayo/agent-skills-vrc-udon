using UdonSharp;

public class RuntimeGeneralDecoys : UdonSharpBehaviour
{
    private string regular = "List<int> async await try { catch ( System.IO. StartCoroutine( AddListener( value => value";
    private string verbatim = @"interface IExample { yield return value; GetComponent<UdonBehaviour>(); }";
    private string interpolated = $"VRCPlayerApi player = source; {Format("[UdonSynced] NoVariableSync ref out int[,] Overload(")}";
    private string raw = """List<int> async await System.Net StartCoroutine( value => value""";
    private string allRuleDecoys = """
        [UdonBehaviourSyncMode(BehaviourSyncMode.NoVariableSync)]
        public class Decoy : UdonSharpBehaviour
        {
            [UdonSynced] private int[] first;
            [UdonSynced] private int second;
            [UdonSynced] private int third;
            [UdonSynced] private int fourth;
            [UdonSynced] private int fifth;
            [UdonSynced] private int sixth;
            private List<int> values;
            private async void Run()
            {
                try { StartCoroutine(null); } catch (System.Exception) { }
                values.Where(value => value > 0);
                button.onClick.AddListener(HandleClick);
                VRCPlayerApi player = source;
                yield return null;
            }
            public interface IDecoy { }
            public override void OnTriggerEnter(Collider other) { }
            private UdonBehaviour Find() => GetComponent<UdonBehaviour>();
            private System.IO.Stream stream;
            private void RefValue(ref int value) { }
            private void OutValue(out int value) { value = 0; }
            private int[,] matrix;
            private void Duplicate(int value) { }
            private void Duplicate(float value) { }
        }
        """;

    // private List<int> commentsDoNotCount;
    /* [UdonSynced] private int[] values; */

    private string Format(string value)
    {
        return value;
    }
}
