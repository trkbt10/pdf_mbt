# SDD Draft: Page clip regression hiding right-column text

## Problem

`<local-fixture>` page 2 (the Table of Contents
page) renders in the SVG output as if the right column is empty.
The reference (pdftoppm) shows a two-column layout: left column
has "SoftBank Settings / Instruction Manual / Table of Contents",
right column has the full TOC listing ("Read Me ... 4", "Using
SoftBank Settings ... 7", "About This Application ... 7", etc).

Analysis of the generated SVG:

- 2,059 `<text>` elements are emitted (one per glyph)
- Text content includes "Read Me", "Using SoftBank", "Connecting",
  etc — the data is present in the DOM
- Almost every text element carries `clip-path="url(#c2)"`
- `c2` is defined as:
  ```
  <path d="M 271.05 832.8 L 581.01 832.8 L 581.01 43.71 L 271.05 43.71 Z" clip-rule="evenodd"/>
  ```
- The clipPath Y range `43.71 → 832.8` covers almost the whole
  page height
- The text Y coordinates (53.78, 101.06, ...) fall inside that
  range

Despite the text being inside the clip region, rsvg-convert
renders NOTHING in the right column. A subset of path elements
that draw white rectangles over the same region appear BEFORE the
text in document order — they may not be the cause (SVG paints
later elements above earlier ones) but they coincide with the
missing text area.

The first page of the document renders correctly (fonts, text,
layout). Starting from page 2 the right column is blank. This is
a regression introduced by the `pdf-svg-glyph-correctness-2`
clip-path fix which wraps clipped glyph paths in
`<g clip-path="url(#cN)">` containers — the same wrapper is now
applied to `<text>` fallback elements and the clip rectangles
themselves are already at top-level. The harness baselines
improved on local-fixture page 6 but the TOC page was never
in the baselines.

## Requirements

### Requirement 1: Expand harness coverage to TOC page

#### 1.1: Page 2 baseline
`visual_baselines.json` SHALL include
`<local-fixture>:page_2` at the locked pixelmatch
parameters. The baseline captures the current (broken) state.

#### 1.2: Manual visibility test
A new test (Node script with real rsvg-convert + human-readable
assertion via string match on rendered PNG OCR or layout bounding
box) SHALL assert that the right column has *some* non-white
pixels. Fail on the current broken state.

Alternative: assert the SVG output's rendered PNG has a non-zero
count of dark pixels in a known right-column region
(x > 270, y 50..800). This proxy for "text is visible" is
mechanically checkable without OCR.

### Requirement 2: Diagnose the clip-path regression

#### 2.1: Compare SVG clip output before and after clip-fix commit
A diagnostic SHALL:
- checkout commit `dacefdc` (immediately before clip fix `7d702a2`)
- render local-fixture page 2 SVG, grep clipPath output
- checkout HEAD, render same
- diff the two SVGs' clipPath and clip-path attribute assignments

Record which attribute assignments changed and on which element
types.

#### 2.2: Identify clip-rule / path-direction mismatch
The diagnostic SHALL also report:
- the Y-axis orientation of each clipPath subpath (increasing vs
  decreasing)
- whether SVG fill-rule evenodd on the current path direction
  gives "inside" or "outside"

If the clip path direction is wrong (e.g. PDF bottom-up stored
verbatim without flipping for SVG top-down), the clip region
excludes the intended area.

### Requirement 3: Fix the clip regression

#### 3.1: Text clip-path must not hide visible content
`<text>` elements inside the page-default clip region MUST render
visibly. The SVG renderer SHALL NOT emit clip-path attributes
that cause text to disappear when the clip rectangle and the text
position are both inside the page.

#### 3.2: Clip-rule stays consistent
If the fix requires changing `clip-rule` from `evenodd` to
`nonzero`, the change SHALL apply uniformly to all clipPath
emissions to keep clip semantics consistent.

#### 3.3: Backward compatibility with glyph-correctness-2
The clip-path wrapping that glyph-correctness-2 applied to glyph
`<path>` elements (wrapping in `<g clip-path=...>` so clip is in
page space) SHALL remain functional. The fix addresses only the
clipPath definition or how it applies to `<text>` fallback
elements.

### Requirement 4: Acceptance

#### 4.1: Page 2 right column visible
Manual review: rendered local-fixture page 2 SHALL show
"Read Me", "Using SoftBank Settings", and subsequent TOC
entries.

#### 4.2: assertNoRegression passes for all baselines
The harness iterates every baseline entry; all SHALL pass.
Updates to baselines SHALL reflect the corrected rendering.

#### 4.3: No regression on existing fixtures
local-fixture page 6 / 7 baselines unchanged or improved.
local-fixture page 4, 5, 6 baselines unchanged or improved.
