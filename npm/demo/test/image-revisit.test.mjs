import assert from "node:assert/strict";
import { test } from "node:test";
import {
  FakeSurface,
  FakeSvgImage,
  assertBlobUrlFetchable,
  createBlobUrl,
  fakePdfSource,
  installAnimationFrameQueue,
  loadImagePatchHooks,
} from "./image-revisit-harness.mjs";

test("revisit restores the cached image href on the freshly mounted SVG image", async () => {
  const {
    patchDeferredSvgImagesForTest,
    resetPdfViewerPatchStats,
    waitForPendingDeferredImageUrlChecks,
  } = await loadImagePatchHooks();
  const frames = installAnimationFrameQueue();
  resetPdfViewerPatchStats();
  const imageUrls = new Map([[0, createBlobUrl("image-0")]]);

  const firstImage = new FakeSvgImage(0);
  const firstCleanup = patchDeferredSvgImagesForTest(
    new FakeSurface([firstImage]),
    fakePdfSource(),
    0,
    imageUrls
  );
  frames.flushAll();

  const firstHref = firstImage.getAttribute("href");
  assert.notEqual(firstHref, "");

  firstCleanup();
  const revisitImage = new FakeSvgImage(0);
  const revisitCleanup = patchDeferredSvgImagesForTest(
    new FakeSurface([revisitImage]),
    fakePdfSource(),
    0,
    imageUrls
  );

  const revisitHref = revisitImage.getAttribute("href");
  const stats = globalThis.window.__pdfViewerPatchStats;
  assert.equal(stats.invocations[0], 2);
  assert.equal(stats.querySelectorHits[0], 2);
  assert.equal(stats.successes[0], 2);
  assert.equal(revisitHref, firstHref);
  await waitForPendingDeferredImageUrlChecks();
  assert.equal(stats.fetchOkBlobUrls[0], 2);
  await assertBlobUrlFetchable(revisitHref, "image-0");
  revisitCleanup();
  URL.revokeObjectURL(firstHref);
});
