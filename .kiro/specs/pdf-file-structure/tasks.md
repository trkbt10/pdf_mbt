# Implementation Plan

- [x] 1. Establish reader foundations
- [x] 1.1 Create the reader package boundary and toolchain baseline
  - Add the downstream reader package with imports only from the existing object, lexer, parser, and standard-library layers.
  - Keep the root library and CLI surface unchanged unless a later public API validation intentionally chooses a re-export.
  - The baseline is complete when the MoonBit toolchain discovers the reader package with no external dependencies and no reversed package imports.
  - _Requirements: 9.1, 9.4_

- [x] 1.2 Define reader metadata, object-location contracts, and diagnostics
  - Represent PDF versions, parsed headers, trailer metadata, cross-reference entries, object locations, section provenance, and opened-file state as typed reader values.
  - Report invalid headers, missing tail markers, invalid xref data, invalid trailers, unsupported filters, invalid object streams, invalid object locations, Prev cycles, and wrapped parser failures with relevant offsets.
  - The contracts are complete when white-box tests can construct representative metadata and assert stable reader error variants with PDF-relative or physical offsets where applicable.
  - _Requirements: 1.2, 1.3, 2.1, 2.3, 3.3, 3.7, 4.2, 6.6, 7.8, 9.5_

- [x] 1.3 Build byte-source offset conversion and slice safety
  - Own the input bytes and PDF-relative base offset for the lifetime of an opened file.
  - Convert every cross-reference offset through the header base, reject out-of-range slices, and preserve raw bytes without normalizing EOL or stream data.
  - The byte boundary is complete when tests show prefixed PDF data uses the `%PDF-` percent byte as offset zero and invalid offsets raise reader errors before slicing.
  - _Requirements: 1.5, 2.1, 2.4, 9.2_

- [x] 2. Read the file envelope
- [x] 2.1 (P) Parse the PDF header and binary indicator
  - Locate the `%PDF-` marker, extract accepted versions `1.0` through `1.7` and `2.0`, and require CR, LF, or CRLF immediately after the version digits.
  - Detect a following binary-indicator comment when it contains at least four high-bit bytes.
  - Header parsing is complete when tests accept every valid version, reject unsupported or unterminated headers, detect the high-bit indicator, and expose the correct offset base.
  - _Depends: 1.2, 1.3_
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5_
  - _Boundary: HeaderScanner_

- [x] 2.2 (P) Locate the latest startxref from the file tail
  - Search backward for the last `%%EOF` marker and ignore earlier EOF markers from incremental updates during initial discovery.
  - Locate the nearest preceding `startxref` keyword and parse the following decimal integer as the latest cross-reference offset.
  - Tail scanning is complete when tests cover multiple EOF markers, missing markers, invalid startxref integers, and offsets converted from the final marker context.
  - _Depends: 1.2, 1.3_
  - _Requirements: 2.1, 2.2, 2.3, 2.4_
  - _Boundary: TailScanner_

- [x] 3. Parse traditional xref sections and trailers
- [x] 3.1 Parse and validate trailer dictionaries
  - Convert the dictionary after a traditional trailer keyword or an xref stream dictionary into validated trailer metadata.
  - Validate direct `Size`, required `Root`, optional `Prev`, `Encrypt`, `Info`, `ID`, and `XRefStm`, including the PDF 2.0 file-identifier requirement.
  - Trailer parsing is complete when tests assert required entries, optional entries, raw dictionary preservation, and precise typing errors for malformed trailer fields.
  - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6, 4.7, 8.1_
  - _Boundary: TrailerParser_

- [x] 3.2 Parse traditional fixed-width cross-reference tables
  - Require the `xref` keyword at the section offset, parse subsection headers, and read every entry as exactly 20 bytes including the two-byte EOL form.
  - Extract in-use and free entries, accept the required EOL variants, validate object 0 when present, and support multiple subsections without allowing comments between `xref` and `trailer`.
  - Table parsing is complete when fixture tests produce entries plus trailer metadata for valid sections and offset-bearing errors for malformed rows or invalid object 0 data.
  - _Depends: 3.1_
  - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 3.8, 4.1_
  - _Boundary: XrefTableParser_

