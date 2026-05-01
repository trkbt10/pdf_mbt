// Reads the PDF header version (e.g. "PDF 1.4") from the first 16 bytes.
export function pdfVersion(bytes: Uint8Array): string {
  const header = new TextDecoder().decode(bytes.subarray(0, 16));
  const match = /^%PDF-(\d\.\d)/.exec(header);
  return match ? `PDF ${match[1]}` : "Unknown";
}
