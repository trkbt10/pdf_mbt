import { execFileSync } from "node:child_process";
import { readFile, writeFile } from "node:fs/promises";
import { mkdtempSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { basename, dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import pixelmatch from "./visual/node_modules/pixelmatch/index.js";
import { PNG } from "./visual/node_modules/pngjs/lib/png.js";
import { PdfDocument } from "../index.mjs";

const HERE = dirname(fileURLToPath(import.meta.url));

// --- LOCKED PARAMETERS (change only via git commit) ---
export const PIXELMATCH_THRESHOLD = 0.1;
export const PIXELMATCH_INCLUDE_AA = true;
export const PIXELMATCH_ALPHA = 0.1;
export const PIXELMATCH_AA_COLOR = [255, 255, 0];
export const PIXELMATCH_DIFF_COLOR = [255, 0, 0];
// -----------------------------------------------------

const BASELINES_PATH = join(HERE, "visual_baselines.json");
const FORBIDDEN_OVERRIDE_KEYS = [
  "threshold",
  "includeAA",
  "alpha",
  "aaColor",
  "diffColor",
];

export async function compare(options) {
  rejectPixelmatchOverrides("compare", options);

  const { pdfPath, pageIndex, workdir = defaultWorkdir(), crop } = options;
  assertRequired("pdfPath", pdfPath);
  assertPageIndex(pageIndex);
  if (crop !== undefined) {
    assertCrop(crop);
  }

  const document = await PdfDocument.open(readFileSync(pdfPath));
  try {
    const pageLabel = `page-${pageIndex + 1}`;
    const svg = document.pageToSvg(pageIndex);
    const svgPath = join(workdir, `${pageLabel}.svg`);
    const rawSvgPng = join(workdir, `${pageLabel}-svg.png`);
    const rawReferencePrefix = join(workdir, `${pageLabel}-ref`);
    const rawReferencePng = `${rawReferencePrefix}.png`;
    const referencePng = crop
      ? join(workdir, `${pageLabel}-ref-crop.png`)
      : rawReferencePng;
    const svgPng = crop ? join(workdir, `${pageLabel}-svg-crop.png`) : rawSvgPng;
    const diffPng = crop
      ? join(workdir, `${pageLabel}-diff-crop.png`)
      : join(workdir, `${pageLabel}-diff.png`);

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
      pdfPath,
      rawReferencePrefix,
    ]);
    execFileSync("rsvg-convert", [svgPath, "-o", rawSvgPng]);

    if (crop) {
      cropPng(rawReferencePng, referencePng, crop);
      cropPng(rawSvgPng, svgPng, crop);
    }

    const result = pixelmatchDiff(referencePng, svgPng, diffPng);
    return {
      diff: result.diff,
      referencePng,
      svgPng,
      diffPng,
      width: result.width,
      height: result.height,
      workdir,
    };
  } finally {
    document.close();
  }
}

export async function assertNoRegression(options) {
  rejectPixelmatchOverrides("assertNoRegression", options);

  const { pdfPath, pageIndex, tolerance = 0.002 } = options;
  const baseline = await readBaseline(pdfPath, pageIndex);
  const current = await compare({ pdfPath, pageIndex });
  if (current.diff > baseline + tolerance) {
    throw new Error(
      `${baselineKey(pdfPath, pageIndex)}: diff ${current.diff.toFixed(
        4
      )} exceeds baseline ${baseline.toFixed(4)} + ${tolerance.toFixed(
        4
      )}; diff image: ${current.diffPng}`
    );
  }
  console.log(
    `no regression: ${baselineKey(pdfPath, pageIndex)} diff ${current.diff.toFixed(
      4
    )} <= ${baseline.toFixed(4)} + ${tolerance.toFixed(4)}`
  );
  return { ...current, baseline, tolerance };
}

export async function assertImprovement(options) {
  rejectPixelmatchOverrides("assertImprovement", options);

  const { pdfPath, pageIndex, expectedMaximum } = options;
  assertRequired("expectedMaximum", expectedMaximum);

  const current = await compare({ pdfPath, pageIndex });
  if (current.diff > expectedMaximum) {
    throw new Error(
      `${baselineKey(pdfPath, pageIndex)}: diff ${current.diff.toFixed(
        4
      )} > expected max ${expectedMaximum.toFixed(4)}; diff image: ${
        current.diffPng
      }`
    );
  }
  console.log(
    `acceptance met: ${baselineKey(pdfPath, pageIndex)} diff ${current.diff.toFixed(
      4
    )} <= ${expectedMaximum.toFixed(4)}`
  );
  return { ...current, expectedMaximum };
}

