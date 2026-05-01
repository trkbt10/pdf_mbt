import type {
  PdfCapabilityReport,
  PdfInfo,
  PdfPageGeometry,
  PdfRenderText,
} from "@trkbt10/pdf-wasm";

export type WasmStatus = "loading" | "ready" | "error";

export type LoadStatus = "idle" | "loading" | "ready" | "error";

export interface PageSvgState {
  status: LoadStatus;
  html: string | null;
  error: string | null;
}

export interface PageTextState {
  status: LoadStatus;
  text: string | null;
  positions: PdfRenderText[] | null;
  error: string | null;
}

export interface PageState {
  svg: PageSvgState;
  text: PageTextState;
  images: ReadonlyMap<number, string>;
}

export type ZoomKind = "fit-width" | "fit-page" | "actual" | "custom";

export interface ZoomValue {
  kind: ZoomKind;
  scale: number;
}

export type SidebarTab = "thumbnails" | "properties";

export interface SidebarUi {
  open: boolean;
  tab: SidebarTab;
}

export interface SearchMatch {
  pageIndex: number;
  charOffset: number;
  length: number;
}

export interface SearchUi {
  query: string;
  matches: SearchMatch[];
  activeMatchIndex: number;
  status: LoadStatus;
}

export interface UiState {
  currentPage: number;
  // Monotonically increasing counter incremented only by explicit
  // navigation actions (toolbar prev/next, page input, thumbnail click,
  // keyboard shortcut). PageCanvas observes this — not currentPage — to
  // decide when to scroll. Visibility-driven currentPage updates do NOT
  // bump this, so scrolling does not snap back on its own.
  navigationRevision: number;
  zoom: ZoomValue;
  sidebar: SidebarUi;
  search: SearchUi;
  debug: boolean;
}

export interface DocumentMeta {
  handle: number | null;
  name: string | null;
  version: string | null;
  info: PdfInfo | null;
  pageCount: number;
  geometry: ReadonlyMap<number, PdfPageGeometry>;
  bytes: Uint8Array | null;
  capabilityReport: PdfCapabilityReport | null;
}

export interface ViewerStoreState {
  wasm: { status: WasmStatus; error: string | null };
  document: DocumentMeta;
  pages: ReadonlyMap<number, PageState>;
  ui: UiState;
}

// `currentPage` is intentionally absent: callers must go through
// navigateToPage (active, scrolls) or reportVisiblePage (passive, no scroll).
export interface UiPatch {
  zoom?: ZoomValue;
  sidebar?: Partial<SidebarUi>;
  search?: Partial<SearchUi>;
  debug?: boolean;
}
