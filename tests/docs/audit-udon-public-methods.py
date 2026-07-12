#!/usr/bin/env python3
"""Audit public UdonSharp method exposure in C# and Markdown examples.

This is a dependency-free, deliberately narrow lexer and declaration audit. It
does not try to compile C#. It recognizes enough valid syntax to classify every
lexical ``public`` declaration, bind the exact VRChat ``NetworkCallable``
attribute, and fail closed when a relevant construct is malformed.
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
import re
import sys
import unicodedata
from typing import Iterable


UNITY_CALLBACK_SIGNATURES = {
    "FixedUpdate": ("void", ()),
    "LateUpdate": ("void", ()),
    "OnAnimatorIK": ("void", (("System", "Int32"),)),
    "OnAnimatorMove": ("void", ()),
    "OnAudioFilterRead": ("void", (("System", "Single", "[]"), ("System", "Int32"))),
    "OnBecameInvisible": ("void", ()),
    "OnBecameVisible": ("void", ()),
    "OnCollisionEnter": ("void", (("UnityEngine", "Collision"),)),
    "OnCollisionEnter2D": ("void", (("UnityEngine", "Collision2D"),)),
    "OnCollisionExit": ("void", (("UnityEngine", "Collision"),)),
    "OnCollisionExit2D": ("void", (("UnityEngine", "Collision2D"),)),
    "OnCollisionStay": ("void", (("UnityEngine", "Collision"),)),
    "OnCollisionStay2D": ("void", (("UnityEngine", "Collision2D"),)),
    "OnControllerColliderHit": ("void", (("UnityEngine", "ControllerColliderHit"),)),
    "OnDestroy": ("void", ()),
    "OnDisable": ("void", ()),
    "OnDrawGizmos": ("void", ()),
    "OnDrawGizmosSelected": ("void", ()),
    "OnEnable": ("void", ()),
    "OnGUI": ("void", ()),
    "OnJointBreak": ("void", (("System", "Single"),)),
    "OnJointBreak2D": ("void", (("UnityEngine", "Joint2D"),)),
    "OnMouseDown": ("void", ()),
    "OnMouseDrag": ("void", ()),
    "OnMouseEnter": ("void", ()),
    "OnMouseExit": ("void", ()),
    "OnMouseOver": ("void", ()),
    "OnMouseUp": ("void", ()),
    "OnMouseUpAsButton": ("void", ()),
    "OnParticleCollision": ("void", (("UnityEngine", "GameObject"),)),
    "OnParticleSystemStopped": ("void", ()),
    "OnParticleTrigger": ("void", ()),
    "OnParticleUpdateJobScheduled": (
        "void",
        (("UnityEngine", "ParticleSystemJobs", "ParticleSystemJobData"),),
    ),
    "OnPostRender": ("void", ()),
    "OnPreCull": ("void", ()),
    "OnPreRender": ("void", ()),
    "OnRenderImage": ("void", (
        ("UnityEngine", "RenderTexture"),
        ("UnityEngine", "RenderTexture"),
    )),
    "OnRenderObject": ("void", ()),
    "OnTransformChildrenChanged": ("void", ()),
    "OnTransformParentChanged": ("void", ()),
    "OnTriggerEnter": ("void", (("UnityEngine", "Collider"),)),
    "OnTriggerEnter2D": ("void", (("UnityEngine", "Collider2D"),)),
    "OnTriggerExit": ("void", (("UnityEngine", "Collider"),)),
    "OnTriggerExit2D": ("void", (("UnityEngine", "Collider2D"),)),
    "OnTriggerStay": ("void", (("UnityEngine", "Collider"),)),
    "OnTriggerStay2D": ("void", (("UnityEngine", "Collider2D"),)),
    "OnValidate": ("void", ()),
    "OnWillRenderObject": ("void", ()),
    "Start": ("void", ()),
    "Update": ("void", ()),
}

# Exact public virtual stubs shipped by UdonSharpBehaviour in Worlds SDK 3.10.4.
# Each name maps to one or more (return type, parameter types) signatures.
SDK_CALLBACK_SIGNATURES = {
    "InputDrop": (("void", (("System", "Boolean"), ("VRC", "Udon", "Common", "UdonInputEventArgs"))),),
    "InputGrab": (("void", (("System", "Boolean"), ("VRC", "Udon", "Common", "UdonInputEventArgs"))),),
    "InputJump": (("void", (("System", "Boolean"), ("VRC", "Udon", "Common", "UdonInputEventArgs"))),),
    "InputLookHorizontal": (("void", (("System", "Single"), ("VRC", "Udon", "Common", "UdonInputEventArgs"))),),
    "InputLookVertical": (("void", (("System", "Single"), ("VRC", "Udon", "Common", "UdonInputEventArgs"))),),
    "InputMoveHorizontal": (("void", (("System", "Single"), ("VRC", "Udon", "Common", "UdonInputEventArgs"))),),
    "InputMoveVertical": (("void", (("System", "Single"), ("VRC", "Udon", "Common", "UdonInputEventArgs"))),),
    "InputUse": (("void", (("System", "Boolean"), ("VRC", "Udon", "Common", "UdonInputEventArgs"))),),
    "Interact": (("void", ()),),
    "MidiControlChange": (("void", (("System", "Int32"), ("System", "Int32"), ("System", "Int32"))),),
    "MidiNoteOff": (("void", (("System", "Int32"), ("System", "Int32"), ("System", "Int32"))),),
    "MidiNoteOn": (("void", (("System", "Int32"), ("System", "Int32"), ("System", "Int32"))),),
    "OnAsyncGpuReadbackComplete": (("void", (("VRC", "SDK3", "Rendering", "VRCAsyncGPUReadbackRequest"),)),),
    "OnAvatarChanged": (("void", (("VRC", "SDKBase", "VRCPlayerApi"),)),),
    "OnAvatarEyeHeightChanged": (("void", (("VRC", "SDKBase", "VRCPlayerApi"), ("System", "Single"))),),
    "OnContactEnter": (("void", (("VRC", "Dynamics", "ContactEnterInfo"),)),),
    "OnContactExit": (("void", (("VRC", "Dynamics", "ContactExitInfo"),)),),
    "OnControllerColliderHitPlayer": (("void", (("VRC", "SDK3", "ControllerColliderPlayerHit"),)),),
    "OnDeserialization": (
        ("void", ()),
        ("void", (("VRC", "Udon", "Common", "DeserializationResult"),)),
    ),
    "OnDroneTriggerEnter": (("void", (("VRC", "SDKBase", "VRCDroneApi"),)),),
    "OnDroneTriggerExit": (("void", (("VRC", "SDKBase", "VRCDroneApi"),)),),
    "OnDroneTriggerStay": (("void", (("VRC", "SDKBase", "VRCDroneApi"),)),),
    "OnDrop": (("void", ()),),
    "OnImageLoadError": (("void", (("VRC", "SDK3", "Image", "IVRCImageDownload"),)),),
    "OnImageLoadSuccess": (("void", (("VRC", "SDK3", "Image", "IVRCImageDownload"),)),),
    "OnInputMethodChanged": (("void", (("VRC", "SDKBase", "VRCInputMethod"),)),),
    "OnLanguageChanged": (("void", (("System", "String"),)),),
    "OnListAvailableProducts": (("void", (("VRC", "Economy", "IProduct", "[]"),)),),
    "OnListProductOwners": (("void", (("VRC", "Economy", "IProduct"), ("System", "String", "[]"))),),
    "OnListPurchases": (("void", (("VRC", "Economy", "IProduct", "[]"), ("VRC", "SDKBase", "VRCPlayerApi"))),),
    "OnMasterTransferred": (("void", (("VRC", "SDKBase", "VRCPlayerApi"),)),),
    "OnOwnershipRequest": (("bool", (("VRC", "SDKBase", "VRCPlayerApi"), ("VRC", "SDKBase", "VRCPlayerApi"))),),
    "OnOwnershipTransferred": (("void", (("VRC", "SDKBase", "VRCPlayerApi"),)),),
    "OnPersistenceUsageUpdated": (("void", ()),),
    "OnPhysBoneGrabbed": (("void", (("VRC", "Dynamics", "PhysBoneGrabbedInfo"),)),),
    "OnPhysBonePosed": (("void", (("VRC", "Dynamics", "PhysBonePosedInfo"),)),),
    "OnPhysBoneReleased": (("void", (("VRC", "Dynamics", "PhysBoneReleasedInfo"),)),),
    "OnPhysBoneUnPosed": (("void", (("VRC", "Dynamics", "PhysBoneUnPosedInfo"),)),),
    "OnPickup": (("void", ()),),
    "OnPickupUseDown": (("void", ()),),
    "OnPickupUseUp": (("void", ()),),
    "OnPlayerCollisionEnter": (("void", (("VRC", "SDKBase", "VRCPlayerApi"),)),),
    "OnPlayerCollisionExit": (("void", (("VRC", "SDKBase", "VRCPlayerApi"),)),),
    "OnPlayerCollisionStay": (("void", (("VRC", "SDKBase", "VRCPlayerApi"),)),),
    "OnPlayerDataStorageExceeded": (("void", (("VRC", "SDKBase", "VRCPlayerApi"),)),),
    "OnPlayerDataStorageWarning": (("void", (("VRC", "SDKBase", "VRCPlayerApi"),)),),
    "OnPlayerDataUpdated": (("void", (
        ("VRC", "SDKBase", "VRCPlayerApi"),
        ("VRC", "SDK3", "Persistence", "PlayerData", "Info", "[]"),
    )),),
    "OnPlayerJoined": (("void", (("VRC", "SDKBase", "VRCPlayerApi"),)),),
    "OnPlayerLeft": (("void", (("VRC", "SDKBase", "VRCPlayerApi"),)),),
    "OnPlayerObjectStorageExceeded": (("void", (("VRC", "SDKBase", "VRCPlayerApi"),)),),
    "OnPlayerObjectStorageWarning": (("void", (("VRC", "SDKBase", "VRCPlayerApi"),)),),
    "OnPlayerParticleCollision": (("void", (("VRC", "SDKBase", "VRCPlayerApi"),)),),
    "OnPlayerRespawn": (("void", (("VRC", "SDKBase", "VRCPlayerApi"),)),),
    "OnPlayerRestored": (("void", (("VRC", "SDKBase", "VRCPlayerApi"),)),),
    "OnPlayerSuspendChanged": (("void", (("VRC", "SDKBase", "VRCPlayerApi"),)),),
    "OnPlayerTriggerEnter": (("void", (("VRC", "SDKBase", "VRCPlayerApi"),)),),
    "OnPlayerTriggerExit": (("void", (("VRC", "SDKBase", "VRCPlayerApi"),)),),
    "OnPlayerTriggerStay": (("void", (("VRC", "SDKBase", "VRCPlayerApi"),)),),
    "OnPostSerialization": (("void", (("VRC", "Udon", "Common", "SerializationResult"),)),),
    "OnPreSerialization": (("void", ()),),
    "OnProductEvent": (("void", (("VRC", "Economy", "IProduct"), ("VRC", "SDKBase", "VRCPlayerApi"))),),
    "OnPurchaseConfirmed": (("void", (("VRC", "Economy", "IProduct"), ("VRC", "SDKBase", "VRCPlayerApi"), ("System", "Boolean"))),),
    "OnPurchaseConfirmedMultiple": (("void", (("VRC", "Economy", "IProduct"), ("VRC", "SDKBase", "VRCPlayerApi"), ("System", "Boolean"), ("System", "Int32"))),),
    "OnPurchaseExpired": (("void", (("VRC", "Economy", "IProduct"), ("VRC", "SDKBase", "VRCPlayerApi"))),),
    "OnPurchasesLoaded": (("void", (("VRC", "Economy", "IProduct", "[]"), ("VRC", "SDKBase", "VRCPlayerApi"))),),
    "OnScreenUpdate": (("void", (("VRC", "SDK3", "Platform", "ScreenUpdateData"),)),),
    "OnSpawn": (("void", ()),),
    "OnStationEntered": (("void", (("VRC", "SDKBase", "VRCPlayerApi"),)),),
    "OnStationExited": (("void", (("VRC", "SDKBase", "VRCPlayerApi"),)),),
    "OnStringLoadError": (("void", (("VRC", "SDK3", "StringLoading", "IVRCStringDownload"),)),),
    "OnStringLoadSuccess": (("void", (("VRC", "SDK3", "StringLoading", "IVRCStringDownload"),)),),
    "OnVRCCameraSettingsChanged": (("void", (("VRC", "SDK3", "Rendering", "VRCCameraSettings"),)),),
    "OnVRCPlusMassGift": (("void", (("VRC", "SDKBase", "VRCPlayerApi"), ("System", "Int32"))),),
    "OnVRCQualitySettingsChanged": (("void", ()),),
    "OnVideoEnd": (("void", ()),),
    "OnVideoError": (("void", (("VRC", "SDK3", "Components", "Video", "VideoError"),)),),
    "OnVideoLoop": (("void", ()),),
    "OnVideoPause": (("void", ()),),
    "OnVideoPlay": (("void", ()),),
    "OnVideoReady": (("void", ()),),
    "OnVideoStart": (("void", ()),),
    "PostLateUpdate": (("void", ()),),
}

METHOD_MODIFIERS = {
    "abstract",
    "async",
    "extern",
    "new",
    "override",
    "partial",
    "readonly",
    "sealed",
    "static",
    "unsafe",
    "virtual",
}

TYPE_KEYWORDS = {"class", "interface", "record", "struct"}
ALL_TYPE_KEYWORDS = TYPE_KEYWORDS | {"enum"}
CSHARP_FENCE_LANGUAGES = {"c#", "cs", "csharp"}
NETWORK_CALLABLE_TYPE = (
    "VRC",
    "SDK3",
    "UdonNetworkCalling",
    "NetworkCallableAttribute",
)
UDONSHARP_BEHAVIOUR_TYPE = ("UdonSharp", "UdonSharpBehaviour")
UNITY_CALLBACK_BASE_TYPES = {
    ("UnityEngine", "MonoBehaviour"),
    ("UnityEngine", "ScriptableObject"),
    ("UnityEditor", "AssetPostprocessor"),
    ("UnityEditor", "Editor"),
    ("UnityEditor", "EditorWindow"),
}

RESERVED_KEYWORDS = {
    "abstract", "as", "base", "bool", "break", "byte", "case", "catch",
    "char", "checked", "class", "const", "continue", "decimal", "default",
    "delegate", "do", "double", "else", "enum", "event", "explicit",
    "extern", "false", "finally", "fixed", "float", "for", "foreach",
    "goto", "if", "implicit", "in", "int", "interface", "internal", "is",
    "lock", "long", "namespace", "new", "null", "object", "operator", "out",
    "override", "params", "private", "protected", "public", "readonly", "ref",
    "return", "sbyte", "sealed", "short", "sizeof", "stackalloc", "static",
    "string", "struct", "switch", "this", "throw", "true", "try", "typeof",
    "uint", "ulong", "unchecked", "unsafe", "ushort", "using", "virtual",
    "void", "volatile", "while",
}


class SourceError(Exception):
    """A malformed or unclassified construct with a source line."""

    def __init__(self, line: int, message: str) -> None:
        super().__init__(message)
        self.line = line
        self.message = message


@dataclass(frozen=True)
class Token:
    value: str
    raw: str
    line: int
    kind: str


@dataclass(frozen=True)
class TypeContext:
    name: str
    bases: frozenset[str]
    base_names: tuple[tuple[str, ...], ...]
    namespace: tuple[str, ...]
    type_path: tuple[str, ...]
    imports: frozenset[tuple[str, ...]]
    aliases: tuple[tuple[str, tuple[str, ...]], ...]


@dataclass(frozen=True)
class Parameter:
    type_name: str
    modifiers: frozenset[str]
    has_default: bool
    supported: bool
    bound_type: tuple[str, ...] | None


@dataclass(frozen=True)
class Method:
    name: str
    display_name: str
    return_type: str
    modifiers: frozenset[str]
    parameterless: bool
    parameters: tuple[Parameter, ...]
    access: str
    generic: bool
    network_callable_occurrences: tuple[int, ...]
    line: int
    context: TypeContext | None


@dataclass(frozen=True)
class Declaration:
    kind: str
    line: int
    method: Method | None = None


@dataclass(frozen=True)
class NetworkCallableOccurrence:
    token_index: int
    line: int


@dataclass(frozen=True)
class SourceSegment:
    text: str
    first_line: int


@dataclass(frozen=True)
class MarkdownContainer:
    parts: tuple[tuple[str, int], ...]


@dataclass(frozen=True)
class MarkdownFence:
    char: str
    length: int
    is_csharp: bool
    line: int
    container: MarkdownContainer


def _spelled(token: Token, value: str) -> bool:
    """Return true only for an unescaped, non-verbatim spelling."""
    return token.value == value and token.raw == value


def _is_identifier_start(char: str) -> bool:
    return char == "_" or unicodedata.category(char) in {
        "Lu", "Ll", "Lt", "Lm", "Lo", "Nl",
    }


def _is_identifier_continue(char: str) -> bool:
    return _is_identifier_start(char) or unicodedata.category(char) in {
        "Mn", "Mc", "Nd", "Pc", "Cf",
    }


def _unicode_escape(source: str, index: int, line: int) -> tuple[str, int] | None:
    if source.startswith("\\u", index):
        length = 4
    elif source.startswith("\\U", index):
        length = 8
    else:
        return None
    end = index + 2 + length
    digits = source[index + 2:end]
    if len(digits) != length or re.fullmatch(r"[0-9A-Fa-f]+", digits) is None:
        raise SourceError(line, "invalid Unicode escape in identifier")
    codepoint = int(digits, 16)
    try:
        return chr(codepoint), end
    except ValueError as error:
        raise SourceError(line, "invalid Unicode code point in identifier") from error


def _read_identifier(source: str, start: int, line: int) -> tuple[Token, int] | None:
    index = start
    verbatim = False
    escaped = False
    raw_parts: list[str] = []
    value_parts: list[str] = []

    if source[index] == "@":
        verbatim = True
        raw_parts.append("@")
        index += 1
        if index >= len(source):
            return None

    unicode_escape = _unicode_escape(source, index, line) if source[index] == "\\" else None
    if unicode_escape is not None:
        char, end = unicode_escape
        if not _is_identifier_start(char):
            return None
        escaped = True
        raw_parts.append(source[index:end])
        value_parts.append(char)
        index = end
    elif _is_identifier_start(source[index]):
        raw_parts.append(source[index])
        value_parts.append(source[index])
        index += 1
    else:
        return None

    while index < len(source):
        if source[index] == "\\":
            unicode_escape = _unicode_escape(source, index, line)
            if unicode_escape is None:
                break
            char, end = unicode_escape
            if not _is_identifier_continue(char):
                raise SourceError(line, "invalid Unicode escape in identifier")
            escaped = True
            raw_parts.append(source[index:end])
            value_parts.append(char)
            index = end
            continue
        if not _is_identifier_continue(source[index]):
            break
        raw_parts.append(source[index])
        value_parts.append(source[index])
        index += 1

    raw = "".join(raw_parts)
    value = "".join(value_parts)
    kind = "keyword" if not verbatim and not escaped and value in RESERVED_KEYWORDS else "identifier"
    return Token(value, raw, line, kind), index


def _skip_quoted(
    source: str,
    start: int,
    line: int,
    *,
    verbatim: bool,
) -> tuple[int, int]:
    quote = source[start]
    quote_count = 1
    while start + quote_count < len(source) and source[start + quote_count] == quote:
        quote_count += 1

    if quote == '"' and quote_count >= 3:
        delimiter = '"' * quote_count
        end = source.find(delimiter, start + quote_count)
        if end < 0:
            raise SourceError(line, "unterminated raw string literal")
        literal_end = end + quote_count
        return literal_end, line + source[start:literal_end].count("\n")

    index = start + 1
    while index < len(source):
        char = source[index]
        if char == "\n":
            if not verbatim:
                raise SourceError(line, "unterminated string literal")
            line += 1
        if verbatim and quote == '"' and char == '"':
            if index + 1 < len(source) and source[index + 1] == '"':
                index += 2
                continue
            return index + 1, line
        if not verbatim and char == "\\":
            index += 2
            continue
        if char == quote:
            return index + 1, line
        index += 1
    raise SourceError(line, "unterminated string literal")


def lex_csharp(source: str, first_line: int = 1) -> list[Token]:
    """Return declaration-relevant tokens without comments or literal contents."""
    tokens: list[Token] = []
    index = 0
    line = first_line

    while index < len(source):
        char = source[index]

        if char.isspace():
            if char == "\n":
                line += 1
            index += 1
            continue

        if source.startswith("//", index):
            newline = source.find("\n", index + 2)
            if newline < 0:
                break
            index = newline
            continue

        if source.startswith("/*", index):
            end = source.find("*/", index + 2)
            if end < 0:
                raise SourceError(line, "unterminated block comment")
            end += 2
            line += source[index:end].count("\n")
            index = end
            continue

        if char in {"$", "@"}:
            prefix_end = index
            while prefix_end < len(source) and source[prefix_end] in {"$", "@"}:
                prefix_end += 1
            if prefix_end < len(source) and source[prefix_end] == '"':
                verbatim = "@" in source[index:prefix_end]
                literal_line = line
                index, line = _skip_quoted(source, prefix_end, line, verbatim=verbatim)
                tokens.append(Token("<literal>", "<literal>", literal_line, "literal"))
                continue

        if char in {'"', "'"}:
            literal_line = line
            index, line = _skip_quoted(source, index, line, verbatim=False)
            tokens.append(Token("<literal>", "<literal>", literal_line, "literal"))
            continue

        identifier = _read_identifier(source, index, line) if (
            char == "@" or char == "\\" or _is_identifier_start(char)
        ) else None
        if identifier is not None:
            token, index = identifier
            tokens.append(token)
            continue

        if char.isdigit():
            end = index + 1
            while end < len(source) and (source[end].isalnum() or source[end] in "._"):
                end += 1
            raw = source[index:end]
            tokens.append(Token(raw, raw, line, "number"))
            index = end
            continue

        two_chars = source[index:index + 2]
        if two_chars in {"=>", "::", "??", "?.", "==", "!=", "<=", ">=", "++", "--"}:
            tokens.append(Token(two_chars, two_chars, line, "punctuation"))
            index += 2
            continue

        tokens.append(Token(char, char, line, "punctuation"))
        index += 1

    return tokens


def _strip_blockquotes(line: str) -> tuple[int, str]:
    depth = 0
    remaining = line
    while True:
        match = re.match(r"^[ ]{0,3}>[ \t]?", remaining)
        if match is None:
            return depth, remaining
        depth += 1
        remaining = remaining[match.end():]


def _advance_column(text: str, column: int) -> int:
    for char in text:
        column = column + 1 if char != "\t" else column + (4 - column % 4)
    return column


def _list_marker(line: str, initial_column: int) -> tuple[int, str, int] | None:
    """Strip one CommonMark list marker and return its content indentation."""
    match = re.match(r"^([ ]{0,3})([-+*]|[0-9]{1,9}[.)])(?:([ \t]+)|$)", line)
    if match is None:
        return None
    whitespace = match.group(3) or ""
    marker_end = len(match.group(1)) + len(match.group(2))
    marker_end_column = initial_column + marker_end
    column = marker_end_column
    for char in whitespace:
        column = _advance_column(char, column)
    padding = column - marker_end_column
    # CommonMark treats one to four following spaces as marker padding. Extra
    # spaces start indented content after the required single-space padding.
    if 1 <= padding <= 4:
        content_column = column
        content_start = match.end()
    else:
        content_column = marker_end_column + 1
        content_start = marker_end + 1 if whitespace else len(line)
    return content_column - initial_column, line[content_start:], content_column


def _container_line(
    line: str,
    active: MarkdownContainer,
) -> tuple[MarkdownContainer, str]:
    consumed = _consume_container(line, active)
    parts = list(active.parts) if consumed is not None else []
    if consumed is None:
        remaining = line
        column = 0
    else:
        remaining, column = consumed
    while True:
        quote = re.match(r"^[ ]{0,3}>[ \t]?", remaining)
        if quote is not None:
            parts.append(("quote", 1))
            column = _advance_column(remaining[:quote.end()], column)
            remaining = remaining[quote.end():]
            continue
        marker = _list_marker(remaining, column)
        if marker is None:
            break
        indent, remaining, column = marker
        parts.append(("list", indent))
    return MarkdownContainer(tuple(parts)), remaining


def _consume_container(
    line: str, container: MarkdownContainer
) -> tuple[str, int] | None:
    remaining = line
    column = 0
    part_index = 0
    while part_index < len(container.parts):
        kind, width = container.parts[part_index]
        if kind == "quote":
            match = re.match(r"^[ ]{0,3}>[ \t]?", remaining)
            if match is None:
                return None
            column = _advance_column(remaining[:match.end()], column)
            remaining = remaining[match.end():]
            part_index += 1
            continue
        if remaining.strip() == "":
            remaining = ""
            part_index += 1
            continue
        required = width
        run_end = part_index + 1
        while (
            run_end < len(container.parts)
            and container.parts[run_end][0] == "list"
        ):
            required += container.parts[run_end][1]
            run_end += 1
        start_column = column
        cursor = 0
        while cursor < len(remaining) and remaining[cursor] in {" ", "\t"}:
            char = remaining[cursor]
            column = _advance_column(char, column)
            cursor += 1
            if column - start_column >= required:
                break
        consumed_columns = column - start_column
        if consumed_columns < required:
            return None
        # A tab can cross more than one nested-list indentation boundary.
        # Preserve any virtual columns beyond the cumulative requirement so
        # fence indentation is interpreted exactly as CommonMark sees it.
        remaining = " " * (consumed_columns - required) + remaining[cursor:]
        column = start_column + required
        part_index = run_end
    return remaining, column


def _strip_fence_container(line: str, container: MarkdownContainer) -> str | None:
    consumed = _consume_container(line, container)
    return None if consumed is None else consumed[0]


def markdown_csharp_segments(text: str) -> list[SourceSegment]:
    """Extract outer C# fences, including valid quote/list containers."""
    segments: list[SourceSegment] = []
    active_container = MarkdownContainer(())
    opener: MarkdownFence | None = None
    content: list[str] = []

    for line_number, original in enumerate(text.splitlines(keepends=True), start=1):
        newline = "\n" if original.endswith(("\n", "\r")) else ""
        line = original.rstrip("\r\n")
        if opener is None:
            container, remaining = _container_line(line, active_container)
            active_container = container
            match = re.match(r"^[ ]{0,3}(`{3,}|~{3,})[ \t]*([^ \t]*)", remaining)
            if match is None:
                continue
            fence = match.group(1)
            language = match.group(2).lower()
            opener = MarkdownFence(
                fence[0],
                len(fence),
                language in CSHARP_FENCE_LANGUAGES,
                line_number,
                container,
            )
            content = []
            continue

        remaining = _strip_fence_container(line, opener.container)
        if remaining is None:
            if opener.is_csharp:
                raise SourceError(opener.line, "unterminated C# Markdown fence")
            # A fenced block inside a quote/list ends when that container ends.
            # Reprocess this physical line so a real outer C# fence cannot hide
            # behind an unterminated non-C# block from the former container.
            opener = None
            content = []
            container, remaining = _container_line(line, active_container)
            active_container = container
            match = re.match(r"^[ ]{0,3}(`{3,}|~{3,})[ \t]*([^ \t]*)", remaining)
            if match is None:
                continue
            fence = match.group(1)
            language = match.group(2).lower()
            opener = MarkdownFence(
                fence[0],
                len(fence),
                language in CSHARP_FENCE_LANGUAGES,
                line_number,
                container,
            )
            continue
        closing = re.fullmatch(
            rf"[ ]{{0,3}}{re.escape(opener.char)}{{{opener.length},}}[ \t]*",
            remaining,
        )
        if closing is not None:
            if opener.is_csharp:
                segments.append(SourceSegment("".join(content), opener.line + 1))
            opener = None
            content = []
        elif opener.is_csharp:
            content.append(remaining + newline)

    if opener is not None and opener.is_csharp:
        raise SourceError(opener.line, "unterminated C# Markdown fence")
    return segments


