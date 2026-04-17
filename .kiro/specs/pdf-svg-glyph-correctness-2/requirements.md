# SDD Draft: Per-glyph outline correctness — second pass (multi-PDF)

## Problem

After `pdf-svg-glyph-correctness` (first pass) closed the local-fixture
per-glyph resolution on `Handset Power On/Off`, the same class of
bug re-surfaces on a different PDF:
`<local-fixture>`,
page 6.

Visual evidence:

- Reference (pdftoppm): `Precautions for use`, numbered list with
  clear English sentences
- SVG (our renderer): every character is a **wrong shape** (tofu-
  like, even though the paths are not notdef — they are real
  glyph outlines, just of the WRONG glyph index)

This is identical in pattern to the local-fixture first-pass issue:
- layout positions correct
- paths present and drawn
- each glyph resolves to the WRONG CFF charstring

Counter to the first-pass fix (Separation Black hex
`#231F20`), this PDF does not depend on Separation colour space.
The first-pass hypothesis check (A/B/C on local-fixture) did not find any
failure mode active on that PDF because local-fixture's font resolution
was actually correct. The problem on local-fixture was colour. The problem
on local-fixture is glyph resolution, and it was not
exercised.

The project harness (`npm/test/visual_baselines.json`) only tracks
local-fixture page 6 and 7. There is no baseline for local-fixture,
so the regression was invisible.

## Requirements

### Requirement 1: Expand visual harness coverage

#### 1.1: local-fixture baseline
`npm/test/visual_baselines.json` SHALL include diff numbers for
<local-fixture> pages 4, 5, 6 (zero-indexed) at
the locked pixelmatch parameters. These become regression oracles
alongside local-fixture.

#### 1.2: Multiple fixtures in harness workflow
SDDs claiming visual improvements SHALL run `assertNoRegression`
against every entry in `visual_baselines.json`, not just local-fixture.
The locked harness already supports this; enforce via a test that
iterates the baselines.

### Requirement 2: Diagnostic for local-fixture page 6

#### 2.1: Glyph trace on the failing page
A whitebox test SHALL trace, for the first 20 glyphs of
local-fixture page 6's first text span, the following:
- character code / CID
- font name (e.g. "F1", "C0_0")
- resolved glyph_id
- post table name at that gid (if present)
- outline first MoveTo coordinate
- expected Unicode character (from ToUnicode CMap)

Output format identical to the local-fixture diagnostic so operators can
compare.

#### 2.2: Cross-check against a trusted source
The expected glyph_id / first-point values SHALL be derived once
from an external reference (fontTools, poppler's `pdftoppm -glyph`
output, or manual inspection of the CFF tables), committed as a
static fixture array in the test, and asserted against the
runtime resolution.

### Requirement 3: Root-cause fix

#### 3.1: Targeted fix based on diagnostic
The fix SHALL target whichever stage of the resolution chain the
diagnostic identifies. Likely candidates (same as first pass):

- A: synthetic cmap misses Adobe Standard Strings
- B: CFF charset format 1/2 off-by-one
- C: post name padding mismatch (wrapper vs renderer)
- D (new): Type0 composite font with CID CMap that maps through
  Identity-H → raw CID, but the CFF wrapper treats the font as
  Type1C (wrong charset interpretation)

D is new since the first pass specifically looked at CID-keyed
(C0_0, C0_1) fonts on local-fixture. local-fixture may use different
composition that the wrapper mishandles.

#### 3.2: Fix applies to both PDFs
After the fix, `assertNoRegression` against both local-fixture and
local-fixture baselines SHALL pass. If the fix moves the
local-fixture baseline (typically improving it), update the baseline in
the same SDD commit.

### Requirement 4: Acceptance criteria

#### 4.1: local-fixture page 6 diff under 15 %
At the locked pixelmatch parameters, the full-page diff on
local-fixture page 6 SHALL be under 15 %. This is
significantly above the local-fixture targets because the page has dense
prose, but the current state (mostly tofu) is around 50–80 %. A
correct-glyph render brings it down to roughly font-rendering AA
noise.

The exact initial baseline SHALL be measured and committed with
the SDD so the "15 % acceptance" is a falsifiable number.

#### 4.2: Visible English text
Manual inspection of the rendered PNG SHALL show recognisable
English words matching the source PDF. A human reviewer SHALL
read text like "Precautions for use", "SoftBank", "network", etc.
This is a qualitative gate: the acceptance is about rendering
correctness, not just pixel diff.

#### 4.3: No regression on local-fixture
local-fixture page 6 and 7 diffs SHALL NOT regress beyond 10 % of their
current baselines (`0.1612` / `0.2145`).

#### 4.4: No regression on tests
`moon test --target native` tests SHALL continue to pass.
