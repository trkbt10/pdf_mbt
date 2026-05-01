import { useEffect } from "react";
import type { RefObject } from "react";
import { observeElement } from "../lib/intersection";

// Visibility hook with a callback API. State, if any, lives on the caller —
// usually wrapped in useEffectEvent. The effect itself depends only on (ref,
// rootMargin), so it fires once per mount and never on prop changes.
export function useElementInView<T extends Element>(
  ref: RefObject<T | null>,
  rootMargin: string,
  onChange: (visible: boolean) => void
): void {
  useEffect(() => {
    const element = ref.current;
    if (!element) return;
    return observeElement(element, rootMargin, (entry) => {
      onChange(entry.isIntersecting);
    });
    // onChange is intentionally omitted from deps — callers wrap it in
    // useEffectEvent so the latest closure is read without re-firing.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [ref, rootMargin]);
}