def source_segments(path: Path) -> list[SourceSegment]:
    text = path.read_text(encoding="utf-8")
    if path.suffix == ".cs":
        return [SourceSegment(text, 1)]
    return markdown_csharp_segments(text)


def _matching_left(tokens: list[Token], right_index: int, left: str, right: str) -> int | None:
    depth = 0
    for index in range(right_index, -1, -1):
        if tokens[index].value == right:
            depth += 1
        elif tokens[index].value == left:
            depth -= 1
            if depth == 0:
                return index
    return None


def _matching_right(tokens: list[Token], left_index: int, left: str, right: str) -> int | None:
    depth = 0
    for index in range(left_index, len(tokens)):
        if tokens[index].value == left:
            depth += 1
        elif tokens[index].value == right:
            depth -= 1
            if depth == 0:
                return index
    return None


def _validate_delimiters(tokens: list[Token]) -> None:
    pairs = {")": "(", "]": "[", "}": "{"}
    stack: list[Token] = []
    for token in tokens:
        if token.value in {"(", "[", "{"}:
            stack.append(token)
        elif token.value in pairs:
            if not stack:
                raise SourceError(token.line, f"unmatched '{token.raw}'")
            if stack[-1].value != pairs[token.value]:
                raise SourceError(stack[-1].line, f"unmatched '{stack[-1].raw}'")
            stack.pop()
    if stack:
        raise SourceError(stack[-1].line, f"unmatched '{stack[-1].raw}'")


