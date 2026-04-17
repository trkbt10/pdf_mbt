# Design: CFF charset-based glyph ID resolution

## Overview

Extend the existing CFF-to-OTF wrapper in `src/svg/cff_wrapper.mbt`
to parse the CFF charset and String INDEX tables, producing a
`glyph_id → glyph_name` mapping. Use this mapping together with
WinAnsiEncoding to populate the synthetic cmap with a correct
`character_code → glyph_id` mapping.

## Current code

`wrap_cff_in_otf(cff_data)` builds a synthetic OTF container with:
- `head`, `maxp`, `hhea`, `hmtx`, `cmap`, `CFF ` tables
- cmap uses identity mapping: codepoint N → glyph_id N

`svg_resolve_glyph_id(ttf, glyph)` in `src/svg/render.mbt`:
- `GlyphIdentifier::CID(cid)` → uses cid directly
- `GlyphIdentifier::CharacterCode(code)` → looks up `ttf.cmap.get(code)`
- `GlyphIdentifier::GlyphName(_)` → looks up `ttf.cmap.get(source_code)`

## CFF binary structure (Adobe TN 5176)

```
CFF Header (4 bytes): major(1) minor(1) hdrSize(1) offSize(1)
Name INDEX:           font names
Top DICT INDEX:       per-font top-level dictionaries
String INDEX:         shared strings (SID >= 391 indexes here)
Global Subr INDEX:    global subroutines
... per-font data (charstrings, private dicts, charsets, etc.)
```

Top DICT operator 15 (charset) gives the absolute offset (from CFF
start) to the charset table. Values 0, 1, 2 are predefined charsets.

### Charset format 0 (common for small fonts)

```
format: uint8 = 0
glyph: SID[nGlyphs-1]   # SIDs for glyph_id 1..nGlyphs-1
```

### Charset format 1 (range-based, 1-byte num_left)

```
format: uint8 = 1
Range1[]: { first: SID; num_left: uint8 }
```
Each range covers (num_left+1) consecutive glyph IDs with consecutive
SIDs starting at `first`. Total glyphs covered = nGlyphs-1.

### Charset format 2 (range-based, 2-byte num_left)

```
format: uint8 = 2
Range2[]: { first: SID; num_left: uint16 }
```

## Adobe Standard Strings (SID 0-390)

The first 391 SIDs are predefined (Adobe TN 5176 Appendix A):
- SID 0: ".notdef"
- SID 1: "space"
- SID 2: "exclam"
- ...
- SID 390: "001.003"

For this implementation we embed the subset that matters for Latin
PDFs (matching WinAnsiEncoding glyph names: A, B, ..., Z, a, ..., z,
zero, one, ..., space, period, comma, semicolon, ...).

The full table of 391 names is ~4KB of string data. We embed it as a
static array.

## WinAnsiEncoding (PDF 9.6.5.3)

Maps character codes 0-255 to Adobe glyph names:
- 65 → "A", 66 → "B", ..., 97 → "a", ..., 122 → "z"
- 32 → "space", 46 → "period", ..., 223 → "germandbls"

The full table is ~1KB. We embed it.

## Solution

### New module: src/svg/cff_charset.mbt

Contains:

```moonbit
// Parses CFF charset and returns glyph_id → SID array
// Returns None if charset cannot be parsed.
fn parse_cff_charset(data: Bytes, num_glyphs: Int) -> Array[Int]?

// Looks up glyph name for a given SID, consulting Adobe Standard
// Strings (0-390) first, then the CFF String INDEX.
fn cff_sid_to_name(data: Bytes, sid: Int) -> String

// Returns glyph name for a given glyph_id in the CFF data.
fn cff_glyph_id_to_name(data: Bytes, glyph_id: Int) -> String

// WinAnsi character code to Adobe glyph name.
fn winansi_code_to_glyph_name(code: Int) -> String

// Adobe Standard Strings table (391 entries, SID 0-390).
let adobe_standard_strings: Array[String]

// WinAnsiEncoding table (256 entries).
let winansi_encoding: Array[String]
```

