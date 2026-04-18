# Tasks: Page clip regression

## Task 1: Add page 2 baseline

**File:** `npm/test/visual_baselines.json`

Run `updateBaseline` for
`<local-fixture>`
page_2, commit. This captures the current (broken) state.

## Task 2: Minimal SVG reproduction

**File:** `npm/test/clip_repro.mjs` (new)

Write a standalone SVG with:
- `<rect>` white background
- `<defs><clipPath id="c2"><path d="M 271.05 832.8 ... Z" clip-rule="evenodd"/></clipPath></defs>`
- `<text clip-path="url(#c2)" transform="matrix(1 0 0 1 278 54)"><tspan>Test</tspan></text>`

rsvg-convert the file, check if the text appears. If it appears,
the bug is not the clipPath geometry — it's in the interaction
between the text element and other SVG structure around it
(nested `<g>`, ordering, etc).

Commit the repro. This is the RED isolation test.

## Task 3: Diagnostic comparison

Render page 2 SVG at HEAD and at commit `dacefdc` (pre-fix).
Save both outputs in a diagnostic directory. Diff the structure.
Record which clip-path emissions changed between the two versions.

Document findings in
`.kiro/specs/pdf-svg-page-clip-regression/diagnostic-output.md`.

## Task 4: Fix the regression

Based on Task 2 (geometry works in isolation?) and Task 3
(what changed), choose:

- If glyph-correctness-2's `<g clip-path>` wrapper is leaking onto
  `<text>` elements: narrow the wrapping condition to apply only
  when emitting glyph `<path>` elements that are transformed in
  font-unit space
- If clipPath Y-flip is missing: add the flip to clip path
  emission

Keep the fix minimal and targeted.

## Task 5: Whitebox regression test

Add a whitebox test that, for a synthetic PDF with a clip rect
covering the right half of the page and text inside it, asserts
the rendered SVG DOES emit text elements inside the clip region
without a `<g>` wrapper that would re-clip them.

Or, add a more direct test: render the SVG, rsvg-convert, check
PNG pixel darkness in a specific rect of the image.

## Task 6: Update baseline and verify

Re-run `updateBaseline` for
`<local-fixture>:page_2` after the fix. Expect
the diff to DROP (not stay the same). Commit the updated
baseline.

Run `npm test` — harness_regression iterates every baseline
and passes.

## Task 7: Drift gate

```bash
indexion spec align status .kiro/specs/pdf-svg-page-clip-regression/requirements.md src/svg/ --threshold 0.3 --fail-on drifted
```

Must exit 0.

## Task 8: Final acceptance

1. Render page 2 manually → right column visible
2. `moon test --target native` passes
3. `npm test` passes (full baseline iteration)
4. No regression on local-fixture page 6/7 or local-fixture page 4/5/6
