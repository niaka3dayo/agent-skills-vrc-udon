#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LAYERS_REF="$ROOT_DIR/skills/unity-vrc-world-sdk-3/references/layers.md"
CONTRIBUTING="$ROOT_DIR/CONTRIBUTING.md"
RENOVATOR_CHECKLIST="$ROOT_DIR/.claude/skills/unity-vrc-skills-renovator/references/update-checklist.md"
CI="$ROOT_DIR/.github/workflows/ci.yml"

require_file() {
    local path="$1"
    if [[ ! -f "$path" ]]; then
        echo "ERROR: missing file: $path" >&2
        exit 1
    fi
}

require_text() {
    local path="$1"
    local needle="$2"
    if ! grep -Fq -- "$needle" "$path"; then
        echo "ERROR: $path does not contain expected text: $needle" >&2
        exit 1
    fi
}

require_normalized_text() {
    local path="$1"
    local needle="$2"
    if ! python3 - "$path" "$needle" <<'PY'
import re
import sys
import unicodedata
from pathlib import Path

text = unicodedata.normalize("NFKC", Path(sys.argv[1]).read_text())
needle = unicodedata.normalize("NFKC", sys.argv[2])
normalized = re.sub(r"\s+", " ", text)
raise SystemExit(0 if needle in normalized else 1)
PY
    then
        echo "ERROR: $path does not contain expected normalized text: $needle" >&2
        exit 1
    fi
}

require_file "$LAYERS_REF"
require_file "$CONTRIBUTING"
require_file "$RENOVATOR_CHECKLIST"

count_exact_line() {
    local text="$1"
    local needle="$2"

    printf '%s\n' "$text" | awk -v needle="$needle" '$0 == needle { count++ } END { print count + 0 }'
}

count_exact_line_in_file() {
    local path="$1"
    local needle="$2"

    awk -v needle="$needle" '$0 == needle { count++ } END { print count + 0 }' "$path"
}

first_exact_line() {
    local text="$1"
    local needle="$2"

    printf '%s\n' "$text" | awk -v needle="$needle" '$0 == needle { print NR; exit }'
}

extract_section() {
    local path="$1"
    local start_heading="$2"
    local end_heading="$3"

    awk -v start_heading="$start_heading" -v end_heading="$end_heading" '
        $0 == start_heading { in_section = 1; print; next }
        in_section && $0 == end_heading { exit }
        in_section { print }
    ' "$path"
}