def _visible_aliases(scopes: list[dict[str, tuple[str, ...]]]) -> dict[str, tuple[str, ...]]:
    aliases: dict[str, tuple[str, ...]] = {}
    for scope in scopes:
        aliases.update(scope)
    return aliases


def _visible_imports(scopes: list[set[tuple[str, ...]]]) -> frozenset[tuple[str, ...]]:
    return frozenset(namespace for scope in scopes for namespace in scope)


def _qualified_name(tokens: list[Token], start: int, end: int) -> tuple[str, ...] | None:
    cursor = start
    if cursor + 1 < end and _spelled(tokens[cursor], "global") and tokens[cursor + 1].value == "::":
        cursor += 2
    parts: list[str] = []
    expect_name = True
    while cursor < end:
        token = tokens[cursor]
        if expect_name:
            if token.kind not in {"identifier", "keyword"}:
                return None
            parts.append(token.value)
            expect_name = False
        else:
            if token.value not in {".", "::"}:
                return None
            expect_name = True
        cursor += 1
    if expect_name or not parts:
        return None
    return tuple(parts)


def _expand_alias(
    name: tuple[str, ...], aliases: dict[str, tuple[str, ...]]
) -> tuple[str, ...]:
    if name and name[0] in aliases:
        return aliases[name[0]] + name[1:]
    return name


