import type { PdfDocument, PdfSvgImageInfo } from "@trkbt10/pdf-wasm";
import { register as registerBlobUrl } from "../lib/blob-urls";
import { parseImageIndex } from "../lib/parse-image-index";

const RAW_RGBA_IMAGE_MIME = "image/x-rgba8";
const PDF_FLATE_RGB_MIME = "image/x-pdf-flate-rgb";
const PDF_FLATE_GRAY_MIME = "image/x-pdf-flate-gray";
const PDF_JPEG_WITH_SMASK_MIME = "image/x-pdf-jpeg-smask";
const PDF_JPEG_SMASK_MAGIC = "PSMK";

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
  } else if (imageMime === PDF_FLATE_RGB_MIME) {
    const blob = await flateSamplesToPngBlob(data, info, 3);
    url = URL.createObjectURL(blob);
  } else if (imageMime === PDF_FLATE_GRAY_MIME) {
    const blob = await flateSamplesToPngBlob(data, info, 1);
    url = URL.createObjectURL(blob);
  } else if (imageMime === PDF_JPEG_WITH_SMASK_MIME) {
    const blob = await jpegWithSMaskToPngBlob(data);
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

// Decompresses a zlib-encoded PDF FlateDecode stream of raw 8-bit samples
// (RGB or grayscale) and rasterizes it to a PNG via OffscreenCanvas. We rely
// on the browser's native zlib (DecompressionStream("deflate")) so the
// decompression cost moves out of wasm-gc, which is the main source of the
// multi-second hangs on photo-heavy PDFs.
async function flateSamplesToPngBlob(
  data: Uint8Array,
  info: PdfSvgImageInfo | null,
  components: 1 | 3
): Promise<Blob> {
  if (!info || info.width <= 0 || info.height <= 0) {
    throw new Error("FlateDecode passthrough requires width/height");
  }
  const samples = await inflateZlib(data);
  const expected = info.width * info.height * components;
  if (samples.length < expected) {
    throw new Error(
      `FlateDecode passthrough sample count mismatch: got ${samples.length}, expected ${expected}`
    );
  }
  const rgba = expandSamplesToRgba(samples, info.width, info.height, components);
  return imageDataToPngBlob(rgba, info.width, info.height);
}

// Unpacks the framed JPEG-with-SMask payload built in
// wasm_api.mbt:jpeg_passthrough_entry, decodes the JPEG natively via
// createImageBitmap, decompresses the soft mask via DecompressionStream,
// composites the alpha channel onto the JPEG, and returns the result as a
// PNG so the SVG <image> can use it like any other Blob URL.
async function jpegWithSMaskToPngBlob(data: Uint8Array): Promise<Blob> {
  const view = new DataView(data.buffer, data.byteOffset, data.byteLength);
  if (data.length < 4) {
    throw new Error("JPEG-with-SMask payload truncated");
  }
  const magic = String.fromCharCode(data[0], data[1], data[2], data[3]);
  if (magic !== PDF_JPEG_SMASK_MAGIC) {
    throw new Error(`JPEG-with-SMask payload missing magic: ${magic}`);
  }
  let cursor = 4;
  const width = view.getUint32(cursor); cursor += 4;
  const height = view.getUint32(cursor); cursor += 4;
  const smaskWidth = view.getUint32(cursor); cursor += 4;
  const smaskHeight = view.getUint32(cursor); cursor += 4;
  const smaskLen = view.getUint32(cursor); cursor += 4;
  const smaskBytes = data.subarray(cursor, cursor + smaskLen);
  cursor += smaskLen;
  const jpegLen = view.getUint32(cursor); cursor += 4;
  const jpegBytes = data.subarray(cursor, cursor + jpegLen);

  const [bitmap, smaskSamples] = await Promise.all([
    createImageBitmap(
      new Blob([uint8ArrayBlobPart(jpegBytes)], { type: "image/jpeg" })
    ),
    inflateZlib(smaskBytes),
  ]);
  try {
    return await compositeJpegWithAlpha(
      bitmap,
      width,
      height,
      smaskSamples,
      smaskWidth,
      smaskHeight
    );
  } finally {
    if (typeof bitmap.close === "function") {
      bitmap.close();
    }
  }
}

async function compositeJpegWithAlpha(
  bitmap: ImageBitmap,
  width: number,
  height: number,
  smaskSamples: Uint8Array,
  smaskWidth: number,
  smaskHeight: number
): Promise<Blob> {
  const canvas = createCanvas(width, height);
  const ctx = canvas.getContext("2d");
  if (!ctx) {
    throw new Error("Canvas 2D context is unavailable");
  }
  ctx.drawImage(bitmap, 0, 0, width, height);
  const imageData = ctx.getImageData(0, 0, width, height);
  applySmaskAlpha(
    imageData.data,
    width,
    height,
    smaskSamples,
    smaskWidth,
    smaskHeight
  );
  ctx.putImageData(imageData, 0, 0);
  return canvasToBlob(canvas);
}

function applySmaskAlpha(
  pixels: Uint8ClampedArray,
  width: number,
  height: number,
  smaskSamples: Uint8Array,
  smaskWidth: number,
  smaskHeight: number
): void {
  // The PDF SMask grid does not have to match the base image grid. Resample
  // with nearest-neighbour: that matches what the wasm path does and avoids a
  // second canvas allocation just to bilinear-upscale a mostly-feathered alpha
  // mask.
  if (smaskWidth === width && smaskHeight === height) {
    for (let i = 0, p = 3; i < smaskSamples.length; i += 1, p += 4) {
      pixels[p] = smaskSamples[i];
    }
    return;
  }
  const xScale = smaskWidth / width;
  const yScale = smaskHeight / height;
  for (let y = 0; y < height; y += 1) {
    const sy = Math.min(smaskHeight - 1, Math.floor(y * yScale));
    const srcRow = sy * smaskWidth;
    const dstRow = y * width;
    for (let x = 0; x < width; x += 1) {
      const sx = Math.min(smaskWidth - 1, Math.floor(x * xScale));
      pixels[(dstRow + x) * 4 + 3] = smaskSamples[srcRow + sx];
    }
  }
}

function expandSamplesToRgba(
  samples: Uint8Array,
  width: number,
  height: number,
  components: 1 | 3
): ImageData {
  const out = new Uint8ClampedArray(width * height * 4);
  if (components === 3) {
    for (let i = 0, j = 0; i < width * height; i += 1, j += 4) {
      const k = i * 3;
      out[j] = samples[k];
      out[j + 1] = samples[k + 1];
      out[j + 2] = samples[k + 2];
      out[j + 3] = 255;
    }
  } else {
    for (let i = 0, j = 0; i < width * height; i += 1, j += 4) {
      const value = samples[i];
      out[j] = value;
      out[j + 1] = value;
      out[j + 2] = value;
      out[j + 3] = 255;
    }
  }
  return new ImageData(out, width, height);
}

async function inflateZlib(data: Uint8Array): Promise<Uint8Array> {
  const blob = new Blob([uint8ArrayBlobPart(data)]);
  const stream = blob.stream().pipeThrough(new DecompressionStream("deflate"));
  const buffer = await new Response(stream).arrayBuffer();
  return new Uint8Array(buffer);
}

async function imageDataToPngBlob(
  imageData: ImageData,
  width: number,
  height: number
): Promise<Blob> {
  const canvas = createCanvas(width, height);
  const ctx = canvas.getContext("2d");
  if (!ctx) {
    throw new Error("Canvas 2D context is unavailable");
  }
  ctx.putImageData(imageData, 0, 0);
  return canvasToBlob(canvas);
}

function createCanvas(
  width: number,
  height: number
): OffscreenCanvas | HTMLCanvasElement {
  if (typeof OffscreenCanvas !== "undefined") {
    return new OffscreenCanvas(width, height);
  }
  const canvas = document.createElement("canvas");
  canvas.width = width;
  canvas.height = height;
  return canvas;
}

function canvasToBlob(
  canvas: OffscreenCanvas | HTMLCanvasElement
): Promise<Blob> {
  if (canvas instanceof OffscreenCanvas) {
    return canvas.convertToBlob({ type: "image/png" });
  }
  return new Promise((resolve, reject) => {
    canvas.toBlob((blob) => {
      if (blob) resolve(blob);
      else reject(new Error("Canvas to PNG conversion failed"));
    }, "image/png");
  });
}
