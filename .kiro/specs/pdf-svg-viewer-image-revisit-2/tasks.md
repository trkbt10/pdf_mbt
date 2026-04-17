# Tasks: Viewer image re-display — second pass

## Task 1: Install + configure Playwright

**Files:** `npm/demo/package.json`, `npm/demo/playwright.config.ts`

Install `@playwright/test` + chromium, wire a test script in
package.json. Configure to use the demo's dev server (or a
pre-built static bundle) as the test target.

If Playwright is too heavy, puppeteer-core + headless chrome is
acceptable.

## Task 2: Failing browser test (RED)

**File:** `npm/demo/test/browser/image-revisit.test.ts`

1. Launch chromium, open the demo
2. Upload `<local-fixture>` (or use a test
   fixture that ships with the demo)
3. Scroll to page 5 (index) — wait for image to load
4. Assert image href non-empty AND visible
5. Scroll to page 30 (off-screen for page 5)
6. Scroll back to page 5
7. Assert image href non-empty AND visible

This FAILS on HEAD.

## Task 3: Diagnostic instrumentation

**File:** `npm/demo/src/PdfViewer.tsx`

Expose via `window.__viewerDiagnostics`:
- on each `ensureCache` call, log `{ handle, action }` where
  action is "reuse" or "recreate"
- on each `patchDeferredSvgImages` invocation, log the surface
  element ID and how many images were patched

Run the Playwright test with these logs captured. Identify which
of F1–F6 is responsible.

## Task 4: Apply the fix

Based on Task 3 diagnostic:

- F1 (surfaceRef null): layoutEffect (already applied in first SDD)
- F3 (Blob URL revoked): validate + recreate
- F6 (cache destroyed on identity change): stabilise handle via
  useMemo on file / content hash

Minimal change to PdfViewer.tsx and/or App.tsx.

## Task 5: Green test

Re-run Playwright test. Passes. Commit.

## Task 6: Regression

1. local-fixture page 7 Playwright scroll-and-back also passes
2. jsdom 10-cycle stress from the first SDD still passes
3. `moon test --target native` still passes

## Task 7: Drift gate

```bash
indexion spec align status .kiro/specs/pdf-svg-viewer-image-revisit-2/requirements.md npm/demo/src/ --threshold 0.3 --fail-on drifted
```

Must exit 0.
