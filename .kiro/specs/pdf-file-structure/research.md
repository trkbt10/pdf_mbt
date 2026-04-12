# Research & Design Decisions

## Summary
- **Feature**: `pdf-file-structure`
- **Discovery Scope**: Complex Integration
- **Key Findings**:
  - The implemented `pdf-objects` packages already expose the required `PdfObject`, `ObjectId`, `PdfStream`, lexer markers, and indirect-object parser contracts. The reader can be added as a downstream package without changing the existing dependency direction.
  - ISO 32000-2 section 7.5 requires two independent cross-reference encodings: fixed-width traditional tables and stream dictionaries plus binary entries. Both must normalize into one index before lazy object loading.
  - Object streams and cross-reference streams require decoded stream bytes, but the current object layer intentionally stores encoded stream data. The design isolates this as a `StructuralStreamDecoder` boundary so file-structure logic does not absorb the later general filter subsystem.

## Research Log

### Existing Package Boundaries
- **Context**: The file reader depends on Phase 1 object, lexer, and parser behavior.
- **Sources Consulted**: `src/objects/pkg.generated.mbti`, `src/lexer/pkg.generated.mbti`, `src/parser/pkg.generated.mbti`, `.kiro/specs/pdf-objects/design.md`, `.kiro/specs/pdf-objects/tasks.md`.
- **Findings**:
  - `objects` owns `PdfObject`, `PdfName`, `PdfDictionary`, `PdfStream`, `ObjectId`, `IndirectObject`, typed accessors, and `PdfParseError`.
  - `lexer` exposes `ByteCursor`, `Lexer`, `PdfToken::HeaderMarker`, and `PdfToken::EofMarker`, but xref tables need raw fixed-width byte parsing rather than ordinary token parsing.
  - `parser` exposes `parse_object`, `parse_all_objects`, and `parse_indirect_object`, which are enough for trailer dictionaries, uncompressed indirect objects, and object-stream object slices.
- **Implications**:
  - Add `src/reader` as a downstream package importing `objects`, `lexer`, and `parser`.
  - Do not modify parser internals unless implementation discovers a consumed-offset contract gap. If that happens, revalidate `pdf-objects`.

### ISO 32000-2 File Structure Rules
- **Context**: Requirements reference local ISO excerpts for section 7.5 and Annex H examples.
- **Sources Consulted**: `spec/extracted/7.5-file-structure.md`, `spec/extracted/7.5-file-structure.spec.txt`, `spec/extracted/annex-h-examples.spec.txt`.
- **Findings**:
  - Header offsets are measured from the `%` byte of `%PDF-`, not necessarily from byte 0 of the physical buffer.
  - Readers are expected to locate the last `%%EOF`, read the preceding `startxref`, and follow the latest cross-reference section first.
  - Traditional xref entries are exactly 20 bytes and allow only `SP CR`, `SP LF`, or `CR LF` as the two-byte entry terminator.
  - Incremental updates create a chain through `Prev`; newer sections override older entries, and free entries remove objects from the resolved active map.
  - Hybrid-reference files use `XRefStm` between the current table and `Prev`.
- **Implications**:
  - The reader needs separate raw-byte parsers for the header, tail, xref table, and xref stream data, then a common merge model.
  - The merge algorithm must process sections in lookup priority order rather than physical file order.

### Bundled Sample PDFs
- **Context**: Requirement 10 names two bundled PDF 2.0 examples.
- **Sources Consulted**: `spec/pdf20examples/Simple PDF 2.0 file.pdf`, `spec/pdf20examples/PDF 2.0 via incremental save.pdf`, and byte-string scans of all bundled PDFs.
- **Findings**:
  - The named required samples use traditional `xref` tables, not `/XRef` streams or `/ObjStm` object streams.
  - `PDF 2.0 via incremental save.pdf` contains multiple `startxref` and `%%EOF` segments and a `Prev` trailer entry.
  - Some non-required bundled examples contain stream filters, but the required samples for this spec do not require general filter decoding.
