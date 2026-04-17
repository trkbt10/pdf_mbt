# Design: Deferred image extraction cache

## Overview

Replace `page_svg_image_entry_by_occurrence(page, target_index)`
with a page-scoped extraction cache populated on first access. The
cache stores `Array[SvgImageEntry]` keyed by `(handle, page)`; the
first accessor call for that key performs exactly one graphics
event walk and extracts every image; subsequent accessor calls
return the pre-extracted entry without re-walking or re-extracting.

No wasm API signature changes. The existing entry-level cache
(`deferred_svg_image_entries`) is replaced by a page-level cache
that subsumes it.

## Current code

`src/npm/wasm_api.mbt`:

```moonbit
let deferred_svg_image_entries : Map[String, @svg.SvgImageEntry] = Map::new()

fn page_svg_image_entry_by_occurrence(page, target_index) -> @svg.SvgImageEntry? {
  let events = page.reader_page().graphics_events(...)
  let mut image_index = 0
  for event in events {
    match event {
      ImagePainted(_, descriptor, state) =>
        match descriptor.source {
          XObjectImage(Some(name)) =>
            match page_image_entry_by_name(page, name) {
              Some(entry) => {
                if image_index == target_index {
                  return deferred_svg_image_entry_data(entry, state)
                }
                image_index += 1
              }
              ...
```

Called 12 times per page 7 accessor sequence ⇒ 12 full event walks
and 12 `extract_image_xobject` calls (one per accessor).

## Solution

### Page-scoped image array cache

```moonbit
/// Page-scoped cache: each entry is the full ordered list of
/// SvgImageEntry values extracted on first accessor call for the
/// (handle, page). Subsequent accessor calls read from this cache
/// without walking graphics events.
let deferred_svg_image_page_cache : Map[String, Array[SvgImageEntry]] = Map::new()
```

Key format: `"handle:page"` (reuse `deferred_page_key`).

### New accessor flow

```moonbit
fn get_deferred_svg_image_entry(handle, page, index) -> SvgImageEntry? {
  let key = deferred_page_key(handle, page)
  let cached = deferred_svg_image_page_cache.get(key)
  let entries = match cached {
    Some(arr) => arr
    None => {
      match build_deferred_svg_image_page(handle, page) {
        Some(arr) => {
          deferred_svg_image_page_cache[key] = arr
          arr
        }
        None => return None
      }
    }
  }
  if index >= 0 && index < entries.length() {
    Some(entries[index])
  } else {
    None
  }
}

fn build_deferred_svg_image_page(handle, page) -> Array[SvgImageEntry]? {
  let pdf_page = get_page(handle, page)?
  let events = try? pdf_page.reader_page().graphics_events(...)
  let entries : Array[SvgImageEntry] = []
  match events {
    Ok(events) => {
      for event in events {
        match event {
          ImagePainted(_, descriptor, state) =>
            match descriptor.source {
              XObjectImage(Some(name)) =>
                match page_image_entry_by_name(pdf_page, name) {
                  Some(entry) =>
                    match deferred_svg_image_entry_data(entry, state) {
                      Some(image) => entries.push(image)
                      None => ()
                    }
                  None => ()
                }
              _ => ()
            }
          _ => ()
        }
      }
      Some(entries)
    }
    Err(_) => None
  }
}
```

One walk per (handle, page). Extraction cost is bounded by the
content and colour-space decoders in `extract_image_xobject`; this
spec does not attempt to speed those up, only to avoid redundant
walks.

### Documented accessor complexity

The accessor implementation SHALL document its single-graphics-walk-
per-page contract in code comments: one graphics event walk per
(handle, page), not per image accessor call. The wasm entry points
(pdf_page_svg_image_data, pdf_page_svg_image_info,
pdf_page_svg_image_mime, pdf_page_svg_image_count) retain their
current signatures; only their internals change so the JS consumer's
call pattern of N `pageSvgImageData(p, i)` calls incurs one graphics
walk rather than N walks.

### Deprecate entry-level cache

Remove `deferred_svg_image_entries` and the old
`get_deferred_svg_image_entry` / `build_deferred_svg_image_entry` /
`page_svg_image_entry_by_occurrence` helpers. `pdf_close` invalidates
both the pages cache and the image page cache.

### Page-scoped image array cache ordering

The image array SHALL preserve the `ImagePainted` event order, which
is the same order used by `render_page_svg_deferred` when assigning
`data-image-index` attributes. This keeps the JS consumer's image
index consistent between accessor calls and SVG DOM.

### Concurrent document closes

`pdf_close(handle)` calls `remove_deferred_pages_for_handle(handle)`
today. Add a parallel `remove_deferred_image_pages_for_handle(handle)`
that removes every cache entry with `handle:` prefix.

## Regression test (compensation)

Add `src/npm/wasm_api_wbtest.mbt` (new file) with:

```moonbit
test "local-fixture page 7 image accessors use one graphics walk" {
  let path = "<local-fixture>"
  if !@fs.path_exists(path) { return }
  let handle = pdf_open_bytes(@fs.read_file_to_bytes(path))
  let page = 6
  let _ = pdf_page_to_svg_deferred(handle, page)
  let count = pdf_page_svg_image_count(handle, page)
  // First-pass accumulated time
  let t0 = @time.now()
  for i in 0..<count {
    pdf_page_svg_image_data(handle, page, i) |> ignore
  }
  let first_ms = @time.elapsed_ms(t0)
  // Second-pass
  let t1 = @time.now()
  for i in 0..<count {
    pdf_page_svg_image_data(handle, page, i) |> ignore
  }
  let second_ms = @time.elapsed_ms(t1)
  assert_true(first_ms < 3000)
  assert_true(second_ms * 10 < first_ms)
  pdf_close(handle)
}
```

If the project doesn't expose `@time.now`/`elapsed_ms`, use
`@env.now_ms()` or a wall-clock helper already used by the existing
benchmark tests.

For Requirement 3.3 (single-walk proof), add a test-only counter in
`build_deferred_svg_image_page` that increments a module-local
`Ref[Int]` each call. Assert that after N accessor calls the
counter equals 1. Use `#when(test)` or a test-private Ref via a
test-only function (`reset_graphics_walk_counter_for_test`) exposed
only inside `*_wbtest.mbt`.

## Files to modify

- `src/npm/wasm_api.mbt` — replace entry-level cache with
  page-level Array cache; remove obsolete helpers; add counter
  hook for the single-walk proof test
- `src/npm/wasm_api_wbtest.mbt` (NEW) — three whitebox tests
  covering Requirement 3.1, 3.2, 3.3

## Acceptance verification

1. `moon test --target native` — 720+ tests pass (adds 3 new)
2. `moon build --target wasm-gc --release` + wasm copy
3. Node profiler (see requirements Req 4.1): cumulative < 3s on
   page 7
4. Pages 4–6 no regression

## Notes on alternative: pre-extract during deferred render

Moving extraction back into `render_page_svg_deferred` (as the
pre-raw-rgba version did) would also satisfy the performance
requirement, but re-introduces the 12s blocking during
`pageToSvgDeferred`. The design intent of image-raw-rgba was to
keep `pageToSvgDeferred` cheap; this cache preserves that while
also keeping the accessor loop fast. The cost is paid once per
page, on first accessor call — which is the actual user journey
(scroll viewport into page ⇒ fetch all images).
