# Research & Design Decisions

## Summary
- **Feature**: `pdf-document-structure`
- **Discovery Scope**: Extension
- **Key Findings**:
  - The existing `src/reader` package already provides `PdfFile::open`, trailer `Root` access, lazy `PdfFile::load_object`, object-stream caching, and structural stream decoding through `src/filters`; document structure can be added without changing `objects`, `lexer`, `parser`, or `filters`.
  - ISO 32000-2 §7.7 makes the Catalog and Page tree dictionary contracts strict while leaving many page and catalog entries semantically owned by later clauses; this spec should validate structural contracts but expose downstream-owned entries as raw `PdfObject` values.
  - Page inheritance and name-tree lookup are both reference traversal problems; the implementation should share defensive traversal rules such as indirect-reference validation, cycle detection, and lazy loading, but keep their public contracts separate.

## Research Log

### Existing Reader Extension Points
- **Context**: The document-structure layer depends on `pdf-file-structure`, so the design needed to identify whether to extend `src/reader` or create a new package.
- **Sources Consulted**:
  - `src/reader/document.mbt`
  - `src/reader/object_loader.mbt`
  - `src/reader/types.mbt`
  - `src/reader/pkg.generated.mbti`
  - `.kiro/specs/pdf-file-structure/design.md`
  - `.kiro/specs/pdf-filters/design.md`
- **Findings**:
  - `PdfFile::open` builds the merged xref index and preserves the latest trailer as `TrailerInfo`.
  - `PdfFile::root_ref` returns the trailer `Root` indirect reference required for Catalog lookup.
  - `PdfFile::load_object` lazily resolves uncompressed and compressed object locations, caches resolved objects, and returns `PdfObject::Null` for missing references.
  - `src/reader` already imports `src/filters`, so document structure does not need a new dependency to consume filtered object streams indirectly.
- **Implications**:
  - The document-structure API belongs in `src/reader` as a downstream layer over `PdfFile`.
  - The design should add a `PdfDocument` facade rather than changing lower parser or object contracts.
  - Public APIs should wrap reader errors in a document-level error type to keep structure validation failures distinct from file-structure failures.

### ISO 32000-2 §7.7 Structural Contracts
- **Context**: Requirements reference Catalog access, Page tree traversal, page entries, inheritance, and the Name dictionary.
- **Sources Consulted**:
  - `spec/extracted/7.7-document-structure.spec.txt`
  - `spec/extracted/7.7-document-structure.md`
  - `.kiro/specs/pdf-document-structure/requirements.md`
- **Findings**:
  - The Catalog is reached from trailer `Root`; `/Type /Catalog` and `/Pages` as an indirect reference are required.
  - Page tree nodes require `/Type /Pages`, `/Kids` as an array of indirect references, and `/Count` as the number of descendant leaf page objects.
  - Page objects require `/Type /Page`; page entries such as `Resources`, `MediaBox`, `CropBox`, and `Rotate` can be inherited from ancestor `Pages` nodes.
  - Inherited composite values are inherited as complete values; dictionaries and arrays are not merged.
  - The Name dictionary maps category names such as `Dests`, `AP`, `JavaScript`, `Pages`, `Templates`, `EmbeddedFiles`, and `AlternatePresentations` to name tree roots.
- **Implications**:
  - Page traversal must be depth-first in `Kids` order and validate root `Count` against discovered leaf pages.
  - The inheritance resolver must stop at the nearest definition and return absence when no source defines the requested inheritable key.
  - Name-tree lookup should accept exact PDF string bytes as keys and return raw `PdfObject` values because destination, JavaScript, embedded file, and template semantics belong to later specs.

### Existing Object Model and Type Safety
- **Context**: The design must use MoonBit's existing strongly typed object model rather than ad hoc dictionary parsing.
- **Sources Consulted**:
  - `src/objects/types.mbt`
  - `src/objects/accessors.mbt`
  - `src/objects/pkg.generated.mbti`
  - `<local>/.codex/skills/moonbit-agent-guide/SKILL.md`
  - `<local>/.codex/skills/moonbit-lang/SKILL.md`
