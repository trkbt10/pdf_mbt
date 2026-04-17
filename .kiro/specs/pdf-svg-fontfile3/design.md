# Design: FontFile3 Embedded Font Support

## Current code

`font_dict_direct_embedded_truetype_font` in `src/svg/render.mbt` only
checks `FontFile2`:

```
match descriptor.get(PdfName::new(b"FontFile2")) {
  Some(Stream(stream)) => parse_svg_font_file2_stream(stream)
  _ => None
}
```

## Target code

Add FontFile3 fallback:

```
match descriptor.get(PdfName::new(b"FontFile2")) {
  Some(Stream(stream)) => parse_svg_font_file2_stream(stream)
  _ => match descriptor.get(PdfName::new(b"FontFile3")) {
    Some(Stream(stream)) => parse_svg_font_file3_stream(stream)
    _ => None
  }
}
```

`parse_svg_font_file3_stream` decodes the stream and calls
`@font.parse_font()` which auto-detects format (OTF with CFF, etc.).

## Files to modify

- `src/svg/render.mbt` — add FontFile3 handling
