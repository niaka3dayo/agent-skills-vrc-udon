#Requires -Version 5.1
<#
.SYNOPSIS
    UdonSharp Code Validation Hook.
.DESCRIPTION
    Checks for common constraint violations in UdonSharp code.
    Called as PostToolUse hook when editing .cs files.
    Input: JSON via stdin with tool_input.file_path
    Output: Warnings to stderr, original input to stdout
#>

$ErrorActionPreference = "Stop"

# Read JSON input from stdin
$HookInput = $input | Out-String

function Stop-Validation([string]$Code) {
    [Console]::Error.WriteLine("[UdonSharp] VALIDATOR-WARNING: validation skipped ($Code)")
    Write-Output $HookInput
    exit 0
}

# Parse file path from JSON
try {
    $JsonObj = $HookInput | ConvertFrom-Json
    $FilePath = $JsonObj.tool_input.file_path
    if (-not $FilePath) {
        $FilePath = $JsonObj.tool_input.filePath
    }
    if (-not $FilePath) {
        $FilePath = ""
    }
} catch {
    Stop-Validation 'JSON_PARSE_FAILED'
}

# Only process .cs files
if ($FilePath -notmatch '\.cs$') {
    Write-Output $HookInput
    exit 0
}

# Check if file exists
if (-not (Test-Path -LiteralPath $FilePath -PathType Leaf)) {
    Write-Output $HookInput
    exit 0
}

try {
    $FileContent = Get-Content -LiteralPath $FilePath -Raw -ErrorAction Stop
} catch {
    Stop-Validation 'SOURCE_READ_FAILED'
}

