import { useEffect, useEffectEvent, useRef, useState } from "react";
import type { PdfPageGeometry } from "@trkbt10/pdf-wasm";
import { useResizeObserver } from "../../hooks/use-resize-observer";
import { useDocumentMeta, useUi } from "../../store/use-viewer-store";
import {
  getSnapshot,
  reportVisiblePage,
  subscribe,
} from "../../store/viewer-store";
import type { ZoomValue } from "../../store/viewer-store.types";
import { PageItem } from "./PageItem";
import styles from "./PageCanvas.module.css";

const PAGE_GAP = 16;

export function PageCanvas() {
  const meta = useDocumentMeta();
  const ui = useUi();
  const canvasRef = useRef<HTMLDivElement>(null);
  const [container, setContainer] = useState({ width: 0, height: 0 });

  useResizeObserver(canvasRef, (rect) =>
    setContainer({ width: rect.width, height: rect.height })
  );

  // Latest closure for the scroll target, captured via useEffectEvent so the
  // store subscription effect below stays at empty deps and never re-fires.
  // The scroll is deferred to a microtask + requestAnimationFrame so the
  // triggering click handler returns synchronously and does not block on
  // layout / IntersectionObserver cascades.
  const scrollToCurrentPage = useEffectEvent((pageIndex: number) => {
    requestAnimationFrame(() => {
      const root = canvasRef.current;
      if (!root) return;
      const target = root.querySelector<HTMLElement>(
        `[data-pdf-page-item][data-page-number="${pageIndex + 1}"]`
      );
      if (target) {
        target.scrollIntoView({
          block: "start",
          inline: "nearest",
          behavior: "auto",
        });
      }
    });
  });

  // Subscribe once: scroll only when navigationRevision bumps (i.e. an
  // explicit user navigation). Visibility-driven currentPage updates do
  // NOT bump that counter, so the user's scroll position stays put.
  useEffect(() => {
    let prev = getSnapshot().ui.navigationRevision;
    return subscribe(() => {
      const next = getSnapshot().ui.navigationRevision;
      if (next !== prev) {
        prev = next;
        scrollToCurrentPage(getSnapshot().ui.currentPage);
      }
    });
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // Synchronous scroll-driven page tracking: IntersectionObserver delays
  // the active-page callback by ~1 frame plus its own scheduling overhead,
  // which made the toolbar's "Page X of Y" lag noticeably behind the user's
  // wheel input. Reading scroll position directly during the scroll event
  // and reporting the closest page index removes that delay; rAF throttling
  // keeps the cost bounded.
  useEffect(() => {
    const root = canvasRef.current;
    if (!root) return;
    let frame = 0;
    function compute(): void {
      frame = 0;
      if (!root) return;
      const items = root.querySelectorAll<HTMLElement>("[data-pdf-page-item]");
      if (items.length === 0) return;
      const reference = root.scrollTop + 8;
      let bestIndex = 0;
      for (let i = 0; i < items.length; i += 1) {
        const item = items[i];
        if (!item) continue;
        if (item.offsetTop > reference) break;
        bestIndex = i;
      }
      reportVisiblePage(bestIndex);
    }
    function onScroll(): void {
      if (frame !== 0) return;
      frame = requestAnimationFrame(compute);
    }
    root.addEventListener("scroll", onScroll, { passive: true });
    compute();
    return () => {
      root.removeEventListener("scroll", onScroll);
      if (frame !== 0) cancelAnimationFrame(frame);
    };
  }, []);

  if (meta.handle === null || meta.pageCount === 0) {
    return null;
  }

  const scale = computeScale(
    meta.geometry,
    ui.zoom,
    container.width,
    container.height
  );
  const hasActiveSearch = ui.search.query.length > 0;

  return (
    <section
      ref={canvasRef}
      className={styles.canvas}
      aria-label="Rendered pages"
    >
      <ol className={styles.pageList} style={{ gap: `${PAGE_GAP}px` }}>
        {Array.from({ length: meta.pageCount }, (_, index) => {
          const geometry = meta.geometry.get(index) ?? {
            width: 612,
            height: 792,
            rotation: 0,
          };
          return (
            <PageItem
              key={index}
              pageIndex={index}
              geometry={geometry}
              scale={scale}
              hasActiveSearch={hasActiveSearch}
            />
          );
        })}
      </ol>
    </section>
  );
}

function computeScale(
  geometry: ReadonlyMap<number, PdfPageGeometry>,
  zoom: ZoomValue,
  containerWidth: number,
  containerHeight: number
): number {
  if (zoom.kind === "actual") return 1;
  if (zoom.kind === "custom") return zoom.scale;
  let maxWidth = 612;
  let maxHeight = 792;
  for (const g of geometry.values()) {
    if (g.width > maxWidth) maxWidth = g.width;
    if (g.height > maxHeight) maxHeight = g.height;
  }
  const horizontalPadding = 32;
  const verticalPadding = 32;
  if (zoom.kind === "fit-width") {
    if (containerWidth <= 0) return 1;
    return Math.max(0.1, (containerWidth - horizontalPadding) / maxWidth);
  }
  if (zoom.kind === "fit-page") {
    if (containerWidth <= 0) return 1;
    const widthScale = (containerWidth - horizontalPadding) / maxWidth;
    const measuredHeight = containerHeight > 0 ? containerHeight : 700;
    const heightScale = (measuredHeight - verticalPadding) / maxHeight;
    return Math.max(0.1, Math.min(widthScale, heightScale));
  }
  return 1;
}
