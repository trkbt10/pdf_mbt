import { execFileSync, spawnSync } from "node:child_process";
import { mkdtemp, readFile, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
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

const tools = ["pdftoppm", "rsvg-convert", "magick"];
const missing = tools.filter((tool) => !toolAvailable(tool));
if (missing.length > 0) {
  console.log(`visual compare skipped: missing ${missing.join(", ")}`);
  process.exit(0);
}

const threshold = Number.parseFloat(process.env.PDF_VISUAL_THRESHOLD ?? "0.05");
const workdir = await mkdtemp(join(tmpdir(), "pdf-visual-"));

await comparePage({
  name: "simple",
  pdf: "../spec/pdf20examples/Simple PDF 2.0 file.pdf",
  pageIndex: 0,
  threshold,
  workdir,
});

console.log("✓ SVG visual comparison");

async function comparePage({ name, pdf, pageIndex, threshold, workdir }) {
  const pdfBytes = await readFile(pdf);
  const document = await PdfDocument.open(pdfBytes);
  try {
    const svg = document.pageToSvg(pageIndex);
    const svgPath = join(workdir, `${name}.svg`);
    const svgPng = join(workdir, `${name}-svg.png`);
    const referencePrefix = join(workdir, `${name}-ref`);
    const referencePng = `${referencePrefix}.png`;
    const diffPng = join(workdir, `${name}-diff.png`);
    await writeFile(svgPath, svg);

    execFileSync("pdftoppm", [
      "-png",
      "-singlefile",
      "-r",
      "72",
      pdf,
      referencePrefix,
    ]);
    execFileSync("rsvg-convert", [svgPath, "-o", svgPng]);
    const diff = comparePng(referencePng, svgPng, diffPng);
    if (diff > threshold) {
      throw new Error(
        `${name} visual diff ${formatPercent(diff)} exceeds ${formatPercent(
          threshold
        )}; diff image: ${diffPng}`
      );
    }
  } finally {
    document.close();
  }
}

function comparePng(referencePng, svgPng, diffPng) {
  const result = spawnSync(
    "magick",
    [
      "compare",
      "-metric",
      "AE",
      "-fuzz",
      "10%",
      referencePng,
      svgPng,
      diffPng,
    ],
    { encoding: "utf8" }
  );
  if (result.status !== 0 && result.status !== 1) {
    throw new Error(result.stderr || result.stdout || "ImageMagick compare failed");
  }
  const output = `${result.stderr}${result.stdout}`;
  const match = output.match(/\((0(?:\.\d+)?|1(?:\.0+)?)\)/);
  if (!match) {
    throw new Error(`failed to parse visual diff metric: ${output}`);
  }
  return Number.parseFloat(match[1]);
}

function toolAvailable(tool) {
  const args = tool === "pdftoppm" ? ["-v"] : ["--version"];
  const result = spawnSync(tool, args, { stdio: "ignore" });
  return result.status === 0;
}

function formatPercent(value) {
  return `${(value * 100).toFixed(2)}%`;
}

function shouldRerunWithWasmFlags() {
  if (process.env.PDF_WASM_TEST_FLAGS === "1") {
    return false;
  }
  return requiredWasmFlags.some((flag) => !process.execArgv.includes(flag));
}
