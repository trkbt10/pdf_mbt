# Implementation Plan

- [ ] 1. Establish common-data package foundation
- [ ] 1.1 Create the common-data package boundary and dependency manifest
  - Add a standalone package for ISO 32000-2 clause 7.9 interpretation that depends only on parsed PDF objects and the standard library.
  - Keep document-hierarchy interpretation separate from low-level parsing, stream filtering, reader traversal, and content-stream operand handling.
  - Completion is observable when the package participates in `moon check` without external dependencies or reverse dependencies from lower layers.
  - _Requirements: 0.1_
  - _Boundary: CommonDataValueModel_

- [ ] 1.2 Define shared common-data values and diagnostics
  - Represent raw source bytes alongside decoded text, date fields, rectangle coordinates, language escape metadata, and tree entries.
  - Provide diagnostics that distinguish invalid strings, dates, rectangles, and tree nodes while avoiding full arbitrary byte dumps.
  - Completion is observable when smoke tests can construct representative values and diagnostics and `moon check` accepts the shared model.
  - _Requirements: 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 0.10, 0.11_
  - _Boundary: CommonDataValueModel_

- [ ] 2. Implement common string qualifications
- [ ] 2.1 Build PDFDocEncoding byte decoding
  - Add the deterministic single-byte mapping needed for document-hierarchy text strings without locale or content-stream behavior.
  - Reject undefined or malformed byte values through common-data diagnostics.
  - Completion is observable when PDFDocEncoded input bytes decode consistently and invalid byte values fail with the string diagnostic category.
  - _Requirements: 0.3, 0.5_
  - _Boundary: TextStringCodec_

- [ ] 2.2 Classify and decode text strings
  - Select UTF-16BE only from the required leading BOM, UTF-8 only from the required leading BOM, and PDFDocEncoding otherwise.
  - Decode supplementary Unicode characters correctly and fail fast on malformed UTF input.
  - Completion is observable when text-string parsing returns decoded text, selected encoding, and original bytes for every supported encoding.
  - _Requirements: 0.2, 0.3, 0.5_
  - _Boundary: TextStringCodec_

- [ ] 2.3 Scan Unicode language escape sequences
  - Recognize ESC language spans in decoded Unicode text for both UTF-16BE and UTF-8 inputs without registry validation.
  - Preserve language and optional country code metadata without changing the decoded text bytes or applying language negotiation.
  - Completion is observable when valid escape spans are exposed and malformed escape sequences raise text-string diagnostics.
  - _Requirements: 0.4_
  - _Boundary: TextStringCodec_

- [ ] 2.4 Validate ASCII strings, byte strings, and text stream bytes
  - Accept only 7-bit bytes for ASCII strings and preserve arbitrary 8-bit payloads for byte strings without character assumptions.
  - Validate unencoded text stream bytes with the same byte-order and lead-byte rules as text strings.
  - Completion is observable when byte strings round-trip raw bytes, ASCII strings reject high-bit bytes, and text stream bytes follow text-string decoding results.
  - _Requirements: 0.2, 0.6, 0.7_
  - _Boundary: TextStringCodec_

- [ ] 2.5 Add focused common-data string tests
  - Cover PDFDocEncoding, UTF-16BE BOM, UTF-8 BOM, supplementary characters, malformed encodings, ASCII rejection, byte-string preservation, text streams, and language escapes.
  - Include at least one large text-string case to exercise linear processing expectations.
  - Completion is observable when targeted common-data string tests pass and demonstrate no content-stream operand interpretation.
  - _Requirements: 0.2, 0.3, 0.4, 0.5, 0.6, 0.7_
  - _Boundary: TextStringCodec_

- [ ] 3. Implement non-string common-data parsers
- [ ] 3.1 Build PDF date parsing
  - Require the `D:` prefix and year field, enforce optional field ordering, apply specified defaults, and reject whitespace.
  - Parse `+`, `-`, `Z`, omitted time-zone information, and accepted legacy apostrophe forms without converting to system time.
  - Completion is observable when parsed dates retain raw bytes and expose range-checked defaulted fields and UTC relationship metadata.
  - _Depends: 2.2, 2.4_
  - _Requirements: 0.8_
  - _Boundary: DateParser_

