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

// Test 2: Lazy page geometry and text positions
const geometry = doc.pageGeometry(0);
assert.ok(geometry.width > 0, "expected positive page width");
assert.ok(geometry.height > 0, "expected positive page height");
assert.equal(geometry.rotation, 0, "expected default page rotation");
const texts = doc.pageTextPositions(0);
assert.ok(texts.length > 0, "expected positioned render text");
assert.ok(
  texts.some((item) => item.text.includes("HelloWorld")),
  "expected HelloWorld in render text"
);
const svg = doc.pageToSvg(0);
assert.ok(svg.startsWith("<svg"), "expected page SVG markup");
assert.ok(svg.includes("<text"), "expected SVG text element");
assert.ok(svg.includes("HelloWorld"), "expected SVG text content");
console.log("✓ Lazy page geometry and text positions");

// Test 3: SVG path output
const shapeDoc = await PdfDocument.open(minimalPdfWithPath());
const shapeSvg = shapeDoc.pageToSvg(0);
assert.ok(shapeSvg.includes("<path"), "expected SVG path element");
assert.ok(shapeSvg.includes("fill=\"#000000\""), "expected default fill color");
console.log("✓ SVG path rendering");

// Test 4: Document info
const info = doc.info();
assert.equal(info.pageCount, 1);
console.log("✓ Document info");

// Test 5: Multi-page PDF
const multiPage = await readFile(
  "../spec/pdf20examples/PDF 2.0 with page level output intent.pdf"
);
const doc2 = await PdfDocument.open(multiPage);
assert.equal(doc2.pageCount(), 2, "expected 2 pages");
console.log("✓ Multi-page PDF");

// Test 6: PdfContext create roundtrip
const ctx = PdfContext.create();
ctx.addPage(612, 792);
ctx.setTitle("Test Document");
const bytes = ctx.toBytes();
const roundtrip = await PdfDocument.open(bytes);
assert.equal(roundtrip.pageCount(), 1);
console.log("✓ PdfContext roundtrip");

doc.close();
shapeDoc.close();
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

function minimalPdfWithPath() {
  const content = "72 72 m 540 72 l 540 720 l h f";
  const objects = [
    "<< /Type /Catalog /Pages 2 0 R >>",
    "<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
    "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Contents 4 0 R >>",
    `<< /Length ${content.length} >>\nstream\n${content}\nendstream`,
  ];
  let pdf = "%PDF-2.0\n";
  const offsets = [0];
  for (let index = 0; index < objects.length; index += 1) {
    offsets.push(pdf.length);
    pdf += `${index + 1} 0 obj\n${objects[index]}\nendobj\n`;
  }
  const xrefOffset = pdf.length;
  pdf += `xref\n0 ${objects.length + 1}\n`;
  pdf += "0000000000 65535 f \n";
  for (let index = 1; index < offsets.length; index += 1) {
    pdf += `${offsets[index].toString().padStart(10, "0")} 00000 n \n`;
  }
  pdf += `trailer\n<< /Size ${objects.length + 1} /Root 1 0 R >>\n`;
  pdf += `startxref\n${xrefOffset}\n%%EOF\n`;
  return new TextEncoder().encode(pdf);
}
