import { readdir, readFile } from "node:fs/promises";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const HERE = dirname(fileURLToPath(import.meta.url));
const ALLOWED_PIXELMATCH_IMPORTER = "visual_harness.mjs";

const PIXELMATCH_IMPORT_RE =
  /^\s*import(?:\s+[\s\S]*?\s+from\s+|\s*)["'][^"']*pixelmatch[^"']*["'];?/m;

const entries = await readdir(HERE, { withFileTypes: true });
const violations = [];

for (const entry of entries) {
  if (!entry.isFile() || !entry.name.endsWith(".mjs")) {
    continue;
  }
  if (entry.name === ALLOWED_PIXELMATCH_IMPORTER || entry.name === "harness_guard.mjs") {
    continue;
  }

  const source = await readFile(join(HERE, entry.name), "utf8");
  if (PIXELMATCH_IMPORT_RE.test(source)) {
    violations.push(entry.name);
  }
}

if (violations.length > 0) {
  console.error("pixelmatch must only be imported by visual_harness.mjs:");
  for (const violation of violations) {
    console.error(` - ${violation}`);
  }
  process.exit(1);
}

console.log("✓ pixelmatch import guard");