- [ ] 3.2 (P) Build rectangle validation
  - Require direct arrays of exactly four numeric values and preserve lower-left and upper-right coordinate order.
  - Allow zero width and zero height without normalization, clipping, reordering, or coordinate transformation.
  - Completion is observable when valid integer and real rectangles produce typed coordinates and malformed arrays raise rectangle diagnostics.
  - _Depends: 1.2_
  - _Requirements: 0.9_
  - _Boundary: RectangleParser_

- [ ] 3.3 (P) Build tree key and pair-array validation
  - Compare name-tree keys byte by byte with prefix ordering and number-tree keys by integer order.
  - Validate pair-array arity, key object types, local duplicate keys, descending keys, and name-tree limits.
  - Completion is observable when valid pair arrays and limits return validated raw-object entries while malformed direct tree node data raises tree diagnostics.
  - _Depends: 1.2_
  - _Requirements: 0.10, 0.11_
  - _Boundary: TreeCore_

- [ ] 3.4 Add focused parser tests for dates, rectangles, and tree core
  - Cover date prefixes, defaults, offsets, legacy apostrophes, range checks, and whitespace rejection.
  - Cover rectangle arity, numeric conversion, source order, zero width, and zero height.
  - Cover name-key byte ordering, number-key ordering, pair-array shape, duplicate rejection, descending rejection, and limits validation.
  - Completion is observable when targeted common-data parser tests pass for all non-string value parsers.
  - _Depends: 3.1, 3.2, 3.3_
  - _Requirements: 0.8, 0.9, 0.10, 0.11_
  - _Boundary: DateParser, RectangleParser, TreeCore_

- [ ] 4. Integrate common data into reader-owned traversal and facades
- [ ] 4.1 Add reader error mapping and compatibility bridge
  - Convert common-data failures into reader-facing document errors with existing owner or key context.
  - Preserve existing reader-facing rectangle and tree entry contracts unless generated interface review confirms an intentional compatible alias.
  - Completion is observable when reader callers can receive common-data validation failures without importing the common-data package directly.
  - _Depends: 3.1, 3.2_
  - _Requirements: 0.1, 0.8, 0.9_
  - _Boundary: ReaderCommonDataBridge_

- [ ] 4.2 Adopt common validation in reader document-hierarchy value helpers
  - Delegate rectangle and relevant document-hierarchy string or date checks through the reader bridge while preserving source-compatible public reader results.
  - Keep indirect object resolution and diagnostic ownership in reader code rather than common-data code.
  - Completion is observable when existing reader value accessors still compile and stricter 7.9 validation appears only at document-hierarchy boundaries.
  - _Depends: 4.1_
  - _Requirements: 0.1, 0.2, 0.8, 0.9_
  - _Boundary: ReaderCommonDataBridge_

- [ ] 4.3 (P) Establish name-tree node shape and traversal safety
  - Enforce root `Kids` versus `Names` exclusivity, indirect child references, non-root limits, and visited-object cycle detection.
  - Keep object loading and missing-object behavior in reader traversal while using common-data validation for direct node entries.
  - Completion is observable when malformed name-tree node shapes and indirect cycles produce deterministic reader errors before lookup or enumeration returns entries.
  - _Depends: 3.3, 4.1_
  - _Requirements: 0.10_
  - _Boundary: NameTreeTraversal_

- [ ] 4.4 Complete name-tree lookup and enumeration semantics
  - Apply byte-wise key order, limits pruning, non-overlapping child ranges, duplicate rejection, and exact byte-key lookup.
  - Preserve raw object values without semantic interpretation of the associated values.
  - Completion is observable when lookups prune excluded branches and enumeration returns ordered raw entries for valid trees.
  - _Depends: 4.3_
  - _Requirements: 0.10_
  - _Boundary: NameTreeTraversal_

- [ ] 4.5 (P) Establish number-tree node shape and traversal safety
  - Enforce root `Kids` versus `Nums` exclusivity, indirect child references, malformed direct pair rejection, and visited-object cycle detection.
  - Keep object loading and missing-object behavior in reader traversal while using common-data validation for direct node entries.
  - Completion is observable when malformed number-tree node shapes and indirect cycles produce deterministic reader errors before enumeration returns entries.
  - _Depends: 3.3, 4.1_
  - _Requirements: 0.11_
  - _Boundary: NumberTreeTraversal_

