import { useEffect } from "react";
import { getSnapshot, navigateToPage, setUi } from "../store/viewer-store";
import { clamp } from "../lib/format";

// Single global keydown handler. Reads state via getSnapshot() so there are
// no stale closures and no useState in the effect body. All branches dispatch
// store actions — never call set*  directly.
export function useKeyboardShortcuts(): void {
  useEffect(() => {
    function onKeyDown(event: KeyboardEvent): void {
      const target = event.target as HTMLElement | null;
      const tag = target?.tagName;
      if (tag === "INPUT" || tag === "TEXTAREA" || target?.isContentEditable) {
        return;
      }
      const snap = getSnapshot();
      const max = Math.max(0, snap.document.pageCount - 1);
      switch (event.key) {
        case "ArrowDown":
        case "PageDown":
          event.preventDefault();
          navigateToPage(clamp(snap.ui.currentPage + 1, 0, max));
          return;
        case "ArrowUp":
        case "PageUp":
          event.preventDefault();
          navigateToPage(clamp(snap.ui.currentPage - 1, 0, max));
          return;
        case "Home":
          event.preventDefault();
          navigateToPage(0);
          return;
        case "End":
          event.preventDefault();
          navigateToPage(max);
          return;
        case "+":
        case "=":
          event.preventDefault();
          setUi({
            zoom: {
              kind: "custom",
              scale: clamp(snap.ui.zoom.scale + 0.1, 0.1, 4),
            },
          });
          return;
        case "-":
          event.preventDefault();
          setUi({
            zoom: {
              kind: "custom",
              scale: clamp(snap.ui.zoom.scale - 0.1, 0.1, 4),
            },
          });
          return;
        case "0":
          event.preventDefault();
          setUi({ zoom: { kind: "actual", scale: 1 } });
          return;
        case "1":
          event.preventDefault();
          setUi({ zoom: { kind: "fit-width", scale: 1 } });
          return;
        case "2":
          event.preventDefault();
          setUi({ zoom: { kind: "fit-page", scale: 1 } });
          return;
        case "Escape":
          if (snap.ui.search.query) {
            setUi({ search: { query: "" } });
          }
          return;
      }
    }
    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  }, []);
}