def _using_alias_at(
    tokens: list[Token],
    index: int,
    aliases: dict[str, tuple[str, ...]],
) -> tuple[str, tuple[str, ...], int] | None:
    if not _spelled(tokens[index], "using") or index + 3 >= len(tokens):
        return None
    alias_token = tokens[index + 1]
    if alias_token.kind != "identifier" or tokens[index + 2].value != "=":
        return None
    semicolon = index + 3
    while semicolon < len(tokens) and tokens[semicolon].value != ";":
        semicolon += 1
    if semicolon >= len(tokens):
        raise SourceError(tokens[index].line, "unterminated using alias")
    target = _qualified_name(tokens, index + 3, semicolon)
    if target is None:
        raise SourceError(tokens[index].line, "malformed using alias")
    return alias_token.value, _expand_alias(target, aliases), semicolon


def _using_namespace_at(tokens: list[Token], index: int) -> tuple[tuple[str, ...], int] | None:
    if not _spelled(tokens[index], "using") or index + 1 >= len(tokens):
        return None
    if index + 2 < len(tokens) and tokens[index + 2].value == "=":
        return None
    semicolon = index + 1
    while semicolon < len(tokens) and tokens[semicolon].value != ";":
        semicolon += 1
    if semicolon >= len(tokens):
        raise SourceError(tokens[index].line, "unterminated using directive")
    name = _qualified_name(tokens, index + 1, semicolon)
    if name is None:
        return None
    return name, semicolon


def _attribute_entry_name(tokens: list[Token]) -> tuple[str, ...] | None:
    if not tokens:
        return None
    start = 0
    if len(tokens) >= 2 and tokens[1].value == ":":
        start = 2
    end = start
    while end < len(tokens) and tokens[end].value != "(":
        end += 1
    return _qualified_name(tokens, start, end)


def _is_network_callable_name(
    name: tuple[str, ...] | None,
    aliases: dict[str, tuple[str, ...]],
    imports: frozenset[tuple[str, ...]],
    context: TypeContext | None,
    local_types: frozenset[tuple[str, ...]],
    line: int,
) -> bool:
    if name is None:
        return False
    if len(name) == 1 and name[0] in aliases:
        expanded = aliases[name[0]]
    elif len(name) == 1 and name[0] in {"NetworkCallable", "NetworkCallableAttribute"}:
        candidates = (name[0],) if name[0].endswith("Attribute") else (
            "NetworkCallable",
            "NetworkCallableAttribute",
        )
        if context is not None:
            for depth in range(len(context.type_path), -1, -1):
                prefix = context.namespace + context.type_path[:depth]
                if any(prefix + (candidate,) in local_types for candidate in candidates):
                    return False
            imported_local = {
                imported + (candidate,)
                for imported in imports
                for candidate in candidates
                if imported + (candidate,) in local_types
            }
            sdk_imported = NETWORK_CALLABLE_TYPE[:-1] in imports
            if imported_local and sdk_imported:
                raise SourceError(
                    line,
                    "ambiguous NetworkCallable attribute binding",
                )
            if imported_local:
                return False
            if sdk_imported:
                return True
        # Existing examples may omit the using directive. With no visible local
        # declaration to bind, classify the security-relevant simple name as the
        # SDK attribute rather than allowing an unresolved name to bypass checks.
        return True
    else:
        expanded = _expand_alias(name, aliases)
    declared_name = expanded
    if expanded[-1:] == ("NetworkCallable",):
        expanded = expanded[:-1] + ("NetworkCallableAttribute",)
    if expanded in local_types or declared_name in local_types:
        return False
    if expanded == NETWORK_CALLABLE_TYPE:
        return True
    if expanded[-1:] == ("NetworkCallableAttribute",):
        raise SourceError(line, "cannot safely bind NetworkCallable attribute name")
    return False


def _network_callable_occurrence(
    entry: list[Token],
    token_index: int,
    section_target: str | None,
    aliases: dict[str, tuple[str, ...]],
    imports: frozenset[tuple[str, ...]],
    context: TypeContext | None,
    local_types: frozenset[tuple[str, ...]],
) -> NetworkCallableOccurrence | None:
    if not entry:
        return None
    name = _attribute_entry_name(entry)
    if not _is_network_callable_name(
        name, aliases, imports, context, local_types, entry[0].line
    ):
        return None

    start = 0
    target = section_target
    if len(entry) >= 2 and entry[1].value == ":":
        target = entry[0].value
        start = 2
    if target is not None and target != "method":
        raise SourceError(entry[0].line, "NetworkCallable attribute must target a method")
    paren = next((index for index in range(start, len(entry)) if entry[index].value == "("), None)
    if paren is not None:
        close = _matching_right(entry, paren, "(", ")")
        if close is None or close != len(entry) - 1:
            raise SourceError(entry[0].line, "malformed NetworkCallable attribute arguments")
        arguments = _split_parameter_tokens(entry[paren + 1:close])
        if len(arguments) > 1:
            raise SourceError(entry[0].line, "NetworkCallable attribute accepts at most one argument")
        if arguments:
            argument = arguments[0]
            if any(token.value == ":" for token in argument):
                if not (
                    len(argument) == 3
                    and argument[0].value == "maxEventsPerSecond"
                    and argument[1].value == ":"
                ):
                    raise SourceError(
                        entry[0].line,
                        "NetworkCallable attribute has an unknown named argument",
                    )
                argument = argument[2:]
            if len(argument) != 1 or re.fullmatch(r"[0-9]+", argument[0].raw) is None:
                raise SourceError(
                    entry[0].line,
                    "NetworkCallable rate must be an integer from 1 to 100",
                )
            rate = int(argument[0].raw)
            if rate < 1 or rate > 100:
                raise SourceError(
                    entry[0].line,
                    "NetworkCallable rate must be an integer from 1 to 100",
                )
    return NetworkCallableOccurrence(token_index, entry[0].line)


def _network_occurrences_in_section(
    tokens: list[Token],
    left: int,
    right: int,
    aliases: dict[str, tuple[str, ...]],
    imports: frozenset[tuple[str, ...]],
    context: TypeContext | None,
    local_types: frozenset[tuple[str, ...]],
) -> tuple[NetworkCallableOccurrence, ...]:
    found: list[NetworkCallableOccurrence] = []
    section_target = (
        tokens[left + 1].value
        if left + 2 < right and tokens[left + 2].value == ":"
        else None
    )
    entry_start = left + 1
    paren_depth = bracket_depth = brace_depth = 0
    for index in range(left + 1, right + 1):
        value = tokens[index].value
        if value == "(":
            paren_depth += 1
        elif value == ")":
            paren_depth -= 1
        elif value == "[":
            bracket_depth += 1
        elif value == "]" and bracket_depth:
            bracket_depth -= 1
        elif value == "{":
            brace_depth += 1
        elif value == "}" and brace_depth:
            brace_depth -= 1
        elif value == "," and paren_depth == bracket_depth == brace_depth == 0:
            entry = tokens[entry_start:index]
            if (
                entry_start != left + 1
                and len(entry) >= 2
                and entry[1].value == ":"
            ):
                raise SourceError(
                    entry[0].line,
                    "attribute target must begin the attribute section",
                )
            occurrence = _network_callable_occurrence(
                entry, entry_start, section_target, aliases, imports,
                context, local_types,
            )
            if occurrence is not None:
                found.append(occurrence)
            entry_start = index + 1
        if paren_depth < 0 or bracket_depth < 0 or brace_depth < 0:
            raise SourceError(tokens[index].line, "malformed attribute section")
    if paren_depth or bracket_depth or brace_depth:
        raise SourceError(tokens[left].line, "malformed attribute section")
    final_entry = tokens[entry_start:right]
    if (
        entry_start != left + 1
        and len(final_entry) >= 2
        and final_entry[1].value == ":"
    ):
        raise SourceError(
            final_entry[0].line,
            "attribute target must begin the attribute section",
        )
    occurrence = _network_callable_occurrence(
        final_entry, entry_start, section_target, aliases, imports,
        context, local_types
    )
    if occurrence is not None:
        found.append(occurrence)
    return tuple(found)


def _attribute_names_before(
    tokens: list[Token],
    declaration_index: int,
    aliases: dict[str, tuple[str, ...]],
    imports: frozenset[tuple[str, ...]],
    context: TypeContext | None,
    local_types: frozenset[tuple[str, ...]],
) -> tuple[int, ...]:
    cursor = declaration_index - 1
    found: list[NetworkCallableOccurrence] = []
    while cursor >= 0 and tokens[cursor].value == "]":
        left = _matching_left(tokens, cursor, "[", "]")
        if left is None:
            raise SourceError(tokens[cursor].line, "unmatched ']'")
        found.extend(_network_occurrences_in_section(
            tokens, left, cursor, aliases, imports, context, local_types
        ))
        cursor = left - 1
    if len(found) > 1:
        raise SourceError(found[1].line, "NetworkCallable attribute cannot be duplicated")
    return tuple(occurrence.token_index for occurrence in found)


def _method_name_before_paren(tokens: list[Token], paren_index: int) -> tuple[Token, int] | None:
    previous = paren_index - 1
    if previous < 0:
        return None
    if tokens[previous].kind == "identifier":
        return tokens[previous], previous
    if tokens[previous].value != ">":
        return None
    generic_left = _matching_left(tokens, previous, "<", ">")
    if generic_left is None or generic_left == 0:
        return None
    name_index = generic_left - 1
    if tokens[name_index].kind != "identifier":
        return None
    return tokens[name_index], name_index


def _find_method_paren(tokens: list[Token], cursor: int) -> int | None:
    scan = cursor
    while scan < len(tokens):
        value = tokens[scan].value
        if value in {";", "{", "}", "=", "=>"}:
            return None
        if value == "(":
            candidate = _method_name_before_paren(tokens, scan)
            close = _matching_right(tokens, scan, "(", ")")
            if close is None:
                raise SourceError(tokens[scan].line, "unclassified public declaration: unmatched '('")
            if candidate is not None and candidate[1] >= cursor:
                return scan
            scan = close
        scan += 1
    return None


