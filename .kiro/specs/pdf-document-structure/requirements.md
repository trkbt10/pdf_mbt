# Requirements Document

## Project Description (Input)
Implement PDF document structure access in MoonBit, conforming to ISO 32000-2:2020 (PDF 2.0) §7.7. The document structure layer resolves the Catalog dictionary from the trailer `Root` entry, traverses the Page tree to enumerate pages, and provides access to per-page attributes (MediaBox, Resources, Contents, etc.) with inheritance from ancestor page tree nodes. This layer builds on `pdf-file-structure` (Phase 2) and `pdf-filters` (Phase 3).

Reference specification: `spec/extracted/7.7-document-structure.spec.txt`

Dependencies: `pdf-objects` (Phase 1), `pdf-file-structure` (Phase 2), `pdf-filters` (Phase 3).

## Requirements

### Requirement 1: Catalog Dictionary Access
The document reader shall resolve and validate the Catalog dictionary from the trailer `Root` entry per §7.7.2.

#### Acceptance Criteria
- The document reader shall follow the trailer `Root` indirect reference to load the Catalog dictionary
- The document reader shall verify the Catalog dictionary contains a `Type` entry with value `Catalog`
- The document reader shall extract the required `Pages` entry (indirect reference to the root page tree node) from the Catalog
- The document reader shall recognize optional Catalog entries including `PageLabels`, `Names`, `Outlines`, `Metadata`, `MarkInfo`, `StructTreeRoot`, and `Lang`

### Requirement 2: Page Tree Traversal
The document reader shall traverse the page tree to enumerate all pages in document order per §7.7.3.

#### Acceptance Criteria
- The document reader shall recognize page tree nodes with `Type` value `Pages` containing a `Kids` array and `Count` integer
- The document reader shall recursively traverse `Kids` entries, which may be either intermediate `Pages` nodes or leaf `Page` objects
- The document reader shall verify that the total page count in `Count` matches the actual number of leaf `Page` objects found
- The document reader shall produce a flat ordered list of page references in document order (left-to-right depth-first traversal of the tree)

### Requirement 3: Page Object Access
The document reader shall parse individual page objects and provide access to their entries per §7.7.3.3.

#### Acceptance Criteria
- The document reader shall recognize page objects with `Type` value `Page`
- The document reader shall provide access to the `MediaBox` entry (required, array of four numbers defining the page boundary)
- The document reader shall provide access to optional page entries including `CropBox`, `Resources`, `Contents`, `Rotate`, `UserUnit`, `Annots`, and `Parent`
- The document reader shall resolve indirect references within page entries on demand

### Requirement 4: Page Attribute Inheritance
The document reader shall implement attribute inheritance from ancestor page tree nodes per §7.7.3.4.

#### Acceptance Criteria
- When a page object does not contain a particular inheritable entry, the document reader shall search its ancestor `Pages` nodes (via `Parent`) until the entry is found or the root is reached
- The document reader shall support inheritance for these entries: `Resources`, `MediaBox`, `CropBox`, and `Rotate`
- The document reader shall use the value from the nearest ancestor that defines the entry
- When neither the page nor any ancestor defines an inheritable entry, the document reader shall return the entry as absent (not raise an error)

### Requirement 5: Name Dictionary
The document reader shall access the name dictionary from the Catalog per §7.7.4.

#### Acceptance Criteria
- The document reader shall resolve the optional `Names` entry in the Catalog dictionary as a name dictionary
- The document reader shall provide lookup for name trees referenced by the name dictionary, including `Dests`, `AP`, `JavaScript`, `Pages`, `Templates`, `EmbeddedFiles`, and `AlternatePresentations`
- Each name tree maps string keys to values; the document reader shall support lookup by key

### Requirement 6: Page Count and Index Access
The document reader shall support page access by zero-based index.

#### Acceptance Criteria
- The document reader shall report the total number of pages in the document
- The document reader shall return the page object for a given zero-based page index
- The document reader shall return an error for out-of-range page indices
- The document reader shall support lazy page tree traversal so that pages are enumerated only when first needed

### Requirement 7: Sample File Validation
The document reader shall correctly access document structure in the bundled PDF 2.0 example files.

#### Acceptance Criteria
- The document reader shall open `spec/pdf20examples/Simple PDF 2.0 file.pdf`, access the Catalog, enumerate pages, and read MediaBox from the first page
- The document reader shall open a multi-page PDF and verify page count matches the root `Count` value
- The document reader shall correctly resolve inherited Resources from an ancestor page tree node
