import { useEffectEvent, useRef } from "react";
import { useElementInView } from "../../hooks/use-element-in-view";
import { requestPageSvg, requestPageText } from "../../store/viewer-store";
import { useCurrentPage, usePage } from "../../store/use-viewer-store";
import type { PdfPageGeometry } from "@trkbt10/pdf-wasm";
import { PageSvgSurface } from "./PageSvgSurface";
import { PagePlaceholder } from "./PagePlaceholder";
import styles from "./PageItem.module.css";

interface PageItemProps {
  pageIndex: number;
  geometry: PdfPageGeometry;
  scale: number;
  hasActiveSearch: boolean;
}

export function PageItem({ pageIndex, geometry, scale, hasActiveSearch }: PageItemProps) {
  const itemRef = useRef<HTMLLIElement>(null);
  const page = usePage(pageIndex);
  const currentPage = useCurrentPage();

  // The 900px-margin preload observer triggers SVG/text fetch ahead of time.
  // Active-page tracking is handled by PageCanvas's scroll listener, not by
  // a separate IntersectionObserver — IO scheduling makes the toolbar lag.
  const onPreload = useEffectEvent((visible: boolean) => {
    if (!visible) return;
    if (page.svg.status === "idle") {
      requestPageSvg(pageIndex);
    }
    if (hasActiveSearch && page.text.status === "idle") {
      requestPageText(pageIndex);
    }
  });

  useElementInView(itemRef, "900px", onPreload);

  const width = geometry.width * scale;
  const className =
    currentPage === pageIndex
      ? `${styles.pageItem} ${styles.pageItemActive}`
      : styles.pageItem;

  // Intrinsic aspect ratio drives the height — the inner SVG fills the box,
  // so the page can never be cropped just because someone picked a wrong
  // pixel height.
  const aspect = `${geometry.width} / ${geometry.height}`;

  return (
    <li
      ref={itemRef}
      className={className}
      style={{ width: `${width}px`, aspectRatio: aspect }}
      data-pdf-page-item=""
      data-page-number={pageIndex + 1}
    >
      {page.svg.status === "ready" && page.svg.html ? (
        <PageSvgSurface
          pageIndex={pageIndex}
          html={page.svg.html}
          imageUrls={page.images}
        />
      ) : (
        <PagePlaceholder
          pageIndex={pageIndex}
          status={page.svg.status === "ready" ? "idle" : page.svg.status}
          error={page.svg.error}
        />
      )}
    </li>
  );
}
