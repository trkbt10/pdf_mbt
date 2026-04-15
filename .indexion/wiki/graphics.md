# Graphics System

The `src/graphics/` package implements the PDF graphics state machine from ISO 32000-2 clauses 8-11.

## Interpretation

`GraphicsInterpreter` processes a `ContentStream` and emits an ordered `GraphicsEvent` stream. It maintains mutable `GraphicsState`: current transformation matrix (CTM), line attributes (width, cap, join, miter, dash pattern), separate stroke/fill colour with colour space tracking, clipping regions, flatness tolerance, rendering intent, and extended graphics state from `gs` operator.

## GraphicsEvent Types

| Event | Trigger |
|-------|---------|
| StateSaved / StateRestored | q / Q operators |
| StateChanged | CTM, colour, line width, dash, etc. mutations |
| PathPainted | Stroke, fill, close-stroke, fill-stroke, end-path |
| ClipChanged | W / W* clipping operators |
| TextObjectBegan / TextObjectEnded | BT / ET text object boundaries |
| ImagePainted | Image XObject via Do operator |
| InlineImagePainted | BI/ID/EI inline image |
| FormXObjectBegan / FormXObjectEnded | Form XObject via Do operator |
| XObjectSkipped | Hidden by optional content decision |
| PatternColourSelected | Pattern colour space activation |
| ShadingPainted | sh shading operator |

## Colour Spaces

Full §8.6 hierarchy implemented in `colour_space.mbt`:

- **Device**: DeviceGray, DeviceRGB, DeviceCMYK
- **CIE-based**: CalGray (gamma), CalRGB (gamma + matrix), Lab (range), ICCBased (profile header validation)
- **Special**: Indexed (lookup table), Separation (single colourant), DeviceN/NChannel (multiple colourants with attributes), Pattern (bare or with underlying space)

`ColourRange` handles component normalization/clamping. `colour_conversion.mbt` provides inter-space conversion including CIE XYZ D65 to sRGB.

## Optional Content

Tracks Optional Content Group (OCG) visibility via BDC/DP/EMC marked content operators. Hidden content applies graphics-state side effects (CTM, colour) but skips painting operations (images, paths, XObjects).

## See Also

- wiki://overview
- wiki://content-streams
- wiki://text-extraction
