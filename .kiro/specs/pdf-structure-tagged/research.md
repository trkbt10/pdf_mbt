# Research & Design Decisions

## Summary
- **Feature**: `pdf-structure-tagged`
- **Discovery Scope**: Extension / Integration-focused discovery
- **Key Findings**:
  - The existing `reader` package already owns Catalog, Page, annotation, name-tree, number-tree, and lazy indirect-object loading. Logical structure therefore belongs at the reader facade rather than in `objects`, `content`, or `graphics`.
  - Tagged PDF requires two related but distinct capabilities: preserving the logical structure tree and producing opt-in conformance diagnostics. The design separates read-side structural models from stricter Tagged PDF validation reports.
  - No new external dependency is required. Standard structure types, attributes, namespaces, role maps, artifacts, and language properties can be represented as typed MoonBit value models over existing `PdfObject` dictionaries.

## Research Log

### Reader and Document Boundary
- **Context**: The structure tree root is reached from Catalog `StructTreeRoot`; mark information and document language are Catalog entries; parent tree and ID tree traversal require indirect object loading.
- **Sources Consulted**:
  - `src/reader/catalog.mbt`
  - `src/reader/document_types.mbt`
  - `src/reader/document_error.mbt`
  - `src/reader/number_tree.mbt`
  - `.kiro/specs/pdf-document-structure/design.md`
  - `.kiro/specs/pdf-annotations/design.md`
- **Findings**:
  - `PdfCatalog::entry` already exposes raw `MarkInfo`, `StructTreeRoot`, and `Lang` entries.
  - `PdfDocument` holds the `PdfFile` and Catalog and is the correct layer for resolving indirect structure objects.
  - Number-tree traversal exists in `src/reader/number_tree.mbt`; the ParentTree can reuse the same traversal policy but needs structure-specific value validation.
  - Annotation parsing already preserves `StructParent` and `Lang`, which can be consumed by structure association checks without changing annotation ownership.
- **Implications**:
  - Add reader-local structure files instead of adding a new package.
  - Keep Catalog optional-entry recognition in `catalog.mbt`; add typed structure accessors in dedicated `structure_*` files.
  - Add `InvalidStructure` or equivalent structure-specific errors to `PdfDocumentError`.

### Content and Object Association Boundary
- **Context**: Structure elements can reference marked-content sequences, complete PDF objects, annotations, and XObjects through `K`, MCR, OBJR, `StructParent`, `StructParents`, and ParentTree entries.
- **Sources Consulted**:
  - `src/content/operator.mbt`
  - `src/content/resources.mbt`
  - `src/graphics/form_xobject.mbt`
  - `.kiro/specs/pdf-content-streams/design.md`
  - `.kiro/specs/pdf-xobjects-images/design.md`
  - `.kiro/specs/pdf-interchange-basics/design.md`
- **Findings**:
  - `@content.StandardContentOperator` already recognizes marked-content operators.
  - `ContentResources` already exposes `Properties`, and Form XObjects already validate `StructParent` and `StructParents` exclusivity.
  - Logical structure should not parse or render content streams by default; it should validate references and provide enough keys for downstream content extraction to correlate MCIDs.
- **Implications**:
  - The structure model stores content-item references and parent-tree lookups, not decoded page text.
  - Content-stream scanning for actual MCID operators remains opt-in through a future analyzer or existing content parsing APIs.
  - Structure association APIs can report mismatches between `K` references and ParentTree entries when enough owner context is available.

### Tagged PDF Semantics
- **Context**: Requirements 1.1 through 1.47 add Tagged PDF rules over the generic logical structure tree: real content versus artifacts, logical order, standard structure types, attributes, and namespaces.
- **Sources Consulted**:
  - `.kiro/specs/pdf-structure-tagged/requirements.md`
  - `spec/extracted/14.7-14.13-structure-tagged.spec.txt`
  - `.kiro/specs/pdf-text/design.md`
  - `.kiro/specs/pdf-forms-signatures/design.md`
- **Findings**:
  - Tagged PDF conformance is broader than reading the structure tree. Some checks need text extraction, font Unicode mapping, or content-stream inspection that are not owned by this spec.
  - Standard structure type handling can be modeled as a catalog of known names, categories, and supplemental constraints, with unknown names preserved and resolved through role maps.
  - Full PDF/UA behavior and screen-reader policy are out of scope; this feature only exposes the declarative PDF inputs.
- **Implications**:
  - Add `PdfTaggedPdfReport` as an opt-in validation report with warnings for checks that require downstream text or rendering context.
  - Keep the reader API read-only and non-rendering.
  - Preserve raw objects for roles, attributes, and properties so future extraction and accessibility specs can build on them.

