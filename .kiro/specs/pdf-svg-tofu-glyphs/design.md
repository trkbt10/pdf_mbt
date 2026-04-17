# Design: Tofu (missing glyph) for symbol characters

## Overview

Stop rendering the `.notdef` glyph (glyph 0) as a visible tofu
when a non-`.notdef` Unicode codepoint resolves to it. Enumerate
affected codepoints in local-fixture via a diagnostic test, fix the
renderer to suppress notdef rendering in that case, and optionally
improve the CFF CID reverse lookup so missing mappings become
hits.

## Current code

`render_glyph_as_path` (src/svg/render.mbt):

```moonbit
let gid = svg_resolve_glyph_id(ttf, glyph)
if gid < 0 || gid >= ttf.num_glyphs { return false }
let outline = ttf.glyph_outline(gid)
if outline.length() == 0 { return svg_glyph_is_spacing(glyph) }
// ... draw <path d="..."/> ...
```

Notice `gid == 0` is not treated differently. If the resolve
returns 0, we render `.notdef` as any other glyph — typically a
rectangle or empty box.

`svg_resolve_glyph_id` (src/svg/render.mbt):

```moonbit
GlyphIdentifier::CID(cid) =>
  let mapped = svg_cid_glyph_id(ttf, cid)
  if mapped >= 0 { mapped } else { cid }
```

If `svg_cid_glyph_id` returns -1 for an unmapped CID, we fall
back to using the raw CID as glyph_id. If `cid` happens to index
into an out-of-range charstring, `glyph_outline` returns empty and
the caller falls through. If `cid` is 0 (some PDFs use CID 0 for
undefined), we return 0 and draw notdef.

## Diagnostic

New whitebox test `test "diagnostic local-fixture pages 6,7 tofu glyphs"`:

1. Open local-fixture, iterate text events for pages 5 and 6
2. For each glyph, compute `gid = svg_resolve_glyph_id(ttf, glyph)`
3. Log all glyphs where `gid == 0` alongside the font name, the
   source CID or character code, and the Unicode fallback from
   the glyph's `unicode` field
4. Log all glyphs where `gid < 0 || gid >= num_glyphs`

Expected output shape:

```
tofu T1_3 code=0xB7 gid=0 unicode="·"
tofu C0_0 cid=256 gid=0 unicode="・"
tofu C0_1 cid=7 gid=0 unicode=""
```

These are the glyphs currently rendered as tofu.

## Avoid drawing `.notdef` as tofu

The renderer SHALL avoid drawing the `.notdef` glyph as a visible
tofu box. When `svg_resolve_glyph_id` returns 0 for a Unicode
codepoint that is not itself the `.notdef` character (suppress
notdef rendering in SVG), `render_glyph_as_path` SHALL NOT draw
the notdef outline. Instead it tries the text fallback, or skips
the glyph if text fallback is unavailable. The notdef rendering
is preserved only when the PDF content stream explicitly references
glyph 0 (preserve notdef for intentional uses) — typically when
the source CID or character code is 0, or the glyph identifier
is explicitly `GlyphIdentifier::Notdef`.

## Fix

### Suppress notdef rendering (Requirement 2)

`render_glyph_as_path` gains a notdef guard:

```moonbit
let gid = svg_resolve_glyph_id(ttf, glyph)
if gid < 0 || gid >= ttf.num_glyphs { return false }
if gid == 0 && !svg_glyph_is_notdef_source(glyph) { return false }
// ... existing logic ...
```

`svg_glyph_is_notdef_source(glyph)` checks whether the source
character was explicitly `.notdef` — typically only if the CID or
character code is 0, or the glyph identifier is
`GlyphIdentifier::Notdef`. Otherwise we reject notdef to let the
text fallback take over.

When `render_glyph_as_path` returns false, the caller chain
decides whether to draw a `<text>` fallback. The fallback gets
the original character from the glyph's `unicode` mapping, which
the browser can render with a default font.

### Optional: Improve CID reverse lookup (Requirement 3)

After the diagnostic identifies specific missing CIDs, check
whether they are represented in the CFF's FD array (CIDFontType0C
with multiple FontDictionaries). Currently `cff_cid_to_glyph_id_map`
uses only the primary FD. Extend to walk all FDs and pick the
first mapping that yields a non-empty charstring.

## Files to modify

- `src/svg/render.mbt` — notdef guard in `render_glyph_as_path`,
  new helper `svg_glyph_is_notdef_source`
- `src/svg/render_wbtest.mbt` — diagnostic test, regression test
  that asserts no tofu glyphs on pages 6-7
- `src/svg/cff_charset.mbt` — optional: extended FD array walking

## Acceptance verification

1. `moon test --target native` — 720+ tests pass (adds diagnostic
   + regression tests)
2. Rebuild wasm, visually verify local-fixture page 6 shows no tofu boxes
3. Pages 6/7 pixelmatch diff does not regress from 12.5% / 17.5%