function Get-CSharpCodeSource([string]$Source) {
    $LineComment = 1
    $BlockComment = 2
    $CommentState = 0
    $Frames = New-Object System.Collections.ArrayList
    $Builder = [System.Text.StringBuilder]::new($Source.Length)
    $QuoteRunRegex = [regex]::new('"+')
    $DollarRunRegex = [regex]::new('\$+')
    $OpenBraceRunRegex = [regex]::new('\{+')
    $CloseBraceRunRegex = [regex]::new('\}+')
    $Index = 0

    function Add-Mask([int]$Count) {
        if ($Count -gt 0) {
            [void]$Builder.Append(' ', $Count)
        }
    }

    function Get-RunLength([int]$Start, [char]$Wanted) {
        if ($Start -lt 0 -or $Start -ge $Source.Length -or $Source[$Start] -ne $Wanted) {
            return 0
        }
        if ($Wanted -eq [char]34) { $RunRegex = $QuoteRunRegex }
        elseif ($Wanted -eq [char]36) { $RunRegex = $DollarRunRegex }
        elseif ($Wanted -eq [char]123) { $RunRegex = $OpenBraceRunRegex }
        elseif ($Wanted -eq [char]125) { $RunRegex = $CloseBraceRunRegex }
        else { throw 'LEXER_FAILED' }

        $Match = $RunRegex.Match($Source, $Start)
        if (-not $Match.Success -or $Match.Index -ne $Start) {
            return 0
        }
        return $Match.Length
    }

    function Add-Literal([string]$Kind, [bool]$Interpolated, [int]$QuoteWidth, [int]$BraceWidth) {
        [void]$Frames.Add(@{
            Type = 'L'
            Kind = $Kind
            Interpolated = $Interpolated
            QuoteWidth = $QuoteWidth
            BraceWidth = $BraceWidth
        })
    }

    function Add-Hole([int]$CloseWidth) {
        [void]$Frames.Add(@{
            Type = 'H'
            CloseWidth = $CloseWidth
            ParenDepth = 0
            BracketDepth = 0
            CodeBraceDepth = 0
            FormatMode = $false
        })
    }

    function Remove-Frame {
        $Frames.RemoveAt($Frames.Count - 1)
    }

    while ($Index -lt $Source.Length) {
        $Current = $Source[$Index]
        $HasNext = $Index + 1 -lt $Source.Length
        $Next = if ($HasNext) { $Source[$Index + 1] } else { [char]0 }

        if ($Current -eq [char]13 -or $Current -eq [char]10) {
            [void]$Builder.Append($Current)
            if ($CommentState -eq $LineComment) {
                $CommentState = 0
            }
            if ($Frames.Count -gt 0) {
                $Top = $Frames[$Frames.Count - 1]
                if ($Top.Type -eq 'L' -and ($Top.Kind -eq 'R' -or $Top.Kind -eq 'C')) {
                    Remove-Frame
                }
            }
            $Index++
            continue
        }

        if ($CommentState -eq $LineComment) {
            Add-Mask 1
            $Index++
            continue
        }

        if ($CommentState -eq $BlockComment) {
            if ($HasNext -and $Current -eq '*' -and $Next -eq '/') {
                Add-Mask 2
                $CommentState = 0
                $Index += 2
            } else {
                Add-Mask 1
                $Index++
            }
            continue
        }

        if ($Frames.Count -gt 0 -and $Frames[$Frames.Count - 1].Type -eq 'L') {
            $Top = $Frames[$Frames.Count - 1]
            $Kind = $Top.Kind

            if ($Kind -eq 'R' -or $Kind -eq 'C') {
                $Closing = if ($Kind -eq 'R') { '"' } else { "'" }
                if ($Current -eq '\') {
                    Add-Mask 1
                    $Index++
                    if ($Index -lt $Source.Length -and $Source[$Index] -ne [char]13 -and $Source[$Index] -ne [char]10) {
                        Add-Mask 1
                        $Index++
                    }
                    continue
                }
                if ($Current -eq $Closing) {
                    Add-Mask 1
                    $Index++
                    Remove-Frame
                    continue
                }
            } elseif ($Kind -eq 'V' -and $Current -eq '"') {
                $Count = Get-RunLength $Index '"'
                Add-Mask $Count
                $Index += $Count
                if ($Count % 2 -eq 1) {
                    Remove-Frame
                }
                continue
            } elseif ($Kind -eq 'W' -and $Current -eq '"') {
                $Count = Get-RunLength $Index '"'
                if ($Count -ge $Top.QuoteWidth) {
                    $Width = $Top.QuoteWidth
                    Add-Mask $Width
                    $Index += $Width
                    Remove-Frame
                } else {
                    Add-Mask $Count
                    $Index += $Count
                }
                continue
            }

            if ($Top.Interpolated -and $Current -eq '{') {
                $Count = Get-RunLength $Index '{'
                $Width = $Top.BraceWidth
                Add-Mask $Count
                if (($Width -eq 1 -and $Count % 2 -eq 1) -or ($Width -gt 1 -and $Count -ge $Width)) {
                    Add-Hole $Width
                }
                $Index += $Count
                continue
            }
            if ($Top.Interpolated -and $Current -eq '}') {
                $Count = Get-RunLength $Index '}'
                Add-Mask $Count
                $Index += $Count
                continue
            }

            Add-Mask 1
            $Index++
            continue
        }

        if ($Frames.Count -gt 0 -and $Frames[$Frames.Count - 1].Type -eq 'H') {
            $Top = $Frames[$Frames.Count - 1]
            if ($Top.FormatMode) {
                if ($Current -eq '}') {
                    $Count = Get-RunLength $Index '}'
                    $Width = $Top.CloseWidth
                    if ($Count -ge $Width) {
                        Add-Mask $Width
                        $Index += $Width
                        Remove-Frame
                    } else {
                        Add-Mask $Count
                        $Index += $Count
                    }
                } else {
                    Add-Mask 1
                    $Index++
                }
                continue
            }

            if ($Current -eq '}' -and
                $Top.ParenDepth -eq 0 -and
                $Top.BracketDepth -eq 0 -and
                $Top.CodeBraceDepth -eq 0) {
                $Count = Get-RunLength $Index '}'
                $Width = $Top.CloseWidth
                if ($Count -ge $Width) {
                    Add-Mask $Width
                    $Index += $Width
                    Remove-Frame
                    continue
                }
            }

            $Previous = if ($Index -gt 0) { $Source[$Index - 1] } else { [char]0 }
            if ($Current -eq ':' -and
                $Top.ParenDepth -eq 0 -and
                $Top.BracketDepth -eq 0 -and
                $Top.CodeBraceDepth -eq 0 -and
                $Previous -ne ':' -and $Next -ne ':') {
                Add-Mask 1
                $Top.FormatMode = $true
                $Index++
                continue
            }
        }

        if ($HasNext -and $Current -eq '/' -and $Next -eq '/') {
            Add-Mask 2
            $CommentState = $LineComment
            $Index += 2
            continue
        }
        if ($HasNext -and $Current -eq '/' -and $Next -eq '*') {
            Add-Mask 2
            $CommentState = $BlockComment
            $Index += 2
            continue
        }

        if ($Current -eq '$') {
            $DollarCount = Get-RunLength $Index '$'
            $AfterDollars = $Index + $DollarCount
            $DelimiterLength = Get-RunLength $AfterDollars '"'
            if ($DelimiterLength -ge 3) {
                Add-Mask ($DollarCount + $DelimiterLength)
                Add-Literal 'W' $true $DelimiterLength $DollarCount
                $Index += $DollarCount + $DelimiterLength
                continue
            }
            if ($DollarCount -eq 1 -and $AfterDollars + 1 -lt $Source.Length -and
                $Source[$AfterDollars] -eq '@' -and $Source[$AfterDollars + 1] -eq '"') {
                Add-Mask 3
                Add-Literal 'V' $true 1 1
                $Index += 3
                continue
            }
            if ($DollarCount -eq 1 -and $AfterDollars -lt $Source.Length -and
                $Source[$AfterDollars] -eq '"') {
                Add-Mask 2
                Add-Literal 'R' $true 1 1
                $Index += 2
                continue
            }
        }

        if ($Current -eq '@' -and $Index + 2 -lt $Source.Length -and
            $Source[$Index + 1] -eq '$' -and $Source[$Index + 2] -eq '"') {
            Add-Mask 3
            Add-Literal 'V' $true 1 1
            $Index += 3
            continue
        }
        if ($Current -eq '@' -and $HasNext -and $Next -eq '"') {
            Add-Mask 2
            Add-Literal 'V' $false 1 0
            $Index += 2
            continue
        }

        if ($Current -eq '"') {
            $DelimiterLength = Get-RunLength $Index '"'
            if ($DelimiterLength -ge 3) {
                Add-Mask $DelimiterLength
                Add-Literal 'W' $false $DelimiterLength 0
                $Index += $DelimiterLength
            } else {
                Add-Mask 1
                Add-Literal 'R' $false 1 0
                $Index++
            }
            continue
        }

        if ($Current -eq "'") {
            Add-Mask 1
            Add-Literal 'C' $false 1 0
            $Index++
            continue
        }

        if ($Frames.Count -gt 0 -and $Frames[$Frames.Count - 1].Type -eq 'H') {
            $Top = $Frames[$Frames.Count - 1]
            if ($Current -eq '(') { $Top.ParenDepth++ }
            elseif ($Current -eq ')' -and $Top.ParenDepth -gt 0) { $Top.ParenDepth-- }
            elseif ($Current -eq '[') { $Top.BracketDepth++ }
            elseif ($Current -eq ']' -and $Top.BracketDepth -gt 0) { $Top.BracketDepth-- }
            elseif ($Current -eq '{') { $Top.CodeBraceDepth++ }
            elseif ($Current -eq '}' -and $Top.CodeBraceDepth -gt 0) { $Top.CodeBraceDepth-- }
        }

        [void]$Builder.Append($Current)
        $Index++
    }

    $Masked = $Builder.ToString()
    if ($Masked.Length -ne $Source.Length) {
        throw 'MASK_LENGTH_MISMATCH'
    }
    return $Masked
}


