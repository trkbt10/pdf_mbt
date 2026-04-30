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

### Requirement 1: Viewer cache application lifetime alignment

The MoonBit SVG package SHALL retain
`viewer_cache_application_lifetime_alignment`. Its documentation
captures document-scoped page SVG strings, deferred image entries,
zero-based page index keys, component unmount/remount survival,
document change discard, and no scroll eviction.

### Requirement 2: Viewer cache blob URL lifecycle alignment

The MoonBit SVG package SHALL retain
`viewer_cache_blob_url_lifecycle_alignment`. Its documentation
captures Blob URLs stored alongside the page SVG cache, reuse across
page remounts, no per-page unmount revocation, and cleanup on
document change or top-level unmount.

### Requirement 3: Viewer cache loadPageSvg stable identity alignment

The MoonBit SVG package SHALL retain
`viewer_cache_load_page_svg_stable_identity_alignment`. Its
documentation captures stable `loadPageSvg` identity, cache reads
through `useRef`, and idempotent repeated calls when a page is
already cached or loading.

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