### Modified: src/svg/cff_wrapper.mbt — Synthetic cmap reflecting charset

The **synthetic cmap reflecting charset** replaces the identity cmap
builder. WinAnsiEncoding-based cmap population reverses the CFF
charset's glyph_id→SID table through Adobe Standard Strings, then
consults WinAnsiEncoding to yield character_code→glyph_id entries.
Codepoints whose WinAnsi glyph name is absent from the CFF charset
receive no cmap entry (fallback for unmatched codepoints). Identity
fallback when charset parsing fails preserves current behaviour.

`build_synthetic_cmap` becomes aware of charset. New signature:

```moonbit
fn build_synthetic_cmap_from_charset(
  cff_data: Bytes,
  num_glyphs: Int,
) -> Bytes
```

This function:
1. Parses CFF charset via `parse_cff_charset`.
2. For each WinAnsi codepoint 0-255, finds the glyph_id whose charset
   SID resolves to the same glyph name as WinAnsi code.
3. Emits a cmap format 4 or 12 subtable with `character_code →
   glyph_id` mappings.
4. Falls back to identity cmap if charset parsing fails.

`wrap_cff_in_otf` calls the new function instead of the identity cmap
builder.

### Modified: src/svg/render.mbt

`svg_resolve_glyph_id` for `GlyphName(name)`:

```moonbit
GlyphIdentifier::GlyphName(name) =>
  match ttf.post {
    Some(post) => {
      // Reverse lookup glyph name → glyph_id
      for gid = 0; gid < post.glyph_names.length(); gid = gid + 1 {
        if post.glyph_names[gid] == name.to_text() {
          return gid
        }
      }
      fallback_cmap_lookup(ttf, source_code)
    }
    None => fallback_cmap_lookup(ttf, source_code)
  }
```

Since the CFF wrapper currently does not emit a post table, the post
table path is for future completeness. The primary fix is the cmap.

## cmap format 4 vs 12

cmap format 4 supports BMP (0-65535) with segment-based encoding,
~64 bytes for 256 codepoints. Format 12 supports full range with
group-based encoding, 28 bytes for a single range.

WinAnsi codepoints 0-255 with scattered glyph_ids: format 4 with one
segment per contiguous run is compact. Format 12 needs one group per
run. Either works; format 4 is the canonical choice for BMP-only
mappings (platformID=3, encodingID=1).

We emit format 4 with one segment per (codepoint, glyph_id) pair (or
per contiguous run) because the mapping is typically scattered.

## Files to modify

- `src/svg/cff_charset.mbt` — NEW: charset parsing, SID resolution,
  WinAnsi table, Adobe Standard Strings
- `src/svg/cff_wrapper.mbt` — modify `wrap_cff_in_otf` and
  `build_synthetic_cmap` to use charset-aware mapping
- `src/svg/render.mbt` — `svg_resolve_glyph_id` unchanged in Phase 1
  (cmap fix alone should resolve most cases)
- `src/svg/render_wbtest.mbt` — NEW test: verify CFF wrapper produces
  non-identity cmap for a real CFF with charset

## Risks and fallbacks

- **Risk**: Adobe Standard Strings table is ~4KB of embedded data.
  This adds binary size but is necessary for correctness.
- **Risk**: Non-WinAnsi encodings (MacRoman, StandardEncoding,
  MacExpertEncoding, custom Differences) are not handled in this
  phase. `GlyphIdentifier::GlyphName` is handled by the render-side
  post table lookup, but CFF wrapper only populates WinAnsi in the
  cmap. Differences-based encodings fall back to identity.
- **Fallback**: If charset parsing fails, identity cmap is used (same
  as current behavior) — no regression.

## Acceptance verification

After implementation:
1. Unit test: `wrap_cff_in_otf` with a known Type1C CFF produces a
   TTFont whose cmap resolves WinAnsi codepoints to correct glyph_ids
   whose outlines are non-empty.
2. Visual: <local-fixture> page 6 diff < 10.0%.
3. Regression: all existing SVG tests pass.
