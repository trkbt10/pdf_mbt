# SDD Draft: SVG Glyph Path Rendering

## Problem

The current SVG renderer uses `<text>` elements with font-family names.
This relies on the SVG viewer having a font with identical glyph shapes
to the PDF's font. Since the PDF defines exact glyph outlines (via
embedded TrueType/CFF fonts) or exact metrics (via Standard 14 font
definitions), the SVG output must reproduce these shapes precisely.

Using `<text>` with a CSS font-family causes differences because:
1. The viewer may substitute a different font (Arial for Helvetica)
2. Even the same-named font may render differently across platforms
3. Font hinting produces platform-specific pixel-level variations

## Solution

When the PDF font has an embedded TrueType font program (FontFile2),
render each glyph as an SVG `<path>` using the font's glyph outlines
from the `glyf` table, accessed via `mizchi/font` TTFont API.

## Requirements

### Requirement 1: Glyph outline extraction

#### 1.1: TrueType glyph outline to SVG path
When a PDF font has an embedded TrueType font program (FontFile2 in
the FontDescriptor), the SVG renderer SHALL extract glyph outlines
using `TTFont::glyph_outline(gid)` and convert them to SVG path data
using `@font.path_commands_to_svg_d()`.

#### 1.2: Character code to glyph ID mapping
The glyph ID SHALL be resolved using the TrueType cmap table via
`TTFont::cmap.get(charcode)`, consistent with the existing text
extraction pipeline in `font_runtime.mbt`.

#### 1.3: CFF font outlines
When a PDF font has an embedded CFF font program (FontFile3), the
SVG renderer SHALL extract glyph outlines using
`TTFont::glyph_outline(gid)` if `mizchi/font` supports CFF parsing.

### Requirement 2: Glyph positioning and scaling

#### 2.1: Glyph coordinate transformation
Each glyph path SHALL be positioned using a transform derived from
the text rendering matrix (ISO 32000-2 §9.4.2):

    T_rm = T_state × T_m × CTM

The glyph outline coordinates (in font units, 1000 or units_per_em
scale) SHALL be scaled to PDF user space by dividing by units_per_em
and multiplying by font_size.

#### 2.2: Y-axis inversion
TrueType glyph coordinates use Y-up, matching PDF conventions.
The SVG Y-flip (PDF bottom-up → SVG top-down) SHALL be applied
via the glyph's transform matrix, not by modifying the outline data.

#### 2.3: Glyph advance
After rendering each glyph path, the text position SHALL advance
by the glyph's horizontal advance width (from hmtx table), matching
the existing `advance_after_glyph` logic in the text interpreter.

### Requirement 3: Fallback for non-embedded fonts

#### 3.1: Standard 14 font fallback
When the PDF font does not have an embedded font program (Standard 14
fonts like Helvetica, Times-Roman, Courier), the SVG renderer SHALL
fall back to `<text>` elements with the appropriate CSS font-family,
as glyph outlines are not available.

#### 3.2: Font availability detection
The SVG renderer SHALL check for the presence of a TTFont in the
RuntimeFont (via the `ttf` field) to decide between path rendering
and text fallback.

### Requirement 4: Fill and stroke

#### 4.1: Text rendering mode
The glyph path fill/stroke SHALL respect the PDF text rendering mode
(ISO 32000-2 §9.3.6):
- Mode 0 (Fill): fill with nonstroking colour
- Mode 1 (Stroke): stroke with stroking colour
- Mode 2 (Fill + Stroke): both
- Mode 3 (Invisible): neither (still affects text position)

For initial implementation, Mode 0 (fill) is sufficient as it covers
the vast majority of PDF text.

#### 4.2: Text colour
The glyph path fill colour SHALL use the current nonstroking colour
from the graphics state, matching the existing SVG text colour logic.

### Requirement 5: SVG output format

#### 5.1: Path element per glyph
Each visible glyph SHALL be rendered as a separate `<path>` element
with a transform attribute encoding its position and scale.

#### 5.2: Grouping
Glyphs from the same text span MAY be grouped in a `<g>` element
for shared attributes (fill colour, transform prefix).

### Requirement 6: TextGlyphEvent integration

#### 6.1: Glyph data availability
The TextGlyphEvent (from the text interpreter) SHALL carry sufficient
information to resolve the glyph ID for outline lookup. The
`source_code` field on DecodedGlyph provides the character code for
cmap lookup.

#### 6.2: Font reference availability
The SVG renderer SHALL have access to the TTFont object for the
current text span's font, obtained from the font resources via the
same path as `font_runtime.mbt`.
