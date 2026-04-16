# @trkbt10/pdf-wasm

Wasm-gc package for the MoonBit `trkbt10/pdf` PDF library.

## Install

```bash
npm install @trkbt10/pdf-wasm
```

## Read a PDF

Node.js currently needs WebAssembly string builtins enabled:

```bash
node --experimental-wasm-stringref --experimental-wasm-imported-strings app.mjs
```

```javascript
import { openPdf } from "@trkbt10/pdf-wasm";
import { readFile } from "node:fs/promises";

const bytes = await readFile("sample.pdf");
const doc = await openPdf(bytes);

console.log(doc.pageCount());
console.log(doc.extractText(0));
console.log(doc.extractText());
console.log(doc.info());

const geometry = doc.pageGeometry(0);
const texts = doc.pageTextPositions(0);
console.log(geometry, texts.length);

const imageCount = doc.pageImageCount(0);
for (let imageIndex = 0; imageIndex < imageCount; imageIndex += 1) {
  const info = doc.pageImageInfo(0, imageIndex);
  const rgba = doc.pageImageRGBA(0, imageIndex);
  console.log(info.width, info.height, rgba.length);
}

doc.close();
```

## Create a PDF

```javascript
import { init, PdfContext } from "@trkbt10/pdf-wasm";
import { writeFile } from "node:fs/promises";

await init();

const ctx = PdfContext.create();
ctx.addPage(612, 792);
ctx.setTitle("My Document");

await writeFile("out.pdf", ctx.toBytes());
ctx.close();
```

## Edit an Existing Document

```javascript
import { openPdf, PdfContext } from "@trkbt10/pdf-wasm";

const doc = await openPdf(inputBytes);
const ctx = PdfContext.fromDocument(doc);
ctx.setTitle("Updated");

const outputBytes = ctx.toBytes();

ctx.close();
doc.close();
```

## Build

From this repository:

```bash
cd npm
npm run build
```

The build writes `npm/dist/pdf.wasm`.

## Exports

- `wasmPath()` returns the absolute path to `dist/pdf.wasm`.
- `wasmBytes()` reads the bundled wasm bytes.
- `instantiate(imports, wasmSource)` instantiates the wasm module.
- `init(wasmSource, imports)` initializes the default wasm instance.
- `openPdf(buffer)` opens a PDF and returns `PdfDocument`.
- `PdfDocument`, `PdfPage`, `PdfImage`, and `PdfContext` provide the high-level API.
