#!/usr/bin/env python3
"""Audit public UdonSharp method exposure in C# source and Markdown examples.

The audit uses a small C# lexer instead of line-oriented regular expressions.
It scans complete ``.cs`` files and C#-labelled Markdown fences while ignoring
prose, comments, and literal contents. Public instance methods with no
parameters are legacy network-call targets even when they return a value; the
network dispatcher discards that value.

Allowed parameterless public instance methods are limited to:

* standard Unity messages with their expected ``void`` return type;
* overridden Udon callbacks in the narrow allowlist below;
* two exact editor framework callbacks, verified against their enclosing type;
* underscore-prefixed local/custom methods; and
* underscore-prefixed ``[NetworkCallable]`` methods that return ``void``.

The former ``NETWORK-EXPOSURE: LEGACY`` comment is intentionally unsupported.
A comment cannot suppress this audit or turn a copyable example into an
approved legacy entry point.
"""

from __future__ import annotations

from dataclasses import dataclass
import re
import sys
from pathlib import Path
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
CSHARP_FENCE_LANGUAGES = {"c#", "cs", "csharp"}


@dataclass(frozen=True)
class Token:
    value: str
    line: int


@dataclass(frozen=True)
class TypeContext:
    name: str
    bases: frozenset[str]


@dataclass(frozen=True)
class Method:
    name: str
    return_type: str
    modifiers: frozenset[str]
    parameterless: bool
    network_callable: bool
    line: int
    context: TypeContext | None


@dataclass(frozen=True)
class SourceSegment:
    text: str
    first_line: int


def _skip_quoted(source: str, start: int, line: int, *, verbatim: bool) -> tuple[int, int]:
    """Skip a normal, verbatim, interpolated, or raw C# string literal."""
    quote = source[start]
    quote_count = 1
    while start + quote_count < len(source) and source[start + quote_count] == quote:
        quote_count += 1

    if quote == '"' and quote_count >= 3:
        delimiter = '"' * quote_count
        end = source.find(delimiter, start + quote_count)
        if end < 0:
            return len(source), line + source[start:].count("\n")
        literal_end = end + quote_count
        return literal_end, line + source[start:literal_end].count("\n")

    index = start + 1
    while index < len(source):
        char = source[index]
        if char == "\n":
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
    return index, line


def lex_csharp(source: str, first_line: int = 1) -> list[Token]:
    """Return declaration-relevant C# tokens without comments or literals."""
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
                line += source[index:].count("\n")
                break
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

        if char.isalpha() or char == "_":
            end = index + 1
            while end < len(source) and (source[end].isalnum() or source[end] == "_"):
                end += 1
            tokens.append(Token(source[index:end], line))
            index = end
            continue

        if char.isdigit():
            end = index + 1
            while end < len(source) and (source[end].isalnum() or source[end] in "._"):
                end += 1
            tokens.append(Token(source[index:end], line))
            index = end
            continue

        two_chars = source[index:index + 2]
        if two_chars in {"=>", "::", "??", "?.", "==", "!=", "<=", ">="}:
            tokens.append(Token(two_chars, line))
            index += 2
            continue

        tokens.append(Token(char, line))
        index += 1

    return tokens


def markdown_csharp_segments(text: str) -> list[SourceSegment]:
    """Extract only explicitly C#-labelled fenced blocks from Markdown."""
    segments: list[SourceSegment] = []
    lines = text.splitlines(keepends=True)
    opener: tuple[str, int] | None = None
    first_line = 0
    content: list[str] = []

    for line_number, line in enumerate(lines, start=1):
        if opener is None:
            match = re.match(r"^[ ]{0,3}(`{3,}|~{3,})[ \t]*([^ \t\r\n]*)", line)
            if match is None:
                continue
            fence = match.group(1)
            language = match.group(2).lower()
            if language not in CSHARP_FENCE_LANGUAGES:
                continue
            opener = (fence[0], len(fence))
            first_line = line_number + 1
            content = []
            continue

        fence_char, fence_length = opener
        if re.match(rf"^[ ]{{0,3}}{re.escape(fence_char)}{{{fence_length},}}[ \t]*$", line.rstrip("\r\n")):
            segments.append(SourceSegment("".join(content), first_line))
            opener = None
            content = []
        else:
            content.append(line)

    if opener is not None:
        segments.append(SourceSegment("".join(content), first_line))
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


