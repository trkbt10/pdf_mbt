import assert from "node:assert/strict";
import { test } from "node:test";
import {
  FakeSurface,
  FakeSvgImage,
  createBlobUrl,
  fakePdfSource,
  installAnimationFrameQueue,
  loadImagePatchHooks,
} from "./image-revisit-harness.mjs";

test("10 revisit cycles restore every image without multiplying Blob URLs", async () => {
  const {
    patchDeferredSvgImagesForTest,
    resetPdfViewerPatchStats,
    waitForPendingDeferredImageUrlChecks,
  } = await loadImagePatchHooks();
  installAnimationFrameQueue();
  resetPdfViewerPatchStats();

  const originalCreateObjectURL = URL.createObjectURL;
  const createdUrls = [];
  URL.createObjectURL = function createObjectURLSpy(blob) {
    const url = originalCreateObjectURL.call(URL, blob);
    createdUrls.push(url);
    return url;
  };

  try {
    const imageCount = 3;
    const imageUrls = new Map(
      Array.from({ length: imageCount }, (_, imageIndex) => [
        imageIndex,
        createBlobUrl(`image-${imageIndex}`),
      ])
    );

    for (let cycle = 0; cycle < 10; cycle += 1) {
      const images = Array.from(
        { length: imageCount },
        (_, imageIndex) => new FakeSvgImage(imageIndex)
      );
      const cleanup = patchDeferredSvgImagesForTest(
        new FakeSurface(images),
        fakePdfSource(),
        0,
        imageUrls
      );

      for (let imageIndex = 0; imageIndex < imageCount; imageIndex += 1) {
        assert.equal(images[imageIndex].getAttribute("href"), imageUrls.get(imageIndex));
      }
      cleanup();
    }

    await waitForPendingDeferredImageUrlChecks();
    const stats = globalThis.window.__pdfViewerPatchStats;
    assert.equal(stats.successes[0], 30);
    assert.equal(stats.fetchOkBlobUrls[0], 30);
    assert.equal(createdUrls.length, imageCount);

    for (const url of imageUrls.values()) {
      URL.revokeObjectURL(url);
    }
  } finally {
    for (const url of createdUrls) {
      URL.revokeObjectURL(url);
    }
    URL.createObjectURL = originalCreateObjectURL;
  }
});
