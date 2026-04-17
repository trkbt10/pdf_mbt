import { useCallback, useEffect, useRef, useState } from "react";
import type { ChangeEvent, DragEvent } from "react";
import type { RefObject } from "react";
import type {
  PdfCapabilityReport,
  PdfDocument,
  PdfImageInfo,
  PdfInfo,
  PdfPageGeometry,
  PdfRenderText,
} from "@trkbt10/pdf-wasm";

export type ZoomValue = "fit" | "0.5" | "0.75" | "1" | "1.25" | "1.5" | "2";

export interface ViewerPage {
  index: number;
  geometry: PdfPageGeometry;
}

export interface ViewerDocument {
  name: string;
  version: string;
  info: PdfInfo;
  featureReport: PdfCapabilityReport;
  pages: ViewerPage[];
  source: PdfDocument;
}

interface PageTextState {
  status: "idle" | "loading" | "ready" | "error";
  texts: PdfRenderText[];
  error?: string;
}

interface PageSvgState {
  status: "idle" | "loading" | "ready" | "error";
  svg: string;
  error?: string;
}

interface CachedPage extends PageSvgState {
  imageUrls: Map<number, string>;
}

interface DocumentCache {
  handle: number;
  pages: Map<number, CachedPage>;
}

interface PageImagesState {
  status: "idle" | "loading" | "ready" | "error";
  count: number;
  items: ImageState[];
  error?: string;
}

interface ImageState {
  info: PdfImageInfo | null;
  rgba: Uint8Array | null;
  status: "idle" | "loading" | "ready" | "error";
  error?: string;
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
  const [zoomValue, setZoomValue] = useState<ZoomValue>("fit");
  const [currentPageIndex, setCurrentPageIndex] = useState(0);
  const [dragActive, setDragActive] = useState(false);
  const cacheRef = useRef<DocumentCache | null>(null);
  const [, setPageSvgVersion] = useState(0);
  const pageSvgs = cachedPageSvgs(cacheRef.current, document);
  const [pageTexts, setPageTexts] = useState<Record<number, PageTextState>>({});
  const [pageImages, setPageImages] = useState<Record<number, PageImagesState>>(
    {}
  );
  const imageLoadFailures = useRef<Set<string>>(new Set());

  useEffect(() => {
    setCurrentPageIndex(0);
    if (document) {
      ensureCache(cacheRef, document);
    } else if (cacheRef.current) {
      revokeAllBlobUrls(cacheRef.current);
      cacheRef.current = null;
    }
    setPageSvgVersion((version) => version + 1);
    setPageTexts({});
    setPageImages({});
    imageLoadFailures.current.clear();
  }, [document]);

  const loadPageSvg = useCallback(
    (pageIndex: number) => {
      if (!document) {
        return;
      }
      const cache = ensureCache(cacheRef, document);
      const current = cache.pages.get(pageIndex);
      if (current) {
        return;
      }
      cache.pages.set(pageIndex, {
        imageUrls: new Map(),
        status: "loading",
        svg: "",
      });
      setPageSvgVersion((version) => version + 1);
      window.setTimeout(() => {
        if (cacheRef.current !== cache) {
          return;
        }
        try {
          const svg = document.source.pageToSvgDeferred(pageIndex);
          const imageUrls = createDeferredSvgImageUrls(
            document.source,
            pageIndex,
            svg
          );
          cache.pages.set(pageIndex, { imageUrls, status: "ready", svg });
          setPageSvgVersion((version) => version + 1);
        } catch (error) {
          cache.pages.set(pageIndex, {
            error: errorMessage(error),
            imageUrls: new Map(),
            status: "error",
            svg: "",
          });
          setPageSvgVersion((version) => version + 1);
        }
      }, 0);
    },
    [document]
  );

  const loadPageText = useCallback(
    (pageIndex: number) => {
      if (!document) {
        return;
      }
      const current = pageTexts[pageIndex];
      if (current && current.status !== "idle") {
        return;
      }
      setPageTexts((states) => ({
        ...states,
        [pageIndex]: { status: "loading", texts: [] },
      }));
      window.setTimeout(() => {
        try {
          const texts = document.source.pageTextPositions(pageIndex);
          setPageTexts((states) => ({
            ...states,
            [pageIndex]: { status: "ready", texts },
          }));
        } catch (error) {
          setPageTexts((states) => ({
            ...states,
            [pageIndex]: {
              error: errorMessage(error),
              status: "error",
              texts: [],
            },
          }));
        }
      }, 0);
    },
    [document, pageTexts]
  );