def _find_type_after(tokens: list[Token], keyword_index: int) -> tuple[Token, int] | None:
    cursor = keyword_index + 1
    if _spelled(tokens[keyword_index], "record") and cursor < len(tokens) and (
        _spelled(tokens[cursor], "class") or _spelled(tokens[cursor], "struct")
    ):
        cursor += 1
    if cursor >= len(tokens) or tokens[cursor].kind != "identifier":
        return None
    return tokens[cursor], cursor


def _direct_base_names(tokens: list[Token]) -> tuple[tuple[str, ...], ...]:
    angle_depth = 0
    colon_index: int | None = None
    end = len(tokens)
    for index, token in enumerate(tokens):
        if token.value == "<":
            angle_depth += 1
        elif token.value == ">" and angle_depth:
            angle_depth -= 1
        elif angle_depth == 0 and _spelled(token, "where"):
            end = index
            break
        elif angle_depth == 0 and token.value == ":" and colon_index is None:
            colon_index = index
    if colon_index is None:
        return ()

    bases: list[tuple[str, ...]] = []
    segment: list[Token] = []
    angle_depth = 0
    sentinel = Token(",", ",", 0, "punctuation")
    for token in tokens[colon_index + 1:end] + [sentinel]:
        if token.value == "<":
            angle_depth += 1
        elif token.value == ">" and angle_depth:
            angle_depth -= 1
        if token.value == "," and angle_depth == 0:
            generic = next((i for i, item in enumerate(segment) if item.value == "<"), len(segment))
            name = _qualified_name(segment, 0, generic)
            if name is not None:
                bases.append(name)
            segment = []
        else:
            segment.append(token)
    return tuple(bases)


def _raw_type_openings(tokens: list[Token]) -> dict[int, tuple[str, tuple[tuple[str, ...], ...]]]:
    openings: dict[int, tuple[str, tuple[tuple[str, ...], ...]]] = {}
    for index, token in enumerate(tokens):
        if token.value not in TYPE_KEYWORDS or token.raw != token.value:
            continue
        found = _find_type_after(tokens, index)
        if found is None:
            continue
        name_token, name_index = found
        cursor = name_index + 1
        while cursor < len(tokens) and tokens[cursor].value not in {"{", ";"}:
            cursor += 1
        if cursor < len(tokens) and tokens[cursor].value == "{":
            openings[cursor] = (
                name_token.value,
                _direct_base_names(tokens[name_index + 1:cursor]),
            )
    return openings


def _after_compilation_prefix(tokens: list[Token]) -> list[Token]:
    cursor = 0
    while cursor < len(tokens):
        if tokens[cursor].value == "#":
            directive_line = tokens[cursor].line
            cursor += 1
            while cursor < len(tokens) and tokens[cursor].line == directive_line:
                cursor += 1
            continue
        if tokens[cursor].value == "[":
            close = _matching_right(tokens, cursor, "[", "]")
            if (
                close is not None
                and cursor + 2 < close
                and tokens[cursor + 1].value in {"assembly", "module"}
                and tokens[cursor + 2].value == ":"
            ):
                cursor = close + 1
                continue
        break
    return tokens[cursor:]


def _is_compilation_directive(tokens: list[Token]) -> bool:
    tokens = _after_compilation_prefix(tokens)
    if not tokens:
        return True
    values = [token.value for token in tokens]
    if values[:2] == ["extern", "alias"]:
        return len(tokens) == 3 and tokens[2].kind == "identifier"
    cursor = 0
    if values[:2] == ["global", "using"]:
        cursor = 2
    elif values[:1] == ["using"]:
        cursor = 1
    else:
        return False
    if cursor < len(tokens) and tokens[cursor].value in {"static", "unsafe"}:
        cursor += 1
    body = tokens[cursor:]
    equals = [index for index, token in enumerate(body) if token.value == "="]
    if equals:
        if len(equals) != 1 or equals[0] != 1 or body[0].kind != "identifier":
            return False
        body = body[2:]
    return bool(body) and _qualified_name(body, 0, len(body)) is not None


def _namespace_openings(
    tokens: list[Token],
) -> tuple[dict[int, tuple[str, ...]], tuple[str, ...]]:
    openings: dict[int, tuple[str, ...]] = {}
    file_scoped: tuple[str, ...] = ()
    brace_depth = 0
    seen_compilation_member = False
    top_level_segment_start = 0
    for index, token in enumerate(tokens):
        if brace_depth == 0 and (
            token.raw in ALL_TYPE_KEYWORDS or _spelled(token, "delegate")
        ):
            seen_compilation_member = True
        if token.value == "{":
            brace_depth += 1
        elif token.value == "}":
            brace_depth = max(0, brace_depth - 1)
        elif token.value == ";" and brace_depth == 0:
            segment = tokens[top_level_segment_start:index]
            namespace_declaration = any(
                _spelled(item, "namespace") for item in segment
            )
            if not segment or (
                not namespace_declaration and not _is_compilation_directive(segment)
            ):
                seen_compilation_member = True
            top_level_segment_start = index + 1
        if not _spelled(token, "namespace"):
            continue
        if _after_compilation_prefix(tokens[top_level_segment_start:index]):
            seen_compilation_member = True
        cursor = index + 1
        while cursor < len(tokens) and tokens[cursor].value not in {"{", ";"}:
            cursor += 1
        if cursor >= len(tokens):
            raise SourceError(token.line, "unterminated namespace declaration")
        name = _qualified_name(tokens, index + 1, cursor)
        if name is None:
            raise SourceError(token.line, "malformed namespace declaration")
        if tokens[cursor].value == ";":
            if brace_depth != 0:
                raise SourceError(
                    token.line,
                    "file-scoped namespace must be at compilation-unit scope",
                )
            if seen_compilation_member:
                raise SourceError(
                    token.line,
                    "file-scoped namespace must precede all members",
                )
            if file_scoped or openings:
                raise SourceError(token.line, "ambiguous file-scoped namespace declaration")
            file_scoped = name
        else:
            if file_scoped:
                raise SourceError(token.line, "file-scoped namespace cannot be mixed with block namespaces")
            openings[cursor] = name
    return openings, file_scoped


def _type_openings(tokens: list[Token]) -> dict[int, TypeContext]:
    raw_types = _raw_type_openings(tokens)
    namespaces, file_scoped = _namespace_openings(tokens)
    openings: dict[int, TypeContext] = {}
    namespace = file_scoped
    type_path: tuple[str, ...] = ()
    frames: list[tuple[str, tuple[str, ...], tuple[str, ...]]] = []
    alias_scopes: list[dict[str, tuple[str, ...]]] = [{}]
    import_scopes: list[set[tuple[str, ...]]] = [set()]

    for index, token in enumerate(tokens):
        visible_aliases = _visible_aliases(alias_scopes)
        alias = _using_alias_at(tokens, index, visible_aliases)
        if alias is not None:
            alias_scopes[-1][alias[0]] = alias[1]
        imported = _using_namespace_at(tokens, index)
        if imported is not None:
            import_scopes[-1].add(imported[0])

        if token.value == "{":
            previous = (namespace, type_path)
            if index in namespaces:
                frames.append(("namespace", *previous))
                namespace = namespace + namespaces[index]
            elif index in raw_types:
                name, raw_bases = raw_types[index]
                aliases = _visible_aliases(alias_scopes)
                base_names = tuple(_expand_alias(base, aliases) for base in raw_bases)
                context = TypeContext(
                    name,
                    frozenset(base[-1] for base in base_names),
                    base_names,
                    namespace,
                    type_path + (name,),
                    _visible_imports(import_scopes),
                    tuple(sorted(aliases.items())),
                )
                openings[index] = context
                frames.append(("type", *previous))
                type_path = context.type_path
            else:
                frames.append(("other", *previous))
            alias_scopes.append({})
            import_scopes.append(set())
        elif token.value == "}" and frames:
            _, namespace, type_path = frames.pop()
            alias_scopes.pop()
            import_scopes.pop()
    return openings


def _local_type_names(openings: dict[int, TypeContext]) -> frozenset[tuple[str, ...]]:
    return frozenset(
        context.namespace + context.type_path
        for context in openings.values()
    )


SYSTEM_TYPE_ALIASES = {
    "Boolean": "bool",
    "Byte": "byte",
    "Char": "char",
    "Double": "double",
    "Int16": "short",
    "Int32": "int",
    "Int64": "long",
    "SByte": "sbyte",
    "Single": "float",
    "String": "string",
    "UInt16": "ushort",
    "UInt32": "uint",
    "UInt64": "ulong",
}
SYNC_PRIMITIVES = frozenset(SYSTEM_TYPE_ALIASES.values())
SYNC_STRUCTS = {
    ("UnityEngine", "Color"),
    ("UnityEngine", "Color32"),
    ("UnityEngine", "Quaternion"),
    ("UnityEngine", "Vector2"),
    ("UnityEngine", "Vector3"),
    ("UnityEngine", "Vector4"),
    ("VRC", "SDKBase", "VRCUrl"),
}
KEYWORD_SYSTEM_TYPES = {
    keyword: ("System", system_name)
    for system_name, keyword in SYSTEM_TYPE_ALIASES.items()
}
KNOWN_PLATFORM_TYPES = set(SYNC_STRUCTS)
for signatures in SDK_CALLBACK_SIGNATURES.values():
    for _, parameters in signatures:
        for parameter in parameters:
            KNOWN_PLATFORM_TYPES.add(parameter[:-1] if parameter[-1:] == ("[]",) else parameter)
for _, parameters in UNITY_CALLBACK_SIGNATURES.values():
    for parameter in parameters:
        KNOWN_PLATFORM_TYPES.add(parameter)


def _split_parameter_tokens(tokens: list[Token]) -> list[list[Token]]:
    if not tokens:
        return []
    parts: list[list[Token]] = []
    start = 0
    depths = {"(": 0, "[": 0, "<": 0, "{": 0}
    closing = {")": "(", "]": "[", ">": "<", "}": "{"}
    for index, token in enumerate(tokens):
        if token.value in depths:
            depths[token.value] += 1
        elif token.value in closing and depths[closing[token.value]]:
            depths[closing[token.value]] -= 1
        elif token.value == "," and not any(depths.values()):
            parts.append(tokens[start:index])
            start = index + 1
    parts.append(tokens[start:])
    if any(not part for part in parts):
        raise SourceError(tokens[0].line, "malformed method parameter list")
    return parts


