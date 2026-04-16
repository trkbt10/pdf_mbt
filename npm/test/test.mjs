import { execFileSync } from "node:child_process";
import { strict as assert } from "node:assert";
import { readFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import { PdfContext, PdfDocument } from "../index.mjs";

const requiredWasmFlags = [
  "--experimental-wasm-stringref",
  "--experimental-wasm-imported-strings",
];

if (shouldRerunWithWasmFlags()) {
  execFileSync(
    process.execPath,
    [...requiredWasmFlags, ...process.execArgv, fileURLToPath(import.meta.url)],
    {
      env: { ...process.env, PDF_WASM_TEST_FLAGS: "1" },
      stdio: "inherit",
    }
  );
  process.exit(0);
}

// Test 1: Open Simple PDF 2.0 and extract text
const simple = await readFile("../spec/pdf20examples/Simple PDF 2.0 file.pdf");
const doc = await PdfDocument.open(simple);
assert.equal(doc.pageCount(), 1, "expected 1 page");
const text = doc.extractText(0);
assert.ok(text.includes("HelloWorld"), "expected HelloWorld, got: " + text);
console.log("✓ Simple PDF text extraction");

// Test 2: Page render data
const renderData = doc.renderData(0);
assert.ok(renderData.width > 0, "expected positive page render width");
assert.ok(renderData.height > 0, "expected positive page render height");
assert.ok(renderData.texts.length > 0, "expected positioned render text");
assert.ok(
  renderData.texts.some((item) => item.text.includes("HelloWorld")),
  "expected HelloWorld in render text"
);
console.log("✓ Page render data");

// Test 3: Document info
const info = doc.info();
assert.equal(info.pageCount, 1);
console.log("✓ Document info");

// Test 4: Multi-page PDF
const multiPage = await readFile(
  "../spec/pdf20examples/PDF 2.0 with page level output intent.pdf"
);
const doc2 = await PdfDocument.open(multiPage);
assert.equal(doc2.pageCount(), 2, "expected 2 pages");
console.log("✓ Multi-page PDF");

// Test 5: PdfContext create roundtrip
const ctx = PdfContext.create();
ctx.addPage(612, 792);
ctx.setTitle("Test Document");
const bytes = ctx.toBytes();
const roundtrip = await PdfDocument.open(bytes);
assert.equal(roundtrip.pageCount(), 1);
console.log("✓ PdfContext roundtrip");

doc.close();
doc2.close();
roundtrip.close();
ctx.close();
console.log("All tests passed");

function shouldRerunWithWasmFlags() {
  if (process.env.PDF_WASM_TEST_FLAGS === "1") {
    return false;
  }
  return requiredWasmFlags.some((flag) => !process.execArgv.includes(flag));
}
