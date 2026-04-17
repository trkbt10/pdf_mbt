# SDD Draft: SVG Image Placement Precision

## Problem

Visual diff between the SVG renderer output and pdftoppm reference
for pages with embedded raster images (e.g. <local-fixture>
page 6, 7) is dominated by image-related pixel differences. Diff
images show large red blocks aligned with image regions, indicating
either:

1. Incorrect image position (x/y offset error from CTM application)
2. Incorrect image size (width/height scaling error)
3. Accumulated rounding error from low-precision number formatting

The current SVG renderer formats image transform coordinates with
`format_svg_number` (3-decimal precision), while glyph path
transforms use `format_svg_number_precise` (6-decimal). At 72 DPI a
3-decimal error of 0.001 PDF unit can shift by 0.001 pixel, but
accumulated CTM multiplications amplify this; 6-decimal precision is
already proven necessary for glyph rendering.

ISO 32000-2 §8.3 defines the Current Transformation Matrix (CTM) and
§8.9.5 defines image placement: an image is mapped from the unit
square (0,0)-(1,1) to the page via CTM. The renderer must apply the
full CTM including non-axis-aligned transforms.

## Requirements

### Requirement 1: High-precision image transform formatting

#### 1.1: 6-decimal precision for matrix transforms
The SVG renderer SHALL format image `transform="matrix(a b c d e f)"`
values with `format_svg_number_precise` (6-decimal precision), not
`format_svg_number` (3-decimal), to match the precision used for
glyph path transforms.

#### 1.2: 6-decimal precision for axis-aligned image attributes
The SVG renderer SHALL format image `x`, `y`, `width`, `height`
attributes for axis-aligned images with `format_svg_number_precise`
(6-decimal precision).

### Requirement 2: Axis-aligned image bounds accuracy

#### 2.1: Y-axis flip for axis-aligned rect
`svg_axis_aligned_image_rect` SHALL compute the SVG y-coordinate as
`page_height - matrix.f - matrix.d` (page-height minus the PDF-space
origin y minus the PDF-space height), matching the Y-axis flip used
for all other SVG elements.

#### 2.2: Width and height from CTM diagonal
For an axis-aligned image (b=c=0), width SHALL be matrix.a and height
SHALL be matrix.d (matching the PDF image coordinate convention where
the image fills the unit square transformed by CTM).

#### 2.3: Axis-aligned detection threshold
`svg_axis_aligned_image_rect` SHALL treat an image as axis-aligned
only when `abs(matrix.b) < 0.001 && abs(matrix.c) < 0.001`, so that
near-zero rotations still use the simpler attribute form without
visible error.

### Requirement 3: Non-axis-aligned image transform accuracy

#### 3.1: Full CTM matrix with Y-axis flip
For non-axis-aligned images, `write_svg_image_matrix` SHALL emit the
matrix with components (a, -b, -c, d, e+c, page_height-f-d) so that
the unit-square (0,0)-(1,1) maps to the PDF image region under the
CTM with the SVG Y-axis flip.

#### 3.2: Pixel expansion detection
`svg_image_pixel_expansion` SHALL detect whether the rendered image
region exceeds the source image pixel dimensions so that the scaling
factor compensates for browser pixel filtering. Thresholds SHALL
remain as currently documented.

### Requirement 4: Acceptance criteria

#### 4.1: local-fixture page 6 image diff reduction
After implementation, <local-fixture> page 6 pixelmatch diff
against pdftoppm at 72 DPI SHALL be less than 5.0%. Current baseline
is approximately 14.0%; removing image placement error is expected
to close most of this gap.

#### 4.2: local-fixture page 7 image diff reduction
<local-fixture> page 7 pixelmatch diff SHALL be less than 5.0%.
Current baseline is approximately 18.3%.

#### 4.3: No regression on existing visual tests
All existing visual compare tests (simple-1, utf8-1, calrgb-1) SHALL
continue to pass below their current diff thresholds.