def _attribute_names_before(tokens: list[Token], declaration_index: int) -> set[str]:
    """Read attribute groups directly attached to this declaration only."""
    names: set[str] = set()
    cursor = declaration_index - 1
    while cursor >= 0 and tokens[cursor].value == "]":
        left = _matching_left(tokens, cursor, "[", "]")
        if left is None:
            break
        names.update(
            token.value
            for token in tokens[left + 1:cursor]
            if token.value in {"NetworkCallable", "NetworkCallableAttribute"}
        )
        cursor = left - 1
    return names


def _method_name_before_paren(tokens: list[Token], paren_index: int) -> tuple[str, int] | None:
    previous = paren_index - 1
    if previous < 0:
        return None
    if re.match(r"^[A-Za-z_]\w*$", tokens[previous].value):
        return tokens[previous].value, previous
    if tokens[previous].value != ">":
        return None
    generic_left = _matching_left(tokens, previous, "<", ">")
    if generic_left is None or generic_left == 0:
        return None
    name_index = generic_left - 1
    if not re.match(r"^[A-Za-z_]\w*$", tokens[name_index].value):
        return None
    return tokens[name_index].value, name_index


def parse_method(
    tokens: list[Token], public_index: int, context: TypeContext | None
) -> Method | None:
    declaration_index = public_index
    modifiers: set[str] = set()
    while (
        declaration_index > 0
        and tokens[declaration_index - 1].value in METHOD_MODIFIERS
    ):
        declaration_index -= 1
        modifiers.add(tokens[declaration_index].value)

    cursor = public_index + 1
    while cursor < len(tokens) and tokens[cursor].value in METHOD_MODIFIERS:
        modifiers.add(tokens[cursor].value)
        cursor += 1

    if cursor >= len(tokens) or tokens[cursor].value in TYPE_KEYWORDS | {"delegate", "enum", "event"}:
        return None

    paren_index: int | None = None
    scan = cursor
    while scan < len(tokens):
        value = tokens[scan].value
        if value in {";", "{", "}", "=", "=>"}:
            return None
        if value == "(":
            candidate = _method_name_before_paren(tokens, scan)
            if candidate is not None and candidate[1] >= cursor:
                paren_index = scan
                break
        scan += 1
    if paren_index is None:
        return None

    name_and_index = _method_name_before_paren(tokens, paren_index)
    if name_and_index is None:
        return None
    name, name_index = name_and_index
    return_tokens = tokens[cursor:name_index]

    if not return_tokens:
        return None

    close_paren = _matching_right(tokens, paren_index, "(", ")")
    if close_paren is None:
        return None
    parameterless = close_paren == paren_index + 1
    return_type = "".join(token.value for token in return_tokens)
    attributes = _attribute_names_before(tokens, declaration_index)

    return Method(
        name=name,
        return_type=return_type,
        modifiers=frozenset(modifiers),
        parameterless=parameterless,
        network_callable=bool(
            {"NetworkCallable", "NetworkCallableAttribute"} & attributes
        ),
        line=tokens[public_index].line,
        context=context,
    )


def _find_type_after(tokens: list[Token], keyword_index: int) -> tuple[str, int] | None:
    cursor = keyword_index + 1
    if tokens[keyword_index].value == "record" and cursor < len(tokens) and tokens[cursor].value in {"class", "struct"}:
        cursor += 1
    if cursor >= len(tokens) or not re.match(r"^[A-Za-z_]\w*$", tokens[cursor].value):
        return None
    return tokens[cursor].value, cursor


