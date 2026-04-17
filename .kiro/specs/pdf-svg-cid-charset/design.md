# Design: CID-keyed CFF font charset handling

## Overview

Extend `src/svg/cff_charset.mbt` and `src/svg/cff_wrapper.mbt` to
recognise CID-keyed CFF fonts (CIDFontType0C) and produce a
`cid → glyph_id` reverse map exposed through the synthetic post
table. Modify `svg_resolve_glyph_id` in `src/svg/render.mbt` to
consult the reverse map when handling `GlyphIdentifier::CID`.

## CFF CID-keyed font structure (Adobe TN 5176 §18)

A CID-keyed CFF font is identified by the presence of TopDICT
operator 30 (ROS) or operator 3073 (CIDCount). These two operators
are mutually implied — a CID-keyed font has both.

### ROS operator (30)

```
ROS: 3 operands = (Registry_SID, Ordering_SID, Supplement)
```
Registry and Ordering are SIDs resolving to strings like "Adobe" /
"Japan1". Supplement is an integer. This identifies the CID system.

### CIDCount operator (3073)

```
CIDCount: 1 operand = total CID count (usually 65535 for full range)
```

### Charset format for CID fonts

The charset binary format (0/1/2) is the same, but the SID slots
contain **CIDs** instead of SIDs. The CID is simply a uint16.

For format 0:
```
format: uint8 = 0
cid: uint16[nGlyphs-1]   # CIDs for glyph_id 1..nGlyphs-1
```

For format 1 (common):
```
format: uint8 = 1
Range1[]: { first_cid: uint16; num_left: uint8 }
```

For format 2:
```
format: uint8 = 2
Range2[]: { first_cid: uint16; num_left: uint16 }
```

Note: format 1 is most common for Japanese/Chinese fonts because
CIDs are often allocated in contiguous ranges.

## Current code gaps

1. `parse_cff_charset` in `cff_charset.mbt` returns `Array[Int]`
   intended as SIDs. For CID fonts, the same data is actually CIDs —
   no format change, only semantic meaning.
2. `cff_glyph_name_table` resolves the array via Adobe Standard
   Strings + String INDEX. For CID fonts, SIDs in the array are CIDs
   that should NOT be resolved through the String INDEX.
3. `build_synthetic_cmap` in `cff_wrapper.mbt` only handles
   WinAnsiEncoding character codes 0-255. CID fonts use CID values
   up to 65535.
4. `svg_resolve_glyph_id` treats `GlyphIdentifier::CID(cid)` as a
   direct glyph_id, which fails for non-identity charsets.

## Solution

### Detection

New function in `cff_charset.mbt`:

```moonbit
pub fn is_cid_keyed_cff(data : Bytes) -> Bool {
  // Check TopDICT for operator 30 (ROS) or 3073 (CIDCount)
  // Returns true if either is present
}
```

## CID → glyph_id reverse mapping

The CID → glyph_id reverse mapping inverts the CID-keyed charset
array so the renderer can translate a PDF Type0 CID into a CFF
glyph_id for a CID-keyed font. Reverse lookup for CID fonts is
exposed through the synthetic post table (Option A below), keeping
the existing ffi surface unchanged. Identity preservation for Type1C
fonts is maintained by only emitting `cid.XXXXX` synthetic glyph
names when the font is detected as CID-keyed; Type1C fonts retain
their SID-based Adobe Standard Strings names.

### Reverse map construction

New function in `cff_charset.mbt`:

```moonbit
pub fn cff_cid_to_glyph_id_map(
  data : Bytes,
  num_glyphs : Int,
) -> Map[Int, Int]? {
  // For CID-keyed fonts, parse charset with CID semantics.
  // Build reverse map: cid → glyph_id (inverting the forward array).
  // glyph_id 0 is always CID 0 (.notdef in CID terms).
  // Returns None if the font is not CID-keyed or parsing fails.
}
```

### Expose reverse map through post table or separate accessor

Since the SVG renderer already looks up glyph names through
`ttf.post.glyph_names`, the cleanest integration is:

Option A (chosen): encode CIDs as synthetic glyph names in the post
table. For glyph_id G with CID C, emit post glyph name
`"cid.00000" + C.to_string()` (zero-padded to 5 digits). The
renderer's `svg_resolve_glyph_id` checks for this prefix when
handling `GlyphIdentifier::CID(cid)` and builds the reverse lookup
on the fly (or caches it).

Option A requires no new ffi surface — the existing `post` table
mechanism carries the mapping.

### Renderer integration

Modify `svg_resolve_glyph_id` in `render.mbt`:

```moonbit
GlyphIdentifier::CID(cid) =>
  match cff_reverse_cid_lookup(ttf, cid) {
    Some(gid) => gid
    None => cid  // existing fallback
  }
```

Where `cff_reverse_cid_lookup` scans `ttf.post.glyph_names` once
(cached per-TTFont) for `"cid.00000" + cid.to_string()` entries.
The cache is a per-TTFont `Map[Int, Int]`.

### Fallback and regression protection

If the CFF font is not CID-keyed, the existing Adobe Standard
Strings + WinAnsiEncoding path is used unchanged. The CID reverse
lookup returns None for Type1C fonts (because no `cid.XXXXX` names
are present in the post table).

## Files to modify

- `src/svg/cff_charset.mbt` — add `is_cid_keyed_cff`,
  `cff_cid_to_glyph_id_map`, CID-aware charset parsing
- `src/svg/cff_wrapper.mbt` — extend `build_synthetic_post` to emit
  `cid.XXXXX` names for CID-keyed fonts
- `src/svg/render.mbt` — modify `svg_resolve_glyph_id` for CID
  handling via the reverse map

## Acceptance verification

1. `moon test --target native` — all tests pass
2. local-fixture page 6 pixelmatch diff < 8.0% (baseline 12.6%)
3. local-fixture page 7 pixelmatch diff ≤ 17.6% (no regression)
4. Numbered list icons and Japanese text visible in page 6 SVG
   output (manual visual inspection)
