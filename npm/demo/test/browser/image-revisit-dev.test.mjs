import assert from "node:assert/strict";
import { basename } from "node:path";
import { existsSync } from "node:fs";
import { test } from "node:test";
import { scrollToPage, uploadPdf, withDemoDevPage } from "./chrome-harness.mjs";

// Reproduces the user-reported revisit failure under dev-server +
// React StrictMode dev double-mount semantics. The prod-build harness
// (visual-sanity / scroll-stress) cannot expose this because vite build
// strips the second pass that StrictMode adds in dev.

const FIXTURES = [
  {
    label: "ISO-14289-2",
    path: "spec/pdf/<local-fixture>",
    visits: [3, 25, 3, 45, 3],
  },
];

for (const fixture of FIXTURES) {
  test(`${fixture.label}: revisit cycle survives dev StrictMode double-mount`, async (t) => {
    if (!existsSync(fixture.path)) {
      t.diagnostic(`fixture missing: ${fixture.path}`);
      return;
    }
    await withDemoDevPage(async (page) => {
      await uploadPdf(page, fixture.path, basename(fixture.path));
      for (const target of fixture.visits) {
        await scrollToPage(page, target);
        await page.waitForFunction(
          (n) => {
            const item = document.querySelector(
              `[data-pdf-page-item][data-page-number="${n}"]`
            );
            const surface = item?.querySelector("[data-pdf-page-svg] svg");
            return Boolean(surface);
          },
          target
        );
      }

      // Re-upload to verify Blob URL registry is cleaned up on document close.
      const initialBlobs = await page.evaluate(() =>
        window.__pdfDemoBlobUrls?.liveCountAll?.() ?? 0
      );
      await uploadPdf(page, fixture.path, basename(fixture.path));
      const finalBlobs = await page.evaluate(() =>
        window.__pdfDemoBlobUrls?.liveCountAll?.() ?? 0
      );
      // After re-open, only the new document's blobs should remain.
      assert.ok(
        finalBlobs <= initialBlobs + 4,
        `blob URL count grew unexpectedly across re-open: ${initialBlobs} -> ${finalBlobs}`
      );
    });
  });
}
