import assert from "node:assert/strict";
import { basename } from "node:path";
import { test } from "node:test";
import {
  pageImageDiagnostics,
  scrollToPage,
  uploadPdf,
  waitForVisiblePageImage,
  withDemoPage,
} from "./chrome-harness.mjs";

const SETTING_APP_MANUAL =
  process.env.PDF_SETTING_APP_FIXTURE ??
  "<local-fixture>";
const SETTING_APP_IMAGE_PAGE = 8;

test("local-fixture image page remains visible after scrolling away and back", async () => {
  await withDemoPage(async (page) => {
    await uploadPdf(page, SETTING_APP_MANUAL, basename(SETTING_APP_MANUAL));

    await scrollToPage(page, SETTING_APP_IMAGE_PAGE);
    const firstVisit = await waitForVisiblePageImage(page, SETTING_APP_IMAGE_PAGE);
    assert.equal(firstVisit.fetchOk, true);

    await scrollToPage(page, 30);
    await scrollToPage(page, SETTING_APP_IMAGE_PAGE);
    const revisit = await waitForVisiblePageImage(page, SETTING_APP_IMAGE_PAGE);

    assert.equal(revisit.fetchOk, true);
    assert.notEqual(revisit.href, "");
    assert.equal(revisit.hasVisibleImage, true);
  });
});

test("local-fixture page 7 image remains visible after scrolling away and back", async () => {
  const fixture =
    process.env.PDF_003Z_FIXTURE ??
    "<local-fixture>";

  await withDemoPage(async (page) => {
    await uploadPdf(page, fixture, basename(fixture));

    await scrollToPage(page, 7);
    const firstVisit = await waitForVisiblePageImage(page, 7);
    assert.equal(firstVisit.fetchOk, true);

    await scrollToPage(page, 20);
    await scrollToPage(page, 7);
    const revisit = await waitForVisiblePageImage(page, 7);

    assert.equal(revisit.fetchOk, true);
    assert.notEqual(revisit.href, "");
    assert.equal(revisit.hasVisibleImage, true);
  });
});

test("local-fixture image-page diagnostic state is available", async () => {
  await withDemoPage(async (page) => {
    await uploadPdf(page, SETTING_APP_MANUAL, basename(SETTING_APP_MANUAL));
    await scrollToPage(page, SETTING_APP_IMAGE_PAGE);
    await waitForVisiblePageImage(page, SETTING_APP_IMAGE_PAGE);
    const state = await pageImageDiagnostics(page, SETTING_APP_IMAGE_PAGE);

    assert.equal(state.pageNumber, SETTING_APP_IMAGE_PAGE);
    assert.equal(state.imageCount > 0, true);
  });
});
