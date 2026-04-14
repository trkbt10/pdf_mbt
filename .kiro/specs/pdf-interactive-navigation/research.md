# Research & Design Decisions

## Summary
- **Feature**: `pdf-interactive-navigation`
- **Discovery Scope**: Extension / Complex Integration
- **Key Findings**:
  - The existing `src/reader` document facade already resolves Catalog, Page tree, page access, inherited page attributes, and Catalog name-tree lookup. Interactive navigation should extend that downstream reader layer rather than changing `objects`, `lexer`, `parser`, `filters`, `content`, or `graphics`.
  - ISO 32000-2:2020 clauses 12.1 through 12.4 mix viewer-facing behavior with structural PDF dictionaries. The parser library should own typed metadata extraction, structural validation, reference traversal, and raw action/file/annotation hand-off, but not execute UI behavior, actions, JavaScript, rendering, collection previews, or annotation handlers.
  - Several navigation features are the same underlying problem: Catalog or Page dictionary entry lookup followed by constrained dictionary parsing and bounded indirect-reference traversal. The design generalizes name-tree and number-tree traversal while keeping feature-specific models for destinations, outlines, collections, page labels, articles, and presentations.

## Research Log

### Existing Reader Extension Points
- **Context**: The feature depends on document-level and page-level navigation data, so discovery needed to identify whether the implementation belongs in `src/reader` or in a new package.
- **Sources Consulted**:
  - `src/reader/document_types.mbt`
  - `src/reader/document_structure.mbt`
  - `src/reader/catalog.mbt`
  - `src/reader/name_dictionary.mbt`
  - `src/reader/page_tree.mbt`
  - `src/reader/document_error.mbt`
  - `.kiro/specs/pdf-document-structure/design.md`
  - `.kiro/specs/pdf-document-structure/research.md`
- **Findings**:
  - `PdfDocument` already wraps `PdfFile`, a validated `PdfCatalog`, and a lazy `PageTreeIndex`.
  - `PdfCatalog::entry` exposes raw Catalog entries such as `ViewerPreferences`, `Outlines`, `PageLabels`, `Dests`, `Threads`, `OpenAction`, `Collection`, and `Names`.
  - `PdfPage::entry`, `PdfPage::resolve_entry`, and page access methods provide raw page dictionary access for `Thumb`, `Dur`, `Trans`, `PresSteps`, `B`, and other page-level entries.
  - Existing name-tree lookup is exact-byte and single-key oriented; collection and named-destination features need enumeration as well as lookup.
- **Implications**:
  - Add navigation APIs inside `src/reader` so they can use private `PdfDocument.file`, `PdfDocument.catalog`, and `PdfPage.record` without exposing lower-level state.
  - Extend the name-tree support with reusable enumeration rather than duplicating name-tree traversal in collection code.
  - Keep lower packages unchanged; this is a reader-layer structural metadata feature.

### ISO 32000-2 Clauses 12.1 Through 12.4
- **Context**: Requirements were generated from `spec/extracted/12.1-12.4-interactive-navigation.spec.txt` and cover viewer preferences, destinations, outlines, thumbnails, collections, page labels, articles, presentations, and sub-page navigation.
- **Sources Consulted**:
  - `spec/extracted/12.1-12.4-interactive-navigation.spec.txt`
  - `.kiro/specs/pdf-interactive-navigation/requirements.md`
  - `spec/extracted/7.7-document-structure.spec.txt`
  - `spec/extracted/7.9-common-data.md`
  - `spec/extracted/7.11-file-specs.md`
- **Findings**:
  - Viewer preferences, outlines, collections, page labels, articles, and presentations are all represented by Catalog or Page dictionary entries and indirect object graphs.
  - Explicit destinations have a compact array grammar whose first operand depends on context: local page reference, remote page index, local structure element reference, or remote structure ID bytes.
  - Named destinations can come from the legacy Catalog `Dests` dictionary keyed by `PdfName` or from the Catalog `Names` dictionary `Dests` name tree keyed by byte strings.
  - Collections depend on the `EmbeddedFiles` name tree and introduce folder association through text-string keys that may begin with a folder ID tag.
  - Page labels depend on number-tree traversal, which is similar to name-tree traversal but uses integer keys and range selection.
