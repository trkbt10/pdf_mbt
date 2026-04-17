# SDD Draft: Viewer image re-display — second pass

## Problem

User reports (multiple times): in the demo, after scrolling past
a page with images and returning, the images remain blank. The
previous `pdf-svg-viewer-image-revisit` SDD (6 commits, jsdom test
passing) did not fix the real-browser symptom.

Either:
- the fix works in the jsdom test but not in a real Chromium
- the fix only covers one of the F1–F5 failure modes and another
  is at play
- a different feature (prefetch scroll, lazy mount, memory pressure)
  is destroying the image cache

The user asked explicitly to verify this is fixed. The jsdom test
was too narrow — it simulated a single toggle but real scrolling
involves IntersectionObserver, multiple remounts, and browser-
level Blob URL lifetime across navigations.

## Requirements

### Requirement 1: Real-browser-like reproduction

#### 1.1: Playwright or puppeteer end-to-end test
A test SHALL launch a headless browser (chromium), load the demo
with a fixture PDF containing images, simulate scrolling past the
image page and back, and assert that the image element has a
non-empty visible `href` (and the image actually renders to pixels
via `getBoundingClientRect` + visibility check).

If playwright is too heavy, an equivalent puppeteer or headless-
chrome test works. The requirement is "real browser", not jsdom.

#### 1.2: Cover the IntersectionObserver path
The test SHALL not fake `isNearViewport` directly. It SHALL use
`window.scrollTo` or programmatic element scrollIntoView so the
production IntersectionObserver fires naturally.

#### 1.3: Use the actual target fixture
The test SHALL use `<local-fixture>` (or another
user-reported failing fixture) if accessible, not a synthetic 1-
image minimal case. This catches the real failure shape.

### Requirement 2: Identify the real failure mode

#### 2.1: Capture DOM state across scroll
The test SHALL dump, for each revisit, the `<image>` element's
attributes, computed style, and whether the Blob URL is still
live (`fetch(url)` succeeds). This discriminates the six modes:

- F1: surfaceRef null
- F2: rAF snapshot stale
- F3: Blob URL revoked
- F4: div reuse skipping image re-creation
- F5: effect deps miss revisit
- F6: cache entry itself missing (ref cache destroyed)

F6 is new since the previous SDD — if the document object identity
changes (e.g. React StrictMode double-mount, or parent re-render
with a new `document` instance), the ref cache is wiped.

### Requirement 3: Fix the real failure mode

#### 3.1: Minimal change to PdfViewer.tsx
Apply a fix targeted at whichever F (1–6) the diagnostic
identifies. Previous F1 fix (synchronous patch) is already in
place; do not revert it unless the new diagnostic says otherwise.

#### 3.2: Do NOT increase test surface area without fixing
If the diagnostic reveals F6 (ref cache destroyed on document
identity change), the fix SHALL preserve ref cache across
identity-unchanged parent re-renders. Use e.g. `useMemo` keyed by
`document.source.handle` for the cache initialiser.

### Requirement 4: Acceptance

#### 4.1: local-fixture page 5+ revisit works
Open <local-fixture> in the demo (via the
Playwright test). Scroll down past an image page, scroll back,
confirm the image is visible.

#### 4.2: No regression on local-fixture
local-fixture page 7 (existing Playwright or manual verification) continues
to work.

#### 4.3: Stress test 10 cycles still passes
The existing jsdom stress test from the first SDD SHALL still
pass — the new fix SHALL NOT regress its behaviour.
