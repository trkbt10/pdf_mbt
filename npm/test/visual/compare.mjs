import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
import { PNG } from "pngjs";
import pixelmatch from "pixelmatch";

const THRESHOLD = 0.01; // 0.01% target
const names = ["simple", "utf8", "calrgb"];
let allPass = true;

mkdirSync("npm/test/visual/diff", { recursive: true });

for (const name of names) {
  try {
    const actual = PNG.sync.read(readFileSync(`npm/test/visual/actual/${name}-1.png`));
    const reference = PNG.sync.read(readFileSync(`npm/test/visual/reference/${name}-1.png`));

    if (actual.width !== reference.width || actual.height !== reference.height) {
      console.log(`❌ ${name}: size mismatch ${actual.width}x${actual.height} vs ${reference.width}x${reference.height}`);
      allPass = false;
      continue;
    }

    const diff = new PNG({ width: actual.width, height: actual.height });
    const numDiff = pixelmatch(actual.data, reference.data, diff.data, actual.width, actual.height, { threshold: 0.1 });
    const total = actual.width * actual.height;
    const pct = numDiff / total * 100;

    writeFileSync(`npm/test/visual/diff/${name}-1.png`, PNG.sync.write(diff));

    const status = pct <= THRESHOLD ? "✅" : pct <= 0.1 ? "⚠️" : "❌";
    console.log(`${status} ${name}: ${numDiff}/${total} (${pct.toFixed(4)}%) ${pct <= THRESHOLD ? "PASS" : "FAIL"}`);

    if (pct > THRESHOLD) allPass = false;
  } catch (e) {
    console.log(`❌ ${name}: ${e.message}`);
    allPass = false;
  }
}

process.exit(allPass ? 0 : 1);
