import { useLayoutEffect, useRef } from "react";
import { patchDeferredSvgImages } from "../../pdf-api/render-page";
import styles from "./PageItem.module.css";

interface PageSvgSurfaceProps {
  pageIndex: number;
  html: string;
  imageUrls: ReadonlyMap<number, string>;
}

// Hosts the wasm-rendered SVG via dangerouslySetInnerHTML and patches
// <image data-image-index> placeholders with their Blob URLs after each
// (re)mount. The effect body performs only DOM operations and never calls
// React state setters — the no-set-state-in-effect lint rule enforces this.
export function PageSvgSurface({
  pageIndex,
  html,
  imageUrls,
}: PageSvgSurfaceProps) {
  const surfaceRef = useRef<HTMLDivElement>(null);

  useLayoutEffect(() => {
    const surface = surfaceRef.current;
    if (!surface) return;
    return patchDeferredSvgImages(surface, imageUrls);
  }, [html, imageUrls, pageIndex]);

  return (
    <div
      ref={surfaceRef}
      className={styles.svgSurface}
      aria-label={`Rendered PDF page ${pageIndex + 1}`}
      data-pdf-page-svg=""
      dangerouslySetInnerHTML={{ __html: html }}
    />
  );
}
