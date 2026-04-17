# Design: CFF-to-OTF Wrapper for FontFile3 Type1C / CIDFontType0C

## Problem

`parse_svg_font_file3_stream` passes raw CFF data to `@font.parse_font()`,
which expects an sfnt container (OTF/TTF). Raw CFF lacks the sfnt header and
required tables (`head`, `maxp`, `hhea`, `hmtx`, `cmap`), so `parse_font`
returns `None`. FrutigerLTStd and similar Type 1C fonts fall back to `<text>`
instead of glyph path rendering.

## Solution

Wrap raw CFF bytes in a minimal OTF container using `@font.rebuild_sfnt()`.
Detect raw CFF by checking the first byte (CFF version major, typically 1).
Construct synthetic required tables with reasonable defaults extracted from the
CFF data itself (glyph count from CharStrings INDEX).

### Detection logic

```
let magic = (bytes[0].to_int() << 24) | (bytes[1].to_int() << 16) |
            (bytes[2].to_int() << 8) | bytes[3].to_int()
if magic == 0x4F54544F || magic == 0x00010000 || magic == 0x74727565 {
  // Already has sfnt header → parse_font directly
} else if bytes[0] == b'\x01' {
  // CFF version 1 header → wrap in OTF
}
```

### Synthetic table construction

From the CFF data we need to extract:
- **num_glyphs**: count of entries in CharStrings INDEX
- **units_per_em**: default to 1000 (standard for CFF/Type 1)

Build 6 tables:

1. **`head`** (54 bytes): units_per_em=1000, indexToLocFormat=0, magic=0x5F0F3CF5
2. **`maxp`** (6 bytes): version=0x00005000 (CFF version), numGlyphs from CharStrings
3. **`hhea`** (36 bytes): ascent=800, descent=-200, numOfLongHorMetrics=numGlyphs
4. **`hmtx`** (4*numGlyphs bytes): advanceWidth=600 (monospace default), lsb=0
5. **`cmap`** (format 0 or minimal): identity mapping (glyph_id = codepoint)
   For PDF use, cmap is not critical because PDF provides its own glyph mapping.
   Use format 12 identity: codepoint → glyph_id for range 0..numGlyphs-1
6. **`CFF `** (4-byte tag, note trailing space): the raw CFF data as-is

Then: `@font.rebuild_sfnt(0x4F54544F, tables)` → Bytes → `@font.parse_font()`

### CFF CharStrings INDEX count extraction

CFF header: major(1) minor(1) hdrSize(1) offSize(1)
Then: Name INDEX, Top DICT INDEX, String INDEX, Global Subr INDEX
Then Top DICT contains operator 17 (CharStrings offset).

Simpler approach: parse just enough CFF to find CharStrings INDEX count.
- Read hdrSize, skip to Name INDEX
- Skip Name INDEX (read count + offsets)
- Read Top DICT INDEX, parse first entry for operator 17
- Seek to CharStrings offset, read count (first 2 bytes = uint16 big-endian)

### PDF FontDescriptor as metadata source

When the PDF FontDescriptor is available, use its fields instead of defaults:
- `/Ascent` → hhea ascent
- `/Descent` → hhea descent
- `/AvgWidth` or `/MissingWidth` → hmtx default advance
- `/StemV`, `/ItalicAngle`, `/Flags` → informational

For this initial implementation, use static defaults. The critical path is
getting `glyph_outline()` to work, which only needs CharStrings + subroutines.

## Files to modify

- `src/svg/render.mbt` — modify `parse_svg_font_file3_stream`
- `src/svg/cff_wrapper.mbt` — NEW: CFF-to-OTF wrapping logic

## Key dependency

- `@font.rebuild_sfnt` (pub fn in mizchi/font)
- `@font.parse_font` (existing)
