#!/bin/bash
# UdonSharp Code Validation Hook (Linux/macOS)
# Checks for common constraint violations in UdonSharp code.
#
# Usage: Called as PostToolUse hook when editing .cs files
# Input: JSON via stdin with tool_input.file_path
# Output: Warnings to stderr, original input to stdout

set -e

input=$(cat)
file_path=$(echo "$input" | jq -r '.tool_input.file_path // .tool_input.filePath // ""')

# Only process .cs files
if [[ ! "$file_path" =~ \.cs$ ]]; then
    echo "$input"
    exit 0
fi

# Check if file exists
if [[ ! -f "$file_path" ]]; then
    echo "$input"
    exit 0
fi

# Check if this is an UdonSharp file
if ! grep -q "using UdonSharp\|UdonSharpBehaviour" "$file_path" 2>/dev/null; then
    echo "$input"
    exit 0
fi

# === Validation Rules ===
warnings=()

# Blocked generics
if grep -qE "List<|Dictionary<|HashSet<|Queue<|Stack<" "$file_path"; then
    warnings+=("[UdonSharp] BLOCKED: Generic collections (List<T>, Dictionary<K,V>) not supported. Use arrays or DataList/DataDictionary.")
fi

# async/await
if grep -qE "\basync\b|\bawait\b" "$file_path"; then
    warnings+=("[UdonSharp] BLOCKED: async/await not supported. Use SendCustomEventDelayedSeconds() instead.")
fi

# try/catch
if grep -qE "\btry\s*\{|\bcatch\s*\(|\bfinally\s*\{" "$file_path"; then
    warnings+=("[UdonSharp] BLOCKED: try/catch/finally not supported. Use defensive null checks and validation.")
fi

# LINQ
if grep -qE "\.Where\(|\.Select\(|\.OrderBy\(|\.FirstOrDefault\(|\.Any\(|\.All\(" "$file_path"; then
    warnings+=("[UdonSharp] BLOCKED: LINQ not supported. Use manual for loops.")
fi

# yield return (coroutines)
if grep -qE "\byield\s+return\b" "$file_path"; then
    warnings+=("[UdonSharp] BLOCKED: Coroutines (yield return) not supported. Use SendCustomEventDelayedSeconds().")
fi

# interface declaration
if grep -qE "^\s*(public\s+)?interface\s+" "$file_path"; then
    warnings+=("[UdonSharp] BLOCKED: Interfaces not supported. Use base class inheritance or SendCustomEvent pattern.")
fi

# StartCoroutine
if grep -qE "StartCoroutine\s*\(" "$file_path"; then
    warnings+=("[UdonSharp] BLOCKED: StartCoroutine not available. Use SendCustomEventDelayedSeconds() instead.")
fi

# Check for AddListener (not supported - delegates blocked)
if grep -qE "\.AddListener\s*\(" "$file_path"; then
    warnings+=("[UdonSharp] BLOCKED: AddListener() not supported. Use Inspector OnClick -> SendCustomEvent instead.")
fi

# Lambda expressions
if grep -qE "=>\s*\{|=>\s*[^;{]+;" "$file_path"; then
    # Exclude property getters/setters (get => / set =>)
    if grep -qE "\)\s*=>" "$file_path"; then
        warnings+=("[UdonSharp] WARNING: Lambda expression detected. Use named methods instead.")
    fi
fi

# Networking issues
if grep -qE "\[UdonSynced\]" "$file_path"; then
    if ! grep -qE "RequestSerialization\s*\(" "$file_path"; then
        warnings+=("[UdonSharp] WARNING: [UdonSynced] found but no RequestSerialization(). Required for Manual sync mode.")
    fi
    if ! grep -qE "Networking\.SetOwner\s*\(|SetOwner\s*\(" "$file_path"; then
        warnings+=("[UdonSharp] WARNING: [UdonSynced] found but no Networking.SetOwner(). Ownership required to modify synced variables.")
    fi
fi

# VRCPlayerApi without validity check
if grep -qE "VRCPlayerApi\s+\w+\s*=" "$file_path"; then
    if ! grep -qE "\.IsValid\s*\(\)|player\s*!=\s*null" "$file_path"; then
        warnings+=("[UdonSharp] WARNING: VRCPlayerApi used. Always check player != null && player.IsValid() before use.")
    fi
fi

# Check for override on Unity standard callbacks (should NOT have override)
if grep -qE "override\s+void\s+(OnTriggerEnter|OnTriggerStay|OnTriggerExit|OnCollisionEnter|OnCollisionStay|OnCollisionExit|OnAnimatorMove|OnAnimatorIK)" "$file_path"; then
    warnings+=("[UdonSharp] WARNING: Unity callbacks (OnTriggerEnter etc.) should NOT use 'override'. Only VRChat events need override.")
fi

# Generic GetComponent<UdonBehaviour> (not exposed)
if grep -qE "GetComponent<UdonBehaviour>" "$file_path"; then
    warnings+=("[UdonSharp] BLOCKED: GetComponent<UdonBehaviour>() not exposed. Use (UdonBehaviour)GetComponent(typeof(UdonBehaviour)) instead.")
fi

# System.Net / System.IO (blocked - use VRC downloaders)
if grep -qE "using\s+System\.(Net|IO)\b|System\.Net\.|System\.IO\." "$file_path"; then
    warnings+=("[UdonSharp] BLOCKED: System.Net/System.IO not available. Use VRCStringDownloader or VRCImageDownloader instead. See references/web-loading.md.")
fi

# Sync bloat: too many synced variables (>5)
synced_count=$(grep -c '\[UdonSynced\]' "$file_path" 2>/dev/null) || synced_count=0
if [[ "$synced_count" -gt 5 ]]; then
    warnings+=("[UdonSharp] SYNC-BLOAT: $synced_count synced variables detected (target: <5 per behaviour). Consider minimizing synced data. See references/sync-examples.md or rules/udonsharp-sync-selection.md.")
fi

# Sync bloat: large synced arrays (int[]/float[] instead of byte[]/short[])
if grep -qE '\[UdonSynced\]' "$file_path" && \
   grep -qE '(int|float)\[\]' "$file_path"; then
    # Check if the array declaration is near [UdonSynced]
    if grep -B1 '(int|float)\[\]' "$file_path" | grep -qE '\[UdonSynced\]'; then
        warnings+=("[UdonSharp] SYNC-BLOAT: Synced int[]/float[] detected. Consider byte[] or short[] if value range allows.")
    fi
fi

# NoVariableSync + [UdonSynced] conflict
if grep -qE 'NoVariableSync' "$file_path" && \
   grep -qE '\[UdonSynced\]' "$file_path"; then
    warnings+=("[UdonSharp] ERROR: NoVariableSync mode but [UdonSynced] variables found. Remove [UdonSynced] or change sync mode.")
fi

# Output warnings
if [[ ${#warnings[@]} -gt 0 ]]; then
    echo "" >&2
    echo "=== UdonSharp Validation Warnings ===" >&2
    for warning in "${warnings[@]}"; do
        echo "$warning" >&2
    done
    echo "===================================" >&2
    echo "" >&2
fi

# Always output original input to allow the edit to proceed
echo "$input"
