#!/usr/bin/env python3
"""Lint resource materialization invariants.

The reader package has one allowed bridge from `PdfObject::Ref` to
`PdfFile::load_object`: `src/reader/indirect_resolution.mbt`. Materializers must
call `resolve_indirect` before variant matching so Ref-wrapped arrays,
dictionaries, streams, or font descendants cannot be silently ignored.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
READER = ROOT / "src" / "reader"
HELPER = READER / "indirect_resolution.mbt"


def line_number(text: str, offset: int) -> int:
    return text.count("\n", 0, offset) + 1


def lint_load_document_object(path: Path, text: str) -> list[str]:
    if path == HELPER:
        return []
    errors: list[str] = []
    for match in re.finditer(r"\bload_document_object\s*\(", text):
        errors.append(
            f"{path.relative_to(ROOT)}:{line_number(text, match.start())}: "
            "direct load_document_object call; use resolve_indirect"
        )
    return errors


def function_blocks(text: str) -> list[tuple[str, int, str]]:
    starts = list(re.finditer(r"(?m)^fn\s+([A-Za-z0-9_]+)\s*\(", text))
    blocks: list[tuple[str, int, str]] = []
    for index, start in enumerate(starts):
        end = starts[index + 1].start() if index + 1 < len(starts) else len(text)
        blocks.append((start.group(1), start.start(), text[start.start() : end]))
    return blocks


def lint_ref_wrapped_array_match(path: Path, text: str) -> list[str]:
    errors: list[str] = []
    pattern = re.compile(
        r"match\s+[^{]+{\s*"
        r"(?:@[A-Za-z0-9_/]+\\.)?Some\s*"
        r"\(\s*(?:@[A-Za-z0-9_/]+\\.)?PdfObject::Array",
        re.DOTALL,
    )
    for name, start, body in function_blocks(text):
        if "materialize" not in name:
            continue
        if not pattern.search(body):
            continue
        before_match = body[: pattern.search(body).start()]
        if "resolve_indirect" not in before_match:
            errors.append(
                f"{path.relative_to(ROOT)}:{line_number(text, start)}: "
                f"{name} matches an Array without prior resolve_indirect"
            )
    return errors


def main() -> int:
    errors: list[str] = []
    for path in sorted(READER.glob("*.mbt")):
        text = path.read_text()
        errors.extend(lint_load_document_object(path, text))
        errors.extend(lint_ref_wrapped_array_match(path, text))
    if errors:
        for error in errors:
            print(error, file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
