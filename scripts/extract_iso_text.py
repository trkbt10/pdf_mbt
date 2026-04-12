"""Extract text from ISO PDF documents with cleanup for KGF processing.

Produces .spec.txt files suitable for indexion's technical-document KGF spec.
Handles: page noise removal, section number + title line joining.
"""

import re
import sys
from pathlib import Path

try:
    import pymupdf
except ImportError:
    print("pip install pymupdf", file=sys.stderr)
    sys.exit(1)

# Noise patterns from ISO PDF text extraction
NOISE_PATTERNS = [
    re.compile(r"^---\s*Page\s+\d+\s*---\s*$"),
    re.compile(r"^ISO[\s_/-]\d+.*$"),
    re.compile(r"^IEC[\s_/-]\d+.*$"),
    re.compile(r"^©\s*(ISO|IEC)\b.*$"),
    re.compile(r"^.*All rights reserved.*$"),
    re.compile(r"^Sold by the\b.*$"),
    re.compile(r"^Single user only.*$"),
    re.compile(r"^.*copying and networking prohibited.*$"),
    re.compile(r"^Goto errata\s*$"),
    re.compile(r"^\d{1,3}\s*$"),  # Standalone page numbers
]

# Section number pattern: "7.3" or "7.3.4.2" (with optional trailing dot/space)
SECTION_NUMBER_RE = re.compile(r"^(\d{1,2}(?:\.\d+)*\.?)\s*$")

# Title line: starts with uppercase letter
TITLE_START_RE = re.compile(r"^[A-Z]")


def is_noise(line: str) -> bool:
    stripped = line.strip()
    return any(p.match(stripped) for p in NOISE_PATTERNS)


def extract_pages(pdf_path: str, start_page: int, end_page: int) -> str:
    """Extract text from page range, clean noise, join split headings."""
    doc = pymupdf.open(pdf_path)
    raw_lines: list[str] = []

    for page_num in range(start_page - 1, min(end_page, len(doc))):
        page = doc[page_num]
        text = page.get_text("text")
        for line in text.split("\n"):
            if not is_noise(line):
                raw_lines.append(line)

    # Join section number lines with their title on the next line
    result: list[str] = []
    i = 0
    while i < len(raw_lines):
        stripped = raw_lines[i].strip()
        m = SECTION_NUMBER_RE.match(stripped)
        if m and i + 1 < len(raw_lines):
            next_stripped = raw_lines[i + 1].strip()
            if next_stripped and TITLE_START_RE.match(next_stripped):
                result.append(f"{stripped} {raw_lines[i + 1]}")
                i += 2
                continue
        result.append(raw_lines[i])
        i += 1

    return "\n".join(result)


def main():
    if len(sys.argv) < 4:
        print(
            "Usage: python extract_iso_text.py <pdf> <start_page> <end_page> [output]",
            file=sys.stderr,
        )
        sys.exit(1)

    pdf_path = sys.argv[1]
    start_page = int(sys.argv[2])
    end_page = int(sys.argv[3])
    output = sys.argv[4] if len(sys.argv) > 4 else None

    text = extract_pages(pdf_path, start_page, end_page)

    if output:
        Path(output).write_text(text, encoding="utf-8")
        print(f"Wrote {output} ({len(text)} bytes)")
    else:
        print(text)


if __name__ == "__main__":
    main()
