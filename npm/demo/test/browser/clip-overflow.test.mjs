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
 * Verify each rendered SVG either clips overflow at the page bounds, or has
 * `overflow=hidden` set so the visible region matches the PDF page box.
 * The local-fixture user guide previously rendered with content drawn outside the
 * MediaBox; this test guards against regressions.
 */

const FIXTURES = [
  {
    label: "local_fixture_p7",
    path:
      process.env.PDF_003Z_FIXTURE ??
      "<local-fixture>",
    pageNumber: 7,
  },
  {
    label: "local_fixture_p8",
    path:
      process.env.PDF_SETTING_APP_FIXTURE ??
      "<local-fixture>",
    pageNumber: 8,
  },
];

for (const fixture of FIXTURES) {
  test(`${fixture.label} clips overflow at page bounds`, async (t) => {
    if (!existsSync(fixture.path)) {
      t.diagnostic(`fixture missing: ${fixture.path}`);
      return;
    }
    await withDemoPage(async (page) => {
      await uploadPdf(page, fixture.path, basename(fixture.path));
      await scrollToPage(page, fixture.pageNumber);
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
        const svg = item?.querySelector("svg");
        if (!svg) return { error: "no_svg" };

        const viewBox = svg
          .getAttribute("viewBox")
          ?.split(/\s+/)
          .map(Number) ?? [0, 0, 0, 0];
        const [vx, vy, vw, vh] = viewBox;

        const bbox = svg.getBBox?.();

        const overflow =
          svg.getAttribute("overflow") ??
          getComputedStyle(svg).overflow ??
          "visible";

        // The visible (clipped) region of the SVG. With `overflow:hidden`
        // (or `overflow=hidden` attribute), the rendered region is the
        // viewBox; otherwise it is the SVG content bbox.
        const isClipped = overflow === "hidden";

        return {
          viewBox: { x: vx, y: vy, w: vw, h: vh },
          bbox: bbox
            ? { x: bbox.x, y: bbox.y, w: bbox.width, h: bbox.height }
            : null,
          overflow,
          isClipped,
        };
      }, fixture.pageNumber);

      t.diagnostic(JSON.stringify(report, null, 2));
      assert.equal(report.error, undefined, `unexpected: ${report.error}`);

      // For visual correctness we need either:
      //   (a) overflow is hidden, in which case bbox can exceed viewBox
      //       safely (clipping happens at render),
      //   (b) bbox is fully contained within viewBox.
      const fitsInViewBox =
        report.bbox &&
        report.bbox.x >= report.viewBox.x - 1 &&
        report.bbox.y >= report.viewBox.y - 1 &&
        report.bbox.x + report.bbox.w <=
          report.viewBox.x + report.viewBox.w + 1 &&
        report.bbox.y + report.bbox.h <=
          report.viewBox.y + report.viewBox.h + 1;

      assert.ok(
        report.isClipped || fitsInViewBox,
        `SVG must clip overflow or fit within viewBox; overflow=${report.overflow}, viewBox=${JSON.stringify(report.viewBox)}, bbox=${JSON.stringify(report.bbox)}`,
      );
    });
  });
}
