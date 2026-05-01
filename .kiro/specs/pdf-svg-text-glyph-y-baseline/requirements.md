# Requirements: Glyph y-baseline integrity for SVG glyph-path renderer

## Background

The MoonBit PDF→SVG renderer at `src/svg/render.mbt` converts page content
into SVG primitives. For text spans whose font has an embedded program,
the renderer emits per-glyph `<path>` elements via
`write_svg_glyph_path_matrix`, each carrying a
`transform="matrix(a b c d tx ty)"`. The translation component
`(tx, ty)` places that glyph on the page.

Browser-based RED evidence on `<local-fixture>`
page 4 (1-indexed) shows that every `<path>` element belonging to the
F6 italic-bold bullet-label spans paints with the SAME `ty=81.86` — the
y coordinate of the heading row at the top of the page. `tx` advances
per glyph correctly. As a result, dozens of bullet-label glyphs collapse
onto a single baseline at page top, overlapping the heading and
producing visually mirrored, unreadable garble. Body prose (F1) paints
with correct per-row `ty` (133.25, 311.38, 477.50, ...).

The wasm `pageTextPositions` API returns CORRECT `y` for the F6 label
spans (y=221, 206, 192, ...), so the text-state machinery in `src/text/`
is computing per-row baselines correctly. The defect lies in how those
baselines flow into each glyph's `rendering_matrix`, OR in how
`src/svg/render.mbt` derives the `ty` for the per-glyph SVG transform.

## Requirement 1: Per-glyph y baseline equals span baseline

### 1.1: Glyph ty matches span y from pageTextPositions

For every `TextSpan` whose font has an embedded program, every emitted
`<path>` glyph in the SVG output SHALL carry a `transform` whose `ty`
component equals `page_height − Y`, where `Y` is the `y` value
`PdfDocument::page_text_positions(pageIndex)` reports for that span,
within `1e-3` numerical tolerance.

### 1.2: Distinct rows produce distinct y

For a page that contains text rows at multiple distinct `y` values, the
distinct count of `ty` values across all glyphs in the same span SHALL
equal `1` (single row per span), and the distinct count of `ty` values
across spans SHALL be greater than or equal to the distinct count of
row baselines reported by `pageTextPositions`.

### 1.3: F6 label spans render readably on OpenXML page 4

After the fix, the rendered SVG of <local-fixture> page 4 in
the npm demo SHALL contain glyph-paths whose `ty` values include the
y-baselines of every visible bullet-list label row (e.g. y near `221`,
`206`, `192` mapped through `page_height − y`). The number of unique
`ty` values shall be `≥ 6` for the bullet-list region (one per label
row), not `1`.

## Requirement 2: Text-state and rendering-matrix invariants

### 2.1: TextRenderingMatrix preserves per-glyph baseline updates

`TextRenderingMatrix::from_text_state` in `src/text/matrix.mbt` SHALL
compose `text_state`, `text_matrix`, and `ctm` so that the resulting
`matrix.f` reflects whatever `text_matrix.f` was supplied. When two
calls to `from_text_state` differ only in `text_matrix.f`, the output
`matrix.f` SHALL differ accordingly.

### 2.2: Per-glyph snapshot uses live text_matrix

The text interpreter at `src/text/interpreter.mbt` SHALL pass a
`text_matrix` to `TextRenderingMatrix::from_text_state` that reflects
all line-positioning operators (`Td`, `TD`, `T*`, `Tm`) that ran prior
to the glyph being emitted. Specifically, when a single `BT…ET` text
object spans multiple rows separated by `Td`/`T*`, the per-glyph
`rendering_matrix.matrix.f` SHALL change between rows.

### 2.3: SVG glyph-path matrix preserves baseline

`write_svg_glyph_path_matrix` in `src/svg/render.mbt` SHALL emit
`ty = page_height − rendering_matrix.matrix.f` without further
modification of the `f` component.

## Requirement 3: Regression safety

### 3.1: Existing svg tests pass

`moon test --target native -p trkbt10/pdf/src/svg` SHALL pass with no
new failures and no skipped tests when the fix lands.

### 3.2: Existing text tests pass

`moon test --target native -p trkbt10/pdf/src/text` SHALL pass with no
new failures and no skipped tests when the fix lands.

### 3.3: Existing graphics tests pass

`moon test --target native -p trkbt10/pdf/src/graphics` SHALL pass with
no new failures and no skipped tests when the fix lands.

## Requirement 4: End-to-end browser verification

### 4.1: Demo bullet-region readability

A fresh `vite build` of `npm/demo` loaded in headless Chromium SHALL
render <local-fixture> page 4 such that the bullet-list region
contains glyphs whose `getBBox()` y values span at least three distinct
row centroids, not collapsed to a single y. This is verified by a node
test that reads each `<path>` `getBBox()` and clusters by y.

### 4.2: pageTextPositions parity

For the bullet-list region of OpenXML page 4, the set of distinct
`(font_name, y)` pairs reported by `pageTextPositions(3)` SHALL each
have at least one corresponding glyph-path in the SVG whose `ty`
satisfies `|ty − (page_height − y)| < 1.0` px.

## Out of scope

- Fallback `<text>` element rendering when no embedded font is
  available (handled by other specs such as `pdf-svg-system-fonts`).
- Fonts without per-glyph translation: Type 3 procedures, image-based
  fonts, soft-mask glyphs.
- The user-reported "Perpetua empty tspan" symptom — body prose for
  Perpetua spans already paints correctly via the glyph-path branch
  after the optional-content `/Type` fix; that issue is resolved
  separately.
- Horizontal advance correctness; this spec addresses vertical baseline
  only.
