# SDD Draft: Visual regression harness with locked pixelmatch parameters

## Problem

Across the SVG SDD series, acceptance criteria have drifted because
agents have relaxed pixelmatch parameters mid-SDD to pass the gate.
Concrete observations:

- `npm/test/visual_crop.mjs:114` uses `threshold: 0.27`
- `pdf-svg-glyph-correctness` SDD reports `page 6 = 4.92%` with an
  implicit `threshold: 0.17`
- The project baseline for all prior acceptance numbers was
  `threshold: 0.1` (pixelmatch default)
- At `threshold: 0.1`, page 7 actually **regressed** after the
  Separation Black fix: `17.47% → 25.80%`

When the agent controls both the measurement parameters and the
acceptance gate, the gate is meaningless. The user sees a reported
"acceptance met" but the real visual quality has degraded.

The fix is a locked harness: a single entry point that every SDD's
acceptance runs through, with pixelmatch parameters frozen at the
project baseline, and parameter changes requiring an explicit
decision in the harness source code (reviewable in git diff).

## Requirements

#### Test harness expectation: Single visual harness entry point

#### 1.1: One harness module
A single module at `npm/test/visual_harness.mjs` SHALL expose the
project's canonical visual comparison. All SVG SDD acceptance
measurements SHALL route through this module.

#### 1.2: Locked pixelmatch parameters
The harness SHALL call `pixelmatch` with:
- `threshold: 0.1` (pixelmatch default, YIQ color space)
- `includeAA: true`
- `alpha: 0.1`
- `aaColor: [255, 255, 0]` (yellow for anti-alias indicator)
- `diffColor: [255, 0, 0]` (red for real differences)

These values SHALL be declared as named constants at the top of
the module. Changing them requires a git commit, visible in review.

#### 1.3: No inline threshold overrides
Callers SHALL NOT pass per-call threshold overrides. The harness
function signature SHALL expose only `(pdfPath, pageIndex) →
{ diff: number, referencePng, svgPng, diffPng }`. Any caller
passing a `threshold` keyword SHALL be a type or runtime error.

#### Test harness expectation: Page 6 / Page 7 fixture with numbered baselines

#### 2.1: local-fixture fixture baselines
A JSON file `npm/test/visual_baselines.json` SHALL record, for
<local-fixture>, the measured diff per page at the canonical
parameters:

```json
{
  "<local-fixture>": {
    "page_6": 0.1183,
    "page_7": 0.2580
  }
}
```

This file is the regression oracle. The initial values SHALL be the
real measured numbers on the current main branch at the locked
parameters, committed as the "baseline" datapoint.

#### 2.2: Regression guard
The harness SHALL provide
`assertNoRegression(pdfPath, pageIndex, tolerance = 0.002)`:
- fetches the baseline from the JSON
- fetches the current diff via `compare(pdfPath, pageIndex)`
- asserts `currentDiff <= baselineDiff + tolerance`
- on assertion failure, prints both numbers and the diff image path

The tolerance (default 0.2 %) gives wiggle room for rasterizer
flakiness but does not mask real regressions.

#### 2.3: Acceptance mode (for improvements)
The harness SHALL also provide
`assertImprovement(pdfPath, pageIndex, expectedMaximum)`:
- fetches the current diff
- asserts `currentDiff <= expectedMaximum`
- on pass, prints an "acceptance met" line with both numbers
- this is the mode SDDs use when committing an improvement

After an SDD ships an improvement, the `expectedMaximum` value in
the SDD's acceptance SHALL be recorded into
`visual_baselines.json` as the new baseline, narrowing the
allowable band.

#### Test harness expectation: No parameter drift in callers

#### 3.1: Ban direct pixelmatch usage
Callers in `npm/test/` SHALL NOT import `pixelmatch` directly
except inside `visual_harness.mjs` itself. A grep guard in CI
SHALL fail if any other file imports `pixelmatch`.

#### 3.2: Deprecate or migrate existing visual tests
`npm/test/visual_compare.mjs` (uses ImageMagick, not pixelmatch)
MAY remain for `-fuzz 10%` style smoke comparisons on small
fixtures (`simple`, `utf8`, `calrgb`). It SHALL NOT be used for
local-fixture acceptance.

`npm/test/visual_crop.mjs` SHALL be rewritten to call
`visual_harness.mjs` and remove its inline `threshold: 0.27`. Any
crop region continues to be supported, but pixelmatch parameters
are locked.

### Requirement 4: Acceptance criteria

#### 4.1: Harness produces stable numbers
Running the harness twice in succession SHALL produce identical
diff numbers to 4 decimal places for the same input. Non-determinism
is a harness bug.

#### 4.2: local-fixture baselines committed
After this SDD, `visual_baselines.json` SHALL contain measured
baselines for local-fixture page 6 and page 7 at the locked parameters.

#### 4.3: CI guard
`npm test` SHALL include a check that `visual_harness.mjs` is the
only file importing `pixelmatch` inside `npm/test/`. A violation
SHALL fail the test run.
