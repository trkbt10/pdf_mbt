import { execFileSync, spawnSync } from "node:child_process";
import { mkdtempSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { PNG } from "./visual/node_modules/pngjs/lib/png.js";

if (!toolAvailable("rsvg-convert")) {
  console.log("clip repro skipped: missing rsvg-convert");
  process.exit(0);
}

const workdir = mkdtempSync(join(tmpdir(), "pdf-clip-repro-"));
const directSvgPath = join(workdir, "clip-repro-direct.svg");
const directPngPath = join(workdir, "clip-repro-direct.png");
const wrappedSvgPath = join(workdir, "clip-repro-wrapped.svg");
const wrappedPngPath = join(workdir, "clip-repro-wrapped.png");

writeReproSvg(
  directSvgPath,
  `<text clip-path="url(#c2)" transform="matrix(1 0 0 1 278 54)" font-size="24" font-family="sans-serif" fill="black">
    <tspan>Test</tspan>
  </text>`
);
writeReproSvg(
  wrappedSvgPath,
  `<g clip-path="url(#c2)">
    <text transform="matrix(1 0 0 1 278 54)" font-size="24" font-family="sans-serif" fill="black">
      <tspan>Test</tspan>
    </text>
  </g>`
);

execFileSync("rsvg-convert", [directSvgPath, "-o", directPngPath]);
execFileSync("rsvg-convert", [wrappedSvgPath, "-o", wrappedPngPath]);

const directPng = PNG.sync.read(readFileSync(directPngPath));
const wrappedPng = PNG.sync.read(readFileSync(wrappedPngPath));
const crop = { x: 270, y: 40, width: 120, height: 60 };
const directDarkPixels = countDarkPixels(directPng, crop);
const wrappedDarkPixels = countDarkPixels(wrappedPng, crop);

if (wrappedDarkPixels === 0) {
  throw new Error(
    `clip repro failed: expected visible text pixels with page-space group clip; svg=${wrappedSvgPath} png=${wrappedPngPath}`
  );
}

console.log(
  `clip repro passed: direct=${directDarkPixels} wrapped=${wrappedDarkPixels} dark pixels`
);

function writeReproSvg(path, content) {
  writeFileSync(
    path,
    `<svg xmlns="http://www.w3.org/2000/svg" width="596" height="842" viewBox="0 0 596 842">
  <rect width="596" height="842" fill="white"/>
  <defs>
    <clipPath id="c2">
      <path d="M 271.05 832.8 L 581.01 832.8 L 581.01 43.71 L 271.05 43.71 Z" clip-rule="evenodd"/>
    </clipPath>
  </defs>
  ${content}
</svg>
`
  );
}

function countDarkPixels(png, crop) {
  let count = 0;
  const xMax = Math.min(png.width, crop.x + crop.width);
  const yMax = Math.min(png.height, crop.y + crop.height);
  for (let y = Math.max(0, crop.y); y < yMax; y += 1) {
    for (let x = Math.max(0, crop.x); x < xMax; x += 1) {
      const offset = (y * png.width + x) * 4;
      const alpha = png.data[offset + 3];
      const red = png.data[offset];
      const green = png.data[offset + 1];
      const blue = png.data[offset + 2];
      if (alpha > 0 && red < 128 && green < 128 && blue < 128) {
        count += 1;
      }
    }
  }
  return count;
}

function toolAvailable(tool) {
  const result = spawnSync(tool, ["--version"], { stdio: "ignore" });
  return result.status === 0;
}
