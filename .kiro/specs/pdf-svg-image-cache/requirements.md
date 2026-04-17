# SDD Draft: Deferred image extraction cache (no repeat graphics walk)

## Problem

Profiling the wasm `pdf_page_svg_image_data` accessor on
<local-fixture> page 7 shows 12,000+ ms of cumulative blocking
across 12 image fetches — unchanged from the pre-lazy baseline of
the image-raw-rgba SDD even though the per-first-access measurement
matches Codex's "pageToSvgDeferred = 161 ms" report.

Per-image timing for page 7 on the first pass (same document handle,
consecutive calls) and the second pass (cache hits):

| Image | First-pass ms | Second-pass ms | MIME      | Size    |
|-------|---------------|----------------|-----------|---------|
| 0     | 86            | 0              | image/x-rgba8 | 36×36   |
| 1     | 84            | 0              | image/x-rgba8 | 38×38   |
| 2–6   | 123–152       | 5–6            | image/x-rgba8 | 480×761 |
| 7     | **5,908**     | 1              | image/x-rgba8 | 148×249 |
| 8     | 106           | 0              | image/x-rgba8 | 3×144   |
| 9     | 159           | 5              | image/x-rgba8 | 480×761 |
| 10    | **6,699**     | 1              | image/x-rgba8 | 150×253 |
| 11    | 94            | 0              | image/x-rgba8 | 3×152   |
| **Total** | **~13,000**| ~18            |           |         |

The current `page_svg_image_entry_by_occurrence` walks the full
graphics event stream on every call, advances to the target index,
then extracts the raw image data. Twelve calls ⇒ twelve full event
walks plus twelve extractions. `deferred_svg_image_entries` caches
the final `SvgImageEntry` but not the intermediate events walk, and
it does nothing for the images not yet fetched.

`render_wasm.mbt::deferred_image_entry` returns an empty placeholder
on wasm-gc (the lazy strategy), so the `SvgDeferredResult.images`
array carries no real data — every accessor call must re-walk
graphics events, defeating memoisation except at the final entry
level.

The cost of walking graphics events on a 12-image page is bounded
by the content-stream interpreter and clip-state accumulation. On
local-fixture page 7 the stream has hundreds of graphics operations; a single
walk is tolerable, twelve walks are not.

## Requirements

### Requirement 1: Page-scoped image extraction cache

#### 1.1: First-accessor materialises all images
The first call to any of `pdf_page_svg_image_data`,
`pdf_page_svg_image_info`, or `pdf_page_svg_image_mime` for a given
`(handle, page)` SHALL trigger one graphics event walk on that page
and extract every `SvgImageEntry` reachable through
`ImagePainted` events into an ordered cache indexed by the image's
placement order on the page.

#### 1.2: Subsequent accessors read from cache
Calls for the same `(handle, page, index)` after the first-accessor
walk SHALL read the pre-extracted entry from the cache, without
walking graphics events again and without re-running
`extract_image_xobject`.

#### 1.3: Cache keyed by (handle, page)
The cache key SHALL be the handle / page pair that already
identifies `deferred_svg_pages`. The cache SHALL survive across
calls for the same document handle and invalidate only when the
document handle is closed.

### Requirement 2: Documented accessor complexity

#### 2.1: Single graphics walk per page
The accessor implementation SHALL be documented (in code comments
or a brief ADR inside the wasm_api source) such that future
maintainers understand "one walk per page, not per image" is the
intended contract.

#### 2.2: No change to wasm API surface
The wasm entry points (`pdf_page_svg_image_data`,
`pdf_page_svg_image_info`, `pdf_page_svg_image_mime`,
`pdf_page_svg_image_count`) SHALL retain their current signatures.
Only their internals change.

### Requirement 3: Regression test (compensation)

#### 3.1: Per-page timing test
A whitebox test SHALL open <local-fixture> (guarded by
`@fs.path_exists`), request `pdf_page_to_svg_deferred` for page 7,
then measure cumulative wall time for a loop that calls
`pdf_page_svg_image_data` for every image index. The assertion
SHALL require the total time on the first pass to remain under a
threshold (e.g. 3,000 ms on the reference machine). The test skips
if the fixture is not present, matching the existing
`diagnostic local-fixture page 4` pattern.

#### 3.2: Cache-hit test
The same test SHALL perform a second pass and assert that the
cumulative second-pass time is significantly smaller than the first
pass (at least 10× ratio). This proves the cache is effective.

#### 3.3: No graphics event walk on cache hit
A whitebox test SHALL count the number of times
`graphics_events(...)` is called per page. For a page with N images
and 2N accessor calls, the number of walks SHALL be exactly one.
Add instrumentation (e.g. a counter module-local variable) only
within the test scope; do not leak it into production code.

### Requirement 4: Acceptance criteria

#### 4.1: Page 7 cumulative under 3 seconds
The cumulative time of `pageToSvgDeferred(6)` plus
`pageSvgImageData(6, i)` for all 12 images SHALL be under 3,000 ms
on the reference machine (currently ~13,000 ms).

#### 4.2: No regression on other pages
Cumulative time on pages 4, 5, 6 SHALL not regress beyond 500 ms.

#### 4.3: Existing tests continue to pass
`moon test --target native` 718+ tests SHALL continue to pass.
