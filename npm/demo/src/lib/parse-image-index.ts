// Parses the `data-image-index` attribute that the SVG renderer emits on
// deferred <image> placeholders. Empty / non-numeric / negative values are
// treated as missing.
export function parseImageIndex(raw: string | null | undefined): number | null {
  if (raw === null || raw === undefined || raw === "") {
    return null;
  }
  const value = Number(raw);
  if (!Number.isInteger(value) || value < 0) {
    return null;
  }
  return value;
}
