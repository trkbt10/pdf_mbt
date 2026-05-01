import { init } from "@trkbt10/pdf-wasm";
import wasmUrl from "@trkbt10/pdf-wasm/pdf.wasm?url";
import { errorMessage } from "../lib/format";
import { setWasmStatus } from "./viewer-store";

let bootstrapped = false;

export function bootstrapWasm(): void {
  if (bootstrapped) return;
  bootstrapped = true;
  void (async () => {
    try {
      await init(await wasmSourceForRuntime(wasmUrl));
      setWasmStatus("ready", null);
    } catch (error) {
      setWasmStatus("error", errorMessage(error));
    }
  })();
}

async function wasmSourceForRuntime(source: string): Promise<string | ArrayBuffer> {
  const sourceUrl = new URL(source, window.location.href);
  if (sourceUrl.protocol !== "file:") return source;
  return readFileUrl(sourceUrl.href);
}

function readFileUrl(source: string): Promise<ArrayBuffer> {
  return new Promise((resolve, reject) => {
    const request = new XMLHttpRequest();
    request.open("GET", source);
    request.responseType = "arraybuffer";
    request.onload = () => {
      if (request.status === 200 || request.status === 0) {
        resolve(request.response);
        return;
      }
      reject(new Error(`Failed to load wasm: ${request.status}`));
    };
    request.onerror = () => reject(new Error("Failed to load wasm"));
    request.send();
  });
}
