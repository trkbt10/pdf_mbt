import { usePageCount } from "../../store/use-viewer-store";
import { ThumbnailItem } from "./ThumbnailItem";
import styles from "./Sidebar.module.css";

export function ThumbnailList() {
  const pageCount = usePageCount();
  if (pageCount === 0) {
    return <p className={styles.empty}>No document loaded.</p>;
  }
  return (
    <ol className={styles.thumbList} aria-label="Page thumbnails">
      {Array.from({ length: pageCount }, (_, i) => (
        <ThumbnailItem key={i} pageIndex={i} />
      ))}
    </ol>
  );
}
