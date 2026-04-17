# SDD Draft: SVG Rendering Precision — Text Metrics

Target: pixel diff < 0.01% against pdftoppm reference at 72 DPI.

## Root Cause Analysis

The current SVG renderer emits `font-size="1"` and encodes the actual font
size into the text element's `transform="matrix(...)"`. This causes:

1. Browser font engines render at 1px then scale — hinting/grid-fitting
   are defeated, producing different glyph shapes than native-size rendering.
2. Character advance widths calculated from PDF font metrics (in
   1/1000-of-text-space units) are placed as tspan x/y coordinates in the
   1-unit coordinate system. When the browser substitutes a local font
   (e.g., Arial for Helvetica), its advance widths differ from PDF metrics,
   causing cumulative drift across long text runs.
3. The combination makes uppercase/lowercase spacing appear uniform when
   the PDF specifies proportional metrics.

ISO 32000-2 §9.4.2 defines the text rendering matrix as:

    T_rm = [T_fs × T_h  0] × T_m × CTM
           [0        T_fs]

where T_fs = font size, T_h = horizontal scaling, T_m = text matrix.

The SVG output must decompose this into font-size (T_fs), transform
(T_m × CTM with Y-flip), and absolute glyph positions (in user-space
points, not 1/T_fs-scaled units).

## Requirements

### Requirement 2: Glyph positioning in absolute coordinates

#### 2.1: Per-character x positions
Each `<tspan>` x attribute SHALL specify the glyph's position in SVG
user-space points (after applying font-size and transform), not in
font-size-relative units.

#### 2.2: Advance width from PDF metrics
Glyph advance positions SHALL be computed from PDF font Width arrays
(§9.6.2), Standard 14 font metrics (Annex A), or embedded TrueType
hmtx/cmap tables — in that priority order. The advance SHALL be:

    tx = (w_glyph / 1000) × T_fs + T_c + T_w(if space)

where w_glyph is in 1/1000 units, T_c = character spacing, T_w = word
spacing, all scaled by T_h.

#### 2.3: TJ array kerning adjustments
TJ array numeric adjustments SHALL be applied as:

    dx = -(adjustment / 1000) × T_fs × T_h

and reflected in the next glyph's x position.

### Requirement 3: Text matrix and CTM interaction

#### 3.1: Non-identity CTM handling
When the CTM contains scaling (e.g., Firefox-style PDFs where font size
is in CTM rather than T_fs), the SVG renderer SHALL extract the effective
font size from the combined rendering matrix, not from T_fs alone.

#### 3.2: Rotated text
When T_m or CTM contains rotation, the SVG transform SHALL preserve the
rotation angle and glyph positions SHALL follow the rotated baseline.

### Requirement 5: Path and shape rendering

#### 5.1: CTM precision
The current transformation matrix SHALL be applied to all path coordinates
without intermediate rounding.

#### 5.2: Stroke attributes
Line width, dash pattern, line cap, and line join SHALL be mapped to SVG
stroke-width, stroke-dasharray, stroke-linecap, and stroke-linejoin
with exact values from the graphics state.

## Test harness expectations (non-tracked)

Items in this section describe visual regression expectations and harness
behaviour for precision validation. They are intentionally below the `###`
tracked requirement heading level, so spec align drift tracking does not treat
them as implementation-surface requirements.

#### SVG font-size SHALL reflect actual PDF font size

##### Font size extraction
The SVG `font-size` attribute on `<text>` elements SHALL be set to the
effective font size (T_fs from ISO 32000-2 §9.4.2), not hardcoded to "1".

##### Transform matrix decomposition
The `transform="matrix(...)"` on `<text>` elements SHALL contain only the
text positioning and orientation (T_m × CTM with PDF→SVG Y-flip), with
font-size scaling factored out into the `font-size` attribute.

##### Horizontal scaling
When the PDF text state specifies `T_h` (horizontal scaling) ≠ 1.0,
the SVG text element SHALL apply it as a separate x-axis scale factor
or via the transform matrix, not baked into font-size.

#### Font family mapping

##### BaseFont to CSS font-family
When the PDF font dictionary specifies BaseFont (e.g., Helvetica,
Times-Roman, Courier), the SVG SHALL use the CSS font-family with
appropriate fallback stack (e.g., "Helvetica, Arial, sans-serif").

##### Embedded font name extraction
For embedded TrueType fonts, the font name SHALL be extracted from the
font's name table and used in the CSS font-family.

#### Colour accuracy

##### Device colour mapping
DeviceGray, DeviceRGB, and DeviceCMYK colours SHALL be converted to SVG
hex colours with correct component mapping.

##### Alpha transparency
The graphics state alpha values SHALL be mapped to SVG fill-opacity and
stroke-opacity attributes.

#### Image positioning accuracy

##### Image transform
The image CTM SHALL be applied as an SVG transform. The 1x1 PDF image
unit square SHALL map correctly to the intended display rectangle.

#### Visual regression gate

##### Pixel diff threshold
SVG rendering SHALL pass pixelmatch comparison against pdftoppm reference
PNGs at 72 DPI with < 0.01% pixel diff for all test fixture PDFs.

##### Test fixture PDFs
- Simple PDF 2.0 (text + shapes): HelloWorld with Helvetica 24pt
- pdf20-utf8-test.pdf (multi-size headings + body text)
- PDF 2.0 CalRGB (text + images in calibrated colour space)
