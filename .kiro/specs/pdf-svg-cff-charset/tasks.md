# Tasks: CFF charset-based glyph ID resolution

## Task 1: Adobe Standard Strings and WinAnsi tables

**File:** `src/svg/cff_charset.mbt` (NEW)

Embed the full Adobe Standard Strings table (391 entries, SID 0-390)
and WinAnsiEncoding table (256 entries) as static arrays.

Public functions:
- `adobe_standard_string(sid: Int) -> String?` — returns the name for
  SID 0-390, or None if sid >= 391
- `winansi_glyph_name(code: Int) -> String` — returns Adobe glyph
  name for WinAnsi codepoint 0-255, or "" for unassigned codes

## Task 2: CFF String INDEX extraction

**File:** `src/svg/cff_charset.mbt`

Add function to locate and read entries from the CFF String INDEX:

- `cff_string_index_entry(data: Bytes, index: Int) -> String?` —
  finds the String INDEX in the CFF data (third INDEX after Name and
  Top DICT), returns string at the given index or None

The String INDEX starts after:
- CFF header (offset 0, size = data[2] bytes)
- Name INDEX
- Top DICT INDEX

Use the existing `cff_skip_index` and `cff_read_uint16` helpers from
`cff_wrapper.mbt` (make them accessible or duplicate).

## Task 3: CFF charset parsing

**File:** `src/svg/cff_charset.mbt`

Add function to parse the CFF charset table:

- `cff_charset_offset(data: Bytes) -> Int` — parses TopDICT operator
  15, returns absolute offset to charset table, or 0/1/2 for
  predefined charsets, or -1 if not found
- `parse_cff_charset(data: Bytes, num_glyphs: Int) -> Array[Int]?` —
  parses charset format 0/1/2, returns array where index is glyph_id
  (0 to num_glyphs-1) and value is SID. glyph_id 0 is always SID 0
  (.notdef). Returns None on format error.

Implementations:
- Format 0: reads num_glyphs-1 uint16 SIDs
- Format 1: reads (first: uint16, num_left: uint8) ranges
- Format 2: reads (first: uint16, num_left: uint16) ranges

## Task 4: glyph_id to glyph_name mapping

**File:** `src/svg/cff_charset.mbt`

Combine charset + String INDEX to return glyph name for a given
glyph_id:

- `cff_glyph_name_table(data: Bytes, num_glyphs: Int) -> Array[String]?`
  — returns array of glyph names indexed by glyph_id. Uses
  `parse_cff_charset` for SIDs, `adobe_standard_string` for SID < 391,
  `cff_string_index_entry` for SID >= 391.

## Task 5: Charset-aware synthetic cmap

**File:** `src/svg/cff_wrapper.mbt`

Replace `build_synthetic_cmap(num_glyphs)` with
`build_synthetic_cmap(cff_data, num_glyphs)`:

1. Call `cff_glyph_name_table(cff_data, num_glyphs)`
2. If successful, build a cmap format 4 subtable with one entry per
   WinAnsi codepoint 0-255 whose glyph name matches a name in the
   CFF glyph name table
3. If charset parsing fails, fall back to the current identity cmap
   (format 12, 0..num_glyphs-1)

cmap format 4 structure (6 + 8*segCount + 2 + 2*segCount + 2*segCount + 2*segCount + glyphIds bytes):
- format=4, length, language=0
- segCountX2, searchRange, entrySelector, rangeShift
- endCode[segCount]
- reservedPad=0
- startCode[segCount]
- idDelta[segCount]
- idRangeOffset[segCount]

For a simple mapping, each segment can be one codepoint wide with
idDelta = glyph_id - codepoint. The last segment SHALL have
endCode=0xFFFF, startCode=0xFFFF, idDelta=1 (sentinel).

## Task 6: Verify with unit tests

**File:** `src/svg/render_wbtest.mbt`

Add tests:

1. `adobe_standard_string` returns ".notdef" for SID 0, "space" for
   SID 1, "A" for SID 34 (standard), "zero" for SID 17.
2. `winansi_glyph_name` returns "A" for code 65, "a" for 97, "space"
   for 32.
3. `parse_cff_charset` on the `cff.add.otf` extracted CFF returns a
   non-None array of 28 entries (the known num_glyphs for this
   fixture).
4. `cff_glyph_name_table` on the same CFF returns readable names.
5. `wrap_cff_in_otf` produces a TTFont whose cmap, for a WinAnsi
   codepoint whose glyph name exists in the CFF, resolves to a
   glyph_id matching the charset (not the identity codepoint).

## Task 7: Verify with integration tests and visual diff

Run `moon test --target native` — all 702+ tests must pass.

Rebuild wasm: `moon build --target wasm-gc --release` and copy to
`npm/dist/pdf.wasm`.

Run <local-fixture> page 6 pixelmatch comparison; expect diff
< 10.0%. Report actual diff and whether acceptance is met.

## Task 8: Spec alignment gate

Before committing, run:

```bash
indexion spec align status .kiro/specs/pdf-svg-cff-charset/requirements.md src/svg/ --threshold 0.3 --fail-on any
```

All requirements SHALL be MATCHED with no DRIFTED, SPEC_ONLY, or
SHALLOW entries. If gaps remain, add doc comments with spec vocabulary
to the implementation or add missing logic.
