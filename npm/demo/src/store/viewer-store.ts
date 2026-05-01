import type {
  PdfCapabilityReport,
  PdfDocument,
  PdfInfo,
} from "@trkbt10/pdf-wasm";
import { revokeAll as revokeAllBlobUrls } from "../lib/blob-urls";
import { errorMessage } from "../lib/format";
import { pdfVersion } from "../lib/pdf-version";
import { openPdfBytes } from "../pdf-api/open-document";
import { renderPageSvg } from "../pdf-api/render-page";
import { runSearchOverPages } from "../pdf-api/search-index";
import type {
  PageState,
  SearchMatch,
  UiPatch,
  ViewerStoreState,
  WasmStatus,
} from "./viewer-store.types";

// Module-scoped, React-independent store. Components observe via
// useSyncExternalStore; mutations happen only inside the action functions
// exported below. State is structurally shared so selectors that read an
// unchanged branch get a stable reference and skip re-renders.

const initialState: ViewerStoreState = {
  wasm: { status: "loading", error: null },
  document: {
    handle: null,
    name: null,
    version: null,
    info: null,
    pageCount: 0,
    geometry: new Map(),
    bytes: null,
    capabilityReport: null,
  },
  pages: new Map(),
  ui: {
    currentPage: 0,
    navigationRevision: 0,
    zoom: { kind: "fit-width", scale: 1 },
    sidebar: { open: true, tab: "thumbnails" },
    search: { query: "", matches: [], activeMatchIndex: -1, status: "idle" },
    debug: false,
  },
};

let state: ViewerStoreState = initialState;
const listeners = new Set<() => void>();

// Live reference to the wasm document. Kept here (not in state) because it
// is not React-observable data — components never read it.
let liveSource: PdfDocument | null = null;

// In-flight search cancellation token. A new query supersedes the old one.
let searchSignal: { cancelled: boolean } = { cancelled: true };

export function getSnapshot(): ViewerStoreState {
  return state;
}

export function getServerSnapshot(): ViewerStoreState {
  return state;
}

export function subscribe(listener: () => void): () => void {
  listeners.add(listener);
  return () => listeners.delete(listener);
}

function commit(next: ViewerStoreState): void {
  if (next === state) return;
  state = next;
  for (const listener of listeners) {
    listener();
  }
}

// ---------- actions ----------

export function setWasmStatus(status: WasmStatus, error: string | null): void {
  commit({ ...state, wasm: { status, error } });
}

export async function openDocument(
  bytes: Uint8Array,
  name: string
): Promise<void> {
  // Tear down any prior document first.
  if (liveSource) {
    const prevHandle = liveSource.handle;
    try {
      liveSource.close();
    } catch {
      // ignore close failures
    }
    revokeAllBlobUrls(prevHandle);
    liveSource = null;
  }
  searchSignal.cancelled = true;

  let opened;
  try {
    opened = await openPdfBytes(bytes);
  } catch (error) {
    commit({
      ...state,
      wasm: { status: "ready", error: null },
      document: { ...initialState.document },
      pages: new Map(),
          ui: { ...state.ui, currentPage: 0, search: initialState.ui.search },
    });
    throw new Error(`Failed to open ${name}: ${errorMessage(error)}`);
  }

  liveSource = opened.source;
  const info: PdfInfo = safeInfo(opened.source);
  const pageCount = opened.source.pageCount();

  commit({
    ...state,
    document: {
      handle: opened.source.handle,
      name,
      version: pdfVersion(bytes),
      info,
      pageCount,
      geometry: opened.geometry,
      bytes,
      capabilityReport: null,
    },
    pages: new Map(),
      ui: {
      ...state.ui,
      currentPage: 0,
      search: { ...initialState.ui.search },
    },
  });
}

export function closeDocument(): void {
  if (liveSource) {
    const handle = liveSource.handle;
    try {
      liveSource.close();
    } catch {
      // ignore
    }
    revokeAllBlobUrls(handle);
    liveSource = null;
  }
  searchSignal.cancelled = true;
  commit({
    ...state,
    document: { ...initialState.document },
    pages: new Map(),
      ui: { ...state.ui, currentPage: 0, search: { ...initialState.ui.search } },
  });
}