contains_positive_name_dump_collision_assignment() {
    local markdown="$1"

    python3 - "$markdown" <<'PY'
import bisect
import re
import sys
import unicodedata

text = unicodedata.normalize("NFKC", sys.argv[1]).casefold()
subject_pattern = r"(?:#\s*286\b|\blayer[\s‐‑‒–—-]*dump\b)"
collision_pattern = (
    r"\b(?:built[\s-]*in\s+)?collision(?:s|\s+"
    r"(?:claims?|behavior|evidence|matrix|pairs?|proof|validation))?\b"
)
subject = re.compile(subject_pattern)
collision = re.compile(collision_pattern)
directive = re.compile(
    r"^\s*"
    r"(?:(?:but|however|instead)\s+)?"
    r"(?P<lead>(?:(?:reviewers?|maintainers?|agents?|contributors?|we|you)\s+)?"
    r"(?:(?:always|must|should|may|can)\s+|(?:is|are)\s+required\s+to\s+|"
    r"(?:do\s+not|don't|never|cannot|can't|must\s+not|should\s+not|"
    r"may\s+not|can\s+not|could\s+not|would\s+not)\s+)?)"
    r"(?P<verb>use|cite|treat|regard|consider|accept|base|derive|rely)\b"
)
directive_negation = re.compile(
    r"\b(?:do\s+not|don't|never|cannot|can't|must\s+not|should\s+not|"
    r"may\s+not|can\s+not|could\s+not|would\s+not)\b"
)
evidential_relation = re.compile(
    r"\b(?:provides?|proves?|confirms?|validates?|verifies?|demonstrates?|shows?|"
    r"establishes?|corroborates?|constitutes?|supports?|"
    r"serves?\s+as|counts?\s+as|(?:should|must|may|can)\s+be\s+"
    r"(?:used|cited|treated|regarded|accepted)\s+as|"
    r"(?:could|would)\s+(?:not\s+)?be\s+"
    r"(?:used|cited|treated|regarded|accepted)\s+as)\b"
)
copula = re.compile(r"\b(?:is|are|was|were)\b")
reverse_relation = re.compile(
    r"\b(?:(?:(?:should|must|may|can|could|would)\s+(?:not\s+)?)?"
    r"(?:comes?\s+from|follows?\s+from|derives?\s+from|rel(?:y|ies)\s+on)|"
    r"(?:(?:should|must|may|can|could|would)\s+(?:not\s+)?be\s+)?"
    r"based\s+on|(?:is|are|was|were)\s+(?:not\s+)?"
    r"(?:provided|proven|confirmed|supported|validated|corroborated)\s+by|uses?|cites?)\b"
)
negative_word = re.compile(r"\b(?:not|never|cannot|can't|neither|no)\b")
assignment_connector = re.compile(r"\b(?:as|for)\b")
role_exclusion = re.compile(
    r"\b(?:names?|review(?:ing)?|evaluat(?:e|ing)|explain|separate|"
    r"independent|distinct|unrelated|required)\b"
)


def markdown_units(value):
    current = []

    def flush():
        if current:
            yield " ".join(current)
            current.clear()

    for raw_line in value.splitlines():
        line = re.sub(r"^(?:\s*>\s?)+", "", raw_line).strip()
        if not line:
            yield from flush()
            continue
        if re.match(r"^#{1,6}\s+", line):
            yield from flush()
            continue
        item = re.match(r"^(?:[-*+]|\d+[.)])\s+(?:\[[ x]\]\s*)?(.*)$", line)
        if item:
            yield from flush()
            current.append(item.group(1))
            continue
        current.append(line)
    yield from flush()


def clauses(value):
    for unit in markdown_units(value):
        for sentence in re.split(r"[.!?;]+", unit):
            sentence = sentence.strip()
            if not sentence:
                continue
            if "not only" in sentence:
                yield sentence
                continue
            yield from (
                part.strip()
                for part in re.split(r",\s*(?=(?:but|however|instead)\b)", sentence)
                if part.strip()
            )


def relation_is_negated(clause, relation):
    if negative_word.search(relation.group(0)):
        return True
    prefix = clause[:relation.start()]
    boundary = max(
        prefix.rfind(","),
        prefix.rfind(" but "),
        prefix.rfind(" however "),
        prefix.rfind(" instead "),
    )
    local = prefix[boundary + 1:]
    following = clause[relation.end():relation.end() + 40]
    return bool(
        re.match(r"\s*(?:no|neither)\b", following)
        or re.match(r"\s*(?:no|neither)\b", local)
        or re.search(
        r"\b(?:does?|did|can|could|should|must|may|would|is|are|was|were)\s+"
        r"not(?:\s+\w+){0,2}\s*$|\b(?:doesn't|didn't|isn't|aren't)\s*$|"
        r"\bfails?\s+to\s*$|\b(?:cannot|can't)(?:\s+\w+){0,2}\s*$|\bnever\s*$",
        local,
        )
    )


def directive_assigns(clause, instruction, subjects, collisions):
    if directive_negation.search(instruction.group("lead")):
        return False
    if re.match(r"\s*(?:no|never)\b", clause[instruction.end():]):
        return False

    entities = sorted(
        [(match.start(), "subject", match) for match in subjects]
        + [(match.start(), "collision", match) for match in collisions]
    )
    for left, right in zip(entities, entities[1:]):
        if left[1] == right[1]:
            continue
        if left[1] == "subject":
            subject_match = left[2]
            collision_match = right[2]
            between = clause[subject_match.end():collision_match.start()]
            connectors = list(assignment_connector.finditer(between))
            if connectors:
                connector = connectors[-1]
                prefix = between[max(0, connector.start() - 12):connector.start()]
                target_gap = between[connector.end():]
                if not re.search(r"\b(?:not|never|rather\s+than)\s*$", prefix) \
                        and not role_exclusion.search(target_gap):
                    return True
            purpose = re.search(
                r"\bto\s+(?:validate|prove|support|confirm|corroborate)\b",
                between,
            )
            if purpose and not role_exclusion.search(between[purpose.end():]):
                return True
        else:
            collision_match = left[2]
            subject_match = right[2]
            between = clause[collision_match.end():subject_match.start()]
            if re.search(r"\b(?:from|on|based\s+on)\b", between) and not re.search(
                r"\b(?:not|never|other\s+than|independent\s+of)\b", between
            ):
                return True
    return False


def is_positive_assignment(clause):
    subjects = list(subject.finditer(clause))
    collisions = list(collision.finditer(clause))
    if not subjects or not collisions:
        return False

    instruction = directive.match(clause)
    if instruction:
        return directive_assigns(clause, instruction, subjects, collisions)

    collision_starts = [item.start() for item in collisions]

    for subject_match in subjects:
        tail = clause[subject_match.end():subject_match.end() + 220]
        for local_relation in evidential_relation.finditer(tail):
            relation_start = subject_match.end() + local_relation.start()
            relation_end = subject_match.end() + local_relation.end()
            relation = re.compile(re.escape(local_relation.group(0))).search(
                clause, relation_start, relation_end
            )
            if relation and not relation_is_negated(clause, relation):
                index = bisect.bisect_left(collision_starts, relation.end())
                if index < len(collisions):
                    item = collisions[index]
                    if item.start() <= relation.end() + 120:
                        target_gap = clause[relation.end():item.start()]
                        if not negative_word.search(target_gap) \
                                and not role_exclusion.search(target_gap):
                            return True

        for relation in copula.finditer(clause, subject_match.end(), subject_match.end() + 80):
            following = clause[relation.end():relation.end() + 140]
            if re.match(r"\s*not\s+only\b", following) and re.search(
                rf"\bbut\s+also\b[^,;]{{0,80}}{collision_pattern}", following
            ):
                return True
            if re.match(r"\s*(?:not|never|neither|unrelated|insufficient)\b|\s*n't\b", following):
                continue
            if collision.search(following) and re.search(
                r"\b(?:evidence|proof|support|basis|source|validation)\b", following
            ):
                return True

    for relation in reverse_relation.finditer(clause):
        before = clause[max(0, relation.start() - 140):relation.start()]
        after = clause[relation.end():relation.end() + 96]
        if not (collision.search(before) and subject.search(after)):
            continue
        if not relation_is_negated(clause, relation):
            return True

    return False


raise SystemExit(0 if any(is_positive_assignment(clause) for clause in clauses(text)) else 1)
PY
}