- [ ] 4. Parse stream-based reference sections and section chains
- [x] 4.1 (P) Provide the structural stream decoding boundary
  - Treat unfiltered structural streams as decoded bytes while keeping general PDF filter support outside this feature.
  - Reject encrypted, `/Crypt`-filtered, or otherwise unsupported structural streams with explicit reader errors.
  - The decoder boundary is complete when tests prove unfiltered xref and object streams pass through unchanged and unsupported filters fail before entry parsing.
  - _Depends: 1.2_
  - _Requirements: 6.2, 6.3, 7.3, 7.8, 9.3_
  - _Boundary: StructuralStreamDecoder_

- [x] 4.2 Parse cross-reference streams
  - Recognize indirect `/Type /XRef` streams at section offsets and validate required `Type`, `Size`, and `W` entries plus the optional `Index` default.
  - Decode multi-byte fields in big-endian order, support type 0, type 1, and type 2 entries, and default the entry type to in-use when `W[0]` is zero.
  - Xref stream parsing is complete when tests cover `W`, `Index`, big-endian decoding, type defaults, free entries, uncompressed entries, compressed entries, unsupported entry handling, and encrypted-stream rejection.
  - _Depends: 3.1, 4.1_
  - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5, 7.6, 7.7, 7.8_
  - _Boundary: XrefStreamParser_

- [x] 4.3 Traverse xref section chains with hybrid and Prev ordering
  - Dispatch a section offset to either a traditional table or an xref stream while preserving section provenance for merging.
  - For hybrid-reference files, read the current table first, then the `XRefStm` stream, then follow `Prev` offsets; track visited offsets to reject cycles.
  - Section traversal is complete when synthetic chains return sections in merge-priority order and cycle or out-of-bounds offsets produce reader errors.
  - _Depends: 2.2, 3.2, 4.2_
  - _Requirements: 2.3, 5.1, 8.1, 8.2_
  - _Boundary: XrefSectionReader_

- [ ] 5. Build active index and lazy object access
- [x] 5.1 (P) Merge section entries into the active cross-reference index
  - Apply latest-first priority, including current table entries before hybrid stream entries and both before `Prev` sections.
  - Keep the winning entry for each object and generation, remove active locations when the winning entry is free, ignore entries above the effective trailer `Size`, and produce compressed or uncompressed locations for active entries.
  - The index is complete when tests verify newer entries win, deleted objects disappear from lookup, entries beyond `Size - 1` are excluded, compressed entries retain their object-stream location, and the merged map reflects valid parsed sections.
  - _Depends: 4.3_
  - _Requirements: 4.2, 5.1, 5.2, 5.3, 5.4, 8.2, 9.1_
  - _Boundary: XrefMerger_

- [x] 5.2 Parse supplied object streams into member indexes
  - Given a resolved `/ObjStm` stream, validate direct non-negative `N` and `First`, decode the structural stream, and parse exactly `N` object-number and relative-offset pairs.
  - Extract generation-0 direct objects by supplied stream-member index, reject stream objects stored inside object streams, and return a cacheable member table for the caller.
  - Object stream parsing is complete when tests extract multiple members from one supplied stream, reject invalid indexes or stream members, and never assign non-zero generations to compressed objects.
  - _Depends: 4.1_
  - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5, 6.6, 9.3_
  - _Boundary: ObjectStreamReader_

- [x] 5.3 Load uncompressed and compressed objects on demand
  - Resolve requested object identifiers through the active index and return null for absent, deleted, or generation-mismatched references.
  - Parse uncompressed locations as indirect objects at the resolved byte offset, verify the parsed identifier, delegate compressed locations to object stream extraction, and cache loaded objects plus object-stream member tables.
  - Lazy loading is complete when tests show the first access parses and caches the object, repeated access reuses the cache, object identity mismatches raise reader errors, and missing references return null.
  - _Depends: 5.1, 5.2_
  - _Requirements: 6.5, 9.1, 9.2, 9.3, 9.4, 9.5_
  - _Boundary: ObjectLoader_

- [x] 5.4 Expose the opened file reader lifecycle
  - Coordinate header parsing, tail discovery, section-chain traversal, xref merge, latest trailer metadata, root reference access, and lazy object loading through the public file handle.
  - Keep file opening structural only: it builds the index without eagerly parsing every in-use indirect object and never falls back to heuristic body scans.
  - The public lifecycle is complete when a black-box test opens a minimal complete PDF, reads version and trailer data, loads an existing object, and receives null for a missing object.
  - _Depends: 2.1, 2.2, 4.3, 5.3_
  - _Requirements: 5.4, 9.1, 9.2, 9.3, 9.4, 9.5_
  - _Boundary: PdfFile_

