import { useEffect, useRef, useState } from "react";
import {
  init,
  PdfContext,
  PdfDocument,
  type PdfCapabilityReport,
  type PdfImage,
  type PdfInfo,
  type PdfPageRenderData,
} from "@trkbt10/pdf-wasm";
import wasmUrl from "@trkbt10/pdf-wasm/pdf.wasm?url";
import PdfViewer, {
  type ExtractedImage,
  type ViewerDocument,
  type ViewerPage,
} from "./PdfViewer";

type WasmStatus = "loading" | "ready" | "error";

const emptyReport: PdfCapabilityReport = { entries: [] };

export default function App() {
  const [wasmStatus, setWasmStatus] = useState<WasmStatus>("loading");
  const [statusMessage, setStatusMessage] = useState("Loading wasm module");
  const [viewerDocument, setViewerDocument] = useState<ViewerDocument | null>(null);
  const [isBusy, setIsBusy] = useState(false);
  const documentRef = useRef<PdfDocument | null>(null);

  useEffect(() => {
    let cancelled = false;

    async function loadWasm() {
      try {
        await init(wasmUrl);
        if (cancelled) {
          return;
        }
        setWasmStatus("ready");
        setStatusMessage("Wasm module ready");
      } catch (error) {
        if (cancelled) {
          return;
        }
        setWasmStatus("error");
        setStatusMessage(errorMessage(error));
      }
    }

    void loadWasm();

    return () => {
      cancelled = true;
      documentRef.current?.close();
    };
  }, []);

  async function handleFile(file: File) {
    const buffer = await file.arrayBuffer();
    await openDocument(new Uint8Array(buffer), file.name);
  }

  async function handleCreatePdf() {
    const ctx = PdfContext.create();
    try {
      ctx.addPage(612, 792);
      ctx.setTitle("React Demo PDF");
      await openDocument(ctx.toBytes(), "created-with-pdf-context.pdf");
    } finally {
      ctx.close();
    }
  }

  async function openDocument(bytes: Uint8Array, name: string) {
    setIsBusy(true);
    setStatusMessage(`Opening ${name}`);

    let nextDocument: PdfDocument | null = null;
    try {
      nextDocument = await PdfDocument.open(bytes);
      const nextViewerDocument = readViewerDocument(nextDocument, name, bytes);
      documentRef.current?.close();
      documentRef.current = nextDocument;
      setViewerDocument(nextViewerDocument);
      setStatusMessage(`Loaded ${name}`);
    } catch (error) {
      nextDocument?.close();
      setStatusMessage(errorMessage(error));
    } finally {
      setIsBusy(false);
    }
  }

  return (
    <main className="appShell">
      <header className="topBar">
        <div>
          <p className="eyebrow">MoonBit PDF wasm</p>
          <h1>PDF package demo</h1>
        </div>
        <p className={statusClassName(wasmStatus)}>{statusMessage}</p>
      </header>

      <PdfViewer
        disabled={wasmStatus !== "ready" || isBusy}
        document={viewerDocument}
        onCreatePdf={handleCreatePdf}
        onFile={handleFile}
      />
    </main>
  );
}

function readViewerDocument(
  document: PdfDocument,
  name: string,
  bytes: Uint8Array
): ViewerDocument {
  const info = readInfo(document);
  const pageCount = document.pageCount();
  const pages = Array.from({ length: pageCount }, (_, index) =>
    readViewerPage(document, index)
  );

  return {
    featureReport: readFeatureReport(document),
    info,
    name,
    pages,
    version: pdfVersion(bytes),
  };
}

function readViewerPage(document: PdfDocument, index: number): ViewerPage {
  return {
    images: readImages(document, index),
    index,
    layoutText: readText(() => document.extractTextLayout(index)),
    rawText: readText(() => document.extractText(index)),
    renderData: readRenderData(document, index),
  };
}

function readRenderData(
  document: PdfDocument,
  pageIndex: number
): PdfPageRenderData {
  try {
    return document.renderData(pageIndex);
  } catch {
    return {
      height: 792,
      images: [],
      texts: [],
      width: 612,
    };
  }
}

function readImages(document: PdfDocument, pageIndex: number): ExtractedImage[] {
  try {
    return document.images(pageIndex).map((image, imageIndex) =>
      readImage(image, pageIndex, imageIndex)
    );
  } catch {
    return [];
  }
}

function readImage(
  image: PdfImage,
  pageIndex: number,
  imageIndex: number
): ExtractedImage {
  return {
    height: image.height(),
    id: `${pageIndex}-${imageIndex}`,
    rgba: image.toRGBA(),
    width: image.width(),
  };
}

function readInfo(document: PdfDocument): PdfInfo {
  try {
    return document.info();
  } catch {
    return {
      author: null,
      creator: null,
      pageCount: document.pageCount(),
      subject: null,
      title: null,
    };
  }
}

function readFeatureReport(document: PdfDocument): PdfCapabilityReport {
  try {
    return document.check();
  } catch {
    return emptyReport;
  }
}

function readText(read: () => string): string {
  try {
    return read();
  } catch (error) {
    return errorMessage(error);
  }
}

function pdfVersion(bytes: Uint8Array): string {
  const header = new TextDecoder().decode(bytes.subarray(0, 16));
  const match = /^%PDF-(\d\.\d)/.exec(header);
  if (!match) {
    return "Unknown";
  }
  return `PDF ${match[1]}`;
}

function errorMessage(error: unknown): string {
  if (error instanceof Error) {
    return error.message;
  }
  return String(error);
}

function statusClassName(status: WasmStatus): string {
  if (status === "ready") {
    return "statusPill statusReady";
  }
  if (status === "error") {
    return "statusPill statusError";
  }
  return "statusPill";
}