### Attributes, Namespaces, and Accessibility Properties
- **Context**: Structure elements can carry direct attributes, class-map attributes, user properties, namespace-specific owners, language, alternate text, replacement text, abbreviation expansion, and pronunciation hints.
- **Sources Consulted**:
  - `.kiro/specs/pdf-structure-tagged/requirements.md`
  - `src/reader/document_types.mbt`
  - `src/reader/forms_types.mbt`
  - `src/reader/annotations.mbt`
- **Findings**:
  - Attribute precedence depends on direct `A`, class-map `C`, format-specific owners, standard owners, inheritance, and defaults.
  - User properties are attribute objects owned by `UserProperties` and can contain arbitrary PDF values; non-text, non-number, and non-boolean values must not be treated as errors.
  - Natural language is hierarchical: Catalog `Lang`, structure element `Lang`, marked-content Span property `Lang`, and Unicode text-string language escapes are distinct sources.
- **Implications**:
  - Add a resolver that reports the source of each resolved attribute or property instead of flattening away provenance.
  - Keep arbitrary attribute objects and user-property values raw where the standard permits extensibility.
  - Natural-language APIs expose effective language from Catalog and structure hierarchy, while text-string language escapes remain a text-string parsing concern.

### External Dependency Verification
- **Context**: Discovery requires checking whether new dependencies are needed for XML namespaces, URI handling, MathML, text segmentation, or accessibility export.
- **Sources Consulted**:
  - `.kiro/steering/tech.md`
  - Existing `moon.pkg` files under `src/`
  - Local ISO excerpts under `spec/extracted/`
- **Findings**:
  - Steering requires standard-library-only implementation.
  - Namespace names, schema references, MathML namespace membership, and role maps are represented as strings, dictionaries, file specifications, and raw references; no XML parser is needed.
  - Unicode segmentation, bidirectional processing, PDF/UA validation, and text-to-speech behavior exceed the current read-side parser scope.
- **Implications**:
  - No web or third-party library research is needed.
  - The design uses exact bytes and `PdfName` values rather than URI, XML, or Unicode-normalization dependencies.
  - Future accessibility export work must revalidate text extraction, Unicode mapping, and segmentation responsibilities.

## Architecture Pattern Evaluation

| Option | Description | Strengths | Risks / Limitations | Notes |
|--------|-------------|-----------|---------------------|-------|
| Put logical structure in `src/objects` | Add structure tree parsing near raw object types | Low-level reuse | Reverses abstraction: structure needs Catalog and object loading | Rejected |
| Put logical structure in `src/content` | Treat MCID and artifacts as content-stream concerns | Good for operator scanning | Cannot own Catalog `StructTreeRoot`, ParentTree, IDTree, or attributes | Rejected |
| Add a new `src/structure` package | Shared structure models independent of reader | Clear domain package | Needs indirect-object loading or callback interfaces not used elsewhere | Rejected for current codebase |
| Extend `src/reader` with structure-specific files | Use existing document facade and lazy loader | Fits current Catalog/Page/annotation pattern and dependency direction | Increases reader package size | Selected |
| Implement full accessibility export now | Convert structure tree into text or HTML-like output | End-user oriented | Requires text extraction, Unicode mapping, rendering policy, and PDF/UA decisions | Rejected |

## Design Decisions

### Decision: Reader-Owned Logical Structure Facade
- **Context**: `StructTreeRoot`, ParentTree, IDTree, MarkInfo, and Catalog `Lang` all require document-level context.
- **Alternatives Considered**:
  1. Add a new package with callback-based object loading.
  2. Add all logic to `document_structure.mbt`.
  3. Add focused `structure_*` files inside `src/reader`.
- **Selected Approach**: Add focused reader files for mark information, structure tree traversal, elements, content references, namespaces, attributes, standard type metadata, Tagged PDF reports, and accessibility properties.
- **Rationale**: This preserves existing dependency direction and follows the pattern used by annotations, actions, forms, multimedia, and requirements.
- **Trade-offs**: The reader package grows, so file boundaries and tests must stay cohesive.
- **Follow-up**: Revalidate if the project later introduces a dedicated package for clause 14 shared models.

### Decision: Separate Structure Reading from Tagged PDF Conformance
- **Context**: A PDF can have logical structure without being fully tagged, while Tagged PDF adds additional rules and diagnostics.
- **Alternatives Considered**:
  1. Fail structure-tree parsing when any Tagged PDF rule is violated.
  2. Ignore Tagged PDF rules and only expose raw structure.
  3. Parse structure tree permissively and provide opt-in conformance reports.
