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

### Requirement 1: Platform-dispatched image encoding

#### 1.1: Web target skips in-wasm PNG encoding
On the wasm-gc target, `page_image_entry_data` SHALL return the raw
RGBA buffer together with width and height metadata for
`DeviceRgbRaster` and `StencilMaskRaster` results, instead of
encoding PNG bytes inside wasm. The MIME type for raw RGBA entries
SHALL be a well-known sentinel understood by the JS consumer (e.g.
`image/x-rgba8`).

#### 1.2: Native target uses built-in PNG encoding
On the native target, `page_image_entry_data` SHALL continue to use
the built-in `encode_png_bytes` path, producing `image/png` entries
that CLI consumers and file writers can use directly.

#### 1.3: JPEG and JPEG2000 pass-through unchanged
`EncodedImageData` with `DCTDecode` or `JPXDecode` filters SHALL
continue to return the original encoded bytes with `image/jpeg` or
`image/jp2` MIME on both targets. These are browser-decodable
without transformation.

### Requirement 2: JavaScript consumer decoding

#### 2.1: Raw RGBA entry shape
`PdfDocument.pageSvgImageData(pageIndex, imageIndex)` SHALL, for a
raw RGBA entry, return an object including the MIME sentinel plus
the width and height required to interpret the byte buffer as
`Uint8ClampedArray` of length `width * height * 4`.

#### 2.2: Browser Canvas decoding
The npm demo (`npm/demo/src/PdfViewer.tsx`) SHALL decode raw RGBA
entries by constructing an `ImageData`, drawing it onto an
`OffscreenCanvas` (or a temporary `<canvas>`), and obtaining a Blob
URL via `canvas.toBlob` / `canvas.convertToBlob`. PNG and JPEG
entries SHALL continue to go through the existing `Blob` path
without canvas intervention.

#### 2.3: Asynchronous decoding
RGBA-to-Blob conversion SHALL use the async canvas API so the main
thread is not blocked by large-pixel rasters.

### Requirement 3: wasm API surface

#### 3.1: pageSvgImageInfo accessor
A new wasm entry point `pdf_page_svg_image_info(handle, page, index)`
SHALL return a JSON-encoded string with at least `mime`, `width`,
`height`. Width and height are 0 for non-RGBA entries.

#### 3.2: pageSvgImageData backward compatible
`pdf_page_svg_image_data` SHALL continue to return the raw bytes:
- For PNG/JPEG/JP2: the encoded file bytes (unchanged)
- For raw RGBA: `width * height * 4` bytes of RGBA (new)

### Requirement 4: Cross-target test coverage

#### 4.1: Native test continues PNG encoding
A whitebox test on the native target SHALL verify
`page_image_entry_data` produces `image/png` entries for a
DeviceRGB raster fixture.

#### 4.2: Wasm-gc behaviour documented via test
A whitebox test (runnable on native for unit verification) SHALL
verify the raw RGBA branch returns the expected MIME sentinel,
width, height, and RGBA byte count for the same fixture — selected
via a feature flag, compile-time function dispatch, or equivalent.

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
