import { execFileSync, spawnSync } from "node:child_process";
import { existsSync } from "node:fs";
import { readFile } from "node:fs/promises";
import { basename, dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { assertNoRegression } from "./visual_harness.mjs";

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
const missingTools = tools.filter((tool) => !toolAvailable(tool));
if (missingTools.length > 0) {
  console.log(`harness regression skipped: missing ${missingTools.join(", ")}`);
  process.exit(0);
}

const HERE = dirname(fileURLToPath(import.meta.url));
const baselinesPath = join(HERE, "visual_baselines.json");
const baselines = JSON.parse(await readFile(baselinesPath, "utf8"));
let checked = 0;
let skipped = 0;

for (const [documentKey, pages] of Object.entries(baselines)) {
  if (documentKey === "_meta") {
    continue;
  }
  if (!isObject(pages)) {
    throw new Error(`Baseline entry ${documentKey} must be an object`);
  }

  const pdfPath = resolveFixturePath(documentKey);
  if (!existsSync(pdfPath)) {
    console.log(`harness regression skipped: missing ${pdfPath}`);
    skipped += countBaselinePages(pages);
    continue;
  }

  for (const [pageKey, baseline] of Object.entries(pages)) {
    if (typeof baseline !== "number") {
      throw new Error(`${documentKey}:${pageKey} baseline must be a number`);
    }
    await assertNoRegression({
      pdfPath,
      pageIndex: pageIndexFromBaselineKey(pageKey),
    });
    checked += 1;
  }
}

if (checked === 0) {
  console.log(`harness regression skipped: no available fixtures (${skipped} baselines)`);
} else {
  console.log(`✓ harness regression checked ${checked} baselines`);
}

function resolveFixturePath(documentKey) {
  const override = fixtureOverride(documentKey);
  if (override) {
    return override;
  }
  return join(process.env.PDF_VISUAL_FIXTURE_DIR ?? "<local>", basename(documentKey));
}

function fixtureOverride(documentKey) {
  switch (documentKey) {
    case "<local-fixture>":
      return process.env.PDF_003Z_FIXTURE;
    case "<local-fixture>":
      return process.env.PDF_SETTING_APP_MANUAL_FIXTURE;
    default:
      return undefined;
  }
}

function pageIndexFromBaselineKey(pageKey) {
  const match = /^page_(\d+)$/.exec(pageKey);
  if (!match) {
    throw new Error(`Invalid baseline page key: ${pageKey}`);
  }
  return Number.parseInt(match[1], 10) - 1;
}

function countBaselinePages(pages) {
  return Object.values(pages).filter((value) => typeof value === "number").length;
}

function isObject(value) {
  return typeof value === "object" && value !== null && !Array.isArray(value);
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
