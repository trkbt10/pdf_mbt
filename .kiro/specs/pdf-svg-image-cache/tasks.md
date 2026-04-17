# Tasks: Deferred image extraction cache

## Task 1: Introduce page-scoped image array cache

**File:** `src/npm/wasm_api.mbt`

1. Declare `let deferred_svg_image_page_cache : Map[String, Array[@svg.SvgImageEntry]] = Map::new()` near the existing `deferred_svg_pages` declaration, with a doc comment explaining the one-walk-per-page contract.
2. Add `fn build_deferred_svg_image_page(handle, page) -> Array[SvgImageEntry]?` that walks `graphics_events` exactly once, iterates `ImagePainted` events, and extracts each image through `deferred_svg_image_entry_data`.

## Task 2: Rewrite accessor to use the page cache

**File:** `src/npm/wasm_api.mbt`

1. Rewrite `get_deferred_svg_image_entry(handle, page, index)` to:
   - Build-or-fetch the page Array via `deferred_svg_image_page_cache`
   - Return the entry at `index` when in range, else `None`
2. Remove the obsolete `deferred_svg_image_entries` Map, the helper
   `build_deferred_svg_image_entry`, and
   `page_svg_image_entry_by_occurrence`.

## Task 3: Handle close correctly

**File:** `src/npm/wasm_api.mbt`

In `pdf_close(handle)`, also iterate
`deferred_svg_image_page_cache` and remove every key with the
`"{handle}:"` prefix, mirroring `remove_deferred_pages_for_handle`.

## Task 4: Add whitebox tests (Requirement 3)

**File:** `src/npm/wasm_api_wbtest.mbt` (NEW if not present, else append)

1. Test "local-fixture page 7 image accessors use one graphics walk": skip
   if fixture absent; open doc; call `pdf_page_to_svg_deferred`;
   call `pdf_page_svg_image_data` N times; assert first-pass time
   < 3,000 ms on the reference machine.
2. Test "local-fixture page 7 image accessors reuse cache on second pass":
   same setup; run a second loop; assert second-pass ≥10× faster
   than first.
3. Test "local-fixture page 7 one graphics walk across N accessor calls":
   expose a test-only counter (`test_reset_graphics_walk_counter`,
   `test_graphics_walk_counter`) from `wasm_api.mbt`; wrap the
   walk inside `build_deferred_svg_image_page` so each call
   increments the counter; assert counter == 1 after N accessor
   calls.

If a timer helper is not already present, either use
`@env.now_ms()` / `@time.now_ms()` (whichever exists) or fall back
to an instance-counted proxy metric (e.g. number of graphics
events interpreted via the counter in test 3 — the time assertions
become counter assertions of walks == 1).

## Task 5: Verify performance with Node profiler

Run:

```bash
cd <workspace>/pdf
moon build --target wasm-gc --release && cp _build/wasm-gc/release/build/src/npm/npm.wasm npm/dist/pdf.wasm

node --experimental-wasm-stringref --experimental-wasm-imported-strings -e "
const { PdfDocument } = await import('./npm/index.mjs');
const { readFile } = await import('node:fs/promises');
const doc = await PdfDocument.open(await readFile('<local-fixture>'));
for (const p of [3,4,5,6]) {
  doc.pageToSvgDeferred(p);
  const n = doc.pageCount(); const t0 = Date.now();
  const count = (doc.pageToSvgDeferred(p).match(/data-image-index=/g)||[]).length;
  for (let i = 0; i < count; i++) doc.pageSvgImageData(p, i);
  console.log('page ' + (p+1) + ' first-pass: ' + (Date.now()-t0) + 'ms, images=' + count);
  const t1 = Date.now();
  for (let i = 0; i < count; i++) doc.pageSvgImageData(p, i);
  console.log('page ' + (p+1) + ' second-pass: ' + (Date.now()-t1) + 'ms');
}"
```

Acceptance:
- Page 7 first-pass < 3,000 ms (currently 12,000 ms)
- Second-pass < 50 ms
- Pages 4–6 no regression beyond current baseline

## Task 6: Drift gate

```bash
indexion spec align status .kiro/specs/pdf-svg-image-cache/requirements.md src/npm/ --threshold 0.3 --fail-on drifted
```

Must exit 0.

## Task 7: Regression

`moon test --target native` — 720+ tests pass (adds 3 new tests).
