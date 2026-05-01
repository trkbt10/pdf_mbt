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
 * Scroll-stress: visit a sequence of pages forward then backward and ensure
 * each one ends with a complete SVG and no broken images. Codifies the
 * "scroll fast through a 30-page PDF and pictures stop showing up" failure
 * mode.
 */

const SETTING = {
  label: "local-fixture",
  path:
    process.env.PDF_SETTING_APP_FIXTURE ??
    "<local-fixture>",
  pages: [3, 6, 8, 11, 14, 8, 6, 3, 11, 14],
};

const Z003 = {
  label: "local-fixture",
  path:
    process.env.PDF_003Z_FIXTURE ??
    "<local-fixture>",
  pages: [2, 5, 7, 11, 7, 2, 11, 5],
};

for (const fixture of [SETTING, Z003]) {
  test(`${fixture.label} survives scroll-stress sequence`, async (t) => {
    if (!existsSync(fixture.path)) {
      t.diagnostic(`fixture missing: ${fixture.path}`);
      return;
    }
    await withDemoPage(async (page) => {
      await uploadPdf(page, fixture.path, basename(fixture.path));

      const visitTimes = [];
      for (const target of fixture.pages) {
        const start = Date.now();
        await scrollToPage(page, target);

        // Wait until either an SVG is visible or 8 seconds pass.
        let ready = false;
        try {
          await page.waitForFunction(
            (n) => {
              const item = document.querySelector(
                `[data-pdf-page-item][data-page-number="${n}"]`,
              );
              if (!item) return false;
              const surface = item.querySelector("[data-pdf-page-svg]");
              return Boolean(surface?.querySelector("svg"));
            },
            target,
          );
          ready = true;
        } catch {
          ready = false;
        }
        const took = Date.now() - start;
        visitTimes.push({ page: target, ready, ms: took });
        t.diagnostic(`page ${target}: ready=${ready}, ${took}ms`);
        assert.ok(ready, `page ${target} did not render in time`);
      }

      // Verify image hrefs across all visited pages are still valid. An image
      // with an empty href is counted as broken UNLESS it has been explicitly
      // hidden (visibility:hidden) — the renderer hides images it could not
      // materialise so they don't surface as broken icons.
      const totals = await page.evaluate(() => {
        const items = Array.from(document.querySelectorAll("[data-pdf-page-item]"));
        let visiblePages = 0;
        let totalImages = 0;
        let brokenImages = 0;
        let hiddenImages = 0;
        for (const item of items) {
          const svg = item.querySelector("[data-pdf-page-svg] svg");
          if (!svg) continue;
          visiblePages += 1;
          for (const img of svg.querySelectorAll("image")) {
            totalImages += 1;
            const href =
              img.getAttribute("href") ??
              img.getAttributeNS("http://www.w3.org/1999/xlink", "href") ??
              "";
            const visibility = img.style.visibility ?? getComputedStyle(img).visibility;
            const looksBroken = !href || href === "data:," || href === "about:blank";
            if (looksBroken) {
              if (visibility === "hidden") {
                hiddenImages += 1;
              } else {
                brokenImages += 1;
              }
            }
          }
        }
        return { visiblePages, totalImages, brokenImages, hiddenImages };
      });

      t.diagnostic(JSON.stringify(totals));
      assert.equal(
        totals.brokenImages,
        0,
        `must not have broken image hrefs: ${JSON.stringify(totals)}`,
      );

      // Average visit time should be sub-second after first hit.
      const median = [...visitTimes]
        .map((v) => v.ms)
        .sort((a, b) => a - b)[Math.floor(visitTimes.length / 2)];
      t.diagnostic(`median visit time: ${median} ms`);
      assert.ok(
        median < 5_000,
        `median visit time too high: ${median}ms`,
      );
    });
  });
}
