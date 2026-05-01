# Requirements: Resource Materialization SoT and shared resolution helpers

## Why this spec exists (penal context)

A Type 0 font glyph resolution defect (see
`.kiro/specs/pdf-svg-cid-resolution/`) was traced to one missing
unwrap in `materialize_descendant_fonts`: when `DescendantFonts`
arrived as `PdfObject::Ref(...)` instead of `PdfObject::Array(...)`,
the function silently fell through and the descendant CIDFont
(carrying CIDToGIDMap and FontFile2) never reached the SVG
renderer. Body text rendered correctly because the parent Font
dictionary's other entries got materialized, masking the bug for
months.

This is a textbook duplication-of-logic failure. `Ref → load_object →
materialize_X` patterns are open-coded across:
- `src/reader/text.mbt:materialize_text_resource_object`
- `src/reader/text.mbt:materialize_font_entry`
- `src/reader/text.mbt:materialize_descendant_fonts`
- `src/reader/xobjects.mbt:materialize_resource_object` and friends
- `src/reader/xobjects.mbt:materialize_xobject_stream`

Each site re-implements the unwrap, picks its own subset of the
expected `PdfObject` variants, and silently no-ops on the rest. The
F6 bug is just the most visible symptom; the same shape can be
hiding in colour spaces, pattern resources, or shading dictionaries
that happen to be Ref-wrapped by some producer.

Glyph resolution paths exhibit the same problem at the SVG layer.
`svg_resolve_glyph_id` (post-name reverse lookup) and
`svg_resolve_embedded_glyph_id` (CFF charset / CIDToGIDMap) live
side by side; new fixes routinely add a third path instead of
extending the first two. The result is that
`SvgEmbeddedFont::cff_cid_to_gid` and `cid_to_gid_map` exist as
fields but were unused for months in some shipping builds.

## Required SoT outcomes

### Requirement 1: Single resource-resolution primitive

#### 1.1: `resolve_indirect` helper

The reader package SHALL expose one helper that, given a
`PdfFile` and a `PdfObject`, returns the fully resolved
`PdfObject`. It SHALL transparently follow `PdfObject::Ref` chains
until a non-Ref is reached or a cycle is detected, and it SHALL
gracefully report the absent / cyclic case via `Result` rather than
silently returning the input.

#### 1.2: All Ref unwraps go through 1.1

