import { useEffect, useRef, useState } from "react";
import type { ChangeEvent, DragEvent } from "react";
import type { PdfCapabilityReport, PdfInfo } from "@trkbt10/pdf-wasm";

export type LayoutMode = "raw" | "layout";

export interface ExtractedImage {
  id: string;
  width: number;
  height: number;
  rgba: Uint8Array;
}

export interface ViewerPage {
  index: number;
  rawText: string;
  layoutText: string;
  images: ExtractedImage[];
}

export interface ViewerDocument {
  name: string;
  version: string;
  info: PdfInfo;
  featureReport: PdfCapabilityReport;
  pages: ViewerPage[];
}

interface PdfViewerProps {
  disabled: boolean;
  document: ViewerDocument | null;
  onCreatePdf: () => Promise<void>;
  onFile: (file: File) => Promise<void>;
}

export default function PdfViewer({
  disabled,
  document,
  onCreatePdf,
  onFile,
}: PdfViewerProps) {
  const [layoutMode, setLayoutMode] = useState<LayoutMode>("raw");
  const [currentPageIndex, setCurrentPageIndex] = useState(0);
  const [dragActive, setDragActive] = useState(false);

  useEffect(() => {
    setCurrentPageIndex(0);
  }, [document]);

  async function handleInputChange(event: ChangeEvent<HTMLInputElement>) {
    const file = event.currentTarget.files?.[0];
    event.currentTarget.value = "";
    if (!file) {
      return;
    }
    await onFile(file);
  }

  function handleDragOver(event: DragEvent<HTMLDivElement>) {
    event.preventDefault();
    setDragActive(true);
  }

  function handleDragLeave() {
    setDragActive(false);
  }

  async function handleDrop(event: DragEvent<HTMLDivElement>) {
    event.preventDefault();
    setDragActive(false);
    const file = firstPdfFile(event.dataTransfer.files);
    if (!file) {
      return;
    }
    await onFile(file);
  }

  return (
    <section className="workspace" aria-label="PDF wasm workspace">
      <div
        className={dropZoneClassName(dragActive)}
        onDragLeave={handleDragLeave}
        onDragOver={handleDragOver}
        onDrop={handleDrop}
      >
        <div>
          <h2>Open a PDF</h2>
          <p>Drop a PDF file here or choose one from disk.</p>
        </div>
        <div className="actions">
          <label className="buttonLike" htmlFor="pdf-file">
            Choose PDF
          </label>
          <input
            accept="application/pdf,.pdf"
            disabled={disabled}
            id="pdf-file"
            onChange={handleInputChange}
            type="file"
          />
          <button disabled={disabled} onClick={onCreatePdf} type="button">
            Create New PDF
          </button>
        </div>
      </div>

      <div className="contentGrid">
        <aside className="documentPanel">
          <DocumentInfo document={document} />
          <FeatureReport report={document?.featureReport ?? null} />
        </aside>

        <section className="pagePanel" aria-label="Extracted pages">
          <div className="panelHeader">
            <div>
              <h2>Pages</h2>
              <p>{pageSummary(document, currentPageIndex)}</p>
            </div>
            <div className="toggleGroup" aria-label="Text layout mode">
              <button
                aria-pressed={layoutMode === "raw"}
                onClick={() => setLayoutMode("raw")}
                type="button"
              >
                Raw text
              </button>
              <button
                aria-pressed={layoutMode === "layout"}
                onClick={() => setLayoutMode("layout")}
                type="button"
              >
                Layout reconstruction
              </button>
            </div>
          </div>

          <PageList
            currentPageIndex={currentPageIndex}
            document={document}
            layoutMode={layoutMode}
            onSelectPage={setCurrentPageIndex}
          />
        </section>
      </div>
    </section>
  );
}

function DocumentInfo({ document }: { document: ViewerDocument | null }) {
  if (!document) {
    return (
      <section className="sideSection">
        <h2>PDF info</h2>
        <p className="mutedText">No document loaded.</p>
      </section>
    );
  }

  return (
    <section className="sideSection">
      <h2>PDF info</h2>
      <dl className="infoList">
        <div>
          <dt>File</dt>
          <dd>{document.name}</dd>
        </div>
        <div>
          <dt>Title</dt>
          <dd>{infoValue(document.info.title)}</dd>
        </div>
        <div>
          <dt>Pages</dt>
          <dd>{document.info.pageCount}</dd>
        </div>
        <div>
          <dt>Version</dt>
          <dd>{document.version}</dd>
        </div>
        <div>
          <dt>Author</dt>
          <dd>{infoValue(document.info.author)}</dd>
        </div>
        <div>
          <dt>Creator</dt>
          <dd>{infoValue(document.info.creator)}</dd>
        </div>
      </dl>
    </section>
  );
}

