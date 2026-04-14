# Research & Design Decisions

## Summary
- **Feature**: `pdf-extensions`
- **Discovery Scope**: Extension
- **Key Findings**:
  - `Extensions` is a Catalog-owned, read-side interpretation and fits the existing `src/reader` document facade without changing `objects`, `parser`, xref, or stream decoding.
  - ISO 32000-2:2020 clause 7.12 requires the `Extensions` dictionary, developer extension dictionaries, and their entries to be direct objects; the design therefore validates directness instead of reusing generic indirect-resolution helpers.
  - `BaseVersion` must be parsed as major/minor integer components and compared to both the file header version and the optional Catalog `Version` entry, not as a floating-point number.

## Research Log

### Existing Reader Integration
- **Context**: The feature is reached through the document Catalog and depends on file version and Catalog entries.
- **Sources Consulted**: `src/reader/document_structure.mbt`, `src/reader/catalog.mbt`, `src/reader/document.mbt`, `src/reader/types.mbt`, `src/reader/document_error.mbt`, `.kiro/specs/pdf-document-structure/design.md`.
- **Findings**:
  - `PdfDocument::open` validates the Catalog through `load_catalog`, and `PdfDocument` retains private access to both `PdfFile` and `PdfCatalog`.
  - `PdfFile::version` exposes the header version as `PdfVersion`.
  - `PdfCatalog::entry` exposes raw Catalog values, which is sufficient for reading optional `Extensions` and optional Catalog `Version`.
  - Existing reader domain files add focused public `PdfDocument` accessors while keeping lower packages unchanged.
- **Implications**:
  - Add `src/reader/extensions.mbt` and `src/reader/extensions_types.mbt` inside the existing reader package.
  - Do not add new package dependencies or change lower-level object parsing.
  - Add an `InvalidExtension` reader diagnostic so extension errors are distinct from Catalog, navigation, and requirement errors.

### Direct Object Requirements
- **Context**: Clause 7.12 explicitly states that the extensions dictionary, developer extension dictionaries, and their entries shall be direct objects.
- **Sources Consulted**: `.kiro/specs/pdf-extensions/requirements.md`, `spec/extracted/7.12-extensions.spec.txt`, `src/objects/types.mbt`, `src/reader/structural_helpers.mbt`.
- **Findings**:
  - Existing `PdfObject::Ref` represents indirect references, and many reader helpers intentionally resolve references.
  - Extensions require the opposite behavior: any reference within `/Extensions`, developer entries, or known developer dictionary fields is malformed.
  - `structural_helpers.mbt` already has direct-object validation patterns, but its domain enum does not include extensions.
- **Implications**:
  - The extension parser must use local direct-object guards and must not call generic reference-resolving helpers for `/Extensions`.
  - Tests must cover indirect `/Extensions`, indirect developer dictionaries, indirect dictionary entries, and arrays containing references.

### Version Semantics
- **Context**: `BaseVersion` names are compared to the PDF version in the file header and optional Catalog `Version`, and the note forbids real-number interpretation.
- **Sources Consulted**: `.kiro/specs/pdf-extensions/requirements.md`, `src/reader/header.mbt`, `src/reader/types.mbt`.
- **Findings**:
  - The reader already models supported file versions as `PdfVersion { major, minor }`.
  - Header parsing accepts PDF 1.0 through 1.7 and PDF 2.0.
  - Catalog `Version` is currently available only as a raw Catalog entry.
- **Implications**:
  - Add package-private helpers to parse version names such as `/1.7` and `/2.0` into `PdfVersion`.
  - Compare `(major, minor)` lexicographically and never through `Double`.
  - Validate `BaseVersion <= header version` and `BaseVersion <= catalog Version` when the Catalog version is present.

### Registry Prefix Handling
- **Context**: Prefix keys are required to be registered prefix names, but the repository has no registry data dependency and steering forbids external dependencies.
- **Sources Consulted**: `.kiro/steering/tech.md`, `.kiro/specs/pdf-extensions/requirements.md`, existing reader designs for unknown or extensible names.
- **Findings**:
  - Existing designs preserve unknown names where ISO defines extensible vocabularies.
  - A live PDF Registry lookup would introduce a network or bundled data maintenance dependency not present in the project.
- **Implications**:
  - The parser treats every non-`Type` key in the Extensions dictionary as a declared developer prefix and preserves its exact `PdfName`.
  - Registry membership verification remains caller-owned or future policy-driven validation; the design covers structural conformance and prefix preservation.

## Architecture Pattern Evaluation

| Option | Description | Strengths | Risks / Limitations | Notes |
|--------|-------------|-----------|---------------------|-------|
| Reader-layer Catalog extension | Add typed `PdfDocument::extensions` access inside `src/reader`. | Matches existing Catalog metadata pattern, has private access to file and catalog version, no dependency change. | Adds another reader public model. | Selected. |
| Common-data package | Put version and extension models under `src/common_data`. | Reusable version parser. | Extensions depend on Catalog and document versions, so common data would need reader context or a premature abstraction. | Rejected for current scope. |
| Generic indirect resolver reuse | Reuse navigation or structural reference resolution. | Less code. | Violates direct-object requirements because references must be rejected, not resolved. | Rejected. |
| External registry validation | Validate prefix names against PDF Registry data. | Stronger registry conformance. | Adds external data dependency or stale bundled registry; conflicts with current standard-library-only policy. | Deferred. |

