# Tasks: CFF-to-OTF Wrapper for FontFile3

## Task 1: Create CFF-to-OTF wrapper module

**File:** `src/svg/cff_wrapper.mbt`

Create functions to wrap raw CFF data in a minimal OTF container:

1. `is_raw_cff(data: Bytes) -> Bool` — detect raw CFF (first byte == 0x01, not sfnt magic)
2. `cff_charstrings_count(data: Bytes) -> Int` — parse CFF header, skip Name/TopDICT/String/GlobalSubr INDEXes, read TopDICT operator 17 (CharStrings offset), read count at that offset
3. `build_synthetic_head(units_per_em: Int) -> Bytes` — 54-byte head table
4. `build_synthetic_maxp(num_glyphs: Int) -> Bytes` — 6-byte maxp (CFF version)
5. `build_synthetic_hhea(num_glyphs: Int) -> Bytes` — 36-byte hhea
6. `build_synthetic_hmtx(num_glyphs: Int) -> Bytes` — 4*num_glyphs bytes
7. `build_synthetic_cmap(num_glyphs: Int) -> Bytes` — format 12 identity mapping
8. `wrap_cff_in_otf(cff_data: Bytes) -> Bytes` — compose all tables, call `@font.rebuild_sfnt(0x4F54544F, tables)`

## Task 2: Integrate wrapper into FontFile3 parsing

**File:** `src/svg/render.mbt`

Modify `parse_svg_font_file3_stream`:
```
fn parse_svg_font_file3_stream(stream: PdfStream) -> TTFont? {
  let decoded = try? @filters.decode_stream(stream)
  match decoded {
    Ok(bytes) =>
      if is_raw_cff(bytes) {
        let wrapped = wrap_cff_in_otf(bytes)
        @font.parse_font(wrapped)
      } else {
        @font.parse_font(bytes)
      }
    Err(_) => None
  }
}
```

## Task 3: Verify with tests

Run `moon test --target native` — all tests must pass.
Test with <local-fixture> page 6 — FrutigerLTStd glyphs should render as `<path>` instead of `<text>`.