  const loadPageImages = useCallback(
    (pageIndex: number) => {
      if (!document) {
        return;
      }
      const current = pageImages[pageIndex];
      if (current && current.status !== "idle") {
        return;
      }
      setPageImages((states) => ({
        ...states,
        [pageIndex]: emptyPageImages("loading"),
      }));
      window.setTimeout(() => {
        try {
          const count = document.source.pageImageCount(pageIndex);
          const items = Array.from({ length: count }, (_, imageIndex) =>
            readImageInfo(document.source, pageIndex, imageIndex)
          );
          setPageImages((states) => ({
            ...states,
            [pageIndex]: { count, items, status: "ready" },
          }));
        } catch (error) {
          setPageImages((states) => ({
            ...states,
            [pageIndex]: {
              ...emptyPageImages("error"),
              error: errorMessage(error),
            },
          }));
        }
      }, 0);
    },
    [document, pageImages]
  );

  const loadImageRGBA = useCallback(
    (pageIndex: number, imageIndex: number) => {
      if (!document) {
        return;
      }
      const loadKey = imageLoadKey(pageIndex, imageIndex);
      if (imageLoadFailures.current.has(loadKey)) {
        return;
      }
      const image = pageImages[pageIndex]?.items[imageIndex];
      if (!image || image.status !== "idle" || image.error) {
        return;
      }
      setPageImages((states) =>
        updateImageState(states, pageIndex, imageIndex, {
          ...image,
          status: "loading",
        })
      );
      window.setTimeout(() => {
        try {
          const rgba = document.source.pageImageRGBA(pageIndex, imageIndex);
          if (
            image.info &&
            rgba.length !== image.info.width * image.info.height * 4
          ) {
            throw new Error("Image RGBA data is unavailable");
          }
          setPageImages((states) =>
            updateImageState(states, pageIndex, imageIndex, {
              ...states[pageIndex].items[imageIndex],
              rgba,
              status: "ready",
            })
          );
        } catch (error) {
          imageLoadFailures.current.add(loadKey);
          setPageImages((states) =>
            updateImageState(states, pageIndex, imageIndex, {
              ...states[pageIndex].items[imageIndex],
              error: errorMessage(error),
              status: "error",
            })
          );
        }
      }, 0);
    },
    [document, pageImages]
  );

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
            <label className="zoomControl">
              <span>Zoom</span>
              <select
                onChange={(event) =>
                  setZoomValue(event.currentTarget.value as ZoomValue)
                }
                value={zoomValue}
              >
                <option value="fit">Fit width</option>
                <option value="0.5">50%</option>
                <option value="0.75">75%</option>
                <option value="1">100%</option>
                <option value="1.25">125%</option>
                <option value="1.5">150%</option>
                <option value="2">200%</option>
              </select>
            </label>
          </div>

          <PageList
            currentPageIndex={currentPageIndex}
            document={document}
            loadImageRGBA={loadImageRGBA}
            loadPageImages={loadPageImages}
            loadPageSvg={loadPageSvg}
            loadPageText={loadPageText}
            onSelectPage={setCurrentPageIndex}
            pageImages={pageImages}
            pageSvgs={pageSvgs}
            pageTexts={pageTexts}
            zoomValue={zoomValue}
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
  loadImageRGBA,
  loadPageImages,
  loadPageSvg,
  loadPageText,
  onSelectPage,
  pageImages,
  pageSvgs,
  pageTexts,
  zoomValue,
}: {
  currentPageIndex: number;
  document: ViewerDocument | null;
  loadImageRGBA: (pageIndex: number, imageIndex: number) => void;
  loadPageImages: (pageIndex: number) => void;
  loadPageSvg: (pageIndex: number) => void;
  loadPageText: (pageIndex: number) => void;
  onSelectPage: (index: number) => void;
  pageImages: Record<number, PageImagesState>;
  pageSvgs: ReadonlyMap<number, CachedPage>;
  pageTexts: Record<number, PageTextState>;
  zoomValue: ZoomValue;
}) {
  if (!document) {
    return <p className="emptyState">Open or create a PDF to inspect pages.</p>;
  }

  return (
    <ol className="pageList">
      {document.pages.map((page) => (
        <PageItem
          currentPageIndex={currentPageIndex}
          imageState={pageImages[page.index] ?? emptyPageImages("idle")}
          key={page.index}
          loadImageRGBA={loadImageRGBA}
          loadPageImages={loadPageImages}
          loadPageSvg={loadPageSvg}
          loadPageText={loadPageText}
          onSelectPage={onSelectPage}
          page={page}
          source={document.source}
          svgState={pageSvgs.get(page.index) ?? emptyPageSvg("idle")}
          textState={pageTexts[page.index] ?? emptyPageText("idle")}
          zoomValue={zoomValue}
        />
      ))}
    </ol>
  );
}

