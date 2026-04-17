# SDD Draft: CID-keyed CFF font charset handling

## Problem

PDF CIDFontType0C fonts (FontFile3 /Subtype /CIDFontType0C) are raw
CFF fonts that use CID-keyed glyph ordering. The current CFF-to-OTF
wrapper applies the same charset parsing as Type1C fonts, but
CID-keyed CFF fonts have different charset semantics: the charset
maps glyph_id → CID rather than glyph_id → SID (String ID).

Adobe TN 5176 §18 defines CID-keyed CFF fonts. Key differences from
Type1C:

1. The CFF TopDICT has operator 30 (ROS = Registry/Ordering/Supplement)
   indicating the CID system (e.g. Adobe/Japan1/6).
2. The charset table maps glyph_id → CID (uint16), not SID.
3. CIDs are looked up through a CIDSystemInfo + CMap defined in the
   parent PDF Type0 composite font, not through Adobe Standard
   Strings.
4. There is no PDF Encoding for CID fonts — the text content stream
   uses CID values directly through the Type0 font's CMap.

Observable failures in <local-fixture> page 6:

- **Numbered list icons**: the ①②③④ icons (Unicode U+2460..) used
  as step markers appear as blank/white circles instead of filled
  circles with numbers. The icons are CID font glyphs.
- **Japanese text**: ShinGoPro (CID font) Japanese labels like
  `言語設定` are absent from the SVG output.

Both symptoms point to CID glyph resolution not working. The render
code currently treats `GlyphIdentifier::CID(cid)` as a direct glyph
ID (`gid = cid`), which is only correct when the charset is
identity. CID-keyed fonts commonly have non-identity charsets where
cid ≠ glyph_id.

## Requirements

### Requirement 1: CID-keyed CFF detection

#### 1.1: ROS operator detection
The CFF wrapper SHALL detect CID-keyed CFF fonts by reading TopDICT
operator 30 (ROS) or operator 3073 (CIDCount). When present, the
font is CID-keyed; when absent, it is Type1C.

#### 1.2: CID-keyed charset handling
For CID-keyed fonts, `parse_cff_charset` SHALL interpret the charset
entries as CID values (uint16), producing a `glyph_id → CID` map
rather than `glyph_id → SID`.

### Requirement 2: CID → glyph_id reverse mapping

#### 2.1: Reverse lookup for CID fonts
The CFF wrapper SHALL build a reverse map `cid → glyph_id` for
CID-keyed fonts and expose it to the SVG renderer via the
synthetic post table (or an equivalent mechanism).

#### 2.2: Identity preservation for Type1C
For non-CID-keyed (Type1C) fonts, the existing charset behaviour
(SID-based glyph name mapping) SHALL be preserved.

### Requirement 3: Renderer CID resolution

#### 3.1: CID-aware glyph ID lookup
`svg_resolve_glyph_id` SHALL consult the reverse CID map (built by
the CFF wrapper) when resolving `GlyphIdentifier::CID(cid)` against
a CID-keyed CFF font. If the CID is present in the reverse map, the
mapped glyph_id SHALL be used; otherwise the CID value SHALL be
used directly (existing behaviour as fallback).

#### 3.2: No regression for non-CFF CID fonts
TrueType CID fonts (CIDFontType2) SHALL NOT be affected by this
change. They already use Identity-H or CIDToGIDMap to resolve CID
to glyph_id at a different layer of the stack.

### Requirement 4: Acceptance criteria

#### 4.1: local-fixture page 6 CID glyphs render
After implementation, <local-fixture> page 6 SHALL render:
- The numbered list icons (①②③④) with their filled circle and
  digit forms, not blank outlines.
- The Japanese text labels (ShinGoPro) as glyph paths, not omitted.

#### 4.2: Visual diff improvement
local-fixture page 6 pixelmatch diff SHALL decrease from the current 12.6%
baseline, targeting less than 8.0%. Page 7 SHALL not regress from
its current 17.6% diff.

#### 4.3: No regression on existing tests
All existing tests SHALL continue to pass. The CFF charset tests
added in `pdf-svg-cff-charset` SHALL remain green.