- **Implications**:
  - The design needs reusable name-tree enumeration and a new number-tree reader in `src/reader`.
  - Destination parsing must be context-aware so future `pdf-actions` and `pdf-annotations` implementations can reuse it for Go-To, remote Go-To, embedded Go-To, and link annotations without re-parsing destination arrays.
  - Collection parsing should expose file associations as raw `PdfObject` file specification values until a file-specification feature owns typed file-spec dictionaries.

### Adjacent Spec Boundaries
- **Context**: Interactive navigation references actions, annotations, embedded files, logical structure, optional content, graphics transitions, and forms. Discovery checked which related specs already exist.
- **Sources Consulted**:
  - `.kiro/specs/pdf-actions/requirements.md`
  - `.kiro/specs/pdf-actions/spec.json`
  - `.kiro/specs/pdf-annotations/requirements.md`
  - `.kiro/specs/pdf-annotations/spec.json`
  - `.kiro/specs/pdf-content-streams/design.md`
  - `.kiro/specs/pdf-graphics/design.md`
  - `.kiro/specs/pdf-document-structure/design.md`
- **Findings**:
  - `pdf-actions` is approved at requirements phase and owns action dictionary semantics, trigger ordering, GoTo variants, URI, JavaScript, transition actions, and action execution semantics.
  - `pdf-annotations` is approved at requirements phase and owns annotation dictionaries, annotation flags, link annotations, annotation tab order, and annotation handlers.
  - `pdf-document-structure` intentionally exposed optional Catalog entries such as `PageLabels`, `Outlines`, and `StructTreeRoot` as raw values for later specs.
  - `pdf-graphics` and `pdf-rendering` own graphics interpretation and rendering. Navigation presentation dictionaries can parse transition metadata but must not render transitions.
- **Implications**:
  - This design owns structural parsing of navigation dictionaries but hands action dictionaries out as raw objects.
  - Outline item activation, link annotation activation, JavaScript, URI handling, form submission, multimedia, and user-interface presentation remain out of boundary.
  - Structure destination page resolution is limited to raw traversal needed by this feature and must be revalidated if a future logical-structure feature adds typed structure-tree semantics.

### MoonBit Implementation Constraints
- **Context**: The design must produce executable implementation tasks for the current MoonBit codebase.
- **Sources Consulted**:
  - `.kiro/steering/product.md`
  - `.kiro/steering/tech.md`
  - `.kiro/steering/structure.md`
  - `<local>/.codex/skills/moonbit-agent-guide/SKILL.md`
  - `<local>/.codex/skills/moonbit-lang/SKILL.md`
  - `moon.mod.json`
  - `src/reader/moon.pkg`
- **Findings**:
  - Steering requires standard library only, native primary target, wasm secondary target, byte-oriented parsing, lazy object resolution, and package-local testing.
  - `src/reader` already imports the local packages needed by this feature: `objects`, `lexer`, `parser`, `filters`, `content`, and `graphics`.
  - MoonBit conventions favor explicit structs, `pub(all) enum` for externally pattern-matchable variants, `suberror` diagnostics, cohesive files, and `moon info` review for public API changes.
- **Implications**:
  - No Web or third-party dependency research is needed; the selected approach uses existing local packages and MoonBit standard data structures only.
  - Add `PdfNavigationError` and wrap it from `PdfDocumentError` rather than overloading low-level parse or reader errors.
  - Tests should be white-box focused in `src/reader` because most helpers need access to package-private document/page state.

## Architecture Pattern Evaluation

| Option | Description | Strengths | Risks / Limitations | Notes |
|--------|-------------|-----------|---------------------|-------|
| Add all navigation parsing directly to `PdfDocument` methods | Implement viewer preferences, outlines, collections, and presentations in one file | Minimal number of files | Large unfocused file, weak task boundaries, difficult review | Rejected |
| New `src/navigation` package | Put all interactive navigation models in a downstream package | Strong package boundary and independent API | Cannot access private `PdfDocument` and `PdfPage` state without expanding public reader internals; adds a new dependency direction | Rejected for this phase |
| Focused navigation files inside `src/reader` | Add cohesive files for viewer preferences, destinations, outlines, collections, page labels, articles, presentations, and shared tree traversal | Preserves current dependency direction, uses existing reader facade, supports package-private helpers, keeps tests local | Expands `src/reader` public API and requires careful file boundaries | Selected |