- **Findings**:
  - `PdfDictionary` is `Map[PdfName, PdfObject]`, and `PdfName` equality is byte based.
  - Existing object accessors validate typed expectations and raise `PdfParseError`; reader code already wraps parser failures at boundaries.
  - MoonBit project conventions prefer package-local cohesive files, `suberror` diagnostics, public enums for external pattern matching, and black-box plus white-box tests.
- **Implications**:
  - New document types should use `@objects.PdfName`, `@objects.ObjectId`, `@objects.PdfObject`, and `@objects.PdfDictionary` directly.
  - Page boxes should normalize to a typed `PdfRectangle` value only after validating four numeric entries.
  - File organization should add focused `catalog.mbt`, `page_tree.mbt`, `page.mbt`, `inheritance.mbt`, `name_tree.mbt`, and `document_error.mbt` files inside `src/reader`.

## Architecture Pattern Evaluation

| Option | Description | Strengths | Risks / Limitations | Notes |
|--------|-------------|-----------|---------------------|-------|
| Extend `PdfFile` only | Add Catalog, page, and name methods directly on `PdfFile` | Minimal new state and small API surface | Harder to cache page enumeration without mixing file and document responsibilities | Rejected as the primary shape; keep `PdfFile::document` as a bridge. |
| Add `PdfDocument` facade in `src/reader` | Wrap an opened `PdfFile`, resolved Catalog metadata, and lazy document-structure caches | Clear boundary over file structure, supports lazy page index, keeps imports unchanged | Adds one public type and document error wrapper | Selected. |
| Create new `src/document` package | Put all document structure in a downstream package | Strong package boundary | Adds a new dependency direction and requires root re-export decisions before the reader package has a stable document API | Rejected for this phase; the repository already treats reader as the downstream file/document access layer. |

## Synthesis Outcomes
- **Generalization**: Catalog optional entries, Page optional entries, inherited page attributes, and name-tree category values are all raw-object access problems once the structural dictionary contract is validated. The design generalizes raw entry access while keeping typed APIs only for §7.7-owned structures such as `Pages`, `Kids`, `Count`, `Parent`, `MediaBox`, `CropBox`, `Rotate`, and name-tree traversal.
- **Build vs. Adopt**: No new library is adopted. Existing `PdfFile::load_object`, `PdfObject`, `PdfDictionary`, and `PdfName` contracts already solve object access and type representation. A small document-structure layer is built because ISO §7.7 validation and traversal are project-domain behavior, not an external dependency concern.
- **Simplification**: The design avoids a new package, avoids typed models for downstream-owned Catalog and Page semantics, and avoids eager Page tree traversal during document creation. The only new public facade is `PdfDocument`, with focused helper types for pages, rectangles, name categories, and errors.

## Design Decisions

### Decision: Use a `PdfDocument` Facade Over `PdfFile`
- **Context**: The document layer needs a Catalog handle, lazy page index, and name-tree lookup while preserving lazy object loading from the existing reader.
- **Alternatives Considered**:
  1. Add all methods directly to `PdfFile`.
  2. Add a separate `PdfDocument` facade in `src/reader`.
  3. Create a new `src/document` package.
- **Selected Approach**: `PdfFile::document` resolves and validates the Catalog once and returns `PdfDocument`. `PdfDocument::open` is a convenience that calls `PdfFile::open` and then `PdfFile::document`.
- **Rationale**: This keeps file-structure ownership in `PdfFile` and document-structure state in `PdfDocument`, while preserving the existing package dependency direction.
- **Trade-offs**: Users who already have a `PdfFile` perform one explicit conversion step. The benefit is that page-index caching and name-tree state do not expand the file-structure aggregate.
- **Follow-up**: During implementation, verify `moon info` shows only intended public additions in `src/reader/pkg.generated.mbti`.

