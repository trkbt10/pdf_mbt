# Design: SVG Image Placement Precision

## Overview

Raise the numeric formatting precision used for SVG `<image>` element
transforms and coordinates from 3 decimals (`format_svg_number`) to
6 decimals (`format_svg_number_precise`), matching the precision
already adopted for glyph path transforms. Verify that the Y-axis
flip and CTM application logic is correct for both axis-aligned
images (attribute form) and non-axis-aligned images (matrix form).

## Current code

In `src/svg/render.mbt`:

### `write_svg_image` (lines ~492-526)
Chooses between axis-aligned attribute form and matrix form:

```
if !expand_x && !expand_y {
  match svg_axis_aligned_image_rect(matrix, page_height) {
    Some((x, y, width, height)) => emit <image x y width height href/>
    None => fall through to matrix form
  }
}
emit <image x=0 y=0 width=1 height=1 href transform=matrix(...)/>
```

### `svg_axis_aligned_image_rect` (lines ~529-540)
```
if abs(b) > 0.001 || abs(c) > 0.001 => None (not axis-aligned)
if a <= 0 || d <= 0 => None
Some((e, page_height - f - d, a, d))
```

### `write_svg_image_matrix` (lines ~543-562)
Emits matrix components with `format_svg_number` (3 decimals):
```
(a * x_scale, -b * x_scale, -c * y_scale, d * y_scale,
 e + c, page_height - f - d)
```

## CTM transformation analysis

PDF image transformation (ISO 32000-2 §8.9.5.1): the image occupies
the unit square (0,0)-(1,1) and the CTM transforms this to the page.
SVG uses top-left origin with Y-axis going down; PDF uses bottom-left
with Y-axis going up, so SVG y = page_height - pdf_y.

For non-axis-aligned images, the image unit square in SVG (top-left
origin) maps to the image unit square in PDF (bottom-left origin) via
y → 1-y, then through the CTM, then through the page-level Y-flip.
Combining the three transforms yields SVG matrix components
(A, B, C, D, E, F) = (a, -b, -c, d, e+c, page_height-f-d).

The current code at `write_svg_image_matrix` emits exactly these
coefficients. **The matrix formula is mathematically correct.** The
residual visual diff must come from precision, not formula.

## Axis-aligned form analysis

For axis-aligned images (b=0, c=0, a>0, d>0), the PDF image unit
square maps to the PDF rectangle:
- bottom-left: (e, f)
- top-right: (e+a, f+d)
- bottom-right: (e+a, f)
- top-left: (e, f+d)

In SVG (Y-flip), this rectangle has:
- top-left: (e, page_height - (f+d))  — upper-left SVG corner
- bottom-right: (e+a, page_height - f)

SVG `<image>` attributes:
- x = e
- y = page_height - f - d
- width = a
- height = d

This matches the current `svg_axis_aligned_image_rect`: ✓

## Non-axis-aligned image transform accuracy

For non-axis-aligned images, non-axis-aligned image transform
accuracy is guaranteed by applying the full CTM matrix with a Y-axis
flip. `write_svg_image_matrix` SHALL emit the matrix with components
(a, -b, -c, d, e+c, page_height-f-d) so that the unit-square
(0,0)-(1,1) maps to the PDF image region under the CTM with the SVG
Y-axis flip. Non-axis-aligned images include rotated, skewed, and
negatively-scaled images.

Pixel expansion detection. `svg_image_pixel_expansion` SHALL detect
whether the rendered image region exceeds the source image pixel
dimensions so that the scaling factor compensates for browser pixel
filtering. Thresholds SHALL remain as currently documented.

## Solution

### Precision upgrade

Change `write_svg_image_matrix` and the axis-aligned branch in
`write_svg_image` to use `format_svg_number_precise` (6 decimals):

```
fn format_svg_number_precise(v: Double) -> String {
  // Already exists in render.mbt for glyph path matrix
  ...
}
```

### Verify expected output

For an image at (10.5, 20.25) with size 50x75 in PDF, page height 792:
- Current (3 decimals): `x="10.5" y="696.75" width="50" height="75"`
- After (6 decimals): `x="10.5" y="696.75" width="50" height="75"`

No change for this example. But for CTM with computed fractional
values (e.g. image positioned at CTM-transformed coordinates with 2
decimal places in original CTM):
- Current: rounds to 0.001, can shift 1 pixel at small scales
- After: preserves up to 0.000001, no rounding error at rendering

### Expand detection unchanged

`svg_image_pixel_expansion` and `svg_image_axis_scales` determine
whether to oversample the image for browser filtering. These logic
paths are orthogonal to the precision question and are left unchanged.

## Files to modify

- `src/svg/render.mbt` — switch `format_svg_number` calls in:
  - `write_svg_image` axis-aligned attribute branch (4 calls)
  - `write_svg_image_matrix` (6 calls)
  to `format_svg_number_precise`

## Acceptance verification

After implementation:
1. local-fixture page 6 pixelmatch diff < 5.0%
2. local-fixture page 7 pixelmatch diff < 5.0%
3. Existing visual tests unchanged (their reference images should
   accept 6-decimal vs 3-decimal since rsvg-convert rounds pixels
   anyway, but if any test fails, investigate)
