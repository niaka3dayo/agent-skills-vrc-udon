namespace General.ValidEvents;

public class LocalEventBase
{
    public virtual void OnPlayerJoined(int slotIndex) { }
}

public class LocalEventConsumer : LocalEventBase
{
    public override void OnPlayerJoined(int slotIndex) { }
    public void Update(int tick) { }
}