contains_official_first_order() {
    local markdown="$1"

    python3 - "$markdown" <<'PY'
import re
import sys
import unicodedata

text = unicodedata.normalize("NFKC", sys.argv[1]).casefold()
text = re.sub(r"\s+", " ", text)
command = re.compile(
    r"\b(?:rank(?:\s+evidence)?|prioritize|prefer|defer\s+to|treat)\b"
)
official = r"official\s+(?:docs?|documentation)"
runtime = r"(?:reproducible\s+)?runtime\s+observations?"

precedence = re.compile(
    rf"\b{official}\b(?P<middle>.{{0,80}}?)"
    rf"(?:takes?\s+precedence\s+over|(?:is|are|be)\s+prioriti[sz]ed\s+over|"
    rf"(?:is|are)\s+authoritative\s+over|has\s+priority\s+over|outranks?|"
    rf"supersedes?|comes?\s+before|(?:is|are)\s+the\s+highest\s+priority"
    rf".{{0,32}}?ahead\s+of|>)"
    rf".{{0,80}}\b{runtime}\b"
)
for relation in precedence.finditer(text):
    if not re.search(r"\bnot\b", relation.group("middle")):
        raise SystemExit(0)

if re.search(
    rf"\bgive\s+{official}\b.{{0,48}}\bpriority\s+over\b.{{0,80}}\b{runtime}\b",
    text,
):
    raise SystemExit(0)

order = re.search(
    rf"\b(?:the\s+)?evidence\s+order\b.{{0,80}}\b{official}\b"
    rf".{{0,100}}\b{runtime}\b",
    text,
)
if order:
    order_text = order.group(0)
    if re.search(official, order_text).start() < re.search(runtime, order_text).start():
        raise SystemExit(0)

for match in command.finditer(text):
    prefix = text[max(0, match.start() - 24):match.start()]
    if re.search(r"\b(?:do\s+not|never|must\s+not|should\s+not)\s*$", prefix):
        continue
    window = text[match.end():match.end() + 220]
    window = re.split(r"[.!?;]", window, maxsplit=1)[0]
    official_match = re.search(official, window)
    if official_match is None:
        continue
    official_position = official_match.start()
    runtime_position = window.find("runtime")
    shipped = window.find("shipped sdk/source")
    earlier = [position for position in (runtime_position, shipped) if position >= 0]
    if not earlier or official_position < min(earlier):
        raise SystemExit(0)
    if re.search(rf"{official}.{{0,48}}\b(?:first|before)\b", window):
        raise SystemExit(0)

raise SystemExit(1)
PY
}

