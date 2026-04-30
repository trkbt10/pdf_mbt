# SDD Draft: DRY / SSoT consolidation for src/svg/

## Problem

The `src/svg/` module has accumulated duplicate logic across
successive SDDs. User feedback:

> "同じロジック・同じバグが 2 箇所に分散していた。SSoT が徹底できていないのでは？"

Concrete evidence: commit `7d702a2` (glyph-correctness-2) added
the `<g clip-path=...>` wrapper pattern to glyph path output;
commit `7ea72ca` (page-clip-regression) applied the identical
pattern to `<text>` fallback output — copy-paste instead of
extracting a helper. Had the helper existed the first time, the
second bug would not have been a separate SDD.

`indexion plan refactor` confirms broader duplication (see
`indexion-refactor-plan.md` in this spec dir):

- 27 function-level structural duplicates (70–97 % similarity)
- 10 repeated string literals across 2+ files
- Notable cases:
  - `cff_pad5` ≈ `svg_pad5` (93 %, cross-file)
  - `cff_write_uint16` ≈ `cff_write_uint32` (95 %, same-file)
  - `parse_cff_charset_format1` ≈ `format2` (97 %, same-file)
  - `format_svg_number` ≈ `format_svg_number_precise` (79 %)
  - `push_macos_system_font_directories` ≈ `_linux_` (95 %)

The clip wrapper duplication is the specific trigger for this
SDD, but the cleanup SHALL address all item categories the
indexion report surfaces above a chosen similarity threshold.

## Requirements

#### Refactor note: Clip-wrap helper user-reported duplication

#### 1.1: Single clip-wrap helper
A single helper `write_svg_clip_wrapper_open(builder, clip_id)`
plus `write_svg_clip_wrapper_close(builder, clip_id)` SHALL
encapsulate the "if clip_id > 0, emit `<g clip-path="url(#cN)">`
... `</g>`" pattern used by glyph path output and text fallback
output. Both existing call sites SHALL route through the helper.

#### 1.2: Image and path consistency check
If other SVG output paths (`<image>`, `<path>` for shapes) have
their own clip-path attribute handling that SHALL NOT change
today, the review SHALL document why (transform matrix is in
page space, so direct `clip-path` on the element is geometrically
sound). A doc comment on each untouched emission SHALL declare
this reason.

#### Refactor note: Consolidate pad / number formatting duplicates

#### 2.1: Single pad-integer helper
`cff_pad5` and `svg_pad5` SHALL merge into one function
`pad_unsigned_decimal(n: Int, width: Int) -> String` in a shared
module (e.g. `src/svg/numeric.mbt` or similar). Both call sites
SHALL use it.

#### 2.2: Parameterised uint BE writer
`cff_write_uint16` and `cff_write_uint32` SHALL merge into one
`cff_write_uint(buf, offset, value, byte_width)` helper. The
93–95 % structural similarity detected by indexion SHALL drop
to 0 % after the merge.

#### 2.3: Parameterised charset format parser
`parse_cff_charset_format1` and `parse_cff_charset_format2`
differ only in the byte width of `num_left`. They SHALL share a
`parse_cff_charset_range_format(data, num_glyphs, num_left_width)`
implementation.

#### 2.4: Parameterised decimal formatter
`format_svg_number` and `format_svg_number_precise` differ only
in decimal count. They SHALL share a
`format_svg_number_with_precision(value, decimals)` body.

### Requirement 3: Consolidate system font directory enumeration

#### 3.1: Per-OS directory list shared structure
`push_macos_system_font_directories`,
`push_linux_system_font_directories` (and any Windows equivalent)
SHALL share a table-driven approach: one table per OS with
directory paths, and one generic `push_system_font_directories`
iterating the table.

#### Refactor note: Magic string constants

#### 4.1: Standard 14 font names
`"Helvetica"`, `"Courier"`, `"Times-Roman"`, `"Times-Bold"`,
`"Times-Italic"`, `"Times-BoldItalic"` that appear in both
`render.mbt` and `system_font.mbt` SHALL be declared as module-
level `let` constants in a single module. Other modules reference
the constants.

#### 4.2: SVG attribute name constants
`"\" height=\""` / `"\" width=\""` repeated in `render.mbt` and
`page_render.mbt` MAY remain inline if the cost of introducing a
helper outweighs the benefit. This case is a candidate for
review but not a mandate — the alternative (a helper that writes
a named SVG attribute) is fine, but the change to call sites must
not obscure reading.

#### Process note: indexion plan in every refactor SDD

#### 5.1: Refactor plan attached to SDD
Any future SDD touching `src/svg/` (or other project modules)
SHALL attach an `indexion-refactor-plan.md` snapshot when a
change could plausibly introduce duplication. The reviewer
compares the before / after function counts in the report.

#### 5.2: Per-task drift gate uses the refactor plan
Instead of per-requirement vocabulary drift only, the drift gate
SHALL include
`indexion plan refactor --threshold=0.85 src/<module>/` and
require the "function duplicates" count to be non-increasing.

### Requirement 6: Acceptance

#### 6.1: indexion report drop
After this SDD, rerunning
`indexion plan refactor --threshold=0.85 --include='*.mbt' \
  --exclude='*_wbtest.mbt' --exclude='*pkg.generated*' src/svg/`
SHALL report fewer function duplicates than before (was 6 at 0.85
threshold, target ≤ 2 after the clean-up).

#### 6.2: No behaviour change
`moon test --target native` tests pass with no change in
assertions. `npm test` visual harness baselines stay within
tolerance. local-fixture and local-fixture renderings are
byte-identical or pixel-equivalent to pre-refactor output.

#### 6.3: Documentation update
A short doc added under `src/svg/README.md` (or equivalent) SHALL
list the helpers introduced by this SDD so a future agent finds
them before writing duplicate code.
