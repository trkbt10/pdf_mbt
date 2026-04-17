const fs = require("node:fs/promises");
const path = require("node:path");

const wasmFile = path.join(__dirname, "dist", "pdf.wasm");

let defaultInstance = null;

function wasmPath() {
  return wasmFile;
}

async function wasmBytes() {
  return fs.readFile(wasmFile);
}

async function instantiate(imports = {}, wasmSource) {
  const source = wasmSource ? await sourceBytes(wasmSource) : await wasmBytes();
  const module = await WebAssembly.compile(source, compileOptions());
  assertJsStringBuiltins(module);
  return WebAssembly.instantiate(module, importObject(imports));
}

async function init(wasmSource, imports = {}) {
  defaultInstance = await instantiate(imports, wasmSource);
  return defaultInstance;
}

async function openPdf(buffer, wasmSource) {
  return PdfDocument.open(buffer, wasmSource);
}

class PdfDocument {
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

  pageGeometry(pageIndex) {
    this.assertOpen();
    return parseJsonResult(this.wasm.pdf_page_geometry_json(this.handle, pageIndex));
  }

  pageTextPositions(pageIndex) {
    this.assertOpen();
    return parseJsonResult(
      this.wasm.pdf_page_text_positions_json(this.handle, pageIndex)
    ).texts;
  }

  pageToSvg(pageIndex) {
    this.assertOpen();
    const svg = this.wasm.pdf_page_to_svg(this.handle, pageIndex);
    if (!svg) {
      throw new Error("Failed to render page SVG");
    }
    return svg;
  }

  pageImageCount(page) {
    this.assertOpen();
    const count = this.wasm.pdf_page_image_count(this.handle, page);
    if (count < 0) {
      throw new Error("Failed to enumerate page images");
    }
    return count;
  }

  pageImageInfo(page, imageIndex) {
    this.assertOpen();
    return parseJsonResult(
      this.wasm.pdf_page_image_info_json(this.handle, page, imageIndex)
    );
  }

  pageImageRGBA(page, imageIndex) {
    this.assertOpen();
    return toUint8Array(this.wasm.pdf_page_image_rgba(this.handle, page, imageIndex));
  }

  renderData(pageIndex) {
    const geometry = this.pageGeometry(pageIndex);
    return {
      height: geometry.height,
      images: [],
      rotation: geometry.rotation,
      texts: this.pageTextPositions(pageIndex),
      width: geometry.width,
    };
  }

  pageImagesCount(page) {
    return this.pageImageCount(page);
  }

  images(page) {
    const count = this.pageImageCount(page);
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

class PdfPage {
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

  geometry() {
    return this.document.pageGeometry(this.index);
  }

  textPositions() {
    return this.document.pageTextPositions(this.index);
  }

  toSvg() {
    return this.document.pageToSvg(this.index);
  }

  images() {
    return this.document.images(this.index);
  }

  imageCount() {
    return this.document.pageImageCount(this.index);
  }
}

class PdfImage {
  constructor(document, page, index) {
    this.document = document;
    this.page = page;
    this.index = index;
  }

  width() {
    return this.info().width;
  }

  height() {
    return this.info().height;
  }

  colorSpace() {
    return this.info().colorSpace;
  }

  info() {
    return this.document.pageImageInfo(this.page, this.index);
  }

  toRGBA() {
    return this.document.pageImageRGBA(this.page, this.index);
  }
}

class PdfContext {
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
    return fs.readFile(source);
  }
  throw new TypeError("wasmSource must be a path, URL, ArrayBuffer, or typed array");
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
    "__moonbit_fs_unstable": {
      get_error_message: () => "filesystem unavailable in wasm",
      get_file_content: () => null,
      get_dir_files: () => null,
      read_file_to_bytes_new: () => -1,
      write_bytes_to_file_new: () => -1,
      path_exists: () => false,
      create_dir_new: () => -1,
      read_dir_new: () => -1,
      is_file_new: () => -1,
      is_dir_new: () => -1,
      remove_file_new: () => -1,
      remove_dir_new: () => -1,
      get_env_var: () => null,
      get_env_var_exists: () => false,
      begin_read_byte_array: () => 0,
      byte_array_read_byte: () => -1,
      finish_read_byte_array: () => {},
      begin_read_string: () => 0,
      string_read_char: () => -1,
      finish_read_string: () => {},
      begin_create_string: () => {},
      string_append_char: () => {},
      finish_create_string: () => "",
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

module.exports = {
  wasmPath,
  wasmBytes,
  instantiate,
  init,
  openPdf,
  PdfDocument,
  PdfPage,
  PdfImage,
  PdfContext,
};
