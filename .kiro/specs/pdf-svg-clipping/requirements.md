# SDD Draft: SVG clipping path support

## Problem

The SVG renderer ignores the PDF graphics state's clipping path.
Observable symptoms on <local-fixture> pages 6 and 7:

1. **Rounded smartphone UI screenshots** appear as full rectangles
   in the SVG output, while pdftoppm renders them as rounded-corner
   shapes matching the original document. The rounded crop is
   applied via a PDF clip operator (`W`/`W*`) before image
   painting.
2. **Form XObject contents** that rely on the Form's BBox to mask
   out-of-bounds drawing may leak beyond the intended region.
3. **Overlapping elements** that use temporary clipping rectangles
   (e.g. text blocks in column layouts) may bleed past the column.

The graphics package already tracks clipping state:
- `@graphics.GraphicsState` has `clipping_path: ClipState`
- `GraphicsEvent::ClipChanged(offset, ClipState)` is emitted after
  each `W`/`W*` + paint sequence
- `ClipState::clips` accumulates `ClipEntry` values with path,
  fill rule, and transformed geometry
- Form XObjects append their BBox as a clip via
  `form_xobject.append_clip`

The SVG renderer needs to read `state.clipping_path` when rendering
paths and images, and emit SVG `<clipPath>` definitions + the
`clip-path` attribute on affected elements. Without this,
axis-aligned crops, rounded-corner crops, and Form-bounded drawings
all render beyond their intended regions.

ISO 32000-2 §8.5.4 defines the clipping path operators.
SVG `<clipPath>` element is defined by SVG 1.1 §14.3.

## Requirements

### Requirement 1: Emit SVG clipPath definitions from ClipState

#### 1.1: One clipPath per unique ClipState
For each distinct `clipping_path` seen during page rendering, the
SVG renderer SHALL emit a `<clipPath>` element inside `<defs>` with
a unique id. Subsequent elements rendered under the same
`clipping_path` SHALL reuse the same clipPath id.

#### 1.2: Intersection of accumulated clips
`ClipState::clips` contains accumulated clip paths. The emitted SVG
`<clipPath>` SHALL represent the intersection of all clips by
nesting (`<clipPath id="c2" clip-path="url(#c1)"><path .../></clipPath>`)
or by combining the paths using SVG 1.1 semantics (one `<path>` per
`ClipEntry`, with each successive clip applied inside the next
clipPath).

#### 1.3: Initial page clip
The page's initial clip (from `ClipState::initial_clip`) SHALL be
included as the outermost clipping boundary. If it equals the
MediaBox, it may be omitted as a no-op.

#### 1.4: Fill rule on clip path
Each `<path>` inside a `<clipPath>` SHALL carry
`clip-rule="evenodd"` when the corresponding `ClipEntry` has
`FillRule::EvenOdd`; otherwise no clip-rule attribute is needed
(nonzero is the SVG default).

### Requirement 2: Apply clipPath to rendered elements

#### 2.1: clip-path attribute on images
When `page_render_image_svg` renders an `<image>` element, it SHALL
emit a `clip-path="url(#id)"` attribute referring to the clipPath
for the current `state.clipping_path`. If the clipping_path is empty
or equals the initial page clip, the attribute MAY be omitted.

#### 2.2: clip-path attribute on paths
When `page_render_path_svg` renders a `<path>` element, it SHALL
emit `clip-path="url(#id)"` similarly. Path rendering that relies
on clipping to mask overflow SHALL respect this attribute.

#### 2.3: clip-path attribute on text
When `page_render_text_svg` and `page_render_text_span_as_paths`
render text elements, they SHALL emit `clip-path="url(#id)"` for
the current graphics-state clipping path so that text rendered
inside a clipped region does not bleed out.

### Requirement 3: Clip path geometry transformation

#### 3.1: CTM-transformed clip geometry
Each `ClipEntry` already stores the path geometry transformed by
the CTM that was active when the clip operator was applied. The
SVG renderer SHALL emit the clip path geometry in SVG coordinates
via the same `svg_path_data` helper used for non-clip paths,
including the Y-axis flip.

#### 3.2: No double-transform
The SVG renderer SHALL NOT apply the current CTM to the clip path
geometry. The geometry is already in page space.

### Requirement 4: Acceptance criteria

#### 4.1: local-fixture page 6 rounded image crop visible
After implementation, <local-fixture> page 6 SHALL render
the smartphone UI screenshot with its rounded-corner crop matching
pdftoppm output. The image SHALL NOT show the unclipped square
form.

#### 4.2: Visual diff improvement
local-fixture page 6 pixelmatch diff SHALL decrease from 12.5% (baseline),
targeting less than 9.0%. Page 7 SHALL improve from 17.5% toward
less than 14.0%.

#### 4.3: No regression on existing tests
All existing `moon test --target native` tests (currently 713)
SHALL continue to pass.
