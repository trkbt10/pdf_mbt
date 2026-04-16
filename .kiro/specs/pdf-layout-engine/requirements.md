# SDD Draft: Layout Estimation Engine

PDF has no concept of words, lines, or paragraphs — only positioned glyphs.
Text reconstruction from glyph positions is inherently estimation.
This package provides a layout estimation engine that is separate from
the core text interpreter, consuming its output to produce grouped text.

## Requirements

### Requirement 1: Package separation
The layout estimation engine SHALL be a separate package (`src/layout/`)
that depends on `src/text/` types but does NOT modify the core text
interpreter. The existing `src/text/layout.mbt` SHALL be migrated here.

### Requirement 2: Kerning collapse (intra-word glyph grouping)
The engine SHALL merge adjacent glyphs into words by collapsing small
TJ positioning adjustments (kerning).

#### 2.1: Kerning threshold
Horizontal displacement between consecutive glyphs SHALL be classified
as kerning (not a word break) when the gap is smaller than a fraction
of the current font size. The default threshold SHALL be 0.25 em
(one quarter of the font size). The threshold SHALL be configurable.

#### 2.2: TJ adjustment handling
TJ operator arrays contain alternating strings and numeric adjustments.
Negative adjustments move the text position forward (kerning tightening).
The engine SHALL treat adjustments whose absolute value is below
(threshold * 1000) as intra-word kerning, concatenating the adjacent
character codes into a single word without inserting spaces.

### Requirement 3: Word detection (inter-word spacing)
The engine SHALL detect word boundaries by identifying horizontal gaps
between glyph groups that exceed the kerning threshold.

#### 3.1: Space insertion
When the horizontal gap between the end of one glyph group and the start
of the next exceeds the word spacing threshold, a space character SHALL
be inserted in the output.

#### 3.2: Explicit space characters
Character code 32 (space) in the text string SHALL always produce a space,
regardless of positioning adjustments.

### Requirement 4: Line detection
The engine SHALL group words into lines based on vertical position.

#### 4.1: Y-coordinate clustering
Glyph groups whose Y-coordinates are within a configurable tolerance
(default: half the dominant font size on the line) SHALL be assigned to
the same logical line.

#### 4.2: Line ordering
Lines SHALL be sorted in reading order: top-to-bottom (descending Y in
PDF coordinate space), left-to-right within each line.

### Requirement 5: Paragraph detection
The engine SHALL optionally detect paragraph boundaries by identifying
vertical gaps between lines that exceed the normal line spacing.

#### 5.1: Paragraph separator
When the vertical gap between consecutive lines exceeds a configurable
multiple (default: 1.5x) of the dominant line spacing, a blank line
SHALL be inserted in the output.

### Requirement 6: Configuration
The engine SHALL accept a configuration struct controlling thresholds:

- `kerning_threshold_em : Double` — kerning collapse threshold (default 0.25)
- `line_tolerance_factor : Double` — Y-clustering tolerance (default 0.5)
- `paragraph_gap_factor : Double` — paragraph break multiplier (default 1.5)

### Requirement 7: Integration API
The engine SHALL provide:

- `estimate_layout(spans : Array[TextSpan], config?) -> LayoutResult`
  where LayoutResult contains lines of words with positional metadata
- `layout_to_text(result : LayoutResult) -> String`
  that formats the layout as plain text with spaces, newlines, and
  paragraph breaks
