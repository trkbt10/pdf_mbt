# SDD Draft: CFF charset-based glyph ID resolution

## Problem

PDF Type1C (FontFile3 /Subtype /Type1C) fonts parsed through the
CFF-to-OTF wrapper currently use a synthetic identity cmap that maps
codepoints directly to glyph IDs (codepoint N → glyph_id N). This
mapping is incorrect because:

1. Subsetted CFF fonts contain only a small number of glyphs (e.g. 73
   for FrutigerLTStd-Roman), reordered by CFF charset order.
2. The PDF `/Encoding` dictionary defines character code → glyph name
   (e.g. WinAnsiEncoding maps code 65 → "A", 66 → "B", etc.).
3. The CFF `charset` table defines glyph_id → SID (String ID), and
   the CFF `String INDEX` resolves SID → glyph_name.
4. Correct mapping requires: character code → (PDF Encoding) →
   glyph_name → (CFF String INDEX reverse lookup) → SID →
   (CFF charset reverse lookup) → glyph_id.

Without this mapping, 100+ text elements on <local-fixture>
page 6 fall back to SVG `<text>` or render with wrong glyphs.

Adobe Technical Note 5176 "The Compact Font Format Specification"
§13 defines charset formats 0, 1, 2. §10 defines the String INDEX
and predefined SIDs 0-390 (Adobe Standard Strings).

## Requirements

### Requirement 1: CFF charset parsing

#### 1.1: charset offset from TopDICT operator 15
The CFF wrapper SHALL read TopDICT operator 15 to determine the
charset offset. Offsets 0, 1, 2 correspond to predefined charsets
ISOAdobeCharset, ExpertCharset, ExpertSubsetCharset respectively.

#### 1.2: charset format 0 parsing
The CFF wrapper SHALL parse charset format 0 as a sequence of uint16
SIDs, one per glyph from glyph_id 1 to num_glyphs-1 (glyph_id 0 is
always .notdef).

#### 1.3: charset format 1 parsing
The CFF wrapper SHALL parse charset format 1 as a sequence of
(first_sid: uint16, num_left: uint8) range records, where each range
covers num_left+1 consecutive glyph IDs with consecutive SIDs starting
at first_sid.

#### 1.4: charset format 2 parsing
The CFF wrapper SHALL parse charset format 2 as a sequence of
(first_sid: uint16, num_left: uint16) range records, identical to
format 1 but with uint16 num_left.

### Requirement 2: CFF String INDEX and glyph name resolution

#### 2.1: Predefined Adobe Standard Strings
The CFF wrapper SHALL resolve SID values 0-390 to glyph names using
the Adobe Standard Strings table defined in Adobe Technical Note 5176
Appendix A.

#### 2.2: Custom String INDEX
The CFF wrapper SHALL resolve SID values >= 391 by looking up entry
(SID - 391) in the CFF String INDEX. The String INDEX is the third
INDEX structure after the CFF header (following Name INDEX and Top
DICT INDEX).

#### 2.3: glyph_id to glyph_name lookup
The CFF wrapper SHALL provide a function that returns the glyph_name
for a given glyph_id by combining charset (glyph_id → SID) and string
resolution (SID → glyph_name).

### Requirement 3: Synthetic cmap reflecting charset

#### 3.1: WinAnsiEncoding-based cmap population
The CFF wrapper SHALL populate the synthetic cmap table by, for each
codepoint in WinAnsiEncoding (0-255), mapping to the glyph_id whose
charset-resolved glyph name matches the WinAnsi glyph name for that
codepoint.

#### 3.2: Fallback for unmatched codepoints
Codepoints whose WinAnsi glyph name is not present in the CFF charset
SHALL NOT be added to the cmap (no cmap entry), so that
`TTFont::cmap.get(code)` returns None for them.

#### 3.3: Identity fallback when charset parsing fails
If CFF charset parsing fails for any reason, the CFF wrapper SHALL
fall back to the existing identity cmap (codepoint == glyph_id up to
num_glyphs-1) so that regression is bounded.

### Requirement 4: SVG renderer glyph ID resolution

#### 4.1: GlyphName identifier uses post or cmap
The SVG renderer's `svg_resolve_glyph_id` SHALL resolve
`GlyphIdentifier::GlyphName(name)` by consulting the TTFont's post
table glyph names (reverse lookup from glyph_name to glyph_id) when
available, falling back to cmap lookup by source_code when post is
absent.

#### 4.2: Empty outline means missing glyph
A resolved glyph_id whose `ttf.glyph_outline(glyph_id)` returns zero
path commands SHALL be treated as a missing glyph and fall back to
SVG `<text>` rendering, preserving visual continuity for unknown
characters.

### Requirement 5: Acceptance criteria

#### 5.1: local-fixture page 6 visual diff
After implementation, <local-fixture> page 6 pixelmatch diff
against pdftoppm at 72 DPI SHALL be less than 10.0%. Current baseline
is approximately 14.0%; the CFF charset fix is expected to reduce
diff by eliminating `<text>` fallbacks for FrutigerLTStd subsets.

#### 5.2: No regression on existing CFF tests
All existing SVG tests SHALL continue to pass, including the
FontFile3 OpenType and Type1C wrapper tests in `render_wbtest.mbt`.
