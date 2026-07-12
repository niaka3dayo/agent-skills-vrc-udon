#Requires -Version 5.1

$ErrorActionPreference = "Stop"

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "../..")).Path
$Hook = Join-Path $RepoRoot "skills/unity-vrc-udon-sharp/hooks/validate-udonsharp.ps1"
$TempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("validate-udonsharp-" + [guid]::NewGuid())
$SyncBloatWarning = 'Synced int[]/float[] detected'
$Passed = 0
$Failed = 0

New-Item -ItemType Directory -Path $TempRoot | Out-Null

function Invoke-Hook([string]$Source) {
    $FilePath = Join-Path $TempRoot (([guid]::NewGuid().ToString()) + ".cs")
    Set-Content -Path $FilePath -Value $Source
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
        @{ Label = 'same-line int[]'; Declaration = '[UdonSynced] private int[] values;' },
        @{ Label = 'preceding-line int[]'; Declaration = "[UdonSynced]`n    private int[] values;" },
        @{ Label = 'same-line float[]'; Declaration = '[UdonSynced] private float[] values;' },
        @{ Label = 'preceding-line float[]'; Declaration = "[UdonSynced]`n    private float[] values;" }
    )

    foreach ($Case in $Cases) {
        $Source = "using UdonSharp;`npublic class Sample : UdonSharpBehaviour`n{`n    $($Case.Declaration)`n}"
        Assert-Contains $Case.Label (Invoke-Hook $Source) $SyncBloatWarning
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

    Write-Output ""
    Write-Output "Summary: $Passed passed, $Failed failed"
    if ($Failed -ne 0) {
        exit 1
    }
} finally {
    Remove-Item -Path $TempRoot -Recurse -Force
}