- **Implications**:
  - The E2E validation focus for Requirement 10 is table parsing, trailer parsing, incremental merge, and object access.
  - Object stream and xref stream tests should use compact synthetic unfiltered fixtures until `pdf-filters` is available.

### Stream Decoding Boundary
- **Context**: Object streams and xref streams operate on decoded stream bytes, while Phase 1 explicitly stores encoded raw `PdfStream.data`.
- **Sources Consulted**: `.kiro/specs/pdf-objects/design.md`, `spec/extracted/7.4-filters.md`, `spec/extracted/7.5-file-structure.md`, `.kiro/steering/structure.md`.
- **Findings**:
  - The project roadmap places a `pdf-filters` phase after file structure.
  - General PDF filter decoding includes ASCII, LZW, Flate, image, and crypt-related filters and is too broad for this file-structure spec.
  - Cross-reference streams must not be decrypted, and `/Crypt` filters must not be silently accepted for structural xref decoding.
- **Implications**:
  - `reader` defines a `StructuralStreamDecoder` boundary for xref and object stream callers.
  - The initial decoder accepts unfiltered structural streams and rejects unsupported or encrypted filters with a reader error.
  - Adding `src/filters` later is a revalidation trigger for Requirements 6.2, 7.3, and 9.3.

## Architecture Pattern Evaluation

| Option | Description | Strengths | Risks / Limitations | Notes |
|--------|-------------|-----------|---------------------|-------|
| Layered reader package | Add `reader` downstream of `objects`, `lexer`, and `parser`; normalize all xref encodings into one index. | Matches steering direction, keeps object parsing reusable, enables independent reader tests. | Requires careful offset rebasing and stream decoding boundary. | Selected. |
| Extend parser package with file structure | Put header, xref, trailer, and object loading into `parser`. | Fewer packages. | Violates `objects <- lexer <- parser <- reader`, mixes direct object parsing with file-level lookup. | Rejected. |
| Full filter subsystem in reader | Implement all PDF standard stream filters inside file-structure work. | Would decode all structural streams immediately. | Duplicates the planned `pdf-filters` phase and expands this spec beyond section 7.5 ownership. | Rejected. |
| Eager whole-file object parse | Scan and parse all indirect objects before lookup. | Simple for small files. | Incorrect for incremental updates, ignores xref authority, defeats random access and lazy loading. | Rejected. |

## Design Decisions

### Decision: Normalize all xref formats into one index
- **Context**: Requirements 3, 5, 7, 8, and 9 all depend on resolving object IDs consistently.
- **Alternatives Considered**:
  1. Keep separate table, stream, and hybrid lookup paths.
  2. Convert each parsed section into a common `XrefEntry` model before merge.
- **Selected Approach**: Traditional table entries, xref stream entries, and hybrid `XRefStm` entries are converted into common free, uncompressed, and compressed entries, then merged by priority.
- **Rationale**: One index keeps lazy object loading independent of the original xref encoding.
- **Trade-offs**: The merge layer must preserve enough section metadata for diagnostics and trailer selection.
- **Follow-up**: Implementation tests must prove current table entries outrank `XRefStm`, which outranks `Prev`.

### Decision: Keep byte-base conversion centralized
- **Context**: Header parsing allows bytes before `%PDF-`, while xref offsets are measured from the `%` byte.
- **Alternatives Considered**:
  1. Store only physical byte indexes.
  2. Store only PDF-relative offsets.
  3. Store both the header base and PDF-relative offsets, converting at file access boundaries.
- **Selected Approach**: `PdfHeader.base_offset` is authoritative. Xref entries store PDF-relative offsets. `ByteSource` converts to physical indexes when slicing the input.
- **Rationale**: This matches ISO offset rules and keeps raw parsers from accidentally mixing coordinate systems.
- **Trade-offs**: Reader errors need explicit file offsets after conversion.
- **Follow-up**: Include tests for `PDF 2.0 with offset start.pdf` and synthetic prefixed files.

