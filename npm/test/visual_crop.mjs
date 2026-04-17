import { execFileSync, spawnSync } from "node:child_process";
import { existsSync } from "node:fs";
import { mkdtempSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { compare } from "./visual_harness.mjs";

const requiredWasmFlags = [
  "--experimental-wasm-stringref",
  "--experimental-wasm-imported-strings",
];
const MAX_HANDSET_CROP_DIFF = 0.28;

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
const result = await compare({
  pdfPath: pdf,
  pageIndex: 5,
  crop: { x: 185, y: 20, width: 130, height: 20 },
  workdir,
});

if (result.diff > MAX_HANDSET_CROP_DIFF) {
  throw new Error(
    `local-fixture page 6 Handset crop diff ${formatPercent(
      result.diff
    )} exceeds ${formatPercent(MAX_HANDSET_CROP_DIFF)}; diff image: ${
      result.diffPng
    }`
  );
}

console.log(`✓ local-fixture page 6 Handset crop diff ${formatPercent(result.diff)}`);

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
