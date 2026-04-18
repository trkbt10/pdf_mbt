# Design: Page clip regression hiding right-column text

## Overview

Diagnose why `clip-path="url(#c2)"` on every `<text>` element on
local-fixture page 2 hides the right column entirely,
identify whether the clipPath definition is inverted or the
clip-rule interpretation is wrong, apply a minimal fix, and add
the TOC page to harness baselines so a regression can't silently
re-hide a column again.

## Expand harness coverage to TOC page

Expand harness coverage to the Table of Contents page by adding
`<local-fixture>:page_2` to
`npm/test/visual_baselines.json` at the locked pixelmatch
parameters. A manual visibility test SHALL additionally assert
that the rendered PNG has a non-zero count of dark pixels in a
known right-column region (x > 270, y 50..800), proving the
column is not covered by a white clip or invisible fallback.

## Diagnostic plan

1. **Snapshot comparison**: render page 2 SVG on current HEAD and
   on the commit before `7d702a2` (clip in page space). Diff the
   clipPath and clip-path attribute distributions.

2. **Geometric check**: for clip rect `c2`
   (271.05, 43.71) – (581.01, 832.8):
   - path is `M 271.05 832.8 L 581.01 832.8 L 581.01 43.71 L 271.05 43.71 Z`
   - points in order: (271.05, 832.8), (581.01, 832.8),
     (581.01, 43.71), (271.05, 43.71)
   - this traverses **counter-clockwise** in SVG y-down space
     (starting top-right, going right, then up, then left, then
     down)
   - evenodd fill should still fill this single-subpath rect

3. **rsvg-convert test**: write a minimal SVG file containing
   only the clipPath c2 and a single `<text>` inside its range,
   render through rsvg-convert, observe whether the text appears.

If step 3 shows text IS visible for a single isolated case, the
bug is NOT in the clipPath geometry but in how multiple clip
contexts interact (e.g. nested `<g clip-path>` wrapping that
prevents the text from entering the clip).

## Candidate root causes

### C1: Coordinate system flip missing in clipPath

PDF content streams produce clip paths in PDF user space (Y up
from bottom). The SVG renderer flips all other geometry to SVG
top-down via `page_height - y`. If clipPath emission skips the
flip, the `c2` path encodes PDF coordinates verbatim, which maps
to a region that excludes the actual text positions (which ARE
SVG-flipped).

Check: are `c2`'s corners (271.05, 43.71) – (581.01, 832.8) the
SVG-space coordinates of the right column, or the PDF bottom-up
ones? A page height of 841.92 and a text at y=53.78 would in PDF
be at y ≈ 788, well outside the clip range. If the text is
SVG-flipped (53.78) and the clip is PDF-original (43.71 – 832.8)
in reversed Y convention, the intersection becomes degenerate.

### C2: Clip hierarchy from parent `<g>` elements

If the text elements are nested inside a `<g>` that already has
`clip-path`, adding another `clip-path` on the text itself forms
an intersection. If one layer is correct and the other is
inverted, nothing shows.

### C3: The fix from 7d702a2 leaks clip-path onto text

The glyph-correctness-2 fix wrapped glyph `<path>` elements in
`<g clip-path=...>` to get page-space clipping. If the same
wrapping was accidentally also applied around `<text>` fallback
elements (which are already in page space because they use a
transform matrix that maps to page coordinates), the `<text>`
gets clipped by a region meant for font-unit glyphs — and the
font-unit clip rect almost certainly excludes the page-space
text position.

C3 is the most likely root cause given the regression timing.

## Fix sketch

If C3: guard the glyph-correctness-2 wrapping to apply ONLY when
emitting glyph `<path>` elements (transformed by font-unit
matrix). For `<text>` fallback elements (which already emit their
own `transform="matrix(...)"` in page space), apply `clip-path`
directly on the element without the `<g>` wrapper.

If C1: add the Y-flip to clipPath geometry at emission time —
currently `svg_clip_path_data` (or equivalent) must compute
`page_height - y` for each Y coordinate in the clip path.

## Files to modify

- `src/svg/render.mbt`: branch in clip-path emission (glyph path
  wrapper vs text direct) OR fix clipPath Y-flip
- `src/svg/render_wbtest.mbt`: regression test for "text inside
  clip rect renders visible pixels"
- `npm/test/visual_baselines.json`: add
  `<local-fixture>:page_2` baseline

## Acceptance verification

1. `moon test --target native` passes with new regression test
2. Wasm rebuild
3. Manual rendering of local-fixture page 2: right column
   visible
4. `assertNoRegression` across all baselines passes
5. drift gate passes
