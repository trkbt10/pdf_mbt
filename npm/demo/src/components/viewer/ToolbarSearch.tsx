import { useEffect, useId, useRef } from "react";
import { Search, X } from "lucide-react";
import { runSearch, setUi } from "../../store/viewer-store";
import { useSearch } from "../../store/use-viewer-store";
import searchStyles from "./ToolbarSearch.module.css";

const DEBOUNCE_MS = 200;

export function ToolbarSearch() {
  const search = useSearch();
  const inputId = useId();
  const inputRef = useRef<HTMLInputElement>(null);
  const debounceRef = useRef<number | null>(null);

  useEffect(() => {
    function onShortcut(event: KeyboardEvent): void {
      if ((event.metaKey || event.ctrlKey) && event.key === "f") {
        event.preventDefault();
        inputRef.current?.focus();
        inputRef.current?.select();
      }
    }
    window.addEventListener("keydown", onShortcut);
    return () => window.removeEventListener("keydown", onShortcut);
  }, []);

  function handleQueryChange(event: React.ChangeEvent<HTMLInputElement>): void {
    const value = event.currentTarget.value;
    // Optimistic UI: store the typed value immediately so the input echoes,
    // but debounce the actual heavy search.
    setUi({ search: { query: value } });
    if (debounceRef.current !== null) {
      window.clearTimeout(debounceRef.current);
    }
    debounceRef.current = window.setTimeout(() => {
      debounceRef.current = null;
      runSearch(value);
    }, DEBOUNCE_MS);
  }

  function handleClear(): void {
    if (debounceRef.current !== null) {
      window.clearTimeout(debounceRef.current);
      debounceRef.current = null;
    }
    runSearch("");
    inputRef.current?.focus();
  }

  function handleNavigate(direction: 1 | -1): void {
    if (search.matches.length === 0) return;
    const next =
      (search.activeMatchIndex + direction + search.matches.length) %
      search.matches.length;
    setUi({ search: { activeMatchIndex: next } });
  }

  const total = search.matches.length;
  const indicator =
    search.status === "loading"
      ? "Searching…"
      : total === 0
        ? search.query.length > 0
          ? "0 results"
          : ""
        : `${search.activeMatchIndex + 1} / ${total}`;

  return (
    <label className={searchStyles.searchBox} htmlFor={inputId}>
      <Search size={14} aria-hidden />
      <input
        ref={inputRef}
        id={inputId}
        type="search"
        placeholder="Search"
        value={search.query}
        onChange={handleQueryChange}
        onKeyDown={(event) => {
          if (event.key === "Enter") {
            event.preventDefault();
            handleNavigate(event.shiftKey ? -1 : 1);
          }
        }}
        aria-label="Search document text"
      />
      {indicator && <span className={searchStyles.indicator}>{indicator}</span>}
      {search.query && (
        <button
          type="button"
          className={searchStyles.clearButton}
          onClick={handleClear}
          aria-label="Clear search"
        >
          <X size={14} />
        </button>
      )}
    </label>
  );
}