function PageItem({
  currentPageIndex,
  imageState,
  loadImageRGBA,
  loadPageImages,
  loadPageSvg,
  loadPageText,
  onSelectPage,
  page,
  source,
  svgState,
  textState,
  zoomValue,
}: {
  currentPageIndex: number;
  imageState: PageImagesState;
  loadImageRGBA: (pageIndex: number, imageIndex: number) => void;
  loadPageImages: (pageIndex: number) => void;
  loadPageSvg: (pageIndex: number) => void;
  loadPageText: (pageIndex: number) => void;
  onSelectPage: (index: number) => void;
  page: ViewerPage;
  source: PdfDocument;
  svgState: PageSvgState;
  textState: PageTextState;
  zoomValue: ZoomValue;
}) {
  const itemRef = useRef<HTMLLIElement | null>(null);
  const isVisible = useElementInView(itemRef, "0px");
  const isNearViewport = useElementInView(itemRef, "900px");

  useEffect(() => {
    if (!isVisible) {
      return;
    }
    onSelectPage(page.index);
    loadPageSvg(page.index);
    loadPageText(page.index);
    loadPageImages(page.index);
  }, [
    isVisible,
    loadPageImages,
    loadPageSvg,
    loadPageText,
    onSelectPage,
    page.index,
  ]);

  return (
    <li
      className={pageItemClassName(page.index, currentPageIndex)}
      ref={itemRef}
    >
      <header>
        <h3>Page {page.index + 1}</h3>
        <div className="pageMeta">
          <span>{pageSizeSummary(page.geometry)}</span>
          <span>{imageSummary(imageState)}</span>
          <button
            onClick={() => {
              onSelectPage(page.index);
              loadPageSvg(page.index);
              loadPageText(page.index);
              loadPageImages(page.index);
            }}
            type="button"
          >
            Select page
          </button>
        </div>
      </header>
      <RenderedPageSvg
        geometry={page.geometry}
        isNearViewport={isNearViewport}
        pageIndex={page.index}
        source={source}
        svgState={svgState}
        textState={textState}
        zoomValue={zoomValue}
      />
      <details className="pageDebug">
        <summary>Lazy content</summary>
        <TextStatus textState={textState} />
        <ImageList
          imageState={imageState}
          loadImageRGBA={(imageIndex) => loadImageRGBA(page.index, imageIndex)}
          pageIndex={page.index}
        />
      </details>
    </li>
  );
}

function RenderedPageSvg({
  geometry,
  isNearViewport,
  pageIndex,
  source,
  svgState,
  textState,
  zoomValue,
}: {
  geometry: PdfPageGeometry;
  isNearViewport: boolean;
  pageIndex: number;
  source: PdfDocument;
  svgState: PageSvgState;
  textState: PageTextState;
  zoomValue: ZoomValue;
}) {
  const frameRef = useRef<HTMLDivElement | null>(null);
  const surfaceRef = useRef<HTMLDivElement | null>(null);
  const [fitWidth, setFitWidth] = useState(0);
  const scale = pageScale(geometry, zoomValue, fitWidth);
  const pageWidth = geometry.width * scale;
  const pageHeight = geometry.height * scale;

  useEffect(() => {
    const frame = frameRef.current;
    if (!frame) {
      return;
    }
    const updateWidth = () => setFitWidth(frame.clientWidth);
    updateWidth();
    const observer = new ResizeObserver(updateWidth);
    observer.observe(frame);
    return () => observer.disconnect();
  }, []);

  useEffect(() => {
    if (!isNearViewport || svgState.status !== "ready") {
      return;
    }
    const surface = surfaceRef.current;
    if (!surface) {
      return;
    }
    return patchDeferredSvgImages(surface, source, pageIndex);
  }, [isNearViewport, pageIndex, source, svgState.status, svgState.svg]);

  return (
    <div className="pageCanvasViewport" ref={frameRef}>
      {isNearViewport && svgState.status === "ready" ? (
        <div
          aria-label={`Rendered PDF page ${pageIndex + 1}`}
          className="pageSvgSurface"
          dangerouslySetInnerHTML={{ __html: svgState.svg }}
          ref={surfaceRef}
          style={{
            height: `${pageHeight}px`,
            width: `${pageWidth}px`,
          }}
        />
      ) : isNearViewport &&
        svgState.status === "error" &&
        textState.status === "ready" ? (
        <FallbackPageCanvas
          geometry={geometry}
          pageHeight={pageHeight}
          pageIndex={pageIndex}
          pageWidth={pageWidth}
          scale={scale}
          texts={textState.texts}
        />
      ) : (
        <div
          aria-label={`PDF page ${pageIndex + 1} placeholder`}
          className="pagePlaceholder"
          style={{ height: `${pageHeight}px`, width: `${pageWidth}px` }}
        >
          <span>Page {pageIndex + 1}</span>
        </div>
      )}
      {(svgState.status === "loading" || textState.status === "loading") && (
        <p className="pageLoading">Loading page SVG...</p>
      )}
      {svgState.status === "error" && (
        <p className="imageError">{svgState.error}</p>
      )}
    </div>
  );
}

