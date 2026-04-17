# Design: Raw RGBA image entries with platform-dispatched encoding

## Overview

Split `page_image_entry_data` into a shared pipeline that chooses
one of two encoders for DeviceRGB raster images based on compile
target:

- **Native**: `encode_png_bytes(image)` → `image/png` entry (unchanged)
- **wasm-gc**: raw RGBA bytes + `image/x-rgba8` MIME sentinel + width/height metadata

JPEG and JPEG2000 pass-through is untouched on both targets.

The JS consumer decodes raw RGBA entries via `ImageData` +
`OffscreenCanvas` + async `toBlob`, producing Blob URLs on the
browser's own thread. PNG/JPEG/JP2 entries continue through the
existing `new Blob([data], { type: mime })` path.

## Current code

`src/svg/render.mbt`:

```moonbit
fn page_image_entry_data(entry, state) -> SvgImageEntry? {
  match extract_image_xobject(...) {
    Ok(extracted) => match extracted.data {
      DeviceRgbRaster(raster) => png_image_entry(raster.width, raster.height, raster.rgba)
      StencilMaskRaster(mask) => {
        let painted = paint_stencil_mask_with_colour(mask, paint)
        png_image_entry(painted.width, painted.height, painted.rgba)
      }
      EncodedImageData(data, filters) => encoded_image_entry(data, filters)
    }
    Err(_) => None
  }
}

fn png_image_entry(width, height, rgba) -> SvgImageEntry? {
  image_data_from_rgba(width, height, rgba)
    .bind(encode_png_bytes)
    .map(bytes => SvgImageEntry::{ mime_type: "image/png", data: bytes })
}
```

## Platform dispatch strategy

MoonBit supports `@when` attributes on top-level declarations and
the target directory mechanism (e.g. `*_native.mbt`,
`*_wasm.mbt`). We use a compile-time function dispatch:

```moonbit
// render.mbt (shared)
fn raster_image_entry(width : Int, height : Int, rgba : Bytes) -> SvgImageEntry? {
  encode_raster_image_entry(width, height, rgba)
}

// render_native.mbt (native target)
#when(target = "native")
fn encode_raster_image_entry(width, height, rgba) -> SvgImageEntry? {
  // Existing PNG encoder path
  ...
}

// render_wasm.mbt (wasm-gc target)
#when(target = "wasm-gc")
fn encode_raster_image_entry(width, height, rgba) -> SvgImageEntry? {
  if width <= 0 || height <= 0 { return None }
  if rgba.length() != width * height * 4 { return None }
  Some(SvgImageEntry::{
    mime_type: "image/x-rgba8",
    data: encode_rgba_with_header(width, height, rgba),
  })
}
```

If `#when(target = ...)` is not available in this MoonBit version,
the equivalent moonbit mechanism is a separate source file with a
`targets` filter in `moon.pkg.json` (`"targets": { "name.mbt":
["native"] }`).

### Width/height encoding options

Because `SvgImageEntry.data` is already `Bytes`, the consumer also
needs to learn width/height. Two options:

**Option A (chosen): separate `pdf_page_svg_image_info` accessor**

Add a new wasm entry point that returns a JSON string:

```
pdf_page_svg_image_info(handle, page, index) -> String
  returns '{"mime":"image/x-rgba8","width":640,"height":1280}'
  for RGBA; '{"mime":"image/png","width":0,"height":0}' for PNG/JPEG/JP2
```

This keeps `pageSvgImageData` returning raw bytes unchanged.

**Option B: prepend header to RGBA bytes**

Prepend 8 bytes (width uint32 big-endian + height uint32 big-endian)
to the RGBA buffer. Consumer strips the header before feeding to
`ImageData`. Simpler, but mixes metadata with pixel data.

Option A is cleaner and future-proofs other metadata. For this
spec, Option A is the chosen design.

## JavaScript consumer

`npm/demo/src/PdfViewer.tsx` currently patches image hrefs with:

```ts
const { data, mime } = document.source.pageSvgImageData(pageIndex, imageIndex);
const blob = new Blob([data], { type: mime });
img.setAttribute("href", URL.createObjectURL(blob));
```

New path:

