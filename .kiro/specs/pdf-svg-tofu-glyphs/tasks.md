# Tasks: Tofu (missing glyph) for symbol characters

## Task 1: Diagnostic enumeration

**File:** `src/svg/render_wbtest.mbt`

Add test `"diagnostic local-fixture pages 6 7 tofu glyphs"` that walks every
text event on pages 5 (index) and 6 (index), and prints glyphs
where `svg_resolve_glyph_id` returns 0 or -1.

Output per-line format:

```
tofu <font_name> code=<hex> gid=<int> unicode=<"char">
```

Skip if fixture not present. Do NOT assert on this step — this is
evidence gathering.

## Task 2: Suppress notdef rendering

**File:** `src/svg/render.mbt`

Modify `render_glyph_as_path`:

```moonbit
let gid = svg_resolve_glyph_id(ttf, glyph)
if gid < 0 || gid >= ttf.num_glyphs { return false }
if gid == 0 && !svg_glyph_is_notdef_source(glyph) { return false }
// ... existing logic ...
```

Add helper:

```moonbit
fn svg_glyph_is_notdef_source(glyph : @text.TextGlyphEvent) -> Bool {
  match glyph.glyph.glyph {
    GlyphIdentifier::Notdef => true
    GlyphIdentifier::CID(0) => true
    GlyphIdentifier::CharacterCode(0) => true
    _ => false
  }
}
```

## Task 3: Regression test

**File:** `src/svg/render_wbtest.mbt`

Add test `"local-fixture pages 6 7 render no notdef paths"`:

1. Skip if fixture not present
2. Render SVG for pages 5 and 6
3. For each glyph event processed, count how many times
   `render_glyph_as_path` would have drawn glyph 0 for a
   non-notdef source (via a test-only counter)
4. Assert the count is 0

## Task 4: Optional FD array extension

**File:** `src/svg/cff_charset.mbt`

If Task 1's diagnostic reveals CID-keyed fonts with missing CIDs
that are covered by a secondary FontDictionary in the FD array,
extend `cff_cid_to_glyph_id_map` to scan all FDs and prefer the
first one providing a non-empty charstring at the target CID.

Skip this task if Task 1 shows no evidence of multi-FD fonts in
local-fixture.

## Task 5: Verify

1. `moon test --target native` — all tests pass
2. `moon build --target wasm-gc --release && cp _build/wasm-gc/release/build/src/npm/npm.wasm npm/dist/pdf.wasm`
3. Visually inspect local-fixture page 6 in the demo or via rsvg-convert
   — no tofu boxes should appear
4. `npm test` passes (no regressions)

## Task 6: Drift gate

```bash
indexion spec align status .kiro/specs/pdf-svg-tofu-glyphs/requirements.md src/svg/ --threshold 0.3 --fail-on drifted
```

Must exit 0.