def _supported_parameter_type(
    type_tokens: list[Token],
    aliases: dict[str, tuple[str, ...]],
    imports: frozenset[tuple[str, ...]],
    context: TypeContext | None,
    local_types: frozenset[tuple[str, ...]],
) -> tuple[str, bool, tuple[str, ...] | None]:
    array = False
    if len(type_tokens) >= 2 and [item.value for item in type_tokens[-2:]] == ["[", "]"]:
        array = True
        type_tokens = type_tokens[:-2]
    if any(item.value in {"[", "]", "<", ">", "?", "*"} for item in type_tokens):
        return "".join(item.raw for item in type_tokens), False, None
    name = _qualified_name(type_tokens, 0, len(type_tokens))
    if name is None:
        return "".join(item.raw for item in type_tokens), False, None
    name = _expand_alias(name, aliases)
    bound: tuple[str, ...] | None = None
    local_binding = False
    if len(name) == 1 and name[0] in KEYWORD_SYSTEM_TYPES:
        bound = KEYWORD_SYSTEM_TYPES[name[0]]
    elif len(name) == 1 and name[0] in SYSTEM_TYPE_ALIASES:
        local = _visible_local_types(name[0], context, imports, local_types)
        if local:
            bound = _single_type_binding(local, type_tokens[0].line)
            local_binding = True
        elif ("System",) in imports:
            bound = ("System", name[0])
    elif len(name) == 1:
        local = _visible_local_types(name[0], context, imports, local_types)
        platform = {
            candidate for candidate in KNOWN_PLATFORM_TYPES
            if candidate[-1] == name[0] and candidate[:-1] in imports
        }
        candidates = local if local else platform
        if candidates:
            bound = _single_type_binding(candidates, type_tokens[0].line)
            local_binding = bool(local)
    else:
        possible = {name, *(imported + name for imported in imports)}
        local = {candidate for candidate in possible if candidate in local_types}
        platform = {
            candidate for candidate in possible if candidate in KNOWN_PLATFORM_TYPES
        }
        if local:
            bound = _single_type_binding(local, type_tokens[0].line)
            local_binding = True
        elif platform:
            bound = _single_type_binding(platform, type_tokens[0].line)
        elif len(name) == 2 and name[0] == "System" and name[1] in SYSTEM_TYPE_ALIASES:
            bound = name
    if bound is not None and array:
        bound = bound + ("[]",)
    supported_base = bound[:-1] if bound is not None and bound[-1:] == ("[]",) else bound
    supported = not local_binding and (
        supported_base in SYNC_STRUCTS or (
            supported_base is not None
            and len(supported_base) == 2
            and supported_base[0] == "System"
            and supported_base[1] in SYSTEM_TYPE_ALIASES
        )
    )
    display = ".".join(name) + ("[]" if array else "")
    return display, supported, bound


def _visible_local_types(
    short_name: str,
    context: TypeContext | None,
    imports: frozenset[tuple[str, ...]],
    local_types: frozenset[tuple[str, ...]],
) -> set[tuple[str, ...]]:
    candidates: set[tuple[str, ...]] = set()
    if context is not None:
        for depth in range(len(context.type_path), -1, -1):
            candidate = context.namespace + context.type_path[:depth] + (short_name,)
            if candidate in local_types:
                candidates.add(candidate)
    for imported in imports:
        candidate = imported + (short_name,)
        if candidate in local_types:
            candidates.add(candidate)
    return candidates


def _single_type_binding(
    candidates: set[tuple[str, ...]], line: int
) -> tuple[str, ...]:
    if len(candidates) != 1:
        raise SourceError(line, "ambiguous type binding")
    return next(iter(candidates))


def _parse_parameters(
    tokens: list[Token],
    aliases: dict[str, tuple[str, ...]],
    imports: frozenset[tuple[str, ...]],
    context: TypeContext | None,
    local_types: frozenset[tuple[str, ...]],
) -> tuple[Parameter, ...]:
    parameters: list[Parameter] = []
    for part in _split_parameter_tokens(tokens):
        equals = next((index for index, item in enumerate(part) if item.value == "="), None)
        declaration = part if equals is None else part[:equals]
        modifiers: set[str] = set()
        while declaration and declaration[0].value in {"in", "out", "params", "ref", "this"}:
            modifiers.add(declaration[0].value)
            declaration = declaration[1:]
        if len(declaration) < 2 or declaration[-1].kind != "identifier":
            raise SourceError(part[0].line, "cannot safely classify NetworkCallable parameter")
        type_name, supported, bound_type = _supported_parameter_type(
            declaration[:-1], aliases, imports, context, local_types
        )
        parameters.append(
            Parameter(
                type_name,
                frozenset(modifiers),
                equals is not None,
                supported,
                bound_type,
            )
        )
    return tuple(parameters)


def _return_type_name(
    tokens: list[Token],
    aliases: dict[str, tuple[str, ...]],
    imports: frozenset[tuple[str, ...]],
    context: TypeContext | None,
    local_types: frozenset[tuple[str, ...]],
) -> str:
    name = _qualified_name(tokens, 0, len(tokens))
    if name is not None:
        expanded = _expand_alias(name, aliases)
        if (
            expanded == ("Boolean",)
            and ("System",) in imports
            and not _visible_local_types("Boolean", context, imports, local_types)
        ):
            expanded = ("System", "Boolean")
        if (
            len(expanded) == 2
            and expanded[0] == "System"
            and expanded not in local_types
        ):
            keyword = SYSTEM_TYPE_ALIASES.get(expanded[1])
            if keyword is not None:
                return keyword
    return "".join(item.raw for item in tokens)


def parse_declaration(
    tokens: list[Token],
    public_index: int,
    context: TypeContext | None,
    aliases: dict[str, tuple[str, ...]],
    imports: frozenset[tuple[str, ...]],
    local_types: frozenset[tuple[str, ...]],
) -> Declaration:
    declaration_index = public_index
    modifiers: set[str] = set()
    while declaration_index > 0 and tokens[declaration_index - 1].raw in METHOD_MODIFIERS:
        declaration_index -= 1
        modifiers.add(tokens[declaration_index].value)

    cursor = public_index + 1
    while cursor < len(tokens) and tokens[cursor].raw in METHOD_MODIFIERS:
        modifiers.add(tokens[cursor].value)
        cursor += 1
    if cursor >= len(tokens):
        raise SourceError(tokens[public_index].line, "unclassified public declaration")

    network_callable = _attribute_names_before(
        tokens,
        declaration_index,
        aliases,
        imports,
        context,
        local_types,
    )

    def non_method(kind: str) -> Declaration:
        if network_callable:
            raise SourceError(
                tokens[public_index].line,
                "NetworkCallable attribute must target a method",
            )
        return Declaration(kind, tokens[public_index].line)

    token = tokens[cursor]
    if token.raw in ALL_TYPE_KEYWORDS:
        return non_method("type")
    if _spelled(token, "delegate"):
        return non_method("delegate")
    if _spelled(token, "event"):
        return non_method("event")

    operator_scan = cursor
    while operator_scan < len(tokens) and tokens[operator_scan].value not in {";", "{", "}", "=", "=>"}:
        if _spelled(tokens[operator_scan], "operator"):
            paren = operator_scan + 1
            while paren < len(tokens) and tokens[paren].value != "(":
                paren += 1
            if paren >= len(tokens) or _matching_right(tokens, paren, "(", ")") is None:
                raise SourceError(tokens[public_index].line, "unclassified public declaration")
            return non_method("operator")
        operator_scan += 1

    paren_index = _find_method_paren(tokens, cursor)
    if paren_index is not None:
        name_and_index = _method_name_before_paren(tokens, paren_index)
        if name_and_index is None:
            raise SourceError(tokens[public_index].line, "unclassified public declaration")
        name_token, name_index = name_and_index
        header = tokens[cursor:name_index]
        if not header:
            if context is not None and name_token.value == context.name:
                return non_method("constructor")
            raise SourceError(tokens[public_index].line, "unclassified public declaration")
        close_paren = _matching_right(tokens, paren_index, "(", ")")
        if close_paren is None:
            raise SourceError(tokens[public_index].line, "unclassified public declaration")
        parameters = _parse_parameters(
            tokens[paren_index + 1:close_paren],
            aliases,
            imports,
            context,
            local_types,
        )
        method = Method(
            name=name_token.value,
            display_name=name_token.raw,
            return_type=_return_type_name(
                header, aliases, imports, context, local_types
            ),
            modifiers=frozenset(modifiers),
            parameterless=not parameters,
            parameters=parameters,
            access=tokens[public_index].value,
            generic=tokens[paren_index - 1].value == ">",
            network_callable_occurrences=network_callable,
            line=tokens[public_index].line,
            context=context,
        )
        return Declaration("method", tokens[public_index].line, method)

    scan = cursor
    square_depth = paren_depth = 0
    while scan < len(tokens):
        value = tokens[scan].value
        if value == "(":
            paren_depth += 1
        elif value == ")" and paren_depth:
            paren_depth -= 1
        elif value == "[":
            square_depth += 1
        elif value == "]" and square_depth:
            square_depth -= 1
        elif paren_depth == square_depth == 0:
            if value == "{" or value == "=>":
                return non_method("indexer" if any(_spelled(t, "this") for t in tokens[cursor:scan]) else "property")
            if value in {";", "="}:
                return non_method("field")
            if value == "}":
                break
        scan += 1
    raise SourceError(tokens[public_index].line, "unclassified public declaration")


def declarations_in_tokens(
    tokens: list[Token],
    local_types: frozenset[tuple[str, ...]],
) -> Iterable[Declaration]:
    openings = _type_openings(tokens)
    type_stack: list[TypeContext | None] = []
    alias_scopes: list[dict[str, tuple[str, ...]]] = [{}]
    import_scopes: list[set[tuple[str, ...]]] = [set()]

    for index, token in enumerate(tokens):
        visible = _visible_aliases(alias_scopes)
        alias = _using_alias_at(tokens, index, visible)
        if alias is not None:
            name, target, _ = alias
            alias_scopes[-1][name] = target
        imported = _using_namespace_at(tokens, index)
        if imported is not None:
            import_scopes[-1].add(imported[0])

        if token.value in {"public", "private", "protected", "internal"} and token.raw == token.value:
            context = next((item for item in reversed(type_stack) if item is not None), None)
            declaration = parse_declaration(
                tokens,
                index,
                context,
                _visible_aliases(alias_scopes),
                _visible_imports(import_scopes),
                local_types,
            )
            if token.value == "public":
                yield declaration
            elif type_stack and type_stack[-1] is not None and declaration.method is not None:
                yield Declaration("nonpublic_method", declaration.line, declaration.method)

        if token.value == "{":
            type_stack.append(openings.get(index))
            alias_scopes.append({})
            import_scopes.append(set())
        elif token.value == "}" and len(alias_scopes) > 1:
            type_stack.pop()
            alias_scopes.pop()
            import_scopes.pop()

    _validate_delimiters(tokens)


