# Design: Viewer image re-display after scroll revisit

## Overview

The pdf-svg-viewer-cache SDD established an application-lifetime
cache but did not test the re-attachment of Blob URLs to
freshly-mounted `<image>` DOM elements on scroll revisit. Observed:
image disappears after the first scroll-away and never returns.

Plan:

1. Write a failing test that reproduces the revisit bug (TDD).
2. Add diagnostic counters to identify which of F1–F5 is the
   failure mode.
3. Apply the matching fix.
4. Verify the test passes and add a stress test for 10 cycles.

## Component structure (recap from existing code)

`PdfViewer.tsx`:

- `cacheRef: useRef<DocumentCache | null>` — application-lifetime
  store for `{ handle, pages: Map<pageIndex, CachedPage> }`
- `pageSvgs = cachedPageSvgs(cacheRef.current, document)` — Map
  reference used to feed children
- `PageItem → RenderedPageSvg` — per-page render
- `RenderedPageSvg`:
  - conditional render: `isNearViewport && svg.status === "ready"`
    ? `<div dangerouslySetInnerHTML={{__html: svg}} ref={surfaceRef}>`
    : placeholder
  - `useEffect([isNearViewport, svgState], patch)` —
    patches Blob URLs into `<image>` elements

`patchDeferredSvgImages(surface, imageUrls)`:

- schedules a `requestAnimationFrame`
- inside the rAF: `surface.querySelectorAll("image[data-image-index]")`
- iterates via second rAF chain, `setAttribute("href", url)`

## Failure mode analysis

| Mode | Symptom pattern | Test it via |
|------|-----------------|-------------|
| F1 | `surfaceRef.current` null on revisit effect | counter of effect runs with null surface |
| F2 | rAF snapshots old DOM | counter of querySelectorAll hits vs expected |
| F3 | Blob URL revoked | `fetch(url)` rejects |
| F4 | `<div>` kept across toggle, images not recreated, patch skipped | DOM inspection of same element reference |
| F5 | Effect deps miss the revisit | effect counter stays flat |

The diagnostic counters (Requirement 2.1) expose which mode is
actually at play so the fix (Requirement 3) is targeted, not
speculative.

## Failing test that reproduces the revisit bug

The failing test that reproduces the revisit bug SHALL drive the
whole workflow via a Node-driven DOM simulation (jsdom or
happy-dom). It mounts the PdfViewer with a stub document, toggles
`isNearViewport` across true / false / true, and asserts that the
`<image>` element carries a non-empty `href` after the revisit. The
assertion SHALL also verify Blob URL liveness via `fetch(url)` so
we discriminate F3 (revoked URL) from the other failure modes.

## Regression tests

Regression tests SHALL follow TDD: the initial failing test turns
green after the chosen fix, and a 10-cycle scroll-past-and-back
stress test SHALL assert every revisit restores the image `href`.
A spy on `URL.createObjectURL` SHALL verify Blob URLs are created
once per image (not recreated on every cycle), so cache
effectiveness is proved by counting rather than timing.

## Specific strong candidate: F4

In React, a conditional ternary between:

```tsx
{condition ? <div>...</div> : <div>placeholder</div>}
```

renders two different JSX elements at the same position. React
reconciliation typically creates a new DOM node when the top-level
element type matches but a deeper structural change occurs. In our
case both branches return `<div>`, so React may reuse the div
and only swap the innerHTML / className / style.

If the div is reused and `dangerouslySetInnerHTML` value is the
same SVG string across both branches, React may skip the DOM
update entirely. Then the placeholder variant has no `<image>`
elements (because innerHTML was different — placeholder text) and
the ready variant sets innerHTML again with fresh `<image
href="">`. `setAttribute("href", url)` should work on these new
elements.

F4 more likely: the placeholder branch mounts its own div and
image content, and on revisit, React recreates the ready div
cleanly. Then the effect should run. What if
the effect DOES run but surfaceRef points to the placeholder div
(stale from previous render) when rAF fires? That's F1+F2 combined.

## Solution sketch (after F identified)

### If F4 — force remount with key

```tsx
<div
  key={isNearViewport ? `ready-${pageIndex}` : `placeholder-${pageIndex}`}
  className={...}
  dangerouslySetInnerHTML={...}
  ref={surfaceRef}
/>
```

Distinct keys force unmount/remount so ref swaps cleanly.

### If F5 — depend on imageUrls map directly

```tsx
useEffect(() => {
  if (!isNearViewport || svgState.status !== "ready") return;
  const surface = surfaceRef.current;
  if (!surface) return;
  return patchDeferredSvgImages(surface, imageUrls);
}, [isNearViewport, svgState.status, svgState.svg, imageUrls]);
```

### If F2 — synchronous walk

```tsx
function patchDeferredSvgImages(surface, imageUrls) {
  const images = surface.querySelectorAll("image[data-image-index]");
  for (const image of images) {
    patchDeferredSvgImage(image, imageUrls);
  }
  // No rAF — run synchronously
}
```

### If F1 — useLayoutEffect

```tsx
useLayoutEffect(() => {
  if (!isNearViewport || svgState.status !== "ready") return;
  const surface = surfaceRef.current;
  if (!surface) return;
  return patchDeferredSvgImages(surface, imageUrlsForSvgState(svgState));
}, [isNearViewport, svgState]);
```

### If F3 — recreate Blob URL

In `createDeferredSvgImageUrls`, wrap URL with a liveness check:
```ts
async function ensureBlobLive(url, source, pageIndex, imageIndex) {
  try {
    await fetch(url);
    return url;
  } catch {
    URL.revokeObjectURL(url);
    return createDeferredSvgImageUrl(source, pageIndex, imageIndex);
  }
}
```

## Files to modify

- `npm/demo/src/PdfViewer.tsx` — diagnostic counters, one of the
  above fixes, possibly key-based remount
- `npm/demo/test/` (new) — jsdom-based revisit test (new directory
  if none exists)
- `npm/package.json` / `npm/demo/package.json` — test script
  entry if needed

## Acceptance verification

1. Failing test from Requirement 1 initially fails on HEAD
2. After fix: failing test passes
3. Stress test (10 cycles) passes
4. Manual browser verification: local-fixture page 7 scroll-away-and-back
   shows all 12 images
