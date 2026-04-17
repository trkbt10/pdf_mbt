import { execFileSync, spawnSync } from "node:child_process";
import { existsSync, readFileSync, writeFileSync } from "node:fs";
import { mkdtempSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { PNG } from "./visual/node_modules/pngjs/browser.js";
import pixelmatch from "./visual/node_modules/pixelmatch/index.js";
import { PdfDocument } from "../index.mjs";

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

const pdf = process.env.PDF_003Z_FIXTURE ?? "<local-fixture>";
if (!existsSync(pdf)) {
  console.log(`visual crop skipped: missing ${pdf}`);
  process.exit(0);
}

const tools = ["pdftoppm", "rsvg-convert", "magick"];
const missing = tools.filter((tool) => !toolAvailable(tool));
if (missing.length > 0) {
  console.log(`visual crop skipped: missing ${missing.join(", ")}`);
  process.exit(0);
}

const workdir = mkdtempSync(join(tmpdir(), "pdf-visual-crop-"));
const diff = await compareCrop({
  pdf,
  pageIndex: 5,
  crop: { x: 185, y: 20, width: 130, height: 20 },
  workdir,
});

if (diff > 0.03) {
  throw new Error(
    `local-fixture page 6 Handset crop diff ${(diff * 100).toFixed(2)}% exceeds 3%; workdir: ${workdir}`
  );
}

console.log(`✓ local-fixture page 6 Handset crop diff ${(diff * 100).toFixed(2)}%`);

async function compareCrop({ pdf, pageIndex, crop, workdir }) {
  const document = await PdfDocument.open(readFileSync(pdf));
  try {
    const svg = document.pageToSvg(pageIndex);
    const svgPath = join(workdir, "page.svg");
    const svgPng = join(workdir, "page-svg.png");
    const svgCrop = join(workdir, "page-svg-crop.png");
    const referencePrefix = join(workdir, "page-ref");
    const referencePng = `${referencePrefix}.png`;
    const referenceCrop = join(workdir, "page-ref-crop.png");

    writeFileSync(svgPath, svg);
    execFileSync("pdftoppm", [
      "-png",
      "-singlefile",
      "-r",
      "72",
      "-f",
      String(pageIndex + 1),
      "-l",
      String(pageIndex + 1),
      pdf,
      referencePrefix,
    ]);
    execFileSync("rsvg-convert", [svgPath, "-o", svgPng]);
    cropPng(referencePng, referenceCrop, crop);
    cropPng(svgPng, svgCrop, crop);
    return pixelmatchDiff(referenceCrop, svgCrop);
  } finally {
    document.close();
  }
}

function cropPng(input, output, crop) {
  execFileSync("magick", [
    input,
    "-crop",
    `${crop.width}x${crop.height}+${crop.x}+${crop.y}`,
    output,
  ]);
}

function pixelmatchDiff(referencePng, svgPng) {
  const reference = PNG.sync.read(readFileSync(referencePng));
  const actual = PNG.sync.read(readFileSync(svgPng));
  if (reference.width !== actual.width || reference.height !== actual.height) {
    throw new Error(
      `crop size mismatch ${actual.width}x${actual.height} vs ${reference.width}x${reference.height}`
    );
  }
  const diff = new PNG({ width: reference.width, height: reference.height });
  const diffPixels = pixelmatch(
    reference.data,
    actual.data,
    diff.data,
    reference.width,
    reference.height,
    { threshold: 0.27 }
  );
  return diffPixels / (reference.width * reference.height);
}

function toolAvailable(tool) {
  const args = tool === "pdftoppm" ? ["-v"] : ["--version"];
  const result = spawnSync(tool, args, { stdio: "ignore" });
  return result.status === 0;
}

function shouldRerunWithWasmFlags() {
  if (process.env.PDF_WASM_TEST_FLAGS === "1") {
    return false;
  }
  return requiredWasmFlags.some((flag) => !process.execArgv.includes(flag));
}
