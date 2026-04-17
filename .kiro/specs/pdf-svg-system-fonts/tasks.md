# Tasks: System Font Resolution for SVG Glyph Path Rendering

## Task 1: Add system font resolution module

**New file:** `src/svg/system_font.mbt`

Implement:

1. `system_font_directories() -> Array[String]` — returns OS font
   directories. Use environment variable detection (`HOME` for paths,
   check for `/System/Library` existence to detect macOS vs Linux).

2. `standard14_base_name(font_name: String) -> String` — strips style
   suffixes from Standard 14 names:
   - "Helvetica-Bold" → "Helvetica"
   - "Helvetica-Oblique" → "Helvetica"
   - "Times-Roman" → "Times"
   - "Times-Bold" → "Times"
   - "Courier-Bold" → "Courier"
   Strip at the last hyphen, with special cases for "Times-Roman" → "Times".

3. `standard14_candidate_names(base_name: String) -> Array[String]` —
   returns alternative file names to search:
   - "Helvetica" → ["Helvetica", "Arial"]
   - "Times" → ["Times", "Times New Roman"]
   - "Courier" → ["Courier", "Courier New"]
   - For others, return just the base name.

4. `resolve_system_font(font_name: String) -> @font.TTFont?` —
   searches font directories for the font:
   - Get base name via standard14_base_name
   - Get candidates via standard14_candidate_names
   - For each directory, for each candidate, try extensions .ttc, .ttf, .otf
   - Read file with `@fs.read_file_to_bytes(path)` (wrap in try/catch)
   - For .ttc: use `@font.parse_font_collection()`, take first font
   - For .ttf/.otf: use `@font.parse_ttf()`
   - Return first successful parse, or None

**Requirement:** 1.1, 1.2, 2.1, 2.2, 2.3, 5.1

## Task 2: Integrate system fonts into SVG rendering

**File:** `src/svg/render.mbt`

Modify `page_svg_embedded_fonts` (or add a new function
`page_svg_all_fonts`) to:

1. First collect embedded fonts as before
2. For each font in text_resources that has NO embedded TTFont,
   call `resolve_system_font(base_font_name)`
3. If found, add to the map

This way the glyph path rendering pipeline automatically uses
system fonts for Standard 14 fonts.

**Requirement:** 4.1, 4.2

## Task 3: Add font caching

**File:** `src/svg/system_font.mbt`

Add a module-level or function-scoped cache:
- Use a `Map[String, @font.TTFont?]` to cache resolution results
- Cache both hits (Some) and misses (None) to avoid repeated file I/O
- The cache lives for the duration of the render call

**Requirement:** 3.1, 3.2

## Task 4: Update moon.pkg dependencies

**File:** `src/svg/moon.pkg`

Add `"moonbitlang/x/fs"` to the import list for file system access.

**Requirement:** 5.1

## Task 5: Add tests

**File:** `src/svg/system_font_wbtest.mbt`

Add tests:
- `standard14_base_name` correctly strips suffixes
- `standard14_candidate_names` returns correct alternatives
- `system_font_directories` returns non-empty list
- `resolve_system_font("Helvetica")` returns Some on macOS
  (skip if font not available)

**File:** `src/svg/render_wbtest.mbt`

Add test:
- Simple PDF 2.0 (Helvetica, Standard 14) produces `<path>` elements
  instead of `<text>` elements when system font is available

## Task 6: Verify

Run `moon test --target native` — all tests must pass.
Commit when done.