def implicit_methods_in_tokens(
    tokens: list[Token],
    local_types: frozenset[tuple[str, ...]],
) -> list[Method]:
    """Collect class members whose private accessibility is implicit."""
    openings = _type_openings(tokens)
    frames: list[TypeContext | None] = []
    alias_scopes: list[dict[str, tuple[str, ...]]] = [{}]
    import_scopes: list[set[tuple[str, ...]]] = [set()]
    found: list[Method] = []
    square_depth = 0

    for index, token in enumerate(tokens):
        visible_aliases = _visible_aliases(alias_scopes)
        alias = _using_alias_at(tokens, index, visible_aliases)
        if alias is not None:
            alias_scopes[-1][alias[0]] = alias[1]
        imported = _using_namespace_at(tokens, index)
        if imported is not None:
            import_scopes[-1].add(imported[0])

        if token.value == "[":
            square_depth += 1
        elif token.value == "]" and square_depth:
            square_depth -= 1
        elif token.value == "(" and square_depth == 0 and frames and frames[-1] is not None:
            candidate = _method_name_before_paren(tokens, index)
            if candidate is not None:
                name_token, name_index = candidate
                start = name_index - 1
                while start >= 0 and tokens[start].value not in {";", "{", "}"}:
                    start -= 1
                declaration_index = start + 1
                cursor = declaration_index
                while cursor < name_index and tokens[cursor].value == "[":
                    attribute_end = _matching_right(tokens, cursor, "[", "]")
                    if attribute_end is None:
                        raise SourceError(tokens[cursor].line, "unmatched '['")
                    cursor = attribute_end + 1
                modifier_index = cursor
                modifiers: set[str] = set()
                while cursor < name_index and tokens[cursor].raw in METHOD_MODIFIERS:
                    modifiers.add(tokens[cursor].value)
                    cursor += 1
                header = tokens[cursor:name_index]
                if (
                    header
                    and not any(item.value in {"=", "=>", "new", "operator"} for item in header)
                    and not any(
                        item.value in {"public", "private", "protected", "internal"}
                        for item in header
                    )
                    and name_token.kind == "identifier"
                ):
                    close_paren = _matching_right(tokens, index, "(", ")")
                    if close_paren is None:
                        raise SourceError(token.line, "unmatched '('")
                    aliases = _visible_aliases(alias_scopes)
                    parameters = _parse_parameters(
                        tokens[index + 1:close_paren],
                        aliases,
                        _visible_imports(import_scopes),
                        frames[-1],
                        local_types,
                    )
                    found.append(
                        Method(
                            name=name_token.value,
                            display_name=name_token.raw,
                            return_type="".join(item.raw for item in header),
                            modifiers=frozenset(modifiers),
                            parameterless=not parameters,
                            parameters=parameters,
                            access="private",
                            generic=tokens[index - 1].value == ">",
                            network_callable_occurrences=_attribute_names_before(
                                tokens,
                                modifier_index,
                                aliases,
                                _visible_imports(import_scopes),
                                frames[-1],
                                local_types,
                            ),
                            line=tokens[modifier_index].line,
                            context=frames[-1],
                        )
                    )

        if token.value == "{":
            frames.append(openings.get(index))
            alias_scopes.append({})
            import_scopes.append(set())
        elif token.value == "}" and frames:
            frames.pop()
            alias_scopes.pop()
            import_scopes.pop()
    return found


def network_callable_occurrences_in_tokens(
    tokens: list[Token],
    local_types: frozenset[tuple[str, ...]],
) -> tuple[NetworkCallableOccurrence, ...]:
    openings = _type_openings(tokens)
    frames: list[TypeContext | None] = []
    alias_scopes: list[dict[str, tuple[str, ...]]] = [{}]
    import_scopes: list[set[tuple[str, ...]]] = [set()]
    found: list[NetworkCallableOccurrence] = []

    for index, token in enumerate(tokens):
        aliases = _visible_aliases(alias_scopes)
        alias = _using_alias_at(tokens, index, aliases)
        if alias is not None:
            alias_scopes[-1][alias[0]] = alias[1]
            aliases = _visible_aliases(alias_scopes)
        imported = _using_namespace_at(tokens, index)
        if imported is not None:
            import_scopes[-1].add(imported[0])

        if token.value == "[":
            right = _matching_right(tokens, index, "[", "]")
            if right is None:
                raise SourceError(token.line, "unmatched '['")
            context = next((item for item in reversed(frames) if item is not None), None)
            found.extend(_network_occurrences_in_section(
                tokens,
                index,
                right,
                aliases,
                _visible_imports(import_scopes),
                context,
                local_types,
            ))

        if token.value == "{":
            frames.append(openings.get(index))
            alias_scopes.append({})
            import_scopes.append(set())
        elif token.value == "}" and frames:
            frames.pop()
            alias_scopes.pop()
            import_scopes.pop()
    return tuple(found)


def _parameter_matches(parameter: Parameter, expected: tuple[str, ...]) -> bool:
    if parameter.modifiers or parameter.has_default:
        return False
    if parameter.bound_type is not None:
        return parameter.bound_type == expected
    expected_display = expected[-2] + "[]" if expected[-1:] == ("[]",) else expected[-1]
    return parameter.type_name == expected_display


def _method_matches_signature(
    method: Method,
    signature: tuple[str, tuple[tuple[str, ...], ...]],
) -> bool:
    return_type, parameters = signature
    return (
        not method.generic
        and
        method.return_type == return_type
        and len(method.parameters) == len(parameters)
        and all(
            _parameter_matches(parameter, expected)
            for parameter, expected in zip(method.parameters, parameters)
        )
    )


def callback_contract_error(method: Method) -> str | None:
    if method.name in SDK_CALLBACK_SIGNATURES:
        if method.modifiers != frozenset({"override"}) or not any(
            _method_matches_signature(method, signature)
            for signature in SDK_CALLBACK_SIGNATURES[method.name]
        ):
            return "built-in Udon event signature does not match SDK 3.10.4"
        return None
    if method.name in UNITY_CALLBACK_SIGNATURES:
        if method.modifiers or not _method_matches_signature(
            method, UNITY_CALLBACK_SIGNATURES[method.name]
        ):
            return "built-in Unity event signature does not match SDK 3.10.4"
    return None


def callback_category(method: Method) -> str | None:
    if method.name in SDK_CALLBACK_SIGNATURES or method.name in UNITY_CALLBACK_SIGNATURES:
        return "callback" if callback_contract_error(method) is None else None
    context = method.context
    if context is None:
        return None
    if (
        method.name == "OnInspectorGUI"
        and method.return_type == "void"
        and "override" in method.modifiers
        and "Editor" in context.bases
    ):
        return "editor_callback"
    if (
        method.name == "OnPreprocess"
        and method.return_type == "bool"
        and "IPreprocessCallbackBehaviour" in context.bases
    ):
        return "editor_callback"
    return None


def display_path(path: Path, root: Path) -> str:
    if root.is_file():
        return path.name
    try:
        return str(path.relative_to(root))
    except ValueError:
        return str(path)


def _type_key(context: TypeContext | None) -> tuple[str, ...]:
    return context.namespace + context.type_path if context is not None else ()


def _resolve_local_base(
    context: TypeContext,
    base_name: tuple[str, ...],
    local_types: frozenset[tuple[str, ...]],
) -> tuple[str, ...] | None:
    candidates: set[tuple[str, ...]] = set()
    if len(base_name) == 1:
        for depth in range(len(context.type_path) - 1, -1, -1):
            candidate = context.namespace + context.type_path[:depth] + base_name
            if candidate in local_types:
                candidates.add(candidate)
        for imported in context.imports:
            candidate = imported + base_name
            if candidate in local_types:
                candidates.add(candidate)
    else:
        if base_name in local_types:
            candidates.add(base_name)
        candidate = context.namespace + base_name
        if candidate in local_types:
            candidates.add(candidate)
    if len(candidates) > 1:
        raise SourceError(1, "ambiguous local inheritance binding")
    return next(iter(candidates)) if candidates else None


def _base_binds_to_platform(
    context: TypeContext,
    base_name: tuple[str, ...],
    platform_type: tuple[str, ...],
    local_types: frozenset[tuple[str, ...]],
) -> bool:
    """Bind a base name without letting a package-local type spoof a platform base."""
    if len(base_name) == 1:
        local = _visible_local_types(
            base_name[0], context, context.imports, local_types
        )
        if local:
            _single_type_binding(local, 1)
            return False
        # Documentation fragments commonly omit their using preamble. A unique
        # platform short name remains bindable only when the whole input has no
        # visible package-local declaration that would shadow it.
        return base_name[0] == platform_type[-1]

    possible = {base_name, context.namespace + base_name}
    possible.update(imported + base_name for imported in context.imports)
    if any(candidate in local_types for candidate in possible):
        return False
    return platform_type in possible


def _ancestor_types(
    type_name: tuple[str, ...],
    graph: dict[tuple[str, ...], set[tuple[str, ...]]],
) -> set[tuple[str, ...]]:
    ancestors: set[tuple[str, ...]] = set()
    pending = list(graph.get(type_name, ()))
    while pending:
        candidate = pending.pop()
        if candidate == type_name:
            raise SourceError(1, "cyclic local inheritance graph")
        if candidate in ancestors:
            continue
        ancestors.add(candidate)
        pending.extend(graph.get(candidate, ()))
    return ancestors


