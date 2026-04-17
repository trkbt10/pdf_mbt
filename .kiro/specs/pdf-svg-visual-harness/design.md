# Design: Visual regression harness with locked pixelmatch parameters

## Overview

Implement a single ECMAScript module exposing `compare`,
`assertNoRegression`, and `assertImprovement` for visual
comparisons of SVG output against pdftoppm references. Pixelmatch
parameters are module-level constants; the function signatures do
not accept threshold overrides. Baseline diff numbers are stored
in a JSON file alongside the module.

Every SDD that claims a visual acceptance criterion routes through
this harness. The file `npm/test/visual_crop.mjs` is rewritten to
use it; `npm/test/visual_compare.mjs` (ImageMagick-based) is left
alone for its existing smoke-test role but SHALL NOT be used for
local-fixture baselines.

## Page 6 / Page 7 fixture with numbered baselines

Baselines for <local-fixture> page 6 and page 7 SHALL be
recorded in `visual_baselines.json` with their measured diff at
the locked pixelmatch parameters. `assertNoRegression` uses these
as the regression oracle: the current diff must stay within
`baseline + tolerance`. `assertImprovement` is used by SDDs
claiming improvement and MUST be paired with a subsequent baseline
update that narrows the band.

## No parameter drift in callers

No parameter drift in callers is enforced by a CI guard: only
`visual_harness.mjs` is allowed to import `pixelmatch`. The harness
function signatures do not accept per-call threshold, alpha, or
includeAA overrides — the locked constants in the module's top-
level are the only source of truth. Existing tests such as
`visual_crop.mjs` are migrated to call the harness; the
ImageMagick-based `visual_compare.mjs` keeps its smoke role for
small fixtures but is not used for local-fixture acceptance.

## Acceptance criteria

The acceptance criteria for this SDD are that the harness produces
stable diff numbers (same input → same number to 4 decimal places),
that the local-fixture baselines are committed in `visual_baselines.json`,
and that the CI guard fails when a file other than the harness
imports `pixelmatch`.

## Module layout

### `npm/test/visual_harness.mjs`

```js
import pixelmatch from "./visual/node_modules/pixelmatch/index.js";
import { PNG } from "./visual/node_modules/pngjs/lib/png.js";
import { execFileSync } from "node:child_process";
import { readFile, writeFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const HERE = dirname(fileURLToPath(import.meta.url));

// --- LOCKED PARAMETERS (change only via git commit) ---
const PIXELMATCH_THRESHOLD = 0.1;
const PIXELMATCH_INCLUDE_AA = true;
const PIXELMATCH_ALPHA = 0.1;
const PIXELMATCH_AA_COLOR = [255, 255, 0];
const PIXELMATCH_DIFF_COLOR = [255, 0, 0];
// -----------------------------------------------------

const BASELINES_PATH = join(HERE, "visual_baselines.json");

export async function compare({ pdfPath, pageIndex, workdir }) {
  // Shell to pdftoppm + rsvg-convert exactly as before
  // Run pixelmatch with the locked parameters
  // Return { diff, referencePng, svgPng, diffPng, width, height }
}

export async function assertNoRegression({ pdfPath, pageIndex, tolerance = 0.002 }) {
  const baselines = JSON.parse(await readFile(BASELINES_PATH, "utf8"));
  const key = baselineKey(pdfPath, pageIndex);
  const baseline = baselines[key];
  if (baseline === undefined) {
    throw new Error(`No baseline for ${key}; run updateBaseline first`);
  }
  const { diff } = await compare({ pdfPath, pageIndex });
  if (diff > baseline + tolerance) {
    throw new Error(
      `${key}: diff ${diff.toFixed(4)} exceeds baseline ${baseline.toFixed(4)} + ${tolerance.toFixed(4)}`
    );
  }
  return { diff, baseline };
}

export async function assertImprovement({ pdfPath, pageIndex, expectedMaximum }) {
  const { diff } = await compare({ pdfPath, pageIndex });
  if (diff > expectedMaximum) {
    throw new Error(
      `${baselineKey(pdfPath, pageIndex)}: diff ${diff.toFixed(4)} > expected max ${expectedMaximum.toFixed(4)}`
    );
  }
  return { diff };
}

export async function updateBaseline({ pdfPath, pageIndex }) {
  const { diff } = await compare({ pdfPath, pageIndex });
  const baselines = JSON.parse(await readFile(BASELINES_PATH, "utf8"));
  baselines[baselineKey(pdfPath, pageIndex)] = diff;
  await writeFile(BASELINES_PATH, JSON.stringify(baselines, null, 2) + "\n");
  return { diff };
}

function baselineKey(pdfPath, pageIndex) {
  return `${pdfPath}:${pageIndex}`;
}
```

