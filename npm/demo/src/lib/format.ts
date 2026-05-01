import type { PdfPageGeometry } from "@trkbt10/pdf-wasm";

export function pageSizeSummary(geometry: PdfPageGeometry): string {
  const w = Math.round(geometry.width);
  const h = Math.round(geometry.height);
  return `${w} × ${h} (${geometry.rotation}°)`;
}

export function infoValue(value: string | number | null | undefined): string {
  if (value === null || value === undefined || value === "") {
    return "—";
  }
  return String(value);
}

export function errorMessage(error: unknown): string {
  if (error instanceof Error) {
    return error.message;
  }
  return String(error);
}

export function firstPdfFile(files: FileList | null): File | null {
  if (!files) {
    return null;
  }
  for (let i = 0; i < files.length; i += 1) {
    const file = files.item(i);
    if (file && (file.type === "application/pdf" || file.name.toLowerCase().endsWith(".pdf"))) {
      return file;
    }
  }
  return null;
}

export function clamp(value: number, min: number, max: number): number {
  if (value < min) return min;
  if (value > max) return max;
  return value;
}
