# Implementation Plan

- [ ] 1. Establish shared navigation foundations
- [ ] 1.1 Add navigation diagnostics and shared validation helpers
  - Add a reader-layer navigation error category that distinguishes malformed navigation metadata from syntax, xref, and page-tree failures.
  - Centralize object loading, required-type checks, numeric coercion, rectangle parsing, color component checks, and indirect-object cycle guards used by navigation structures.
  - Preserve lazy loading so malformed optional navigation entries fail only when their navigation API is requested.
  - Done when malformed present navigation dictionaries can produce navigation-specific errors without changing existing document-structure error behavior.
  - _Requirements: 1, 2.3, 2.6, 2.8, 2.9, 2.13, 2.15_

- [ ] 1.2 Define catalog navigation model contracts
  - Add externally inspectable value models for viewer preferences, destinations, named destinations, outlines, thumbnails, collections, folders, navigators, and raw hand-off fields.
  - Keep action dictionaries, file specifications, structure elements, metadata streams, annotation dictionaries, and unknown extensible names as raw PDF objects at their ownership boundary.
  - Model defaults and absence explicitly so missing optional Catalog entries can return absence or empty collections.
  - Done when the catalog-level navigation values can be constructed in tests without executing actions, rendering, opening files, or mutating PDF structures.
  - _Requirements: 1, 2, 2.1, 2.2, 2.5, 2.6, 2.7, 2.8, 2.9, 2.10_

- [ ] 1.3 Define page navigation model contracts
  - Add externally inspectable value models for page labels, article threads and beads, page presentation settings, transitions, and sub-page navigation nodes.
  - Preserve zero-based page indexing and raw action hand-off while representing page labels and presentation metadata as display-only values.
  - Model absent page duration, absent PageLabels, absent article beads, and absent navigation nodes as defaults or empty results.
  - Done when page-level navigation values can be constructed in tests without changing page access, optional-content state, rendering, or presentation timing.
  - _Requirements: 1, 2.11, 2.12, 2.13, 2.14, 2.15_

- [ ] 1.4 Extend name-tree enumeration for navigation consumers
  - Keep exact byte-key lookup behavior unchanged while adding ordered enumeration for destination and embedded-file name trees.
  - Reuse the same limits validation, indirect loading, and cycle detection policy as existing name-tree lookup.
  - Done when enumeration and exact lookup agree for the same keys, and malformed name-tree nodes still raise reader-layer errors.
  - _Requirements: 2.5, 2.8, 2.9_
  - _Boundary: NameTreeReader_

- [ ] 1.5 (P) Add number-tree lookup for page labels
  - Parse number-tree nodes with the same bounded traversal policy used by name trees.
  - Return both enumerated ranges and the greatest range key not above a requested zero-based page index.
  - Done when a page-label consumer can retrieve sorted ranges and perform range lookup without scanning every page.
  - _Requirements: 2.12_
  - _Boundary: NumberTreeReader_
  - _Depends: 1.1_

- [ ] 1.6 (P) Expose page identity helpers needed by navigation
  - Provide package-local helpers for first-page fallback, page-object identity validation, and page-count bounds without changing public page-tree traversal semantics.
  - Ensure structure-destination and page-label consumers can distinguish valid page references from other dictionaries.
  - Done when navigation parsers can ask for first page, page reference validation, and page bounds through package-local helpers.
  - _Requirements: 2.4, 2.12, 2.13_
  - _Boundary: NavigationBoundary_
  - _Depends: 1.1_

- [ ] 2. Implement document-level navigation readers
- [ ] 2.1 (P) Parse viewer preferences with ISO defaults
  - Parse all viewer preference booleans, page-mode names, reading direction, page boundary names, print settings, copy counts, page ranges, and enforce names.
  - Default absent boolean entries to false, treat unrecognized print scaling as application default, and validate enforce names against the allowed set.
  - Preserve implementation-dependent preferences as optional typed values rather than inventing processor behavior.
  - Done when a present ViewerPreferences dictionary returns typed settings and malformed constrained values raise navigation errors.
  - _Requirements: 2_
  - _Boundary: ViewerPreferencesReader_
  - _Depends: 1.1, 1.2_

