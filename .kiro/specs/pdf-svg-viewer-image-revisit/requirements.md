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

### Requirement 1: Failing test that reproduces the revisit bug

#### 1.1: Node-driven DOM simulation test
A test SHALL simulate (via jsdom or Node with DOM emulation) the
viewer component lifecycle:
- mount PdfViewer with a document whose page 0 has 1 image
- trigger isNearViewport=true for page 0 ⇒ assert `<image>` has
  non-empty href
- trigger isNearViewport=false ⇒ placeholder shown
- trigger isNearViewport=true again ⇒ assert `<image>` again has
  non-empty href with the same Blob URL (or a re-created one)

The test is expected to FAIL on the current implementation. Fix
work proceeds only after the test reproduces the bug.

#### 1.2: Blob URL liveness assertion
After the revisit, the test SHALL assert the Blob URL's content
is still fetchable (via `fetch(url).then(r => r.blob())`). If the
URL has been revoked, the fetch rejects. This discriminates F3
from F1/F2/F4/F5.

### Requirement 2: Identify failure mode

#### 2.1: Diagnostic counter
Add per-page counters exposed on window (dev build only):
- `patchInvocations[pageIndex]` — times `patchDeferredSvgImages`
  was called
- `patchSuccesses[pageIndex]` — times a non-empty image URL was
  applied

On revisit the invocations counter MUST increment; the successes
counter MUST increment by `imageCount`. If invocations increments
but successes does not, F2 or F1. If neither increments, F5. If
both increment but image still blank in DOM, F3 or F4.

#### 2.2: Blob URL re-creation fallback
Independent of the diagnostic, implement a fallback: when revisit
triggers patch, validate the URL via a HEAD or fetch; if invalid,
re-create the Blob URL from the wasm accessor and update the
cache. This removes F3 as a failure mode regardless of which
other mode applies.

### Requirement 3: Fix the failure mode

Apply the fix corresponding to whichever mode Requirement 2.1
identifies:

- **F1 fix**: in the patch effect, use layoutEffect (runs after
  DOM commit, before browser paint) or chain via
  `useEffect` with `surfaceRef.current` as a dep so the effect
  always sees the latest DOM.
- **F2 fix**: replace `requestAnimationFrame` indirection with a
  synchronous DOM walk inside the effect body. Defer the actual
  `setAttribute` to `requestIdleCallback` only if the walk found
  no images.
- **F3 fix**: validate Blob URLs before patch; recreate if
  invalidated.
- **F4 fix**: use React `key={isNearViewport ? svg : ""}` on the
  surface div to force remount, plus `dangerouslySetInnerHTML`
  key. Or replace the whole pattern with manual DOM manipulation
  that owns the image href attribute.
- **F5 fix**: depend on `isNearViewport && svgState.status === "ready"
  ? svgState.imageUrls : null` in the effect deps, so the image
  URL map reference drives the effect independent of svgState.

### Requirement 4: Regression tests

#### 4.1: Revisit passes
The test from Requirement 1 SHALL pass after the fix.

#### 4.2: Scroll-past-and-back 10 times
A stress test: simulate 10 cycles of scroll past / back on a
multi-image page. Every revisit SHALL restore all images. No
Blob URL leaks (counter of active URL.createObjectURL calls
stays bounded).

#### 4.3: No regression on other demo flows
Existing demo features (search, zoom, page jump) SHALL continue
to work.

### Requirement 5: Acceptance

Demo app: open <local-fixture>, scroll page 7 into viewport
so its 12 images load, scroll away to page 15, scroll back to
page 7. All 12 images SHALL be visible with their correct
content.
