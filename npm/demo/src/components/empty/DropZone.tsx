import { useState } from "react";
import { openDocument } from "../../store/viewer-store";
import { errorMessage, firstPdfFile } from "../../lib/format";

interface DropZoneProps {
  className?: string;
  activeClassName?: string;
  children?: React.ReactNode;
}

export function DropZone({ className, activeClassName, children }: DropZoneProps) {
  const [active, setActive] = useState(false);

  function handleDragOver(event: React.DragEvent<HTMLDivElement>): void {
    event.preventDefault();
    setActive(true);
  }
  function handleDragLeave(): void {
    setActive(false);
  }
  function handleDrop(event: React.DragEvent<HTMLDivElement>): void {
    event.preventDefault();
    setActive(false);
    const file = firstPdfFile(event.dataTransfer.files);
    if (!file) return;
    void (async () => {
      try {
        const buf = await file.arrayBuffer();
        await openDocument(new Uint8Array(buf), file.name);
      } catch (error) {
        console.warn("pdf-demo: drop open failed", errorMessage(error));
      }
    })();
  }

  const composed =
    active && activeClassName
      ? `${className ?? ""} ${activeClassName}`.trim()
      : (className ?? "");

  return (
    <div
      className={composed}
      onDragOver={handleDragOver}
      onDragLeave={handleDragLeave}
      onDrop={handleDrop}
      data-pdf-drop-zone=""
    >
      {children}
    </div>
  );
}
