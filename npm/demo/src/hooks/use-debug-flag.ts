// Reads `?debug=1` (or localStorage `pdf-demo-debug`) once at mount.
// Not reactive — the user reloads the page when toggling.
export function readDebugFlag(): boolean {
  if (typeof window === "undefined") return false;
  try {
    const params = new URLSearchParams(window.location.search);
    if (params.get("debug") === "1") return true;
    if (window.localStorage.getItem("pdf-demo-debug") === "1") return true;
  } catch {
    // SecurityError in some sandboxed contexts; fall through.
  }
  return false;
}