function Test-UdonSharpBehaviourSource([string]$MaskedSource) {
    $BaseNames = New-Object System.Collections.Generic.List[string]
    $BaseNames.Add('UdonSharpBehaviour')
    $BaseNames.Add('UdonSharp\.UdonSharpBehaviour')
    $BaseNames.Add('global::UdonSharp\.UdonSharpBehaviour')

    $AliasPattern = 'using\s+(?<Alias>[A-Za-z_][A-Za-z0-9_]*)\s*=\s*(?<Target>(?:global::)?UdonSharp(?:\.UdonSharpBehaviour)?)\s*;'
    foreach ($AliasMatch in [regex]::Matches($MaskedSource, $AliasPattern)) {
        $AliasName = [regex]::Escape($AliasMatch.Groups['Alias'].Value)
        if ($AliasMatch.Groups['Target'].Value.EndsWith('UdonSharpBehaviour')) {
            $BaseNames.Add($AliasName)
        } else {
            $BaseNames.Add($AliasName + '\.UdonSharpBehaviour')
        }
    }

    foreach ($BaseName in $BaseNames) {
        $ClassPattern = '(?s)\bclass\s+[A-Za-z_][A-Za-z0-9_]*\s*:[^{};]*[,:\s]' + $BaseName + '(?=$|[,<{\s])'
        if ($MaskedSource -match $ClassPattern) {
            return $true
        }
    }
    return $false
}

