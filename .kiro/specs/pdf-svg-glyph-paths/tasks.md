# Tasks: SVG Glyph Path Rendering

## Task 1: Build font-name → TTFont map for SVG rendering

**File:** `src/svg/render.mbt`

Add a function `page_svg_embedded_fonts(page) -> Map[PdfName, TTFont]`
that iterates over the page's font resources and, for each font with
a FontFile2 stream in its FontDescriptor, parses the embedded TrueType
font and stores it in the map.

This parallels the existing `page_svg_font_families` function but
returns TTFont objects instead of CSS font-family strings.

Use the same parsing logic as `font_runtime.mbt::parse_embedded_truetype_font`.

**Requirement:** 3.2, 6.2

## Task 2: Add glyph path rendering function

**File:** `src/svg/render.mbt`

Add `render_glyph_as_path(builder, glyph, ttf, units_per_em, page_height)`
that:

1. Gets the glyph ID via `ttf.cmap.get(glyph.glyph.source_code)`
2. Gets the outline via `ttf.glyph_outline(gid)`
3. Converts to SVG path data via `@font.path_commands_to_svg_d(outline)`
4. Computes the transform matrix from `glyph.rendering_matrix`:
   - Scale by `1.0 / units_per_em`
   - Apply Y-flip for SVG (negate b, c; f = page_height - f)
5. Emits `<path d="..." transform="matrix(...)" fill="..."/>`

Handle the case where cmap lookup fails or outline is empty by
falling through to text rendering.

**Requirement:** 1.1, 1.2, 2.1, 2.2, 5.1

## Task 3: Add span-level glyph path rendering

**File:** `src/svg/render.mbt`

Add `page_render_text_span_as_paths(builder, span, glyphs, ttf, page_height)`
that renders all glyphs in a text span as individual `<path>` elements.

For each glyph in the span:
- Skip zero-width spacing glyphs
- Call `render_glyph_as_path` for each visible glyph
- Use the span's fill colour (nonstroking colour from graphics state,
  currently hardcoded as "#000000")

**Requirement:** 4.1, 4.2, 5.1

## Task 4: Modify page_render_text_svg to use paths when available

**File:** `src/svg/render.mbt`

Modify `page_render_text_svg` (or its caller in `page_render_svg_text_events`)
to:

1. Accept the embedded fonts map
2. For each text span, check if the span's font_name has an entry in
   the embedded fonts map
3. If yes, call `page_render_text_span_as_paths` instead of the
   existing `page_render_text_svg`
4. If no, fall back to the existing `<text>` rendering

Update `page_render_svg_text_events` to build the embedded fonts map
once and pass it through.

**Requirement:** 3.1, 3.2

## Task 5: Add moon.pkg dependency

**File:** `src/svg/moon.pkg`

Add `"mizchi/font"` to the import list so the SVG package can access
`path_commands_to_svg_d` and `TTFont` APIs directly.

Also add `"mizchi/svg"` if needed for the `PathCommand` type.

**Requirement:** 1.1

## Task 6: Update tests

**File:** `src/svg/render_wbtest.mbt`

Add tests that verify:
- A PDF with embedded TrueType font produces `<path>` elements instead
  of `<text>` elements for its text
- A PDF with Standard 14 font (no embedding) still produces `<text>`
  elements
- The glyph path transform includes correct scaling and positioning

**Requirement:** 1.1, 3.1

## Task 7: Verify with moon test

Run `moon test --target native` and ensure all tests pass (currently 686).

Commit changes when tests pass.
