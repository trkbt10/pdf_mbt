# Tasks: PdfViewer application-lifetime page cache

## Task 1: Introduce ref-backed DocumentCache

**File:** `npm/demo/src/PdfViewer.tsx`

1. Define `CachedPage` and `DocumentCache` types (see design.md §"Cache structure")
2. Add `cacheRef = useRef<DocumentCache | null>(null)`
3. Add `ensureCache(cacheRef, document)` helper that creates a new
   cache when the document identity changes and revokes Blob URLs
   from the previous cache
4. Add a `version` state (`useState(0)` + `setVersion`) used purely
   to trigger re-render when cache entries change

## Task 2: Rewrite loadPageSvg to use the ref cache

**File:** `npm/demo/src/PdfViewer.tsx`

1. Remove `pageSvgs` from `loadPageSvg`'s `useCallback` dependency
   array; keep only `document`
2. Read current state through `cacheRef.current` inside the callback
3. Write state changes by mutating the cache Map and calling
   `setVersion(v => v + 1)`
4. Move `patchImageUrls` (Blob URL generation for all images on the
   page) into the success branch, and store the Map on the cached
   page entry
5. Verify the callback reference is stable across renders (no
   dependency on per-page state)

## Task 3: Wire page rendering to the cached Blob URL Map

**File:** `npm/demo/src/PdfViewer.tsx`

1. Update the page-rendering subcomponent (wherever
   `dangerouslySetInnerHTML` sets the SVG) to read the `imageUrls`
   Map from the cached entry instead of fetching image data again
2. When iterating `image[data-image-index]` elements, set `href`
   from `imageUrls.get(index)` directly; no calls to
   `pageSvgImageData` here — those happened once in `loadPageSvg`

## Task 4: Blob URL cleanup on document change and unmount

**File:** `npm/demo/src/PdfViewer.tsx`

1. Implement `revokeAllBlobUrls(cache)` that iterates every page's
   `imageUrls` and calls `URL.revokeObjectURL`
2. Call it inside `ensureCache` before switching documents
3. Add a top-level `useEffect` with an empty dep array whose cleanup
   function calls `revokeAllBlobUrls(cacheRef.current)` and resets
   `cacheRef.current = null`

## Task 5: Document wasm deferred_svg_pages as per-call pending state

**File:** `src/npm/wasm_api.mbt`

Update the doc comment on `let deferred_svg_pages` to clarify:

- This is pending state for the accessor bridge, not a cache
- The viewer layer is responsible for avoiding duplicate
  `pdf_page_to_svg_deferred` calls

No code change, only comment. This update makes the spec alignment
gate find "per-call pending state" vocabulary.

## Task 6: Verify

1. `moon test --target native` — still 711 tests pass
2. `npm run build --prefix npm/demo` — succeeds
3. Manual check (if browser dev server available): load local-fixture, scroll
   to page 7, away, and back; a `console.log` inside `loadPageSvg`
   SHALL fire once per page across the session, not on every
   revisit. Alternatively, add a temporary counter and assert via
   test.

## Task 7: Spec alignment gate

```bash
indexion spec align status .kiro/specs/pdf-svg-viewer-cache/requirements.md npm/demo/src/ --threshold 0.3 --fail-on drifted
```

Also check wasm side:

```bash
indexion spec align status .kiro/specs/pdf-svg-viewer-cache/requirements.md src/npm/ --threshold 0.3 --fail-on drifted
```

Both SHALL exit 0. If DRIFTED items remain, add spec vocabulary to
doc comments (for MoonBit side) or comments (for TypeScript side).

Note: TypeScript files may not be recognised by the indexion KGF
for alignment extraction; for this spec the primary alignment target
is `src/npm/` (wasm side) and the TypeScript implementation is
verified via build + manual acceptance only.
