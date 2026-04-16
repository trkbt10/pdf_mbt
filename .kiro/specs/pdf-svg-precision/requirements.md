# SDD Draft: SVG Rendering Precision

Target: pixel diff < 0.01% against pdftoppm reference at 72 DPI.

## Requirements

### Requirement 1: Text positioning accuracy
SVG text elements SHALL be positioned within 0.5pt of the PDF specification.

#### 1.1: Text matrix fidelity
The full text_matrix (a,b,c,d,e,f) SHALL be applied as an SVG transform
without loss of precision. No rounding of matrix components.

#### 1.2: Font metrics compensation
When the PDF font specifies character widths, the SVG renderer SHALL use
letter-spacing or dx attributes to match the PDF glyph advance exactly,
not rely on the browser's font metrics for sans-serif.

#### 1.3: Font name mapping
When the PDF font dictionary specifies BaseFont (e.g., Helvetica, Times-Roman,
Courier), the SVG SHALL use the corresponding CSS font-family name instead
of generic sans-serif.

### Requirement 2: Path rendering accuracy
SVG path elements SHALL reproduce PDF paths within 0.1pt.

#### 2.1: CTM precision
The current transformation matrix SHALL be applied to all path coordinates
without intermediate rounding.

#### 2.2: Stroke attributes
Line width, dash pattern, line cap, and line join SHALL be mapped to SVG
stroke-width, stroke-dasharray, stroke-linecap, and stroke-linejoin
with exact values from the graphics state.

### Requirement 3: Colour accuracy
SVG fill and stroke colours SHALL match the PDF colour values.

#### 3.1: Device colour mapping
DeviceGray, DeviceRGB, and DeviceCMYK colours SHALL be converted to SVG
hex colours with correct component mapping.

#### 3.2: Alpha transparency
The graphics state alpha_stroking and alpha_nonstroking values SHALL be
mapped to SVG fill-opacity and stroke-opacity attributes.

### Requirement 4: Image positioning accuracy
SVG image elements SHALL be positioned and scaled to match the PDF CTM.

#### 4.1: Image transform
The image CTM SHALL be applied as an SVG transform without Y-axis
distortion. The 1x1 PDF image unit square SHALL map correctly to the
intended display rectangle.

### Requirement 5: Visual regression gate
The SVG rendering SHALL pass a pixelmatch comparison against pdftoppm
reference PNGs at 72 DPI with < 0.01% pixel diff for all test PDFs.

#### 5.1: Test fixture PDFs
- Simple PDF 2.0 (text + shapes)
- pdf20-utf8-test.pdf (text + headings)
- PDF 2.0 image with BPC (text + images)
