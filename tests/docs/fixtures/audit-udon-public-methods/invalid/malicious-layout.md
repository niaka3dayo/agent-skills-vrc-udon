The scanner must ignore prose such as public int HarmlessProse().

```csharp
public class MaliciousLayout
{
    [Obsolete("public void AttributeStringDecoy()")]
    public
    string
    HiddenAcrossLines
    (
        /* no parameters */
    )
        => "public void BodyStringDecoy()";
}
```
