# Tasks: SVG Image Performance — Blob URL Deferred Loading

## Task 1: Add deferred image rendering to SVG renderer

**File:** `src/svg/render.mbt`, `src/svg/page_render.mbt`

1. Add `SvgDeferredResult` and `SvgImageEntry` structs in page_render.mbt
2. Add `render_page_svg_deferred(page) -> SvgDeferredResult` public function
3. Modify image rendering path: when in deferred mode, instead of generating
   base64 data URL, store image bytes+mime in collector array and emit
   `<image href="" data-image-index="N" .../>` placeholder
4. Existing `render_page_svg` unchanged (backward compatible)

## Task 2: Add wasm API functions

**File:** `src/npm/wasm_api.mbt`, `src/npm/moon.pkg`

1. Add `pdf_page_to_svg_deferred(handle, page) -> String`
2. Store deferred result in a cache (map of handle+page → SvgDeferredResult)
3. Add `pdf_page_svg_image_count(handle, page) -> Int`
4. Add `pdf_page_svg_image_data(handle, page, index) -> Bytes`
5. Add `pdf_page_svg_image_mime(handle, page, index) -> String`
6. Register new exports in moon.pkg

## Task 3: Update npm package

**Files:** `npm/index.mjs`, `npm/index.cjs`, `npm/index.d.ts`

1. Add `pageToSvgDeferred(pageIndex)` method to PdfDocument class
2. Add `pageSvgImageData(pageIndex, imageIndex)` method
3. Add TypeScript type definitions

## Task 4: Update demo app to use deferred mode

**File:** `npm/demo/src/PdfViewer.tsx`

1. Switch `pageToSvg` → `pageToSvgDeferred` in loadPageSvg callback
2. After setting innerHTML, use `requestAnimationFrame` to patch images with Blob URLs
3. Clean up Blob URLs on page unmount (URL.revokeObjectURL)

## Task 5: Verify with tests

Run `moon test --target native` — all tests must pass.
Run npm test — existing visual_compare tests must pass (they use pageToSvg, not deferred).
Test with <local-fixture> page 7 in demo — should not block browser.
