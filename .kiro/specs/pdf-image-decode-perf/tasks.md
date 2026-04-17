# Tasks: Image decode hot-loop preallocation

## Task 1: Pre-size RGBA output buffer (Phase 1)

**File:** `src/graphics/image_decode.mbt`

1. In `decode_sample_bytes_to_rgb`, replace `let rgba : Array[Byte] = []`
   with a `FixedArray[Byte]` of size `width * height * 4`.
2. Replace the four `rgba.push(...)` calls with index assignments
   using `pixel * 4 + {0,1,2,3}`.
3. Replace `Bytes::from_array(rgba)` with a FixedArray-compatible
   conversion. Options:
   - `Bytes::makei(total * 4, fn(i) { rgba[i] })` (one final copy)
   - `Bytes::from_fixed_array(rgba)` if that API exists
   Check existing code in `mizchi/font` or `mizchi/image` for the
   idiomatic pattern.

Verify:
- `moon test --target native` — all tests pass
- Behaviour identical: add a whitebox test with a small known
  input and assert the returned bytes match the pre-change output
  byte-for-byte.

## Task 2: Pre-size stencil alpha buffer (Phase 1)

**File:** `src/graphics/image_decode.mbt`

Apply the same treatment to `decode_stencil_alpha_mask`: pre-size
the alpha byte buffer, index-write, and convert to `Bytes` once.

Verify with an existing stencil-mask test or add a new one if none
covers the hot loop.

## Task 3: Reuse component scratch buffer (Phase 2)

**File:** `src/graphics/image_decode.mbt`

1. Add a `scratch : Array[Double]` parameter to
   `pixel_to_device_rgb`, `indexed_pixel_to_device_rgb`, and any
   other per-pixel helpers that allocate internally.
2. Hoist the scratch allocation to the caller
   (`decode_sample_bytes_to_rgb`) with length = `space.component_count()`.
3. Rewrite the inner loop to overwrite `scratch[c]` instead of
   pushing.
4. Ensure re-entrancy is not broken — scratch is local to the
   caller's frame, not a module-level mutable.

Verify:
- `moon test --target native` — all tests pass
- Byte-identity assertion continues to hold

## Task 4: Pixel-identity golden test

**File:** `src/graphics/image_decode_wbtest.mbt`

1. Construct a minimal PDF image XObject fixture in-memory with a
   known 4×4 DeviceRGB raster (16 pixels, 64 bytes). Hard-code the
   expected `rgba` bytes as a hex literal.
2. Call `extract_image_xobject(None, stream, 0L)` and assert
   `data.DeviceRgbRaster.rgba` matches the golden bytes exactly.

This test protects the optimisation against silent changes.

## Task 5: Page 7 performance bound test

**File:** `src/graphics/image_decode_wbtest.mbt` or
`src/npm/wasm_api_wbtest.mbt` (re-use the existing local-fixture fixture
guard pattern)

1. Skip if `<local-fixture>` not
   present.
2. Open the document, request `pdf_page_to_svg_deferred` for page
   6, then loop `pdf_page_svg_image_data(handle, 6, i)` over all
   12 image indices.
3. Measure cumulative wall time via the runtime's time helper.
4. Assert cumulative time < 3,000 ms.

If no time helper is exposed, fall back to measuring the number of
sample-buffer-copy operations via a test-only counter similar to
the graphics_walk_counter in wasm_api.mbt.

## Task 6: Verification

1. `moon test --target native` — all tests pass
2. `moon build --target wasm-gc --release && cp _build/wasm-gc/release/build/src/npm/npm.wasm npm/dist/pdf.wasm`
3. Node profile script:

```bash
node --experimental-wasm-stringref --experimental-wasm-imported-strings -e "
const { PdfDocument } = await import('./npm/index.mjs');
const { readFile } = await import('node:fs/promises');
const doc = await PdfDocument.open(await readFile('<local-fixture>'));
for (const p of [3, 4, 5, 6]) {
  const svg = doc.pageToSvgDeferred(p);
  const count = (svg.match(/data-image-index=/g)||[]).length;
  const t0 = Date.now();
  for (let i = 0; i < count; i++) doc.pageSvgImageData(p, i);
  console.log('page ' + (p+1) + ' cumulative: ' + (Date.now()-t0) + 'ms, images=' + count);
}"
```

Acceptance:
- Page 7 cumulative < 3,000 ms (was 11,699 ms)
- Pages 4–6 within 10 % of current baseline

## Task 7: Drift gate

```bash
indexion spec align status .kiro/specs/pdf-image-decode-perf/requirements.md src/graphics/ --threshold 0.3 --fail-on drifted
```

Must exit 0.
