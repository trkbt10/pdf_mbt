import { FileUp } from "lucide-react";
import styles from "./EmptyState.module.css";

export function EmptyState() {
  return (
    <div className={styles.empty} role="status" aria-label="No document loaded">
      <FileUp size={48} aria-hidden />
      <h2>Open a PDF</h2>
      <p>Drop a PDF file here or click Open in the toolbar.</p>
    </div>
  );
}
