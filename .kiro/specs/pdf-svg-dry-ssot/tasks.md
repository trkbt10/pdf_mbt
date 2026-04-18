# Tasks: DRY / SSoT consolidation for src/svg/

## Task 0: Confirm starting point

Run and capture the pre-refactor plan:

```bash
indexion plan refactor --threshold=0.85 --include='*.mbt' \
  --exclude='*_wbtest.mbt' --exclude='*pkg.generated*' \
  --output=.kiro/specs/pdf-svg-dry-ssot/indexion-refactor-plan-before.md \
  src/svg/
```

Commit as the baseline.

## Task 1: Clip wrapper helper

**File:** `src/svg/render.mbt`

1. Introduce `write_svg_clip_wrapper_begin(builder, clip_id)` and
   `write_svg_clip_wrapper_end(builder, clip_id)` (top-level).
2. Replace the duplicate `if clip_id > 0 { "<g"...">" }` blocks in
   `page_render_text_span_as_paths` and `page_render_text_svg`
   with calls.
3. Add a doc comment on each helper citing the page-space clip
   rule and referencing the two originating SDDs.

Verify:
- `moon test --target native` passes
- Visual harness `assertNoRegression` passes for all baselines
- No change to the emitted SVG byte-equality for a fixture case
  (add a snapshot test if not present)

## Task 2: Number formatter consolidation

**File:** `src/svg/render.mbt`

1. Introduce
   `format_svg_number_with_precision(value: Double, decimals: Int) -> String`.
2. Rewrite `format_svg_number` and `format_svg_number_precise` to
   delegate.
3. Keep the two public wrappers so call sites don't change.

Verify indexion duplicate count drops for this pair.

## Task 3: CFF uint writer consolidation

**File:** `src/svg/cff_wrapper.mbt`

1. Add `cff_write_uint(buf, offset, value, width)`.
2. Replace `cff_write_uint16` and `cff_write_uint32` call sites
   with the new helper (or keep the two thin wrappers that
   delegate).

## Task 4: CFF charset format 1/2 consolidation

**File:** `src/svg/cff_charset.mbt`

1. Introduce
   `parse_cff_charset_range_format(data, num_glyphs, num_left_width)`
   covering both format 1 (`num_left_width = 1`) and format 2
   (`num_left_width = 2`).
2. Replace `parse_cff_charset_format1` and `parse_cff_charset_format2`
   bodies to call the helper (or delete and update the dispatch
   in the caller).

Run the existing CFF charset unit tests — all SHALL still pass.

## Task 5: CID zero-pad helper consolidation

**File:** choose one of `src/svg/cff_charset.mbt` or a new shared
module

1. Keep one `cff_pad5(n: Int) -> String` (or rename to
   `cid_pad5` for clarity).
2. Delete the duplicate from `src/svg/render.mbt`
   (`svg_pad5`) and update any usage.

## Task 6: System font directory table

**File:** `src/svg/system_font.mbt`

1. Introduce `let system_font_dir_tables : Array[...]` with one
   entry per OS.
2. Replace `push_macos_system_font_directories` and
   `push_linux_system_font_directories` with a single
   `push_system_font_directories(os, out)` that reads from the
   table.

## Task 7: Standard 14 font name constants

**Files:** `src/svg/system_font.mbt` (primary), `src/svg/render.mbt`
(consumer)

1. Export module-level constants for "Helvetica", "Courier",
   "Times-Roman", "Times-Bold", "Times-Italic", "Times-BoldItalic"
   from `system_font.mbt`.
2. In `render.mbt`, replace string literals with the constants.

## Task 8: Update README index

**File:** `src/svg/README.md` (create if missing, else append)

Add a section listing the helpers introduced by this SDD:
`write_svg_clip_wrapper_{begin,end}`,
`format_svg_number_with_precision`, `cff_write_uint`,
`parse_cff_charset_range_format`, `cid_pad5`,
`push_system_font_directories`, `std14_*` constants.

## Task 9: Re-run refactor plan and confirm drop

```bash
indexion plan refactor --threshold=0.85 --include='*.mbt' \
  --exclude='*_wbtest.mbt' --exclude='*pkg.generated*' \
  --output=.kiro/specs/pdf-svg-dry-ssot/indexion-refactor-plan-after.md \
  src/svg/
```

Commit both `-before` and `-after` reports. Acceptance: function
duplicate count (at 0.85 threshold) ≤ 2 in the "after" report.

## Task 10: Process requirement — future SDDs auto-run refactor plan

**File:** `.indexion/sdd-reports/templates/drift-gate.sh` (new or
update) — a snippet that SDD implementation prompts can copy.
Contents:

```bash
#!/usr/bin/env bash
set -euo pipefail
spec_dir="$1"
impl_dir="$2"
indexion spec align status "$spec_dir/requirements.md" "$impl_dir" \
  --threshold 0.3 --fail-on drifted
indexion plan refactor --threshold=0.85 --include='*.mbt' \
  --exclude='*_wbtest.mbt' --exclude='*pkg.generated*' \
  "$impl_dir" > /tmp/refactor-after.md
# Compare function duplicate count with the previous baseline —
# fail if increased. (Exact comparison logic left to future SDD.)
```

For this SDD, the snippet is an artifact; wiring into CI is a
follow-up.

## Task 11: Final verification

1. `moon test --target native` — all tests pass (730+)
2. `moon build --target wasm-gc --release && cp _build/wasm-gc/release/build/src/npm/npm.wasm npm/dist/pdf.wasm`
3. `npm test` — harness_regression iterates baselines, all pass
4. Manual inspection: local-fixture page 2 right column
   visible (regression catch for the clip-wrapper helper)
5. `indexion spec align status .kiro/specs/pdf-svg-dry-ssot/requirements.md src/svg/ --threshold 0.3 --fail-on drifted`
   passes