def _direct_base_names(tokens: list[Token]) -> frozenset[str]:
    """Return direct base/interface names, excluding generic arguments."""
    angle_depth = 0
    colon_index: int | None = None
    end = len(tokens)

    for index, token in enumerate(tokens):
        if token.value == "<":
            angle_depth += 1
        elif token.value == ">" and angle_depth:
            angle_depth -= 1
        elif angle_depth == 0 and token.value == "where":
            end = index
            break
        elif angle_depth == 0 and token.value == ":" and colon_index is None:
            colon_index = index

    if colon_index is None or colon_index >= end:
        return frozenset()

    bases: set[str] = set()
    segment: list[Token] = []
    angle_depth = 0
    for token in tokens[colon_index + 1:end] + [Token(",", 0)]:
        if token.value == "<":
            angle_depth += 1
        elif token.value == ">" and angle_depth:
            angle_depth -= 1
        if token.value == "," and angle_depth == 0:
            prefix = segment
            if any(item.value == "<" for item in prefix):
                prefix = prefix[:next(
                    index for index, item in enumerate(prefix) if item.value == "<"
                )]
            identifiers = [
                item.value
                for item in prefix
                if re.match(r"^[A-Za-z_]\w*$", item.value)
                and item.value != "global"
            ]
            if identifiers:
                bases.add(identifiers[-1])
            segment = []
        else:
            segment.append(token)

    return frozenset(bases)


def methods_in_tokens(tokens: list[Token]) -> Iterable[Method]:
    type_stack: list[TypeContext | None] = []
    pending_type: tuple[str, int] | None = None

    for index, token in enumerate(tokens):
        if token.value in TYPE_KEYWORDS:
            found = _find_type_after(tokens, index)
            if found is not None:
                pending_type = found

        if token.value == "public":
            context = next((item for item in reversed(type_stack) if item is not None), None)
            method = parse_method(tokens, index, context)
            if method is not None:
                yield method

        if token.value == "{":
            if pending_type is None:
                type_stack.append(None)
            else:
                type_name, name_index = pending_type
                declaration_tokens = tokens[name_index + 1:index]
                type_stack.append(
                    TypeContext(type_name, _direct_base_names(declaration_tokens))
                )
                pending_type = None
        elif token.value == "}" and type_stack:
            type_stack.pop()
        elif token.value == ";" and pending_type is not None:
            pending_type = None


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
    }

    for path in paths:
        for segment in source_segments(path):
            tokens = lex_csharp(segment.text, segment.first_line)
            for method in methods_in_tokens(tokens):
                location = f"{display_path(path, root)}:{method.line}"
                signature = f"public {method.return_type} {method.name}()"

                if method.network_callable:
                    if method.return_type != "void":
                        violations.append(
                            f"{location}: NetworkCallable method must return void: {signature}"
                        )
                    if not method.name.startswith("_"):
                        violations.append(
                            f"{location}: NetworkCallable method name must start with '_': {signature}"
                        )

                if not method.parameterless or "static" in method.modifiers:
                    continue

                if method.network_callable:
                    counts["network_callable"] += 1
                elif method.name.startswith("_"):
                    counts["local"] += 1
                else:
                    category = callback_category(method)
                    if category is not None:
                        counts[category] += 1
                    else:
                        violations.append(
                            f"{location}: legacy network exposure: {signature}"
                        )

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
            "ERROR: public method audit found legacy exposure or an invalid "
            "NetworkCallable declaration:",
            file=sys.stderr,
        )
        for violation in violations:
            print(f"  {violation}", file=sys.stderr)
        return 1

    total = sum(counts.values())
    print(
        "PASS: audited "
        f"{total} parameterless public instance methods "
        f"({counts['callback']} runtime callbacks, "
        f"{counts['editor_callback']} editor callbacks, "
        f"{counts['network_callable']} NetworkCallable entries, "
        f"{counts['local']} local/custom underscore methods)"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
