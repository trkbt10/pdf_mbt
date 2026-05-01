import { setUi } from "../../store/viewer-store";
import { useUi } from "../../store/use-viewer-store";
import { ThumbnailList } from "./ThumbnailList";
import { DocumentProperties } from "./DocumentProperties";
import styles from "./Sidebar.module.css";

export function Sidebar() {
  const ui = useUi();

  if (!ui.sidebar.open) return null;

  return (
    <aside className={styles.sidebar} aria-label="Document sidebar">
      <div className={styles.tabs} role="tablist">
        <button
          type="button"
          role="tab"
          aria-selected={ui.sidebar.tab === "thumbnails"}
          className={
            ui.sidebar.tab === "thumbnails"
              ? `${styles.tab} ${styles.tabActive}`
              : styles.tab
          }
          onClick={() => setUi({ sidebar: { tab: "thumbnails" } })}
        >
          Thumbnails
        </button>
        <button
          type="button"
          role="tab"
          aria-selected={ui.sidebar.tab === "properties"}
          className={
            ui.sidebar.tab === "properties"
              ? `${styles.tab} ${styles.tabActive}`
              : styles.tab
          }
          onClick={() => setUi({ sidebar: { tab: "properties" } })}
        >
          Properties
        </button>
      </div>
      <div className={styles.body}>
        {ui.sidebar.tab === "thumbnails" ? (
          <ThumbnailList />
        ) : (
          <DocumentProperties />
        )}
      </div>
    </aside>
  );
}