```ts
async function urlForImage(document, pageIndex, imageIndex) {
  const info = document.source.pageSvgImageInfo(pageIndex, imageIndex);
  const { mime, width, height } = JSON.parse(info);
  const data = document.source.pageSvgImageData(pageIndex, imageIndex);

  if (mime === "image/x-rgba8") {
    // Decode on browser thread via canvas
    const canvas = new OffscreenCanvas(width, height);
    const ctx = canvas.getContext("2d");
    const imageData = new ImageData(new Uint8ClampedArray(data.buffer, data.byteOffset, data.byteLength), width, height);
    ctx.putImageData(imageData, 0, 0);
    const blob = await canvas.convertToBlob({ type: "image/png" });
    return URL.createObjectURL(blob);
  }

  // PNG / JPEG / JP2: direct Blob (unchanged)
  return URL.createObjectURL(new Blob([data], { type: mime }));
}
```

The async branch unblocks the main thread: `convertToBlob` runs
natively and yields the Blob as a Promise.

Fallback: if `OffscreenCanvas.convertToBlob` is unavailable, use a
visible-free `<canvas>` element + `canvas.toBlob(callback, "image/png")`.

## wasm API surface

The wasm API surface gains one new accessor,
`pdf_page_svg_image_info(handle, page, index)`, that returns a JSON
string `{"mime","width","height"}` so the consumer can tell
`image/x-rgba8` entries from PNG/JPEG/JP2 entries without inspecting
byte contents. `pdf_page_svg_image_data` stays backward compatible:
for PNG/JPEG/JP2 it returns the encoded file bytes; for raw RGBA it
returns `width * height * 4` RGBA bytes. No other wasm entry point
changes signature.

## npm package API

`npm/index.mjs`, `npm/index.cjs`:

```js
pageSvgImageInfo(pageIndex, imageIndex) {
  this.assertOpen();
  const json = this.wasm.pdf_page_svg_image_info(this.handle, pageIndex, imageIndex);
  return JSON.parse(json);
}
```

`npm/index.d.ts`:

```ts
pageSvgImageInfo(pageIndex: number, imageIndex: number): { mime: string; width: number; height: number };
```

## Native path unchanged

The CLI rendering workflow (`moon run cmd/... --target native`) and
any native library consumers call `page_image_entry_data` and get
PNG bytes directly. No migration required.

## Cross-target test

`src/svg/render_wbtest.mbt` contains a fixture exercising the
DeviceRGB path. Split into two tests:

1. Native PNG encoding path — asserts `mime_type == "image/png"` and
   the PNG magic bytes `[0x89, 0x50, 0x4E, 0x47]`
2. Wasm RGBA path — asserts `mime_type == "image/x-rgba8"` and
   `data.length() == width * height * 4`

The wasm test can run on native if the dispatcher function is
parameterised by an explicit target selector for testing, or via a
test-only variant that bypasses `#when`.

## Files to modify

- `src/svg/render.mbt` — split `page_image_entry_data` into shared
  dispatcher + platform-specific encoder, introduce
  `image/x-rgba8` MIME constant
- `src/svg/render_native.mbt` (new) — native PNG encoder implementation
- `src/svg/render_wasm.mbt` (new) — wasm raw RGBA encoder implementation
- `src/svg/moon.pkg` — target-selective file inclusion
- `src/npm/wasm_api.mbt` — add `pdf_page_svg_image_info`
- `src/npm/moon.pkg` — export new wasm API
- `npm/index.mjs`, `npm/index.cjs`, `npm/index.d.ts` — add
  `pageSvgImageInfo` method
- `npm/demo/src/PdfViewer.tsx` — canvas-based RGBA decoding
- `src/svg/render_wbtest.mbt` — per-target test branches

## Acceptance verification

1. `moon test --target native` — existing tests + new PNG-path test pass
2. `moon build --target wasm-gc --release` — succeeds
3. `cp _build/wasm-gc/release/build/src/npm/npm.wasm npm/dist/pdf.wasm`
4. Node profile script on pages 4 and 7 shows deferred rendering
   under 2s for page 7 and under 1s for page 4
5. `npm run build --prefix npm/demo` — demo build clean
6. Pixelmatch local-fixture page 6/7 diff not regressed

Performance targets recap:
- Page 7: 12,064 ms → < 2,000 ms (≥ 6x speedup)
- Page 4: 545 ms → < 1,000 ms (no regression, ideally < 200 ms)
