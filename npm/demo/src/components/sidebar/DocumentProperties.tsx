import { useDocumentMeta } from "../../store/use-viewer-store";
import { infoValue } from "../../lib/format";
import styles from "./Sidebar.module.css";

export function DocumentProperties() {
  const meta = useDocumentMeta();
  if (meta.handle === null) {
    return <p className={styles.empty}>No document loaded.</p>;
  }
  const info = meta.info;
  return (
    <div className={styles.properties}>
      <dl>
        <dt>File</dt>
        <dd>{infoValue(meta.name)}</dd>
        <dt>Title</dt>
        <dd>{infoValue(info?.title)}</dd>
        <dt>Author</dt>
        <dd>{infoValue(info?.author)}</dd>
        <dt>Subject</dt>
        <dd>{infoValue(info?.subject)}</dd>
        <dt>Creator</dt>
        <dd>{infoValue(info?.creator)}</dd>
        <dt>Pages</dt>
        <dd>{meta.pageCount}</dd>
        <dt>Version</dt>
        <dd>{infoValue(meta.version)}</dd>
      </dl>
    </div>
  );
}
