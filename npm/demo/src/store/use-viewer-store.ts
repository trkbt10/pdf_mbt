import { useSyncExternalStore } from "react";
import { getSnapshot, getServerSnapshot, subscribe } from "./viewer-store";
import type {
  DocumentMeta,
  PageState,
  SearchUi,
  UiState,
  WasmStatus,
} from "./viewer-store.types";

// Stable empty values so selectors that hit a missing key still return a
// reference-stable result and don't trigger spurious re-renders.
const EMPTY_PAGE: PageState = {
  svg: { status: "idle", html: null, error: null },
  text: { status: "idle", text: null, positions: null, error: null },
  images: new Map(),
};

function useStore<T>(selector: (s: ReturnType<typeof getSnapshot>) => T): T {
  return useSyncExternalStore(
    subscribe,
    () => selector(getSnapshot()),
    () => selector(getServerSnapshot())
  );
}

export function useWasmStatus(): { status: WasmStatus; error: string | null } {
  return useStore((s) => s.wasm);
}

export function useDocumentMeta(): DocumentMeta {
  return useStore((s) => s.document);
}

export function usePageCount(): number {
  return useStore((s) => s.document.pageCount);
}

export function usePage(pageIndex: number): PageState {
  return useStore((s) => s.pages.get(pageIndex) ?? EMPTY_PAGE);
}

export function useUi(): UiState {
  return useStore((s) => s.ui);
}

export function useCurrentPage(): number {
  return useStore((s) => s.ui.currentPage);
}

export function useSearch(): SearchUi {
  return useStore((s) => s.ui.search);
}