function FeatureReport({ report }: { report: PdfCapabilityReport | null }) {
  const entries = report?.entries ?? [];

  return (
    <section className="sideSection">
      <h2>Feature check</h2>
      {entries.length === 0 && <p className="mutedText">No report yet.</p>}
      {entries.length > 0 && (
        <ul className="featureList">
          {entries.map((entry) => (
            <li key={entry.featureName}>
              <span className={featureStatusClassName(entry.status)}>
                {entry.status}
              </span>
              <strong>{entry.featureName}</strong>
              <small>{entry.category}</small>
              <p>{entry.description}</p>
            </li>
          ))}
        </ul>
      )}
    </section>
  );
}

function PageList({
  currentPageIndex,
  document,
  layoutMode,
  onSelectPage,
}: {
  currentPageIndex: number;
  document: ViewerDocument | null;
  layoutMode: LayoutMode;
  onSelectPage: (index: number) => void;
}) {
  if (!document) {
    return <p className="emptyState">Open or create a PDF to inspect pages.</p>;
  }

  return (
    <ol className="pageList">
      {document.pages.map((page) => (
        <li className={pageItemClassName(page.index, currentPageIndex)} key={page.index}>
          <header>
            <h3>Page {page.index + 1}</h3>
            <div className="pageMeta">
              <span>{imageSummary(page.images)}</span>
              <button onClick={() => onSelectPage(page.index)} type="button">
                Select page
              </button>
            </div>
          </header>
          <pre>{pageText(page, layoutMode)}</pre>
          <ImageList images={page.images} />
        </li>
      ))}
    </ol>
  );
}

function ImageList({ images }: { images: ExtractedImage[] }) {
  if (images.length === 0) {
    return <p className="mutedText">No decoded images on this page.</p>;
  }

  return (
    <div className="imageGrid">
      {images.map((image) => (
        <figure key={image.id}>
          <ImageCanvas image={image} />
          <figcaption>
            {image.width} x {image.height} RGBA
          </figcaption>
        </figure>
      ))}
    </div>
  );
}

function ImageCanvas({ image }: { image: ExtractedImage }) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);

  useEffect(() => {
    const canvas = canvasRef.current;
    const context = canvas?.getContext("2d");
    if (!canvas || !context) {
      return;
    }
    const imageData = new ImageData(
      new Uint8ClampedArray(image.rgba),
      image.width,
      image.height
    );
    context.putImageData(imageData, 0, 0);
  }, [image]);

  return (
    <canvas
      aria-label={`Extracted image ${image.width} by ${image.height}`}
      height={image.height}
      ref={canvasRef}
      width={image.width}
    />
  );
}

function firstPdfFile(files: FileList): File | null {
  const allFiles = Array.from(files);
  const pdfFile = allFiles.find((file) => {
    if (file.type === "application/pdf") {
      return true;
    }
    return file.name.toLowerCase().endsWith(".pdf");
  });
  return pdfFile ?? null;
}

function pageText(page: ViewerPage, layoutMode: LayoutMode): string {
  if (layoutMode === "layout") {
    return page.layoutText;
  }
  return page.rawText;
}

function imageSummary(images: ExtractedImage[]): string {
  if (images.length === 1) {
    return "1 image";
  }
  return `${images.length} images`;
}

function pageSummary(
  document: ViewerDocument | null,
  currentPageIndex: number
): string {
  if (!document) {
    return "No pages loaded";
  }
  if (document.pages.length === 1) {
    return "1 page loaded, page 1 selected";
  }
  return `${document.pages.length} pages loaded, page ${currentPageIndex + 1} selected`;
}

function infoValue(value: string | null): string {
  return value ?? "Not set";
}

function dropZoneClassName(active: boolean): string {
  if (active) {
    return "dropZone dropZoneActive";
  }
  return "dropZone";
}

function featureStatusClassName(status: string): string {
  return `featureStatus featureStatus-${status}`;
}

function pageItemClassName(pageIndex: number, currentPageIndex: number): string {
  if (pageIndex === currentPageIndex) {
    return "pageItem pageItemActive";
  }
  return "pageItem";
}
