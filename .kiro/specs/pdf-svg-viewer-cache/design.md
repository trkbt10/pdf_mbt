# Design: PdfViewer application-lifetime page cache

## Overview

Move the page SVG cache from React component state (`pageSvgs`,
`pageTexts`, etc.) to a `useRef`-backed `Map` that outlives component
unmount/remount. The cache holds `{ svg, imageBlobUrls }` per page
and is scoped to the currently-open document via a document identity
token (e.g. the document handle). wasm and npm package surfaces are
not modified.

## Current code

`npm/demo/src/PdfViewer.tsx`:

```typescript
const [pageSvgs, setPageSvgs] = useState<Record<number, PageSvgState>>({});
const loadPageSvg = useCallback(
  (pageIndex: number) => {
    const current = pageSvgs[pageIndex];
    if (current && current.status !== "idle") { return; }
    setPageSvgs(states => ({ ...states, [pageIndex]: { status: "loading", svg: "" }}));
    setTimeout(() => {
      const svg = document.source.pageToSvgDeferred(pageIndex);
      setPageSvgs(states => ({ ...states, [pageIndex]: { status: "ready", svg }}));
    }, 0);
  },
  [document, pageSvgs],  // ← pageSvgs makes callback unstable
);
```

Problems:
- `pageSvgs` dep → callback identity changes on every state update
- `useState` cache → lost on unmount
- No Blob URL reuse across remounts

## Solution

### Cache structure

```typescript
type CachedPage = {
  status: "loading" | "ready" | "error";
  svg: string;
  imageUrls: Map<number, string>;  // image-index → Blob URL
  error?: string;
};

type DocumentCache = {
  handle: number;              // identity token for the open document
  pages: Map<number, CachedPage>;
};
```

Store via `useRef<DocumentCache | null>(null)` so the Map instance
survives remounts.

### State model

Keep a small React state (`pageSvgs: Record<number, { status, svg }>`)
purely for rendering — updates trigger re-render. But the source of
truth is the ref-backed Map. On initial mount or when a page is
already cached, seed the state from the ref.

```typescript
const cacheRef = useRef<DocumentCache | null>(null);
const [, setVersion] = useState(0);  // bump to trigger rerender

const loadPageSvg = useCallback((pageIndex: number) => {
  // No per-page state in deps — callback stable across page updates
  const cache = ensureCache(cacheRef, document);
  const existing = cache.pages.get(pageIndex);
  if (existing && existing.status !== "idle") return;  // idempotent

  cache.pages.set(pageIndex, { status: "loading", svg: "", imageUrls: new Map() });
  setVersion(v => v + 1);

  setTimeout(() => {
    try {
      const svg = document.source.pageToSvgDeferred(pageIndex);
      const imageUrls = patchImageUrls(document, pageIndex, svg);  // creates Blob URLs
      cache.pages.set(pageIndex, { status: "ready", svg, imageUrls });
      setVersion(v => v + 1);
    } catch (e) {
      cache.pages.set(pageIndex, { status: "error", svg: "", imageUrls: new Map(), error: String(e) });
      setVersion(v => v + 1);
    }
  }, 0);
}, [document]);  // ← only depends on document
```

### Document identity check

```typescript
function ensureCache(ref, document) {
  const handle = document.source.handle;
  if (!ref.current || ref.current.handle !== handle) {
    // Document changed — revoke all blob URLs, reset cache
    if (ref.current) {
      for (const page of ref.current.pages.values()) {
        for (const url of page.imageUrls.values()) URL.revokeObjectURL(url);
      }
    }
    ref.current = { handle, pages: new Map() };
  }
  return ref.current;
}
```

### Blob URL cleanup on unmount

```typescript
useEffect(() => {
  return () => {
    if (cacheRef.current) {
      for (const page of cacheRef.current.pages.values()) {
        for (const url of page.imageUrls.values()) URL.revokeObjectURL(url);
      }
      cacheRef.current = null;
    }
  };
}, []);
```

This fires only on PdfViewer unmount, not on per-page unmount.

### Patching images into DOM

Page rendering component (existing) receives `svg` and the
`imageUrls` Map. After `dangerouslySetInnerHTML` insertion, iterate
`image[data-image-index]` elements and set `href` from `imageUrls`.
The Map is pre-populated before the page becomes visible, so
`requestAnimationFrame` is no longer strictly required, but keeping
it helps UI responsiveness for large pages.

### Image URL creation

Moved into `loadPageSvg` (runs off the main thread via `setTimeout(0)`):

```typescript
function patchImageUrls(document, pageIndex, svg) {
  const urls = new Map<number, string>();
  const count = document.source.pageSvgImageCount?.(pageIndex) ?? 0;
  for (let i = 0; i < count; i++) {
    const { data, mime } = document.source.pageSvgImageData(pageIndex, i);
    const blob = new Blob([data], { type: mime });
    urls.set(i, URL.createObjectURL(blob));
  }
  return urls;
}
```

## wasm API remains stateless per call

No wasm changes. The `deferred_svg_pages` map inside wasm remains
"pending state for accessor bridge", meaning: the rendering call
populates it so the subsequent image accessor calls work. This is
not a cache because the JS viewer avoids duplicate rendering calls
through the viewer-side Map.

Document `deferred_svg_pages` comment to clarify its role:

```moonbit
/// Pending SVG render results, keyed by "handle:page". Populated by
/// pdf_page_to_svg_deferred, consumed by subsequent pdf_page_svg_image_*
/// accessors for the same (handle, page). This is NOT a cache — the
/// viewer layer is responsible for avoiding duplicate deferred-render
/// invocations via its own application-lifetime cache.
let deferred_svg_pages : Map[String, @svg.SvgDeferredResult] = Map::new()
```

## Files to modify

- `npm/demo/src/PdfViewer.tsx` — convert page SVG state to ref-backed
  Map cache, remove `pageSvgs` from `useCallback` deps, move Blob URL
  generation into `loadPageSvg`, add cleanup on document change /
  unmount
- `src/npm/wasm_api.mbt` — add clarifying doc comment to
  `deferred_svg_pages` (no behaviour change)

## Files NOT modified

- `src/svg/render.mbt`, `src/svg/page_render.mbt` — wasm rendering
  pipeline unchanged
- `npm/index.mjs`, `npm/index.cjs`, `npm/index.d.ts` — npm wrapper
  unchanged (cache lives in the consumer, not the library)

## Acceptance verification

1. `moon test --target native` — unchanged, 711 tests pass
2. `npm run build --prefix npm/demo` — succeeds
3. Manual browser check: scroll to page 7, away, and back; the
   browser dev tools Performance tab SHALL show one `pageToSvgDeferred`
   call, not two
4. No regression on local-fixture page 6/7 visual diff
