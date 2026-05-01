import { useState } from "react";
import { useKeyboardShortcuts } from "../../hooks/use-keyboard-shortcuts";
import { useDocumentMeta, useUi } from "../../store/use-viewer-store";
import { CapabilityReport } from "../debug/CapabilityReport";
import { DropZone } from "../empty/DropZone";
import { EmptyState } from "../empty/EmptyState";
import { Sidebar } from "../sidebar/Sidebar";
import { Toolbar } from "./Toolbar";
import { PageCanvas } from "./PageCanvas";
import styles from "./PdfViewer.module.css";

interface PdfViewerProps {
  debugEnabled: boolean;
}

export function PdfViewer({ debugEnabled }: PdfViewerProps) {
  const [debugOpen, setDebugOpen] = useState(false);
  const meta = useDocumentMeta();
  const ui = useUi();

  useKeyboardShortcuts();

  const hasDocument = meta.handle !== null;
  const bodyClass = ui.sidebar.open
    ? styles.body
    : `${styles.body} ${styles.bodyWithoutSidebar}`;

  return (
    <div className={styles.shell}>
      <Toolbar debugEnabled={debugEnabled} onOpenDebug={() => setDebugOpen(true)} />
      <DropZone
        className={bodyClass}
        activeClassName={styles.dropZoneOverlayActive}
      >
        {hasDocument ? (
          <>
            <Sidebar />
            <PageCanvas />
          </>
        ) : (
          <EmptyState />
        )}
      </DropZone>
      {debugOpen && debugEnabled && (
        <CapabilityReport onClose={() => setDebugOpen(false)} />
      )}
    </div>
  );
}
