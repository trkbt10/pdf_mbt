import type { PdfDocument, PdfSvgImageInfo } from "@trkbt10/pdf-wasm";
import { register as registerBlobUrl } from "../lib/blob-urls";
import { parseImageIndex } from "../lib/parse-image-index";

const RAW_RGBA_IMAGE_MIME = "image/x-rgba8";

export interface PageSvgPayload {
  html: string;
  imageUrls: ReadonlyMap<number, string>;
}

// Renders one page's SVG (with deferred <image data-image-index>) and creates
// a Blob URL per deferred image. URLs are registered against the document
// handle so they are revoked deterministically on document close.
export async function renderPageSvg(
  source: PdfDocument,
  pageIndex: number
): Promise<PageSvgPayload> {
  const html = source.pageToSvgDeferred(pageIndex);
  const indexes = deferredSvgImageIndexes(html);
  const urls = new Map<number, string>();
  for (const imageIndex of indexes) {
    try {
      const url = await createDeferredImageUrl(source, pageIndex, imageIndex);
      if (url) {
        urls.set(imageIndex, url);
      }
    } catch (error) {
      console.warn(
        `pdf-demo: deferred image decode failed (page=${pageIndex} image=${imageIndex})`,
        error
      );
    }
  }
  return { html, imageUrls: urls };
}

export async function createDeferredImageUrl(
  source: PdfDocument,
  pageIndex: number,
  imageIndex: number
): Promise<string | null> {
  const info = source.pageSvgImageInfo(pageIndex, imageIndex);
  const { data, mime } = source.pageSvgImageData(pageIndex, imageIndex);
  const imageMime = info?.mime ?? mime;
  if (!imageMime || data.length === 0) {
    return null;
  }
  let url: string;
  if (imageMime === RAW_RGBA_IMAGE_MIME) {
    if (!info) {
      return null;
    }
    const blob = await rawRgbaImageBlob(data, info);
    url = URL.createObjectURL(blob);
  } else {
    url = URL.createObjectURL(
      new Blob([uint8ArrayBlobPart(data)], { type: imageMime })
    );
  }
  registerBlobUrl(source.handle, url);
  return url;
}

export function deferredSvgImageIndexes(svg: string): number[] {
  const parsed = new DOMParser().parseFromString(svg, "image/svg+xml");
  const seen = new Set<number>();
  for (const image of parsed.querySelectorAll<SVGImageElement>(
    "image[data-image-index]"
  )) {
    const idx = parseImageIndex(image.getAttribute("data-image-index"));
    if (idx !== null) {
      seen.add(idx);
    }
  }
  return Array.from(seen);
}

// Patches every <image data-image-index="N"> in `surface` with the
// corresponding Blob URL from `imageUrls`. Returns a cleanup function that
// disconnects the MutationObserver used to recover from in-place SVG re-inserts
// (StrictMode dev double-mount, parent re-renders).
//
// This function reads from the DOM and writes setAttribute. It must NOT call
// any React state setter; the lint rule enforces this when called from inside
// useLayoutEffect.
export function patchDeferredSvgImages(
  surface: HTMLElement,
  imageUrls: ReadonlyMap<number, string>
): () => void {
  applyHrefs(surface, imageUrls);
  const observer = new MutationObserver(() => applyHrefs(surface, imageUrls));
  observer.observe(surface, { childList: true, subtree: true });
  return () => observer.disconnect();
}

function applyHrefs(
  surface: HTMLElement,
  imageUrls: ReadonlyMap<number, string>
): void {
  const images = surface.querySelectorAll<SVGImageElement>(
    "image[data-image-index]"
  );
  for (const image of images) {
    const idx = parseImageIndex(image.getAttribute("data-image-index"));
    if (idx === null) continue;
    const url = imageUrls.get(idx);
    if (!url) continue;
    if (image.getAttribute("href") !== url) {
      image.setAttribute("href", url);
    }
  }
}

async function rawRgbaImageBlob(
  data: Uint8Array,
  info: PdfSvgImageInfo
): Promise<Blob> {
  if (info.width <= 0 || info.height <= 0) {
    throw new Error("Raw RGBA image dimensions are invalid");
  }
  if (data.length !== info.width * info.height * 4) {
    throw new Error("Raw RGBA byte count is invalid");
  }
  const imageData = new ImageData(
    new Uint8ClampedArray(data),
    info.width,
    info.height
  );
  if (typeof OffscreenCanvas !== "undefined") {
    const canvas = new OffscreenCanvas(info.width, info.height);
    const ctx = canvas.getContext("2d");
    if (ctx) {
      ctx.putImageData(imageData, 0, 0);
      return canvas.convertToBlob({ type: "image/png" });
    }
  }
  return rawRgbaImageBlobFromHtmlCanvas(imageData);
}

function rawRgbaImageBlobFromHtmlCanvas(imageData: ImageData): Promise<Blob> {
  const canvas = document.createElement("canvas");
  canvas.width = imageData.width;
  canvas.height = imageData.height;
  const ctx = canvas.getContext("2d");
  if (!ctx) {
    return Promise.reject(new Error("Canvas 2D context is unavailable"));
  }
  ctx.putImageData(imageData, 0, 0);
  return new Promise((resolve, reject) => {
    canvas.toBlob((blob) => {
      if (blob) resolve(blob);
      else reject(new Error("Canvas RGBA conversion failed"));
    }, "image/png");
  });
}

function uint8ArrayBlobPart(data: Uint8Array): BlobPart {
  // Copy into a fresh ArrayBuffer-backed Uint8Array so the Blob is stable
  // even if the source buffer is reused by wasm.
  const copy = new Uint8Array(data.byteLength);
  copy.set(data);
  return copy;
}
