# SDD Draft: Per-glyph outline correctness against pdftoppm

## Problem

<local-fixture> page 6 pixelmatch diff against pdftoppm is
12.50 % strict (anti-aliasing-tolerant equally 12.50 %). Pages 1-3
with only text show similar per-character colouring in the diff
image, every text glyph tinted red even though the text layout
matches. Pixel shifting the entire SVG in any direction makes the
match worse — at `(dx, dy) = (0, 0)` the diff is minimum, so the
overall layout is correct but each character's outline is different
from what pdftoppm renders.

The expected path when rendering Type1C subset fonts:

1. `decode_composite_font_string` (or simple font equivalent)
   produces a `GlyphIdentifier::CharacterCode(code)` or
   `GlyphIdentifier::GlyphName(name)`
2. `svg_resolve_glyph_id(ttf, glyph)` consults `ttf.cmap` (from the
   CFF-to-OTF wrapper's synthetic charset-aware cmap) to return the
   CFF charstring index for that character
3. `ttf.glyph_outline(gid)` returns the correct outline

If step 2 returns the wrong `gid`, `glyph_outline(gid)` returns a
different character's outline — the glyph renders at the correct
position but with the wrong shape. This matches the observed
symptom: layout preserved, per-character pixel mismatch.

Candidate root causes to investigate by testing:

- **A. Synthetic cmap misses Adobe Standard Strings lookup**: the
  WinAnsiEncoding-to-SID reverse lookup in `build_synthetic_cmap`
  might fail on some glyph names, falling back to identity and
  producing an incorrect mapping.
- **B. CFF charset parsing wrong offset/format for T1_3 / T1_4**:
  if the CFF in T1_3 uses format 1 ranges but `parse_cff_charset`
  returns format 0 data, every glyph ID is offset-by-one or worse.
- **C. post table synthetic names indexed wrong**: if the
  synthetic post produces `cid00001..cidNNNNN` entries but
  `svg_cid_glyph_id` scans with padding mismatch (e.g. "cid1" vs
  "cid00001"), every CID lookup fails silently and falls back to
  `cid` as glyph_id, then the page renders with identity-index
  outlines.

Adobe Technical Note 5176 §18 on CID-keyed and non-CID CFF fonts,
ISO 32000-2 §9.6.6 on encoding resolution, and §9.9 on FontFile
embedding are the applicable sources.

## Requirements

### Requirement 1: Byte-identity per-glyph regression test

#### 1.1: Golden glyph mapping for each local-fixture subset font
A whitebox test SHALL, for each embedded CFF font on local-fixture page 6
(T1_0…T1_5 and C0_0, C0_1), assert that a well-known character
code or CID resolves through the SVG pipeline to the expected
CFF charstring index. The expected indices SHALL be derived once
from a trusted tool (e.g. fontTools or Adobe documentation) and
hard-coded as golden values.

#### 1.2: Byte-identity of glyph outline
For each golden (font, char_code) pair, the test SHALL fetch
`ttf.glyph_outline(resolved_gid)` and assert that:
- the outline is non-empty
- the outline's first `MoveTo` coordinate matches the golden value
  within floating-point tolerance (1e-3)

This catches off-by-one charset mis-indexing without needing to
hash the entire outline.

#### 1.3: cross-check the fallback path does NOT win
The test SHALL verify that the glyph id resolved through
`svg_resolve_glyph_id` differs from the raw `char_code` or `cid`
value when the charset maps a codepoint to a subset-reordered
glyph. Currently identity fallback may silently succeed because
the CFF has an outline at the identity index that happens to be
non-empty.

#### Test harness expectation: End-to-end render verification

#### 2.1: Render golden crop
A whitebox or Node-driven test SHALL render local-fixture page 6, extract a
small fixed crop (e.g. the "Handset Power On/Off" header at
known x/y/width/height), rasterise through rsvg-convert, and
compare against a pdftoppm golden crop of the same region. The
assertion SHALL require the crop's pixelmatch diff to be under a
tighter threshold (e.g. 3 %) than the full-page 12.5 % so a
specific character mis-rendering is detected.

#### 2.2: Text path count parity
For a page with known text layout, the number of `<path>` elements
produced by the SVG renderer SHALL equal the number of glyphs
emitted by pdftoppm (via `pdftotext -layout` or ghostscript
trace). A count mismatch indicates a dropped or doubled glyph
beyond the per-glyph outline mismatch.

### Requirement 3: Acceptance criteria

#### 3.1: Page 6 full-page diff under 5 %
After fixing the root cause(s) identified in Requirement 1, the
local-fixture page 6 full-page pixelmatch diff SHALL drop from 12.50 % to
under 5 %. The fix may need to address more than one of A/B/C if
multiple candidates are confirmed.

#### 3.2: Page 7 full-page diff under 10 %
Page 7 (more images, fewer text glyphs) SHALL drop from 17.47 %
to under 10 %.

#### 3.3: No regression on tests
`moon test --target native` 719+ tests SHALL continue to pass.
Existing CFF-charset whitebox tests SHALL continue to pass.

### Requirement 4: Instrumentation before fix

#### 4.1: Glyph resolution trace
A whitebox test (can be diagnostic-only, like the existing local-fixture
CID chain test) SHALL print, for each character on the page's
"Handset" header, the following table:

```
char_code | glyph_id_resolved | post_name_at_gid | outline_first_point
```

The output distinguishes:
- identity fallback (glyph_id == char_code, post_name == "cidNNNNN")
- charset-correct (glyph_id != char_code, post_name == Adobe
  glyph name like "H" or "a")
- missing-outline (outline empty)

This instrumentation is the evidence base for choosing which of
A/B/C to fix.