- **Selected Approach**: `PdfDocument::structure_tree` returns structural data; `PdfDocument::tagged_pdf_report` evaluates Tagged PDF checks and reports errors or warnings.
- **Rationale**: This lets users inspect malformed or partially tagged files while still exposing conformance issues.
- **Trade-offs**: Consumers must opt into strict diagnostics.
- **Follow-up**: Future PDF/UA specs can add stricter profiles without changing the base structure API.

### Decision: Model Role Maps and Namespaces as Resolution Chains
- **Context**: Role maps can be transitive, circular, and namespace-specific.
- **Alternatives Considered**:
  1. Resolve only one role-map hop.
  2. Reject circular role maps.
  3. Preserve chains and stop when a recognized type is found or a visited name repeats.
- **Selected Approach**: Store the original type, namespace, resolution chain, final recognized type when present, and circular-chain marker when encountered.
- **Rationale**: This matches the standard's permissive role-map behavior and avoids losing producer intent.
- **Trade-offs**: Callers need to inspect both original and resolved types.
- **Follow-up**: Revalidate when Annex M namespace difference data is extracted.

### Decision: Resolve Attributes with Provenance
- **Context**: Attribute precedence includes direct `A`, class-map `C`, format-specific owners, standard owners, inheritance, and defaults.
- **Alternatives Considered**:
  1. Expose only raw `A` and `C`.
  2. Return a fully flattened map without source details.
  3. Return resolved attributes with source metadata and raw objects.
- **Selected Approach**: Attribute APIs expose both raw attribute objects and resolved values with source kind, owner, namespace, revision, inherited flag, and default flag.
- **Rationale**: Provenance is necessary for conformance checks and future export decisions.
- **Trade-offs**: The model is richer than a simple key-value map.
- **Follow-up**: Add owner-specific helpers incrementally for Layout, List, PrintField, Table, and Artifact.

### Decision: Keep Text Extraction and Rendering Out of Boundary
- **Context**: Several Tagged PDF checks mention Unicode mapping, word breaks, hidden content, layout, and screen-reader behavior.
- **Alternatives Considered**:
  1. Add text extraction and Unicode mapping to this feature.
  2. Add rendering/layout calculations to validate visual rectangles.
  3. Store declarative structure data and report checks requiring downstream context as warnings.
- **Selected Approach**: This spec exposes structure, attributes, content references, language, replacement text, and diagnostic hooks but does not extract text or render.
- **Rationale**: Steering and existing specs keep text extraction and rendering in separate domains.
- **Trade-offs**: Some conformance checks are partial until downstream text/rendering APIs are available.
- **Follow-up**: Revalidate with `pdf-text`, rendering, and PDF/UA-oriented specs.

## Risks & Mitigations
- Structure trees can be cyclic or extremely deep - mitigate with visited-object tracking and bounded traversal errors.
- ParentTree entries can disagree with `K` references - mitigate with opt-in cross-check diagnostics that identify both sources.
- Role maps may be circular - mitigate by preserving the chain and reporting a cycle instead of rejecting the whole tree.
- Full Tagged PDF conformance depends on external clauses and future text extraction - mitigate by separating structural parsing from conformance reports with explicit warning categories.
- User properties and private attributes may contain sensitive arbitrary data - mitigate by preserving raw values and documenting that policy/redaction belongs to callers.

## References
- `spec/extracted/14.7-14.13-structure-tagged.spec.txt` - Local ISO 32000-2:2020 source excerpt for logical structure and Tagged PDF.
- `.kiro/specs/pdf-structure-tagged/requirements.md` - Numeric requirement source for this design.
- `.kiro/specs/pdf-document-structure/design.md` - Existing Catalog, Page, name-tree, number-tree, and document facade boundary.
- `.kiro/specs/pdf-annotations/design.md` - Existing annotation parsing and `StructParent` preservation boundary.
- `.kiro/specs/pdf-content-streams/design.md` - Existing marked-content operator parsing boundary.
- `.kiro/specs/pdf-xobjects-images/design.md` - Existing XObject `StructParent` and `StructParents` metadata boundary.
- `.kiro/specs/pdf-text/design.md` - Text extraction and ActualText non-goals relevant to this spec boundary.
- `.kiro/steering/product.md` - Read-side product scope and writer non-goals.
- `.kiro/steering/tech.md` - MoonBit, package, dependency, and validation constraints.
