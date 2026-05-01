// Per-rootMargin shared IntersectionObserver factory. We don't share a single
// global observer because rootMargin can't be changed after creation; instead
// we cache one observer per (rootMargin) string to avoid creating dozens of
// observers when many PageItems mount simultaneously.

type Callback = (entry: IntersectionObserverEntry) => void;

interface ObserverEntry {
  observer: IntersectionObserver;
  callbacks: WeakMap<Element, Callback>;
}

const observers = new Map<string, ObserverEntry>();

function ensureObserver(rootMargin: string): ObserverEntry {
  const cached = observers.get(rootMargin);
  if (cached) {
    return cached;
  }
  const callbacks = new WeakMap<Element, Callback>();
  const observer = new IntersectionObserver(
    (entries) => {
      for (const entry of entries) {
        const cb = callbacks.get(entry.target);
        if (cb) {
          cb(entry);
        }
      }
    },
    { rootMargin }
  );
  const entry: ObserverEntry = { observer, callbacks };
  observers.set(rootMargin, entry);
  return entry;
}

export function observeElement(
  element: Element,
  rootMargin: string,
  callback: Callback
): () => void {
  if (typeof IntersectionObserver === "undefined") {
    callback({ isIntersecting: true } as IntersectionObserverEntry);
    return () => {};
  }
  const entry = ensureObserver(rootMargin);
  entry.callbacks.set(element, callback);
  entry.observer.observe(element);
  return () => {
    entry.observer.unobserve(element);
    entry.callbacks.delete(element);
  };
}
