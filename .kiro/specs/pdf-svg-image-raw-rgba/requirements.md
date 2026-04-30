# SDD Draft: Raw RGBA image entries with platform-dispatched encoding

## Problem

`pdf_page_to_svg_deferred` takes ~12 seconds for <local-fixture>
page 7 (12 images), while other pages take well under 1 second. The
main thread is blocked for the full duration because wasm-side PNG
encoding runs synchronously inside the single-threaded wasm module.

Profiling:

| Page | Time   | Images |
|------|--------|--------|
| 1–3  | <100ms | 0      |
| 4    | 545ms  | 12     |
| 5    | 171ms  | 2      |
| 6    | 273ms  | 2      |
| 7    | 12,064ms | 12   |

Pages 4 and 7 both have 12 images. Page 4 is 545ms; page 7 is 12s.
The cost scales with total image pixel volume: page 7 contains
full-resolution screenshots that expand to multi-megabyte RGBA
buffers, each then PNG-encoded synchronously by
`mizchi/image::encode_png_bytes`.

The correct fix is to stop encoding PNG inside wasm for DeviceRGB
raster images on the web target. Hand the raw RGBA buffer over to
the browser, which decodes natively (canvas + ImageData) on its own
thread. Native and CLI targets still benefit from the built-in PNG
encoder because they cannot dispatch to a browser.

ISO 32000-2 §8.9.5 defines PDF image XObject data. `DeviceRGB` rasters
produced by `mizchi/pdf/graphics::extract_image_xobject` are already
decoded to RGBA bytes — re-encoding into PNG inside wasm is redundant
when the consumer can render RGBA directly.

## Requirements

### Requirement 1: raw_rgba_image_mime sentinel

The SVG package SHALL retain `raw_rgba_image_mime` as the shared
`image/x-rgba8` sentinel. The wasm-gc raster encoder returns raw
RGBA bytes with width and height metadata for browser canvas
decoding, while native target raster encoding continues to return
`image/png` bytes.

#### 1.1: SvgImageEntry raw RGBA shape

`SvgImageEntry` SHALL carry `mime_type`, `data`, `width`, and
`height` so raw RGBA image data exposes the MIME sentinel plus
width/height metadata for canvas decoding. PNG, JPEG, and JP2 entries
continue to use encoded image bytes with no RGBA dimensions.

### Requirement 3: wasm API surface

#### 3.1: pageSvgImageInfo accessor
A new wasm entry point `pdf_page_svg_image_info(handle, page, index)`
SHALL return a JSON-encoded string with at least `mime`, `width`,
`height`. Width and height are 0 for non-RGBA entries.

#### 3.2: pageSvgImageData backward compatible
`pdf_page_svg_image_data` SHALL continue to return the raw bytes:
- For PNG/JPEG/JP2: the encoded file bytes (unchanged)
- For raw RGBA: `width * height * 4` bytes of RGBA (new)

### Requirement 4: encode_raster_image_entry target dispatch

The target-specific `encode_raster_image_entry` implementations SHALL
document cross-target behaviour: wasm-gc returns raw RGBA
`image/x-rgba8` entries with dimensions, while native uses
`encode_png_bytes` and returns PNG entries for file and CLI consumers.

### Requirement 5: Acceptance criteria

#### 5.1: Page 7 deferred rendering under 2 seconds
`pageToSvgDeferred(6)` on the web target SHALL complete in under
2,000ms on the reference machine (currently 12,064ms). The image
decode step happens asynchronously in the browser after the SVG is
returned.

#### 5.2: Page 4 deferred rendering under 1 second
`pageToSvgDeferred(3)` SHALL complete in under 1,000ms
(currently 545ms). Acceptance: still under 1,000ms after the
change, ideally under 200ms.

#### 5.3: No regression in visual output
<local-fixture> page 6 and 7 pixelmatch diff SHALL NOT
regress beyond current baselines (12.5% page 6, 17.5% page 7).

#### 5.4: Existing tests pass
All existing `moon test --target native` tests SHALL continue to
pass. `npm test` SHALL continue to pass.
