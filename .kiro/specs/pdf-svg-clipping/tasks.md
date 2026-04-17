# Tasks: SVG clipping path support

## Task 1: Clipping registry types and signature

**File:** `src/svg/render.mbt`

1. Define `priv struct SvgClipDef { id : Int, entries : Array[ClipEntry], parent_id : Int? }`
2. Define `priv struct SvgClipRegistry { mut clips : Array[SvgClipDef], mut id_by_signature : Map[String, Int] }`
3. Add `fn svg_clip_signature(state: GraphicsState) -> String` that
   returns a stable string identifier for the current clipping
   state (e.g. concatenation of each `ClipEntry` path's `svg_path_data`
   result plus fill-rule char)
4. Add `fn svg_register_clip(registry: SvgClipRegistry, state: GraphicsState, page_height: Double) -> Int`
   — returns the clip id (0 means no-clip)

## Task 2: Build registry from graphics event stream

**File:** `src/svg/render.mbt`

Add `fn build_svg_clip_registry(events: Array[GraphicsEvent], page_height: Double) -> SvgClipRegistry`:

- Walks each `PathPainted`, `ImagePainted`, `InlineImagePainted`
  event and registers its `state.clipping_path`
- Also walks `TextGlyphEvent`-bearing events if needed for text
- Returns the built registry

## Task 3: Emit clipPath definitions

**File:** `src/svg/render.mbt`

Add `fn write_svg_clip_defs(builder: StringBuilder, registry: SvgClipRegistry, page_height: Double) -> Unit`:

- If registry is empty, emit nothing
- Otherwise wrap all clipPath elements in a single `<defs>...</defs>`
- For each `SvgClipDef`, emit `<clipPath id="c{id}" [clip-path="url(#c{parent_id})"]>` + per-entry `<path>` + `</clipPath>`
- Path `d` attribute comes from `svg_path_data(entry.path, identity_matrix, page_height)`
- `clip-rule="evenodd"` when entry uses `FillRule::EvenOdd`

## Task 4: Apply clip-path to image elements

**File:** `src/svg/render.mbt`

Modify `page_render_image_svg` and `write_svg_image` to accept the
clip id (or look up via registry) and emit `clip-path="url(#c{id})"`
alongside other attributes. Skip when id is 0 (no-clip).

## Task 5: Apply clip-path to paths and text

**File:** `src/svg/render.mbt`

Modify `page_render_path_svg` similarly.

For text rendering, propagate the clip id through
`page_render_text_svg` and `page_render_text_span_as_paths`.
Emit `clip-path="url(#c{id})"` on the `<text>` element (which
applies to all its `<tspan>` descendants) and on each `<path>`
element for glyph paths.

## Task 6: Wire into render_page_svg_impl

**File:** `src/svg/render.mbt` (or `page_render.mbt` depending on
where `render_page_svg_impl` lives)

1. Build the registry once by collecting graphics events (and
   text events if separate)
2. Call `write_svg_clip_defs` after the background rect, before
   graphics/text rendering
3. Pass the registry down through `page_render_graphics_svg` and
   the text rendering entry points

## Task 7: Tests

**File:** `src/svg/render_wbtest.mbt`

Add whitebox tests:

1. A PDF with a single clip rectangle + image → SVG contains
   `<clipPath id="c1">` + `<image ... clip-path="url(#c1)"/>`
2. A PDF with no clip (just page default) → no `<clipPath>` in
   output, no `clip-path` attributes on images
3. A PDF with stacked clips → nested `<clipPath clip-path="...">`

Use existing `build_single_page_pdf` helper to construct the
fixture content streams.

## Task 8: Verify and rebuild

1. `moon test --target native` — all tests pass (currently 713+)
2. `moon build --target wasm-gc --release && cp _build/wasm-gc/release/build/src/npm/npm.wasm npm/dist/pdf.wasm`
3. Pixelmatch local-fixture page 6, 7:
   - Acceptance: page 6 < 9.0% (baseline 12.5%), page 7 < 14.0%
     (baseline 17.5%)
   - Report actual diff in the commit message
4. Visual check: smartphone image in page 6 SVG has rounded corners
   matching pdftoppm output

## Task 9: Spec alignment gate

```bash
indexion spec align status .kiro/specs/pdf-svg-clipping/requirements.md src/svg/ --threshold 0.3 --fail-on drifted
```

Must exit 0. For DRIFTED items, add spec vocabulary to public
function doc comments (e.g. "clipping path", "clipPath registry",
"clip-path attribute", "intersection of clips", "initial page
clip").
