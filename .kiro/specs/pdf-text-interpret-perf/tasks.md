# Tasks: Text interpreter performance

## Task 1: Performance-bound regression test (RED) [x]

**File:** `src/reader/text_perf_wbtest.mbt` (new)

1. Add test `"local-fixture page 5 text_program time bound"`
   that:
   - Skips if `<local-fixture>` absent
   - Opens the PDF, calls `page.text_program` for page 5
     (zero-index 4)
   - Uses `@env.now_ms()` to measure elapsed time
   - Asserts `elapsed_ms < 3000`
2. Same for pages 5, 7, 8 (zero-index 5, 7, 8) with same bound.

This test FAILS on HEAD. Commit the RED test with a clear message.

## Task 2: Diagnostic instrumentation [x]

**File:** `src/text/interpreter.mbt`

1. Add a test-visible Ref `text_interpret_phase_ms : Ref[Array[(String, Double)]]`
   accumulator (use `#when(test)` or a test-private module helper).
2. In `interpret_text`, timestamp each of:
   - overall `parse_decoded_content` (already in reader::text.mbt)
   - overall `interpret_text` loop
   - per-operator-kind time via a small Map[String, Double] counter
3. Add a second test that calls the diagnostic and prints the
   breakdown for local-fixture page 5. No assertion — this
   is the evidence.
4. Keep the instrumentation in a compile-time or test-only path
   so production pays no runtime cost.

## Task 3: Analyse diagnostic output [x]

After Task 2 runs, read the printed breakdown. Identify which
phase or operator accounts for the 42-second page 5 time.
Document the observation in
`.kiro/specs/pdf-text-interpret-perf/diagnostic-output.md`.

Candidate hypotheses (see design.md §"Likely hot spots"): H1 font
resolution per glyph, H2 ToUnicode CMap linear scan, H3 per-glyph
Array allocations, H4 state copy on StateChanged.

## Task 4: Apply the fix [x]

Exactly one of H1/H2/H3/H4 (or a newly identified one) becomes
the target. Implement the minimal change:

- H1: cache font state in the interpreter, invalidate on `Tf`
- H2: index CMap ranges, binary-search or O(1) lookup
- H3: hoist scratch Arrays to the interpreter scope
- H4: StateChanged delta emission or snapshot ID

Add unit tests for the specific path changed so the correctness
is preserved.

## Task 5: Tighten the regression bound [x]

Once Task 4 lowers runtime, update Task 1's assertion from
`< 3000` per page to a tighter bound that reflects the new time
plus a small slack (e.g. `< 800 ms`). This guards future
regressions.

## Task 6: Verification [x]

1. `moon test --target native` — all tests pass (724+ including
   new regression + diagnostic)
2. `moon build --target wasm-gc --release && cp _build/wasm-gc/release/build/src/npm/npm.wasm npm/dist/pdf.wasm`
3. Node profile on local-fixture all 76 pages:

```bash
node --experimental-wasm-stringref --experimental-wasm-imported-strings -e "
const { PdfDocument } = await import('./npm/index.mjs');
const { readFile } = await import('node:fs/promises');
const doc = await PdfDocument.open(await readFile('<local-fixture>'));
let max = 0;
for (let i = 0; i < doc.pageCount(); i++) {
  const t0 = Date.now();
  doc.pageToSvgDeferred(i);
  const dt = Date.now() - t0;
  max = Math.max(max, dt);
  if (dt > 2000) console.log('SLOW page ' + (i+1) + ': ' + dt + 'ms');
}
console.log('max: ' + max + 'ms');
"
```

Acceptance: every page < 2,000 ms, max < 2,000 ms.

4. local-fixture pages 4–7 no regression beyond 10 %
5. Visual harness `assertNoRegression` on local-fixture page 6 / 7 passes

## Task 7: Drift gate [x]

```bash
indexion spec align status .kiro/specs/pdf-text-interpret-perf/requirements.md src/text/ --threshold 0.3 --fail-on drifted
indexion spec align status .kiro/specs/pdf-text-interpret-perf/requirements.md src/reader/ --threshold 0.3 --fail-on drifted
```

Both must exit 0.

## Implementation Notes

- Diagnostic on local-fixture page 6 showed `parse_decoded_content=13 ms`, `interpret_text=528071 ms`, `TJ=528069 ms`, and `font_load_ms=527920 ms` across 3181 font loads.
- The targeted H1 fix caches `RuntimeFont` per font resource name inside `TextInterpreter`; post-fix page 6 was `interpret_text=463 ms`, `font_loads=5`.
- Tightened local-fixture regression guard to `< 800 ms`; verified pages 5/6/8/9 at 552/459/436/446 ms in native tests.
- Wasm profile after rebuild: local-fixture all 76 pages `pageToSvgDeferred`, slow=0, max=157 ms.