### Decision: Expose Downstream-Owned Entries as Raw Objects
- **Context**: Catalog and Page dictionaries contain many entries whose detailed semantics are defined in later clauses, including outlines, metadata, structure trees, annotations, content streams, and actions.
- **Alternatives Considered**:
  1. Model every optional Catalog and Page entry with a typed structure now.
  2. Validate structural entries and expose optional downstream-owned entries as `PdfObject?`.
- **Selected Approach**: Type structural entries owned by this spec, such as Catalog `Pages`, Page tree `Kids` and `Count`, page `Parent`, boxes, and basic inherited attributes. Preserve optional entries such as `Outlines`, `Metadata`, `StructTreeRoot`, `Annots`, and `Contents` as raw objects or references.
- **Rationale**: The current phase is document structure access, not semantic interpretation of content, metadata, annotations, or logical structure.
- **Trade-offs**: Callers must inspect raw values for downstream concepts until later specs add typed APIs.
- **Follow-up**: Revalidate this design if a later spec changes raw `PdfObject` ownership or requires typed entry contracts.

### Decision: Lazy Page Tree Index With Defensive Traversal
- **Context**: Requirements require page count, index access, Count validation, document order, and lazy traversal.
- **Alternatives Considered**:
  1. Traverse the whole Page tree during `PdfDocument` creation.
  2. Traverse and cache pages on first page count or page access.
  3. Traverse on every page lookup.
- **Selected Approach**: `PdfDocument` validates the Catalog during creation, then builds a cached `PageTreeIndex` the first time `page_count` or `page(index)` is called.
- **Rationale**: This satisfies lazy traversal while giving stable out-of-range checks and avoiding repeated tree walks.
- **Trade-offs**: The first page access may perform full tree traversal. That is acceptable because Count validation requires comparing the complete leaf count.
- **Follow-up**: Tests must prove `PdfDocument::document` does not enumerate pages until the first page API call.

### Decision: Exact Byte Keys for Name Tree Lookup
- **Context**: The object model stores PDF string values as `Bytes`, and `PdfName` equality is byte based.
- **Alternatives Considered**:
  1. Accept MoonBit `String` lookup keys and convert to bytes.
  2. Accept exact `Bytes` lookup keys and optionally add text convenience later.
- **Selected Approach**: Name-tree lookup accepts exact `Bytes` keys and returns `PdfObject?`.
- **Rationale**: PDF strings may not be UTF-8, and byte-exact lookup avoids silent transcoding errors.
- **Trade-offs**: Text-oriented callers need to provide encoded key bytes.
- **Follow-up**: A future common-data spec can add encoding-aware string helpers if needed.

## Risks & Mitigations
- Page tree cycles or repeated intermediate nodes could cause infinite traversal — track visited `ObjectId` values for Pages nodes and parent-chain resolution, and raise a document error on cycles.
- `Count` values can disagree with actual leaf pages — compute subtree leaf counts during traversal and raise a page-tree error when the root or any intermediate node is inconsistent.
- Optional entries can contain indirect references or malformed shapes — resolve only entries owned by this spec, preserve raw optional objects, and provide on-demand reference resolution helpers.
- Name tree depth or malformed `Kids` and `Names` arrays can produce ambiguous lookup failures — validate node shape at each lookup step and treat missing categories or keys as `None`, not as errors.
- First page access may load many page dictionaries — keep traversal lazy until needed and cache the flat `PageTreeIndex` after the first successful traversal.

## References
- `spec/extracted/7.7-document-structure.spec.txt` — local ISO 32000-2 §7.7 excerpt used for Catalog, Page tree, Page object, inheritance, and Name dictionary contracts.
- `.kiro/specs/pdf-document-structure/requirements.md` — authoritative requirements for this spec.
- `.kiro/specs/pdf-file-structure/design.md` — upstream reader boundary and `PdfFile` object-loading contract.
- `.kiro/specs/pdf-filters/design.md` — upstream structural stream decoding integration already available through `src/reader`.
- `.kiro/steering/product.md`, `.kiro/steering/tech.md`, `.kiro/steering/structure.md` — project-wide MoonBit, dependency, and PDF parsing guidance.