Every `Ref → load_object` site in `src/reader/` SHALL be migrated to
the helper. After the refactor, repository-wide `grep` for
`load_document_object` SHALL return at most ONE call site outside
the helper itself (the helper's implementation), plus tests.

### Requirement 2: Materialization is documented

#### 2.1: Materialization SoT document

A new file `.kiro/steering/resource-materialization.md` SHALL describe:
- WHAT each materialization pass does (font, xobject, ext-g-state,
  pattern, shading, properties).
- WHERE each pass lives (file:line).
- WHEN each pass runs (which `PdfPage::*` entry point).
- WHICH `PdfObject` variants it accepts and which it rejects.
- The contract that **every** Ref-shaped value is unwrapped before
  variant matching.

#### 2.2: Materialization functions enforce 2.1

After the refactor, the materialization functions SHALL begin with a
single call to `resolve_indirect` (or equivalent shared helper)
before pattern matching. The same defect (Ref-wrapped value silently
ignored) SHALL be impossible to recreate by adding a new
materializer.

### Requirement 3: Glyph resolution is one path

#### 3.1: Single glyph_id resolver

The SVG renderer SHALL expose exactly one function that takes
`(SvgEmbeddedFont, TextGlyphEvent) -> Int?` and returns the
resolved glyph id or None. Internally it MAY consult multiple
sources (CFF charset, CIDToGIDMap, post reverse map, identity
fallback), but the call sites SHALL use only this one entry.

#### 3.2: Decommission the duplicated path

`svg_resolve_glyph_id` (the older, post-only path) SHALL be deleted
or be made an internal helper of 3.1 with no remaining external
callers.

#### 3.3: Resolution priority is explicit

The body of 3.1 SHALL be a flat sequence of strategies ordered as:
1. CFF charset reverse map (CIDFontType0 / CIDFontType0C).
2. CIDToGIDMap (CIDFontType2 with explicit map).
3. CIDToGIDMap Identity (CIDFontType2 with `/CIDToGIDMap /Identity`).
4. `post.glyph_names` reverse lookup (legacy compatibility).
5. CharacterCode cmap lookup (simple fonts).
6. Identity fallback only when all above return None and the
   resulting gid is within `[0, ttf.num_glyphs)`.

The order SHALL be encoded as a single readable function body.
Tests SHALL drive each strategy to its own assertion.

### Requirement 4: Lint and CI gate

#### 4.1: Repeat-this-defect detector

A lint rule (`scripts/lint_resource_materialization.py` or
equivalent) SHALL flag any function whose body contains:
- `match value { Some(Array(values)) => ...; _ => () }` patterns
  WITHOUT a Ref-unwrap above.
- A direct `load_document_object` outside the `resolve_indirect`
  helper.

The rule SHALL run in `npm/demo/test/lint.test.mjs` or a sibling
MoonBit-side test gate so a future regression cannot land silently.

#### 4.2: Spec align gate

`indexion spec align status` for this spec SHALL hit zero with
`--fail-on any` after the refactor lands.

## Required regressions to fix in the same PR

The refactor SHALL include explicit fixtures for at least:
- A document whose `Font.DescendantFonts` is `Ref` (covered by
  <local-fixture> already).
- A document whose `XObject` resource value is `Ref` to a Form
  XObject whose `Resources` is also `Ref` (search the corpus for
  one; if absent, generate a synthetic fixture).
- A `Resources.ColorSpace` entry that is `Ref` to an Array.

Each fixture SHALL ship as a wbtest demonstrating the materialized
output is structurally complete (no Ref leaks past the
materializer).

## Requirement 5: CIDFontType2 + Identity glyph resolution (root-cause closure)

### 5.1: Subset glyph_id resolution priority

For a Type 0 / Identity-H font whose descendant is a CIDFontType2
with `/CIDToGIDMap /Identity` AND whose embedded FontFile2 is a
*subset*, the resolver SHALL determine the glyph_id for a CID using
the following priority order. All four sources of truth SHALL be
consulted; the resolver picks the first non-zero, in-range gid.

  1. ToUnicode codepoint → the subset's `cmap` (Format 4 / Format 12)
     via Unicode lookup. Microsoft Word subsets are typically keyed
     this way regardless of what `/CIDToGIDMap` declares.
  2. Subset `cmap` keyed by CID (when a CID-aware Format 6/10 cmap
     is present in the subset).
  3. Literal CID via `/CIDToGIDMap` (the spec-conformant path).
  4. Identity fallback only when 1-3 return None and `cid <
     ttf.num_glyphs`.

### 5.2: Cross-validation with ToUnicode

When more than one source returns a candidate, the resolver SHALL
prefer the candidate whose corresponding glyph outline (via
`ttf.glyph_outline(gid)`) yields a non-empty result AND whose
implied Unicode codepoint (via the embedded font's reverse cmap)
matches the ToUnicode mapping. The cross-validation SHALL be
performed once per (font, cid) pair and cached.

### 5.3: Fixture

The verification suite SHALL include `<local-fixture>`
page 2 as a fixture, asserting that:
- the F6 line at PDF y=323.86 emits exactly 31 `<path>` elements
  (not 27, not 0), and
- when each path is rendered in isolation in their tx order, the
  composite reads "the reader's understanding but " (with a single
  trailing space ASCII 0x20) within a recognised character set
  (italic-bold lowercase Latin + apostrophe + space).

## Out of scope

- Performance optimisation. The helper may be O(n) in chain length;
  cycles are reported, not optimized.
- Adding new file types or new resource categories.
- Changing the public reader API surface.

## Acceptance verification

```bash
# A. Unit + e2e
moon test --target native -p trkbt10/pdf/src/reader
moon test --target native -p trkbt10/pdf/src/svg
moon test --target native -p trkbt10/pdf/src/text
moon test --target native -p trkbt10/pdf

# B. Drift gate
indexion spec align status \
  .kiro/specs/pdf-refactor-resource-materialization-sot/requirements.md \
  src/ --threshold 0.3 --fail-on any

# C. F6 readable on OpenXML p2
bash npm/scripts/build.sh
node --experimental-wasm-stringref --experimental-wasm-imported-strings <<'EOF'
import { readFileSync, writeFileSync } from "node:fs";
import { PdfDocument } from "npm/index.mjs";
const doc = await PdfDocument.open(readFileSync("<local-fixture>"));
writeFileSync("/tmp/openxml-after-refactor.svg", doc.pageToSvgDeferred(1));
doc.close();
EOF
python3 -c '
import re
with open("/tmp/openxml-after-refactor.svg") as f: data = f.read()
pat = re.compile(r"<path d=\"([^\"]+)\" transform=\"matrix\(([^)]+)\)\"")
ok = 0
for m in pat.finditer(data):
  parts = m.group(2).split()
  if len(parts) != 6: continue
  tx, ty = float(parts[4]), float(parts[5])
  if 60 < tx < 140 and abs(ty - 468.14) < 0.5:
    ok += 1
assert ok >= 27, "F6 line glyph count regressed"
print("F6 line glyphs:", ok)
'
```

All three steps SHALL pass.