try {
    $MaskedSource = Get-CSharpCodeSource $FileContent
} catch {
    if ($_.Exception.Message -eq 'MASK_LENGTH_MISMATCH') {
        Stop-Validation 'MASK_LENGTH_MISMATCH'
    }
    Stop-Validation 'LEXER_FAILED'
}

# Check if this is structurally an UdonSharp behaviour. External project base
# types are intentionally not resolved by this per-file hook.
if (-not (Test-UdonSharpBehaviourSource $MaskedSource)) {
    Write-Output $HookInput
    exit 0
}

# === Validation Rules ===
$Warnings = @()

# Check for blocked generics
if ($MaskedSource -match 'List<|Dictionary<|HashSet<|Queue<|Stack<') {
    $Warnings += "[UdonSharp] BLOCKED: Generic collections (List<T>, Dictionary<K,V>) not supported. Use arrays or DataList/DataDictionary."
}

# Check for async/await
if ($MaskedSource -match '\basync\b|\bawait\b') {
    $Warnings += "[UdonSharp] BLOCKED: async/await not supported. Use SendCustomEventDelayedSeconds() instead."
}

# Check for try/catch
if ($MaskedSource -match '\btry\s*\{|\bcatch\s*\(|\bfinally\s*\{') {
    $Warnings += "[UdonSharp] BLOCKED: try/catch/finally not supported. Use defensive null checks and validation."
}

# Check for LINQ
if ($MaskedSource -match '\.Where\(|\.Select\(|\.OrderBy\(|\.FirstOrDefault\(|\.Any\(|\.All\(') {
    $Warnings += "[UdonSharp] BLOCKED: LINQ not supported. Use manual for loops."
}

# Check for yield return (coroutines)
if ($MaskedSource -match '\byield\s+return\b') {
    $Warnings += "[UdonSharp] BLOCKED: Coroutines (yield return) not supported. Use SendCustomEventDelayedSeconds()."
}

# Check for interface declaration
if ($MaskedSource -match '(?m)^\s*(public\s+)?interface\s+') {
    $Warnings += "[UdonSharp] BLOCKED: Interfaces not supported. Use base class inheritance or SendCustomEvent pattern."
}

