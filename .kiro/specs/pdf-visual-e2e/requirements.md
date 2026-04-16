# SDD Draft: Visual E2E Testing (Screenshot Diff)

## Requirements

### Requirement 1: Reference rendering pipeline
The test pipeline SHALL generate reference renderings of PDF pages
using an established tool (poppler pdftoppm) as ground truth.

#### 1.1: Reference PNG generation
For each test PDF page, `pdftoppm -png -r 150` SHALL produce a
reference PNG at 150 DPI.

### Requirement 2: SVG-to-PNG pipeline
The library's SVG output SHALL be converted to PNG for comparison.

#### 2.1: SVG rasterization
The SVG string from `pdf_page_to_svg` SHALL be rasterized to PNG
at the same DPI as the reference. Use headless browser (playwright)
or a dedicated SVG rasterizer.

### Requirement 3: Pixel-level comparison
The test SHALL compare the library PNG against the reference PNG
using pixel-level diff.

#### 3.1: Diff metric
Use pixelmatch or similar algorithm. The diff SHALL report:
- Total pixel count
- Differing pixel count
- Diff percentage
- Visual diff image (red overlay on differences)

#### 3.2: Threshold
A page passes if diff percentage is below a configurable threshold
(default: 5%). This allows for minor font rendering differences
while catching layout/positioning/missing-element errors.

### Requirement 4: Automated test suite
The visual E2E tests SHALL run as part of the test suite.

#### 4.1: Test fixture PDFs
Use spec/pdf20examples/ PDFs as fixtures. Do NOT include copyrighted
PDFs. Reference PNGs can be committed to the repo (gitlfs or small).

#### 4.2: CI-compatible
The test SHALL work in CI environments with headless browser support.
When reference PNGs don't exist, generate them first (bootstrap mode).

### Requirement 5: Regression detection
When a code change causes visual regression (diff exceeds threshold),
the test SHALL fail with the diff image saved for review.
