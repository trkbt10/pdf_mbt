export interface PdfInfo {
  pageCount: number;
  title: string | null;
  author: string | null;
  subject: string | null;
  creator: string | null;
}

export interface PdfCapabilityEntry {
  featureName: string;
  category: string;
  status: "supported" | "partial" | "unsupported" | "unused";
  description: string;
}

export interface PdfCapabilityReport {
  entries: PdfCapabilityEntry[];
}

export interface PdfRenderText {
  text: string;
  x: number;
  y: number;
  fontSize: number;
  fontName: string | null;
}

export interface PdfPageGeometry {
  width: number;
  height: number;
  rotation: number;
}

export interface PdfImageInfo {
  width: number;
  height: number;
  colorSpace: string | null;
}

export interface PdfPageRenderData {
  width: number;
  height: number;
  rotation: number;
  texts: PdfRenderText[];
  images: [];
}

export function wasmPath(): string;

export function wasmBytes(): Promise<Uint8Array>;

export function instantiate(
  imports?: WebAssembly.Imports,
  wasmSource?: string | URL | BufferSource
): Promise<WebAssembly.Instance>;

export function init(
  wasmSource?: string | URL | BufferSource,
  imports?: WebAssembly.Imports
): Promise<WebAssembly.Instance>;

export function openPdf(
  buffer: Uint8Array | ArrayBuffer | ArrayBufferView,
  wasmSource?: string | URL | BufferSource
): Promise<PdfDocument>;

export class PdfDocument {
  constructor(wasmInstance: WebAssembly.Instance, handle: number);
  readonly wasmInstance: WebAssembly.Instance;
  readonly wasm: WebAssembly.Exports;
  readonly handle: number;
  readonly closed: boolean;
  static open(
    buffer: Uint8Array | ArrayBuffer | ArrayBufferView,
    wasmSource?: string | URL | BufferSource
  ): Promise<PdfDocument>;
  pageCount(): number;
  page(index: number): PdfPage;
  extractText(page?: number): string;
  extractTextLayout(page: number): string;
  pageGeometry(pageIndex: number): PdfPageGeometry;
  pageTextPositions(pageIndex: number): PdfRenderText[];
  pageImageCount(page: number): number;
  pageImageInfo(page: number, imageIndex: number): PdfImageInfo;
  pageImageRGBA(page: number, imageIndex: number): Uint8Array;
  renderData(pageIndex: number): PdfPageRenderData;
  pageImagesCount(page: number): number;
  images(page: number): PdfImage[];
  info(): PdfInfo;
  check(): PdfCapabilityReport;
  close(): void;
}

export class PdfPage {
  constructor(document: PdfDocument, index: number);
  readonly document: PdfDocument;
  readonly index: number;
  extractText(): string;
  extractTextLayout(): string;
  geometry(): PdfPageGeometry;
  textPositions(): PdfRenderText[];
  renderData(): PdfPageRenderData;
  images(): PdfImage[];
  imageCount(): number;
}

export class PdfImage {
  constructor(document: PdfDocument, page: number, index: number);
  readonly document: PdfDocument;
  readonly page: number;
  readonly index: number;
  width(): number;
  height(): number;
  colorSpace(): string | null;
  info(): PdfImageInfo;
  toRGBA(): Uint8Array;
}

export class PdfContext {
  constructor(wasmInstance: WebAssembly.Instance, handle: number);
  readonly wasmInstance: WebAssembly.Instance;
  readonly wasm: WebAssembly.Exports;
  readonly handle: number;
  readonly closed: boolean;
  static create(wasmInstance?: WebAssembly.Instance): PdfContext;
  static fromDocument(doc: PdfDocument): PdfContext;
  addPage(width: number, height: number): number;
  setTitle(title: string): void;
  toBytes(): Uint8Array;
  close(): void;
}
