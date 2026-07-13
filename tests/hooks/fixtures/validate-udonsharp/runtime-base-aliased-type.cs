using BehaviourAlias = global::UdonSharp.UdonSharpBehaviour;

public class RuntimeAliasedTypeBase : BehaviourAlias
{
    private void Run()
    {
        Example.Values.Where(value => value > 0);
    }
}
