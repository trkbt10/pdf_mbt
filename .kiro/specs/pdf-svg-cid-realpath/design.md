# Design: CID-keyed CFF reverse-lookup real-data path

## Overview

Diagnose why the CID reverse-lookup path added in
`pdf-svg-cid-charset` does not activate for real local-fixture
FontFile3 streams, then apply a targeted fix. The scope is
debugging + minimal correction, not a rewrite of CID handling.

## Diagnostic instrumentation for real local-fixture CFF data

The diagnostic instrumentation for real local-fixture CFF data is a
whitebox test that loads <local-fixture>, iterates the
page-6 font resources, decodes every FontFile3 stream, and prints
the state of the detection / parsing / post table / renderer
reverse-lookup chain for each stream. The output pinpoints which
stage is failing for real data.

## Investigation plan

The failure happens somewhere in the chain:

```
FontFile3 stream
 → decode_stream (existing)
 → is_raw_cff (cff_wrapper.mbt)      [A]
 → is_cid_keyed_cff (cff_charset.mbt) [B]
 → parse_cff_cid_charset             [C]
 → cff_cid_to_glyph_id_map           [D]
 → build_synthetic_post with cid00000 names  [E]
 → rebuild_sfnt + parse_font                  [F]
 → ttf.post.glyph_names populated              [G]
 → svg_resolve_glyph_id reverse lookup        [H]
```

Any single break in A→H prevents the path from activating.

### Diagnostic test outline

A new whitebox test in `src/svg/render_wbtest.mbt` loads local-fixture page 6
FontFile3 streams and prints the state of each stage:

```moonbit
test "diagnostic local-fixture page 6 CID font chain" {
  let path = "<local-fixture>"
  if !@fs.path_exists(path) { return }
  let document = @reader.PdfDocument::open(@fs.read_file_to_bytes(path))
  let page = document.page(5)
  let resources = page.text_resources()
  for name, summary in resources.fonts {
    // Walk the font object → find FontFile3 streams → decode
    // Print stages A-G for each stream
    ...
  }
}
```

Output pattern:

```
font C0_0:
  FontFile3 stream decoded, len=12345
  is_raw_cff=true
  is_cid_keyed_cff=true
  CIDCount=256
  charset format=1, num_ranges=3, num_glyphs=7
  cid_map size=7, sample: {0=>0, 1=>256, ...}
  wrapped OTF len=20123
  parse_font ok, num_glyphs=7
  post.glyph_names[0..4]=[".notdef", "cid00256", "cid00257", ...]

font C0_1:
  ...

font T1_0 (Type1C, not CID):
  is_cid_keyed_cff=false
  (skipped — uses Type1C path)
```

From this output we can pinpoint the exact stage that fails and
apply a targeted fix.

## Anticipated fixes

Without running the diagnostic yet, the three most likely root
causes and their fixes:

### Fix option 1: TopDICT operator 30 detection

The CFF TopDICT scanner (`cff_dict_find_operator`) may not skip
operand 30 (real number) correctly. Real numbers are variable-length
nibble encoded and the scanner must advance past them. Adobe TN 5176
Table 5 specifies the nibble format.

If the scanner treats the first nibble of a real number as an
operator, the ROS (operator 30) detection might misfire — either
false positive (non-CID font detected as CID) or false negative
(CID font not detected because scanner gets lost in the real number
bytes).

**Fix**: audit `cff_dict_find_operator` and `cff_decode_dict_operand`
in `cff_wrapper.mbt` to ensure real number operand bytes are fully
consumed. Reference: mizchi/font `cff.mbt` `skip_real_number`.

### Fix option 2: Synthetic post table format

mizchi/font's `parse_post` (in parser.mbt) expects post table
format 1.0, 2.0, 2.5, 3.0, or 4.0. Format 2.0 is the only format
that carries per-glyph names:

```
version: 0x00020000 (fixed)
italicAngle, underlinePosition, underlineThickness, isFixedPitch,
minMemType42, maxMemType42, minMemType1, maxMemType1
numGlyphs: uint16
glyphNameIndex: uint16[numGlyphs]
names: Pascal strings (length byte + bytes) for custom name entries
  (indexed by glyphNameIndex[i] - 258 when glyphNameIndex[i] >= 258;
   indexes 0-257 are Macintosh standard glyph names)
```

If the current `build_synthetic_post` does not emit this exact
format, `parse_post` silently returns an empty glyph_names array.

**Fix**: verify the format with a Python inspection tool or
cross-check against a known working OTF (e.g. running the existing
cff_wrapper output through `fontTools.ttLib`).

### Fix option 3: Renderer string comparison

The renderer reverse-lookup must match the exact string produced by
the wrapper. Candidates for the format:
- `"cid00000"` (no separator, 5 digits)
- `"cid.00000"` (dot separator, Adobe Glyph List Convention)
- `"cid00012"` (5 digits for CID 12)

**Fix**: unify on `"cid00012"` (no separator, zero-padded to 5
digits after prefix) in both `build_synthetic_post` and
`svg_cid_glyph_id`. Use a shared helper function if practical.

## Files likely to change

- `src/svg/render_wbtest.mbt` — new diagnostic test
- `src/svg/cff_charset.mbt` or `cff_wrapper.mbt` — depending on
  diagnosis, one of:
  - fix TopDICT real-number operand handling
  - fix post table format
  - fix glyph name string format

Do not introduce new public APIs. The fix SHALL be minimal and
targeted at the specific stage identified by the diagnostic test.

## Acceptance verification

1. `moon test --target native` — all tests pass, diagnostic test
   prints useful output for C0_0 and C0_1 fonts on local-fixture page 6
2. Wasm rebuild
3. local-fixture page 6 pixelmatch diff < 10.0%
4. local-fixture page 7 diff not regressed (still ≤ 17.6%)
