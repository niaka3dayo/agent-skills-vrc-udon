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
if (-not (Test-Path $FilePath)) {
    Write-Output $Input
    exit 0
}

$FileContent = Get-Content -Path $FilePath -Raw

# Check if this is an UdonSharp file
if ($FileContent -notmatch 'using UdonSharp|UdonSharpBehaviour') {
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

# Check for potential networking issues
if ($FileContent -match '\[UdonSynced\]') {
    # Check if RequestSerialization is called
    if ($FileContent -notmatch 'RequestSerialization\s*\(') {
        $Warnings += "[UdonSharp] WARNING: [UdonSynced] found but no RequestSerialization(). Required for Manual sync mode."
    }
    # Check if SetOwner is called
    if ($FileContent -notmatch 'Networking\.SetOwner\s*\(|SetOwner\s*\(') {
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
$SyncedCount = ([regex]::Matches($FileContent, '\[UdonSynced\]')).Count
if ($SyncedCount -gt 5) {
    $Warnings += "[UdonSharp] SYNC-BLOAT: $SyncedCount synced variables detected (target: <5 per behaviour). Consider minimizing synced data. See references/sync-examples.md or rules/udonsharp-sync-selection.md."
}

# Sync bloat: large synced arrays (int[]/float[] instead of byte[]/short[])
if ($FileContent -match '\[UdonSynced\]') {
    # Check for synced int[]/float[] patterns (UdonSynced on preceding line or same line)
    if ($FileContent -match '\[UdonSynced\][^\r\n]*\b(int|float)\[\]') {
        $Warnings += "[UdonSharp] SYNC-BLOAT: Synced int[]/float[] detected. Consider byte[] or short[] if value range allows."
    }
}

# NoVariableSync + [UdonSynced] conflict
if ($FileContent -match 'NoVariableSync' -and $FileContent -match '\[UdonSynced\]') {
    $Warnings += "[UdonSharp] ERROR: NoVariableSync mode but [UdonSynced] variables found. Remove [UdonSynced] or change sync mode."
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
