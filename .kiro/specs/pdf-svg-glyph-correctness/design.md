# Design: Per-glyph outline correctness against pdftoppm

## Overview

Diagnose and fix per-character glyph outline mismatch in the SVG
renderer for <local-fixture>. The evidence before this SDD:

- Layout is correct (shift tests show `dx=0, dy=0` is the optimum)
- Text paths are rendered with `<path fill="…"/>` (expected)
- 12.50 % of page 6 pixels differ, scattered on every text glyph
- CFF charset parsing and `svg_cid_glyph_id` were implemented in
  the pdf-svg-cff-charset and pdf-svg-cid-realpath SDDs

Hypotheses A / B / C (see requirements.md §Problem) are all
internal to the character_code → glyph_id resolution chain. This
SDD starts with diagnostic instrumentation (Requirement 4), uses
its output to pick the specific fix, then adds byte-identity
regression tests (Requirement 1) and end-to-end crop tests
(Requirement 2).

## Diagnostic instrumentation first

Before touching any code, add a whitebox diagnostic that traces
every character on the "Handset Power On/Off" header of local-fixture page
6:

```
char_code | glyph_id_resolved | post_name_at_gid | outline_first_point
H         0x48 → gid=43 post="H"  first=(55.0, 0.0)
a         0x61 → gid=18 post="a"  first=(42.0, 13.0)
n         0x6E → gid=25 post="n"  first=(65.0, 0.0)
d         0x64 → gid=21 post="d"  first=(87.0, 0.0)
s         0x73 → gid=30 post="s"  first=(29.0, -12.0)
...
```

If every row shows `post_name == Adobe glyph name`, hypothesis C is
FALSE. If any row shows `post_name == "cidXXXXX"` or empty, the
renderer is falling back to identity lookup — C is TRUE.

The `first_point` of the outline cross-checks against a fontTools
extraction of the same CFF. Mismatch = A or B.

## Suspected fix patterns by hypothesis

### A (cmap gap)

`build_synthetic_cmap` iterates WinAnsi codepoints 0-255 and maps
to the first glyph_id whose charset-resolved name matches. If
Adobe Standard Strings lookup fails (e.g. SID > 390 and String
INDEX read returns "") the name matching silently fails and the
codepoint gets no cmap entry → SVG fallback to identity lookup at
char_code.

Fix: audit `cff_sid_to_name` and confirm that SIDs >= 391 read
from String INDEX correctly. Add a unit test with a known CFF's
SID 391+ entry.

### B (charset format mis-parse)

`parse_cff_charset` dispatches on charset format byte (0 / 1 / 2).
An off-by-one in Format 1 range decoding would shift every glyph
by one.

Fix: add a unit test that exercises Format 1 with a known range
sequence and asserts the resulting CID / SID array element-by-
element.

### C (post name padding mismatch)

`build_synthetic_post` in `cff_wrapper.mbt` produces names, and
`svg_cid_glyph_id` in `render.mbt` scans them. A zero-padding
mismatch (e.g. wrapper emits `"cid1"` vs renderer looks up
`"cid00001"`) makes every CID lookup silently fail.

Fix: share a single `cff_cid_glyph_name(cid: Int) -> String`
helper between wrapper and renderer. The pdf-svg-cid-charset SDD
already discussed this pattern.

## Test compensation

Tests are written first (TDD). If the diagnostic output from
Requirement 4 reveals a specific hypothesis, the test assertions
are set to the values produced by a trusted external tool
(`fontTools.ttLib` via a one-shot Python helper, or pdftoppm
tracing output).

### Per-glyph byte-identity test

For a small hand-picked set (e.g. 5 characters from T1_3 "Handset"
+ 2 characters from C0_0 CID font):

```moonbit
let cases = [
  ("T1_3", 0x48, 43, (55.0, 0.0)),   // H
  ("T1_3", 0x61, 18, (42.0, 13.0)),  // a
  ("T1_3", 0x6E, 25, (65.0, 0.0)),   // n
  ...
]
for (font_name, char_code, expected_gid, expected_first) in cases {
  let gid = resolve_glyph_id_for(page=5, font_name, char_code)
  assert_eq(gid, expected_gid)
  let outline = ttf.glyph_outline(gid)
  let first = first_move_point(outline)
  assert_double_near(first.x, expected_first.0, 1e-3)
  assert_double_near(first.y, expected_first.1, 1e-3)
}
```

### Crop pixelmatch test

Render page 6, crop the "Handset Power On/Off" rectangle (a fixed
region in pixel coordinates), rasterise, pixelmatch against a
pdftoppm-generated crop of the same rectangle. Assertion: crop
diff < 3 %. This is tighter than the full-page 12.5 % so a
mis-rendered single character bumps the crop diff visibly.

## Files to modify

- `src/svg/render_wbtest.mbt` — diagnostic instrumentation test
  (R4), per-glyph byte-identity test (R1)
- `src/svg/cff_wrapper.mbt` and/or `src/svg/cff_charset.mbt` —
  fix whichever of A/B/C the diagnostic identifies
- `npm/test/visual_crop.mjs` (new) — end-to-end crop pixelmatch
  (R2.1) if required for the acceptance threshold

## Acceptance verification

1. `moon test --target native` — all tests pass (adds diagnostic +
   per-glyph + crop tests, 7 new tests total)
2. Rebuild wasm, Node profile unchanged (this SDD does not touch
   the hot path)
3. local-fixture page 6 pixelmatch diff under 5 % (was 12.50 %)
4. local-fixture page 7 pixelmatch diff under 10 % (was 17.47 %)
