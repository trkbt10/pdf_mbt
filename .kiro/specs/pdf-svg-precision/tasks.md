# Tasks: SVG Rendering Precision — Text Metrics

## Task 1: Extract effective font size from rendering matrix

**File:** `src/svg/render.mbt`

Add a function `svg_extract_font_size(matrix: TextMatrix) -> Double` that
extracts the effective font size from the rendering matrix:
- For non-rotated matrices: `abs(matrix.d)`
- For rotated matrices: `sqrt(matrix.a * matrix.a + matrix.b * matrix.b)`

This handles both standard font-size (Tf operator) and CTM-based sizing
(Firefox-style PDFs where Tf=1 and CTM carries the scale).

**Requirement:** 1.1, 3.1

## Task 2: Decompose rendering matrix — factor out font-size

**File:** `src/svg/render.mbt`

Add a function `svg_text_transform_without_fontsize(matrix: TextMatrix, font_size: Double, page_height: Double) -> TextMatrix`
that produces the SVG transform matrix with font-size factored out:

- Divide a, b, c, d by font_size
- Adjust e, f for PDF→SVG Y-flip (e stays, f = page_height - f)
- The resulting matrix handles horizontal scaling (Th) and rotation

**Requirement:** 1.2, 1.3

## Task 3: Compute absolute glyph positions in SVG user-space

**File:** `src/svg/render.mbt`

Modify `svg_positioned_text` to compute glyph x/y positions in absolute
SVG points (post-font-size) instead of 1/fs-relative units:

- For each glyph, get its rendering_matrix translation (e, f)
- Subtract the parent text element's translation
- Apply the inverse of the parent's non-translation components
- Result: positions in the font-size coordinate system (multiply by 1.0,
  since font-size is now real)

For the common non-rotated case, the x position of glyph n relative to
glyph 0 is: `(glyph_n.rm.e - glyph_0.rm.e) / (font_size * Th)`

Wait — since the transform already includes Th, the tspan x values
should be in the post-Th coordinate system. Need to think about this:

Actually the correct computation is:
- parent transform = T_m/fs × CTM (with fs factored out)
- parent inverse maps global → local
- glyph global position = (rm.e, rm.f) in PDF space
- glyph local = parent_inverse × glyph_global
- That local position is in the text element's coordinate system where
  font-size applies

Simplest correct approach: keep the current `svg_matrix_local_point`
logic but use the new parent matrix (without font-size) instead of the
old one (with font-size). The local points will then be in points, not
in 1/fs units.

**Requirement:** 2.1, 2.2, 2.3

## Task 4: Update page_render_text_svg to emit real font-size

**File:** `src/svg/render.mbt`

Modify `page_render_text_svg` to:
1. Call `svg_extract_font_size` to get effective font size
2. Write `font-size="{effective_fs}"` instead of `font-size="1"`
3. Call `svg_text_transform_without_fontsize` for the transform matrix
4. Remove `text-anchor="start"` and `textLength`/`lengthAdjust` if present
   (these were workarounds for the 1-unit coordinate system)

**Requirement:** 1.1, 1.2

## Task 5: Update unit tests

**File:** `src/svg/render_wbtest.mbt`

Update all SVG rendering tests to expect:
- Real font-size values instead of `font-size="1"`
- Absolute coordinates in tspan x/y values
- Correct transform matrices with font-size factored out

**Requirement:** 8.1

## Task 6: Visual regression verification

Run the visual E2E tests (`npm/test/visual/compare.mjs`) and verify:
- Simple PDF: pixel diff < 0.01%
- UTF-8 PDF: pixel diff < 0.01%
- CalRGB PDF: pixel diff < 0.01%

If references need regeneration due to improved rendering, regenerate
with pdftoppm at 72 DPI and verify the new diff values.

**Requirement:** 8.1, 8.2
