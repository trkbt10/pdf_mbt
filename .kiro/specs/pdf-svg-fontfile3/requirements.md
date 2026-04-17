# SDD Draft: FontFile3 Embedded Font Support for SVG Rendering

## Problem

The SVG glyph path renderer only reads `FontFile2` (TrueType) from
font descriptors. PDFs commonly embed fonts as:

- **FontFile3 Subtype=Type1C** (ISO 32000-2 §9.9, Table 124):
  CFF font program for Type 1 fonts. Raw CFF data (not in OTF container).
- **FontFile3 Subtype=CIDFontType0C** (ISO 32000-2 §9.9, Table 124):
  CFF font program for CID Type 0 fonts. Raw CFF data.
- **FontFile3 Subtype=OpenType** (ISO 32000-2 §9.9, Table 124):
  OpenType font program containing either TrueType glyf or CFF data
  in an OTF/TTF container.

The `mizchi/font` library supports:
- `parse_ttf` / `parse_font`: OTF/TTF containers (including those with CFF tables)
- `glyph_outline`: Returns outlines from either glyf or CFF tables
- Does NOT support standalone/raw CFF data (no OTF container)

## Requirements

### Requirement 1: FontFile3 with OpenType subtype

#### 1.1: OpenType embedded fonts
When the font descriptor has `FontFile3` with `Subtype=OpenType`,
the SVG renderer SHALL decode the stream and parse it with
`@font.parse_font()` to obtain a TTFont for glyph path rendering.

### Requirement 2: FontFile3 with Type1C subtype

#### 2.1: Raw CFF font programs
When the font descriptor has `FontFile3` with `Subtype=Type1C`,
the SVG renderer SHALL attempt to parse the decoded stream.
If `@font.parse_font()` can handle it (some CFF data has OTF-like
headers), use the result. Otherwise, fall back to `<text>` rendering.

#### 2.2: Future CFF standalone support
Raw CFF parsing (without OTF container) is a `mizchi/font` library
enhancement. Until available, Type1C fonts SHALL fall back to
`<text>` rendering with correct font metrics from the PDF Widths array.

### Requirement 3: FontFile3 with CIDFontType0C subtype

#### 3.1: CID CFF font programs
Same as Requirement 2 — attempt `parse_font()`, fall back to `<text>`.

### Requirement 4: FontFile (Type 1, non-compact)

#### 4.1: Type 1 font programs
FontFile (no subtype) contains Type 1 font programs in Adobe format.
These are not parseable by `mizchi/font`. SHALL fall back to `<text>`.

### Requirement 5: Font descriptor lookup order

#### 5.1: Lookup priority
The SVG renderer SHALL check font descriptor entries in this order:
1. FontFile2 (TrueType) — parse with `@font.parse_ttf()`
2. FontFile3 (OpenType/Type1C/CIDFontType0C) — parse with `@font.parse_font()`
3. FontFile (Type 1) — skip (not supported)
4. System font resolution — existing fallback
5. `<text>` element — last resort