- [ ] 2.2 (P) Parse explicit, structure, and named destinations
  - Support all explicit destination views, including null retention values and zero zoom retention.
  - Resolve name-object destinations from the legacy Catalog destination dictionary and byte-string destinations from the Names destination tree.
  - Support local page references, local structure references with page fallback, remote page indices, and remote structure ID byte strings through explicit caller context.
  - Preserve destination dictionary attributes that belong to adjacent action handling as raw values.
  - Done when named lookup, named enumeration, explicit array parsing, and structure fallback are observable through component tests.
  - _Requirements: 2.2, 2.3, 2.4, 2.5_
  - _Boundary: DestinationParser_
  - _Depends: 1.1, 1.2, 1.4, 1.6_

- [ ] 2.3 Parse document outlines in display order
  - Traverse outline roots and item linked lists through first, last, previous, next, parent, and child relationships.
  - Preserve title bytes, count sign, color, style flags, optional destination, raw action dictionary, and raw structure element reference.
  - Reject malformed outline items that contain both a destination and an action, miss required entries, or introduce cycles.
  - Done when outline items are returned in linked-list order with nested children and raw hand-off values intact.
  - _Requirements: 2.1, 2.2, 2.6_
  - _Depends: 2.2_

- [ ] 2.4 (P) Parse page thumbnails as metadata descriptors
  - Validate thumbnail stream dictionaries and expose dimensions, color-space classification, bits per component, decode data, raw stream identity, and page index.
  - Accept only the significant thumbnail entries for navigation metadata and ignore unrelated image dictionary entries.
  - Avoid decoding, rendering, or sampling thumbnail image data.
  - Done when pages with valid thumbnails return descriptors and invalid thumbnail shapes raise navigation errors.
  - _Requirements: 2.1, 2.7_
  - _Boundary: ThumbnailReader_
  - _Depends: 1.1, 1.2, 1.3_

- [ ] 2.5 (P) Parse portable collection metadata and navigators
  - Parse collection schema fields, initial document key, view mode, sort keys, ascending defaults, colors, split settings, embedded-file entries, and navigator layouts.
  - Preserve file specification objects as raw values and treat absent EmbeddedFiles as an empty collection member list.
  - Preserve unknown navigator layout names while requiring at least one standard fallback layout when a navigator is present.
  - Done when collection metadata can be read without opening embedded files, previewing attachments, or applying UI layouts.
  - _Requirements: 2.8, 2.10_
  - _Boundary: CollectionReader_
  - _Depends: 1.1, 1.2, 1.4_

- [ ] 2.6 Traverse collection folders and associate files
  - Traverse folder parent, child, and sibling links with cycle detection and unique non-negative folder IDs.
  - Validate folder names, sibling name conflicts at the supported normalization boundary, free ID ranges, collection item metadata, descriptions, dates, and folder thumbnails.
  - Associate EmbeddedFiles entries with folder IDs using the bracketed numeric prefix convention and place nonconforming keys under the root folder.
  - Done when a folder tree returns ordered folders, file-to-folder associations, free ranges, and root fallback assignments.
  - _Requirements: 2.8, 2.9_
  - _Depends: 2.4, 2.5_

- [ ] 3. Implement page-level navigation readers
- [ ] 3.1 (P) Parse page labels from number-tree ranges
  - Require a page-index zero range when PageLabels is present and default missing start numbers to one.
  - Format decimal, uppercase Roman, lowercase Roman, uppercase alphabetic, lowercase alphabetic, and prefix-only labels.
  - Keep labels as display metadata and leave document page indexing zero-based.
  - Done when individual label lookup and range enumeration return deterministic labels for valid page indices.
  - _Requirements: 2.11, 2.12_
  - _Boundary: PageLabelReader_
  - _Depends: 1.3, 1.5, 1.6_

- [ ] 3.2 (P) Parse article threads and page bead references
  - Parse Catalog thread arrays, thread information dictionaries, metadata streams, and first-bead references.
  - Traverse bead rings through next and previous links, validating page references and bead rectangles.
  - Parse page bead arrays in drawing order and preserve thread metadata as raw hand-off values.
  - Done when document threads and per-page bead references expose ordered bead metadata and terminate deterministically on malformed rings.
  - _Requirements: 2.11, 2.13_
  - _Boundary: ArticleReader_
  - _Depends: 1.1, 1.3, 1.6_

