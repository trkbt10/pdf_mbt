import { PdfDocument, type PdfPageGeometry } from "@trkbt10/pdf-wasm";

export interface OpenedDocument {
  source: PdfDocument;
  geometry: ReadonlyMap<number, PdfPageGeometry>;
}

export async function openPdfBytes(
  bytes: Uint8Array
): Promise<OpenedDocument> {
  const source = await PdfDocument.open(bytes);
  const pageCount = source.pageCount();
  const geometry = new Map<number, PdfPageGeometry>();
  for (let i = 0; i < pageCount; i += 1) {
    try {
      geometry.set(i, source.pageGeometry(i));
    } catch {
      geometry.set(i, { width: 612, height: 792, rotation: 0 });
    }
  }
  return { source, geometry };
}
