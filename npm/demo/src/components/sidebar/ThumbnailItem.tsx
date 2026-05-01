import { useEffectEvent, useRef } from "react";
import type { PdfPageGeometry } from "@trkbt10/pdf-wasm";
import { useElementInView } from "../../hooks/use-element-in-view";
import { navigateToPage, requestPageSvg } from "../../store/viewer-store";
import {
  useCurrentPage,
  useDocumentMeta,
  usePage,
} from "../../store/use-viewer-store";
import { PageSvgSurface } from "../viewer/PageSvgSurface";
import styles from "./Sidebar.module.css";

interface ThumbnailItemProps {
  pageIndex: number;
}

const THUMB_WIDTH = 180;

export function ThumbnailItem({ pageIndex }: ThumbnailItemProps) {
  const itemRef = useRef<HTMLLIElement>(null);
  const meta = useDocumentMeta();
  const page = usePage(pageIndex);
  const currentPage = useCurrentPage();

  // When the thumbnail enters view, request the page's SVG. The same render
  // is cached and reused by the main canvas, so we never call
  // pageToSvgDeferred twice per page.
  const onVisibility = useEffectEvent((visible: boolean) => {
    if (visible && page.svg.status === "idle") {
      requestPageSvg(pageIndex);
    }
  });

  useElementInView(itemRef, "200px", onVisibility);

  function handleClick(): void {
    navigateToPage(pageIndex);
  }

  const className =
    pageIndex === currentPage
      ? `${styles.thumbItem} ${styles.thumbItemActive}`
      : styles.thumbItem;

  const geometry = meta.geometry.get(pageIndex);

  return (
    <li
      ref={itemRef}
      className={className}
      data-pdf-thumbnail-item=""
      data-page-number={pageIndex + 1}
    >
      <button
        type="button"
        className={styles.thumbButton}
        onClick={handleClick}
        aria-label={`Go to page ${pageIndex + 1}`}
      >
        <ThumbnailFrame
          pageIndex={pageIndex}
          geometry={geometry}
          html={page.svg.status === "ready" ? page.svg.html : null}
          imageUrls={page.images}
        />
      </button>
      <span className={styles.thumbLabel}>Page {pageIndex + 1}</span>
    </li>
  );
}

function ThumbnailFrame({
  pageIndex,
  geometry,
  html,
  imageUrls,
}: {
  pageIndex: number;
  geometry: PdfPageGeometry | undefined;
  html: string | null;
  imageUrls: ReadonlyMap<number, string>;
}) {
  const aspect = geometry
    ? `${geometry.width} / ${geometry.height}`
    : "612 / 792";
  return (
    <div
      className={styles.thumbFrame}
      style={{ width: `${THUMB_WIDTH}px`, aspectRatio: aspect }}
    >
      {html ? (
        <PageSvgSurface
          pageIndex={pageIndex}
          html={html}
          imageUrls={imageUrls}
        />
      ) : null}
    </div>
  );
}
