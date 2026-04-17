# Tasks: Per-glyph outline correctness — second pass

## Task 1: Expand harness baselines

**File:** `npm/test/visual_baselines.json`

Use `updateBaseline` once per (fixture, page) to capture current
(broken) local-fixture baselines at the locked pixelmatch
parameters:

- `<local-fixture>:page_4`
- `:page_5`
- `:page_6`

Commit the updated JSON.

## Task 2: Harness regression iteration test

**File:** `npm/test/harness_regression.mjs` (new)

Iterate every entry in `visual_baselines.json`, call
`assertNoRegression` for each. Wire into `npm test`.

This ensures every SDD touching rendering runs through every
fixture's baseline, not just local-fixture.

## Task 3: Diagnostic trace (RED evidence)

**File:** `src/svg/render_wbtest.mbt`

Add `test "diagnostic local-fixture page 6 glyph trace"`
matching design.md §"Diagnostic for local-fixture page 6".
Print glyph resolution details for the first 30 glyphs.

Commit the test + `diagnostic-output.md` with the captured output.

## Task 4: Identify failure mode from diagnostic

Read the diagnostic output. Classify the observed problem:

- A / B / C / D (see design.md §"Candidate failure modes") —
  whichever matches the resolution output

Document the identification in `diagnostic-output.md` before the
fix commit.

## Task 5: Apply minimal fix

Apply the fix in the module responsible for the identified mode:

- A: `cff_sid_to_name`
- B: `parse_cff_charset`
- C: shared `cff_cid_glyph_name` helper
- D: `build_synthetic_cmap` encoding branch for Identity-H

Keep the change scoped. Add a unit test that exercises the fixed
code path.

## Task 6: Verify

1. `moon test --target native` — all tests pass
2. `moon build --target wasm-gc --release && cp _build/wasm-gc/release/build/src/npm/npm.wasm npm/dist/pdf.wasm`
3. `npm test` — harness regression iteration passes (local-fixture + new
   local-fixture baselines)
4. Node profile: local-fixture page 6 rendered PNG shows
   readable English (manual review)
5. Update baselines to the new (better) diff numbers; commit
   the JSON update

## Task 7: Drift gate

```bash
indexion spec align status .kiro/specs/pdf-svg-glyph-correctness-2/requirements.md src/svg/ --threshold 0.3 --fail-on drifted
```

Must exit 0.