function patchDeferredSvgImages(
  surface: HTMLElement,
  source: PdfDocument,
  pageIndex: number
) {
  const urls: string[] = [];
  let cancelled = false;
  let frameId = 0;
  let images: SVGImageElement[] = [];
  let cursor = 0;

  const patchNext = () => {
    if (cancelled) {
      return;
    }
    const image = images[cursor];
    cursor += 1;
    if (image) {
      patchDeferredSvgImage(image, source, pageIndex, urls);
    }
    if (cursor < images.length) {
      frameId = window.requestAnimationFrame(patchNext);
    }
  };

  frameId = window.requestAnimationFrame(() => {
    images = Array.from(
      surface.querySelectorAll<SVGImageElement>("image[data-image-index]")
    );
    patchNext();
  });

  return () => {
    cancelled = true;
    window.cancelAnimationFrame(frameId);
    for (const url of urls) {
      URL.revokeObjectURL(url);
    }
  };
}

function patchDeferredSvgImage(
  image: SVGImageElement,
  source: PdfDocument,
  pageIndex: number,
  urls: string[]
) {
  const imageIndex = parseImageIndex(image.getAttribute("data-image-index"));
  if (imageIndex === null) {
    return;
  }
  const { data, mime } = source.pageSvgImageData(pageIndex, imageIndex);
  if (!mime || data.length === 0) {
    return;
  }
  const url = URL.createObjectURL(
    new Blob([uint8ArrayBlobPart(data)], { type: mime })
  );
  urls.push(url);
  image.setAttribute("href", url);
}

function parseImageIndex(rawIndex: string | null): number | null {
  if (!rawIndex) {
    return null;
  }
  const imageIndex = Number.parseInt(rawIndex, 10);
  if (!Number.isFinite(imageIndex)) {
    return null;
  }
  return imageIndex;
}

function uint8ArrayBlobPart(data: Uint8Array): ArrayBuffer {
  const copy = new Uint8Array(data.byteLength);
  copy.set(data);
  return copy.buffer;
}

function FallbackPageCanvas({
  geometry,
  pageHeight,
  pageIndex,
  pageWidth,
  scale,
  texts,
}: {
  geometry: PdfPageGeometry;
  pageHeight: number;
  pageIndex: number;
  pageWidth: number;
  scale: number;
  texts: PdfRenderText[];
}) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);

  useEffect(() => {
    const canvas = canvasRef.current;
    const context = canvas?.getContext("2d");
    if (!canvas || !context) {
      return;
    }
    drawFallbackPage(canvas, context, geometry, texts, scale);
  }, [geometry, scale, texts]);

  return (
    <canvas
      aria-label={`Text fallback for PDF page ${pageIndex + 1}`}
      ref={canvasRef}
      style={{
        height: `${pageHeight}px`,
        width: `${pageWidth}px`,
      }}
    />
  );
}

function drawFallbackPage(
  canvas: HTMLCanvasElement,
  context: CanvasRenderingContext2D,
  geometry: PdfPageGeometry,
  texts: PdfRenderText[],
  scale: number
) {
  const pixelRatio = window.devicePixelRatio || 1;
  const canvasWidth = Math.max(
    1,
    Math.round(geometry.width * scale * pixelRatio)
  );
  const canvasHeight = Math.max(
    1,
    Math.round(geometry.height * scale * pixelRatio)
  );
  canvas.width = canvasWidth;
  canvas.height = canvasHeight;
  context.setTransform(scale * pixelRatio, 0, 0, scale * pixelRatio, 0, 0);
  context.fillStyle = "#ffffff";
  context.fillRect(0, 0, geometry.width, geometry.height);
  context.fillStyle = "#111111";
  context.textBaseline = "alphabetic";
  for (const text of texts) {
    context.font = `${safeFontSize(text.fontSize)}px sans-serif`;
    context.fillText(text.text, text.x, geometry.height - text.y);
  }
}

