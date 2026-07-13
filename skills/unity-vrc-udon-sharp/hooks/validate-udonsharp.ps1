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

# Read and write the hook payload without PowerShell pipeline newline
# normalization. This keeps the documented passthrough contract byte-exact.
$HookInput = [Console]::In.ReadToEnd()

function Write-HookInput {
    [Console]::Out.Write($HookInput)
}

function Stop-Validation([string]$Code) {
    [Console]::Error.WriteLine("[UdonSharp] VALIDATOR-WARNING: validation skipped ($Code)")
    Write-HookInput
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
    Write-HookInput
    exit 0
}

# Check if file exists
if (-not (Test-Path -LiteralPath $FilePath -PathType Leaf)) {
    Write-HookInput
    exit 0
}

try {
    $FileContent = Get-Content -LiteralPath $FilePath -Raw -Encoding UTF8 -ErrorAction Stop
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
            [void]$Builder.Append('$', $DollarCount)
            $Index += $DollarCount
            continue
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
    $IdentifierPattern = '@?[_\p{L}\p{Nl}][_\p{L}\p{Nl}\p{Nd}\p{Pc}\p{Mn}\p{Mc}\p{Cf}]*'
    $BaseNames = New-Object System.Collections.Generic.List[string]
    $BaseNames.Add('UdonSharpBehaviour')
    $BaseNames.Add('UdonSharp\.UdonSharpBehaviour')
    $BaseNames.Add('global::UdonSharp\.UdonSharpBehaviour')

    $AliasPattern = 'using\s+(?<Alias>' + $IdentifierPattern + ')\s*=\s*(?<Target>(?:global::)?UdonSharp(?:\.UdonSharpBehaviour)?)\s*;'
    foreach ($AliasMatch in [regex]::Matches($MaskedSource, $AliasPattern)) {
        $AliasValue = $AliasMatch.Groups['Alias'].Value.TrimStart('@')
        $AliasName = '@?' + [regex]::Escape($AliasValue)
        if ($AliasMatch.Groups['Target'].Value.EndsWith('UdonSharpBehaviour')) {
            $BaseNames.Add($AliasName)
        } else {
            $BaseNames.Add($AliasName + '\.UdonSharpBehaviour')
        }
    }

    foreach ($BaseName in $BaseNames) {
        $ClassPattern = '\bclass\s+' + $IdentifierPattern + '\s*:\s*' + $BaseName + '(?=$|[,<{\s])'
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
$FlatSource = $MaskedSource -replace '[\r\n]', ' '

# Check if this is structurally an UdonSharp behaviour. External project base
# types are intentionally not resolved by this per-file hook.
if (-not (Test-UdonSharpBehaviourSource $FlatSource)) {
    Write-HookInput
    exit 0
}

# === Validation Rules ===
$Warnings = @()

# Check for blocked generics
if ($FlatSource -match 'List\s*<|Dictionary\s*<|HashSet\s*<|Queue\s*<|Stack\s*<') {
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

# Lambda expressions across logical lines. Mask every declaration expression
# body before looking for lambda arrows, including multiple members on one line.
$IdentifierPattern = '@?[_\p{L}\p{Nl}][_\p{L}\p{Nl}\p{Nd}\p{Pc}\p{Mn}\p{Mc}\p{Cf}]*'
$ModifierPattern = '^(public|private|protected|internal|static|abstract|virtual|sealed|new|override|extern|partial|async|unsafe|readonly)[ \t]+'
function Remove-LeadingAttributeSections([string]$Text) {
    $Text = $Text.Trim()
    while ($Text.StartsWith('[')) {
        $Depth = 0
        $End = -1
        for ($Position = 0; $Position -lt $Text.Length; $Position++) {
            if ($Text[$Position] -eq '[') { $Depth++ }
            elseif ($Text[$Position] -eq ']') {
                $Depth--
                if ($Depth -eq 0) {
                    $End = $Position
                    break
                }
            }
        }
        if ($End -lt 0) { return $Text }
        $Text = $Text.Substring($End + 1).Trim()
    }
    return $Text
}

function Get-MemberSegment([string]$Text, [int]$Arrow) {
    for ($Position = $Arrow - 1; $Position -ge 0; $Position--) {
        if ($Text[$Position] -eq ';' -or $Text[$Position] -eq '{' -or $Text[$Position] -eq '}') {
            return $Text.Substring($Position + 1, $Arrow - $Position - 1).Trim()
        }
    }
    return $Text.Substring(0, $Arrow).Trim()
}

function Find-MatchingOpenParen([string]$Text) {
    $Depth = 0
    for ($Position = $Text.Length - 1; $Position -ge 0; $Position--) {
        if ($Text[$Position] -eq ')') { $Depth++ }
        elseif ($Text[$Position] -eq '(') {
            $Depth--
            if ($Depth -eq 0) { return $Position }
        }
    }
    return -1
}

function Test-DeclarationArrow([string]$Text, [int]$Arrow) {
    $Segment = Remove-LeadingAttributeSections (Get-MemberSegment $Text $Arrow)
    if ($Segment -match '^(get|set|init)[ \t]*$') { return $true }

    $HadModifier = $false
    while ($Segment -match $ModifierPattern) {
        $Segment = $Segment.Substring($Matches[0].Length).Trim()
        $HadModifier = $true
    }
    if (-not $Segment -or $Segment -match '[=;]' -or
        $Segment -match '^(return|throw|yield|case|goto|new)([ \t]|$)') {
        return $false
    }

    if ($Segment.EndsWith(')')) {
        $Open = Find-MatchingOpenParen $Segment
        if ($Open -lt 0) { return $false }
        $Prefix = $Segment.Substring(0, $Open).Trim()
    } else {
        if ($Segment -match '[()]') { return $false }
        $Prefix = $Segment
    }

    if ($Prefix -match ('^(?<Return>.+?)[ \t]+(?<Name>' + $IdentifierPattern + ')$')) {
        return $true
    }
    return $HadModifier -and $Prefix -match ('^' + $IdentifierPattern + '$')
}

function Remove-DeclarationExpressionBodies([string]$Text) {
    $SearchFrom = 0
    $DeclarationMasked = $false
    while (($Arrow = $Text.IndexOf('=>', $SearchFrom, [System.StringComparison]::Ordinal)) -ge 0) {
        if ($DeclarationMasked) {
            $HasBoundary = $false
            for ($Position = $SearchFrom; $Position -lt $Arrow; $Position++) {
                if ($Text[$Position] -eq ';' -or $Text[$Position] -eq '{' -or $Text[$Position] -eq '}') {
                    $HasBoundary = $true
                    break
                }
            }
            if ($HasBoundary) { $DeclarationMasked = $false }
        }
        if (-not $DeclarationMasked -and (Test-DeclarationArrow $Text $Arrow)) {
            $Text = $Text.Remove($Arrow, 2).Insert($Arrow, '  ')
            $DeclarationMasked = $true
        }
        $SearchFrom = $Arrow + 2
    }
    return $Text
}

$LambdaCandidate = Remove-DeclarationExpressionBodies $FlatSource
$HasLambda = $LambdaCandidate -match '\)\s*=>\s*(?:\{|[^;{]+;)' -or
    $LambdaCandidate -match ('(^|[=(,\s])' + $IdentifierPattern + '\s*=>\s*(?:\{|[^;{]+;)')
if ($HasLambda) {
    $Warnings += "[UdonSharp] WARNING: Lambda expression detected. Use named methods instead."
}

function Get-SyncStats([string]$Source) {
    function Get-AttributeFlags([string]$Content) {
        $Compact = $Content -replace '[ \t\r\n]', ''
        $Target = ''
        if ($Compact -match '^(assembly|module|field|event|method|param|property|return|type|typevar):') {
            $Target = $Matches[1]
            $Compact = $Compact.Substring($Matches[0].Length)
        }

        $Synced = $false
        $NoVariableSync = $false
        $Segment = [System.Text.StringBuilder]::new()
        $Parens = 0
        $Brackets = 0
        $Braces = 0
        $Segments = [System.Collections.Generic.List[string]]::new()
        for ($Position = 0; $Position -lt $Compact.Length; $Position++) {
            $Character = $Compact[$Position]
            if ($Character -eq ',' -and $Parens -eq 0 -and $Brackets -eq 0 -and $Braces -eq 0) {
                $Segments.Add($Segment.ToString())
                [void]$Segment.Clear()
                continue
            }
            [void]$Segment.Append($Character)
            if ($Character -eq '(') { $Parens++ }
            elseif ($Character -eq ')' -and $Parens -gt 0) { $Parens-- }
            elseif ($Character -eq '[') { $Brackets++ }
            elseif ($Character -eq ']' -and $Brackets -gt 0) { $Brackets-- }
            elseif ($Character -eq '{') { $Braces++ }
            elseif ($Character -eq '}' -and $Braces -gt 0) { $Braces-- }
        }
        $Segments.Add($Segment.ToString())

        foreach ($Attribute in $Segments) {
            if (-not $Attribute) { continue }
            $Open = $Attribute.IndexOf('(')
            if ($Open -ge 0) {
                $Name = $Attribute.Substring(0, $Open)
                $Arguments = $Attribute.Substring($Open + 1, $Attribute.Length - $Open - 2)
            } else {
                $Name = $Attribute
                $Arguments = ''
            }
            $Name = $Name -replace '^global::', '' -replace '^UdonSharp\.', '' -replace 'Attribute$', ''

            if (($Target -eq '' -or $Target -eq 'field') -and $Name -eq 'UdonSynced') {
                $Synced = $true
            }
            if (($Target -eq '' -or $Target -eq 'type') -and $Name -eq 'UdonBehaviourSyncMode') {
                $Arguments = $Arguments -replace 'global::', '' -replace 'UdonSharp\.', ''
                if ($Arguments -eq 'BehaviourSyncMode.NoVariableSync') {
                    $NoVariableSync = $true
                }
            }
        }

        return [pscustomobject]@{
            Synced = $Synced
            NoVariableSync = $NoVariableSync
        }
    }

    function Reset-PendingDeclaration {
        $State.PendingSynced = $false
        $State.PendingNoVariableSync = $false
        [void]$State.DeclarationBuilder.Clear()
        $State.DeclarationParens = 0
        $State.DeclarationBrackets = 0
        $State.DeclarationBraces = 0
        $State.DeclarationHasAssignment = $false
        $State.DeclarationUtf8Bytes = 0
    }

    function Get-FieldInfo([string]$Declaration) {
        if ($Declaration -match '^((public|private|protected|internal|static|readonly|const|volatile|new) +)*(class|struct|interface|enum|delegate|event|record)( |$)') {
            return $null
        }

        $Parens = 0
        $Brackets = 0
        $Braces = 0
        $Angles = 0
        $DelimiterPosition = -1
        $Delimiter = [char]0
        for ($Position = 0; $Position -lt $Declaration.Length; $Position++) {
            $Character = $Declaration[$Position]
            $NextCharacter = if ($Position + 1 -lt $Declaration.Length) { $Declaration[$Position + 1] } else { [char]0 }
            if ($Character -eq '(') { $Parens++ }
            elseif ($Character -eq ')' -and $Parens -gt 0) { $Parens-- }
            elseif ($Character -eq '[') { $Brackets++ }
            elseif ($Character -eq ']' -and $Brackets -gt 0) { $Brackets-- }
            elseif ($Character -eq '{') { $Braces++ }
            elseif ($Character -eq '}' -and $Braces -gt 0) { $Braces-- }
            elseif ($Character -eq '<' -and $Parens -eq 0 -and $Brackets -eq 0 -and $Braces -eq 0) { $Angles++ }
            elseif ($Character -eq '>' -and $Angles -gt 0 -and $Parens -eq 0 -and $Brackets -eq 0 -and $Braces -eq 0) { $Angles-- }
            elseif ($Parens -eq 0 -and $Brackets -eq 0 -and $Braces -eq 0 -and $Angles -eq 0 -and
                    ($Character -eq '=' -or $Character -eq ',' -or $Character -eq ';')) {
                if ($Character -eq '=' -and $NextCharacter -eq '>') { return $null }
                $DelimiterPosition = $Position
                $Delimiter = $Character
                break
            }
        }
        if ($DelimiterPosition -lt 0) { return $null }

        $Header = (($Declaration.Substring(0, $DelimiterPosition)) -replace '[ \t\r\n]+', ' ').Trim()
        while ($Header -match '^(public|private|protected|internal|static|readonly|const|volatile|new) +') {
            $Header = $Header.Substring($Matches[0].Length)
        }
        $LastSpace = $Header.LastIndexOf(' ')
        if ($LastSpace -lt 1) { return $null }
        $Identifier = $Header.Substring($LastSpace + 1)
        if ($Identifier -notmatch '^@?[_\p{L}\p{Nl}][_\p{L}\p{Nl}\p{Nd}\p{Pc}\p{Mn}\p{Mc}\p{Cf}]*$') {
            return $null
        }
        $TypeName = $Header.Substring(0, $LastSpace).Trim()
        if (-not $TypeName) { return $null }
        $LargeArray = $TypeName -match '^(int|float) *\[ *\]$'

        $Count = if ($Delimiter -eq ',') { 2 } else { 1 }
        if ($Delimiter -eq ';') {
            return [pscustomobject]@{ Count = $Count; LargeArray = $LargeArray }
        }
        $Parens = 0
        $Brackets = 0
        $Braces = 0
        for ($Position = $DelimiterPosition + 1; $Position -lt $Declaration.Length; $Position++) {
            $Character = $Declaration[$Position]
            if ($Character -eq '(') { $Parens++ }
            elseif ($Character -eq ')' -and $Parens -gt 0) { $Parens-- }
            elseif ($Character -eq '[') { $Brackets++ }
            elseif ($Character -eq ']' -and $Brackets -gt 0) { $Brackets-- }
            elseif ($Character -eq '{') { $Braces++ }
            elseif ($Character -eq '}' -and $Braces -gt 0) { $Braces-- }
            elseif ($Character -eq ',' -and $Parens -eq 0 -and $Brackets -eq 0 -and $Braces -eq 0) { $Count++ }
            elseif ($Character -eq ';' -and $Parens -eq 0 -and $Brackets -eq 0 -and $Braces -eq 0) {
                return [pscustomobject]@{ Count = $Count; LargeArray = $LargeArray }
            }
        }
        return $null
    }

    function Complete-Declaration {
        $Declaration = ($State.DeclarationBuilder.ToString() -replace '[ \t\r\n]+', ' ').Trim()
        $IsClass = $Declaration -match '^((public|private|protected|internal|abstract|sealed|static|partial|new) +)*class( |$)'

        if ($State.PendingNoVariableSync -and $IsClass) {
            $State.HasNoVariableSync = $true
            Reset-PendingDeclaration
            return
        }
        $FieldInfo = if ($State.PendingSynced) { Get-FieldInfo $Declaration } else { $null }
        if ($null -ne $FieldInfo) {
            $State.SyncedCount += $FieldInfo.Count
            if ($FieldInfo.LargeArray) { $State.HasLargeSyncedArray = $true }
            Reset-PendingDeclaration
            return
        }
        Reset-PendingDeclaration
    }

    function Add-DeclarationFragment([string]$Text, [int]$Start) {
        if (-not ($State.PendingSynced -or $State.PendingNoVariableSync) -or $Start -ge $Text.Length) {
            return $Start
        }
        $Boundary = -1
        for ($Position = $Start; $Position -lt $Text.Length; $Position++) {
            $Character = $Text[$Position]
            $NextCharacter = if ($Position + 1 -lt $Text.Length) { $Text[$Position + 1] } else { [char]0 }
            if ($Character -eq '(') { $State.DeclarationParens++ }
            elseif ($Character -eq ')' -and $State.DeclarationParens -gt 0) { $State.DeclarationParens-- }
            elseif ($Character -eq '[') { $State.DeclarationBrackets++ }
            elseif ($Character -eq ']' -and $State.DeclarationBrackets -gt 0) { $State.DeclarationBrackets-- }
            elseif ($Character -eq '{') {
                if ($State.DeclarationParens -eq 0 -and $State.DeclarationBrackets -eq 0 -and
                    $State.DeclarationBraces -eq 0 -and -not $State.DeclarationHasAssignment) {
                    $Boundary = $Position
                    break
                }
                $State.DeclarationBraces++
            } elseif ($Character -eq '}' -and $State.DeclarationBraces -gt 0) {
                $State.DeclarationBraces--
            } elseif ($Character -eq '=' -and $NextCharacter -ne '>' -and
                      $State.DeclarationParens -eq 0 -and $State.DeclarationBrackets -eq 0 -and $State.DeclarationBraces -eq 0) {
                $State.DeclarationHasAssignment = $true
            } elseif ($Character -eq ';' -and $State.DeclarationParens -eq 0 -and
                      $State.DeclarationBrackets -eq 0 -and $State.DeclarationBraces -eq 0) {
                $Boundary = $Position
                break
            }
        }

        $Piece = if ($Boundary -ge 0) {
            $Text.Substring($Start, $Boundary - $Start + 1)
        } else {
            $Text.Substring($Start)
        }
        if ($State.DeclarationBuilder.Length -gt 0) {
            [void]$State.DeclarationBuilder.Append(' ')
            $State.DeclarationUtf8Bytes++
        }
        [void]$State.DeclarationBuilder.Append($Piece)
        $State.DeclarationUtf8Bytes += [System.Text.Encoding]::UTF8.GetByteCount($Piece)
        if ($State.DeclarationUtf8Bytes -gt 262144) { throw 'ATTRIBUTE_SCAN_FAILED' }
        if ($Boundary -ge 0) { Complete-Declaration }
        if ($Boundary -ge 0) { return $Boundary + 1 }
        return $Text.Length
    }

    function Find-AttributeAfterBoundary([string]$Text, [int]$Start) {
        $AfterBoundary = $false
        for ($Position = $Start; $Position -lt $Text.Length; $Position++) {
            $Character = $Text[$Position]
            if ($Character -eq ';' -or $Character -eq '{' -or $Character -eq '}') {
                $AfterBoundary = $true
                continue
            }
            if ($AfterBoundary -and ($Character -eq ' ' -or $Character -eq [char]9)) { continue }
            if ($AfterBoundary -and $Character -eq '[') { return $Position }
            if ($AfterBoundary) { $AfterBoundary = $false }
        }
        return $Text.Length
    }

    function Start-Attribute {
        $State.CollectingAttribute = $true
        [void]$State.AttributeContent.Clear()
        $State.AttributeParens = 0
        $State.AttributeBrackets = 0
        $State.AttributeBraces = 0
    }

    function Read-SourceLine([string]$Line) {
        $Position = 0
        while ($Position -lt $Line.Length) {
            if ($State.CollectingAttribute) {
                $Character = $Line[$Position]
                if ($Character -eq ']' -and $State.AttributeParens -eq 0 -and
                    $State.AttributeBrackets -eq 0 -and $State.AttributeBraces -eq 0) {
                    $Flags = Get-AttributeFlags $State.AttributeContent.ToString()
                    $State.PendingSynced = $State.PendingSynced -or $Flags.Synced
                    $State.PendingNoVariableSync = $State.PendingNoVariableSync -or $Flags.NoVariableSync
                    $State.CollectingAttribute = $false
                    [void]$State.AttributeContent.Clear()
                    $Position++
                    continue
                }

                [void]$State.AttributeContent.Append($Character)
                if ($Character -eq '(') { $State.AttributeParens++ }
                elseif ($Character -eq ')' -and $State.AttributeParens -gt 0) { $State.AttributeParens-- }
                elseif ($Character -eq '[') { $State.AttributeBrackets++ }
                elseif ($Character -eq ']' -and $State.AttributeBrackets -gt 0) { $State.AttributeBrackets-- }
                elseif ($Character -eq '{') { $State.AttributeBraces++ }
                elseif ($Character -eq '}' -and $State.AttributeBraces -gt 0) { $State.AttributeBraces-- }
                $Position++
                continue
            }

            while ($Position -lt $Line.Length -and ($Line[$Position] -eq ' ' -or $Line[$Position] -eq [char]9)) {
                $Position++
            }
            if ($Position -ge $Line.Length) { return }
            if (($State.PendingSynced -or $State.PendingNoVariableSync) -and $State.DeclarationBuilder.Length -gt 0) {
                $Position = Add-DeclarationFragment $Line $Position
                continue
            }
            if ($Line[$Position] -eq '[') {
                Start-Attribute
                $Position++
                continue
            }
            if ($State.PendingSynced -or $State.PendingNoVariableSync) {
                $Position = Add-DeclarationFragment $Line $Position
                continue
            }
            $Position = Find-AttributeAfterBoundary $Line $Position
            if ($Position -ge $Line.Length) { return }
        }
    }

    $State = @{
        PendingSynced = $false
        PendingNoVariableSync = $false
        DeclarationBuilder = [System.Text.StringBuilder]::new()
        DeclarationParens = 0
        DeclarationBrackets = 0
        DeclarationBraces = 0
        DeclarationHasAssignment = $false
        DeclarationUtf8Bytes = 0
        CollectingAttribute = $false
        AttributeContent = [System.Text.StringBuilder]::new()
        AttributeParens = 0
        AttributeBrackets = 0
        AttributeBraces = 0
        SyncedCount = 0
        HasNoVariableSync = $false
        HasLargeSyncedArray = $false
    }

    foreach ($Line in [regex]::Split($Source, '\r?\n')) {
        if ($State.CollectingAttribute) { [void]$State.AttributeContent.Append([char]10) }
        Read-SourceLine $Line
    }

    return [pscustomobject]@{
        SyncedCount = $State.SyncedCount
        HasNoVariableSync = $State.HasNoVariableSync
        HasLargeSyncedArray = $State.HasLargeSyncedArray
    }
}

try {
    $SyncStats = Get-SyncStats $MaskedSource
} catch {
    Stop-Validation 'ATTRIBUTE_SCAN_FAILED'
}
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

# Check for multi-dimensional arrays (T[,])
if ($MaskedSource -match '\w+\s*\[\s*,') {
    $Warnings += "[UdonSharp] BLOCKED: Multi-dimensional arrays (T[,]) not supported. Use jagged arrays (T[][]) or flatten to 1D instead."
}

# Check for method overloading (same name, different signatures). Scan logical
# member segments so a line break before '(' cannot hide an overload.
function Get-DeclarationMethodName([string]$Text) {
    $Declaration = Remove-LeadingAttributeSections $Text
    if ($Declaration -match '^(return|throw|yield|case|goto|new)([ \t]|$)') { return $null }
    while ($Declaration -match '^(public|private|protected|internal|static|abstract|virtual|sealed|new|override|extern|partial|async|unsafe|readonly)[ \t]+') {
        $Declaration = $Declaration.Substring($Matches[0].Length)
    }
    $Prefix = $Declaration.Trim()
    if (-not $Prefix -or $Prefix -match '[=;{}()]') { return $null }
    if ($Prefix -notmatch '^(?<Return>.+?)[ \t]+(?<Name>' + $IdentifierPattern + ')$') { return $null }
    if ($Matches['Return'].Trim() -match '^(return|throw|yield|case|goto|new)$') { return $null }
    $Name = $Matches['Name']
    if ($Name[0] -ne '@' -and $Name -match '^(if|for|foreach|while|switch|catch|using|lock|fixed|nameof|typeof|sizeof|checked|unchecked|delegate)$') {
        return $null
    }
    if ($Name[0] -eq '@') { return $Name.Substring(1) }
    return $Name
}

function Get-MethodNames([string]$Source) {
    $Names = [System.Collections.Generic.List[string]]::new()
    $Segment = [System.Text.StringBuilder]::new()
    $Parens = 0
    $Brackets = 0
    $SegmentInvalid = $false
    for ($Position = 0; $Position -lt $Source.Length; $Position++) {
        $Character = $Source[$Position]
        if ($Character -eq '[' -and $Parens -eq 0) { $Brackets++ }
        elseif ($Character -eq ']' -and $Parens -eq 0 -and $Brackets -gt 0) { $Brackets-- }

        if ($Character -eq '(' -and $Parens -eq 0 -and $Brackets -eq 0) {
            $Name = $null
            if (-not $SegmentInvalid) {
                $Name = Get-DeclarationMethodName $Segment.ToString()
            }
            if ($Name) { $Names.Add($Name) }
            [void]$Segment.Clear()
            $SegmentInvalid = $false
            $Parens = 1
            continue
        }
        if ($Character -eq '(' -and $Brackets -eq 0) {
            $Parens++
            continue
        }
        if ($Character -eq ')' -and $Brackets -eq 0 -and $Parens -gt 0) {
            $Parens--
            continue
        }

        if ($Parens -eq 0 -and $Brackets -eq 0 -and
            ($Character -eq ';' -or $Character -eq '{' -or $Character -eq '}')) {
            [void]$Segment.Clear()
            $SegmentInvalid = $false
            continue
        }
        if ($Parens -eq 0) {
            if ($Character -eq '=' -and $Brackets -eq 0) { $SegmentInvalid = $true }
            [void]$Segment.Append($Character)
            if ($Segment.Length -gt 1024) {
                [void]$Segment.Remove(0, $Segment.Length - 512)
            }
        }
    }
    return $Names.ToArray()
}

try {
    $MethodNames = @(Get-MethodNames $FlatSource)
} catch {
    Stop-Validation 'METHOD_SCAN_FAILED'
}
$OverloadedNames = @($MethodNames | Group-Object | Where-Object { $_.Count -gt 1 } | Select-Object -ExpandProperty Name)
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
Write-HookInput
