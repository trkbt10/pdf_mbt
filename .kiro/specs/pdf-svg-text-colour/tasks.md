# Tasks: SVG Text Colour from Graphics State

## Task 1: Understand the graphics event stream for text

**Research:** Read how `page.graphics_events()` returns
`GraphicsEvent::TextShown(spans, glyphs, state)` events.
Check the GraphicsEvent enum in `src/graphics/` to understand
what data is available. The `state: GraphicsState` has
nonstroking colour via `svg_colour(state, ColourUse::Nonstroking)`.

## Task 2: Add fill colour parameter to text rendering functions

**File:** `src/svg/render.mbt`

Modify these functions to accept a `fill_colour: String` parameter:
- `page_render_text_svg` — replace `fill="#000000"` with the parameter
- `page_render_text_span_as_paths` — pass through to render_glyph_as_path
- `render_glyph_as_path` — replace `fill="#000000"` with the parameter

## Task 3: Extract nonstroking colour from graphics state

**File:** `src/svg/render.mbt`

In the code that processes text events and calls `page_render_text_svg`,
obtain the graphics state's nonstroking colour. There are two approaches:

**Approach A:** If text is rendered from graphics events (`TextShown`),
the GraphicsState is directly available. Use
`svg_colour(state, @graphics.ColourUse::Nonstroking)`.

**Approach B:** If text is rendered from text events separately,
correlate with graphics events to find the colour. This is more complex.

Prefer Approach A if possible.

## Task 4: Update tests

**File:** `src/svg/render_wbtest.mbt`

Update tests that check for `fill="#000000"` to expect the correct
colour from the test fixture's graphics state.

## Task 5: Verify

Run `moon test --target native` — all 693 tests must pass.
Commit when done.