- [ ] 4.6 Complete number-tree ordering, enumeration, and lookup semantics
  - Apply ascending integer key order, duplicate rejection, ordered enumeration, and less-than-or-equal lookup behavior needed by page label consumers.
  - Preserve raw object values and avoid consumer-specific interpretation in the generic traversal helper.
  - Completion is observable when number-tree enumeration returns ascending entries and PageLabels continues to resolve labels through the hardened helper.
  - _Depends: 4.5_
  - _Requirements: 0.11_
  - _Boundary: NumberTreeTraversal_

- [ ] 4.7 Add reader integration tests
  - Cover common-data error mapping, rectangle compatibility, invalid root shapes, invalid child references, limits pruning, exact byte lookups, non-overlapping ranges, cycle detection, sorted number keys, malformed number pairs, and page-label lookup behavior.
  - Include regression coverage that existing public reader model names and raw tree values remain available.
  - Completion is observable when targeted reader tests pass and generated reader interface changes are limited to intentional additions.
  - _Depends: 4.2, 4.4, 4.6_
  - _Requirements: 0.1, 0.8, 0.9, 0.10, 0.11_
  - _Boundary: ReaderCommonDataBridge, NameTreeTraversal, NumberTreeTraversal_

- [ ] 5. Adopt common validation at downstream document-object boundaries
- [ ] 5.1 Apply text and date validation to interchange-owned document metadata
  - Validate document information and page-piece date or text values only where interchange already owns public validation behavior.
  - Preserve exact metadata bytes and leave XML metadata parsing outside this feature.
  - Completion is observable when interchange validation reports common-data failures through existing interchange errors while raw bytes remain accessible.
  - _Depends: 4.7_
  - _Requirements: 0.2, 0.8_
  - _Boundary: InterchangeCommonDataAdoption_

- [ ] 5.2 Apply rectangle validation to graphics document-object bounding boxes
  - Reuse common rectangle validation for document-object bounding boxes while converting results to existing graphics geometry values.
  - Keep content-stream rectangle operators and rendering behavior unaffected.
  - Completion is observable when graphics validation accepts the same valid bounding boxes, rejects malformed arrays consistently, and still returns existing graphics rectangle values.
  - _Depends: 4.7_
  - _Requirements: 0.9_
  - _Boundary: GraphicsCommonDataAdoption_

- [ ] 5.3 Add cross-package isolation tests
  - Cover interchange byte preservation, graphics bounding-box compatibility, and content-stream string or rectangle behavior remaining independent of common-data document semantics.
  - Include a regression case that demonstrates 7.9 text-string rules are not applied to content-stream string operands.
  - Completion is observable when targeted interchange, graphics, and content tests pass without introducing a dependency from content to common-data.
  - _Depends: 5.1, 5.2_
  - _Requirements: 0.1, 0.2, 0.7, 0.8, 0.9_
  - _Boundary: InterchangeCommonDataAdoption, GraphicsCommonDataAdoption, Content streams_

- [ ] 6. Validate the complete feature and public API surface
- [ ] 6.1 Run focused package validation
  - Run common-data, reader, interchange, graphics, and content test scopes that cover all implemented clause 7.9 behaviors and boundary exclusions.
  - Confirm malformed UTF, date, rectangle, tree, and cyclic-indirect-object cases fail deterministically without unbounded recursion or out-of-bounds access.
  - Completion is observable when all targeted package tests pass on the current workspace.
  - _Depends: 5.3_
  - _Requirements: 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 0.10, 0.11_
  - _Boundary: Validation_

- [ ] 6.2 Run project-wide build, formatting, and interface review
  - Run the project check, formatter, and interface generation commands required by steering and inspect generated public API diffs.
  - Confirm lower-layer packages do not import reader or downstream packages and that only intended generated interfaces change.
  - Completion is observable when project-wide validation succeeds and generated interface files reflect only the planned common-data additions and compatibility-preserving reader updates.
  - _Depends: 6.1_
  - _Requirements: 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 0.10, 0.11_
  - _Boundary: Validation_
