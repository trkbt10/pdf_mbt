import styles from "./PageItem.module.css";

interface PagePlaceholderProps {
  pageIndex: number;
  status: "idle" | "loading" | "error";
  error?: string | null;
}

export function PagePlaceholder({ pageIndex, status, error }: PagePlaceholderProps) {
  if (status === "error") {
    return (
      <div
        className={styles.errorMessage}
        role="alert"
        aria-label={`Page ${pageIndex + 1} failed to render`}
      >
        {error ?? "Failed to render"}
      </div>
    );
  }
  return (
    <div
      className={styles.placeholder}
      aria-label={`Page ${pageIndex + 1} placeholder`}
    >
      {status === "loading" ? "Rendering…" : `Page ${pageIndex + 1}`}
    </div>
  );
}
