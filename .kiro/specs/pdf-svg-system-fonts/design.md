# Design: System Font Resolution for SVG Glyph Path Rendering

## Architecture

```
page_svg_embedded_fonts(page) → Map[PdfName, TTFont]
    ↓
For fonts NOT in embedded map:
    ↓
resolve_system_font(base_font_name) → TTFont?
    ↓
    1. Map BaseFont → candidate file names
    2. Search OS font directories for candidates
    3. Read file via @fs.read_file_to_bytes
    4. Parse via @font.parse_ttf or @font.parse_font_collection
    5. Cache in render-scoped map
    ↓
If found → glyph path rendering (same as embedded)
If not found → <text> fallback
```

## Files

### New file: `src/svg/system_font.mbt`
- `resolve_system_font(base_font: PdfName) -> @font.TTFont?`
- `system_font_directories() -> Array[String]`
- `standard14_candidate_names(base_font: PdfName) -> Array[String]`
- Font file reading and parsing

### Modified: `src/svg/render.mbt`
- `page_svg_embedded_fonts` → also resolve system fonts for
  Standard 14 fonts that have no embedding
- Or: separate system font map built alongside embedded font map

### Modified: `src/svg/moon.pkg`
- Add `"moonbitlang/x/fs"` to imports (for `read_file_to_bytes`)
- Already has `"mizchi/font"` from glyph-paths spec

## Conditional compilation

MoonBit supports `#[cfg(target = "native")]` or we can use
try/catch on `@fs.read_file_to_bytes` which raises `IOError`.
On wasm-gc, the function will raise and we catch → return None.

## Font name mapping

Not hardcoding specific paths. Instead:
1. OS-specific directories from `@config.resolve_os_dir` pattern
2. Candidate names derived from BaseFont by stripping style suffixes
3. File extension search order: .ttc, .ttf, .otf
