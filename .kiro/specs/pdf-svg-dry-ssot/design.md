# Design: DRY / SSoT consolidation for src/svg/

## Overview

Consolidate the structural duplicates and magic-string repeats
surfaced by `indexion plan refactor` into shared helpers. The
user-reported clip-wrapper duplication is the first target because
it's a live correctness hazard; the other items are code-quality
clean-ups with regression-safe mechanical transformations.

Input artifact: `indexion-refactor-plan.md` (in this spec dir).

## Consolidate pad / number formatting duplicates

Pad / number formatting duplicates SHALL be consolidated via
shared helpers: the single pad-integer helper `cid_pad5` (merged
from `cff_pad5` and `svg_pad5`, 93 % structural similarity), the
parameterised uint BE writer `cff_write_uint(buf, offset, value,
byte_width)` (merged from `cff_write_uint16` / `cff_write_uint32`,
95 % similarity), the parameterised charset format parser
`parse_cff_charset_range_format(data, num_glyphs,
num_left_width)` (merged from `parse_cff_charset_format1` and
`parse_cff_charset_format2`, 97 %), and the parameterised decimal
formatter `format_svg_number_with_precision(value, decimals)`
(shared body for `format_svg_number` and
`format_svg_number_precise`, 79 %).

## Target consolidations

### Clip-wrap helper (Requirement 1)

Current code (after the two clip fixes):

```moonbit
// src/svg/render.mbt, glyph path path
if clip_id > 0 {
  builder.write_string("<g")
  write_svg_clip_path_attribute(builder, clip_id)
  builder.write_string(">")
}
// ... glyph path emission ...
if clip_id > 0 {
  builder.write_string("</g>")
}

// src/svg/render.mbt, text fallback path — IDENTICAL pattern
if clip_id > 0 {
  builder.write_string("<g")
  write_svg_clip_path_attribute(builder, clip_id)
  builder.write_string(">")
}
// ... <text> emission ...
if clip_id > 0 {
  builder.write_string("</g>")
}
```

New helper:

```moonbit
/// Wraps transformed SVG content in an untransformed <g clip-path>
/// so the clip is evaluated in page coordinates, not in the child's
/// local transform space. Call begin before emitting the transformed
/// children, end after.
fn write_svg_clip_wrapper_begin(builder : StringBuilder, clip_id : Int) -> Unit {
  if clip_id <= 0 { return }
  builder.write_string("<g")
  write_svg_clip_path_attribute(builder, clip_id)
  builder.write_string(">")
}

fn write_svg_clip_wrapper_end(builder : StringBuilder, clip_id : Int) -> Unit {
  if clip_id <= 0 { return }
  builder.write_string("</g>")
}
```

Both call sites reduce to:

```moonbit
write_svg_clip_wrapper_begin(builder, clip_id)
// ... emit transformed children ...
write_svg_clip_wrapper_end(builder, clip_id)
```

### Number formatters (Requirement 2.4)

Current code:

```moonbit
fn format_svg_number(value : Double) -> String {
  // ... 3-decimal rounding, trimming, ...
}

fn format_svg_number_precise(value : Double) -> String {
  // ... 6-decimal rounding, trimming, ...  (79% structural similarity)
}
```

Merge:

```moonbit
fn format_svg_number_with_precision(value : Double, decimals : Int) -> String {
  // body parameterised over `decimals`
}

fn format_svg_number(value : Double) -> String {
  format_svg_number_with_precision(value, 3)
}

fn format_svg_number_precise(value : Double) -> String {
  format_svg_number_with_precision(value, 6)
}
```

Keep the two public wrappers to avoid touching call sites.

### CFF byte writer (Requirement 2.2)

`cff_write_uint16` / `cff_write_uint32` differ only in loop
iteration count. Merge:

```moonbit
fn cff_write_uint(buf : FixedArray[Byte], offset : Int, value : Int, width : Int) -> Unit {
  for i = 0; i < width; i = i + 1 {
    buf[offset + i] = ((value >> ((width - 1 - i) * 8)) & 0xFF).to_byte()
  }
}
```

### CFF charset format 1/2 parser (Requirement 2.3)

Merge `parse_cff_charset_format1` and `parse_cff_charset_format2`
into `parse_cff_charset_range_format(data, num_glyphs,
num_left_width)`. num_left_width is 1 for format 1, 2 for format 2.

### Pad-integer helper (Requirement 2.1)

`cff_pad5` and `svg_pad5` at 93 % similarity are identical work.
Move one into a shared module (e.g. a new `src/svg/numeric.mbt`
or place it in the existing `src/svg/cff_charset.mbt` as
`cid_pad5`) and delete the other.

### Per-OS font directory tables (Requirement 3)

```moonbit
priv struct OsFontDirTable {
  os : String
  dirs : Array[String]
}

let system_font_dir_tables : Array[OsFontDirTable] = [
  { os: "macos", dirs: ["/System/Library/Fonts", "/Library/Fonts", ...] },
  { os: "linux", dirs: ["/usr/share/fonts", ...] },
  ...
]

fn push_system_font_directories(os : String, out : Array[String]) -> Unit {
  for entry in system_font_dir_tables {
    if entry.os == os {
      for d in entry.dirs { out.push(d) }
    }
  }
}
```

### String constants (Requirement 4.1)

```moonbit
pub let std14_helvetica : String = "Helvetica"
pub let std14_courier : String = "Courier"
pub let std14_times_roman : String = "Times-Roman"
pub let std14_times_bold : String = "Times-Bold"
pub let std14_times_italic : String = "Times-Italic"
pub let std14_times_bold_italic : String = "Times-BoldItalic"
```

In one module (likely `system_font.mbt`), export these; `render.mbt`
imports them.

## Process requirement (Requirement 5)

`.indexion/sdd-reports/<spec>/refactor-plan.md` SHALL be attached
to each SDD that edits `src/svg/`. The plan is generated by:

```bash
indexion plan refactor --threshold=0.85 --include='*.mbt' \
  --exclude='*_wbtest.mbt' --exclude='*pkg.generated*' \
  --output=.kiro/specs/<spec>/indexion-refactor-plan.md \
  src/svg/
```

The per-task drift gate additionally runs
`indexion plan refactor` and asserts the function duplicate count
does not rise compared to the pre-commit baseline.

## Files to modify

- `src/svg/render.mbt` — consume clip wrapper helper + number
  formatter consolidation + image-axis scale ≈ length review
- `src/svg/cff_wrapper.mbt` — consume uint writer helper
- `src/svg/cff_charset.mbt` — consume charset format helper + pad5
- `src/svg/system_font.mbt` — table-driven dir enumeration +
  std14 constants
- `src/svg/numeric.mbt` (NEW, optional) — pad5, formatter
- `src/svg/README.md` (NEW or appended) — helper index

## Acceptance

1. `moon test --target native` passes — no behaviour change
2. `npm test` passes — no visual regression
3. `indexion plan refactor --threshold=0.85 src/svg/` reports ≤ 2
   function-level duplicates (was 6 at 0.85)
4. `assertNoRegression` on all baselines passes
5. drift gate passes
