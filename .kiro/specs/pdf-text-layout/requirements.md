# SDD Draft: Text Layout Reconstruction

Reference: ISO 32000-2 §9.4 (text positioning operators)

## Requirements

### Requirement 2: Layout mode text extraction
`PdfPage::extract_text_layout() -> String` SHALL return text with spatial
layout preserved: words separated by spaces, lines separated by newlines,
paragraphs separated by blank lines.

### Requirement 3: LayoutWord separator preservation
When text spans form column-like gaps, `layout_text_spans`,
`estimate_layout`, and `layout_to_text` SHALL preserve separators through
`LayoutWord.separator_before` rather than exposing a separate table detector.
