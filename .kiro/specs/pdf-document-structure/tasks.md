# Implementation Plan

- [ ] 1. Establish document-structure foundations
- [x] 1.1 Define document-level diagnostics and shared structural value shapes
  - Add document errors that wrap reader failures and distinguish invalid catalog, page tree, page object, inherited attribute, name tree, page-index, and cycle failures.
  - Add shared document-structure values for validated catalog state, page records, page rectangles, and name-tree categories without changing lower object or reader contracts.
  - The completed foundation lets document APIs report malformed required structures with document-specific errors while optional and absent values remain representable.
  - _Requirements: 1.2, 2.3, 3.1, 4.1, 5.3, 6.3_

- [x] 1.2 Create reusable document-structure fixture coverage for synthetic PDFs
  - Provide complete synthetic PDF bytes for a valid catalog, a single page, nested page trees, inherited resources, and name dictionary cases.
  - Keep the fixtures compatible with the existing file reader so tests exercise real trailer, xref, and indirect-object loading behavior.
  - The completed fixtures can open through the current reader and expose the structural shapes needed by catalog, page tree, inheritance, names, and example validation tests.
  - _Requirements: 7.1, 7.2, 7.3_

- [ ] 2. Resolve the document catalog and facade entry points
- [x] 2.1 Resolve and validate the catalog from the latest trailer root
  - Follow the latest trailer root reference through the existing object loader and require the resolved object to be a dictionary.
  - Require `/Type /Catalog` and a required `/Pages` indirect reference.
  - Preserve raw optional catalog entries for `PageLabels`, `Names`, `Outlines`, `Metadata`, `MarkInfo`, `StructTreeRoot`, and `Lang` without interpreting them.
  - The completed resolver returns a validated catalog with its root page tree reference, and malformed catalog structures raise document errors with object context.
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 5.1_
  - _Boundary: CatalogResolver_

- [x] 2.2 Expose document creation and catalog access without page traversal
  - Add document creation from complete bytes and from an already opened file while preserving the existing file cache and object-loading behavior.
  - Validate the catalog during document creation and expose it through the document facade.
  - Keep the page tree unresolved until page count, page list, or indexed page access is requested.
  - The completed facade can open a simple PDF, return its catalog, and prove that page enumeration has not happened during document creation.
  - _Requirements: 1.1, 6.4, 7.1_
  - _Boundary: DocumentFacade_

- [ ] 3. Build lazy page indexing and indexed page access
- [x] 3.1 Traverse page tree nodes in document order
  - Load the root page tree node from the catalog and validate `Pages` nodes with `Kids` and non-negative `Count` entries.
  - Traverse child references recursively from left to right and accept only intermediate `Pages` nodes or leaf `Page` objects.
  - Reject malformed child entries, repeated intermediate nodes, cycles, and count mismatches.
  - The completed traversal produces the expected ordered leaf page references for nested page-tree fixtures and reports count failures before exposing a page index.
  - _Requirements: 2.1, 2.2, 2.3, 2.4, 3.1, 7.2_
  - _Boundary: PageTreeWalker_

- [x] 3.2 Store and reuse the ordered page index
  - Record each leaf page reference with its raw page dictionary, zero-based index, parent reference, and known ancestor context.
  - Cache the complete page index only after a successful traversal, leaving no public partial state after traversal errors.
  - Reuse the cached index for subsequent page count and indexed page calls.
  - The completed cache reports the same ordered pages across repeated calls without rebuilding the page tree.
  - _Requirements: 2.4, 6.1, 6.2, 6.4_
  - _Boundary: PageTreeIndex_

- [x] 3.3 Return pages by zero-based index with count and bounds errors
  - Report page count from the cached page index.
  - Return all pages in document order and return one page for a valid zero-based index.
  - Raise a document page-index error for negative and out-of-range indices.
  - The completed document facade returns page 0 from a single-page fixture, preserves nested document order, and reports the requested index and total count in bounds failures.
  - _Requirements: 2.4, 3.1, 6.1, 6.2, 6.3_
  - _Boundary: DocumentFacade_

- [ ] 4. Implement page structural access and inheritance
- [x] 4.1 Provide direct page entry access and on-demand reference resolution
  - Validate page dictionaries as `/Type /Page` before exposing page entry behavior.
  - Provide direct access to structural entries such as parent, contents, user unit, and annotations without applying inheritance.
  - Resolve direct references, and top-level references in array-valued entries, only when explicit resolution is requested.
  - The completed page access returns raw direct entries and proves content-stream targets are not loaded unless the caller requests resolution.
  - _Requirements: 3.1, 3.3, 3.4, 6.2, 7.1_
  - _Boundary: PageAccessor_

- [x] 4.2 (P) Resolve inherited page attributes through ancestor nodes
  - Search the page first and then parent `Pages` nodes for `Resources`, `MediaBox`, `CropBox`, and `Rotate`.
  - Return the nearest definition as-is, return absence when no ancestor defines the key, and never merge composite values.
  - Detect malformed parent objects and parent-chain cycles.
  - The completed inheritance resolver returns ancestor resources for a leaf that omits them and returns absence for undefined inherited keys without raising.
  - _Requirements: 4.1, 4.2, 4.3, 4.4, 7.3_
  - _Boundary: InheritanceResolver_
  - _Depends: 3.2_

