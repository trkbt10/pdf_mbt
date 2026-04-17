# Design: SVG clipping path support

## Overview

Read `GraphicsState::clipping_path` from each graphics event,
collect distinct `ClipState` values into a registry, emit SVG
`<clipPath>` elements inside `<defs>`, and apply
`clip-path="url(#id)"` to images, paths, and text elements. Leverage
the existing `svg_path_data` helper for clip path geometry so the
Y-axis flip is consistent.

## Current code

`src/svg/render.mbt`:

- `page_render_graphics_svg` iterates graphics events but only
  handles `PathPainted` and `ImagePainted`
- `ClipChanged` events are discarded
- `page_render_path_svg` and `page_render_image_svg` emit `<path>`
  and `<image>` elements without any `clip-path` attribute
- The SVG root element has no `<defs>` section for clipPath
  definitions

## Graphics package types (reference)

```moonbit
// from src/graphics/state.mbt
struct ClipState {
  initial_clip : Rect?     // page's initial clip (MediaBox-based)
  clips : Array[ClipEntry]  // accumulated clips from W/W*
}

// from src/graphics/pkg.generated.mbti
struct ClipEntry {
  path : GraphicsPath       // geometry already in page space
  fill_rule : FillRule      // Nonzero or EvenOdd
}
```

`ClipEntry::path.subpaths` contains line-to/curve-to segments in
page coordinates. `svg_path_data` already converts GraphicsPath
into an SVG `d` attribute with Y-axis flip.

## Emit SVG clipPath definitions from ClipState

Emit SVG clipPath definitions from ClipState: one `<clipPath>` per
unique ClipState is registered with a stable id, and the intersection
of accumulated clips is represented by nesting later clipPath
elements via `clip-path="url(#cN)"`. The initial page clip from
`ClipState::initial_clip` becomes the outermost clipping boundary; a
no-op page clip equal to the MediaBox is omitted. Fill rule on clip
path is propagated through `clip-rule="evenodd"` on each `<path>`
inside the clipPath when the `ClipEntry` uses `FillRule::EvenOdd`.

## Apply clipPath to rendered elements

Apply clipPath to rendered elements by attaching a
`clip-path="url(#cN)"` attribute on the rendered SVG node for the
current graphics-state clipping path. This applies to:

- clip-path attribute on images — the `<image>` element emitted by
  `page_render_image_svg` carries the attribute
- clip-path attribute on paths — the `<path>` element emitted by
  `page_render_path_svg` carries the attribute
- clip-path attribute on text — the `<text>` element emitted by
  `page_render_text_svg` and the glyph-path `<path>` elements
  emitted by `page_render_text_span_as_paths` carry the attribute
  so text clipped to a region does not bleed

When the clipping path is empty or equals the initial page clip,
the attribute is omitted.

## Solution

### Clipping registry

```moonbit
priv struct SvgClipRegistry {
  mut clips : Array[SvgClipDef]        // ordered by first-use
  mut id_by_signature : Map[String, Int]  // dedup key → id
}

priv struct SvgClipDef {
  id : Int                    // 1-based; rendered as "c1", "c2", ...
  entries : Array[ClipEntry]  // from ClipState::clips
  parent_id : Int?            // for nested <clipPath clip-path="...">
}
```

A signature string hashes the `ClipState` so identical clipping
states reuse the same id. For the first pass, keys are computed
from the sequence of path data strings; collisions are unlikely for
rendered output.

### Rendering pipeline

1. Pre-scan the graphics events to collect distinct `ClipState`
   snapshots (one per rendered element). Register them in the
   registry in the order they first appear.
2. Emit `<defs>` at the top of the page SVG with one `<clipPath>`
   per registry entry. Each `<clipPath>` contains `<path d="..."
   clip-rule="..."/>` entries corresponding to `ClipEntry` values.
   For nested intersection, wrap later clip paths with a
   `clip-path` attribute referencing an earlier clipPath.
3. When rendering images / paths / text, look up the clip id from
   the registry by the element's `state.clipping_path` signature
   and emit `clip-path="url(#c{id})"`.

### Code changes

- **New helper** `svg_clip_registry()` — build a registry from the
  event stream.
- **New helper** `write_svg_clip_defs(builder, registry)` — emit
  `<defs><clipPath>...</clipPath></defs>`.
- **Modify** `page_render_graphics_svg` — first pass registers
  clips, second pass renders elements with clip-path attributes.
- **Modify** `page_render_image_svg` / `page_render_path_svg` /
  `page_render_text_svg` — accept the registry, look up clip id,
  emit the attribute.
- **Modify** `render_page_svg_impl` — call `write_svg_clip_defs`
  once after the `<rect>` background and before graphics/text
  rendering.

### Empty/no-op clipping states

If `state.clipping_path.clips.length() == 0` and
`initial_clip` equals the page's MediaBox (the default), no
`clip-path` attribute is needed. The registry can represent this
as id 0 = no-clip, skipping emission.

### Nested clipPath vs combined path

SVG 1.1 clip-path works as follows:
- Each `<path>` inside a `<clipPath>` defines a region
- Multiple paths within the same `<clipPath>` are **unioned** (with
  the fill rule)
- For **intersection** (which is what PDF's stacked clips
  represent), use nested clipPath via `clip-path` attribute on the
  inner clipPath

For our implementation:

```
<defs>
  <clipPath id="c1">
    <path d="..." clip-rule="nonzero"/>  <!-- clip 1 geometry -->
  </clipPath>
  <clipPath id="c2" clip-path="url(#c1)">
    <path d="..." clip-rule="nonzero"/>  <!-- clip 2 geometry -->
  </clipPath>
</defs>
```

Then a rendered element with 2 clips uses `clip-path="url(#c2)"`.

### Y-axis flip consistency

The geometry in `ClipEntry::path` is in page coordinate space
(Y-up). SVG uses Y-down. The existing `svg_path_data` converts via
Y = page_height - y, which must also apply to clip paths. Use the
same helper — do not introduce a new converter.

## Files to modify

- `src/svg/render.mbt` — add clip registry, emit clipPath defs,
  apply clip-path attributes to images/paths/text
- `src/svg/page_render.mbt` — if needed, expose helper for
  registry construction
- `src/svg/render_wbtest.mbt` — add tests for clipPath emission

## Acceptance verification

1. `moon test --target native` — unchanged + new tests pass
2. Wasm rebuild
3. local-fixture page 6 pixelmatch diff < 9.0% (baseline 12.5%)
4. local-fixture page 7 pixelmatch diff < 14.0% (baseline 17.5%)
5. Visual: rounded smartphone image crops visible on page 6/7