export function requestPageSvg(pageIndex: number): void {
  if (!liveSource) return;
  const current = state.pages.get(pageIndex);
  if (current && current.svg.status !== "idle") return;
  const seedPage: PageState = {
    svg: { status: "loading", html: null, error: null },
    text: current?.text ?? { status: "idle", text: null, positions: null, error: null },
    images: current?.images ?? new Map(),
  };
  commit({ ...state, pages: setPage(state.pages, pageIndex, seedPage) });

  const handleAtRequest = liveSource.handle;
  const sourceAtRequest = liveSource;
  queueMicrotask(async () => {
    if (!liveSource || liveSource.handle !== handleAtRequest) return;
    try {
      const payload = await renderPageSvg(sourceAtRequest, pageIndex);
      if (!liveSource || liveSource.handle !== handleAtRequest) return;
      const existing = state.pages.get(pageIndex);
      const nextPage: PageState = {
        svg: { status: "ready", html: payload.html, error: null },
        text: existing?.text ?? { status: "idle", text: null, positions: null, error: null },
        images: payload.imageUrls,
      };
      commit({ ...state, pages: setPage(state.pages, pageIndex, nextPage) });
    } catch (error) {
      if (!liveSource || liveSource.handle !== handleAtRequest) return;
      const existing = state.pages.get(pageIndex);
      const nextPage: PageState = {
        svg: { status: "error", html: null, error: errorMessage(error) },
        text: existing?.text ?? { status: "idle", text: null, positions: null, error: null },
        images: existing?.images ?? new Map(),
      };
      commit({ ...state, pages: setPage(state.pages, pageIndex, nextPage) });
    }
  });
}

export function requestPageText(pageIndex: number): void {
  if (!liveSource) return;
  const current = state.pages.get(pageIndex);
  if (current?.text.status === "loading" || current?.text.status === "ready") return;
  const seedPage: PageState = {
    svg: current?.svg ?? { status: "idle", html: null, error: null },
    text: { status: "loading", text: null, positions: null, error: null },
    images: current?.images ?? new Map(),
  };
  commit({ ...state, pages: setPage(state.pages, pageIndex, seedPage) });

  const handleAtRequest = liveSource.handle;
  const sourceAtRequest = liveSource;
  queueMicrotask(() => {
    if (!liveSource || liveSource.handle !== handleAtRequest) return;
    try {
      const text = sourceAtRequest.extractText(pageIndex);
      const positions = sourceAtRequest.pageTextPositions(pageIndex);
      if (!liveSource || liveSource.handle !== handleAtRequest) return;
      const existing = state.pages.get(pageIndex);
      const nextPage: PageState = {
        svg: existing?.svg ?? { status: "idle", html: null, error: null },
        text: { status: "ready", text, positions, error: null },
        images: existing?.images ?? new Map(),
      };
      commit({ ...state, pages: setPage(state.pages, pageIndex, nextPage) });
    } catch (error) {
      if (!liveSource || liveSource.handle !== handleAtRequest) return;
      const existing = state.pages.get(pageIndex);
      const nextPage: PageState = {
        svg: existing?.svg ?? { status: "idle", html: null, error: null },
        text: { status: "ready", text: null, positions: null, error: errorMessage(error) },
        images: existing?.images ?? new Map(),
      };
      commit({ ...state, pages: setPage(state.pages, pageIndex, nextPage) });
    }
  });
}

export function requestCapabilityReport(): void {
  if (!liveSource) return;
  if (state.document.capabilityReport) return;
  let report: PdfCapabilityReport;
  try {
    report = liveSource.check();
  } catch (error) {
    console.warn("pdf-demo: capability check failed", error);
    return;
  }
  commit({
    ...state,
    document: { ...state.document, capabilityReport: report },
  });
}

