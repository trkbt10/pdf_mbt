# Implementation Plan

- [ ] 1. Establish interchange package foundations
- [ ] 1.1 Create shared interchange package boundary and diagnostics
  - Add the shared package manifest with only the allowed dependencies on object values, stream filters, and parsed content.
  - Introduce component-specific diagnostics for malformed metadata, document information, file identifiers, page-piece data, procedure sets, marked content, and wrapped filter or content failures.
  - Keep the shared package independent of reader and graphics ownership to avoid dependency cycles.
  - Done when the package builds and diagnostics can identify owner object context when available.
  - _Requirements: 1, 2.1, 2.2, 2.3, 3, 4, 4.1, 4.2_
  - _Boundary: InterchangeValueModel_

- [ ] 1.2 Define raw-preserving interchange value models
  - Represent metadata streams, document information, source diagnostics, file-id match results, page-piece entries, procedure-set names, and marked-content reports as inspectable read-side values.
  - Preserve raw streams, dictionaries, names, byte strings, objects, and offsets for future consumers.
  - Exclude writer mutation, XML semantic parsing, logical structure, Tagged PDF, associated files, and rendering semantics from these values.
  - Done when public interface review exposes all shared models without reader or graphics ownership.
  - _Requirements: 1, 2.1, 2.2, 2.3, 2.4, 3, 4, 4.1, 4.2_
  - _Boundary: InterchangeValueModel_

- [ ] 2. Build document and object metadata core validators
- [ ] 2.1 (P) Validate metadata stream shape and decoded XML payload
  - Accept only metadata streams whose dictionary declares Metadata and XML names.
  - Decode stream data through existing filters while retaining raw stream and optional object identity.
  - Treat XML bytes as opaque metadata and avoid XMP schema interpretation.
  - Done when valid metadata streams produce decoded bytes and malformed type, subtype, owner, or filter failures raise interchange diagnostics.
  - _Requirements: 2.1, 2.2_
  - _Boundary: MetadataStreamReader_
  - _Depends: 1.1, 1.2_

- [ ] 2.2 Validate object-level metadata entries supplied by owners
  - Accept owner-supplied stream or dictionary components with optional Metadata entries.
  - Return absence for missing object-level Metadata and validate present metadata streams through the shared metadata rules.
  - Keep owner-specific indirect loading outside the shared helper so reader, graphics, or future owners control object resolution.
  - Done when non-document owners can call the helper and receive absence, valid raw XML metadata, or an owner-context interchange error.
  - _Requirements: 2.1, 2.2, 4.2_
  - _Boundary: MetadataStreamReader_
  - _Depends: 2.1_

- [ ] 2.3 (P) Extract and validate document information dictionaries
  - Resolve known document information entries as byte-preserved text strings or date strings.
  - Apply the allowed Trapped names and the Unknown default for absence.
  - Preserve the raw dictionary and unknown entries while rejecting known non-date metadata fields with invalid shapes.
  - Done when valid Info dictionaries expose all known keys and malformed known entries fail with document-info diagnostics.
  - _Requirements: 2.1, 2.3_
  - _Boundary: DocumentInfoReader_
  - _Depends: 1.1, 1.2_

- [ ] 2.4 Compare metadata source presence and raw date equivalence
  - Report which metadata sources are present without mutating either source.
  - Compare CreationDate and ModDate only by exact byte equality when both read-side values are available.
  - Distinguish Equivalent, Different, OnlyInfo, OnlyMetadataStream, and NotEvaluated without parsing XMP schemas.
  - Done when diagnostics expose each comparison state separately for creation and modification dates.
  - _Requirements: 2.4_
  - _Boundary: MetadataSourceDiagnostics_
  - _Depends: 2.1, 2.3_

