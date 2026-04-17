# Tasks: Viewer image re-display after scroll revisit

## Task 1: Failing test (TDD RED)

**Directory:** `npm/demo/test/` (new or existing)

Set up jsdom (or happy-dom) as the test environment. Write
`image-revisit.test.ts`:

1. Mount `<PdfViewer document={...} />` with a fixture that exposes
   page 0 with 1 image via PdfDocument stubs
2. Fire: set `isNearViewport=true` (e.g. via IntersectionObserver
   mock) → wait for `imageUrls` to populate
3. Assert: `document.querySelector("image[data-image-index=\"0\"]")`
   has a non-empty `href`
4. Fire: set `isNearViewport=false`
5. Fire: set `isNearViewport=true` again
6. Assert: image has non-empty `href` again (this is the failing
   assertion on HEAD)

Commit the test with a clear message "test: reproduce viewer image
revisit bug (FAILS on HEAD)". If jsdom isn't immediately
installable, use a simpler test harness: directly require
`patchDeferredSvgImages` and exercise it against a hand-built DOM
representing the remount sequence.

## Task 2: Diagnostic counters

**File:** `npm/demo/src/PdfViewer.tsx`

Add dev-only counters:

```ts
declare global {
  interface Window {
    __pdfViewerPatchStats?: {
      invocations: number;
      successes: number;
      lastSurfaceNull: boolean;
      lastQuerySelectorHits: number;
      lastFetchOkBlobUrls: number;
    };
  }
}
```

Increment inside `patchDeferredSvgImages` and the per-image patch.
Clear on document change.

Log the stats inside the failing test from Task 1 via
`window.__pdfViewerPatchStats` to identify which F (F1–F5) is the
failure mode.

## Task 3: Pick fix based on stats

**Source:** Task 2 output in test log

Choose the matching fix pattern from design.md § "Solution sketch":

- F1 → `useLayoutEffect` instead of `useEffect`
- F2 → synchronous DOM walk, no rAF indirection
- F3 → Blob URL liveness check + re-create
- F4 → key-based remount of surface div
- F5 → extend useEffect deps to include `imageUrls` reference

Apply the minimal change. Commit with a message describing which
failure mode was confirmed and which fix was applied.

## Task 4: Test turns GREEN

Re-run the Task 1 test. Assertion for revisit now passes. Commit
as "test: image revisit restores href on scroll return".

## Task 5: Stress test (10 cycles)

**File:** `npm/demo/test/image-revisit-stress.test.ts`

Cycle `isNearViewport` 10 times. Assert after each cycle the
image href is present. Additionally count `URL.createObjectURL`
calls via a spy:

```ts
const createObjectURLSpy = vi.spyOn(URL, "createObjectURL");
// ... run 10 cycles ...
expect(createObjectURLSpy).toHaveBeenCalledTimes(expectedCount);
// expectedCount should equal the original image count, not
// original × 10 — caching means URLs are created once
```

## Task 6: Drift gate

```bash
indexion spec align status .kiro/specs/pdf-svg-viewer-image-revisit/requirements.md npm/demo/src/ --threshold 0.3 --fail-on drifted
```

Must exit 0. Note: TypeScript KGF is weak for declaration
extraction; accept IMPL_ONLY entries as long as DRIFTED is 0.

## Task 7: Manual verification

After wasm rebuild and demo build:

```bash
moon build --target wasm-gc --release && cp _build/wasm-gc/release/build/src/npm/npm.wasm npm/dist/pdf.wasm
cd npm/demo && npm run build
```

Load local-fixture in the demo, scroll to page 7 (images load), scroll
away to page 15, scroll back to page 7. Every image must be
visible.

## Task 8: Regression

`moon test --target native` — 719+ tests pass (no MoonBit changes
expected in this SDD, but verify).

`npm test` — if it exists, must pass.

## Implementation Notes

- Task 6: Drift gate passed with `Drifted: 0` for `npm/demo/src/`; `Impl only: 1` accepted per task guidance.
- Task 7: `moon build --target wasm-gc --release`, wasm copy, and `npm/demo` production build passed; local-fixture PDF was not present locally, and sandbox denied starting the Vite dev server.
- Task 8: `moon test --target native` passed 722 tests; `npm test` passed 2 demo image revisit tests.
