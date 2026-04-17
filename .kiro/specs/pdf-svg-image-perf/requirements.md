# SDD Draft: SVG Image Performance — Blob URL Deferred Loading

## Problem

Pages with large raster images in <local-fixture> (e.g. page 7
with 12 images totalling 1.18MB of base64 data, SVG size 1.44MB)
cause the browser main thread to block or freeze. The SVG string
containing inline `data:image/...;base64,...` URLs is set via
`dangerouslySetInnerHTML`, forcing the browser to synchronously
decode megabytes of base64 during DOM parsing.

Chromium and other browsers do not stream-decode inline base64
images; the entire data URL must be parsed before the image element
can be rendered. For 12 images in a single SVG, this can block the
main thread for seconds, during which UI events are queued and the
tab appears frozen.

The ideal mitigation is to defer image loading after SVG DOM
insertion, using `URL.createObjectURL(blob)` to hand off decoding to
the browser's async image pipeline.

## Requirements

### Requirement 1: Deferred image rendering mode

#### 1.1: New public rendering function
The SVG package SHALL expose a `render_page_svg_deferred` public
function that returns both an SVG string and an ordered collection
of image entries, in place of inline base64 data URLs.

#### 1.2: Image placeholder syntax
In the deferred SVG string, each `<image>` element SHALL use an
empty `href=""` attribute and a `data-image-index="N"` attribute,
where N is the zero-based index into the image entries collection.

#### 1.3: Image entry format
Each image entry SHALL carry the MIME type (e.g. `image/png`,
`image/jpeg`, `image/jp2`) and the raw encoded image bytes (not
base64 text).

### Requirement 2: wasm API surface

#### 2.1: Deferred SVG wasm entry point
`pdf_page_to_svg_deferred(handle: Int, page: Int) -> String` SHALL
return the SVG string with image placeholders for the specified
document handle and page index.

#### 2.2: Image count query
`pdf_page_svg_image_count(handle: Int, page: Int) -> Int` SHALL
return the number of image entries corresponding to the deferred
SVG for the specified page. Call results SHALL be consistent with
the last `pdf_page_to_svg_deferred` invocation for the same page.

#### 2.3: Image data accessor
`pdf_page_svg_image_data(handle: Int, page: Int, index: Int) -> Bytes`
SHALL return the raw encoded image bytes for the image at the given
index. Indexes outside the valid range SHALL return an empty Bytes
value.

#### 2.4: Image MIME accessor
`pdf_page_svg_image_mime(handle: Int, page: Int, index: Int) -> String`
SHALL return the MIME type for the image at the given index, or an
empty string for invalid indexes.

### Requirement 3: npm package API

#### 3.1: Deferred SVG method
`PdfDocument.pageToSvgDeferred(pageIndex)` SHALL wrap the wasm
`pdf_page_to_svg_deferred` entry point and return the SVG string.

#### 3.2: Image data method
`PdfDocument.pageSvgImageData(pageIndex, imageIndex)` SHALL return
an object `{ data: Uint8Array, mime: string }` constructed from the
wasm image accessors.

#### 3.3: TypeScript types
`npm/index.d.ts` SHALL declare the new `pageToSvgDeferred` and
`pageSvgImageData` methods with appropriate return types.

#### 3.4: Backward compatibility
The existing `pageToSvg(pageIndex)` method SHALL remain unchanged so
that existing consumers (visual regression tests, `rsvg-convert`
integration) continue to receive inline base64 SVG output.

### Requirement 4: Demo application integration

#### 4.1: Deferred mode in PdfViewer
`npm/demo/src/PdfViewer.tsx` SHALL switch from `pageToSvg` to
`pageToSvgDeferred` when rendering pages and SHALL patch image
`href` attributes with `URL.createObjectURL(blob)` after DOM
insertion.

#### 4.2: Blob URL cleanup
The demo SHALL call `URL.revokeObjectURL` on generated Blob URLs
when the page component unmounts or when a page is no longer
rendered, preventing memory leaks.

### Requirement 5: Acceptance criteria

#### 5.1: local-fixture page 7 no browser block
After implementation, loading <local-fixture> page 7 in the
demo SHALL not block the browser main thread for longer than 100ms
during SVG DOM insertion. The image data loading happens
asynchronously after the SVG is visible.

#### 5.2: Test suite unchanged
All existing tests (`moon test --target native`, npm visual
regression via `pageToSvg`) SHALL continue to pass without
modification. The deferred API is additive.