def audit_path(root: Path) -> tuple[list[str], dict[str, int]]:
    if root.is_file():
        paths = [root] if root.suffix in {".cs", ".md"} else []
    else:
        paths = sorted((*root.rglob("*.cs"), *root.rglob("*.md")))

    violations: list[str] = []
    counts = {
        "callback": 0,
        "editor_callback": 0,
        "network_callable": 0,
        "local": 0,
        "declaration": 0,
    }

    units: list[tuple[str, list[Token], dict[int, TypeContext]]] = []
    all_local_types: set[tuple[str, ...]] = set()
    for path in paths:
        shown_path = display_path(path, root)
        try:
            segments = source_segments(path)
        except (SourceError, UnicodeDecodeError) as error:
            line = error.line if isinstance(error, SourceError) else 1
            message = error.message if isinstance(error, SourceError) else "invalid UTF-8"
            violations.append(f"{shown_path}:{line}: {message}")
            continue

        for segment in segments:
            try:
                tokens = lex_csharp(segment.text, segment.first_line)
                _validate_delimiters(tokens)
                openings = _type_openings(tokens)
            except SourceError as error:
                violations.append(f"{shown_path}:{error.line}: {error.message}")
                continue
            units.append((shown_path, tokens, openings))
            all_local_types.update(_local_type_names(openings))

    local_types = frozenset(all_local_types)
    parsed_units: list[tuple[str, list[Declaration], list[Method]]] = []
    located_methods: list[tuple[str, Method]] = []
    type_contexts: dict[tuple[str, ...], list[TypeContext]] = {}
    for shown_path, tokens, openings in units:
        for context in openings.values():
            type_contexts.setdefault(_type_key(context), []).append(context)
        try:
            declarations = list(declarations_in_tokens(tokens, local_types))
            implicit_methods = implicit_methods_in_tokens(tokens, local_types)
            occurrences = network_callable_occurrences_in_tokens(tokens, local_types)
        except SourceError as error:
            violations.append(f"{shown_path}:{error.line}: {error.message}")
            continue

        methods = [
            declaration.method for declaration in declarations
            if declaration.method is not None
        ] + implicit_methods
        attached_occurrences = {
            occurrence
            for method in methods
            for occurrence in method.network_callable_occurrences
        }
        for occurrence in occurrences:
            if occurrence.token_index not in attached_occurrences:
                violations.append(
                    f"{shown_path}:{occurrence.line}: NetworkCallable attribute must target a method"
                )
        parsed_units.append((shown_path, declarations, methods))
        located_methods.extend((shown_path, method) for method in methods)

    inheritance: dict[tuple[str, ...], set[tuple[str, ...]]] = {}
    for type_name, contexts in type_contexts.items():
        bases = inheritance.setdefault(type_name, set())
        for context in contexts:
            for base_name in context.base_names:
                try:
                    resolved = _resolve_local_base(context, base_name, local_types)
                except SourceError as error:
                    violations.append(f"{'.'.join(type_name)}:{error.message}")
                    continue
                if resolved is not None:
                    bases.add(resolved)

    methods_by_type: dict[tuple[str, ...], list[Method]] = {}
    for _, method in located_methods:
        methods_by_type.setdefault(_type_key(method.context), []).append(method)
    overloaded_network_methods: set[tuple[tuple[str, ...], str, int]] = set()
    try:
        ancestors_by_type = {
            type_name: _ancestor_types(type_name, inheritance)
            for type_name in type_contexts
        }
    except SourceError as error:
        violations.append(error.message)
        ancestors_by_type = {type_name: set() for type_name in type_contexts}
    descendants_by_type = {type_name: set() for type_name in type_contexts}
    for type_name, ancestors in ancestors_by_type.items():
        for ancestor in ancestors:
            descendants_by_type.setdefault(ancestor, set()).add(type_name)
    for _, method in located_methods:
        if not method.network_callable_occurrences:
            continue
        type_name = _type_key(method.context)
        if not type_name:
            continue
        related_types = (
            {type_name}
            | ancestors_by_type.get(type_name, set())
            | descendants_by_type.get(type_name, set())
        )
        matching = sum(
            candidate.name == method.name
            for related in related_types
            for candidate in methods_by_type.get(related, ())
        )
        if matching > 1:
            overloaded_network_methods.add((type_name, method.name, method.line))

    udon_types: set[tuple[str, ...]] = set()
    unity_callback_types: set[tuple[str, ...]] = set()
    for type_name, contexts in type_contexts.items():
        try:
            if any(
                _base_binds_to_platform(
                    context, base_name, UDONSHARP_BEHAVIOUR_TYPE, local_types
                )
                for context in contexts
                for base_name in context.base_names
            ):
                udon_types.add(type_name)
            if any(
                _base_binds_to_platform(context, base_name, platform, local_types)
                for context in contexts
                for base_name in context.base_names
                for platform in UNITY_CALLBACK_BASE_TYPES
            ):
                unity_callback_types.add(type_name)
        except SourceError as error:
            violations.append(f"{'.'.join(type_name)}:{error.message}")
    changed = True
    while changed:
        changed = False
        for type_name, bases in inheritance.items():
            if type_name not in udon_types and bases & udon_types:
                udon_types.add(type_name)
                changed = True
            if (
                type_name not in unity_callback_types
                and bases & unity_callback_types
            ):
                unity_callback_types.add(type_name)
                changed = True

    unity_callback_types.update(udon_types)

    def callback_relevant(method: Method) -> bool:
        context = method.context
        if context is None:
            return (
                method.name in SDK_CALLBACK_SIGNATURES
                or method.name in UNITY_CALLBACK_SIGNATURES
            )
        type_name = _type_key(context)
        if method.name in SDK_CALLBACK_SIGNATURES:
            return type_name in udon_types
        if method.name in UNITY_CALLBACK_SIGNATURES:
            return type_name in unity_callback_types
        return type_name in udon_types

    invalid_callbacks: set[tuple[str, int, str]] = set()
    for shown_path, method in located_methods:
        if not callback_relevant(method):
            continue
        callback_error = callback_contract_error(method)
        if method.name in SDK_CALLBACK_SIGNATURES and method.access != "public":
            callback_error = "built-in Udon event modifier does not match SDK 3.10.4"
        if callback_error is not None:
            signature = f"{method.access} {method.return_type} {method.display_name}()"
            violations.append(
                f"{shown_path}:{method.line}: {callback_error}: {signature}"
            )
            invalid_callbacks.add((shown_path, method.line, method.name))

    for shown_path, declarations, methods in parsed_units:
            public_declarations = [
                declaration for declaration in declarations
                if declaration.kind != "nonpublic_method"
            ]
            counts["declaration"] += len(public_declarations)
            for method in methods:
                if not method.network_callable_occurrences:
                    continue
                counts["network_callable"] += 1
                location = f"{shown_path}:{method.line}"
                signature = (
                    f"{method.access} {method.return_type} "
                    f"{method.display_name}()"
                )
                if method.name in SDK_CALLBACK_SIGNATURES or method.name in UNITY_CALLBACK_SIGNATURES:
                    violations.append(
                        f"{location}: built-in Udon event cannot be NetworkCallable: {signature}"
                    )
                if method.access != "public":
                    violations.append(
                        f"{location}: NetworkCallable method must be public: {signature}"
                    )
                if method.return_type != "void":
                    violations.append(
                        f"{location}: NetworkCallable method must return void: {signature}"
                    )
                if not method.name.startswith("_"):
                    violations.append(
                        f"{location}: NetworkCallable method name must start with '_': {signature}"
                    )
                if "static" in method.modifiers:
                    violations.append(
                        f"{location}: NetworkCallable method must be an instance method: {signature}"
                    )
                for modifier in ("virtual", "override", "abstract", "extern", "async", "sealed"):
                    if modifier in method.modifiers:
                        violations.append(
                            f"{location}: NetworkCallable method cannot be {modifier}: {signature}"
                        )
                if method.generic:
                    violations.append(
                        f"{location}: NetworkCallable method cannot be generic: {signature}"
                    )
                if len(method.parameters) > 8:
                    violations.append(
                        f"{location}: NetworkCallable method cannot have more than 8 parameters: {signature}"
                    )
                for parameter in method.parameters:
                    if "params" in parameter.modifiers:
                        violations.append(
                            f"{location}: NetworkCallable parameter cannot use params: {signature}"
                        )
                    if parameter.modifiers & {"ref", "out", "in", "this"}:
                        violations.append(
                            f"{location}: NetworkCallable parameter cannot use ref, out, in, or this: {signature}"
                        )
                    if parameter.has_default:
                        violations.append(
                            f"{location}: NetworkCallable parameter cannot have a default value: {signature}"
                        )
                    if not parameter.supported:
                        violations.append(
                            f"{location}: unsupported NetworkCallable parameter type '{parameter.type_name}': {signature}"
                        )
                overload_key = (_type_key(method.context), method.name, method.line)
                if overload_key in overloaded_network_methods:
                    violations.append(
                        f"{location}: NetworkCallable method cannot be overloaded: {signature}"
                    )

            for declaration in public_declarations:
                method = declaration.method
                if method is None:
                    continue
                location = f"{shown_path}:{method.line}"
                signature = f"public {method.return_type} {method.display_name}()"

                if method.network_callable_occurrences:
                    continue

                if (shown_path, method.line, method.name) in invalid_callbacks:
                    continue

                if "static" in method.modifiers:
                    continue
                category = (
                    callback_category(method)
                    if callback_relevant(method)
                    or method.name in {"OnInspectorGUI", "OnPreprocess"}
                    else None
                )
                if category is not None:
                    counts[category] += 1
                    continue
                if not method.parameterless:
                    continue
                if method.name.startswith("_"):
                    counts["local"] += 1
                    continue
                violations.append(f"{location}: legacy network exposure: {signature}")

    return violations, counts


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: audit-udon-public-methods.py <path>", file=sys.stderr)
        return 2

    root = Path(sys.argv[1])
    if not root.exists():
        print(f"ERROR: audit path does not exist: {root}", file=sys.stderr)
        return 2

    violations, counts = audit_path(root)
    if violations:
        print(
            "ERROR: public method audit found malformed source, an unclassified "
            "public declaration, legacy exposure, or an invalid NetworkCallable declaration:",
            file=sys.stderr,
        )
        for violation in violations:
            print(f"  {violation}", file=sys.stderr)
        return 1

    total = sum(counts[key] for key in ("callback", "editor_callback", "network_callable", "local"))
    print(
        f"PASS: audited {total} public instance methods "
        f"({counts['callback']} runtime callbacks, "
        f"{counts['editor_callback']} editor callbacks, "
        f"{counts['network_callable']} NetworkCallable entries, "
        f"{counts['local']} local/custom underscore methods); "
        f"classified {counts['declaration']} public declarations"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
