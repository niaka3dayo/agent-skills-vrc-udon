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


UNITY_MESSAGE_ALLOWLIST = {
    "FixedUpdate",
    "LateUpdate",
    "OnDisable",
    "OnEnable",
    "Start",
    "Update",
}

UDON_OVERRIDE_CALLBACK_ALLOWLIST = {
    "Interact",
    "OnDeserialization",
    "OnDrop",
    "OnPersistenceUsageUpdated",
    "OnPickup",
    "OnPickupUseDown",
    "OnPickupUseUp",
    "OnPostSerialization",
    "OnPreSerialization",
    "OnSpawn",
    "OnVideoEnd",
    "OnVideoLoop",
    "OnVideoPause",
    "OnVideoPlay",
    "OnVideoReady",
    "OnVideoStart",
    "OnVRCQualitySettingsChanged",
    "PostLateUpdate",
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
    namespace: tuple[str, ...]
    type_path: tuple[str, ...]


@dataclass(frozen=True)
class Parameter:
    type_name: str
    modifiers: frozenset[str]
    has_default: bool
    supported: bool


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
    network_callable: bool
    line: int
    context: TypeContext | None


@dataclass(frozen=True)
class Declaration:
    kind: str
    line: int
    method: Method | None = None


@dataclass(frozen=True)
class SourceSegment:
    text: str
    first_line: int


@dataclass(frozen=True)
class MarkdownContainer:
    quote_depth: int
    list_indents: tuple[int, ...]


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
                index, line = _skip_quoted(source, prefix_end, line, verbatim=verbatim)
                continue

        if char in {'"', "'"}:
            index, line = _skip_quoted(source, index, line, verbatim=False)
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


def _list_marker(line: str) -> tuple[int, str] | None:
    """Strip one CommonMark list marker and return its content indentation."""
    match = re.match(r"^([ ]{0,3})([-+*]|[0-9]{1,9}[.)])(?:([ \t]+)|$)", line)
    if match is None:
        return None
    whitespace = match.group(3) or ""
    padding = len(whitespace.expandtabs(4))
    # CommonMark treats one to four following spaces as marker padding. Extra
    # spaces start indented content after the required single-space padding.
    used_padding = padding if 1 <= padding <= 4 else 1
    marker_end = len(match.group(1)) + len(match.group(2))
    indent = marker_end + used_padding
    content_start = marker_end + used_padding if whitespace else len(line)
    return indent, line[content_start:]


def _container_line(
    line: str,
    active_lists: dict[int, tuple[int, ...]],
) -> tuple[MarkdownContainer, str]:
    quote_depth, remaining = _strip_blockquotes(line)
    list_indents = active_lists.get(quote_depth, ())

    if list_indents:
        required = sum(list_indents)
        leading = len(remaining) - len(remaining.lstrip(" "))
        if remaining.strip() == "":
            return MarkdownContainer(quote_depth, list_indents), ""
        if leading >= required:
            remaining = remaining[required:]
        else:
            list_indents = ()

    parsed_indents = list(list_indents)
    while True:
        marker = _list_marker(remaining)
        if marker is None:
            break
        indent, remaining = marker
        parsed_indents.append(indent)

    active_lists[quote_depth] = tuple(parsed_indents)
    return MarkdownContainer(quote_depth, tuple(parsed_indents)), remaining


def _strip_fence_container(line: str, container: MarkdownContainer) -> str | None:
    quote_depth, remaining = _strip_blockquotes(line)
    if quote_depth != container.quote_depth:
        return None
    required = sum(container.list_indents)
    if required:
        if remaining.strip() == "":
            return ""
        leading = len(remaining) - len(remaining.lstrip(" "))
        if leading < required:
            return None
        remaining = remaining[required:]
    return remaining


def markdown_csharp_segments(text: str) -> list[SourceSegment]:
    """Extract outer C# fences, including valid quote/list containers."""
    segments: list[SourceSegment] = []
    active_lists: dict[int, tuple[int, ...]] = {}
    opener: MarkdownFence | None = None
    content: list[str] = []

    for line_number, original in enumerate(text.splitlines(keepends=True), start=1):
        newline = "\n" if original.endswith(("\n", "\r")) else ""
        line = original.rstrip("\r\n")
        if opener is None:
            container, remaining = _container_line(line, active_lists)
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
            container, remaining = _container_line(line, active_lists)
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
    if expanded == NETWORK_CALLABLE_TYPE:
        return True
    if expanded in local_types or declared_name in local_types:
        return False
    if expanded[-1:] == ("NetworkCallableAttribute",):
        raise SourceError(line, "cannot safely bind NetworkCallable attribute name")
    return False


def _attribute_names_before(
    tokens: list[Token],
    declaration_index: int,
    aliases: dict[str, tuple[str, ...]],
    imports: frozenset[tuple[str, ...]],
    context: TypeContext | None,
    local_types: frozenset[tuple[str, ...]],
) -> bool:
    cursor = declaration_index - 1
    found = False
    while cursor >= 0 and tokens[cursor].value == "]":
        left = _matching_left(tokens, cursor, "[", "]")
        if left is None:
            raise SourceError(tokens[cursor].line, "unmatched ']'")
        entry_start = left + 1
        paren_depth = bracket_depth = brace_depth = 0
        for index in range(left + 1, cursor + 1):
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
                found = found or _is_network_callable_name(
                    _attribute_entry_name(tokens[entry_start:index]),
                    aliases,
                    imports,
                    context,
                    local_types,
                    tokens[entry_start].line,
                )
                entry_start = index + 1
            if paren_depth < 0 or bracket_depth < 0 or brace_depth < 0:
                raise SourceError(tokens[index].line, "malformed attribute section")
        if paren_depth or bracket_depth or brace_depth:
            raise SourceError(tokens[left].line, "malformed attribute section")
        found = found or _is_network_callable_name(
            _attribute_entry_name(tokens[entry_start:cursor]),
            aliases,
            imports,
            context,
            local_types,
            tokens[entry_start].line,
        )
        cursor = left - 1
    return found


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


def _direct_base_names(tokens: list[Token]) -> frozenset[str]:
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
        return frozenset()

    bases: set[str] = set()
    segment: list[Token] = []
    angle_depth = 0
    sentinel = Token(",", ",", 0, "punctuation")
    for token in tokens[colon_index + 1:end] + [sentinel]:
        if token.value == "<":
            angle_depth += 1
        elif token.value == ">" and angle_depth:
            angle_depth -= 1
        if token.value == "," and angle_depth == 0:
            identifiers: list[str] = []
            segment_angle_depth = 0
            for item in segment:
                if item.value == "<":
                    segment_angle_depth += 1
                elif item.value == ">" and segment_angle_depth:
                    segment_angle_depth -= 1
                elif segment_angle_depth == 0 and item.kind == "identifier":
                    identifiers.append(item.value)
            if identifiers:
                bases.add(identifiers[-1])
            segment = []
        else:
            segment.append(token)
    return frozenset(bases)


def _raw_type_openings(tokens: list[Token]) -> dict[int, tuple[str, frozenset[str]]]:
    openings: dict[int, tuple[str, frozenset[str]]] = {}
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


def _namespace_openings(tokens: list[Token]) -> dict[int, tuple[str, ...]]:
    openings: dict[int, tuple[str, ...]] = {}
    for index, token in enumerate(tokens):
        if not _spelled(token, "namespace"):
            continue
        cursor = index + 1
        while cursor < len(tokens) and tokens[cursor].value not in {"{", ";"}:
            cursor += 1
        if cursor >= len(tokens):
            raise SourceError(token.line, "unterminated namespace declaration")
        if tokens[cursor].value == ";":
            raise SourceError(token.line, "file-scoped namespace is not safely classified")
        name = _qualified_name(tokens, index + 1, cursor)
        if name is None:
            raise SourceError(token.line, "malformed namespace declaration")
        openings[cursor] = name
    return openings


def _type_openings(tokens: list[Token]) -> dict[int, TypeContext]:
    raw_types = _raw_type_openings(tokens)
    namespaces = _namespace_openings(tokens)
    openings: dict[int, TypeContext] = {}
    namespace: tuple[str, ...] = ()
    type_path: tuple[str, ...] = ()
    frames: list[tuple[str, tuple[str, ...], tuple[str, ...]]] = []

    for index, token in enumerate(tokens):
        if token.value == "{":
            previous = (namespace, type_path)
            if index in namespaces:
                frames.append(("namespace", *previous))
                namespace = namespace + namespaces[index]
            elif index in raw_types:
                name, bases = raw_types[index]
                context = TypeContext(name, bases, namespace, type_path + (name,))
                openings[index] = context
                frames.append(("type", *previous))
                type_path = context.type_path
            else:
                frames.append(("other", *previous))
        elif token.value == "}" and frames:
            _, namespace, type_path = frames.pop()
    return openings


def _local_type_names(openings: dict[int, TypeContext]) -> frozenset[tuple[str, ...]]:
    return frozenset(
        context.namespace + context.type_path
        for context in openings.values()
        if context.name in {"NetworkCallable", "NetworkCallableAttribute"}
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
) -> tuple[str, bool]:
    array = False
    if len(type_tokens) >= 2 and [item.value for item in type_tokens[-2:]] == ["[", "]"]:
        array = True
        type_tokens = type_tokens[:-2]
    if any(item.value in {"[", "]", "<", ">", "?", "*"} for item in type_tokens):
        return "".join(item.raw for item in type_tokens), False
    name = _qualified_name(type_tokens, 0, len(type_tokens))
    if name is None:
        return "".join(item.raw for item in type_tokens), False
    name = _expand_alias(name, aliases)
    if len(name) == 1 and name[0] in SYNC_PRIMITIVES:
        supported = True
    elif len(name) == 1 and name[0] in SYSTEM_TYPE_ALIASES:
        supported = True
    elif len(name) == 2 and name[0] == "System" and name[1] in SYSTEM_TYPE_ALIASES:
        supported = True
    elif name in SYNC_STRUCTS:
        supported = True
    elif len(name) == 1 and any(candidate[-1] == name[0] for candidate in SYNC_STRUCTS):
        supported = True
    else:
        supported = False
    display = ".".join(name) + ("[]" if array else "")
    return display, supported


def _parse_parameters(
    tokens: list[Token],
    aliases: dict[str, tuple[str, ...]],
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
        type_name, supported = _supported_parameter_type(declaration[:-1], aliases)
        parameters.append(
            Parameter(type_name, frozenset(modifiers), equals is not None, supported)
        )
    return tuple(parameters)


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
        )
        method = Method(
            name=name_token.value,
            display_name=name_token.raw,
            return_type="".join(item.raw for item in header),
            modifiers=frozenset(modifiers),
            parameterless=not parameters,
            parameters=parameters,
            access=tokens[public_index].value,
            generic=tokens[paren_index - 1].value == ">",
            network_callable=network_callable,
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


def declarations_in_tokens(tokens: list[Token]) -> Iterable[Declaration]:
    openings = _type_openings(tokens)
    local_types = _local_type_names(openings)
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
) -> list[Method]:
    """Collect class members whose private accessibility is implicit."""
    openings = _type_openings(tokens)
    local_types = _local_type_names(openings)
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
                    parameters = _parse_parameters(tokens[index + 1:close_paren], aliases)
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
                            network_callable=_attribute_names_before(
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


def callback_category(method: Method) -> str | None:
    if method.return_type == "void" and method.name in UNITY_MESSAGE_ALLOWLIST:
        return "callback"
    if (
        method.return_type == "void"
        and method.name in UDON_OVERRIDE_CALLBACK_ALLOWLIST
        and "override" in method.modifiers
    ):
        return "callback"
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
                declarations = list(declarations_in_tokens(tokens))
                implicit_methods = implicit_methods_in_tokens(tokens)
            except SourceError as error:
                violations.append(f"{shown_path}:{error.line}: {error.message}")
                continue

            public_declarations = [
                declaration for declaration in declarations
                if declaration.kind != "nonpublic_method"
            ]
            counts["declaration"] += len(public_declarations)
            methods = [
                declaration.method for declaration in declarations
                if declaration.method is not None
            ] + implicit_methods
            method_names: dict[tuple[tuple[str, ...], str], int] = {}
            for method in methods:
                context_key = (
                    method.context.namespace + method.context.type_path
                    if method.context is not None else ()
                )
                key = (context_key, method.name)
                method_names[key] = method_names.get(key, 0) + 1
            for method in methods:
                if not method.network_callable:
                    continue
                counts["network_callable"] += 1
                location = f"{shown_path}:{method.line}"
                signature = (
                    f"{method.access} {method.return_type} "
                    f"{method.display_name}()"
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
                context_key = (
                    method.context.namespace + method.context.type_path
                    if method.context is not None else ()
                )
                if method_names.get((context_key, method.name), 0) > 1:
                    violations.append(
                        f"{location}: NetworkCallable method cannot be overloaded: {signature}"
                    )

            for declaration in public_declarations:
                method = declaration.method
                if method is None:
                    continue
                location = f"{shown_path}:{method.line}"
                signature = f"public {method.return_type} {method.display_name}()"

                if method.network_callable:
                    continue

                if not method.parameterless or "static" in method.modifiers:
                    continue
                if method.name.startswith("_"):
                    counts["local"] += 1
                    continue
                category = callback_category(method)
                if category is not None:
                    counts[category] += 1
                else:
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
