# Tasks: Raw RGBA image entries with platform-dispatched encoding

## Task 1: Introduce image/x-rgba8 MIME constant and SvgImageEntry extension

**Files:** `src/svg/render.mbt`, `src/svg/page_render.mbt`

1. Define the sentinel `"image/x-rgba8"` as a constant or shared
   string value used by both the encoder and the consumer-side
   discriminator.
2. Ensure `SvgImageEntry` retains its current shape
   `{ mime_type, data }`. Width/height are not added here — they
   ride alongside via `SvgDeferredResult.images` plus metadata
   stored in `SvgImageEntry` as an optional extension
   (`width : Int?`, `height : Int?`) or a parallel Array. Simplest:
   add two optional fields to `SvgImageEntry` defaulting to `None`.

## Task 2: Shared dispatcher for raster encoding

**File:** `src/svg/render.mbt`

1. Rename the existing combined function (or introduce a new one) so
   `raster_image_entry(width, height, rgba) -> SvgImageEntry?` is the
   shared entry for `DeviceRgbRaster` and the painted
   `StencilMaskRaster`.
2. `raster_image_entry` validates `width > 0`, `height > 0`, and
   `rgba.length() == width * height * 4`, returning `None` on
   mismatch.
3. Inside `raster_image_entry`, dispatch to the target-specific
   `encode_raster_image_entry(width, height, rgba) -> SvgImageEntry?`
   (introduced in Tasks 3a/3b).

## Task 3a: Native PNG encoder implementation

**File:** `src/svg/render_native.mbt` (new)

1. Add `fn encode_raster_image_entry(width, height, rgba) -> SvgImageEntry?`
   that calls the existing `encode_png_bytes` on the reconstructed
   `ImageData` and wraps the bytes in
   `SvgImageEntry::{ mime_type: "image/png", data, width: None, height: None }`.
2. If `image_data_from_rgba` or `encode_png_bytes` returns `None`,
   the encoder returns `None`.

## Task 3b: Wasm-gc raw RGBA encoder implementation

**File:** `src/svg/render_wasm.mbt` (new)

1. Add `fn encode_raster_image_entry(width, height, rgba) -> SvgImageEntry?`
   that returns
   `SvgImageEntry::{ mime_type: "image/x-rgba8", data: rgba, width: Some(width), height: Some(height) }`
   without any compression.

## Task 4: Target-selective file inclusion

**File:** `src/svg/moon.pkg`

1. Use the MoonBit `targets` filter mechanism in `moon.pkg.json`
   (this project uses `moon.pkg` as the filename) to include
   `render_native.mbt` only on native target and `render_wasm.mbt`
   only on wasm-gc target.
2. Verify `moon check --target native` and `moon check --target wasm-gc`
   both succeed.

## Task 5: pdf_page_svg_image_info wasm entry

**File:** `src/npm/wasm_api.mbt`, `src/npm/moon.pkg`

1. Add `pub fn pdf_page_svg_image_info(handle : Int, page : Int, index : Int) -> String`
   that returns a small JSON string:
   - For valid indexes: `{"mime":"image/png","width":0,"height":0}` for
     PNG/JPEG/JP2 entries, or
     `{"mime":"image/x-rgba8","width":W,"height":H}` for RGBA entries
   - For invalid indexes or missing deferred result: `""`
2. Register the new export in `moon.pkg`.

## Task 6: npm JS wrapper

**Files:** `npm/index.mjs`, `npm/index.cjs`, `npm/index.d.ts`

1. Add method `pageSvgImageInfo(pageIndex, imageIndex)` that calls
   the wasm entry and `JSON.parse`s the result. If the string is
   empty, return `null`.
2. Add the matching TypeScript declaration: return type
   `{ mime: string; width: number; height: number } | null`.

## Task 7: Browser canvas-based RGBA decoding in demo

**File:** `npm/demo/src/PdfViewer.tsx`

1. Where the existing Blob URL patching happens, branch on
   `mime === "image/x-rgba8"`:
   - Construct an `ImageData` from the raw bytes using `width` and
     `height` from `pageSvgImageInfo`
   - Draw onto an `OffscreenCanvas(width, height)` (or visible-free
     `<canvas>`) and `await canvas.convertToBlob({ type: "image/png" })`
   - Use the resulting Blob URL for the `<image>` href
2. PNG/JPEG/JP2 MIMEs continue through the existing direct Blob path.
3. Wrap the RGBA decode in a try/catch so a single failure does not
   stop remaining images from loading.

## Task 8: Tests

**File:** `src/svg/render_wbtest.mbt`

1. Add `test "native DeviceRGB raster produces image/png entry"`
   that constructs a small RGBA buffer, calls the shared
   dispatcher, and asserts `mime_type == "image/png"` plus PNG
   magic bytes at the beginning of `data`. This test is gated to
   run on native (via `targets` in `moon.pkg` for a dedicated
   `*_native_wbtest.mbt` file, if needed).
2. Add `test "wasm DeviceRGB raster produces image/x-rgba8 entry"`
   gated to run on wasm-gc, asserting MIME sentinel, width, height,
   and byte count.

If the target gating for individual tests is not straightforward,
instead add one test per target by moving them into
`render_native_wbtest.mbt` and `render_wasm_wbtest.mbt` with
`moon.pkg` `targets` filters.

## Task 9: Verify performance and visual output

1. `moon test --target native` — all tests pass
2. `moon build --target wasm-gc --release && cp _build/wasm-gc/release/build/src/npm/npm.wasm npm/dist/pdf.wasm`
3. `npm run build --prefix npm/demo` — build succeeds
4. Run the Node profiler:

```bash
node --experimental-wasm-stringref --experimental-wasm-imported-strings -e "
const { PdfDocument } = await import('./npm/index.mjs');
const { readFile } = await import('node:fs/promises');
const doc = await PdfDocument.open(await readFile('<local-fixture>'));
for (let i = 0; i < doc.pageCount(); i++) {
  const t0 = Date.now();
  const svg = doc.pageToSvgDeferred(i);
  console.log('page ' + (i+1) + ': ' + (Date.now() - t0) + ' ms, SVG=' + (svg.length/1024).toFixed(0) + 'KB');
}"
```

   Acceptance:
   - Page 7: < 2,000 ms (currently 12,064 ms)
   - Page 4: < 1,000 ms (currently 545 ms)

5. Pixelmatch local-fixture page 6/7 diff: no regression vs current baselines
   (12.5% page 6, 17.5% page 7). Demo page renders the same way
   after the canvas-based decode path resolves to the same PNG
   output.

## Task 10: Spec alignment gate

```bash
indexion spec align status .kiro/specs/pdf-svg-image-raw-rgba/requirements.md src/svg/ --threshold 0.3 --fail-on drifted
indexion spec align status .kiro/specs/pdf-svg-image-raw-rgba/requirements.md src/npm/ --threshold 0.3 --fail-on drifted
```

Both SHALL exit 0 (no DRIFTED). Add spec vocabulary to doc comments
(e.g. "raw RGBA", "platform-dispatched", "image/x-rgba8",
"OffscreenCanvas") as needed.
