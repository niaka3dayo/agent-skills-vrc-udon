#Requires -Version 5.1

$ErrorActionPreference = "Stop"

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "../..")).Path
$Hook = Join-Path $RepoRoot "skills/unity-vrc-udon-sharp/hooks/validate-udonsharp.ps1"
$SharedFixtures = Join-Path $RepoRoot "tests/hooks/fixtures/validate-udonsharp"
$SharedRules = Join-Path $SharedFixtures "rules.tsv"
$SharedCases = Join-Path $SharedFixtures "cases.tsv"
$TemplateCases = Join-Path $SharedFixtures "template-cases.tsv"
$TemplateRoot = Join-Path $RepoRoot "skills/unity-vrc-udon-sharp/assets/templates"
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

function Invoke-HookProcess([string]$Payload) {
    $PowerShellPath = (Get-Process -Id $PID).Path
    $StartInfo = New-Object System.Diagnostics.ProcessStartInfo
    $StartInfo.FileName = $PowerShellPath
    $StartInfo.Arguments = '-NoLogo -NoProfile -File "' + $Hook + '"'
    $StartInfo.UseShellExecute = $false
    $StartInfo.CreateNoWindow = $true
    $StartInfo.RedirectStandardInput = $true
    $StartInfo.RedirectStandardOutput = $true
    $StartInfo.RedirectStandardError = $true

    $Process = New-Object System.Diagnostics.Process
    $Process.StartInfo = $StartInfo
    [void]$Process.Start()
    $Process.StandardInput.Write($Payload)
    $Process.StandardInput.Close()
    $Stdout = $Process.StandardOutput.ReadToEnd()
    $Stderr = $Process.StandardError.ReadToEnd()
    $Process.WaitForExit()

    return [pscustomobject]@{
        ExitCode = $Process.ExitCode
        Stdout = $Stdout
        Stderr = $Stderr
    }
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

function Invoke-SharedParityMatrix {
    $ExpectedInventory = 'GENERIC;ASYNC;TRY_CATCH;LINQ;YIELD_RETURN;INTERFACE;START_COROUTINE;ADD_LISTENER;LAMBDA;SYNC_NO_SERIALIZE;SYNC_NO_OWNER;PLAYER_VALIDITY;UNITY_CALLBACK_OVERRIDE;GETCOMPONENT_UDON;SYSTEM_IO_NET;SYNC_COUNT;SYNC_ARRAY;SYNC_MODE_CONFLICT;REF_PARAMETER;OUT_PARAMETER;MULTIDIM_ARRAY;METHOD_OVERLOAD'
    $RuleIds = New-Object System.Collections.Generic.List[string]
    $RuleSubstrings = New-Object System.Collections.Generic.List[string]
    $SeenRuleIds = New-Object 'System.Collections.Generic.HashSet[string]'
    $SeenRuleSubstrings = New-Object 'System.Collections.Generic.HashSet[string]'

    foreach ($Line in Get-Content -LiteralPath $SharedRules) {
        $Columns = $Line.Split("`t")
        if ($Columns.Count -ne 2 -or -not $Columns[0] -or -not $Columns[1]) {
            Write-Output "FAIL [shared rules] malformed rules.tsv row: $Line"
            $script:Failed++
            return
        }
        $RuleId = $Columns[0]
        $Substring = $Columns[1]
        if ($RuleId -notmatch '^[A-Z][A-Z0-9_]*$' -or -not $SeenRuleIds.Add($RuleId)) {
            Write-Output "FAIL [shared rules] unknown or duplicate rule ID: $RuleId"
            $script:Failed++
            return
        }
        if (-not $SeenRuleSubstrings.Add($Substring)) {
            Write-Output "FAIL [shared rules] duplicate warning substring: $Substring"
            $script:Failed++
            return
        }
        $RuleIds.Add($RuleId)
        $RuleSubstrings.Add($Substring)
    }

    $ActualInventory = $RuleIds -join ';'
    if ($ActualInventory -ne $ExpectedInventory) {
        Write-Output 'FAIL [shared rules] 22-rule inventory mismatch'
        Write-Output "  expected: $ExpectedInventory"
        Write-Output "  actual:   $ActualInventory"
        $script:Failed++
        return
    }
    Write-Output 'PASS [shared rules] 22-rule inventory is exact'
    $script:Passed++

    function Convert-WarningLinesToRuleIds([string[]]$Lines) {
        $ActualIds = New-Object System.Collections.Generic.List[string]
        $SeenActualIds = New-Object 'System.Collections.Generic.HashSet[string]'

        foreach ($WarningLine in $Lines) {
            if ($WarningLine.Contains('[UdonSharp] VALIDATOR-WARNING:') -or
                $WarningLine.Contains('lexical mask length mismatch') -or
                $WarningLine.Contains('MASK_LENGTH_MISMATCH')) {
                throw 'validator internal failure detected'
            }
            if ($WarningLine -notmatch '\[UdonSharp\] (?:BLOCKED|WARNING|SYNC-BLOAT|ERROR):') {
                continue
            }

            $MatchingIds = New-Object System.Collections.Generic.List[string]
            for ($Index = 0; $Index -lt $RuleIds.Count; $Index++) {
                if ($WarningLine.Contains($RuleSubstrings[$Index])) {
                    $MatchingIds.Add($RuleIds[$Index])
                }
            }
            if ($MatchingIds.Count -ne 1) {
                throw "warning line maps to $($MatchingIds.Count) rule IDs: $WarningLine"
            }
            if (-not $SeenActualIds.Add($MatchingIds[0])) {
                throw "duplicate actual rule ID: $($MatchingIds[0])"
            }
            $ActualIds.Add($MatchingIds[0])
        }

        return $ActualIds.ToArray()
    }

    $SyntheticLines = @(
        "[UdonSharp] BLOCKED: $($RuleSubstrings[1])",
        "[UdonSharp] BLOCKED: $($RuleSubstrings[0])"
    )
    try {
        $SyntheticActual = (Convert-WarningLinesToRuleIds $SyntheticLines) -join ';'
        if ($SyntheticActual -eq "$($RuleIds[1]);$($RuleIds[0])") {
            Write-Output 'PASS [shared mapping] actual warning order is preserved'
            $script:Passed++
        } else {
            Write-Output 'FAIL [shared mapping] actual warning order was reordered'
            $script:Failed++
        }
    } catch {
        Write-Output "FAIL [shared mapping] $($_.Exception.Message)"
        $script:Failed++
    }

    try {
        [void](Convert-WarningLinesToRuleIds @('[UdonSharp] VALIDATOR-WARNING: validation skipped (MASK_LENGTH_MISMATCH)'))
        Write-Output 'FAIL [shared mapping] internal failure was accepted'
        $script:Failed++
    } catch {
        Write-Output 'PASS [shared mapping] internal failure is rejected'
        $script:Passed++
    }

    $SeenCaseIds = New-Object 'System.Collections.Generic.HashSet[string]'
    $ExpectedRuleCoverage = New-Object 'System.Collections.Generic.HashSet[string]'
    $CaseNumber = 0
    foreach ($Line in Get-Content -LiteralPath $SharedCases) {
        $CaseNumber++
        $Columns = $Line.Split("`t")
        if ($Columns.Count -ne 4) {
            Write-Output "FAIL [shared case $CaseNumber] malformed cases.tsv row"
            $script:Failed++
            continue
        }
        $CaseId, $Fixture, $Newline, $ExpectedText = $Columns
        if (-not $CaseId -or -not $Fixture -or -not $Newline -or -not $ExpectedText) {
            Write-Output "FAIL [shared case $CaseNumber] empty cases.tsv field"
            $script:Failed++
            continue
        }
        if (-not $SeenCaseIds.Add($CaseId)) {
            Write-Output "FAIL [shared case $CaseId] duplicate case ID"
            $script:Failed++
            continue
        }
        if ($Newline -ne 'LF' -and $Newline -ne 'CRLF') {
            Write-Output "FAIL [shared case $CaseId] unknown newline mode: $Newline"
            $script:Failed++
            continue
        }
        $FixturePath = Join-Path $SharedFixtures $Fixture
        if (-not (Test-Path -LiteralPath $FixturePath -PathType Leaf)) {
            Write-Output "FAIL [shared case $CaseId] missing fixture: $Fixture"
            $script:Failed++
            continue
        }

        $ExpectedIds = @()
        if ($ExpectedText -ne '-') {
            $ExpectedIds = @($ExpectedText.Split(';'))
        }
        $ExpectedSeen = New-Object 'System.Collections.Generic.HashSet[string]'
        $ExpectedIsValid = $true
        foreach ($ExpectedId in $ExpectedIds) {
            if (-not $SeenRuleIds.Contains($ExpectedId)) {
                Write-Output "FAIL [shared case $CaseId] unknown expected rule ID: $ExpectedId"
                $script:Failed++
                $ExpectedIsValid = $false
                break
            }
            if (-not $ExpectedSeen.Add($ExpectedId)) {
                Write-Output "FAIL [shared case $CaseId] duplicate expected rule ID: $ExpectedId"
                $script:Failed++
                $ExpectedIsValid = $false
                break
            }
            [void]$ExpectedRuleCoverage.Add($ExpectedId)
        }
        if (-not $ExpectedIsValid) {
            continue
        }
        $OrderedExpected = @($RuleIds | Where-Object { $ExpectedSeen.Contains($_) })
        $Expected = $OrderedExpected -join ';'
        if ($Expected -ne ($ExpectedIds -join ';')) {
            Write-Output "FAIL [shared case $CaseId] expected IDs are not in rules.tsv order"
            $script:Failed++
            continue
        }

        $Source = [System.IO.File]::ReadAllText($FixturePath)
        $Source = $Source.Replace("`r`n", "`n").Replace("`r", "`n")
        if ($Newline -eq 'CRLF') {
            $Source = $Source.Replace("`n", "`r`n")
        }
        $Materialized = Join-Path $TempRoot ("shared-" + $CaseId + ".cs")
        [System.IO.File]::WriteAllText($Materialized, $Source, (New-Object System.Text.UTF8Encoding($false)))
        $Payload = @{ tool_input = @{ file_path = $Materialized } } | ConvertTo-Json -Compress
        $ActualOutput = $Payload | & $Hook 2>&1 | Out-String

        try {
            $ActualIds = @(Convert-WarningLinesToRuleIds ([regex]::Split($ActualOutput, '\r?\n')))
        } catch {
            Write-Output "FAIL [shared case $CaseId] warning mapping failed: $($_.Exception.Message)"
            Write-Output $ActualOutput
            $script:Failed++
            continue
        }
        $Actual = $ActualIds -join ';'
        if ($Actual -eq $Expected) {
            $DisplayRules = $Actual
            if (-not $DisplayRules) { $DisplayRules = '-' }
            Write-Output "PASS [shared case $CaseId] rules=$DisplayRules"
            $script:Passed++
        } else {
            $ExpectedDisplay = $Expected
            $ActualDisplay = $Actual
            if (-not $ExpectedDisplay) { $ExpectedDisplay = '-' }
            if (-not $ActualDisplay) { $ActualDisplay = '-' }
            Write-Output "FAIL [shared case $CaseId] rules mismatch"
            Write-Output "  expected: $ExpectedDisplay"
            Write-Output "  actual:   $ActualDisplay"
            $script:Failed++
        }
    }

    $TemplateCount = 0
    foreach ($Line in Get-Content -LiteralPath $TemplateCases) {
        $TemplateCount++
        $Columns = $Line.Split([char]9)
        if ($Columns.Count -ne 2 -or -not $Columns[0] -or -not $Columns[1]) {
            Write-Output "FAIL [template case $TemplateCount] malformed template-cases.tsv row"
            $script:Failed++
            continue
        }
        $TemplateName, $TemplateExpected = $Columns
        $TemplatePath = Join-Path $TemplateRoot $TemplateName
        if (-not (Test-Path -LiteralPath $TemplatePath -PathType Leaf)) {
            Write-Output "FAIL [template case $TemplateName] missing template"
            $script:Failed++
            continue
        }
        $Payload = @{ tool_input = @{ file_path = $TemplatePath } } | ConvertTo-Json -Compress
        $TemplateOutput = $Payload | & $Hook 2>&1 | Out-String
        try {
            $TemplateActual = @(Convert-WarningLinesToRuleIds ([regex]::Split($TemplateOutput, '\r?\n'))) -join ';'
        } catch {
            Write-Output "FAIL [template case $TemplateName] warning mapping failed: $($_.Exception.Message)"
            $script:Failed++
            continue
        }
        if ($TemplateExpected -eq '-') { $TemplateExpected = '' }
        if ($TemplateActual -eq $TemplateExpected) {
            $TemplateDisplay = $TemplateActual
            if (-not $TemplateDisplay) { $TemplateDisplay = '-' }
            Write-Output "PASS [template case $TemplateName] rules=$TemplateDisplay"
            $script:Passed++
        } else {
            Write-Output "FAIL [template case $TemplateName] expected=$TemplateExpected actual=$TemplateActual"
            $script:Failed++
        }
    }

    $RepositoryTemplateCount = @(Get-ChildItem -LiteralPath $TemplateRoot -Filter '*.cs' -File).Count
    if ($TemplateCount -eq $RepositoryTemplateCount) {
        Write-Output "PASS [template cases] manifest covers all $TemplateCount templates"
        $script:Passed++
    } else {
        Write-Output "FAIL [template cases] manifest=$TemplateCount repository=$RepositoryTemplateCount"
        $script:Failed++
    }

    foreach ($RuleId in $RuleIds) {
        if (-not $ExpectedRuleCoverage.Contains($RuleId)) {
            Write-Output "FAIL [shared rules] rule ID missing from expected cases: $RuleId"
            $script:Failed++
        }
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
        $CaseOutput = Invoke-Hook $Source $Case.LeafName
        Assert-Contains $Case.Label $CaseOutput $SyncBloatWarning
        if ($Case.LeafName) {
            Assert-Contains 'literal path input JSON passthrough' $CaseOutput 'Bracket[1].cs'
        }
    }

    $MissingPathPayload = '{"tool_input":{}}'
    $MissingPathOutput = $MissingPathPayload | & $Hook 2>&1 | Out-String
    Assert-Contains 'missing path input JSON passthrough' $MissingPathOutput '"tool_input":{}'

    $MalformedPayload = '{"tool_input":'
    $MalformedResult = Invoke-HookProcess $MalformedPayload
    if ($MalformedResult.ExitCode -eq 0) {
        Write-Output 'PASS [malformed input JSON] exit=0'
        $script:Passed++
    } else {
        Write-Output "FAIL [malformed input JSON] exit=$($MalformedResult.ExitCode)"
        $script:Failed++
    }
    if ($MalformedResult.Stdout.Trim() -eq $MalformedPayload) {
        Write-Output 'PASS [malformed input JSON] stdout passes input through'
        $script:Passed++
    } else {
        Write-Output 'FAIL [malformed input JSON] stdout changed the input'
        $script:Failed++
    }
    $ExpectedOperationalWarning = '[UdonSharp] VALIDATOR-WARNING: validation skipped (JSON_PARSE_FAILED)'
    if ($MalformedResult.Stderr.TrimEnd("`r", "`n") -eq $ExpectedOperationalWarning -and
        ($MalformedResult.Stderr -split "`n").Count -eq 2) {
        Write-Output 'PASS [malformed input JSON] exactly one stderr warning line'
        $script:Passed++
    } else {
        Write-Output 'FAIL [malformed input JSON] stderr is not exactly one warning line'
        Write-Output $MalformedResult.Stderr
        $script:Failed++
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
    [UdonSynced] // Blank trivia does not detach an attribute from its declaration.

    private int[] values;
}
'@
    Assert-Contains 'blank trivia preserves attribute attachment' (Invoke-Hook $SeparatedAttributeSource) $SyncBloatWarning

    $NoFinalLf = 'alpha' + [char]10 + 'beta'
    $NoFinalCrLf = $NoFinalLf.Replace([string][char]10, ([string][char]13 + [char]10))
    if ($NoFinalCrLf -eq ('alpha' + [char]13 + [char]10 + 'beta') -and
        -not $NoFinalCrLf.EndsWith([string][char]10)) {
        Write-Output 'PASS [materializer] CRLF conversion preserves missing final newline'
        $script:Passed++
    } else {
        Write-Output 'FAIL [materializer] CRLF conversion changed missing final newline'
        $script:Failed++
    }

    $FinalLf = 'alpha' + [char]10 + 'beta' + [char]10
    $FinalCrLf = $FinalLf.Replace([string][char]10, ([string][char]13 + [char]10))
    if ($FinalCrLf -eq ('alpha' + [char]13 + [char]10 + 'beta' + [char]13 + [char]10)) {
        Write-Output 'PASS [materializer] CRLF conversion preserves final newline'
        $script:Passed++
    } else {
        Write-Output 'FAIL [materializer] CRLF conversion lost final newline'
        $script:Failed++
    }

    $Quotes = '"' * 15000
    $NearQuotes = '"' * 14999
    $RawPerformanceSource = @(
        'using UdonSharp;'
        'public class RawPerformance : UdonSharpBehaviour'
        '{'
        ('    private string value = ' + $Quotes)
        $NearQuotes
        ($Quotes + ';')
        '}'
    ) -join [char]10
    $RawStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $RawPerformanceOutput = Invoke-Hook $RawPerformanceSource 'raw-performance.cs'
    $RawStopwatch.Stop()
    Assert-NotContains 'raw string scan has no internal failure' $RawPerformanceOutput 'VALIDATOR-WARNING'
    if ($RawStopwatch.Elapsed.TotalSeconds -lt 8) {
        Write-Output ("PASS [raw string linear scan] elapsed={0:N3}s" -f $RawStopwatch.Elapsed.TotalSeconds)
        $script:Passed++
    } else {
        Write-Output ("FAIL [raw string linear scan] elapsed={0:N3}s" -f $RawStopwatch.Elapsed.TotalSeconds)
        $script:Failed++
    }

    # A run-length probe must reject a non-matching start in constant time.
    # Without the start-character guard, Regex.Match scans toward the final
    # quote for every incomplete `$x` token and makes the lexer quadratic.
    $DollarPerformanceSource = @(
        'using UdonSharp;'
        'public class DollarPerformance : UdonSharpBehaviour'
        '{'
        ('    private int value = ' + ('$x' * 15000) + '";')
        '}'
    ) -join [char]10
    $DollarStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $DollarPerformanceOutput = Invoke-Hook $DollarPerformanceSource 'dollar-performance.cs'
    $DollarStopwatch.Stop()
    Assert-NotContains 'dollar probe has no internal failure' $DollarPerformanceOutput 'VALIDATOR-WARNING'
    if ($DollarStopwatch.Elapsed.TotalSeconds -lt 8) {
        Write-Output ("PASS [dollar probe linear scan] elapsed={0:N3}s" -f $DollarStopwatch.Elapsed.TotalSeconds)
        $script:Passed++
    } else {
        Write-Output ("FAIL [dollar probe linear scan] elapsed={0:N3}s" -f $DollarStopwatch.Elapsed.TotalSeconds)
        $script:Failed++
    }

    Invoke-SharedParityMatrix

    Write-Output ""
    Write-Output "Summary: $Passed passed, $Failed failed"
    if ($Failed -ne 0) {
        exit 1
    }
} finally {
    Remove-Item -Path $TempRoot -Recurse -Force
}
