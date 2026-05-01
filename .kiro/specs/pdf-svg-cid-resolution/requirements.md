# Requirements: CID-keyed font glyph index resolution for SVG renderer

## Background and observed defect

The MoonBit PDF→SVG renderer at `src/svg/render.mbt` produces wrong
glyph drawings on the F6 italic-bold subset font of
`<local-fixture>` page 2.

User-visible symptom: the phrase "the reader's understanding but"
renders as garbled, mirrored text ("treadbsundestandright"-style
collapse). The same defect affects every other F6 bullet-list label on
the same page. Body prose in F1 (Times Roman) renders correctly.

## RED evidence collected

1. F6 font dictionary:
   - `Subtype = Type0` (composite font)
   - `BaseFont = ABCDEE+Perpetua` (subset)
   - `Encoding = Identity-H`
   - `DescendantFonts = Ref(34 0)`
   - `ToUnicode = Stream`
2. `pageTextPositions(1)` reports the F6 line correctly: 31 spans on
   row y=323.86 spelling out "the reader's understanding but " with
   each span being a single character at the expected x position.
3. The text interpreter emits `GlyphShown` events with
   `GlyphIdentifier::CID(cid)` values like `CID(87)`, `CID(75)`,
   `CID(72)`, … and `source_code` matching the CID.
4. `svg_resolve_glyph_id` in `src/svg/render.mbt` resolves
   `GlyphIdentifier::CID(cid)` by consulting `svg_cid_glyph_id`,
   which performs a linear search over `ttf.post.glyph_names` for the
   synthetic name `"cid" + cid_pad5(cid)` (e.g. `cid00087`).
5. For F6 the lookup returns `-1`; the renderer then falls back to
   `cid` itself as the glyph id. That `cid` is out of range or points
   to an unrelated glyph in the subset's TrueType-style space, so the
   resulting SVG either drops the glyph or paints a wrong outline.
6. Native and wasm SVG outputs match for F6 — the divergence between
   "input characters" and "drawn glyphs" is target-independent.

## What is correct (PDF spec, ISO 32000-2)

For Type 0 fonts using `Identity-H` with a CIDFontType0 descendant
(CFF-based), section 9.7.5.4 defines the resolution chain as:
  - char code (16-bit, big-endian) → CID via the CMap
  - CID → glyph_index via the embedded CFF font program's charset
    table (operator 15 in the CFF Top DICT)

The current implementation already wraps raw CFF in OTF
(`src/svg/cff_wrapper.mbt:wrap_cff_in_otf`) and synthesises a `post`
table whose entries are the names `"cid" + cid_pad5(cid)` — the
intent is to use that post table as a reverse map for CID → gid
lookup. For F6 this synthetic post table is either missing or
incomplete; therefore the resolver returns `-1`.

For CIDFontType2 (TrueType) descendants, ISO 32000-2 section 9.7.5.3
specifies CID → glyph_index via the descendant font's `CIDToGIDMap`
(an Identity stream or an explicit byte stream). The current
implementation has no path that reads `CIDToGIDMap`.

## Requirement 1: CID glyph index resolution

### 1.1: CFF charset path SHALL produce glyph_index for CID
For a Type 0 font whose descendant is a CIDFontType0 / CIDFontType0C,
the SVG renderer SHALL resolve `CID(c) → glyph_index` by parsing the
embedded CFF font program's charset table (Adobe TN 5176 formats 0,
1, and 2) and mapping `c` to the glyph_index whose charset entry
equals `c`.

### 1.2: CIDToGIDMap path SHALL produce glyph_index for CID
For a Type 0 font whose descendant is a CIDFontType2, the SVG
renderer SHALL resolve `CID(c) → glyph_index` from the descendant
font dictionary's `CIDToGIDMap` entry, treating
`/CIDToGIDMap /Identity` as `glyph_index = c` and a stream as a
big-endian uint16 array indexed by `c`.

### 1.3: Fallback ordering
The combined `svg_resolve_glyph_id` SHALL try, in order, for a
CID-keyed glyph identifier:
  1. CFF charset reverse lookup (1.1) when the embedded font carries
     a CFF program.
  2. CIDToGIDMap lookup (1.2) when the descendant font is
     CIDFontType2.
  3. Existing post-table reverse lookup (current code).
  4. Direct identity (`gid = cid`) only as the last resort, and only
     when the resulting `gid` is within `[0, ttf.num_glyphs)`.

### 1.4: Missing-glyph behaviour
When all lookup paths fail to produce a valid glyph_index, the
renderer SHALL NOT emit an `<image>`-style placeholder or paint a
wrong outline. Instead, it SHALL fall through to the `<text>`
fallback path (already present in `page_render_texts_svg`) so the
character is rendered through CSS font-family lookup, preserving
information.

## Requirement 2: SVG output for OpenXML p2 F6 line

### 2.1: All 31 F6 glyphs SHALL emit a `<path>`
For <local-fixture> page 2, the SVG output of
`pageToSvgDeferred(1)` SHALL contain at least 31 `<path>` elements
whose `transform="matrix(... ... ... ... tx ty)"` has
`ty = 792 - 323.86 ≈ 468.14` and `72.0 ≤ tx ≤ 135.0`.

### 2.2: F6 glyph outlines SHALL match the spelled phrase
When each F6 path on row ty=468.14 is rendered in isolation at large
scale, the depicted shape SHALL match the corresponding character
from the phrase "the reader's understanding but " in the order
determined by ascending `tx`. Verification: a node screenshot
harness already exists in
`npm/demo/test/browser/chrome-harness.mjs` and a per-glyph SVG can
be generated by extracting one `<path>` at a time.

## Requirement 3: Regression safety

### 3.1: Existing svg tests pass
`moon test --target native -p trkbt10/pdf/src/svg` SHALL pass.

### 3.2: Existing text tests pass
`moon test --target native -p trkbt10/pdf/src/text` SHALL pass.

### 3.3: Standard 14 / pure TrueType fonts unaffected
Documents using simple Type 1 fonts and Standard 14 fonts SHALL
render identically to before the fix. Verify by a diff of a
representative SVG (e.g. `spec/pdf/<local-fixture>` page 1 SVG
output) before and after the fix.

## Requirement 4: Design constraints

### 4.1: Single source of truth for CID resolution
The CFF charset parser already exists at
`src/svg/cff_charset.mbt:parse_cff_cid_charset`. Reuse it; do not
re-implement.

### 4.2: Avoid leaking CFF bytes through TTFont
The `@font.TTFont` value stored in
`page_svg_embedded_fonts(...)` does not carry the raw CFF data.
Therefore the CID → glyph_index resolution either:
  (a) happens at TTFont construction time
      (`parse_svg_font_file3_stream`) by stashing the CID-to-glyph
      map alongside the TTFont, OR
  (b) reads it from the font dictionary at lookup time.
The fix SHALL pick exactly one approach and document why.

### 4.3: No silent target divergence
The fix SHALL behave identically on `--target native` and
`--target wasm-gc`, validated by re-running the comparison test
that produced the current 13-path delta.

## Out of scope

- Rendering correctness of Type 3 procedure glyph fonts.
- Vertical writing mode (Identity-V).
- Variable fonts and OpenType `gvar`.
- Font fallback when the embedded font program is corrupted beyond
  parser recovery.
