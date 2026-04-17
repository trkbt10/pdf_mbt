# Design: SVG Text Colour from Graphics State

## Current Architecture

The page renderer processes two event streams separately:
1. Graphics events (paths, images) — has GraphicsState with colour
2. Text events (spans, glyphs) — has TextGlyphEvent without colour

Both come from `page.text_events()` / `page.graphics_events()`.

## Solution

The graphics event stream includes `TextShown` events that carry the
`GraphicsState` at the time of text rendering. Use this to extract
the nonstroking colour for each text span.

Currently `page_render_svg_text_events` processes text events. Instead,
iterate over graphics events and when encountering `TextShown`, extract
both the text spans/glyphs AND the graphics state's nonstroking colour.

## Alternative: Simpler approach

Look at how `page_render_graphics_svg` processes events. The
`GraphicsEvent::TextShown` variant carries text spans AND the graphics
state. We can render text from this event directly with colour info.

The key change:
- In `page_render_graphics_svg`, when processing `TextShown` events,
  render text (as paths or `<text>`) with the state's nonstroking colour
- Remove the separate `page_render_svg_text_events` call, or have it
  delegate to a shared function that accepts a colour parameter

## Files to modify

- `src/svg/render.mbt` — modify text rendering functions to accept
  and use a fill colour string instead of hardcoding "#000000"
