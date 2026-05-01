import assert from "node:assert/strict";
import { basename } from "node:path";
import { test } from "node:test";
import { existsSync } from "node:fs";
import {
  scrollToPage,
  uploadPdf,
  waitForVisiblePageImage,
  withDemoPage,
} from "./chrome-harness.mjs";

/**
 * Performance bench covering the two user-reported hang scenarios:
 *  1. local-fixture has pages that used to block for 40s+ on text
 *     interpretation.
 *  2. local-fixture has image pages that used to block on image decode.
 *
 * Each assertion codifies an upper bound; regressions surface as test
 * failures rather than interactive browser freezes. Skipped gracefully when
 * the fixture PDFs aren't present on the current machine.
 */

const SETTING_APP_MANUAL =
  process.env.PDF_SETTING_APP_FIXTURE ??
  "<local-fixture>";
const PAGE_BUDGET_MS = 10_000; // generous: Chromium headless + wasm warm-up

test("local-fixture first text page renders below perf budget", async (t) => {
  if (!existsSync(SETTING_APP_MANUAL)) {
    t.diagnostic(`fixture missing: ${SETTING_APP_MANUAL}`);
    return;
  }
  await withDemoPage(async (page) => {
    const uploadStart = Date.now();
    await uploadPdf(page, SETTING_APP_MANUAL, basename(SETTING_APP_MANUAL));
    const uploadMs = Date.now() - uploadStart;
    t.diagnostic(`upload took ${uploadMs} ms`);
    assert.ok(
      uploadMs < PAGE_BUDGET_MS,
      `upload exceeded ${PAGE_BUDGET_MS}ms (actual ${uploadMs}ms)`
    );

    // Jump to a text-heavy page that previously triggered the 40s block.
    const scrollStart = Date.now();
    await scrollToPage(page, 6);
    const scrollMs = Date.now() - scrollStart;
    t.diagnostic(`scroll to page 6 took ${scrollMs} ms`);

    // Wait for the placeholder to become a rendered SVG. Re-scroll on each
    // poll because lazy loading of pages above pushes this target out of view.
    const waitStart = Date.now();
    await page.waitForFunction(
      () => {
        const item = document.querySelector(
          `[data-pdf-page-item][data-page-number="6"]`,
        );
        if (!item) return false;
        item.scrollIntoView({ block: "center", inline: "nearest" });
        const surface = item.querySelector("[data-pdf-page-svg]");
        return Boolean(surface && surface.querySelector("svg"));
      },
      30_000
    );
    const waitMs = Date.now() - waitStart;
    t.diagnostic(`page 6 SVG ready in ${waitMs} ms`);
    assert.ok(
      waitMs < PAGE_BUDGET_MS,
      `page 6 SVG took ${waitMs}ms (>${PAGE_BUDGET_MS}ms budget)`
    );
  });
});

test("local-fixture image page visible under 15s budget", async (t) => {
  if (!existsSync(SETTING_APP_MANUAL)) {
    t.diagnostic(`fixture missing: ${SETTING_APP_MANUAL}`);
    return;
  }
  await withDemoPage(async (page) => {
    await uploadPdf(page, SETTING_APP_MANUAL, basename(SETTING_APP_MANUAL));

    const start = Date.now();
    await scrollToPage(page, 8);
    const visited = await waitForVisiblePageImage(page, 8);
    const totalMs = Date.now() - start;
    t.diagnostic(
      `page 8 image visible in ${totalMs} ms, fetchOk=${visited.fetchOk}`
    );
    assert.equal(visited.fetchOk, true);
    assert.ok(totalMs < 15_000, `page 8 took ${totalMs}ms`);
  });
});