- [ ] 2.5 Verify metadata and Info validators with unit tests
  - Cover valid metadata stream type/subtype, decoded payload preservation, wrong owner, wrong names, object-level Metadata helper behavior, and filter errors.
  - Cover Info text key typing, raw date retention, Trapped defaults and allowed values, and invalid known key failures.
  - Cover source diagnostics for byte-equal, byte-different, OnlyInfo, OnlyMetadataStream, and unsupported XMP extraction cases.
  - Done when targeted unit tests pass and each tested malformed case raises the intended interchange error.
  - _Requirements: 2.1, 2.2, 2.3, 2.4, 4.2_
  - _Boundary: MetadataStreamReader, DocumentInfoReader, MetadataSourceDiagnostics tests_
  - _Depends: 2.1, 2.2, 2.3, 2.4_

- [ ] 3. Build identifier and page-piece validators
- [ ] 3.1 (P) Expose file identifier comparison behavior
  - Classify exact reference matches, same original/different version matches, different files, and missing current identifiers.
  - Use byte-string equality for both identifier elements.
  - Avoid identifier generation, digest computation, uniqueness policy, or writer update behavior.
  - Done when caller-supplied identifier pairs return deterministic match classifications.
  - _Requirements: 3_
  - _Boundary: FileIdentifierAccess_
  - _Depends: 1.2_

- [ ] 3.2 (P) Validate page-piece dictionaries and private producer data
  - Treat each page-piece entry key as a producer or data-type name and require each value to be a data dictionary.
  - Require LastModified as a raw date string for each data dictionary.
  - Preserve optional Private values as opaque objects of any type.
  - Done when valid multiple-entry dictionaries are returned in source order and malformed entry shapes fail with page-piece diagnostics.
  - _Requirements: 4_
  - _Boundary: PagePieceReader_
  - _Depends: 1.2_

- [ ] 3.3 Provide exact-byte page-piece date comparison helpers
  - Compare LastModified values only for equality and never chronological ordering.
  - Make comparison usable by document, page, and form owners without interpreting private data.
  - Done when helper tests prove equal and unequal dates are distinguishable while timezone and ordering assumptions are absent.
  - _Requirements: 4_
  - _Boundary: PagePieceReader_
  - _Depends: 3.2_

- [ ] 3.4 Verify file identifier and page-piece validators with unit tests
  - Cover all file-id match classifications, including missing current IDs.
  - Cover page-piece dictionaries with several producer keys, missing LastModified, invalid data dictionaries, and opaque Private payloads.
  - Cover exact-byte date comparison without ordering behavior.
  - Done when validator tests pass and no writer-only identifier or mutation behavior is introduced.
  - _Requirements: 3, 4_
  - _Boundary: FileIdentifierAccess, PagePieceReader tests_
  - _Depends: 3.1, 3.2, 3.3_

- [ ] 4. Build content interchange validators
- [ ] 4.1 (P) Validate predefined procedure set resource names
  - Recognize only PDF, Text, ImageB, ImageC, and ImageI as typed procedure set names.
  - Read typed names from the resource category while preserving existing raw resource lookup behavior.
  - Treat absent procedure sets as an empty typed result and malformed present entries as validation failures.
  - Done when every predefined procedure set maps to a typed value and unknown names are rejected only through the opt-in typed validator.
  - _Requirements: 2_
  - _Boundary: ProcedureSetValidator_
  - _Depends: 1.2_

- [ ] 4.2 (P) Normalize marked-content operands and property lists
  - Validate operands for MP, DP, BMC, BDC, and EMC according to operator arity and operand type.
  - Represent properties as inline dictionaries, named resource entries, null, or absence where permitted.
  - Reject missing named properties and indirect references inside inline property dictionaries.
  - Done when marked-content points and sequence starts expose normalized property data without optional-content, Tagged PDF, or associated-file interpretation.
  - _Requirements: 4.1, 4.2_
  - _Boundary: MarkedContentAnalyzer_
  - _Depends: 1.2_

- [ ] 4.3 Track marked-content scope balance and text-object nesting
  - Maintain nested BMC/BDC scopes and reject unmatched EMC or unclosed sequences at stream end.
  - Track BT/ET nesting and reject crossing combinations between text objects and marked-content sequences.
  - Treat a page Contents array that has already been concatenated by reader integration as one logical stream.
  - Done when valid nested sequences produce a report with begin/end offsets and invalid crossing patterns fail at the offending instruction.
  - _Requirements: 4.1_
  - _Boundary: MarkedContentAnalyzer_
  - _Depends: 4.2_

