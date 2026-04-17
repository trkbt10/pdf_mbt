import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { createRequire } from "node:module";
import { pathToFileURL } from "node:url";
import ts from "typescript";

const require = createRequire(import.meta.url);

export async function loadImagePatchHooks() {
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

export function installAnimationFrameQueue() {
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

export class FakeSurface {
  constructor(images) {
    this.images = images;
  }

  querySelectorAll(selector) {
    assert.equal(selector, "image[data-image-index]");
    return this.images;
  }
}

export class FakeSvgImage {
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

export function createBlobUrl(value) {
  return URL.createObjectURL(new Blob([value], { type: "text/plain" }));
}

export async function assertBlobUrlFetchable(url, expectedText) {
  const response = await fetch(url);
  const blob = await response.blob();
  assert.equal(await blob.text(), expectedText);
}

export function fakePdfSource() {
  return {
    pageSvgImageData(_pageIndex, imageIndex) {
      return {
        data: new TextEncoder().encode(`image-${imageIndex}`),
        mime: "text/plain",
      };
    },
    pageSvgImageInfo() {
      return null;
    },
  };
}

function rewriteReactImports(source) {
  const reactUrl = pathToFileURL(require.resolve("react")).href;
  const jsxRuntimeUrl = pathToFileURL(require.resolve("react/jsx-runtime")).href;
  return source
    .replaceAll('from "react";', `from "${reactUrl}";`)
    .replaceAll('from "react/jsx-runtime";', `from "${jsxRuntimeUrl}";`);
}
