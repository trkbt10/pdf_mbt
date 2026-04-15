# SDD Draft: Text Layout Reconstruction

Reference: ISO 32000-2 §9.4 (text positioning operators)

## Requirements

### Requirement 1: Spatial text grouping
The text extraction pipeline SHALL optionally reconstruct spatial layout
by grouping text spans into lines based on their Y-coordinate position.

#### 1.1: Line detection
Spans with Y-coordinates within a threshold (e.g., half the font size)
SHALL be grouped into the same logical line.

#### 1.2: Word spacing detection
Within a line, spans separated by horizontal gaps larger than a threshold
(e.g., 1/4 of the average character width) SHALL be separated by space
characters in the output.

#### 1.3: Line ordering
Lines SHALL be sorted top-to-bottom (descending Y in PDF coordinate system)
to produce reading order output.

### Requirement 2: Layout mode text extraction
`PdfPage::extract_text_layout() -> String` SHALL return text with spatial
layout preserved: words separated by spaces, lines separated by newlines,
paragraphs separated by blank lines.

### Requirement 3: Table-like structure detection
When text spans form a grid pattern (aligned columns with consistent
X-coordinates across multiple lines), the extraction SHALL optionally
insert tab characters between columns.