- [x] 4.3 Convert page boundary and scalar attributes into typed results
  - Normalize `MediaBox` and `CropBox` arrays of four numbers into rectangle values after direct or inherited lookup.
  - Validate inherited or direct `Rotate` values and direct `UserUnit` values while leaving resources, contents, and annotations as raw objects.
  - Surface malformed rectangle or scalar shapes as document errors tied to the page or inherited source.
  - The completed page API returns typed page boxes and rotation values for valid pages and raises deterministic document errors for malformed arrays.
  - _Requirements: 3.2, 3.3, 4.2, 4.3, 4.4, 7.1_
  - _Boundary: PageAccessor, InheritanceResolver_
  - _Depends: 4.2_

- [ ] 5. Implement catalog name dictionary lookup
- [x] 5.1 (P) Resolve optional name dictionary category roots
  - Treat a missing catalog `Names` entry as absence rather than an error.
  - Resolve direct or indirect `Names` entries to a dictionary when present.
  - Recognize `Dests`, `AP`, `JavaScript`, `Pages`, `Templates`, `EmbeddedFiles`, and `AlternatePresentations` category roots without interpreting their values.
  - The completed name dictionary access returns category roots when present and returns absence for missing names dictionaries or missing categories.
  - _Requirements: 5.1, 5.2_
  - _Boundary: NameDictionaryReader_
  - _Depends: 2.1_

- [ ] 5.2 Search name trees by exact PDF string bytes
  - Support leaf `Names` arrays that map exact string keys to raw values.
  - Support intermediate `Kids` traversal with indirect node loading and optional `Limits` pruning.
  - Detect malformed name arrays, non-string keys, invalid child references, and cycles.
  - The completed lookup returns the matching raw value for an exact byte key, returns absence for missing keys, and raises a name-tree document error for malformed trees.
  - _Requirements: 5.2, 5.3_
  - _Boundary: NameTreeReader_

- [ ] 6. Integrate the public surface and validation coverage
- [ ] 6.1 Wire document APIs into the reader public interface
  - Make the document facade, catalog, page, rectangle, name category, and document error shapes visible through the reader package boundary.
  - Regenerate the public interface metadata and verify existing file-structure APIs remain unchanged in behavior.
  - Preserve the existing package dependency direction and avoid changes to lower object, lexer, parser, or filter packages.
  - The completed integration passes public API review and shows only the intended reader document-structure additions.
  - _Requirements: 1.1, 3.4, 5.2, 6.1, 6.2, 6.3_
  - _Boundary: DocumentFacade, Reader public interface_

- [ ] 6.2 Cover catalog and lazy page-tree behavior with whitebox tests
  - Assert catalog root resolution, catalog type validation, required pages reference extraction, optional catalog entry recognition, and reader-error wrapping.
  - Assert lazy page-tree traversal, nested document order, kids validation, count validation, repeated-node rejection, and cycle detection.
  - The completed test suite fails on catalog or page-tree contract regressions and confirms document creation does not enumerate pages.
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 2.1, 2.2, 2.3, 2.4, 6.4_
  - _Boundary: CatalogResolver, PageTreeWalker, PageTreeIndex tests_

- [ ] 6.3 (P) Cover page access and inheritance behavior with whitebox tests
  - Assert page type validation, direct page entries, on-demand entry resolution, typed page boxes, rotation, user unit, annotations, and malformed page entry errors.
  - Assert inherited resources, media box, crop box, and rotate prefer the page value, then nearest ancestor, return absence when undefined, and never merge dictionaries.
  - The completed tests fail on page accessor or inheritance regressions and include the inherited-resources acceptance scenario.
  - _Requirements: 3.1, 3.2, 3.3, 3.4, 4.1, 4.2, 4.3, 4.4, 7.3_
  - _Boundary: PageAccessor, InheritanceResolver tests_
  - _Depends: 4.3_

- [ ] 6.4 (P) Cover name dictionary and name-tree lookup with whitebox tests
  - Assert missing names dictionaries, required categories, exact byte-key matching, missing key absence, leaf lookup, intermediate kids traversal, and limits pruning.
  - Assert malformed name-tree shapes raise document errors instead of returning misleading absence.
  - The completed tests fail on name dictionary or name-tree lookup regressions across all required categories.
  - _Requirements: 5.1, 5.2, 5.3_
  - _Boundary: NameDictionaryReader, NameTreeReader tests_
  - _Depends: 5.2_

- [ ] 6.5 Validate bundled and end-to-end PDF document examples
  - Open the bundled simple PDF 2.0 example, resolve its catalog, enumerate pages, fetch page 0, and read its media box through public APIs.
  - Validate a multi-page document count against the root page tree count and validate inherited resources from an ancestor page tree node.
  - Run formatting, public interface generation, build checks, and the full test suite after the document-structure work is integrated.
  - The completed validation demonstrates the public document APIs work on bundled examples and all reader tests pass.
  - _Requirements: 1.1, 2.3, 3.2, 4.1, 6.1, 6.4, 7.1, 7.2, 7.3_