- [ ] 3.3 (P) Parse page presentation metadata
  - Parse page duration, transition style defaults, transition duration, dimension, motion, direction, scale, and opaque-area flags.
  - Represent missing duration as no automatic advance and keep transition effects as metadata only.
  - Validate style-specific constrained names and directions without rendering or applying any transition.
  - Done when page presentation metadata returns defaults for missing entries and typed values for valid transition dictionaries.
  - _Requirements: 2.11, 2.14_
  - _Boundary: PresentationReader_
  - _Depends: 1.1, 1.3_

- [ ] 3.4 Traverse sub-page navigation nodes
  - Parse the primary presentation-step node from page navigation metadata when present.
  - Traverse next and previous navigation-node links with cycle detection.
  - Preserve forward and backward action dictionaries as raw values and never execute them.
  - Done when navigation nodes return in deterministic order with raw actions and cycle failures are reported as navigation errors.
  - _Requirements: 2.11, 2.15_
  - _Depends: 3.3_

- [ ] 4. Wire public reader facades and integration contracts
- [ ] 4.1 Connect document-level navigation APIs to catalog readers
  - Expose document facade access for viewer preferences, named destination lookup and enumeration, outline, collection, page label lookup and ranges, and article threads.
  - Return absence or empty arrays for missing optional structures and navigation errors for present malformed structures.
  - Preserve existing document opening, catalog access, page count, page ordering, and name-tree exact lookup behavior.
  - Done when callers can inspect all Catalog-level navigation metadata through the reader facade.
  - _Requirements: 1, 2, 2.1, 2.2, 2.5, 2.6, 2.8, 2.10, 2.11, 2.12, 2.13_
  - _Depends: 2.1, 2.2, 2.3, 2.5, 2.6, 3.1, 3.2_

- [ ] 4.2 Connect page-level navigation APIs to page readers
  - Expose page facade access for thumbnails, article beads, presentation metadata, and navigation nodes.
  - Keep inherited page attributes, page tree traversal, and page-index behavior unchanged.
  - Return empty or default metadata for absent optional page entries and navigation errors for malformed present entries.
  - Done when callers can inspect all Page-level navigation metadata from an existing page handle.
  - _Requirements: 1, 2.1, 2.7, 2.11, 2.13, 2.14, 2.15_
  - _Depends: 2.4, 3.2, 3.3, 3.4_

- [ ] 4.3 Review public API surface and generated package interface
  - Regenerate the reader package interface after additive public navigation APIs are in place.
  - Confirm public enums are pattern-matchable where intended and structs expose only read-only inspection data.
  - Confirm raw hand-off fields remain at adjacent-spec ownership boundaries and no upstream package imports the reader layer.
  - Done when the generated package interface reflects only intended reader navigation additions.
  - _Requirements: 1, 2.2, 2.6, 2.8, 2.13, 2.15_
  - _Depends: 4.1, 4.2_

- [ ] 5. Validate behavior, robustness, and non-regression
- [ ] 5.1 Add component-focused white-box coverage
  - Cover viewer preference defaults, destination forms, named destination sources, outline order, thumbnails, collection schemas, folders, page labels, articles, presentations, and navigation nodes.
  - Include malformed present entries for required keys, constrained names, invalid values, and raw hand-off preservation.
  - Done when each navigation component has focused tests proving its accepted values, defaults, and error paths.
  - _Requirements: 2, 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7, 2.8, 2.9, 2.10, 2.11, 2.12, 2.13, 2.14, 2.15_
  - _Depends: 4.1, 4.2_

- [ ] 5.2 Add cross-structure integration and regression coverage
  - Build synthetic documents that combine Catalog and Page navigation entries and access them through public document and page APIs.
  - Verify new navigation APIs do not change page count, page ordering, inherited page attributes, catalog entry access, or existing exact name-tree lookup.
  - Exercise large trees, linked lists, rings, repeated references, and cycles so traversal terminates predictably.
  - Done when integration tests prove navigation parsing coexists with existing reader behavior and bounded traversal.
  - _Requirements: 1, 2.5, 2.6, 2.8, 2.9, 2.12, 2.13, 2.15_
  - _Depends: 5.1_

- [ ] 5.3 Run final toolchain validation
  - Run formatter, type checks, reader package tests, full test suite, and public API generation.
  - Inspect any generated interface diff and verify no non-standard dependency or package dependency inversion was introduced.
  - Done when validation commands pass and any remaining failures are tied to explicit external blockers rather than the navigation implementation.
  - _Requirements: 1, 2, 2.11_
  - _Depends: 4.3, 5.2_