# Check for StartCoroutine
if ($MaskedSource -match 'StartCoroutine\s*\(') {
    $Warnings += "[UdonSharp] BLOCKED: StartCoroutine not available. Use SendCustomEventDelayedSeconds() instead."
}

# Check for AddListener (not supported - delegates blocked)
if ($MaskedSource -match '\.AddListener\s*\(') {
    $Warnings += "[UdonSharp] BLOCKED: AddListener() not supported. Use Inspector OnClick -> SendCustomEvent instead."
}

# Lambda expressions on one physical line. Simple and parenthesized forms use
# the same ASCII space/tab contract as the Bash hook.
$HasLambda = $false
foreach ($Line in [regex]::Split($MaskedSource, '\r?\n')) {
    $Candidate = [regex]::Replace(
        $Line,
        '^[ \t]*((public|private|protected|internal|static|virtual|override|abstract|sealed|new)[ \t]+)*[A-Za-z_][A-Za-z0-9_.:<>,?\[\]]*[ \t]+[A-Za-z_][A-Za-z0-9_]*[ \t]*\([^)]*\)[ \t]*=>',
        '',
        1
    )
    $Candidate = [regex]::Replace($Candidate, '(^|[;{ \t])(get|set|init)[ \t]*=>', ' ')
    if ($Candidate -match '\)[ \t]*=>[ \t]*(?:\{|[^;{\r\n]+;)' -or
        $Candidate -match '(^|[=(, \t])[A-Za-z_][A-Za-z0-9_]*[ \t]*=>[ \t]*(?:\{|[^;{\r\n]+;)') {
        $HasLambda = $true
        break
    }
}
if ($HasLambda) {
    $Warnings += "[UdonSharp] WARNING: Lambda expression detected. Use named methods instead."
}

function Get-SyncStats([string]$Source) {
    function Find-AttributeGroupEnd([string]$Text) {
        $Parens = 0
        for ($Position = 1; $Position -lt $Text.Length; $Position++) {
            if ($Position + 1 -lt $Text.Length -and $Text.Substring($Position, 2) -eq '[]') {
                $Position++
                continue
            }
            if ($Text[$Position] -eq '(') { $Parens++ }
            elseif ($Text[$Position] -eq ')' -and $Parens -gt 0) { $Parens-- }
            elseif ($Text[$Position] -eq ']' -and $Parens -eq 0) { return $Position }
        }
        return -1
    }

    function Process-Declaration([string]$Declaration) {
        $Declaration = $Declaration.TrimStart()
        $IsClass = $Declaration -match '^((public|private|protected|internal|abstract|sealed|static|partial)[ \t]+)*class[ \t]+'
        $IsField = $Declaration -notmatch '^(class|struct|interface|enum|delegate|event)[ \t]+' -and
            $Declaration -notmatch '[)][ \t]*(\{|=>)' -and
            $Declaration -match '^((public|private|protected|internal|static|readonly|const|volatile|new)[ \t]+)*([A-Za-z_][A-Za-z0-9_.:<>,?]*[ \t]*(\[[ \t]*\])?[ \t]+)+[A-Za-z_][A-Za-z0-9_]*[ \t]*(=|,|;)'

        if ($State.PendingNoVariableSync -and $IsClass) {
            $State.HasNoVariableSync = $true
        }
        if ($State.PendingSynced -and $IsField) {
            $State.SyncedCount++
            if ($Declaration -match '^((public|private|protected|internal|static|readonly|const|volatile|new)[ \t]+)*(int|float)[ \t]*\[[ \t]*\][ \t]+') {
                $State.HasLargeSyncedArray = $true
            }
        }
        $State.PendingSynced = $false
        $State.PendingNoVariableSync = $false
    }

    $State = @{
        PendingSynced = $false
        PendingNoVariableSync = $false
        SyncedCount = 0
        HasNoVariableSync = $false
        HasLargeSyncedArray = $false
    }

    foreach ($Line in [regex]::Split($Source, '\r?\n')) {
        $Rest = $Line.TrimStart()
        $FoundGroup = $false
        $LineSynced = $false
        $LineNoVariableSync = $false

        while ($Rest.StartsWith('[')) {
            $End = Find-AttributeGroupEnd $Rest
            if ($End -lt 0) { break }
            $FoundGroup = $true
            $Compact = $Rest.Substring(1, $End - 1) -replace '[ \t\r\n]', ''
            $Target = ''
            if ($Compact -match '^(type|field):') {
                $Target = $Matches[1]
                $Compact = $Compact.Substring($Matches[0].Length)
            }
            if (($Target -eq '' -or $Target -eq 'field') -and
                $Compact -match '(^|,)((global::)?UdonSharp\.)?UdonSynced(Attribute)?($|,|\()') {
                $LineSynced = $true
            }
            if (($Target -eq '' -or $Target -eq 'type') -and
                $Compact -match '(^|,)((global::)?UdonSharp\.)?UdonBehaviourSyncMode(Attribute)?\(BehaviourSyncMode\.NoVariableSync\)($|,)') {
                $LineNoVariableSync = $true
            }
            $Rest = $Rest.Substring($End + 1).TrimStart()
        }

        if ($FoundGroup) {
            $State.PendingSynced = $State.PendingSynced -or $LineSynced
            $State.PendingNoVariableSync = $State.PendingNoVariableSync -or $LineNoVariableSync
            if ($Rest) {
                Process-Declaration $Rest
            }
            continue
        }

        if (-not [string]::IsNullOrWhiteSpace($Line) -and
            ($State.PendingSynced -or $State.PendingNoVariableSync)) {
            Process-Declaration $Line
        }
    }

    return [pscustomobject]@{
        SyncedCount = $State.SyncedCount
        HasNoVariableSync = $State.HasNoVariableSync
        HasLargeSyncedArray = $State.HasLargeSyncedArray
    }
}