## Synthesis Outcomes
- **Generalization**: Named destinations, collection files, embedded files, and page labels all require tree traversal over Catalog entries. The design generalizes name-tree enumeration and number-tree lookup while keeping feature-specific parser components small and direct.
- **Generalization**: Outline items, article beads, collection folders, and navigation nodes are all linked object graphs. The design applies one bounded traversal policy: load through `PdfFile::load_object`, validate expected dictionary type, track visited `ObjectId` values, and raise a navigation error on cycles or malformed links.
- **Build vs. Adopt**: No external library is adopted. ISO dictionary parsing, number-tree traversal, and linked PDF object validation are project-domain behavior that must align with existing `PdfObject`, `PdfDictionary`, `PdfName`, and `PdfFile` contracts.
- **Simplification**: The design does not introduce UI models, renderer callbacks, action execution, annotation handlers, JavaScript, or file-system access. It exposes raw action and file-specification values at the navigation boundary until adjacent specs own typed semantics.

## Design Decisions

### Decision: Reader-Layer Navigation Metadata
- **Context**: Interactive navigation data is reached through already validated Catalog and Page objects.
- **Alternatives Considered**:
  1. Extend `PdfFile` with navigation methods.
  2. Create a new `src/navigation` package.
  3. Add focused navigation files to `src/reader`.
- **Selected Approach**: Add `viewer_preferences.mbt`, `destination.mbt`, `outline.mbt`, `thumbnail.mbt`, `collection.mbt`, `page_labels.mbt`, `articles.mbt`, `presentation.mbt`, and shared tree helpers inside `src/reader`.
- **Rationale**: `src/reader` is already the downstream document access package and can use private document/page state without exposing low-level file internals.
- **Trade-offs**: `src/reader` grows, so file boundaries and tests must stay cohesive.
- **Follow-up**: Verify `moon info` shows only intended `src/reader` public API additions.

### Decision: Parse Navigation Structures, Do Not Execute Viewer Behavior
- **Context**: Requirements use interactive PDF processor language, but the product goal is a PDF parser library.
- **Alternatives Considered**:
  1. Model and simulate viewer behavior such as hiding toolbars, opening outlines, selecting thumbnails, sorting collection UI, and running transitions.
  2. Parse and validate the PDF data structures while exposing typed metadata and raw downstream-owned values.
- **Selected Approach**: The parser returns typed viewer preferences, destinations, outlines, thumbnails, collections, page labels, threads, transition dictionaries, and navigation nodes. It never performs UI actions, rendering, action execution, or file-system operations.
- **Rationale**: This satisfies parser-library responsibilities and keeps actions, annotations, rendering, and application UI in their own boundaries.
- **Trade-offs**: A viewer application must interpret the returned metadata itself.
- **Follow-up**: Downstream action and annotation specs should consume destination parsing contracts instead of duplicating them.

### Decision: Context-Aware Destination Parsing
- **Context**: Destination arrays use the same view syntax but the first element changes by context.
- **Alternatives Considered**:
  1. Parse the first element as a raw `PdfObject` and leave all interpretation to callers.
  2. Require callers to choose a `DestinationContext` and return a typed `PdfDestinationTarget`.
- **Selected Approach**: Destination parsing accepts `DestinationContext` and returns a typed `PdfDestination` with `PdfDestinationTarget` and `PdfDestinationView`.
- **Rationale**: This makes the syntax reusable for local destinations, structure destinations, remote destinations, and future action parsing while avoiding ambiguous inference.
- **Trade-offs**: Callers must know their context. That is already true in the PDF specification.
- **Follow-up**: Revalidate this contract when `pdf-actions` designs GoToR and GoToE parsing.

### Decision: Reusable Tree Enumeration
- **Context**: Current name-tree support provides exact-key lookup but collection and validation workflows need full entry enumeration. Page labels also require range lookup over number-tree keys.
- **Alternatives Considered**:
  1. Implement tree traversal separately in named destinations, collection, and page labels.
  2. Extend reader helpers with `name_tree_entries` and `number_tree_lookup_range`.
