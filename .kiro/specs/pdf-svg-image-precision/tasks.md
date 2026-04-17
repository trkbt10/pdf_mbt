# Tasks: SVG Image Placement Precision

## Task 1: Audit format_svg_number usage for images

**File:** `src/svg/render.mbt`

Identify all `format_svg_number` calls that emit image coordinates:

- `write_svg_image` axis-aligned attribute branch (x, y, width, height)
- `write_svg_image_matrix` (a, b, c, d, e, f matrix components)

Document each call site that will be upgraded.

## Task 2: Upgrade axis-aligned image attributes to 6-decimal precision

**File:** `src/svg/render.mbt`

In `write_svg_image` axis-aligned branch, replace `format_svg_number`
with `format_svg_number_precise` for:

- `x` attribute
- `y` attribute
- `width` attribute
- `height` attribute

## Task 3: Upgrade image matrix transform to 6-decimal precision

**File:** `src/svg/render.mbt`

In `write_svg_image_matrix`, replace `format_svg_number` with
`format_svg_number_precise` for all six matrix components:
a*x_scale, -b*x_scale, -c*y_scale, d*y_scale, e+c, page_height-f-d.

## Task 4: Verify axis-aligned rect Y-axis flip

**File:** `src/svg/render.mbt`

Verify that `svg_axis_aligned_image_rect` returns:
`(matrix.e, page_height - matrix.f - matrix.d, matrix.a, matrix.d)`

This matches PDF → SVG Y-flip for axis-aligned images. No code change
expected; add a doc comment that links to Requirement 2.1-2.2.

## Task 5: Verify matrix form Y-axis flip

**File:** `src/svg/render.mbt`

Verify that `write_svg_image_matrix` emits:
`(a, -b, -c, d, e+c, page_height - f - d)`

which maps the SVG image unit square (y-down) through PDF CTM with
embedded y-flip (y → 1-y) and then the page-level y-flip. See
design.md §"CTM transformation analysis" for derivation.

No code change expected in the formula itself; the fix is precision
only. Add doc comment linking to Requirement 3.1.

## Task 6: Rebuild and visual diff

1. `moon test --target native` — all tests pass
2. `moon build --target wasm-gc --release && cp _build/wasm-gc/release/build/src/npm/npm.wasm npm/dist/pdf.wasm`
3. Run pixelmatch comparison for <local-fixture> pages 6, 7
4. Report actual diff percentages

Acceptance: page 6 diff < 5.0%, page 7 diff < 5.0%.

## Task 7: Spec alignment gate

Before committing, run:

```bash
indexion spec align status .kiro/specs/pdf-svg-image-precision/requirements.md src/svg/ --threshold 0.3 --fail-on any
```

All requirements SHALL be MATCHED. Add doc comments referencing spec
vocabulary (pixel expansion detection, Y-axis flip, CTM components,
6-decimal precision) as needed to close any DRIFTED/SPEC_ONLY items.