function TextStatus({ textState }: { textState: PageTextState }) {
  if (textState.status === "error") {
    return <p className="imageError">{textState.error}</p>;
  }
  if (textState.status !== "ready") {
    return <p className="mutedText">Text positions load when the page is visible.</p>;
  }
  if (textState.texts.length === 0) {
    return <p className="mutedText">No positioned text on this page.</p>;
  }
  return <pre>{textState.texts.map((text) => text.text).join("\n")}</pre>;
}

function ImageList({
  imageState,
  loadImageRGBA,
  pageIndex,
}: {
  imageState: PageImagesState;
  loadImageRGBA: (imageIndex: number) => void;
  pageIndex: number;
}) {
  if (imageState.status === "error") {
    return <p className="imageError">{imageState.error}</p>;
  }
  if (imageState.status !== "ready") {
    return <p className="mutedText">Image placeholders load when the page is visible.</p>;
  }
  if (imageState.count === 0) {
    return <p className="mutedText">No images on this page.</p>;
  }

  return (
    <div className="imageGrid">
      {imageState.items.map((image, index) => (
        <ImageTile
          image={image}
          imageIndex={index}
          key={`${pageIndex}-${index}`}
          loadImageRGBA={loadImageRGBA}
        />
      ))}
    </div>
  );
}

function ImageTile({
  image,
  imageIndex,
  loadImageRGBA,
}: {
  image: ImageState;
  imageIndex: number;
  loadImageRGBA: (imageIndex: number) => void;
}) {
  const tileRef = useRef<HTMLElement | null>(null);
  const isVisible = useElementInView(tileRef, "200px");

  useEffect(() => {
    if (isVisible && image.status === "idle" && !image.error) {
      loadImageRGBA(imageIndex);
    }
  }, [image.error, image.status, imageIndex, isVisible, loadImageRGBA]);

  const label = image.info
    ? `${image.info.width} x ${image.info.height} ${infoValue(image.info.colorSpace)}`
    : "Image metadata unavailable";

  return (
    <figure ref={tileRef}>
      {image.info && image.rgba ? (
        <ImageCanvas image={image} />
      ) : image.status === "error" ? (
        <div className="imagePlaceholder" role="status">
          {image.error ?? "RGBA unavailable"}
        </div>
      ) : (
        <button
          className="imagePlaceholder"
          onClick={() => loadImageRGBA(imageIndex)}
          type="button"
        >
          {image.status === "loading" ? "Loading RGBA" : "Load RGBA"}
        </button>
      )}
      <figcaption>{label}</figcaption>
    </figure>
  );
}

function ImageCanvas({ image }: { image: ImageState }) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const info = image.info;
  const rgba = image.rgba;

  useEffect(() => {
    const canvas = canvasRef.current;
    const context = canvas?.getContext("2d");
    if (!canvas || !context || !info || !rgba) {
      return;
    }
    const imageData = new ImageData(
      new Uint8ClampedArray(rgba),
      info.width,
      info.height
    );
    context.putImageData(imageData, 0, 0);
  }, [info, rgba]);

  if (!info) {
    return null;
  }

  return (
    <canvas
      aria-label={`Extracted image ${info.width} by ${info.height}`}
      height={info.height}
      ref={canvasRef}
      width={info.width}
    />
  );
}

function readImageInfo(
  document: PdfDocument,
  pageIndex: number,
  imageIndex: number
): ImageState {
  try {
    return {
      info: document.pageImageInfo(pageIndex, imageIndex),
      rgba: null,
      status: "idle",
    };
  } catch (error) {
    return {
      error: errorMessage(error),
      info: null,
      rgba: null,
      status: "error",
    };
  }
}

function updateImageState(
  states: Record<number, PageImagesState>,
  pageIndex: number,
  imageIndex: number,
  image: ImageState
): Record<number, PageImagesState> {
  const page = states[pageIndex];
  if (!page) {
    return states;
  }
  const items = page.items.slice();
  items[imageIndex] = image;
  return {
    ...states,
    [pageIndex]: { ...page, items },
  };
}