- [ ] 4.4 Verify content interchange validators with unit tests
  - Cover all predefined procedure sets and malformed ProcSet arrays or names.
  - Cover MP/DP/BMC/BDC/EMC operands, inline and named properties, null properties, missing named resources, nested scopes, unbalanced EMC, and BT/ET crossing.
  - Verify analyzer output preserves tags, properties, point entries, sequence entries, and offsets.
  - Done when content-level tests pass without changing parser, resource lookup, or graphics visibility behavior.
  - _Requirements: 2, 4.1, 4.2_
  - _Boundary: ProcedureSetValidator, MarkedContentAnalyzer tests_
  - _Depends: 4.1, 4.2, 4.3_

- [ ] 5. Integrate document metadata and identifiers through reader
- [ ] 5.1 Add reader error wrapping and package integration
  - Add reader-layer wrapping for interchange validation failures without collapsing them into unrelated navigation or page errors.
  - Add the dependency needed for reader-owned object loading to call interchange validators.
  - Keep object loading lazy and request-scoped for metadata, Info, PieceInfo, and file identifiers.
  - Done when reader APIs can return interchange diagnostics while existing document and raw catalog access still compile.
  - _Requirements: 1, 2.1, 2.2, 2.3, 3, 4_
  - _Boundary: Reader facade, InterchangeValueModel_
  - _Depends: 1.1, 1.2_

- [ ] 5.2 Expose catalog metadata, document information, and source diagnostics
  - Resolve Catalog Metadata and trailer Info through reader-owned object loading.
  - Return absence for optional missing sources and validation errors for malformed present sources.
  - Combine metadata stream, document information, and date diagnostics into the designed read-side source summary.
  - Done when callers can inspect document metadata sources without parsing XML schemas or mutating metadata.
  - _Requirements: 2.1, 2.2, 2.3, 2.4_
  - _Boundary: MetadataStreamReader, DocumentInfoReader, Reader facade_
  - _Depends: 2.1, 2.3, 2.4, 5.1_

- [ ] 5.3 Expose trailer file identifiers through reader convenience access
  - Provide direct file identifier access from validated trailer data.
  - Apply reference comparison helpers to the current file identifier when present.
  - Preserve existing trailer ID validation and missing-ID behavior.
  - Done when a loaded file can report its ID and compare a supplied reference as exact, version, different, or missing.
  - _Requirements: 3_
  - _Boundary: FileIdentifierAccess, Reader facade_
  - _Depends: 3.1, 5.1_

- [ ] 5.4 Verify reader metadata and file-id integration
  - Use synthetic documents with Catalog Metadata, trailer Info, and PDF 2.0 ID data.
  - Assert missing optional metadata and Info return absence rather than errors.
  - Assert malformed present metadata or Info wraps interchange diagnostics with owner context.
  - Done when integration tests pass through the real reader loading path and public API review shows intended metadata and file-id additions.
  - _Requirements: 2.1, 2.2, 2.3, 2.4, 3_
  - _Boundary: Reader facade, MetadataStreamReader, DocumentInfoReader, FileIdentifierAccess tests_
  - _Depends: 5.2, 5.3_

- [ ] 6. Integrate page-piece data across document, page, and form owners
- [ ] 6.1 Expose Catalog and Page PieceInfo through reader APIs
  - Resolve optional PieceInfo dictionaries from document catalog and page dictionaries.
  - Return absence for missing entries and validation errors for malformed present entries.
  - Preserve raw private data and exact LastModified bytes for each producer entry.
  - Done when document and page callers can inspect PieceInfo without interpreting private payloads.
  - _Requirements: 4_
  - _Boundary: PagePieceReader, Reader facade_
  - _Depends: 3.2, 3.3, 5.1_

