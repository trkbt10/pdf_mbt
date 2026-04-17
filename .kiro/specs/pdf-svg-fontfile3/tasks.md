# Tasks: FontFile3 Embedded Font Support

## Task 1: Add FontFile3 stream parsing function

**File:** `src/svg/render.mbt`

Add `parse_svg_font_file3_stream(stream: PdfStream) -> @font.TTFont?`:
1. Decode the stream with `@filters.decode_stream(stream)`
2. Parse with `@font.parse_font(bytes)` (auto-detects OTF/CFF format)
3. Return the TTFont or None

## Task 2: Modify font descriptor lookup to check FontFile3

**File:** `src/svg/render.mbt`

Modify `font_dict_direct_embedded_truetype_font` to:
1. First check FontFile2 (existing)
2. If not found, check FontFile3

```
match descriptor.get(PdfName::new(b"FontFile2")) {
  Some(Stream(stream)) => parse_svg_font_file2_stream(stream)
  _ => match descriptor.get(PdfName::new(b"FontFile3")) {
    Some(Stream(stream)) => parse_svg_font_file3_stream(stream)
    _ => None
  }
}
```

## Task 3: Verify with tests

Run `moon test --target native` — all 693 tests must pass.
Commit when done.
