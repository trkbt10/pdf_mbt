# interchange

## API

- **`PdfMetadataStream`** (Struct) — Valid metadata stream wrapper. `raw_stream` preserves the stream object
- **`PdfMetadataDateComparison`** (Enum) — Read-side comparison state for document information dates and metadata
- **`PdfDocumentInfo`** (Struct) — Raw-preserving document information dictionary view. Known text entries are
- **`PdfDocumentMetadataSources`** (Struct) — Aggregate metadata source summary for callers that want Catalog Metadata,
- **`MarkedContentProperty`** (Enum) — Normalized marked-content property list. Named properties preserve both the
- **`MarkedContentScope`** (Struct) — Marked-content point or sequence. Points use `begin_offset` as the operator
- **`PdfPagePieceData`** (Struct) — One producer/data-type entry in a Page-Piece dictionary. `Private` remains
- **`MarkedContentReport`** (Struct) — Structural marked-content analysis report preserving point and sequence
- **`PdfFileIdMatch`** (Enum) — Exact byte-comparison result for a current file identifier and a reference
- **`compare_file_identifier_bytes`** (Function) — Compares current and reference file identifiers by exact byte equality.
- **`PdfTrappedStatus`** (Enum) — Document information Trapped status. Absence is reported as `Unknown`.
- **`PdfPagePieceDictionary`** (Struct) — Validated Page-Piece dictionary preserving source order via `entries`.
- **`PdfProcedureSetName`** (Enum) — Predefined deprecated procedure set names from ISO 32000-2 Table 346.
- **`PdfMetadataSourceDiagnostics`** (Struct) — Metadata source presence and exact-byte date comparison diagnostics.
- **`compare_optional_file_identifier_bytes`** (Function) — Helper for callers whose current file identifier is optional.
- **`info_mod_date`** (Function) — 


- **`compare_optional_dates`** (Function) — 


- **`MarkedContentAnalyzerState`** (Struct) — 


- **`page_piece_dates_equal`** (Function) — 


- **`same_last_modified`** (Function) — 


- **`info_creation_date`** (Function) — 


- **`OpenMarkedContentScope`** (Struct) — 
- **`pdf_name`** (Function) —
