# SDD Draft: Text interpreter performance on large PDFs

## Problem

`<local-fixture>` (76 pages, 3.2MB) blocks the wasm
main thread for tens of seconds on specific pages:

```
page 5: svg=17,486 ms imgs=32 ms count=5
page 6: svg=42,431 ms imgs=11 ms count=1
page 8: svg=10,947 ms imgs=47 ms count=2
page 9: svg=24,812 ms imgs=274 ms count=4
```

Counter to the earlier lazy image-materialisation work, these
delays are NOT caused by images:

```
pageTextPositions(5): 42,520 ms, entries=3181
pageImageCount(5): 1 ms, count=1
```

`pageTextPositions` alone — which routes through
`PdfPage::text_program` → `@text::interpret_text` — takes 42
seconds for one page. The page has only 1 image but 3181 text
positions. The text interpreter is the dominant cost.

User has reported this blocking behaviour "multiple times" and
rightly calls it unaddressed. Previous SDDs (image-raw-rgba,
image-cache, image-decode-perf) fixed the image pipeline but the
text pipeline was never profiled.

### Profile summary of the failing cases

| Page | text positions | interpret time |
|------|----------------|----------------|
| 5    | ~3,181         | 17.5 s         |
| 6    | 3,181          | 42.4 s         |
| 8    | ?              | 10.9 s         |
| 9    | ?              | 24.8 s         |

3181 glyphs × O(n²) scan = ~10M operations — consistent with the
wasm single-thread time observed. Candidate hot spots in the text
interpreter pipeline:

- Per-glyph work that rescans the whole glyph array (quadratic)
- Per-glyph allocation of temporary arrays in the decode path
- ToUnicode CMap lookup walking the entire map per character
- Font resource resolution repeated per glyph instead of once per
  span

Without profiling evidence, the above are only candidates. The
SDD starts with instrumentation to identify the actual hot spot.

## Requirements

### Requirement 1: Performance bound test (regression guard)

#### 1.1: Regression test against local-fixture fixture
A whitebox test SHALL open <local-fixture> (guarded
by `@fs.path_exists`), call `page.text_program(...)` for pages 4,
5, 7, 8 (zero-indexed), and assert each completes under a strict
bound on the reference machine. The initial bound SHALL be set to
the current measured time, +10 % tolerance, so any future
regression fires the assert.

The bound SHALL be tightened after each fix commit that measurably
improves the runtime.

#### 1.2: text_positions_json bound
An identical test SHALL exercise the `pdf_page_text_positions_json`
wasm API entry for the same pages and assert the same bounds.

### Requirement 2: Diagnostic instrumentation

#### 2.1: Per-phase timer in the text interpreter
An instrumentation pass SHALL measure and print:
- time spent parsing the content stream (`parse_decoded_content`)
- time spent in the text interpreter loop itself
  (`interpret_text`)
- count of interpreter operations per page
- count of glyph decodes per page
- count of per-glyph allocations (if measurable)

Emission SHALL be test-only (guarded by a compile-time flag or
test-only module) so production builds pay no cost.

#### 2.2: Operation breakdown
For the worst page (page 6 of local-fixture with 42 s), the
instrumentation SHALL break the time down by operator kind (Tj,
TJ, Tm, Tf, etc.) so we know whether it's bulk glyph rendering or
a specific operator that is quadratic.

### Requirement 3: Targeted performance fix

#### 3.1: Fix identified by diagnostics
The fix SHALL target the specific hot spot identified by the
diagnostic output. No speculative refactoring.

#### 3.2: Algorithmic improvement, not caching
Where the diagnostic reveals an O(n²) or worse algorithm, the fix
SHALL reduce complexity (e.g. build an index once, use it many
times). Caching already-computed values is fine when the cache
entry is reused.

### Requirement 4: Acceptance criteria

#### 4.1: local-fixture page 6 under 3 seconds
After the fix, `pageTextPositions(5)` (zero-indexed) on
<local-fixture> SHALL complete in under 3,000 ms
on the reference machine. Current baseline: 42,520 ms. Target is
14× speedup.

#### 4.2: All local-fixture pages under 2 seconds
`pageToSvgDeferred(i)` for every page 0..75 of
local-fixture SHALL complete in under 2,000 ms. Current: up
to 42,431 ms on worst page. This is the UX gate: the user must
not see multi-second main-thread blocks.

#### 4.3: No regression on local-fixture
local-fixture pages 4–7 `pageToSvgDeferred` times SHALL not regress
beyond 10 % of the current measurements (page 4: 148 ms, page 7:
161 ms, etc).

#### 4.4: No regression on existing tests
`moon test --target native` 724+ tests SHALL continue to pass.
Visual harness `assertNoRegression` against local-fixture page 6 and 7
baselines SHALL pass.