$SyncStats = Get-SyncStats $MaskedSource
$SyncedCount = $SyncStats.SyncedCount
$HasNoVariableSync = $SyncStats.HasNoVariableSync
$HasLargeSyncedArray = $SyncStats.HasLargeSyncedArray

# Check for potential networking issues
if ($SyncedCount -gt 0) {
    # Check if RequestSerialization is called
    if ($MaskedSource -notmatch 'RequestSerialization\s*\(') {
        $Warnings += "[UdonSharp] WARNING: [UdonSynced] found but no RequestSerialization(). Required for Manual sync mode."
    }
    # Check if SetOwner is called
    if ($MaskedSource -notmatch 'Networking\.(?:SetOwner|IsOwner)\s*\(|(?:^|[^.A-Za-z0-9_])IsOwner\s*\(') {
        $Warnings += "[UdonSharp] WARNING: [UdonSynced] found but no Networking.SetOwner() or Networking.IsOwner() guard. Confirm ownership before writes."
    }
}

# Check for VRCPlayerApi without validity check
if ($MaskedSource -match 'VRCPlayerApi\s+\w+\s*=') {
    if ($MaskedSource -notmatch '\.IsValid\s*\(\)|Utilities\.IsValid\s*\(|player\s*!=\s*null') {
        $Warnings += "[UdonSharp] WARNING: VRCPlayerApi used. Always check player != null && player.IsValid() before use."
    }
}

# Check for override on Unity standard callbacks (should NOT have override)
if ($MaskedSource -match 'override\s+void\s+(OnTriggerEnter|OnTriggerStay|OnTriggerExit|OnCollisionEnter|OnCollisionStay|OnCollisionExit|OnAnimatorMove|OnAnimatorIK)') {
    $Warnings += "[UdonSharp] WARNING: Unity callbacks (OnTriggerEnter etc.) should NOT use 'override'. Only VRChat events need override."
}

