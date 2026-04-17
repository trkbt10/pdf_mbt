import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { createRequire } from "node:module";
import { test } from "node:test";
import { pathToFileURL } from "node:url";
import ts from "typescript";

const require = createRequire(import.meta.url);

test("revisit restores the cached image href on the freshly mounted SVG image", async () => {
  const { patchDeferredSvgImagesForTest } = await loadImagePatchHooks();
  const frames = installAnimationFrameQueue();
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
  assert.equal(revisitHref, firstHref);
  await assertBlobUrlFetchable(revisitHref);
  revisitCleanup();
  URL.revokeObjectURL(firstHref);
});

async function loadImagePatchHooks() {
  const sourceUrl = new URL("../src/PdfViewer.tsx", import.meta.url);
  const source = await readFile(sourceUrl, "utf8");
  const transpiled = ts.transpileModule(source, {
    compilerOptions: {
      jsx: ts.JsxEmit.ReactJSX,
      module: ts.ModuleKind.ES2022,
      moduleResolution: ts.ModuleResolutionKind.Bundler,
      target: ts.ScriptTarget.ES2022,
      verbatimModuleSyntax: false,
    },
  });
  const moduleUrl = `data:text/javascript;base64,${Buffer.from(
    rewriteReactImports(transpiled.outputText)
  ).toString("base64")}`;
  const module = await import(moduleUrl);
  return module.__pdfViewerImagePatchTestHooks;
}

function rewriteReactImports(source) {
  const reactUrl = pathToFileURL(require.resolve("react")).href;
  const jsxRuntimeUrl = pathToFileURL(require.resolve("react/jsx-runtime")).href;
  return source
    .replaceAll('from "react";', `from "${reactUrl}";`)
    .replaceAll('from "react/jsx-runtime";', `from "${jsxRuntimeUrl}";`);
}

function installAnimationFrameQueue() {
  const frames = [];
  globalThis.window = {
    cancelAnimationFrame(frameId) {
      const index = frames.findIndex((frame) => frame.id === frameId);
      if (index >= 0) {
        frames.splice(index, 1);
      }
    },
    requestAnimationFrame(callback) {
      const id = frames.length + 1;
      frames.push({ callback, id });
      return id;
    },
  };

  return {
    flushAll() {
      while (frames.length > 0) {
        const frame = frames.shift();
        frame.callback(0);
      }
    },
  };
}

class FakeSurface {
  constructor(images) {
    this.images = images;
  }

  querySelectorAll(selector) {
    assert.equal(selector, "image[data-image-index]");
    return this.images;
  }
}

class FakeSvgImage {
  constructor(imageIndex) {
    this.attributes = new Map([
      ["data-image-index", String(imageIndex)],
      ["href", ""],
    ]);
  }

  getAttribute(name) {
    return this.attributes.get(name) ?? null;
  }

  setAttribute(name, value) {
    this.attributes.set(name, value);
  }
}

function createBlobUrl(value) {
  return URL.createObjectURL(new Blob([value], { type: "text/plain" }));
}

async function assertBlobUrlFetchable(url) {
  const response = await fetch(url);
  const blob = await response.blob();
  assert.equal(await blob.text(), "image-0");
}

function fakePdfSource() {
  return {
    pageSvgImageData() {
      return {
        data: new TextEncoder().encode("image-0"),
        mime: "text/plain",
      };
    },
    pageSvgImageInfo() {
      return null;
    },
  };
}