function ensureCache(
  cacheRef: RefObject<DocumentCache | null>,
  document: ViewerDocument
): DocumentCache {
  const handle = document.source.handle;
  const cache = cacheRef.current;
  if (cache && cache.handle === handle) {
    return cache;
  }
  if (cache) {
    revokeAllBlobUrls(cache);
  }
  const nextCache = { handle, pages: new Map<number, CachedPage>() };
  cacheRef.current = nextCache;
  return nextCache;
}

function cachedPageSvgs(
  cache: DocumentCache | null,
  document: ViewerDocument | null
): ReadonlyMap<number, CachedPage> {
  if (!cache || !document || cache.handle !== document.source.handle) {
    return new Map();
  }
  return cache.pages;
}

function createDeferredSvgImageUrls(
  source: PdfDocument,
  pageIndex: number,
  svg: string
): Map<number, string> {
  const urls = new Map<number, string>();
  try {
    for (const imageIndex of deferredSvgImageIndexes(svg)) {
      const { data, mime } = source.pageSvgImageData(pageIndex, imageIndex);
      if (mime && data.length > 0) {
        urls.set(
          imageIndex,
          URL.createObjectURL(
            new Blob([uint8ArrayBlobPart(data)], { type: mime })
          )
        );
      }
    }
  } catch (error) {
    revokeBlobUrlMap(urls);
    throw error;
  }
  return urls;
}

function deferredSvgImageIndexes(svg: string): number[] {
  const parsed = new DOMParser().parseFromString(svg, "image/svg+xml");
  const rawIndexes = Array.from(
    parsed.querySelectorAll<SVGImageElement>("image[data-image-index]")
  ).map((image) => image.getAttribute("data-image-index"));
  const indexes = rawIndexes
    .map((rawIndex) => parseImageIndex(rawIndex))
    .filter((index): index is number => index !== null);
  return Array.from(new Set(indexes));
}

function revokeAllBlobUrls(cache: DocumentCache) {
  for (const page of cache.pages.values()) {
    revokeBlobUrlMap(page.imageUrls);
  }
}

function revokeBlobUrlMap(urls: ReadonlyMap<number, string>) {
  for (const url of urls.values()) {
    URL.revokeObjectURL(url);
  }
}

function imageLoadKey(pageIndex: number, imageIndex: number): string {
  return `${pageIndex}:${imageIndex}`;
}

function emptyPageText(status: PageTextState["status"]): PageTextState {
  return { status, texts: [] };
}

function emptyPageSvg(status: PageSvgState["status"]): PageSvgState {
  return { status, svg: "" };
}

function emptyPageImages(status: PageImagesState["status"]): PageImagesState {
  return { count: 0, items: [], status };
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

function pageScale(
  geometry: PdfPageGeometry,
  zoomValue: ZoomValue,
  fitWidth: number
): number {
  if (zoomValue !== "fit") {
    return Number(zoomValue);
  }
  if (fitWidth <= 0 || geometry.width <= 0) {
    return 1;
  }
  return clampScale((fitWidth - 2) / geometry.width);
}

function clampScale(scale: number): number {
  if (scale < 0.1) {
    return 0.1;
  }
  if (scale > 4) {
    return 4;
  }
  return scale;
}

function safeFontSize(value: number): number {
  if (Number.isFinite(value) && value > 0) {
    return value;
  }
  return 12;
}

function imageSummary(imageState: PageImagesState): string {
  if (imageState.status === "idle") {
    return "Images pending";
  }
  if (imageState.status === "loading") {
    return "Loading images";
  }
  if (imageState.count === 1) {
    return "1 image";
  }
  return `${imageState.count} images`;
}

function pageSizeSummary(geometry: PdfPageGeometry): string {
  return `${Math.round(geometry.width)} x ${Math.round(geometry.height)} pt`;
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

function errorMessage(error: unknown): string {
  if (error instanceof Error) {
    return error.message;
  }
  return String(error);
}

function useElementInView<T extends Element>(
  ref: RefObject<T | null>,
  rootMargin: string
): boolean {
  const [isVisible, setIsVisible] = useState(false);

  useEffect(() => {
    const element = ref.current;
    if (!element) {
      return;
    }
    if (typeof IntersectionObserver === "undefined") {
      setIsVisible(true);
      return;
    }
    const observer = new IntersectionObserver(
      ([entry]) => setIsVisible(entry.isIntersecting),
      { rootMargin }
    );
    observer.observe(element);
    return () => observer.disconnect();
  }, [ref, rootMargin]);

  return isVisible;
}
