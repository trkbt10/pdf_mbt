// Document-handle-scoped Blob URL registry.
// Lifetime: URLs are revoked only when their owning document handle is closed.
// Never on per-page unmount, never on StrictMode dev double-mount cleanup —
// that was the structural source of the page-revisit defect.

const registry = new Map<number, Set<string>>();

export function register(handle: number, url: string): void {
  let set = registry.get(handle);
  if (!set) {
    set = new Set();
    registry.set(handle, set);
  }
  set.add(url);
}

export function revokeAll(handle: number): void {
  const set = registry.get(handle);
  if (!set) {
    return;
  }
  for (const url of set) {
    URL.revokeObjectURL(url);
  }
  registry.delete(handle);
}

export function liveCount(handle: number): number {
  return registry.get(handle)?.size ?? 0;
}

export function liveCountAll(): number {
  let total = 0;
  for (const set of registry.values()) {
    total += set.size;
  }
  return total;
}

declare global {
  interface Window {
    __pdfDemoBlobUrls?: {
      liveCount: typeof liveCount;
      liveCountAll: typeof liveCountAll;
    };
  }
}

if (typeof window !== "undefined") {
  window.__pdfDemoBlobUrls = { liveCount, liveCountAll };
}