- [ ] 6.2 Preserve Form XObject PieceInfo in graphics-owned form validation
  - Add the package dependency needed for graphics form validation to use interchange page-piece models.
  - Validate and preserve form PieceInfo alongside existing metadata and structure-parent behavior.
  - Keep rendering and optional-content interpretation unchanged.
  - Done when a valid Form XObject exposes preserved PieceInfo and a malformed form PieceInfo fails through the graphics validation path.
  - _Requirements: 4_
  - _Boundary: PagePieceReader, Graphics Form XObject_
  - _Depends: 3.2, 3.3_

- [ ] 6.3 Verify page-piece owner integration
  - Cover Catalog, Page, and Form XObject PieceInfo with valid private data, missing optional entries, and malformed LastModified cases.
  - Assert exact-byte date helpers work the same across document, page, and form owners.
  - Assert raw private data is retained object-for-object.
  - Done when reader and graphics tests pass and existing form metadata, StructParent, and StructParents behavior remains intact.
  - _Requirements: 4_
  - _Boundary: PagePieceReader integration tests_
  - _Depends: 6.1, 6.2_

- [ ] 7. Integrate content analysis with existing resources and graphics behavior
- [ ] 7.1 Expose procedure set and marked-content analysis over parsed content
  - Make typed ProcSet validation and marked-content analysis usable by callers that already have parsed content and resources.
  - Preserve the existing content parser as the only source of instructions and offsets.
  - Avoid changing raw resource lookup, deprecated ProcSet compatibility, or graphics event interpretation.
  - Done when callers can analyze parsed content opt-in and existing content parsing tests continue to pass.
  - _Requirements: 2, 4.1, 4.2_
  - _Boundary: ProcedureSetValidator, MarkedContentAnalyzer, Content integration_
  - _Depends: 4.1, 4.2, 4.3_

- [ ] 7.2 Confirm optional-content and future-feature handoff boundaries
  - Preserve property-list dictionaries raw for optional content, logical structure, Tagged PDF, object metadata, associated files, and future consumers.
  - Ensure marked-content analysis does not evaluate visibility, role maps, MCIDs, structure parents, or accessibility semantics.
  - Keep graphics optional-content visibility behavior authoritative and unchanged.
  - Done when tests show property data is retained while optional-content visibility results match existing expectations.
  - _Requirements: 1, 4.1, 4.2_
  - _Boundary: MarkedContentAnalyzer, Graphics optional-content integration_
  - _Depends: 7.1_

- [ ] 7.3 Verify content interchange integration
  - Parse decoded content bytes with marked-content operators and named property resources, then analyze the resulting stream.
  - Cover a page-contents-array style concatenated stream as one marked-content scope boundary.
  - Verify ProcSet extraction using existing resource dictionaries.
  - Done when integration tests pass for valid resources, missing optional ProcSet, named properties, unbalanced scopes, and BT/ET crossing.
  - _Requirements: 2, 4.1, 4.2_
  - _Boundary: Content integration tests_
  - _Depends: 7.1, 7.2_

- [ ] 8. Validate public API, regressions, and generated interfaces
- [ ] 8.1 Regenerate package interfaces and review public surface
  - Run formatting and public interface generation after all package-level API changes are in place.
  - Confirm generated interfaces expose only intended interchange, reader, content, and graphics additions.
  - Confirm no lower objects, lexer, parser, xref, stream filter, page tree, content parser, or rendering contracts changed beyond the approved design.
  - Done when generated interfaces are updated and the public API diff matches the design scope.
  - _Requirements: 1, 2, 2.1, 2.2, 2.3, 2.4, 3, 4, 4.1, 4.2_
  - _Boundary: Public API and package interface validation_
  - _Depends: 5.4, 6.3, 7.3_

- [ ] 8.2 Run full build and regression validation
  - Run the project build and test commands used by this repository.
  - Include metadata, document information, file identifier, page-piece, ProcSet, marked-content, reader, graphics, PDF 2.0 example, and existing regression suites.
  - Investigate and fix regressions inside the owned boundaries only.
  - Done when formatting, build, interface generation, and tests complete successfully or any remaining failure is tied to an explicit external blocker.
  - _Requirements: 1, 2, 2.1, 2.2, 2.3, 2.4, 3, 4, 4.1, 4.2_
  - _Boundary: End-to-end validation_
  - _Depends: 8.1_
