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
$Input = $input | Out-String

# Parse file path from JSON
try {
    $JsonObj = $Input | ConvertFrom-Json
    $FilePath = $JsonObj.tool_input.file_path
    if (-not $FilePath) {
        $FilePath = $JsonObj.tool_input.filePath
    }
    if (-not $FilePath) {
        $FilePath = ""
    }
} catch {
    Write-Output $Input
    exit 0
}

# Only process .cs files
if ($FilePath -notmatch '\.cs$') {
    Write-Output $Input
    exit 0
}

# Check if file exists
if (-not (Test-Path -LiteralPath $FilePath -PathType Leaf)) {
    Write-Output $Input
    exit 0
}

$FileContent = Get-Content -LiteralPath $FilePath -Raw

function Get-CSharpLexicallyMaskedSource([string]$Source) {
    $Code = 0
    $LineComment = 1
    $BlockComment = 2
    $RegularString = 3
    $VerbatimString = 4
    $Character = 5
    $RawString = 6
    $State = $Code
    $RawDelimiterLength = 0
    $Builder = [System.Text.StringBuilder]::new($Source.Length)
    $Index = 0

    while ($Index -lt $Source.Length) {
        $Current = $Source[$Index]
        $HasNext = $Index + 1 -lt $Source.Length
        $Next = if ($HasNext) { $Source[$Index + 1] } else { [char]0 }

        if ($Current -eq "`r" -or $Current -eq "`n") {
            [void]$Builder.Append($Current)
            if ($State -eq $LineComment -or $State -eq $RegularString -or $State -eq $Character) {
                $State = $Code
            }
            $Index++
            continue
        }

        if ($State -eq $LineComment) {
            [void]$Builder.Append(' ')
            $Index++
            continue
        }

        if ($State -eq $BlockComment) {
            if ($HasNext -and $Current -eq '*' -and $Next -eq '/') {
                [void]$Builder.Append(' ', 2)
                $State = $Code
                $Index += 2
            } else {
                [void]$Builder.Append(' ')
                $Index++
            }
            continue
        }

        if ($State -eq $RegularString -or $State -eq $Character) {
            $ClosingCharacter = if ($State -eq $RegularString) { '"' } else { "'" }
            if ($Current -eq '\') {
                [void]$Builder.Append(' ')
                $Index++
                if ($Index -lt $Source.Length -and $Source[$Index] -ne "`r" -and $Source[$Index] -ne "`n") {
                    [void]$Builder.Append(' ')
                    $Index++
                }
            } else {
                [void]$Builder.Append(' ')
                if ($Current -eq $ClosingCharacter) {
                    $State = $Code
                }
                $Index++
            }
            continue
        }

        if ($State -eq $VerbatimString) {
            if ($HasNext -and $Current -eq '"' -and $Next -eq '"') {
                [void]$Builder.Append(' ', 2)
                $Index += 2
            } else {
                [void]$Builder.Append(' ')
                if ($Current -eq '"') {
                    $State = $Code
                }
                $Index++
            }
            continue
        }

        if ($State -eq $RawString) {
            $QuoteCount = 0
            while ($Index + $QuoteCount -lt $Source.Length -and $Source[$Index + $QuoteCount] -eq '"') {
                $QuoteCount++
            }
            if ($QuoteCount -ge $RawDelimiterLength) {
                [void]$Builder.Append(' ', $RawDelimiterLength)
                $Index += $RawDelimiterLength
                $State = $Code
            } else {
                [void]$Builder.Append(' ')
                $Index++
            }
            continue
        }

        if ($HasNext -and $Current -eq '/' -and $Next -eq '/') {
            [void]$Builder.Append(' ', 2)
            $State = $LineComment
            $Index += 2
            continue
        }
        if ($HasNext -and $Current -eq '/' -and $Next -eq '*') {
            [void]$Builder.Append(' ', 2)
            $State = $BlockComment
            $Index += 2
            continue
        }

        if ($Current -eq '$') {
            $DollarCount = 0
            while ($Index + $DollarCount -lt $Source.Length -and $Source[$Index + $DollarCount] -eq '$') {
                $DollarCount++
            }
            $AfterDollars = $Index + $DollarCount
            $QuoteCount = 0
            while ($AfterDollars + $QuoteCount -lt $Source.Length -and $Source[$AfterDollars + $QuoteCount] -eq '"') {
                $QuoteCount++
            }
            if ($QuoteCount -ge 3) {
                [void]$Builder.Append(' ', $DollarCount + $QuoteCount)
                $RawDelimiterLength = $QuoteCount
                $State = $RawString
                $Index += $DollarCount + $QuoteCount
                continue
            }
            if ($DollarCount -eq 1 -and $AfterDollars + 1 -lt $Source.Length -and
                $Source[$AfterDollars] -eq '@' -and $Source[$AfterDollars + 1] -eq '"') {
                [void]$Builder.Append(' ', 3)
                $State = $VerbatimString
                $Index += 3
                continue
            }
            if ($DollarCount -eq 1 -and $AfterDollars -lt $Source.Length -and $Source[$AfterDollars] -eq '"') {
                [void]$Builder.Append(' ', 2)
                $State = $RegularString
                $Index += 2
                continue
            }
        }

        if ($Current -eq '@' -and $Index + 2 -lt $Source.Length -and
            $Source[$Index + 1] -eq '$' -and $Source[$Index + 2] -eq '"') {
            [void]$Builder.Append(' ', 3)
            $State = $VerbatimString
            $Index += 3
            continue
        }
        if ($Current -eq '@' -and $HasNext -and $Next -eq '"') {
            [void]$Builder.Append(' ', 2)
            $State = $VerbatimString
            $Index += 2
            continue
        }

        if ($Current -eq '"') {
            $QuoteCount = 0
            while ($Index + $QuoteCount -lt $Source.Length -and $Source[$Index + $QuoteCount] -eq '"') {
                $QuoteCount++
            }
            if ($QuoteCount -ge 3) {
                [void]$Builder.Append(' ', $QuoteCount)
                $RawDelimiterLength = $QuoteCount
                $State = $RawString
                $Index += $QuoteCount
            } else {
                [void]$Builder.Append(' ')
                $State = $RegularString
                $Index++
            }
            continue
        }

        if ($Current -eq "'") {
            [void]$Builder.Append(' ')
            $State = $Character
            $Index++
            continue
        }

        [void]$Builder.Append($Current)
        $Index++
    }

    $Masked = $Builder.ToString()
    if ($Masked.Length -ne $Source.Length) {
        throw "lexical mask length mismatch"
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

$MaskedSource = Get-CSharpLexicallyMaskedSource $FileContent

# Check if this is structurally an UdonSharp behaviour. External project base
# types are intentionally not resolved by this per-file hook.
if (-not (Test-UdonSharpBehaviourSource $MaskedSource)) {
    Write-Output $Input
    exit 0
}

# === Validation Rules ===
$Warnings = @()

# Check for blocked generics
if ($FileContent -match 'List<|Dictionary<|HashSet<|Queue<|Stack<') {
    $Warnings += "[UdonSharp] BLOCKED: Generic collections (List<T>, Dictionary<K,V>) not supported. Use arrays or DataList/DataDictionary."
}

# Check for async/await
if ($FileContent -match '\basync\b|\bawait\b') {
    $Warnings += "[UdonSharp] BLOCKED: async/await not supported. Use SendCustomEventDelayedSeconds() instead."
}

# Check for try/catch
if ($FileContent -match '\btry\s*\{|\bcatch\s*\(|\bfinally\s*\{') {
    $Warnings += "[UdonSharp] BLOCKED: try/catch/finally not supported. Use defensive null checks and validation."
}

# Check for LINQ
if ($FileContent -match '\.Where\(|\.Select\(|\.OrderBy\(|\.FirstOrDefault\(|\.Any\(|\.All\(') {
    $Warnings += "[UdonSharp] BLOCKED: LINQ not supported. Use manual for loops."
}

# Check for yield return (coroutines)
if ($FileContent -match '\byield\s+return\b') {
    $Warnings += "[UdonSharp] BLOCKED: Coroutines (yield return) not supported. Use SendCustomEventDelayedSeconds()."
}

# Check for interface declaration
if ($FileContent -match '(?m)^\s*(public\s+)?interface\s+') {
    $Warnings += "[UdonSharp] BLOCKED: Interfaces not supported. Use base class inheritance or SendCustomEvent pattern."
}

# Check for StartCoroutine
if ($FileContent -match 'StartCoroutine\s*\(') {
    $Warnings += "[UdonSharp] BLOCKED: StartCoroutine not available. Use SendCustomEventDelayedSeconds() instead."
}

# Check for AddListener (not supported - delegates blocked)
if ($FileContent -match '\.AddListener\s*\(') {
    $Warnings += "[UdonSharp] BLOCKED: AddListener() not supported. Use Inspector OnClick -> SendCustomEvent instead."
}

# Lambda expressions. Keep this on RawSource so interpolation expressions are
# not hidden by the structural/sync lexical mask.
if ($FileContent -match '(?m)\)[ \t]*=>[ \t]*(?:\{|[^;{\r\n]+;)') {
    $Warnings += "[UdonSharp] WARNING: Lambda expression detected. Use named methods instead."
}

# Attribute-aware sync inventory from MaskedSource.
$SyncedCount = 0
$HasNoVariableSync = $false
$AttributeGroupPattern = '(?s)\[(?:[^\[\]]|\[\])*\]'
foreach ($AttributeGroupMatch in [regex]::Matches($MaskedSource, $AttributeGroupPattern)) {
    $AttributeContent = $AttributeGroupMatch.Value.Substring(1, $AttributeGroupMatch.Value.Length - 2)
    $CompactAttributeContent = $AttributeContent -replace '[ \t\r\n]', ''
    $SyncedCount += ([regex]::Matches($CompactAttributeContent, '(?:^|,|:)UdonSynced(?:Attribute)?(?:$|,|\()')).Count
    if ($CompactAttributeContent -match '(?:^|,)UdonBehaviourSyncMode(?:Attribute)?\(BehaviourSyncMode\.NoVariableSync\)(?:$|,)') {
        $HasNoVariableSync = $true
    }
}

# Check for potential networking issues
if ($SyncedCount -gt 0) {
    # Check if RequestSerialization is called
    if ($MaskedSource -notmatch 'RequestSerialization\s*\(') {
        $Warnings += "[UdonSharp] WARNING: [UdonSynced] found but no RequestSerialization(). Required for Manual sync mode."
    }
    # Check if SetOwner is called
    if ($MaskedSource -notmatch 'Networking\.SetOwner\s*\(|SetOwner\s*\(') {
        $Warnings += "[UdonSharp] WARNING: [UdonSynced] found but no Networking.SetOwner(). Ownership required to modify synced variables."
    }
}

# Check for VRCPlayerApi without validity check
if ($FileContent -match 'VRCPlayerApi\s+\w+\s*=') {
    if ($FileContent -notmatch '\.IsValid\s*\(\)|player\s*!=\s*null') {
        $Warnings += "[UdonSharp] WARNING: VRCPlayerApi used. Always check player != null && player.IsValid() before use."
    }
}

# Check for override on Unity standard callbacks (should NOT have override)
if ($FileContent -match 'override\s+void\s+(OnTriggerEnter|OnTriggerStay|OnTriggerExit|OnCollisionEnter|OnCollisionStay|OnCollisionExit|OnAnimatorMove|OnAnimatorIK)') {
    $Warnings += "[UdonSharp] WARNING: Unity callbacks (OnTriggerEnter etc.) should NOT use 'override'. Only VRChat events need override."
}

# Check for generic GetComponent (not exposed)
if ($FileContent -match 'GetComponent<UdonBehaviour>') {
    $Warnings += "[UdonSharp] BLOCKED: GetComponent<UdonBehaviour>() not exposed. Use (UdonBehaviour)GetComponent(typeof(UdonBehaviour)) instead."
}

# Check for System.Net / System.IO (blocked - use VRC downloaders)
if ($FileContent -match 'using\s+System\.(Net|IO)\b|System\.Net\.|System\.IO\.') {
    $Warnings += "[UdonSharp] BLOCKED: System.Net/System.IO not available. Use VRCStringDownloader or VRCImageDownloader instead. See references/web-loading.md."
}

# Sync bloat: too many synced variables (>5)
if ($SyncedCount -gt 5) {
    $Warnings += "[UdonSharp] SYNC-BLOAT: $SyncedCount synced variables detected (target: <5 per behaviour). Consider minimizing synced data. See references/sync-examples.md or rules/udonsharp-sync-selection.md."
}

# Sync bloat: large synced arrays (int[]/float[] instead of byte[]/short[])
$SyncedArrayFieldPrefixPattern = '^[ \t]*(?:(?:public|private|protected|internal|static|readonly)[ \t]+)*(?:int|float)[ \t]*\[\][ \t]+[A-Za-z_][A-Za-z0-9_]*[ \t]*(?:=|,|;)'
$LeadingAttributeGroupsPattern = '^[ \t]*(?<AttributeGroups>(?:\[(?:[^\[\]\r\n]|\[\])*\][ \t]*)+)(?<Remainder>.*)$'
$AttributeGroupPattern = '\[((?:[^\[\]\r\n]|\[\])*)\]'
$UdonSyncedInAttributeGroupPattern = '(?:^|,)[ \t]*UdonSynced(?:Attribute)?[ \t]*(?:$|,|\()'
$PreviousLineHasAttribute = $false
$FoundSyncedArrayField = $false
$Reader = [System.IO.StringReader]::new($MaskedSource)

try {
    while ($null -ne ($Line = $Reader.ReadLine())) {
        if (-not $PreviousLineHasAttribute -and $Line -notmatch '^[ \t]*\[') {
            continue
        }

        if ($PreviousLineHasAttribute -and $Line -match $SyncedArrayFieldPrefixPattern) {
            $FoundSyncedArrayField = $true
            break
        }

        $PreviousLineHasAttribute = $false
        $AttributeLineMatch = [regex]::Match($Line, $LeadingAttributeGroupsPattern)
        if ($AttributeLineMatch.Success) {
            $HasUdonSyncedAttribute = $false
            foreach ($AttributeGroupMatch in [regex]::Matches($AttributeLineMatch.Groups['AttributeGroups'].Value, $AttributeGroupPattern)) {
                if ($AttributeGroupMatch.Groups[1].Value -match $UdonSyncedInAttributeGroupPattern) {
                    $HasUdonSyncedAttribute = $true
                    break
                }
            }

            $Declaration = $AttributeLineMatch.Groups['Remainder'].Value
            if ($HasUdonSyncedAttribute -and $Declaration -match $SyncedArrayFieldPrefixPattern) {
                $FoundSyncedArrayField = $true
                break
            }
            if ($HasUdonSyncedAttribute -and $Declaration -match '^[ \t]*$') {
                $PreviousLineHasAttribute = $true
            }
        }
    }
} finally {
    $Reader.Dispose()
}

if ($FoundSyncedArrayField) {
    $Warnings += "[UdonSharp] SYNC-BLOAT: Synced int[]/float[] detected. Consider byte[] or short[] if value range allows."
}

# NoVariableSync + [UdonSynced] conflict
if ($HasNoVariableSync -and $SyncedCount -gt 0) {
    $Warnings += "[UdonSharp] ERROR: NoVariableSync mode but [UdonSynced] variables found. Remove [UdonSynced] or change sync mode."
}

# Check for ref parameter in method declaration
if ($FileContent -match '\b(void|int|float|bool|string|[A-Z][A-Za-z0-9_]*)\s+\w+\s*\(.*\bref\s+\w') {
    $Warnings += "[UdonSharp] BLOCKED: ref parameters not supported in UdonSharp. Use return values or synced fields instead."
}

# Check for out parameter in method declaration
if ($FileContent -match '\b(void|int|float|bool|string|[A-Z][A-Za-z0-9_]*)\s+\w+\s*\(.*\bout\s+\w') {
    $Warnings += "[UdonSharp] BLOCKED: out parameters not supported in UdonSharp. Use return values instead."
}

# Check for multi-dimensional arrays (T[,])
if ($FileContent -match '\w+\s*\[,') {
    $Warnings += "[UdonSharp] BLOCKED: Multi-dimensional arrays (T[,]) not supported. Use jagged arrays (T[][]) or flatten to 1D instead."
}

# Check for method overloading (same name, different signatures)
$MethodMatches = [regex]::Matches(
    $FileContent,
    '(?m)^\s*(?:public|private|protected|internal|override|virtual|static|\s)+\s+(?:void|int|float|bool|string|[A-Z][A-Za-z0-9_]*)\s+([A-Za-z_][A-Za-z0-9_]*)\s*\('
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
Write-Output $Input
