import assert from "node:assert/strict";
import { mkdtemp, readdir, readFile, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { pathToFileURL } from "node:url";
import { spawn } from "node:child_process";

const CHROME_PATH =
  process.env.CHROME_PATH ??
  "<local-cache>/ms-playwright/chromium_headless_shell-1217/chrome-headless-shell-mac-arm64/chrome-headless-shell";
let demoBuildPromise;

export async function withDemoPage(callback) {
  const demoUrl = await demoBuildUrl();
  const browser = await startChrome();
  const page = await browser.newPage();
  try {
    await page.navigate(demoUrl);
    await waitForReady(page);
    await callback(page);
  } finally {
    await page.close();
    await browser.close();
  }
}

export async function withDemoDevPage(callback) {
  const dev = await startDevServer();
  const browser = await startChrome();
  const page = await browser.newPage();
  try {
    await page.navigate(dev.url);
    await waitForReady(page);
    await callback(page);
  } finally {
    await page.close();
    await browser.close();
    await dev.stop();
  }
}

async function waitForReady(page) {
  await page.waitForFunction(() => {
    const el = document.querySelector("[data-pdf-status]");
    return el?.getAttribute("data-pdf-status") === "ready";
  });
}

export async function uploadPdf(page, filePath, fileName) {
  await page.setFileInputFiles("#pdf-file", [filePath]);
  await page.waitForFunction(
    (name) => {
      const el = document.querySelector("[data-pdf-document-name]");
      return el?.getAttribute("data-pdf-document-name") === name;
    },
    fileName
  );
}

export async function scrollToPage(page, pageNumber) {
  // Lazy page rendering causes the target's y-offset to drift as pages above
  // inflate. Re-scrolling on every poll keeps the target centered until the
  // layout stabilises.
  await page.waitForFunction(
    (number) => {
      const pageItem = document.querySelector(
        `[data-pdf-page-item][data-page-number="${number}"]`
      );
      if (!pageItem) {
        return false;
      }
      pageItem.scrollIntoView({ block: "center", inline: "nearest" });
      const rect = pageItem.getBoundingClientRect();
      return rect.top < window.innerHeight && rect.bottom > 0;
    },
    pageNumber
  );
}

export async function waitForVisiblePageImage(page, pageNumber) {
  return waitFor(() => page.evaluate(async (number) => {
    async function pageImageState(pageNumber) {
      const pageItem = pageItemForNumber(pageNumber);
      // Lazy loading of pages above may shift this page out of view again.
      // Re-scrolling on each poll keeps it centered until its SVG materialises.
      pageItem.scrollIntoView({ block: "center", inline: "nearest" });
      const images = Array.from(
        pageItem.querySelectorAll("svg image[data-image-index]")
      );
      const image = images[0] ?? null;
      const href =
        image?.getAttribute("href") ??
        image?.getAttributeNS("http://www.w3.org/1999/xlink", "href") ??
        "";
      const rect = image?.getBoundingClientRect();
      const style = image ? getComputedStyle(image) : null;
      const fetchOk = href
        ? await fetch(href)
            .then((response) => response.ok)
            .catch(() => false)
        : false;
      const visibleByRect = rect ? rect.width > 0 && rect.height > 0 : false;
      const visibleByStyle =
        style?.display !== "none" &&
        style?.visibility !== "hidden" &&
        style?.opacity !== "0";
      return {
        fetchOk,
        hasVisibleImage: Boolean(href && fetchOk && visibleByRect && visibleByStyle),
        href,
        imageCount: images.length,
        pageNumber,
        rect: rect
          ? {
              bottom: rect.bottom,
              height: rect.height,
              left: rect.left,
              right: rect.right,
              top: rect.top,
              width: rect.width,
            }
          : null,
        style: style
          ? {
              display: style.display,
              opacity: style.opacity,
              visibility: style.visibility,
            }
          : null,
      };
    }

    function pageItemForNumber(pageNumber) {
      const pageItem = document.querySelector(
        `[data-pdf-page-item][data-page-number="${pageNumber}"]`
      );
      if (!pageItem) {
        throw new Error(`Page ${pageNumber} is not in the page list`);
      }
      return pageItem;
    }

    const state = await pageImageState(number);
    return state.hasVisibleImage ? state : false;
  }, pageNumber), 90_000);
}

export async function pageImageDiagnostics(page, pageNumber) {
  return page.evaluate(async (number) => {
    async function pageImageState(pageNumber) {
      const pageItem = pageItemForNumber(pageNumber);
      const images = Array.from(
        pageItem.querySelectorAll("svg image[data-image-index]")
      );
      const image = images[0] ?? null;
      const href =
        image?.getAttribute("href") ??
        image?.getAttributeNS("http://www.w3.org/1999/xlink", "href") ??
        "";
      const rect = image?.getBoundingClientRect();
      const style = image ? getComputedStyle(image) : null;
      const fetchOk = href
        ? await fetch(href)
            .then((response) => response.ok)
            .catch(() => false)
        : false;
      const visibleByRect = rect ? rect.width > 0 && rect.height > 0 : false;
      const visibleByStyle =
        style?.display !== "none" &&
        style?.visibility !== "hidden" &&
        style?.opacity !== "0";
      return {
        fetchOk,
        hasVisibleImage: Boolean(href && fetchOk && visibleByRect && visibleByStyle),
        href,
        imageCount: images.length,
        pageNumber,
        rect: rect
          ? {
              bottom: rect.bottom,
              height: rect.height,
              left: rect.left,
              right: rect.right,
              top: rect.top,
              width: rect.width,
            }
          : null,
        style: style
          ? {
              display: style.display,
              opacity: style.opacity,
              visibility: style.visibility,
            }
          : null,
      };
    }

    function pageItemForNumber(pageNumber) {
      const pageItem = document.querySelector(
        `[data-pdf-page-item][data-page-number="${pageNumber}"]`
      );
      if (!pageItem) {
        throw new Error(`Page ${pageNumber} is not in the page list`);
      }
      return pageItem;
    }

    return pageImageState(number);
  }, pageNumber);
}

async function demoBuildUrl() {
  demoBuildPromise ??= buildDemo();
  return demoBuildPromise;
}

async function buildDemo() {
  const distDir = await mkdtemp(join(tmpdir(), "pdf-demo-dist-"));
  const child = spawn(
    "npm",
    ["exec", "vite", "--", "build", "--outDir", distDir, "--emptyOutDir"],
    {
      cwd: new URL("../..", import.meta.url),
      stdio: ["ignore", "pipe", "pipe"],
    }
  );
  let output = "";
  child.stdout.on("data", (chunk) => {
    output += chunk.toString();
  });
  child.stderr.on("data", (chunk) => {
    output += chunk.toString();
  });

  await new Promise((resolve, reject) => {
    child.on("exit", (code) => {
      if (code === 0) {
        resolve();
        return;
      }
      reject(new Error(`Vite build failed:\n${output}`));
    });
    child.on("error", reject);
  });
  await patchBuiltScripts(distDir);

  return pathToFileURL(join(distDir, "index.html")).href;
}

async function patchBuiltScripts(distDir) {
  const assetsDir = join(distDir, "assets");
  const entries = await readdir(assetsDir);
  const scripts = entries.filter((entry) => entry.endsWith(".js"));
  await Promise.all(
    scripts.map(async (script) => {
      const scriptPath = join(assetsDir, script);
      const source = await readFile(scriptPath, "utf8");
      await writeFile(
        scriptPath,
        [
          "WebAssembly.compile = (source, options) => Promise.resolve(new WebAssembly.Module(source, options));",
          source,
        ].join("\n")
      );
    })
  );
}

async function startDevServer() {
  const child = spawn(
    "npm",
    ["exec", "vite", "--", "dev", "--host", "127.0.0.1", "--port", "0"],
    {
      cwd: new URL("../..", import.meta.url),
      stdio: ["ignore", "pipe", "pipe"],
    }
  );
  let output = "";
  const url = await new Promise((resolve, reject) => {
    function onData(chunk) {
      output += chunk.toString();
      const match = /https?:\/\/127\.0\.0\.1:(\d+)/.exec(output);
      if (match) {
        child.stdout.off("data", onData);
        child.stderr.off("data", onData);
        resolve(`http://127.0.0.1:${match[1]}/`);
      }
    }
    child.stdout.on("data", onData);
    child.stderr.on("data", onData);
    child.on("exit", (code) => {
      reject(new Error(`vite dev exited (${code}) before printing URL:\n${output}`));
    });
  });
  return {
    url,
    async stop() {
      child.kill("SIGTERM");
      await waitForProcessExit(child);
    },
  };
}

async function startChrome() {
  const userDataDir = await mkdtemp(join(tmpdir(), "pdf-demo-chrome-"));
  const child = spawn(CHROME_PATH, [
    "--remote-debugging-pipe",
    "--single-process",
    "--no-sandbox",
    "--disable-gpu",
    "--no-first-run",
    "--no-default-browser-check",
    "--allow-file-access-from-files",
    `--user-data-dir=${userDataDir}`,
    "--window-size=1280,900",
    "about:blank",
  ], {
    stdio: ["ignore", "ignore", "pipe", "pipe", "pipe"],
  });
  child.stderr.on("data", () => {});
  const connection = CdpConnection.connect(child.stdio[3], child.stdio[4]);

  return {
    async newPage() {
      const { targetId } = await connection.send("Target.createTarget", {
        url: "about:blank",
      });
      const { sessionId } = await connection.send("Target.attachToTarget", {
        flatten: true,
        targetId,
      });
      const page = new CdpPage(connection, sessionId, targetId);
      await page.enable();
      return page;
    },
    async close() {
      connection.close();
      child.kill();
      await waitForProcessExit(child);
      await rm(userDataDir, {
        force: true,
        maxRetries: 5,
        recursive: true,
        retryDelay: 100,
      });
    },
  };
}

class CdpPage {
  constructor(connection, sessionId, targetId) {
    this.connection = connection;
    this.sessionId = sessionId;
    this.targetId = targetId;
  }

  async enable() {
    await this.send("Runtime.enable");
    await this.send("Page.enable");
    await this.send("DOM.enable");
    await this.send("Page.addScriptToEvaluateOnNewDocument", {
      source: `
        WebAssembly.compile = (source, options) => Promise.resolve(
          new WebAssembly.Module(source, options)
        );
      `,
    });
  }

  async navigate(url) {
    await this.send("Page.navigate", { url });
    await this.waitForLoad();
  }

  async close() {
    await this.connection.send("Target.closeTarget", {
      targetId: this.targetId,
    });
  }

  async screenshot({ format = "png", clip } = {}) {
    const params = { format };
    if (clip) {
      // CDP requires numeric clip with explicit `scale`. Floats are fine for
      // the dimensions but `scale` MUST be a number. Default to 1.
      params.clip = {
        x: clip.x,
        y: clip.y,
        width: clip.width,
        height: clip.height,
        scale: clip.scale ?? 1,
      };
    }
    const result = await this.send("Page.captureScreenshot", params);
    return Buffer.from(result.data, "base64");
  }

  async evaluate(pageFunction, ...args) {
    const expression = `(${pageFunction})(...${JSON.stringify(args)})`;
    const result = await this.send("Runtime.evaluate", {
      awaitPromise: true,
      expression,
      returnByValue: true,
    });
    if (result.exceptionDetails) {
      throw new Error(
        result.exceptionDetails.exception?.description ??
          result.exceptionDetails.text
      );
    }
    return result.result.value;
  }

  async waitForFunction(pageFunction, ...args) {
    return waitFor(() => this.evaluate(pageFunction, ...args), 20_000);
  }

  async setFileInputFiles(selector, files) {
    const { root } = await this.send("DOM.getDocument");
    const { nodeId } = await this.send("DOM.querySelector", {
      nodeId: root.nodeId,
      selector,
    });
    assert.notEqual(nodeId, 0, `file input not found: ${selector}`);
    await this.send("DOM.setFileInputFiles", { files, nodeId });
  }

  async waitForLoad() {
    await waitFor(() =>
      this.evaluate(() => document.readyState === "complete")
    );
  }

  send(method, params = {}) {
    return this.connection.send(method, params, this.sessionId);
  }
}

class CdpConnection {
  constructor(input, output) {
    this.nextId = 1;
    this.outputBuffer = "";
    this.pending = new Map();
    this.input = input;
    this.output = output;
    this.output.setEncoding("utf8");
    this.output.on("data", (chunk) => {
      this.outputBuffer += chunk;
      this.readMessages();
    });
  }

  static connect(input, output) {
    return new CdpConnection(input, output);
  }

  readMessages() {
    let separatorIndex = this.outputBuffer.indexOf("\0");
    while (separatorIndex >= 0) {
      const rawMessage = this.outputBuffer.slice(0, separatorIndex);
      this.outputBuffer = this.outputBuffer.slice(separatorIndex + 1);
      this.handleMessage(JSON.parse(rawMessage));
      separatorIndex = this.outputBuffer.indexOf("\0");
    }
  }

  handleMessage(message) {
    if (!message.id) {
      return;
    }
    const pending = this.pending.get(message.id);
    if (!pending) {
      return;
    }
    this.pending.delete(message.id);
    if (message.error) {
      pending.reject(new Error(message.error.message));
      return;
    }
    pending.resolve(message.result);
  }

  send(method, params = {}, sessionId = undefined) {
    const id = this.nextId;
    this.nextId += 1;
    const payload = { id, method, params };
    if (sessionId) {
      payload.sessionId = sessionId;
    }
    const promise = new Promise((resolve, reject) => {
      this.pending.set(id, { reject, resolve });
    });
    this.input.write(`${JSON.stringify(payload)}\0`);
    return promise;
  }

  close() {
    this.input.end();
    this.output.destroy();
  }
}

async function waitFor(predicate, timeoutMs = 10_000) {
  const deadline = Date.now() + timeoutMs;
  let lastError;
  while (Date.now() < deadline) {
    try {
      const value = await predicate();
      if (value) {
        return value;
      }
    } catch (error) {
      lastError = error;
    }
    await new Promise((resolve) => setTimeout(resolve, 100));
  }
  if (lastError) {
    throw lastError;
  }
  throw new Error("Timed out waiting for browser condition");
}

async function waitForProcessExit(child) {
  if (child.exitCode !== null) {
    return;
  }
  await new Promise((resolve) => {
    const timeout = setTimeout(resolve, 2_000);
    child.once("exit", () => {
      clearTimeout(timeout);
      resolve();
    });
  });
}