count_active_ci_contract_run() {
    local yaml="$1"
    python3 - "$yaml" <<'PY'
import re
import sys

lines = sys.argv[1].splitlines()
in_docs = False
job_disabled = False
job_non_gating = False
steps = []
current = None


def scalar(value):
    value = value.strip()
    if len(value) >= 2 and value[0] == value[-1] and value[0] in "\"'":
        value = value[1:-1].strip()
    return re.sub(r"\s+", " ", value).casefold()


def false_scalar(value):
    return scalar(value) in {"false", "${{ false }}"}


def true_scalar(value):
    return scalar(value) in {"true", "${{ true }}"}

for line in lines:
    if re.fullmatch(r"  docs:\s*", line):
        in_docs = True
        continue
    if in_docs and re.fullmatch(r"  [A-Za-z0-9_-]+:\s*", line):
        break
    if not in_docs:
        continue
    job_field = re.match(r"^    (if|continue-on-error):\s*(.*?)\s*$", line, re.I)
    if job_field:
        if job_field.group(1).casefold() == "if" and false_scalar(job_field.group(2)):
            job_disabled = True
        if job_field.group(1).casefold() == "continue-on-error" \
                and true_scalar(job_field.group(2)):
            job_non_gating = True
    step = re.match(r"^      -\s+(.*)$", line)
    if step:
        if current is not None:
            steps.append(current)
        current = [step.group(1)]
    elif current is not None and re.match(r"^        \S", line):
        current.append(line.strip())

if current is not None:
    steps.append(current)

count = 0
for step in steps:
    parsed = {}
    for field in step:
        match = re.match(r"^([A-Za-z0-9_-]+):\s*(.*?)\s*$", field)
        if match:
            parsed.setdefault(match.group(1).casefold(), []).append(match.group(2))
    if any(false_scalar(value) for value in parsed.get("if", [])):
        continue
    if any(true_scalar(value) for value in parsed.get("continue-on-error", [])):
        continue
    for command in parsed.get("run", []):
        command = scalar(command)
        if command == "bash tests/docs/layers-reference-contract.test.sh":
            count += 1

print(0 if job_disabled or job_non_gating else count)
PY
}

assert_positive_collision_assignment() {
    local text="$1"
    if ! contains_positive_name_dump_collision_assignment "$text"; then
        echo "ERROR: positive #286 collision-evidence assignment was not detected: $text" >&2
        exit 1
    fi
}

assert_nonpositive_collision_assignment() {
    local text="$1"
    if contains_positive_name_dump_collision_assignment "$text"; then
        echo "ERROR: non-positive #286 collision-evidence statement was rejected: $text" >&2
        exit 1
    fi
}

# Exercise polarity and both assignment orders independently of the current
# policy prose. This keeps a future wording change from weakening the gate.
for statement in \
    "Use #286 layer-dump as built-in collision evidence." \
    "Use the #286 layer-dump as evidence for built-in collision claims." \
    "Cite #286 as proof for built-in collision claims." \
    "The #286 layer-dump is built-in collision evidence." \
    "The #286 layer-dump provides proof for built-in collision behavior." \
    "Use built-in collision evidence from the #286 layer-dump." \
    "Cite proof for built-in collision claims from #286." \
    "The #286 layer-dump validates built-in collision behavior." \
    "Built-in collision evidence comes from the #286 layer-dump." \
    "Built-in collision validation relies on the #286 layer-dump." \
    "#286 supports built-in collision claims." \
    "#286 is the source for built-in collision behavior." \
    "Reviewers must use #286 as built-in collision evidence." \
    "#286 should be used as proof for built-in collision claims." \
    "The #286 layer-dump could be used as proof for built-in collision claims." \
    "Built-in collision evidence is provided by the #286 layer-dump." \
    "Built-in collision evidence should be based on the #286 layer-dump." \
    "Reviewers are required to use #286 as built-in collision evidence." \
    "- [x] Use #286 as built-in collision evidence." \
    "The #286 layer-dump, which does not list names, provides proof for built-in collision behavior." \
    "The #286 layer-dump does not prove names but validates built-in collision behavior." \
    "#286 is not only name evidence but also built-in collision evidence." \
    "Use #286 to validate built-in collision behavior." \
    "Base built-in collision claims on the #286 layer-dump." \
    "Derive built-in collision claims from the #286 layer-dump." \
    "Rely on #286 for built-in collision claims." \
    "Built-in collision behavior is proven by the #286 layer-dump." \
    "#286 corroborates built-in collision behavior." \
    "#286 demonstrates built-in collision behavior." \
    "#286 shows that the built-in collision matrix is retained." \
    "#286 establishes proof for built-in collision pairs." \
    "#286 verifies built-in collision behavior." \
    "Built-in collision behavior follows from #286." \
    "Built-in collision evidence may rely on #286." \
    "Do not use official docs alone, but use #286 as built-in collision evidence." \
    "Use #286 not only as name evidence but also as built-in collision evidence." \
    "Use #286 not only for names but also for built-in collision claims."; do
    assert_positive_collision_assignment "$statement"
done

