import { useEffect } from "react";
import { X } from "lucide-react";
import {
  requestCapabilityReport,
} from "../../store/viewer-store";
import { useDocumentMeta } from "../../store/use-viewer-store";
import styles from "./CapabilityReport.module.css";

interface CapabilityReportProps {
  onClose: () => void;
}

export function CapabilityReport({ onClose }: CapabilityReportProps) {
  const meta = useDocumentMeta();

  useEffect(() => {
    if (meta.handle !== null && meta.capabilityReport === null) {
      requestCapabilityReport();
    }
  }, [meta.handle, meta.capabilityReport]);

  useEffect(() => {
    function onKey(event: KeyboardEvent): void {
      if (event.key === "Escape") onClose();
    }
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [onClose]);

  const entries = meta.capabilityReport?.entries ?? [];

  return (
    <div className={styles.modalBackdrop} role="dialog" aria-modal>
      <div className={styles.modal}>
        <header className={styles.header}>
          <h2>PDF capability report</h2>
          <button
            type="button"
            className={styles.closeButton}
            aria-label="Close"
            onClick={onClose}
          >
            <X size={18} />
          </button>
        </header>
        <div className={styles.body}>
          {meta.handle === null ? (
            <p className={styles.empty}>Open a document first.</p>
          ) : entries.length === 0 ? (
            <p className={styles.empty}>Loading…</p>
          ) : (
            <ul className={styles.entries}>
              {entries.map((entry, idx) => (
                <li key={idx} className={styles.entry}>
                  <span className={badgeClass(entry.status)}>
                    {entry.status}
                  </span>
                  <span>
                    <div className={styles.featureName}>{entry.featureName}</div>
                    <div className={styles.category}>{entry.category}</div>
                  </span>
                  <p className={styles.description}>{entry.description}</p>
                </li>
              ))}
            </ul>
          )}
        </div>
      </div>
    </div>
  );
}

function badgeClass(status: string): string {
  switch (status) {
    case "supported":
      return `${styles.statusBadge} ${styles.statusSupported}`;
    case "partial":
      return `${styles.statusBadge} ${styles.statusPartial}`;
    case "unsupported":
      return `${styles.statusBadge} ${styles.statusUnsupported}`;
    default:
      return `${styles.statusBadge} ${styles.statusUnused}`;
  }
}
