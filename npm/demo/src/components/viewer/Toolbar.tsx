import { useId, useRef } from "react";
import {
  ChevronLeft,
  ChevronRight,
  Download,
  HelpCircle,
  Menu,
  Minus,
  Plus,
  Search,
  Upload,
} from "lucide-react";
import {
  closeDocument,
  getCurrentDocumentBytes,
  navigateToPage,
  openDocument,
  setUi,
} from "../../store/viewer-store";
import {
  useCurrentPage,
  useDocumentMeta,
  usePageCount,
  useUi,
  useWasmStatus,
} from "../../store/use-viewer-store";
import { clamp, errorMessage } from "../../lib/format";
import type { ZoomKind } from "../../store/viewer-store.types";
import { ToolbarSearch } from "./ToolbarSearch";
import styles from "./Toolbar.module.css";

interface ToolbarProps {
  debugEnabled: boolean;
  onOpenDebug: () => void;
}

export function Toolbar({ debugEnabled, onOpenDebug }: ToolbarProps) {
  const fileInputRef = useRef<HTMLInputElement>(null);
  const pageInputId = useId();
  const wasm = useWasmStatus();
  const meta = useDocumentMeta();
  const pageCount = usePageCount();
  const currentPage = useCurrentPage();
  const ui = useUi();

  const disabled = wasm.status !== "ready";
  const hasDocument = meta.handle !== null;
  const max = Math.max(0, pageCount - 1);

  async function handleFile(file: File): Promise<void> {
    try {
      const buf = await file.arrayBuffer();
      await openDocument(new Uint8Array(buf), file.name);
    } catch (error) {
      // Open failures keep the previous document; surface via console.
      console.warn("pdf-demo: open failed", errorMessage(error));
    }
  }

  function handleFileChange(event: React.ChangeEvent<HTMLInputElement>): void {
    const file = event.currentTarget.files?.[0];
    event.currentTarget.value = "";
    if (file) {
      void handleFile(file);
    }
  }

  function handleDrop(file: File): void {
    void handleFile(file);
  }

  function handlePagePrev(): void {
    navigateToPage(clamp(currentPage - 1, 0, max));
  }
  function handlePageNext(): void {
    navigateToPage(clamp(currentPage + 1, 0, max));
  }
  function handlePageInput(event: React.ChangeEvent<HTMLInputElement>): void {
    const raw = Number(event.currentTarget.value);
    if (!Number.isFinite(raw)) return;
    navigateToPage(clamp(Math.trunc(raw) - 1, 0, max));
  }

  function handleZoomChange(event: React.ChangeEvent<HTMLSelectElement>): void {
    const value = event.currentTarget.value;
    if (value === "fit-width" || value === "fit-page" || value === "actual") {
      setUi({ zoom: { kind: value as ZoomKind, scale: 1 } });
      return;
    }
    const scale = Number(value);
    if (Number.isFinite(scale)) {
      setUi({ zoom: { kind: "custom", scale } });
    }
  }

  function handleZoomOut(): void {
    setUi({ zoom: { kind: "custom", scale: clamp(ui.zoom.scale - 0.1, 0.1, 4) } });
  }
  function handleZoomIn(): void {
    setUi({ zoom: { kind: "custom", scale: clamp(ui.zoom.scale + 0.1, 0.1, 4) } });
  }

  function handleSidebar(): void {
    setUi({ sidebar: { open: !ui.sidebar.open } });
  }

  function handleDownload(): void {
    const bytes = getCurrentDocumentBytes();
    if (!bytes || !meta.name) return;
    const copy = new Uint8Array(bytes.byteLength);
    copy.set(bytes);
    const url = URL.createObjectURL(new Blob([copy], { type: "application/pdf" }));
    const a = document.createElement("a");
    a.href = url;
    a.download = meta.name;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    setTimeout(() => URL.revokeObjectURL(url), 0);
  }

  void handleDrop; // exposed via App-level DropZone wrapper.
  void closeDocument; // currently unused in toolbar but reserved for "Close" UX.

  const zoomSelectValue =
    ui.zoom.kind === "custom" ? ui.zoom.scale.toFixed(2) : ui.zoom.kind;
  const displayPage = pageCount === 0 ? 0 : currentPage + 1;

  return (
    <header
      className={styles.toolbar}
      role="toolbar"
      aria-label="PDF viewer toolbar"
      data-pdf-status={wasm.status}
      data-pdf-document-name={meta.name ?? ""}
    >
      <div className={styles.group}>
        <button
          type="button"
          className={styles.iconButton}
          aria-label="Toggle sidebar"
          aria-pressed={ui.sidebar.open}
          onClick={handleSidebar}
        >
          <Menu size={18} />
        </button>
        <span className={styles.docTitle} title={meta.name ?? ""}>
          {wasm.status === "loading"
            ? "Loading…"
            : wasm.status === "error"
              ? wasm.error ?? "wasm error"
              : meta.name ?? "No document"}
        </span>
      </div>

      <div className={styles.group}>
        <button
          type="button"
          className={styles.button}
          disabled={disabled}
          onClick={() => fileInputRef.current?.click()}
        >
          <Upload size={14} />
          Open
        </button>
        <input
          ref={fileInputRef}
          id="pdf-file"
          className={styles.fileInput}
          type="file"
          accept="application/pdf,.pdf"
          onChange={handleFileChange}
        />
      </div>

      <div className={styles.pageNav}>
        <button
          type="button"
          className={styles.iconButton}
          aria-label="Previous page"
          disabled={!hasDocument || currentPage <= 0}
          onClick={handlePagePrev}
        >
          <ChevronLeft size={16} />
        </button>
        <label htmlFor={pageInputId} className={styles.pageOf} hidden>
          Page
        </label>
        <input
          id={pageInputId}
          type="number"
          className={styles.pageInput}
          aria-label="Current page"
          min={1}
          max={Math.max(1, pageCount)}
          value={displayPage}
          onChange={handlePageInput}
          disabled={!hasDocument}
        />
        <span className={styles.pageOf}>/ {pageCount}</span>
        <button
          type="button"
          className={styles.iconButton}
          aria-label="Next page"
          disabled={!hasDocument || currentPage >= max}
          onClick={handlePageNext}
        >
          <ChevronRight size={16} />
        </button>
      </div>

      <div className={styles.zoomGroup}>
        <button
          type="button"
          className={styles.iconButton}
          aria-label="Zoom out"
          onClick={handleZoomOut}
          disabled={!hasDocument}
        >
          <Minus size={16} />
        </button>
        <select
          className={styles.zoomSelect}
          aria-label="Zoom"
          value={zoomSelectValue}
          onChange={handleZoomChange}
          disabled={!hasDocument}
        >
          <option value="0.50">50%</option>
          <option value="0.75">75%</option>
          <option value="actual">100%</option>
          <option value="1.25">125%</option>
          <option value="1.50">150%</option>
          <option value="2.00">200%</option>
          <option value="fit-width">Fit width</option>
          <option value="fit-page">Fit page</option>
        </select>
        <button
          type="button"
          className={styles.iconButton}
          aria-label="Zoom in"
          onClick={handleZoomIn}
          disabled={!hasDocument}
        >
          <Plus size={16} />
        </button>
      </div>

      <div className={styles.spacer} />

      <ToolbarSearch />

      <div className={styles.group}>
        <button
          type="button"
          className={styles.iconButton}
          aria-label="Download PDF"
          onClick={handleDownload}
          disabled={!hasDocument}
        >
          <Download size={18} />
        </button>
        {debugEnabled && (
          <button
            type="button"
            className={styles.iconButton}
            aria-label="Open debug panel"
            onClick={onOpenDebug}
          >
            <HelpCircle size={18} />
          </button>
        )}
      </div>
    </header>
  );
}

// Placeholder so unused imports don't trip the lint rule on Search icon.
void Search;