export async function updateBaseline(options) {
  rejectPixelmatchOverrides("updateBaseline", options);

  const { pdfPath, pageIndex } = options;
  const current = await compare({ pdfPath, pageIndex });
  const baselines = await readBaselines();
  const documentKey = basename(pdfPath);
  const pageKey = pageBaselineKey(pageIndex);
  const next = {
    ...baselines,
    _meta: baselineMetadata(),
  };

  next[documentKey] = {
    ...(isObject(next[documentKey]) ? next[documentKey] : {}),
    [pageKey]: roundDiff(current.diff),
  };
  await writeFile(BASELINES_PATH, JSON.stringify(next, null, 2) + "\n");
  return current;
}

function baselineMetadata() {
  return {
    measured_on: "2026-04-17",
    pixelmatch: {
      threshold: PIXELMATCH_THRESHOLD,
      includeAA: PIXELMATCH_INCLUDE_AA,
      alpha: PIXELMATCH_ALPHA,
      aaColor: PIXELMATCH_AA_COLOR,
      diffColor: PIXELMATCH_DIFF_COLOR,
    },
  };
}

export function baselineKey(pdfPath, pageIndex) {
  assertRequired("pdfPath", pdfPath);
  assertPageIndex(pageIndex);
  return `${basename(pdfPath)}:${pageBaselineKey(pageIndex)}`;
}

async function readBaseline(pdfPath, pageIndex) {
  const baselines = await readBaselines();
  const documentKey = basename(pdfPath);
  const pageKey = pageBaselineKey(pageIndex);
  const nested = baselines[documentKey]?.[pageKey];
  if (typeof nested === "number") {
    return nested;
  }

  const legacyKey = `${pdfPath}:${pageIndex}`;
  const legacy = baselines[legacyKey];
  if (typeof legacy === "number") {
    return legacy;
  }

  throw new Error(
    `No baseline for ${baselineKey(pdfPath, pageIndex)} in ${BASELINES_PATH}; run updateBaseline first`
  );
}

async function readBaselines() {
  try {
    return JSON.parse(await readFile(BASELINES_PATH, "utf8"));
  } catch (error) {
    if (error.code === "ENOENT") {
      return {};
    }
    throw error;
  }
}

function pixelmatchDiff(referencePng, svgPng, diffPng) {
  const reference = PNG.sync.read(readFileSync(referencePng));
  const actual = PNG.sync.read(readFileSync(svgPng));
  if (reference.width !== actual.width || reference.height !== actual.height) {
    throw new Error(
      `image size mismatch ${actual.width}x${actual.height} vs ${reference.width}x${reference.height}`
    );
  }

  const diff = new PNG({ width: reference.width, height: reference.height });
  const diffPixels = pixelmatch(
    reference.data,
    actual.data,
    diff.data,
    reference.width,
    reference.height,
    {
      threshold: PIXELMATCH_THRESHOLD,
      includeAA: PIXELMATCH_INCLUDE_AA,
      alpha: PIXELMATCH_ALPHA,
      aaColor: PIXELMATCH_AA_COLOR,
      diffColor: PIXELMATCH_DIFF_COLOR,
    }
  );
  writeFileSync(diffPng, PNG.sync.write(diff));
  return {
    diff: diffPixels / (reference.width * reference.height),
    width: reference.width,
    height: reference.height,
  };
}

function cropPng(input, output, crop) {
  execFileSync("magick", [
    input,
    "-crop",
    `${crop.width}x${crop.height}+${crop.x}+${crop.y}`,
    "+repage",
    output,
  ]);
}

function rejectPixelmatchOverrides(functionName, options) {
  if (!isObject(options)) {
    throw new TypeError(`${functionName} expects a single options object`);
  }

  const override = FORBIDDEN_OVERRIDE_KEYS.find((key) =>
    Object.prototype.hasOwnProperty.call(options, key)
  );
  if (override) {
    throw new TypeError(
      `${functionName} does not accept pixelmatch override '${override}'; edit visual_harness.mjs constants instead`
    );
  }
}

function assertRequired(name, value) {
  if (value === undefined || value === null || value === "") {
    throw new TypeError(`${name} is required`);
  }
}

function assertPageIndex(pageIndex) {
  if (!Number.isInteger(pageIndex) || pageIndex < 0) {
    throw new TypeError(`pageIndex must be a non-negative integer, got ${pageIndex}`);
  }
}

function assertCrop(crop) {
  if (!isObject(crop)) {
    throw new TypeError("crop must be an object");
  }
  for (const key of ["x", "y", "width", "height"]) {
    if (!Number.isInteger(crop[key]) || crop[key] < 0) {
      throw new TypeError(`crop.${key} must be a non-negative integer`);
    }
  }
  if (crop.width === 0 || crop.height === 0) {
    throw new TypeError("crop.width and crop.height must be greater than zero");
  }
}

function defaultWorkdir() {
  return mkdtempSync(join(tmpdir(), "pdf-visual-harness-"));
}

function pageBaselineKey(pageIndex) {
  return `page_${pageIndex + 1}`;
}

function roundDiff(diff) {
  return Number(diff.toFixed(4));
}

function isObject(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}
