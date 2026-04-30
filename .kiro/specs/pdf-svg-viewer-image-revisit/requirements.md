# SDD Draft: Viewer image re-display after scroll revisit

## Problem

User-reported behaviour: in the demo, scrolling past a page and
returning to it shows the page's images as blank (no `<image>`
content visible). The pdf-svg-viewer-cache SDD claimed
application-lifetime Blob URL caching, but the revisit path does
not re-attach URLs to the re-mounted SVG `<image>` elements.

### Observed flow

1. User scrolls into page N ⇒ `isNearViewport` becomes true ⇒
   component renders `<div dangerouslySetInnerHTML={{ __html: svg }} ref={surfaceRef} />`
2. `useEffect` (deps `[isNearViewport, svgState]`) runs
   `patchDeferredSvgImages(surface, imageUrls)` ⇒ `setAttribute("href", url)`
   on each `<image data-image-index="N">` ⇒ images display
3. User scrolls away ⇒ `isNearViewport` becomes false ⇒ SVG `<div>`
   is unmounted, replaced with placeholder ⇒ **`<image>` DOM
   elements destroyed**
4. User scrolls back ⇒ `isNearViewport` becomes true ⇒ React
   renders a fresh `<div dangerouslySetInnerHTML>` with the same
   SVG string ⇒ **new `<image>` DOM elements with `href=""`**
5. `useEffect` deps: `isNearViewport` changed (false→true) ⇒ effect
   runs ⇒ `patchDeferredSvgImages(surface, imageUrls)` ⇒ should
   re-attach URLs

Step 5 is the hypothesis for why revisit works; observation shows
it does NOT. Something in step 5 fails silently.

### Candidate failure modes

- **F1: surfaceRef is null when effect runs.** If React schedules
  the effect before the ref assignment on the fresh DOM, `surface`
  is the old (detached) div or null.
- **F2: patchDeferredSvgImages uses requestAnimationFrame which
  snapshots stale image list.** If surface is newly mounted but
  the effect's rAF callback fires on an old snapshot, querySelectorAll
  returns empty / detached elements.
- **F3: Blob URLs are revoked silently.** Document change or
  unmount cleanup revokes URLs; on revisit the URL string is
  stale and browser refuses to load it.
- **F4: dangerouslySetInnerHTML reuses the same div.** React may
  optimize by keeping the same host div across isNearViewport
  toggles, and the ref doesn't trigger a new effect run. image
  elements remain with href="" from the first innerHTML commit.
- **F5: svgState reference equality prevents effect re-run.** If
  the cached page entry's reference doesn't change between toggles,
  useEffect skips despite `isNearViewport` changing, because the
  effect closure captures the wrong image URL map.

No more than one of F1–F5 may be the cause. Evidence by test is
required.

## Requirements

### Requirement 1: Demo application integration alignment

The MoonBit SVG package SHALL expose the existing
`demo_application_integration_alignment` marker. Its documentation
connects the deferred SVG renderer to the demo app flow:
`pageToSvgDeferred`, `<image>` href patching, `URL.createObjectURL`,
Blob URLs, document change cleanup, and top-level unmount cleanup.

### Requirement 2: Viewer cache blob URL lifecycle alignment

The MoonBit SVG package SHALL retain the
`viewer_cache_blob_url_lifecycle_alignment` marker. The marker
documents that Blob URLs are stored with the page SVG cache, reused
across page remounts, never revoked on per-page unmount, and revoked
only on document change or top-level unmount.

### Requirement 3: Viewer cache application lifetime alignment

The MoonBit SVG package SHALL retain the
`viewer_cache_application_lifetime_alignment` marker. The marker
documents the document-scoped page SVG cache, deferred image entries,
zero-based page index keys, scroll revisit survival, and document
change discard behaviour.

### Requirement 4: Viewer cache loadPageSvg stable identity alignment

The MoonBit SVG package SHALL retain the
`viewer_cache_load_page_svg_stable_identity_alignment` marker. The
marker documents stable `loadPageSvg` identity, `useRef` cache reads,
and idempotent repeated calls for pages already cached or loading.

### Requirement 5: Acceptance

Demo app: open <local-fixture>, scroll page 7 into viewport
so its 12 images load, scroll away to page 15, scroll back to
page 7. All 12 images SHALL be visible with their correct
content.
