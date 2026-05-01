import type { PdfDocument } from "@trkbt10/pdf-wasm";
import type { SearchMatch } from "../store/viewer-store.types";

// Walks the document one page per microtask and accumulates query matches.
// Returns an iterator that yields after each page so the caller can commit
// progressive results to the store without blocking the main thread.
export async function* runSearchOverPages(
  source: PdfDocument,
  query: string,
  pageCount: number,
  signal: { cancelled: boolean }
): AsyncGenerator<{ pageIndex: number; matches: SearchMatch[] }, void, void> {
  if (query.length === 0) {
    return;
  }
  const needle = query.toLowerCase();
  for (let pageIndex = 0; pageIndex < pageCount; pageIndex += 1) {
    if (signal.cancelled) return;
    let body: string;
    try {
      body = source.extractText(pageIndex);
    } catch {
      continue;
    }
    const haystack = body.toLowerCase();
    const matches: SearchMatch[] = [];
    let from = 0;
    while (from <= haystack.length) {
      const found = haystack.indexOf(needle, from);
      if (found < 0) break;
      matches.push({ pageIndex, charOffset: found, length: needle.length });
      from = found + needle.length;
    }
    if (matches.length > 0) {
      yield { pageIndex, matches };
    }
    // Yield to the event loop between pages so the UI stays responsive.
    await Promise.resolve();
  }
}