for statement in \
    "Prioritize official docs, then shipped SDK/source, then reproducible runtime observation." \
    "Rank evidence with official docs first, before runtime observation." \
    "Official docs take precedence over runtime observation." \
    "Official docs should be prioritized over reproducible runtime observation." \
    "Give official documentation priority over runtime observations." \
    "Prefer official documentation over shipped SDK/source and runtime observation." \
    "Rank evidence as runtime observation, SDK/source, then official docs. Official docs are authoritative over runtime observation." \
    "Official docs outrank runtime observations." \
    "Official docs supersede runtime observations." \
    "Official docs come before runtime observations." \
    "Defer to official docs over runtime observations." \
    "Treat official docs as primary over runtime observations." \
    "The evidence order is official docs, shipped SDK/source, runtime observations." \
    "Official docs are the highest priority, ahead of runtime observations." \
    "Official docs > shipped SDK/source > runtime observation."; do
    if ! contains_official_first_order "$statement"; then
        echo "ERROR: official-first evidence order was not detected: $statement" >&2
        exit 1
    fi
done

for statement in \
    "Rank evidence as reproducible runtime observation, shipped SDK/source, then official docs." \
    "Do not prioritize official docs over reproducible runtime evidence." \
    "Official docs should not be prioritized over runtime observation." \
    "Official docs do not outrank runtime observations." \
    "Do not defer to official docs over runtime observations." \
    "Prefer runtime observation over official docs; consult official docs first for intended behavior."; do
    if contains_official_first_order "$statement"; then
        echo "ERROR: valid evidence order was rejected: $statement" >&2
        exit 1
    fi
done

CI_SELF_CONTRACT=$'jobs:\n  docs:\n    steps:\n      - name: contract\n        run: "bash tests/docs/layers-reference-contract.test.sh"\n  other:\n    steps:\n      - name: false command\n        run: printf tests/docs/layers-reference-contract.test.sh'
if [[ "$(count_active_ci_contract_run "$CI_SELF_CONTRACT")" -ne 1 ]]; then
    echo "ERROR: active docs-job CI command was not detected exactly once" >&2
    exit 1
fi
for invalid_ci in \
    $'jobs:\n  docs:\n    steps:\n      # run: bash tests/docs/layers-reference-contract.test.sh' \
    $'jobs:\n  docs:\n    steps:\n      - name: false command\n        run: printf tests/docs/layers-reference-contract.test.sh' \
    $'jobs:\n  docs:\n    if: false\n    steps:\n      - name: disabled job\n        run: bash tests/docs/layers-reference-contract.test.sh' \
    $'jobs:\n  docs:\n    steps:\n      - name: disabled step\n        if: false\n        run: bash tests/docs/layers-reference-contract.test.sh' \
    $'jobs:\n  docs:\n    steps:\n      - name: non-gating\n        continue-on-error: true\n        run: bash tests/docs/layers-reference-contract.test.sh' \
    $'jobs:\n  docs:\n    if: "false"\n    steps:\n      - run: bash tests/docs/layers-reference-contract.test.sh' \
    $'jobs:\n  docs:\n    continue-on-error: true\n    steps:\n      - run: bash tests/docs/layers-reference-contract.test.sh' \
    $'jobs:\n  docs:\n    steps:\n      - if: "false"\n        run: bash tests/docs/layers-reference-contract.test.sh' \
    $'jobs:\n  docs:\n    steps:\n      - if: "${{ false }}"\n        run: bash tests/docs/layers-reference-contract.test.sh' \
    $'jobs:\n  docs:\n    steps:\n      - continue-on-error: "true"\n        run: bash tests/docs/layers-reference-contract.test.sh' \
    $'jobs:\n  docs:\n    steps:\n      - continue-on-error: ${{ true }}\n        run: bash tests/docs/layers-reference-contract.test.sh' \
    $'jobs:\n  other:\n    steps:\n      - name: wrong job\n        run: bash tests/docs/layers-reference-contract.test.sh'; do
    if [[ "$(count_active_ci_contract_run "$invalid_ci")" -ne 0 ]]; then
        echo "ERROR: inactive or false CI wiring was accepted" >&2
        exit 1
    fi
done
assert_positive_collision_assignment $'### Evidence gate\nUse #286 as built-in collision evidence.'

