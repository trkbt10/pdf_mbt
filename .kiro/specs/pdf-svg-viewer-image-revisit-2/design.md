# Design: Viewer image re-display — second pass

## Overview

The first revisit SDD fixed a jsdom-level revisit issue
(synchronous restore in `useEffect`). The user reports the real-
browser symptom persists. This SDD:

1. Adds a Playwright end-to-end test that reproduces the real-
   browser failure.
2. Captures diagnostic DOM state to identify failure mode F1–F6.
3. Fixes the identified mode with minimal change.

## Real-browser-like reproduction

The real-browser-like reproduction drives the entire workflow via
Playwright (or equivalent headless chromium). It loads the demo,
uploads a fixture PDF with images, exercises the
IntersectionObserver path by scrolling via the actual DOM
(`element.scrollIntoView` / `window.scrollTo`) rather than faking
`isNearViewport`, and uses the user-reported failing fixture
(<local-fixture>) rather than a synthetic minimal
case. Only a real-browser harness exposes the scrolling and Blob
URL lifetime behaviour that jsdom simulation missed.

## Candidate new failure mode: F6 — ref cache destroyed

The prior SDD treated the ref cache as immortal across renders.
But `cacheRef.current` is reset when:

- `ensureCache` detects `cache.handle !== document.source.handle`
  (line 83 area in PdfViewer.tsx)
- The PdfViewer component itself unmounts

If the parent component re-creates the `document` object on every
render (e.g. `const document = openPdf(...)` inline in JSX without
useMemo), the handle changes, the cache is revoked, and all Blob
URLs become invalid. The `dangerouslySetInnerHTML` still has the
old `data-image-index="N"` attributes, but `imageUrls.get(N)`
returns undefined because the cache was wiped.

This is very likely for the local-fixture case where many
pages have images — any user-triggered re-render that changes the
document identity wipes 75 pages of cached image URLs in one go.

## Fix strategy (if F6 confirmed)

### Use stable handle identifier

`ensureCache` already keys by `cache.handle !== document.source.handle`.
The fix is upstream: ensure that `document.source.handle` is
stable for the same opened PDF, even if the parent re-renders the
`document` object.

If `PdfDocument.open(bytes)` generates a new handle every call,
parent's useMemo on the file should guarantee stability. If the
parent doesn't use useMemo, the cache is wiped unnecessarily.

Candidate fixes:

**Fix A**: in the demo's top-level file handling, wrap
`PdfDocument.open` in `useMemo(() => ..., [file])` so the handle
stays stable.

**Fix B**: in PdfViewer, track the *file* identity via content
hash or URL rather than the document object, so re-opening the
same PDF doesn't wipe the cache.

**Fix C**: if the underlying wasm `pdf_open_bytes` always creates
a new handle, add deduplication at the JS layer keyed by bytes
hash, returning the same handle for the same PDF.

Without evidence, do not choose. The Playwright diagnostic decides.

## Instrumentation

Add to the Playwright test a `window.__viewerCacheHandle` tracker
that records the current cache's handle on each `ensureCache`
call. If the handle changes between two scrolls without the user
reopening the file, F6 is confirmed.

## Files to modify

- `npm/demo/test/browser/image-revisit.test.ts` — new Playwright
  test
- `npm/demo/src/PdfViewer.tsx` — diagnostic logs + one of A/B/C
- `npm/demo/src/App.tsx` (or wherever `PdfDocument.open` is
  invoked) — useMemo fix if F6 A applies
- `npm/package.json` — playwright install + test script if needed

## Acceptance verification

1. Playwright test loads local-fixture, scrolls to page 6 →
   page 20 → page 6, asserts image visible
2. Same pattern on local-fixture page 7 passes
3. Stress 10 cycles (existing jsdom test) still passes
4. `moon test --target native` unchanged