### Decision: Lazy loading with cache by `ObjectId`
- **Context**: The reader must provide random access and parse objects only when first accessed.
- **Alternatives Considered**:
  1. Parse every active object after opening the file.
  2. Store xref index only and parse on each request.
  3. Store xref index and memoize parsed objects.
- **Selected Approach**: `PdfFile::open` builds header, trailer, section chain, and merged xref index. `PdfFile::load_object` resolves and caches parsed objects by `ObjectId`.
- **Rationale**: This preserves random access, avoids work for unused objects, and prevents repeated object-stream decoding.
- **Trade-offs**: Cache mutation must stay encapsulated in the reader state.
- **Follow-up**: Tests should verify repeated loads return consistent values and do not require eager parsing.

### Decision: Decode structural streams through a narrow adapter
- **Context**: Xref streams and object streams need decoded data, but general filter decoding is a later spec.
- **Alternatives Considered**:
  1. Treat `PdfStream.data` as decoded.
  2. Implement general filter decoding here.
  3. Add a narrow structural decoder boundary and fail unsupported filters explicitly.
- **Selected Approach**: `StructuralStreamDecoder` returns decoded bytes for unfiltered structural streams and raises `UnsupportedFilter` for filtered or encrypted structural streams until the filter package is available.
- **Rationale**: This keeps file-structure contracts honest without hiding filter work inside xref parsing.
- **Trade-offs**: Filtered object streams and xref streams are not fully supported until the later filter integration.
- **Follow-up**: Revalidate Requirements 6.2, 7.3, and 9.3 when `pdf-filters` is introduced.

### Decision: Use parser slices for object-stream members
- **Context**: Objects inside object streams omit `obj` and `endobj`, and their offsets are relative to the first object byte in the decoded stream.
- **Alternatives Considered**:
  1. Reimplement direct object parsing inside reader.
  2. Slice each object range and call `parse_all_objects`, requiring exactly one object result.
- **Selected Approach**: Use the existing direct-object parser on exact object slices derived from the object stream header.
- **Rationale**: The object parser already owns all section 7.2 and 7.3 syntax. Exact slices avoid needing new parser cursor APIs.
- **Trade-offs**: If implementation needs consumed-offset diagnostics, parser API expansion becomes a revalidation trigger.
- **Follow-up**: Test adjacent object-stream objects with no whitespace between values.

## Risks & Mitigations
- Offset base mistakes can load the wrong object - Centralize conversion through `PdfHeader.base_offset` and test prefixed PDFs.
- Fixed-width xref table parsing can accidentally accept comments or variable-length rows - Parse table entries as raw 20-byte records, not lexer tokens.
- `Prev` chains can loop or point outside the buffer - Track visited section offsets and validate physical slice bounds.
- Hybrid-reference priority can be inverted - Model section traversal order explicitly and test current table, `XRefStm`, then `Prev`.
- Filtered structural streams are outside the current dependency set - Fail with explicit `UnsupportedFilter` and revalidate after `pdf-filters`.
- Object-stream recursion can allow stream objects inside object streams - Parse each compressed object as exactly one direct object and reject stream syntax or stream-valued results.

## References
- `spec/extracted/7.5-file-structure.md` - local ISO 32000-2 section 7.5 excerpt used for file header, xref, trailer, incremental update, object stream, xref stream, and hybrid-reference behavior.
- `spec/extracted/annex-h-examples.spec.txt` - local Annex H examples used for sample-file validation scope.
- `.kiro/specs/pdf-objects/design.md` - upstream object, lexer, parser boundary contracts.
- `.kiro/steering/product.md`, `.kiro/steering/tech.md`, `.kiro/steering/structure.md` - project goals, MoonBit toolchain rules, and package dependency direction.