- [ ] 6. Validate samples, robustness, and public surface
- [x] 6.1 Validate synthetic traditional and incremental file flows
  - Open a synthetic minimal traditional-table PDF and load Catalog, Pages, Page, content stream, and metadata objects by identifier.
  - Open a synthetic incremental-update PDF with multiple sections and verify later entries win while deleted objects resolve to null.
  - The flow is complete when public API tests pass without document-structure interpretation and all resolved objects match the expected latest xref entries.
  - _Depends: 5.4_
  - _Requirements: 5.1, 5.2, 5.3, 5.4, 9.1, 9.2, 9.5_

- [x] 6.2 Validate synthetic hybrid-reference and object-stream flows
  - Open a hybrid-reference fixture and verify lookup priority is current table, then `XRefStm`, then `Prev` sections.
  - Load a synthetic unfiltered object stream containing multiple direct objects and verify invalid compressed stream members raise object-stream errors.
  - The flow is complete when hybrid and compressed-object tests pass through the public reader API and exercise both table and stream reference sources.
  - _Depends: 5.4_
  - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5, 6.6, 8.1, 8.2, 9.3_

- [x] 6.3 Prepare and validate Annex H examples through public API
  - Build or normalize test fixtures from the Annex H.2 and H.3 extracted examples so byte offsets, xref data, and trailers are consistent inputs for the reader.
  - Parse the Annex H.2 fixture and access all listed indirect objects, including Catalog, Pages, Page, Content stream, and Metadata; parse the Annex H.3 fixture and access font resources plus content stream objects without interpreting content operators.
  - Annex validation is complete when the public reader loads every required indirect object from both prepared fixtures and leaves document semantics to later layers.
  - _Depends: 5.4_
  - _Requirements: 10.1, 10.2_

- [x] 6.4 Validate bundled PDF 2.0 example files
  - Parse `spec/pdf20examples/Simple PDF 2.0 file.pdf` and load all in-use indirect objects reachable from its cross-reference data.
  - Parse `spec/pdf20examples/PDF 2.0 via incremental save.pdf`, follow incremental updates, and resolve modified objects to their latest versions.
  - Bundled validation is complete when both example files pass through the public reader API with expected object counts and latest-version resolution.
  - _Depends: 5.4_
  - _Requirements: 5.1, 5.2, 10.3, 10.4_

- [x] 6.5 Complete malformed-structure robustness coverage
  - Exercise malformed headers, tails, xref rows, trailer fields, stream filters, object stream headers, out-of-bounds offsets, and parser-error wrapping with representative tests.
  - Verify each failure reports the intended reader error category and relevant offset without scanning heuristics or swallowing parser context.
  - Robustness coverage is complete when the malformed fixture suite passes and each design error category is asserted at least once.
  - _Depends: 6.1, 6.2_
  - _Requirements: 1.2, 1.3, 2.1, 2.3, 3.3, 3.7, 4.2, 6.6, 7.8, 9.5_

- [x] 6.6 Validate lazy-loading and xref performance boundaries
  - Verify opening a file builds xref and trailer state without parsing every in-use object and repeated object loads use memoized results.
  - Verify large fixed-width xref tables are processed in linear time with bounds-checked reads and object streams are decoded once per container object.
  - Performance validation is complete when tests or lightweight benchmarks demonstrate lazy parsing, cache reuse, and linear xref-table behavior within the reader package.
  - _Depends: 5.4_
  - _Requirements: 3.3, 9.1, 9.3, 9.4_

- [x] 6.7 Complete formatting, checking, testing, and public API validation
  - Run the standard MoonBit validation sequence and review the generated public interface so only intentional reader APIs are exposed.
  - Confirm the final package graph still uses only allowed dependencies and keeps file-structure responsibilities out of lower parser packages.
  - Final validation is complete when formatting, checking, testing, and interface generation all pass with no external dependency additions or unexpected public surface changes.
  - _Depends: 6.3, 6.4, 6.5, 6.6_
  - _Requirements: 9.4, 10.1, 10.2, 10.3, 10.4_