for statement in \
    "Do not use the #286 layer-dump as built-in collision evidence." \
    "Never cite #286 as proof for built-in collision claims." \
    "The #286 layer-dump is not built-in collision evidence." \
    "The #286 layer-dump does not provide proof for built-in collision behavior." \
    "Use #286 as name evidence, not as built-in collision evidence." \
    "Use #286 only as names evidence; do not cite it as proof for built-in collision claims." \
    "No built-in collision evidence comes from the #286 layer-dump." \
    "The #286 layer-dump is unrelated to built-in collision behavior." \
    "Use built-in collision evidence from a source other than the #286 layer-dump." \
    "Use #286 for names rather than as built-in collision evidence." \
    "Use #286 for names, not for built-in collision claims." \
    "Use built-in collision evidence independent of the #286 layer-dump." \
    "Use #286 for names only—never for built-in collisions." \
    "The #286 layer-dump provides evidence for names, not built-in collision behavior." \
    "The #286 layer-dump is neither proof nor evidence for built-in collision behavior." \
    "Built-in collision validation does not rely on the #286 layer-dump." \
    "Reviewers must not use #286 as built-in collision evidence." \
    "#286 should not be used as proof for built-in collision claims." \
    "Built-in collision evidence may not rely on #286." \
    "Built-in collision evidence would not come from the #286 layer-dump." \
    "Use #286 to verify names before reviewing built-in collision evidence." \
    "Use #286 to explain why separate built-in collision evidence is required." \
    "Use #286 when reviewing built-in collision claims, but only as name evidence." \
    "Use #286 only for names when evaluating built-in collision evidence separately." \
    "Do not use #286 to validate built-in collision behavior." \
    "#286 does not corroborate built-in collision behavior." \
    "Built-in collision behavior is not proven by the #286 layer-dump." \
    "#286 doesn't prove built-in collision behavior." \
    "#286 isn't built-in collision evidence." \
    "#286 fails to prove built-in collision behavior." \
    "#286 is insufficient evidence for built-in collision behavior." \
    "#286 cannot reliably prove built-in collision behavior." \
    "Use no built-in collision evidence from #286." \
    "Maintainers should use #286 for names, never for built-in collision claims." \
    "The #286 layer-dump cannot validate built-in collision behavior." \
    "The #286 layer-dump provides no proof for built-in collision behavior."; do
    assert_nonpositive_collision_assignment "$statement"
done
assert_nonpositive_collision_assignment $'> #286 is name evidence only\n>\n> Built-in collision evidence requires a separate reproduction.'
assert_nonpositive_collision_assignment $'- #286 is name evidence only\n- Built-in collision evidence requires a separate reproduction.'

require_evidence_order() {
    local path="$1"
    local label="$2"
    local start_heading="$3"
    local end_heading="$4"
    local expected_order="$5"
    local start_count end_count start_line end_line section normalized rank_count

    start_count="$(count_exact_line_in_file "$path" "$start_heading")"
    end_count="$(count_exact_line_in_file "$path" "$end_heading")"
    if [[ "$start_count" -ne 1 || "$end_count" -ne 1 ]]; then
        echo "ERROR: $label Evidence Gate headings must be unique" >&2
        exit 1
    fi

    start_line="$(awk -v needle="$start_heading" '$0 == needle { print NR; exit }' "$path")"
    end_line="$(awk -v needle="$end_heading" '$0 == needle { print NR; exit }' "$path")"
    if [[ "$start_line" -ge "$end_line" ]]; then
        echo "ERROR: $label Evidence Gate boundaries are out of order" >&2
        exit 1
    fi

    section="$(extract_section "$path" "$start_heading" "$end_heading")"
    normalized="$(printf '%s\n' "$section" | tr '\n' ' ' | tr -s ' ')"
    if [[ "$normalized" != *"$expected_order"* ]]; then
        echo "ERROR: $label Evidence Gate must rank runtime observation > shipped SDK/source > official docs" >&2
        exit 1
    fi

    rank_count="$(printf '%s\n' "$normalized" | awk '
        {
            text = tolower($0)
            needle = "rank evidence"
            while ((position = index(text, needle)) > 0) {
                count++
                text = substr(text, position + length(needle))
            }
        }
        END { print count + 0 }
    ')"
    if [[ "$rank_count" -ne 1 ]]; then
        echo "ERROR: $label Evidence Gate must contain exactly one evidence-ranking instruction" >&2
        exit 1
    fi

    if contains_official_first_order "$section"; then
        echo "ERROR: $label Evidence Gate contains an official-docs-first instruction" >&2
        exit 1
    fi

    if contains_positive_name_dump_collision_assignment "$section"; then
        echo "ERROR: $label Evidence Gate treats the #286 name dump as built-in collision evidence" >&2
        exit 1
    fi
}

MATRIX_HEADING="### VRChat Default Collision Matrix"
MATRIX_END_HEADING="### Custom Layer Collision Settings"
if [[ "$(count_exact_line_in_file "$LAYERS_REF" "$MATRIX_HEADING")" -ne 1 ]]; then
    echo "ERROR: collision matrix heading must appear exactly once" >&2
    exit 1
fi
if [[ "$(count_exact_line_in_file "$LAYERS_REF" "$MATRIX_END_HEADING")" -ne 1 ]]; then
    echo "ERROR: collision matrix end heading must appear exactly once" >&2
    exit 1
fi
MATRIX_HEADING_LINE="$(awk -v needle="$MATRIX_HEADING" '$0 == needle { print NR; exit }' "$LAYERS_REF")"
MATRIX_END_HEADING_LINE="$(awk -v needle="$MATRIX_END_HEADING" '$0 == needle { print NR; exit }' "$LAYERS_REF")"
if [[ "$MATRIX_HEADING_LINE" -ge "$MATRIX_END_HEADING_LINE" ]]; then
    echo "ERROR: collision matrix section boundaries are out of order" >&2
    exit 1
