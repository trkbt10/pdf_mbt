# Tasks: CID-keyed CFF font charset handling

## Task 1: Detect CID-keyed CFF fonts

**File:** `src/svg/cff_charset.mbt`

Add `is_cid_keyed_cff(data: Bytes) -> Bool`:

1. Parse the CFF header and locate the TopDICT
2. Search for operator 30 (ROS, one-byte operator) or operator
   3073 (CIDCount, two-byte 12 + 1)
3. Return true if either is present

Also add:
- `cff_cid_count(data: Bytes) -> Int` — reads the CIDCount operator
  (3073), returns 0 if not present

## Task 2: Parse CID-keyed charset with CID semantics

**File:** `src/svg/cff_charset.mbt`

Add `parse_cff_cid_charset(data: Bytes, num_glyphs: Int) -> Array[Int]?`:

- Uses the same charset format parsing as `parse_cff_charset` (formats
  0, 1, 2)
- Returns array where index is glyph_id and value is CID
- Result semantics: glyph_id 0 is always CID 0 (.notdef)

The existing `parse_cff_charset` can be reused because the binary
format is identical — only the interpretation differs.

## Task 3: Build CID-to-glyph_id reverse map

**File:** `src/svg/cff_charset.mbt`

Add `cff_cid_to_glyph_id_map(data: Bytes, num_glyphs: Int) -> Map[Int, Int]?`:

1. If the font is not CID-keyed (`is_cid_keyed_cff` returns false),
   return None
2. Call `parse_cff_cid_charset` to get glyph_id → CID array
3. Build inverse Map: CID → glyph_id
4. Return the map

## Task 4: Emit CID glyph names in synthetic post table

**File:** `src/svg/cff_wrapper.mbt`

Modify `build_synthetic_post` (or create it if not present):

- For CID-keyed fonts, generate glyph names of the form
  `"cid00000"`, `"cid00001"`, etc., zero-padded to 5 digits after
  the `cid` prefix (so CID 12 becomes `"cid00012"`)
- For Type1C fonts, keep the existing charset-resolved glyph names

This leverages the existing post table path so no new ffi surface
is needed.

## Task 5: Renderer CID reverse lookup

**File:** `src/svg/render.mbt`

Add `svg_cid_glyph_id(ttf: TTFont, cid: Int) -> Int`:

1. Scan `ttf.post.glyph_names` for `"cid" + zero_pad(cid, 5)`
2. Return the first matching glyph_id, or -1 if not found

Modify `svg_resolve_glyph_id` for `GlyphIdentifier::CID(cid)`:

```
GlyphIdentifier::CID(cid) =>
  let mapped = svg_cid_glyph_id(ttf, cid)
  if mapped >= 0 { mapped } else { cid }
```

Consider caching the per-TTFont CID map since this lookup may be
called many times per page.

## Task 6: Verify with unit tests

**File:** `src/svg/render_wbtest.mbt`

Add tests:

1. `is_cid_keyed_cff` returns false for Type1C fixtures, true for a
   CID-keyed CFF fixture (if one is available in mizchi/font
   fixtures).
2. `parse_cff_cid_charset` on a known CID-keyed CFF returns a
   non-None array whose length equals num_glyphs.
3. `cff_cid_to_glyph_id_map` produces a valid inverse map for known
   test data.
4. `svg_cid_glyph_id` resolves known CIDs via synthetic post table
   names.

## Task 7: Visual verification

1. `moon test --target native` — all tests pass
2. `moon build --target wasm-gc --release && cp _build/wasm-gc/release/build/src/npm/npm.wasm npm/dist/pdf.wasm`
3. local-fixture page 6 pixelmatch diff — target < 8.0% (baseline 12.6%)
4. local-fixture page 7 pixelmatch diff — no regression (≤ 17.6%)
5. Visually verify numbered list icons (①②③④) and Japanese text
   appear in page 6 output

## Task 8: Spec alignment gate

```bash
indexion spec align status .kiro/specs/pdf-svg-cid-charset/requirements.md src/svg/ --threshold 0.3 --fail-on drifted
```

Must exit 0.