# Check for generic GetComponent (not exposed)
if ($MaskedSource -match 'GetComponent<UdonBehaviour>') {
    $Warnings += "[UdonSharp] BLOCKED: GetComponent<UdonBehaviour>() not exposed. Use (UdonBehaviour)GetComponent(typeof(UdonBehaviour)) instead."
}

# Check for System.Net / System.IO (blocked - use VRC downloaders)
if ($MaskedSource -match 'using\s+System\.(Net|IO)\b|System\.Net\.|System\.IO\.') {
    $Warnings += "[UdonSharp] BLOCKED: System.Net/System.IO not available. Use VRCStringDownloader or VRCImageDownloader instead. See references/web-loading.md."
}

# Sync bloat: too many synced variables (>5)
if ($SyncedCount -gt 5) {
    $Warnings += "[UdonSharp] SYNC-BLOAT: $SyncedCount synced variables detected (target: <5 per behaviour). Consider minimizing synced data. See references/sync-examples.md or rules/udonsharp-sync-selection.md."
}

# Sync bloat: large synced arrays (int[]/float[] instead of byte[]/short[])
if ($HasLargeSyncedArray) {
    $Warnings += "[UdonSharp] SYNC-BLOAT: Synced int[]/float[] detected. Consider byte[] or short[] if value range allows."
}

# NoVariableSync + [UdonSynced] conflict
if ($HasNoVariableSync -and $SyncedCount -gt 0) {
    $Warnings += "[UdonSharp] ERROR: NoVariableSync mode but [UdonSynced] variables found. Remove [UdonSynced] or change sync mode."
}

# Check for ref parameter in method declaration
if ($MaskedSource -match '\b(void|int|float|bool|string|[A-Z][A-Za-z0-9_]*)\s+\w+\s*\(.*\bref\s+\w') {
    $Warnings += "[UdonSharp] BLOCKED: ref parameters not supported in UdonSharp. Use return values or synced fields instead."
}

# Check for out parameter in method declaration
if ($MaskedSource -match '\b(void|int|float|bool|string|[A-Z][A-Za-z0-9_]*)\s+\w+\s*\(.*\bout\s+\w') {
    $Warnings += "[UdonSharp] BLOCKED: out parameters not supported in UdonSharp. Use return values instead."
}

# Check for multi-dimensional arrays (T[,])
if ($MaskedSource -match '\w+\s*\[,') {
    $Warnings += "[UdonSharp] BLOCKED: Multi-dimensional arrays (T[,]) not supported. Use jagged arrays (T[][]) or flatten to 1D instead."
}

# Check for method overloading (same name, different signatures)
$MethodMatches = [regex]::Matches(
    $MaskedSource,
    '(?m)^[ \t]*(?:(?:public|private|protected|internal|override|virtual|static)[ \t]+)*(?:void|int|float|bool|string|[A-Z][A-Za-z0-9_]*)[ \t]+([A-Za-z_][A-Za-z0-9_]*)[ \t]*\('
)
$MethodNames = $MethodMatches | ForEach-Object { $_.Groups[1].Value }
$OverloadedNames = $MethodNames | Group-Object | Where-Object { $_.Count -gt 1 } | Select-Object -ExpandProperty Name
if ($OverloadedNames.Count -gt 0) {
    $OverloadList = $OverloadedNames -join ', '
    $Warnings += "[UdonSharp] WARNING: Method overloading detected for: $OverloadList. Only simple overloads may work; prefer unique method names."
}

# Output warnings
if ($Warnings.Count -gt 0) {
    $SavedErrorAction = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    Write-Error ""
    Write-Error "=== UdonSharp Validation Warnings ==="
    foreach ($Warning in $Warnings) {
        Write-Error $Warning
    }
    Write-Error "==================================="
    Write-Error ""
    $ErrorActionPreference = $SavedErrorAction
}

# Always output original input to allow the edit to proceed
Write-Output $HookInput
