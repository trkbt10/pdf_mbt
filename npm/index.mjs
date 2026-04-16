const wasmFile = new URL("./dist/pdf.wasm", import.meta.url);

let defaultInstance = null;

export function wasmPath() {
  if (wasmFile.protocol === "file:") {
    return pathFromFileUrl(wasmFile);
  }
  return wasmFile.href;
}

export async function wasmBytes() {
  return sourceBytes(wasmFile);
}

export async function instantiate(imports = {}, wasmSource) {
  const source = wasmSource ? await sourceBytes(wasmSource) : await wasmBytes();
  const module = await WebAssembly.compile(source, compileOptions());
  assertJsStringBuiltins(module);
  return WebAssembly.instantiate(module, importObject(imports));
}

export async function init(wasmSource, imports = {}) {
  defaultInstance = await instantiate(imports, wasmSource);
  return defaultInstance;
}

export async function openPdf(buffer, wasmSource) {
  return PdfDocument.open(buffer, wasmSource);
}

export class PdfDocument {
  constructor(wasmInstance, handle) {
    this.wasmInstance = normalizeInstance(wasmInstance);
    this.wasm = this.wasmInstance.exports;
    this.handle = handle;
    this.closed = false;
  }

  static async open(buffer, wasmSource) {
    const instance = await defaultWasmInstance(wasmSource);
    const handle = instance.exports.pdf_open(toUint8Array(buffer));
    if (handle < 0) {
      throw new Error("Failed to open PDF");
    }
    return new PdfDocument(instance, handle);
  }

  pageCount() {
    this.assertOpen();
    const count = this.wasm.pdf_page_count(this.handle);
    if (count < 0) {
      throw new Error("Failed to read PDF page count");
    }
    return count;
  }

  page(index) {
    this.assertOpen();
    return new PdfPage(this, index);
  }

  extractText(page) {
    this.assertOpen();
    if (page === undefined) {
      const parts = [];
      for (let i = 0; i < this.pageCount(); i += 1) {
        parts.push(this.extractText(i));
      }
      return parts.join("\f");
    }
    return this.wasm.pdf_extract_text(this.handle, page);
  }

  extractTextLayout(page) {
    this.assertOpen();
    return this.wasm.pdf_extract_text_layout(this.handle, page);
  }

  renderData(pageIndex) {
    this.assertOpen();
    return parseJsonResult(this.wasm.pdf_page_render_json(this.handle, pageIndex));
  }

  pageImagesCount(page) {
    this.assertOpen();
    const count = this.wasm.pdf_page_images_count(this.handle, page);
    if (count < 0) {
      throw new Error("Failed to enumerate page images");
    }
    return count;
  }

  images(page) {
    const count = this.pageImagesCount(page);
    return Array.from({ length: count }, (_, index) => new PdfImage(this, page, index));
  }

  info() {
    this.assertOpen();
    return parseJsonResult(this.wasm.pdf_info_json(this.handle));
  }

  check() {
    this.assertOpen();
    return parseJsonResult(this.wasm.pdf_check_json(this.handle));
  }

  close() {
    if (!this.closed) {
      this.wasm.pdf_close(this.handle);
      this.closed = true;
    }
  }

  assertOpen() {
    if (this.closed) {
      throw new Error("PDF document is closed");
    }
  }
}

export class PdfPage {
  constructor(document, index) {
    this.document = document;
    this.index = index;
  }

  extractText() {
    return this.document.extractText(this.index);
  }

  extractTextLayout() {
    return this.document.extractTextLayout(this.index);
  }

  renderData() {
    return this.document.renderData(this.index);
  }

  images() {
    return this.document.images(this.index);
  }

  imageCount() {
    return this.document.pageImagesCount(this.index);
  }
}

export class PdfImage {
  constructor(document, page, index) {
    this.document = document;
    this.page = page;
    this.index = index;
  }

  width() {
    const width = this.document.wasm.pdf_image_width(
      this.document.handle,
      this.page,
      this.index
    );
    if (width < 0) {
      throw new Error("Invalid PDF image handle");
    }
    return width;
  }

  height() {
    const height = this.document.wasm.pdf_image_height(
      this.document.handle,
      this.page,
      this.index
    );
    if (height < 0) {
      throw new Error("Invalid PDF image handle");
    }
    return height;
  }

  toRGBA() {
    return this.document.wasm.pdf_image_rgba(
      this.document.handle,
      this.page,
      this.index
    );
  }
}

export class PdfContext {
  constructor(wasmInstance, handle) {
    this.wasmInstance = normalizeInstance(wasmInstance);
    this.wasm = this.wasmInstance.exports;
    this.handle = handle;
    this.closed = false;
  }

  static create(wasmInstance = defaultInstance) {
    const instance = requireInstance(wasmInstance);
    const handle = instance.exports.ctx_new();
    if (handle < 0) {
      throw new Error("Failed to create PDF context");
    }
    return new PdfContext(instance, handle);
  }

