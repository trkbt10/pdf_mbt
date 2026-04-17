# SDD Draft: PdfViewer application-lifetime page cache

## Problem

The web viewer (`npm/demo/src/PdfViewer.tsx`) re-renders pages from
scratch when the user scrolls away and back. Symptoms observed:

1. `loadPageSvg` is wrapped with `useCallback` whose deps include
   `pageSvgs`, so the callback is regenerated on every page state
   update. Downstream components receiving the callback re-run
   their effects and can re-invoke `loadPageSvg`.
2. `pageSvgs` is stored in component state, so a component unmount
   (e.g. navigating away and back) discards the cache and forces
   re-parsing of every page.
3. The wasm `pdf_page_to_svg_deferred` unconditionally overwrites
   its `deferred_svg_pages` map on every call. The stored result is
   required for `pdf_page_svg_image_count/data/mime` accessors,
   but it is not a cache — subsequent `pageToSvgDeferred` calls
   for the same page re-run the full SVG rendering pipeline.

An LRU cache is inappropriate here because a PDF viewer legitimately
revisits pages as the user scrolls. LRU eviction would recreate the
same page re-parse problem under the guise of caching.

The correct design:

- wasm stays stateless per call (or carries a small pending state
  only for the accessor bridge)
- CLI consumers need no cache (single-pass)
- JS single-shot consumers need no cache
- Web viewer holds an **application-lifetime Map** keyed by page
  index, outlives component unmounts, and is never evicted

This spec addresses the web viewer layer only. wasm and npm package
API surfaces are unchanged.

## Requirements

### Requirement 1: Application-lifetime page SVG cache

#### 1.1: Cache outlives component unmount
The web viewer SHALL store rendered page SVGs in a cache that
survives React component unmount/remount cycles. The cache key is
the page index (zero-based), the value includes the SVG string and
the deferred image entries required for Blob URL patching.

#### 1.2: Cache scoped to the open document
The cache SHALL be scoped to the currently-open PDF document. When
the user opens a different PDF, the cache for the previous document
SHALL be discarded and Blob URLs revoked.

#### 1.3: No eviction on scroll
The cache SHALL NOT evict entries based on page scroll position,
viewport distance, or any size-based policy. A user scrolling
forward and back SHALL receive the cached SVG instantly.

### Requirement 2: loadPageSvg stable identity

#### 2.1: Callback does not depend on per-page state
`loadPageSvg` SHALL NOT include `pageSvgs` (or equivalent per-page
state) in its `useCallback` dependency array. The callback SHALL
read the current cache state through a stable reference (e.g. `useRef`).

#### 2.2: Idempotent on repeated calls
Repeated calls to `loadPageSvg(pageIndex)` for the same index
SHALL be idempotent: if the page is already cached or loading, the
second call SHALL return without scheduling new work.

### Requirement 3: Blob URL lifecycle

#### 3.1: Blob URL cache co-located with SVG cache
Blob URLs generated from deferred image entries SHALL be stored
alongside the SVG cache for the corresponding page, so that the
same URLs are reused across remounts.

#### 3.2: Revoke on document change
All Blob URLs SHALL be revoked via `URL.revokeObjectURL` when:
- The user opens a different document (entire cache discarded)
- The viewer is destroyed (React unmount of the top-level
  PdfViewer)

#### 3.3: No revocation on per-page unmount
Blob URLs SHALL NOT be revoked when a page component unmounts due
to scrolling. The URLs remain valid for the document's lifetime.

### Requirement 4: wasm API remains stateless per call

#### 4.1: wasm surface unchanged
The wasm entry points (`pdf_page_to_svg`, `pdf_page_to_svg_deferred`,
`pdf_page_svg_image_count`, `pdf_page_svg_image_data`,
`pdf_page_svg_image_mime`) SHALL retain their current signatures
and behaviour. No new wasm-level cache is introduced.

#### 4.2: deferred_svg_pages remains per-call pending state
The existing wasm-side `deferred_svg_pages` map is documented as
"pending state for the accessor bridge", not a cache. Calling
`pdf_page_to_svg_deferred` twice for the same page re-renders
(same behaviour as today); the JS viewer cache avoids the
re-render call.

### Requirement 5: Acceptance criteria

#### 5.1: No re-parse on scroll revisit
When the user scrolls to page N, away, and back to page N, the
browser SHALL NOT invoke the wasm rendering pipeline a second time
for page N. Verified via a counter in the JS layer or a debug log
in `loadPageSvg`.

#### 5.2: Existing npm tests unchanged
`npm test` SHALL pass without modification. The visual regression
test uses `pageToSvg` (synchronous path) and does not go through
the viewer cache.

#### 5.3: Demo build succeeds
`npm run build --prefix npm/demo` SHALL produce a working bundle.
