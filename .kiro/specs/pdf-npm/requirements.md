# SDD Draft: npm Package for JavaScript/TypeScript

## Requirements

### Requirement 1: npm package structure
The project SHALL provide an npm-publishable package under `npm/` that
exposes the PDF library to JavaScript and TypeScript consumers.

#### 1.1: Package layout
```
npm/
  package.json        — npm metadata, main/module/types entry points
  tsconfig.json       — TypeScript configuration
  src/
    index.ts          — TypeScript API surface (re-exports)
    pdf.ts            — High-level API: open, extractText, extractImages
    low-level.ts      — Low-level API: PdfFile, PdfObject, streams
    types.ts          — TypeScript type definitions
  wasm/
    pdf.wasm          — Built wasm-gc binary (gitignored, built by script)
  scripts/
    build.sh          — moon build --target wasm-gc + wasm post-processing
  README.md           — npm package documentation
```

#### 1.2: MoonBit JS FFI bridge
Create `src/npm/` MoonBit package with `--target js` or `--target wasm-gc`
that exports functions callable from JavaScript via MoonBit's FFI system.

### Requirement 2: High-level JavaScript API
The npm package SHALL expose a high-level API for common PDF operations.

#### 2.1: Document opening
```typescript
import { openPdf } from '@trkbt10/pdf';
const doc = openPdf(buffer: Uint8Array);
```

#### 2.2: Text extraction
```typescript
const text = doc.extractText();           // all pages
const pageText = doc.page(0).extractText(); // single page
const layout = doc.page(0).extractTextLayout(); // with layout
```

#### 2.3: Image extraction
```typescript
const images = doc.page(0).images();
const rgba = images[0].toRGBA(); // Uint8Array of RGBA pixels
```

#### 2.4: Document info
```typescript
const info = doc.info();
// { title, author, pageCount, version, encrypted }
```

#### 2.5: Capability check
```typescript
const report = doc.check();
// Array of { feature, status, description }
```

### Requirement 3: Low-level JavaScript API
The npm package SHALL also expose low-level PDF object access.

#### 3.1: Object access
```typescript
const file = openPdfFile(buffer);
const obj = file.loadObject(objectId);
```

#### 3.2: Stream decoding
```typescript
const decoded = file.decodeStream(streamObj);
```

#### 3.3: Content stream parsing
```typescript
const instructions = page.contentInstructions();
```

### Requirement 4: PdfContext for JS
The npm package SHALL expose PdfContext for document creation and editing.

#### 4.1: Create new PDF
```typescript
const ctx = PdfContext.create();
const page = ctx.addPage(612, 792);
ctx.setTitle('My Document');
const bytes = ctx.toBytes(); // Uint8Array
```

#### 4.2: Edit existing PDF
```typescript
const ctx = PdfContext.fromDocument(doc);
ctx.setTitle('Updated');
const bytes = ctx.toBytes();
```

### Requirement 5: Build system
The npm package SHALL have a build script that compiles MoonBit to
wasm-gc and produces the JavaScript wrapper.

#### 5.1: Build command
`npm run build` in `npm/` SHALL:
1. Run `moon build --target wasm-gc` for the wasm binary
2. Generate TypeScript type definitions
3. Bundle the wasm + JS wrapper for npm publishing

#### 5.2: TypeScript types
The package SHALL ship `.d.ts` type definitions for all public APIs.