fi
MATRIX_SECTION="$(extract_section "$LAYERS_REF" "$MATRIX_HEADING" "$MATRIX_END_HEADING")"

COLLIDE_HEADING="✅ Collide:"
DO_NOT_COLLIDE_HEADING="❌ Do NOT collide:"
if [[ "$(count_exact_line "$MATRIX_SECTION" "$COLLIDE_HEADING")" -ne 1 ]]; then
    echo "ERROR: collision matrix must contain exactly one '$COLLIDE_HEADING' heading" >&2
    exit 1
fi
if [[ "$(count_exact_line "$MATRIX_SECTION" "$DO_NOT_COLLIDE_HEADING")" -ne 1 ]]; then
    echo "ERROR: collision matrix must contain exactly one '$DO_NOT_COLLIDE_HEADING' heading" >&2
    exit 1
fi

COLLIDE_HEADING_LINE="$(first_exact_line "$MATRIX_SECTION" "$COLLIDE_HEADING")"
DO_NOT_COLLIDE_HEADING_LINE="$(first_exact_line "$MATRIX_SECTION" "$DO_NOT_COLLIDE_HEADING")"
if [[ "$COLLIDE_HEADING_LINE" -ge "$DO_NOT_COLLIDE_HEADING_LINE" ]]; then
    echo "ERROR: collision matrix headings are in the wrong order" >&2
    exit 1
fi

COLLIDE_SECTION="$(printf '%s\n' "$MATRIX_SECTION" | awk -v start="$COLLIDE_HEADING" -v end="$DO_NOT_COLLIDE_HEADING" '
    $0 == start { in_section = 1; next }
    $0 == end { in_section = 0 }
    in_section { print }
')"
DO_NOT_COLLIDE_SECTION="$(printf '%s\n' "$MATRIX_SECTION" | awk -v start="$DO_NOT_COLLIDE_HEADING" '
    $0 == start { in_section = 1; next }
    in_section { print }
')"

COLLIDE_PAIRS=(
    "- Player ↔ Environment"
    "- Player ↔ Pickup"
    "- PlayerLocal ↔ Environment"
    "- Pickup ↔ Environment"
)
DO_NOT_COLLIDE_PAIRS=(
    "- Player ↔ Player (VRChat controlled)"
    "- Player ↔ PlayerLocal"
    "- PickupNoEnvironment ↔ Environment"
    "- Walkthrough ↔ Player"
)

for pair in "${COLLIDE_PAIRS[@]}"; do
    if [[ "$(count_exact_line "$COLLIDE_SECTION" "$pair")" -ne 1 ]]; then
        echo "ERROR: expected collision pair is missing or duplicated under '$COLLIDE_HEADING': $pair" >&2
        exit 1
    fi
    if [[ "$(count_exact_line "$DO_NOT_COLLIDE_SECTION" "$pair")" -ne 0 ]]; then
        echo "ERROR: collision pair appears under '$DO_NOT_COLLIDE_HEADING': $pair" >&2
        exit 1
    fi
done

for pair in "${DO_NOT_COLLIDE_PAIRS[@]}"; do
    if [[ "$(count_exact_line "$DO_NOT_COLLIDE_SECTION" "$pair")" -ne 1 ]]; then
        echo "ERROR: expected non-collision pair is missing or duplicated under '$DO_NOT_COLLIDE_HEADING': $pair" >&2
        exit 1
    fi
    if [[ "$(count_exact_line "$COLLIDE_SECTION" "$pair")" -ne 0 ]]; then
        echo "ERROR: non-collision pair appears under '$COLLIDE_HEADING': $pair" >&2
        exit 1
    fi
done

# Keep each runtime-contract fact independently testable. A single summary
# sentence must not be enough to make this smoke test pass.
require_text "$LAYERS_REF" "The **collision matrix** you configure for layers 22-31 IS preserved"
require_text "$LAYERS_REF" "Layer **names are NOT preserved**"
require_text "$LAYERS_REF" "at runtime the VRChat client overrides them"
require_text "$LAYERS_REF" 'layer 22 = `user0`'
require_text "$LAYERS_REF" 'layer 31 = `user9`'
require_text "$LAYERS_REF" "contradicts the official documentation"
require_text "$LAYERS_REF" "Runtime observation"

# The workaround must describe the script-facing contract, not only the
# observed names.
require_text "$LAYERS_REF" "reference user layers by number or bitmask"
require_text "$LAYERS_REF" "layers 22-31, always use numeric constants"
require_text "$LAYERS_REF" "private const int LAYER_PROJECTILES"
require_text "$LAYERS_REF" "1 << LAYER_PROJECTILES"
require_text "$LAYERS_REF" "LayerMask.NameToLayer(\"YourCustomName\")"

