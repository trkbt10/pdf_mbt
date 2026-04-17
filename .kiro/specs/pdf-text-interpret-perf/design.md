# Design: Text interpreter performance on large PDFs

## Overview

Instrument `src/text/interpreter.mbt` (and related modules) to
expose per-phase and per-operator timing for a single-page text
interpretation. Profile `<local-fixture>` page 5
(42 s). Use the evidence to identify the actual hot spot. Fix the
specific bottleneck without speculative refactoring.

## Diagnostic approach

### Per-phase timing

Add optional timing probes inside `PdfPage::text_program` (reader
side) and `interpret_text` (text side):

```moonbit
// Test-only: expose accumulated timings through a module-local Ref
#when(test)
pub let text_interpret_phase_ms : Ref[Array[(String, Double)]] = { val: [] }

#when(test)
pub fn text_interpret_phase_reset() -> Unit {
  text_interpret_phase_ms.val = []
}

fn text_interpret_phase_record(name : String, ms : Double) -> Unit {
  text_interpret_phase_ms.val.push((name, ms))
}
```

Within `interpret_text`, wrap main phases:

```moonbit
let parse_t0 = @env.now_ms()
let parsed = parse_decoded_content(...)
text_interpret_phase_record("parse", @env.now_ms() - parse_t0)

let interp_t0 = @env.now_ms()
for op in parsed {
  match op { ... }
}
text_interpret_phase_record("interpret", @env.now_ms() - interp_t0)
```

### Per-operator breakdown

Inside the operator switch, count by operator kind. For the slow
cases (Tj, TJ, T*, etc.), further measure time-per-invocation.

### Find the quadratic

If totals are, e.g., `parse=100 ms, interpret=42,000 ms`, then the
bottleneck is in the interpreter loop. Per-operator counts combined
with wall-clock reveal whether it's 3,000 Tj calls each taking
14 ms (per-call bug) or 3,000 Tj calls with cumulative O(n²) work
(index bug).

## Likely hot spots (hypotheses — confirm via diagnostics)

### H1: Font resource resolution per glyph

The interpreter may look up the current font's FontDescriptor /
Encoding / ToUnicode CMap for every glyph even though the font
doesn't change within a span. Each lookup might walk the resources
dictionary linearly.

Fix: cache the resolved font state when `Tf` (set font) fires,
reuse until the next `Tf`.

### H2: ToUnicode CMap linear scan per character

If `map_source_code` walks an Array of ranges linearly, a ToUnicode
CMap with many ranges makes every character code O(n), the span
O(n × chars) = quadratic.

Fix: pre-sort ranges once, use binary search; or build a dense
lookup array when ranges are small.

### H3: Per-glyph Array allocations

Each glyph decode allocates temporary Arrays (character bytes,
decoded codepoints, component doubles). At 3,000 glyphs × N
allocations per glyph × small-array re-growth, the GC/allocation
cost dominates.

Fix: hoist temporaries to the interpreter scope, reuse across
iterations.

### H4: State copy on every StateChanged

`GraphicsState::copy()` may deep-copy resources. If the interpreter
emits a StateChanged event per Tj/TJ, the copy cost is quadratic.

Fix: make StateChanged carry only the delta, or use a snapshot ID
so consumers can decide whether to refresh.

The diagnostic narrows to one of H1–H4 (or something not listed);
the fix targets that hot spot.

## Implementation sketch

### Step 1: add diagnostic instrumentation

Add timing Refs in `src/text/interpreter.mbt` (test-only
compile). Add a whitebox test under `src/text/` that runs
`interpret_text` on a synthetic content stream matching
local-fixture page 5's shape (many glyphs, 1 image), prints
the breakdown.

Commit this first (RED evidence).

### Step 2: reproduce on real data

Add a test in `src/reader/` that opens
<local-fixture> (skip if not present), calls
`text_program` for pages 4 (index), prints the accumulated
timings. This is the regression guard that will be tightened
after the fix.

### Step 3: apply the targeted fix

Only after the diagnostic confirms the hot spot. Keep the fix
minimal — one module touched, one code path changed. Reuse the
diagnostic to verify the before/after ms drop.

### Step 4: shrink the regression bound

The test in step 2 initially asserts `< current_time + 10 %`.
After the fix, tighten to `< 3000 ms` per the acceptance.

## Files to modify

- `src/text/interpreter.mbt` — instrumentation + targeted fix
- `src/text/state.mbt` or `src/text/font_runtime.mbt` — fix
  depending on hot spot
- `src/text/interpreter_test.mbt` — diagnostic + regression tests
- `src/reader/text_wbtest.mbt` or new file — local-fixture
  fixture guard test

Do NOT touch `src/svg/` for this SDD. The issue is strictly
upstream.

## Acceptance verification

1. `moon test --target native` — all tests pass (724+ now, adds
   diagnostic + regression tests)
2. `moon build --target wasm-gc --release && cp _build/wasm-gc/release/build/src/npm/npm.wasm npm/dist/pdf.wasm`
3. Node profile on <local-fixture>:
   - every page `pageToSvgDeferred` < 2,000 ms
   - page 5 `pageTextPositions` < 3,000 ms
4. Visual harness `assertNoRegression` on local-fixture page 6 / 7 still passes