export function runSearch(query: string): void {
  // Cancel any in-flight search.
  searchSignal.cancelled = true;
  searchSignal = { cancelled: false };
  const localSignal = searchSignal;

  const trimmed = query.trim();
  if (trimmed.length === 0) {
    commit({
      ...state,
      ui: {
        ...state.ui,
        search: { query, matches: [], activeMatchIndex: -1, status: "idle" },
      },
    });
    return;
  }

  commit({
    ...state,
    ui: {
      ...state.ui,
      search: { query, matches: [], activeMatchIndex: -1, status: "loading" },
    },
  });

  if (!liveSource) return;
  const handleAtStart = liveSource.handle;
  const source = liveSource;
  const pageCount = state.document.pageCount;

  void (async () => {
    const accumulated: SearchMatch[] = [];
    for await (const batch of runSearchOverPages(
      source,
      trimmed,
      pageCount,
      localSignal
    )) {
      if (localSignal.cancelled || !liveSource || liveSource.handle !== handleAtStart) {
        return;
      }
      accumulated.push(...batch.matches);
      commit({
        ...state,
        ui: {
          ...state.ui,
          search: {
            query: trimmed,
            matches: accumulated.slice(),
            activeMatchIndex: accumulated.length > 0 ? 0 : -1,
            status: "loading",
          },
        },
      });
    }
    if (localSignal.cancelled) return;
    commit({
      ...state,
      ui: {
        ...state.ui,
        search: {
          query: trimmed,
          matches: accumulated,
          activeMatchIndex: accumulated.length > 0 ? 0 : -1,
          status: "ready",
        },
      },
    });
  })();
}

export function setUi(patch: UiPatch): void {
  const next = { ...state.ui };
  if (patch.zoom) next.zoom = patch.zoom;
  if (patch.sidebar) next.sidebar = { ...next.sidebar, ...patch.sidebar };
  if (patch.search) next.search = { ...next.search, ...patch.search };
  if (patch.debug !== undefined) next.debug = patch.debug;
  commit({ ...state, ui: next });
}

// Explicit, user-initiated navigation: toolbar prev/next, page input,
// thumbnail click, keyboard shortcut. Bumps navigationRevision so
// PageCanvas knows to scroll. Use this — NOT setUi({ currentPage }) —
// for any code path that wants the page to actually scroll into view.
export function navigateToPage(pageIndex: number): void {
  const max = Math.max(0, state.document.pageCount - 1);
  const target = pageIndex < 0 ? 0 : pageIndex > max ? max : pageIndex;
  commit({
    ...state,
    ui: {
      ...state.ui,
      currentPage: target,
      navigationRevision: state.ui.navigationRevision + 1,
    },
  });
}

// Passive update from scroll-driven visibility callbacks. Updates the
// status bar / thumbnail highlight but does NOT bump navigationRevision,
// so PageCanvas leaves the user's scroll position alone.
export function reportVisiblePage(pageIndex: number): void {
  if (state.ui.currentPage === pageIndex) return;
  commit({
    ...state,
    ui: { ...state.ui, currentPage: pageIndex },
  });
}

// ---------- helpers ----------

function setPage(
  pages: ReadonlyMap<number, PageState>,
  pageIndex: number,
  next: PageState
): ReadonlyMap<number, PageState> {
  const map = new Map(pages);
  map.set(pageIndex, next);
  return map;
}

function safeInfo(source: PdfDocument): PdfInfo {
  try {
    return source.info();
  } catch {
    return {
      pageCount: source.pageCount(),
      title: null,
      author: null,
      subject: null,
      creator: null,
    };
  }
}

// Test-only reset hook — exported under __ prefix, not part of the public API.
export function __resetForTest(): void {
  if (liveSource) {
    try { liveSource.close(); } catch { /* ignore */ }
    revokeAllBlobUrls(liveSource.handle);
    liveSource = null;
  }
  searchSignal.cancelled = true;
  state = initialState;
  for (const listener of listeners) listener();
}

// Document bytes accessor for the download button (kept in state.document.bytes).
export function getCurrentDocumentBytes(): Uint8Array | null {
  return state.document.bytes;
}