## Design Decisions

### Decision: Keep extensions in `src/reader`
- **Context**: `/Extensions` is a Catalog entry and validation needs header and Catalog version context.
- **Alternatives Considered**:
  1. Add a new `src/extensions` package.
  2. Add extension models to `src/common_data`.
  3. Add reader-local extension files.
- **Selected Approach**: Add reader-local `extensions.mbt`, `extensions_types.mbt`, `extensions_wbtest.mbt`, and small edits to `document_error.mbt` and `pkg.generated.mbti`.
- **Rationale**: The reader package already owns Catalog metadata, lazy document context, and document-layer errors.
- **Trade-offs**: The reader package grows, but no dependency boundary changes.
- **Follow-up**: Review `moon info` to confirm only intended reader APIs are exported.

### Decision: Validate directness locally
- **Context**: Clause 7.12 forbids indirect objects in the extensions dictionary tree.
- **Alternatives Considered**:
  1. Resolve references for convenience.
  2. Preserve raw references and leave validation to callers.
  3. Reject `PdfObject::Ref` wherever the extension tree requires direct objects.
- **Selected Approach**: Reject references in `/Extensions`, prefix dictionary values, array elements, and known developer dictionary entries.
- **Rationale**: This directly reflects the ISO conformance rule and avoids hiding malformed files behind resolution.
- **Trade-offs**: Some non-conforming PDFs are rejected by the typed API even if their referenced objects are otherwise loadable.
- **Follow-up**: Add malformed-fixture tests for every directness boundary.

### Decision: Model prefix groups explicitly
- **Context**: PDF 2.0 allows an array of developer extension dictionaries under one prefix.
- **Alternatives Considered**:
  1. Flatten all developer extension dictionaries into one array with repeated prefix fields only.
  2. Store a map from prefix to one dictionary.
  3. Store prefix groups containing one or more developer entries.
- **Selected Approach**: Use `PdfExtensionPrefixEntry { prefix, developers, raw_value }` and `PdfDeveloperExtension` entries.
- **Rationale**: This preserves the source grouping and supports both PDF 1.7 dictionary form and PDF 2.0 array form.
- **Trade-offs**: Callers do one extra level of traversal when they want all entries.
- **Follow-up**: Provide a simple `entries_for_prefix` helper if implementation finds repeated lookup code.

### Decision: Compare version names as integer pairs
- **Context**: The specification states that `BaseVersion` is not a real number.
- **Alternatives Considered**:
  1. Compare string bytes lexicographically.
  2. Parse as `Double`.
  3. Parse into `PdfVersion` integer components and compare tuples.
- **Selected Approach**: Parse names into `PdfVersion` and compare `(major, minor)` pairs.
- **Rationale**: It matches existing reader header representation and the specification note.
- **Trade-offs**: Version names outside the reader-supported grammar are invalid for this API.
- **Follow-up**: Tests must prove `/1.10` is greater than `/1.7` if multi-digit minors are accepted, or document the supported grammar if implementation restricts to reader-supported versions.

## Synthesis Outcomes
- **Generalization**: The core problem is Catalog-owned direct dictionary validation with version-name comparison. A small shared local version helper inside `extensions.mbt` is enough; no package-wide version abstraction is needed.
- **Build vs Adopt**: Build the parser with existing `PdfObject`, `PdfName`, `PdfDictionary`, and `PdfVersion`; no external library or registry dependency fits the project constraints.
- **Simplification**: One public accessor and two public model types cover the requirements. The design avoids a generic direct-object validator or registry service until another feature needs it.

## Risks & Mitigations
- Direct-object validation may accidentally resolve references through reused helpers - Keep extension parsing in a dedicated file and test `PdfObject::Ref` rejection at each level.
- Version comparison may drift from header parsing - Reuse the existing `PdfVersion` struct and add focused version-name tests.
- Registry prefix validation is not enforced - Preserve exact prefix names and document the registry-membership limitation as an explicit non-goal.
- PDF 2.0-only array and optional entries may appear in lower-version files - Gate array form, `URL`, and `ExtensionRevision` against the document version policy in tests.

## References
- `spec/extracted/7.12-extensions.spec.txt` - ISO 32000-2:2020 clause 7.12 extracted source text.
- `.kiro/specs/pdf-extensions/requirements.md` - Numeric requirement source for this design.
- `.kiro/specs/pdf-document-structure/design.md` - Existing Catalog and document facade ownership.
- `.kiro/steering/product.md`, `.kiro/steering/tech.md`, `.kiro/steering/structure.md` - Project goals, dependency policy, and package layout.
