# Project Overview

trkbt10/pdf is a pure MoonBit implementation of ISO 32000-2 (PDF 2.0). It provides a layered read-side pipeline from raw bytes to structured document access, graphics interpretation, and text extraction.

## Design Principles

- **ISO clause traceability**: Every type and function cites its ISO 32000-2 section. `PdfObject` maps to §7.3, `PdfFile::open` implements §7.5.5, `GraphicsInterpreter` covers clauses 8-11.
- **Pure MoonBit**: No C FFI. DEFLATE, LZW, AES, RC4, MD5, SHA-2 are all implemented natively.
- **Layered dependencies**: lexer → parser → reader → content → graphics/text → rendering. Each layer depends only on the layers below.

## Pipeline

```
Bytes → Lexer (PdfToken) → Parser (PdfObject) → Reader (PdfFile, xref, trailer)
  → Content (ContentInstruction) → Graphics (GraphicsEvent) / Text (TextSpan)
```

## Entry Points

- `PdfFile::open(bytes)` — reverse-parse from %%EOF, resolve xref chain, build object cache
- `PdfDocument::from_file(file)` — load Catalog, page tree, metadata
- `interpret_content(stream, resources, state)` — graphics state machine
- `interpret_text(stream, resources, initial)` — text extraction

## See Also

- wiki://object-model
- wiki://file-reading
- wiki://content-streams
- wiki://graphics
- wiki://text-extraction
- wiki://cryptography
