# Design: SVG Image Performance — Blob URL Deferred Loading

## Problem

Pages with large images (e.g. <local-fixture> page 7) cause the browser
to block/freeze when the SVG string containing megabytes of inline base64
data URLs is set via `dangerouslySetInnerHTML`.

## Solution

Add a new rendering mode where image data is separated from the SVG string.
The SVG contains `<image>` placeholders with `data-image-index` attributes.
Image binary data is retrievable separately. The browser creates Blob URLs
from the binary data and patches `<image>` elements after DOM insertion.

### wasm API additions

```moonbit
// Returns SVG string with image placeholders instead of inline base64
pub fn pdf_page_to_svg_deferred(handle: Int, page: Int) -> String

// Returns number of images in the deferred SVG
pub fn pdf_page_svg_image_count(handle: Int, page: Int) -> Int

// Returns image bytes for a specific index (PNG/JPEG/JP2 encoded)
pub fn pdf_page_svg_image_data(handle: Int, page: Int, index: Int) -> Bytes

// Returns MIME type for a specific image index
pub fn pdf_page_svg_image_mime(handle: Int, page: Int, index: Int) -> String
```

### SVG output

Deferred mode replaces:
```xml
<image href="data:image/png;base64,AAAA..." .../>
```
With:
```xml
<image href="" data-image-index="0" .../>
```

### npm package API

```javascript
class PdfDocument {
  // Existing — unchanged (backward compatible)
  pageToSvg(pageIndex) { ... }

  // New — returns SVG with placeholder images
  pageToSvgDeferred(pageIndex) {
    return this.wasm.pdf_page_to_svg_deferred(this.handle, pageIndex);
  }

  // New — returns image data for Blob URL creation
  pageSvgImageData(pageIndex, imageIndex) {
    return {
      data: this.wasm.pdf_page_svg_image_data(this.handle, pageIndex, imageIndex),
      mime: this.wasm.pdf_page_svg_image_mime(this.handle, pageIndex, imageIndex),
    };
  }
}
```

### Demo app integration (PdfViewer.tsx)

```javascript
const svg = document.source.pageToSvgDeferred(pageIndex);
// Set SVG immediately (no large base64 — fast)
setPageSvgs(states => ({
  ...states,
  [pageIndex]: { status: "ready", svg },
}));

// Then asynchronously load images
requestAnimationFrame(() => {
  const container = containerRef.current;
  const images = container.querySelectorAll("image[data-image-index]");
  for (const img of images) {
    const idx = parseInt(img.getAttribute("data-image-index"));
    const { data, mime } = document.source.pageSvgImageData(pageIndex, idx);
    const blob = new Blob([data], { type: mime });
    img.setAttribute("href", URL.createObjectURL(blob));
  }
});
```

### Implementation in render.mbt

Add a `deferred_images` mode to the rendering pipeline:

```moonbit
// Thread-local (or parameter) to collect image data during rendering
// When deferred mode is active:
//   - page_image_data_url returns "" and records image data in collector
//   - write_svg_image adds data-image-index attribute

pub fn render_page_svg_deferred(page: PdfPage) -> SvgDeferredResult {
  // ... same as render_page_svg but with image collection
}

pub(all) struct SvgDeferredResult {
  svg: String
  images: Array[SvgImageEntry]
}

pub(all) struct SvgImageEntry {
  mime_type: String
  data: Bytes
}
```

### visual_compare.mjs compatibility

The existing `pageToSvg()` is unchanged — tests continue using inline base64.
`rsvg-convert` works with data URLs, no change needed.

## Files to modify

- `src/svg/render.mbt` — add deferred rendering mode
- `src/svg/page_render.mbt` — add `render_page_svg_deferred` public function
- `src/npm/wasm_api.mbt` — add wasm API functions
- `npm/index.mjs`, `npm/index.cjs` — add JS wrapper methods
- `npm/index.d.ts` — add TypeScript types
- `npm/demo/src/PdfViewer.tsx` — switch to deferred mode

## Acceptance criteria

The <local-fixture> page 7 no browser block criterion is that
after deferred loading is enabled, inserting the page's SVG into the
DOM does not block the main thread beyond 100ms. Image data loading
happens asynchronously through `URL.createObjectURL(blob)` after the
SVG is visible.

The existing `pageToSvg(pageIndex)` path remains unchanged so that
the test suite (npm visual regression via rsvg-convert + inline
base64 output, and `moon test --target native`) continues to pass.
The deferred API is additive and does not replace the existing
synchronous path.
