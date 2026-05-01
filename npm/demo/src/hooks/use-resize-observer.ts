import { useEffect } from "react";
import type { RefObject } from "react";

export function useResizeObserver<T extends Element>(
  ref: RefObject<T | null>,
  onChange: (rect: DOMRectReadOnly) => void
): void {
  useEffect(() => {
    const element = ref.current;
    if (!element) return;
    if (typeof ResizeObserver === "undefined") {
      onChange(element.getBoundingClientRect());
      return;
    }
    const observer = new ResizeObserver((entries) => {
      const entry = entries[0];
      if (entry) onChange(entry.contentRect);
    });
    observer.observe(element);
    return () => observer.disconnect();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [ref]);
}