- **Selected Approach**: Add shared name-tree enumeration and number-tree traversal helpers in `src/reader`.
- **Rationale**: The same validation rules apply across these features: `Kids` versus leaf arrays, `Limits`, sorted keys, pair arrays, indirect-reference loading, and cycle detection.
- **Trade-offs**: The shared helpers become part of the reader navigation substrate and must remain byte/integer generic rather than feature-specific.
- **Follow-up**: Keep public exposure minimal; feature APIs should consume helpers internally unless callers need enumerated names.

### Decision: Raw Hand-Off for Actions and File Specifications
- **Context**: Outlines, navigation nodes, destinations, collections, and articles refer to actions, file specifications, embedded files, and metadata streams whose full semantics are outside this spec.
- **Alternatives Considered**:
  1. Add partial typed action and file-specification models now.
  2. Store and expose raw `PdfObject` values for downstream specs.
- **Selected Approach**: Navigation structures expose action dictionaries, file specifications, collection item dictionaries, metadata streams, and unknown layout names as raw `PdfObject` values or `PdfName` values where the current spec does not own semantics.
- **Rationale**: This prevents hidden ownership conflicts with `pdf-actions`, `pdf-annotations`, and future file-specification work.
- **Trade-offs**: Consumers get structural navigation metadata now but must wait for adjacent specs for richer action and file-spec interpretation.
- **Follow-up**: Revalidate when those specs add typed APIs that should replace raw fields.

### Decision: Additive Reader Public Surface
- **Context**: The existing document-structure APIs are already public and downstream specs depend on their Catalog, Page, page-index, and name-tree behavior.
- **Alternatives Considered**:
  1. Replace raw Catalog and Page entry APIs with fully typed navigation accessors.
  2. Add navigation accessors beside the existing raw entry APIs and keep raw access available.
- **Selected Approach**: Add navigation-specific `PdfDocument` and `PdfPage` methods while preserving existing raw entry access and page traversal contracts.
- **Rationale**: The feature can provide typed metadata without breaking existing tests or downstream specs that still need raw PDF values.
- **Trade-offs**: Some information is reachable through both raw and typed paths, so documentation and tests must make the typed path authoritative only for clause 12.1 through 12.4 navigation metadata.
- **Follow-up**: Verify `moon info` after implementation to ensure public API changes are intentional and additive.

## Risks & Mitigations
- The requirements combine several independent ISO subclauses under one feature — mitigate with boundary-first design and cohesive per-domain files so implementation tasks remain bounded.
- Linked object graphs such as outlines, article beads, folders, and navigation nodes can cycle — mitigate with `ObjectId` visited sets and maximum traversal policies tied to loaded indirect references.
- Name-tree and number-tree traversal can silently accept malformed arrays — mitigate by validating pair counts, key types, child-reference types, and `Limits` ordering before returning values.
- Text-string normalization for collection folder names can be broader than current byte-oriented infrastructure — mitigate by storing raw bytes, validating byte-level forbidden values, and isolating normalization policy behind a navigation text-name helper that can be revalidated when common text-string decoding becomes available.
- Adjacent action, annotation, logical-structure, and file-specification specs may later change ownership — mitigate with explicit revalidation triggers and raw hand-off contracts.

## References
- `spec/extracted/12.1-12.4-interactive-navigation.spec.txt` — local ISO 32000-2:2020 clause 12.1 through 12.4 excerpt.
- `.kiro/specs/pdf-interactive-navigation/requirements.md` — authoritative requirements for this feature.
- `.kiro/specs/pdf-document-structure/design.md` — upstream `PdfDocument`, Catalog, Page, Page tree, and Name dictionary contracts.
- `.kiro/specs/pdf-actions/requirements.md` — adjacent action dictionary and action execution scope.
- `.kiro/specs/pdf-annotations/requirements.md` — adjacent annotation and link annotation scope.
- `spec/extracted/7.9-common-data.md` — name tree and number tree background.
- `spec/extracted/7.11-file-specs.md` — collection item and file-specification references used as raw hand-off data.
- `.kiro/steering/product.md`, `.kiro/steering/tech.md`, `.kiro/steering/structure.md` — project-wide MoonBit, dependency, and PDF parsing guidance.