No threshold parameter is exposed. Callers cannot override. The
only way to "relax" a threshold is to commit to `BASELINES_PATH`
with a new number, which shows up in git review as a visible
regression.

### `npm/test/visual_baselines.json`

Initial content after this SDD runs once on the current main:

```json
{
  "<local-fixture>:5": 0.1183,
  "<local-fixture>:6": 0.2580
}
```

The absolute path is fine for the local reference environment; for
CI this file extends to a portable form (e.g. relative to project
root or identified by SHA-256 hash of the PDF contents).

### `npm/test/visual_crop.mjs` rewrite

Replace the inline pixelmatch call + `threshold: 0.27` with an
`import { compare } from "./visual_harness.mjs"` and pass the
cropped PNG pair through the harness `compare` at the locked
threshold. Crop regions continue to be defined per call; threshold
is not a knob.

### `npm/test/visual_compare.mjs`

Leave as-is. ImageMagick `-fuzz 10%` is used for smoke tests on
small fixtures (simple / utf8 / calrgb) where byte-identical
expectation is impractical. This file SHALL NOT be used for local-fixture
acceptance and SHALL NOT be touched in this SDD.

### Guardrail test

Add `npm/test/harness_guard.mjs`:

```js
import { readdir, readFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const HERE = dirname(fileURLToPath(import.meta.url));

async function main() {
  const entries = await readdir(HERE);
  const violations = [];
  for (const entry of entries) {
    if (!entry.endsWith(".mjs")) continue;
    if (entry === "visual_harness.mjs") continue;
    if (entry === "harness_guard.mjs") continue;
    const source = await readFile(join(HERE, entry), "utf8");
    if (/\bpixelmatch\b/.test(source)) {
      violations.push(entry);
    }
  }
  if (violations.length > 0) {
    console.error("Files importing pixelmatch outside visual_harness.mjs:");
    violations.forEach(v => console.error(" - " + v));
    process.exit(1);
  }
  console.log("pixelmatch import guard passed");
}

await main();
```

Wire into `npm/package.json`'s `test` script so it runs as part of
`npm test`.

## Acceptance

1. `npm test` runs without regression
2. `visual_harness.mjs` exists with locked parameters
3. `visual_baselines.json` records local-fixture page 6, 7 at threshold 0.1
4. `visual_crop.mjs` no longer has an inline `threshold: 0.27`
5. Future SDDs cite `assertImprovement({ expectedMaximum: X })` with
   an `X` that SHALL be < current baseline if claiming improvement

## SDD retrofit

The prior `pdf-svg-glyph-correctness` SDD recorded an acceptance at
threshold 0.17; this was a parameter change that is no longer
allowed. Amend its verification record (in the SDD's
`verification.md` or equivalent) with:

- current baseline at threshold 0.1: page 6 = 0.1183, page 7 = 0.2580
- previous baseline at threshold 0.1: page 6 = 0.1250, page 7 = 0.1747
- **page 7 regressed** by ~0.083 absolute

This is where honesty about the current state starts.

## Files to modify

- `npm/test/visual_harness.mjs` — NEW
- `npm/test/visual_baselines.json` — NEW, with current-main values
- `npm/test/visual_crop.mjs` — rewrite to use harness
- `npm/test/harness_guard.mjs` — NEW
- `npm/package.json` — add `harness_guard.mjs` to test script
- `.kiro/specs/pdf-svg-glyph-correctness/verification.md` — amend
  to show real baseline numbers at the locked parameters

Do NOT change SDD requirements.md / design.md / tasks.md of prior
SDDs — those are the historical record. Only the verification
record is amended.
