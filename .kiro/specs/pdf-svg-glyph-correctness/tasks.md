# Tasks: Per-glyph outline correctness

## Task 1: Diagnostic instrumentation (Requirement 4)

**File:** `src/svg/render_wbtest.mbt`

Add `test "diagnostic local-fixture page 6 Handset header glyph trace"`:

1. Skip if fixture not present
2. Open local-fixture, get page 5 text events
3. Locate the "Handset Power On/Of" span
4. For each glyph in that span, print:
   - char_code (hex)
   - resolved glyph_id through `svg_resolve_glyph_id`
   - post-table name at the resolved glyph_id (via
     `ttf.glyph_name(gid)` or Array lookup)
   - outline's first `MoveTo` point (x, y)

Output prefix with `diagnostic local-fixture glyph_trace:` so it's greppable.
Do NOT assert — this is the evidence gathering step.

## Task 2: Run diagnostic and analyse

Run:

```bash
moon test --target native -p trkbt10/pdf/src/svg 2>&1 | grep "diagnostic local-fixture glyph_trace"
```

Record the output. Expected analysis:

- If every row shows `post_name == Adobe_glyph_name` → hypothesis C is
  FALSE, investigate A or B by cross-checking against fontTools.
- If any row shows `post_name == "cidNNNNN"` → hypothesis C is TRUE,
  fix the name format mismatch between wrapper and renderer.
- If outline `first` points don't match fontTools' output → hypothesis
  A (cmap gap) or B (charset parse bug).

## Task 3: Per-glyph byte-identity test (Requirement 1)

**File:** `src/svg/render_wbtest.mbt`

Add `test "local-fixture page 6 per-glyph outline golden"`:

1. Build a Python helper (or inline a fontTools CLI invocation in
   the test setup) to extract golden `(font_name, char_code,
   expected_gid, expected_first_point)` tuples from local-fixture's CFF
   fonts. Commit the resulting Array as a static fixture so the
   test does not need Python at runtime.
2. Assert each pair matches through `svg_resolve_glyph_id` and
   `ttf.glyph_outline` as documented in design.md § "Per-glyph
   byte-identity test".
3. If building the Python helper is impractical, fall back to
   generating the fixture once by running the diagnostic of Task 1
   on the current implementation, then hardening the known-good
   rows as the golden set while fixing only the known-bad rows.

## Task 4: Apply the root-cause fix

Depending on Task 2's analysis, apply one of:

**4a (hypothesis A)**: Fix `cff_sid_to_name` to correctly handle
SIDs >= 391 through the CFF String INDEX. Add a unit test with a
known SID 391+ lookup.

**4b (hypothesis B)**: Fix `parse_cff_charset`'s Format 1 or
Format 2 range decoder. Add a unit test with a known Format 1
range that exercises the specific bug.

**4c (hypothesis C)**: Introduce a single
`cff_cid_glyph_name(cid: Int) -> String` helper in
`cff_charset.mbt`, used by both `build_synthetic_post` (wrapper
side) and `svg_cid_glyph_id` (renderer side). Remove any duplicate
name-formatting code.

All three fixes have pre-existing candidate code in
`src/svg/cff_charset.mbt`, `src/svg/cff_wrapper.mbt`, and
`src/svg/render.mbt`.

## Task 5: Crop pixelmatch test (Requirement 2.1)

**File:** `npm/test/visual_crop.mjs` (new)

Render local-fixture page 6 in Node, crop the "Handset Power On/Off" rect
(approximately x=185, y=20, width=130, height=20 at 72 DPI),
rasterise through rsvg-convert, compare against a pdftoppm
`-x 185 -y 20 -W 130 -H 20` crop.

Assertion: crop pixelmatch diff < 3 %.

Wire into `npm test` if not already via a test runner update.

## Task 6: Verification

1. `moon test --target native` — all tests pass (adds ~7 new)
2. `moon build --target wasm-gc --release && cp _build/wasm-gc/release/build/src/npm/npm.wasm npm/dist/pdf.wasm`
3. Node full-page pixelmatch:
   - Page 6 diff < 5 % (was 12.50 %)
   - Page 7 diff < 10 % (was 17.47 %)

If the first fix doesn't achieve the acceptance threshold, loop
back to Task 2 with the new diagnostic output — the remaining gap
likely points to a second hypothesis from A/B/C.

## Task 7: Drift gate

```bash
indexion spec align status .kiro/specs/pdf-svg-glyph-correctness/requirements.md src/svg/ --threshold 0.3 --fail-on drifted
```

Must exit 0.