# Preserve the evidence trail and the scope of the observation.
require_text "$LAYERS_REF" "Issue #286"
require_text "$LAYERS_REF" "layer-dump script"
require_text "$LAYERS_REF" "creator-docs#303"
require_text "$LAYERS_REF" "official docs or client behavior change"
require_text "$LAYERS_REF" "### VRChat Default Collision Matrix"

# Preserve the intentionally retained VRChat-specific built-in behavior rather
# than allowing an official-docs-only replacement to erase the current table
# or default matrix.
for behavior in \
    "| Environment (11) | Reliably collides with players; pickups also collide with it. |" \
    "| Pickup (13) | Objects with VRC_Pickup; collides with players and environment; collision with other Pickups depends on settings. |" \
    "| PickupNoEnvironment (14) | Collides with players but does NOT collide with environment; use for objects that can be handed through walls. |" \
    "| Walkthrough (17) | Players can walk through; trigger events can still fire. |" \
    "| MirrorReflection (18) | Displayed only in mirrors; not visible to regular cameras. |" \
    "- Player ↔ Environment" \
    "- Player ↔ Pickup" \
    "- PlayerLocal ↔ Environment" \
    "- Pickup ↔ Environment" \
    "- Player ↔ Player (VRChat controlled)" \
    "- Player ↔ PlayerLocal" \
    "- PickupNoEnvironment ↔ Environment" \
    "- Walkthrough ↔ Player"; do
    require_text "$LAYERS_REF" "$behavior"
done

# The maintenance gate must be visible both to reviewers and to the
# renovator workflow. Check each required evidence source separately.
for path in "$CONTRIBUTING" "$RENOVATOR_CHECKLIST"; do
    require_text "$path" "git blame"
    require_text "$path" "git log"
    require_text "$path" "related Issue/PR"
    require_text "$path" "upstream report"
    require_text "$path" "reproduction evidence"
    require_text "$path" "runtime observation"
    require_text "$path" "shipped SDK/source"
    require_text "$path" "official docs"
    require_text "$path" "Do not generalize beyond the verified observation"
    require_text "$path" "official difference"
    require_text "$path" "#286"
    require_text "$path" "#287"
    require_text "$path" "creator-docs#303"
    require_text "$path" "built-in layer collision"
    require_text "$path" "#288"
    require_text "$path" "#294"
    require_text "$path" "user-layer names"
    require_text "$path" "built-in collision behavior"
    require_text "$path" "collision retention"
    require_normalized_text "$path" "layer-dump directly observes names only"
    require_text "$path" "LayerMask.LayerToName(0..31)"
    require_text "$path" "separate collision reproduction"
    require_text "$path" "independent runtime/SDK evidence"
    if grep -Fq "Re-run the layer-dump" "$path"; then
        echo "ERROR: $path treats the name dump as collision evidence" >&2
        exit 1
    fi
done

require_evidence_order \
    "$CONTRIBUTING" \
    "CONTRIBUTING.md" \
    "### Evidence gate for conflicting runtime observations" \
    "## What to Report" \
    "Rank evidence in this order: a reproducible runtime observation from the same target version, shipped SDK/source, then official docs."
require_evidence_order \
    "$RENOVATOR_CHECKLIST" \
    "update-checklist.md" \
    "## Evidence Gate Before Revising Existing Claims" \
    "## Phase 2: Information Gathering" \
    "Rank evidence as reproducible runtime observation, shipped SDK/source, then official docs."

# #286 is evidence for user-layer behavior only; it must not be attached to
# the built-in collision section.
USER_LAYERS_SECTION="$(sed -n '/^## User Layers (22-31)$/,/^## Layer Behavior Notes$/p' "$LAYERS_REF")"
BUILTIN_COLLISION_SECTION="$(sed -n '/^## Collision Matrix$/,$p' "$LAYERS_REF" | sed -n '/^### VRChat Default Collision Matrix$/,/^### Custom Layer Collision Settings$/p')"
if ! grep -Fq "#286" <<<"$USER_LAYERS_SECTION"; then
    echo "ERROR: #286 evidence is not scoped to the user-layer section" >&2
    exit 1
fi
if grep -Fq "#286" <<<"$BUILTIN_COLLISION_SECTION"; then
    echo "ERROR: #286 evidence was applied to built-in collision claims" >&2
    exit 1
fi

require_file "$CI"
if [[ "$(count_active_ci_contract_run "$(cat "$CI")")" -ne 1 ]]; then
    echo "ERROR: docs job must run the layers reference contract exactly once" >&2
    exit 1
fi

echo "PASS: layers runtime exception and evidence-boundary contract"
