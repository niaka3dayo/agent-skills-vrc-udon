#Requires -Version 5.1

$ErrorActionPreference = "Stop"

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "../..")).Path
$Hook = Join-Path $RepoRoot "skills/unity-vrc-udon-sharp/hooks/validate-udonsharp.ps1"
$TempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("validate-udonsharp-" + [guid]::NewGuid())
$SyncBloatWarning = 'Synced int[]/float[] detected'
$Passed = 0
$Failed = 0

New-Item -ItemType Directory -Path $TempRoot | Out-Null

function Invoke-Hook([string]$Source, [string]$LeafName = $null) {
    if (-not $LeafName) {
        $LeafName = ([guid]::NewGuid().ToString()) + ".cs"
    }
    $FilePath = Join-Path $TempRoot $LeafName
    Set-Content -LiteralPath $FilePath -Value $Source
    $Payload = @{ tool_input = @{ file_path = $FilePath } } | ConvertTo-Json -Compress
    return $Payload | & $Hook 2>&1 | Out-String
}

function Assert-Contains([string]$Label, [string]$Actual, [string]$Expected) {
    if ($Actual.Contains($Expected)) {
        Write-Output "PASS [$Label] contains: $Expected"
        $script:Passed++
    } else {
        Write-Output "FAIL [$Label] missing: $Expected"
        $script:Failed++
    }
}

function Assert-NotContains([string]$Label, [string]$Actual, [string]$Unexpected) {
    if ($Actual.Contains($Unexpected)) {
        Write-Output "FAIL [$Label] unexpected: $Unexpected"
        $script:Failed++
    } else {
        Write-Output "PASS [$Label] does not contain: $Unexpected"
        $script:Passed++
    }
}

try {
    $Cases = @(
        @{ Label = 'same-line int[]'; Declaration = '[UdonSynced] private int[] values;'; NewLine = "`n" },
        @{ Label = 'preceding-line int[]'; Declaration = "[UdonSynced]`n    private int[] values;"; NewLine = "`n" },
        @{ Label = 'same-line float[]'; Declaration = '[UdonSynced] private float[] values;'; NewLine = "`n" },
        @{ Label = 'preceding-line float[]'; Declaration = "[UdonSynced]`n    private float[] values;"; NewLine = "`n" },
        @{ Label = 'CRLF same-line declaration'; Declaration = '[UdonSynced] private int[] values;'; NewLine = "`r`n" },
        @{ Label = 'CRLF preceding-line declaration'; Declaration = "[UdonSynced]`r`n    private float[] values;"; NewLine = "`r`n" },
        @{ Label = 'multiline initializer'; Declaration = "[UdonSynced] private int[] values =`n        new int[]`n        {`n            1,`n            2`n        };"; NewLine = "`n" },
        @{ Label = 'attribute with trailing line comment'; Declaration = "[UdonSynced] // Applies to the immediately following physical line.`n    private float[] values;"; NewLine = "`n" },
        @{ Label = 'multiple declarators'; Declaration = '[UdonSynced] private int[] values, previousValues;'; NewLine = "`n" },
        @{ Label = 'combined attributes on same line'; Declaration = '[UdonSynced, FieldChangeCallback(nameof(Values))] private int[] values;'; NewLine = "`n" },
        @{ Label = 'combined attributes on preceding line'; Declaration = "[UdonSynced, FieldChangeCallback(nameof(Values))]`n    private float[] values;"; NewLine = "`n" },
        @{ Label = 'chained attributes on same line'; Declaration = '[UdonSynced][FieldChangeCallback(nameof(Values))] private float[] values;'; NewLine = "`n" },
        @{ Label = 'chained attributes on preceding line'; Declaration = "[UdonSynced][FieldChangeCallback(nameof(Values))]`n    private int[] values;"; NewLine = "`n" },
        @{ Label = 'array type inside combined attribute group'; Declaration = '[UdonSynced, Example(typeof(int[]))] private float[] values;'; NewLine = "`n" },
        @{ Label = 'literal bracket path'; Declaration = '[UdonSynced] private int[] values;'; NewLine = "`n"; LeafName = 'Bracket[1].cs' }
    )

    foreach ($Case in $Cases) {
        $Source = "using UdonSharp;$($Case.NewLine)public class Sample : UdonSharpBehaviour$($Case.NewLine){$($Case.NewLine)    $($Case.Declaration)$($Case.NewLine)}"
        Assert-Contains $Case.Label (Invoke-Hook $Source $Case.LeafName) $SyncBloatWarning
    }

    $UnsyncedSource = @'
using UdonSharp;
public class Sample : UdonSharpBehaviour
{
    [UdonSynced] private byte[] compactValues;
    private int[] integerValues;
    private float[] floatValues;
}
'@
    Assert-NotContains 'unsynced int[]/float[]' (Invoke-Hook $UnsyncedSource) $SyncBloatWarning

    $UnrelatedAttributeSource = @'
using UdonSharp;
public class Sample : UdonSharpBehaviour
{
    [FieldChangeCallback(nameof(Values))]
    private int[] values;
}
'@
    Assert-NotContains 'FieldChangeCallback-only field' (Invoke-Hook $UnrelatedAttributeSource) $SyncBloatWarning

    $CommentedSameLineSource = @'
using UdonSharp;
public class Sample : UdonSharpBehaviour
{
    /*
    [UdonSynced] private int[] values;
    */
}
'@
    Assert-NotContains 'same-line declaration in block comment' (Invoke-Hook $CommentedSameLineSource) $SyncBloatWarning

    $CommentedPrecedingLineSource = @'
using UdonSharp;
public class Sample : UdonSharpBehaviour
{
    /*
    [UdonSynced]
    private float[] values;
    */
}
'@
    Assert-NotContains 'preceding-line declaration in block comment' (Invoke-Hook $CommentedPrecedingLineSource) $SyncBloatWarning

    $SeparatedAttributeSource = @'
using UdonSharp;
public class Sample : UdonSharpBehaviour
{
    [UdonSynced] // The blank line consumes the attribute association.

    private int[] values;
}
'@
    Assert-NotContains 'attribute does not skip a physical line' (Invoke-Hook $SeparatedAttributeSource) $SyncBloatWarning

    Write-Output ""
    Write-Output "Summary: $Passed passed, $Failed failed"
    if ($Failed -ne 0) {
        exit 1
    }
} finally {
    Remove-Item -Path $TempRoot -Recurse -Force
}