  static fromDocument(doc) {
    doc.assertOpen();
    const handle = doc.wasm.ctx_from_document(doc.handle);
    if (handle < 0) {
      throw new Error("Failed to create PDF context from document");
    }
    return new PdfContext(doc.wasmInstance, handle);
  }

  addPage(width, height) {
    this.assertOpen();
    const pageRef = this.wasm.ctx_add_page(this.handle, width, height);
    if (pageRef < 0) {
      throw new Error("Failed to add PDF page");
    }
    return pageRef;
  }

  setTitle(title) {
    this.assertOpen();
    this.wasm.ctx_set_title(this.handle, title);
  }

  toBytes() {
    this.assertOpen();
    return this.wasm.ctx_to_bytes(this.handle);
  }

  close() {
    if (!this.closed) {
      this.wasm.ctx_close(this.handle);
      this.closed = true;
    }
  }

  assertOpen() {
    if (this.closed) {
      throw new Error("PDF context is closed");
    }
  }
}

async function defaultWasmInstance(wasmSource) {
  if (!defaultInstance || wasmSource) {
    await init(wasmSource);
  }
  return defaultInstance;
}

async function sourceBytes(source) {
  if (source instanceof ArrayBuffer || ArrayBuffer.isView(source)) {
    return source;
  }
  if (typeof source === "string" || source instanceof URL) {
    if (shouldFetchSource(source)) {
      const response = await fetch(source);
      if (!response.ok) {
        throw new Error(`Failed to fetch wasm: ${response.status} ${response.statusText}`);
      }
      return response.arrayBuffer();
    }
    if (isNodeRuntime()) {
      return readFileInNode(source);
    }
  }
  throw new TypeError("wasmSource must be a path, URL, ArrayBuffer, or typed array");
}

async function readFileInNode(source) {
  const nodeImport = Function("specifier", "return import(specifier)");
  const { readFile } = await nodeImport("node:fs/promises");
  return readFile(source);
}

function shouldFetchSource(source) {
  if (typeof fetch !== "function") {
    return false;
  }
  if (!isNodeRuntime()) {
    return true;
  }
  if (source instanceof URL) {
    return source.protocol !== "file:";
  }
  try {
    const url = new URL(source);
    return url.protocol === "http:" || url.protocol === "https:";
  } catch {
    return false;
  }
}

function isNodeRuntime() {
  return typeof process !== "undefined" && !!process.versions?.node;
}

function pathFromFileUrl(url) {
  const path = decodeURIComponent(url.pathname);
  if (/^\/[A-Za-z]:/.test(path)) {
    return path.slice(1);
  }
  return path;
}

function compileOptions() {
  return {
    builtins: ["js-string"],
    importedStringConstants: "_",
  };
}

function importObject(extra) {
  return {
    ...extra,
    "_": new Proxy({}, { get: (_, name) => name }),
    "wasm:js-string": {
      ...(extra["wasm:js-string"] || {}),
      length: (value) => value.length,
      charCodeAt: (value, index) => value.charCodeAt(index),
      equals: (left, right) => left === right,
      concat: (left, right) => left + right,
      fromCodePoint: (value) => String.fromCodePoint(value),
      fromCharCodeArray: () => {
        throw new Error(jsStringBuiltinError());
      },
    },
    console: {
      ...(extra.console || {}),
      log: (value) => console.log(value),
    },
    pdf: {
      ...(extra.pdf || {}),
      uint8array_length: (arr) => arr.length,
      uint8array_get: (arr, index) => arr[index],
      uint8array_new: (length) => new Uint8Array(length),
      uint8array_set: (arr, index, value) => {
        arr[index] = value;
      },
    },
  };
}

function normalizeInstance(value) {
  if (value && value.instance) {
    return value.instance;
  }
  return requireInstance(value);
}

function requireInstance(value) {
  if (!value) {
    throw new Error("WASM module not initialized. Call init() first.");
  }
  return value;
}

function toUint8Array(buffer) {
  if (buffer instanceof Uint8Array) {
    return buffer;
  }
  if (buffer instanceof ArrayBuffer) {
    return new Uint8Array(buffer);
  }
  if (ArrayBuffer.isView(buffer)) {
    return new Uint8Array(buffer.buffer, buffer.byteOffset, buffer.byteLength);
  }
  throw new TypeError("Expected ArrayBuffer or typed array");
}

function parseJsonResult(json) {
  const result = JSON.parse(json);
  if (result.error) {
    throw new Error(result.error);
  }
  return result;
}

function assertJsStringBuiltins(module) {
  const missing = WebAssembly.Module.imports(module).some(
    (entry) => entry.module === "wasm:js-string"
  );
  if (missing) {
    throw new Error(jsStringBuiltinError());
  }
}

function jsStringBuiltinError() {
  return "This wasm-gc build requires WebAssembly JS string builtins. In Node.js, run with --experimental-wasm-stringref --experimental-wasm-imported-strings.";
}
