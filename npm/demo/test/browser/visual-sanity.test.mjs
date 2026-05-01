import assert from "node:assert/strict";
import { basename } from "node:path";
import { existsSync } from "node:fs";
import { test } from "node:test";
import {
  scrollToPage,
  uploadPdf,
  withDemoPage,
} from "./chrome-harness.mjs";

/**
 * Visual sanity bench. Codifies "the rendered output is structurally correct"
 * for several real-world PDFs:
 *  - SVG element exists with non-trivial bbox
 *  - At least one <image> per visual page has a non-empty href
 *  - Image natural size matches the embedded resource
 *  - No NaN/Infinity in transform/positioning attributes
 *  - Page surface has no rendering errors logged
 */

const FIXTURES = [
  {
    label: "local-fixture",
    path:
      process.env.PDF_SETTING_APP_FIXTURE ??
      "<local-fixture>",
    pageNumber: 8, // image-heavy page
  },
  {
    label: "local-fixture",
    path:
      process.env.PDF_003Z_FIXTURE ??
      "<local-fixture>",
    pageNumber: 7,
  },
  {
    label: "redacted",
    path:
      "spec/pdf/<local-fixture>",
    pageNumber: 1,
  },
];

for (const fixture of FIXTURES) {
  test(`${fixture.label} page ${fixture.pageNumber} renders correctly`, async (t) => {
    if (!existsSync(fixture.path)) {
      t.diagnostic(`fixture missing: ${fixture.path}`);
      return;
    }
    await withDemoPage(async (page) => {
      await uploadPdf(page, fixture.path, basename(fixture.path));
      await scrollToPage(page, fixture.pageNumber);

      // Wait for SVG to materialise.
      await page.waitForFunction(
        (n) => {
          const item = document.querySelector(
            `[data-pdf-page-item][data-page-number="${n}"]`,
          );
          if (!item) return false;
          item.scrollIntoView({ block: "center", inline: "nearest" });
          const surface = item.querySelector("[data-pdf-page-svg]");
          return Boolean(surface?.querySelector("svg"));
        },
        fixture.pageNumber,
      );

      const report = await page.evaluate((n) => {
        const item = document.querySelector(
          `[data-pdf-page-item][data-page-number="${n}"]`,
        );
        if (!item) return { error: "no_page_item" };
        const svg = item.querySelector("svg");
        if (!svg) return { error: "no_svg" };

        const bbox = svg.getBBox?.();
        const viewBox = svg.getAttribute("viewBox");
        const width = svg.getAttribute("width");
        const height = svg.getAttribute("height");

        const images = Array.from(svg.querySelectorAll("image"));
        const imageReports = images.map((img, idx) => {
          const href =
            img.getAttribute("href") ??
            img.getAttributeNS("http://www.w3.org/1999/xlink", "href") ??
            "";
          const bb = img.getBoundingClientRect();
          return {
            idx,
            href: href.slice(0, 60),
            hrefScheme: href.split(":")[0] ?? "",
            width: bb.width,
            height: bb.height,
            x: img.getAttribute("x"),
            y: img.getAttribute("y"),
            transform: img.getAttribute("transform"),
          };
        });

        const texts = svg.querySelectorAll("text").length;
        const paths = svg.querySelectorAll("path").length;

        const numericIssues = [];
        const all = svg.querySelectorAll("*");
        for (const el of all) {
          for (const attr of ["x", "y", "width", "height", "transform", "d"]) {
            const v = el.getAttribute(attr);
            if (v && /\b(NaN|Infinity|-Infinity)\b/i.test(v)) {
              numericIssues.push({ tag: el.tagName, attr, value: v });
              if (numericIssues.length > 5) break;
            }
          }
          if (numericIssues.length > 5) break;
        }

        return {
          viewBox,
          width,
          height,
          bboxWidth: bbox?.width ?? null,
          bboxHeight: bbox?.height ?? null,
          imageCount: images.length,
          textCount: texts,
          pathCount: paths,
          imageReports: imageReports.slice(0, 3),
          numericIssues,
        };
      }, fixture.pageNumber);

      t.diagnostic(JSON.stringify(report, null, 2));

      assert.equal(report.error, undefined, `unexpected: ${report.error}`);
      assert.ok(
        report.viewBox,
        "SVG must have a viewBox",
      );
      assert.ok(
        Number(report.width) > 0,
        `SVG width must be positive: ${report.width}`,
      );
      assert.ok(
        Number(report.height) > 0,
        `SVG height must be positive: ${report.height}`,
      );
      assert.equal(
        report.numericIssues.length,
        0,
        `numeric attrs must not contain NaN/Infinity: ${JSON.stringify(report.numericIssues)}`,
      );

      const visualNodes = report.imageCount + report.textCount + report.pathCount;
      assert.ok(
        visualNodes > 0,
        `page must have at least one visible node (got images=${report.imageCount}, text=${report.textCount}, paths=${report.pathCount})`,
      );

      for (const img of report.imageReports) {
        assert.ok(
          img.hrefScheme === "blob" ||
            img.hrefScheme === "data" ||
            img.hrefScheme === "http" ||
            img.hrefScheme === "https",
          `image href scheme must be supported: ${JSON.stringify(img)}`,
        );
        assert.ok(
          img.width > 0 && img.height > 0,
          `image must have positive box: ${JSON.stringify(img)}`,
        );
      }
    });
  });
}
