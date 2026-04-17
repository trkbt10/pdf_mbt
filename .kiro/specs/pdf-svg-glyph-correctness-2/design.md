# Design: Per-glyph outline correctness — second pass

## Overview

First-pass `pdf-svg-glyph-correctness` fixed local-fixture but the same
class of bug (wrong glyph outline per character code) persists on
<local-fixture>. This SDD:

1. Adds local-fixture baselines to the locked visual harness
   (Requirement 1)
2. Runs a glyph trace diagnostic on local-fixture page 6
   (Requirement 2)
3. Applies the targeted fix based on the diagnostic
   (Requirement 3)

## Expand visual harness coverage

Baselines for the second fixture are added to
`npm/test/visual_baselines.json`:

```json
{
  "_meta": { ... },
  "<local-fixture>": {
    "page_6": 0.1612,
    "page_7": 0.2145
  },
  "<local-fixture>": {
    "page_4": <measured>,
    "page_5": <measured>,
    "page_6": <measured>
  }
}
```

`<measured>` values are captured on HEAD via `updateBaseline` so
the "baseline" reflects the current (broken) state. The fix later
shrinks these numbers. After the fix, baselines are updated to the
new measured diff.

A new Node-driven test in `npm/test/harness_regression.mjs` loops
every entry in `visual_baselines.json` and calls
`assertNoRegression`. Run this as part of `npm test`. If a SDD
improves a diff, the SDD commit updates the baseline entry in the
same commit that ships the improvement.

## Diagnostic for local-fixture page 6

A whitebox test in `src/svg/render_wbtest.mbt`:

```
test "diagnostic local-fixture page 6 glyph trace" {
  let path = "<local-fixture>"
  if !@fs.path_exists(path) {
    return
  }
  let document = @reader.PdfDocument::open(@fs.read_file_to_bytes(path))
  let page = document.page(5)
  let result = try? page.text_program(@reader.TextPageOptions::default())
  match result {
    Ok(program) => {
      let glyph_groups = text_program_span_glyphs(program)
      let embedded_fonts = page_svg_embedded_fonts(page)
      for span_index, span in program.spans {
        if span_index >= 3 { break }
        for glyph_index, glyph in span_glyphs(glyph_groups, span_index) {
          if glyph_index >= 10 { break }
          diagnostic_print_glyph_trace(
            span.font_name.unwrap_or(...).to_text(),
            embedded_fonts.get(span.font_name.unwrap_or(...))?.unwrap_or(...),
            glyph,
          )
        }
      }
    }
    Err(_) => ()
  }
}
```

Run once on HEAD, record the output in
`.kiro/specs/pdf-svg-glyph-correctness-2/diagnostic-output.md`,
use it to choose the fix target.

## Candidate failure modes

Same catalog as first pass plus D:

- **A**: cmap miss for SID >= 391
- **B**: charset format 1/2 off-by-one
- **C**: post name padding mismatch
- **D (new)**: Type0 composite font using Identity-H CMap.
  The raw CID from the content stream is passed directly; the CFF
  wrapper's synthetic charset/post is for Type1C (where char_code
  goes through Encoding). If the wrapper treats an Identity-H CID
  font as Type1C, every CID looks up the wrong glyph.

## Root-cause fix

The targeted fix based on the diagnostic output SHALL apply one
(or more) of the candidate modes A/B/C/D to bring
local-fixture page 6 under the 15% diff target. The same
fix SHALL apply to both PDFs: harness_regression iteration SHALL
pass on local-fixture page 6/7 AND local-fixture pages 4/5/6 after
the change. Where the fix affects the local-fixture baselines, the SDD
commit updates the baseline JSON in the same commit so reviewers
see the movement.

## Suspected fix patterns

- A: fix `cff_sid_to_name` for SID >= 391
- B: fix `parse_cff_charset` format 1/2 ranges
- C: unify `cff_cid_glyph_name` helper
- D: detect Identity-H vs WinAnsi encoding at font-descriptor level
  in `build_synthetic_cmap`; when Identity-H, pass CID through
  without remapping (cmap maps codepoint==glyph_id only for the
  identity range)

Diagnostic drives which to apply.

## Files to modify

- `src/svg/render_wbtest.mbt` — diagnostic test
- `src/svg/cff_charset.mbt` / `cff_wrapper.mbt` / `render.mbt` —
  whichever the diagnostic points at
- `npm/test/visual_baselines.json` — add local-fixture baselines
- `npm/test/harness_regression.mjs` (new) — iterate baselines,
  assert no regression
- `npm/package.json` — wire harness_regression into `npm test`
- `.kiro/specs/pdf-svg-glyph-correctness-2/diagnostic-output.md` —
  recorded glyph trace

## Acceptance verification

1. `moon test --target native` — all tests pass
2. `moon build --target wasm-gc --release` + wasm copy
3. `assertNoRegression` iterates all baselines, passes
4. local-fixture page 6 diff measured < 15 %
5. local-fixture page 6/7 no regression beyond 10 %
6. Manual visual inspection: recognisable English text on
   local-fixture page 6
