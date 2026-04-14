# Research & Design Decisions

## Summary
- **Feature**: `pdf-interchange-basics`
- **Discovery Scope**: Extension / Integration-focused discovery
- **Key Findings**:
  - The repository already exposes the file identifier pair through `TrailerInfo.id`, recognizes the deprecated `ProcSet` resource category in `@content.ContentResources`, and parses marked-content operators as standard content operators. The design extends these contracts instead of replacing them.
  - Document-level `Metadata`, object-level `Metadata`, trailer `Info`, `PieceInfo`, and marked-content property lists are interchange metadata, not rendering state. They should be preserved structurally and validated at the layer that owns the source object.
  - Project steering makes PDF writing a non-goal. Metadata reconciliation and file-identifier generation rules are therefore represented as read-side preservation and diagnostics, not writer mutation behavior.

## Research Log

### Existing File and Document Boundaries
- **Context**: Requirements 2.3 and 3 depend on the trailer `Info` and `ID` entries, while requirement 2.2 depends on Catalog and object-level `Metadata` entries.
- **Sources Consulted**:
  - `src/reader/types.mbt`
  - `src/reader/trailer.mbt`
  - `src/reader/document.mbt`
  - `src/reader/catalog.mbt`
  - `.kiro/specs/pdf-file-structure/design.md`
  - `.kiro/specs/pdf-document-structure/design.md`
- **Findings**:
  - `TrailerInfo` already stores `info : ObjectId?`, `id : PdfFileId?`, and `raw_dict`.
  - PDF 2.0 trailer parsing already requires `ID` and validates it as an array of two byte strings.
  - `PdfCatalog::entry` exposes raw optional Catalog entries such as `Metadata` and `PieceInfo`, but no typed interchange API validates the referenced stream or dictionary.
- **Implications**:
  - Keep file-level trailer validation in `src/reader/trailer.mbt`.
  - Add reader facade APIs that resolve and validate `Info`, `Metadata`, `ID`, and Catalog `PieceInfo` without changing `PdfFile::open`.
  - Preserve raw dictionaries and streams for downstream consumers and future writer support.

### Existing Content Stream and Graphics Boundaries
- **Context**: Requirements 2, 4.1, and 4.2 concern procedure sets, marked-content operators, property lists, and proper BMC/BDC/EMC nesting with BT/ET.
- **Sources Consulted**:
  - `src/content/operator.mbt`
  - `src/content/parser.mbt`
  - `src/content/resources.mbt`
  - `src/content/resources_wbtest.mbt`
  - `src/graphics/object_context.mbt`
  - `src/graphics/interpreter.mbt`
  - `.kiro/specs/pdf-content-streams/design.md`
  - `.kiro/specs/pdf-graphics/design.md`
- **Findings**:
  - `@content.StandardContentOperator` already recognizes `MP`, `DP`, `BMC`, `BDC`, and `EMC`.
  - `ContentResources` already models the `Properties` and `ProcSet` resource categories.
  - The graphics object context rejects path operators inside text objects and recognizes marked-content operators, but it does not enforce separate BMC/BDC/EMC nesting relative to BT/ET for a generic interchange consumer.
- **Implications**:
  - Add a content-layer marked-content analyzer over parsed `ContentOperation` values. It should validate operands, scope balance, page-stream containment, and text-object nesting without rendering.
  - Keep optional-content visibility in `src/graphics`; reuse the analyzer's property-list normalization where helpful.
  - Add typed `ProcSet` enumeration and validation without changing normal resource lookup semantics.

### Metadata Streams and XMP
- **Context**: Requirements 2.1 through 2.4 distinguish metadata streams from document information dictionaries and prefer XMP metadata streams in PDF 2.0.
- **Sources Consulted**:
  - `spec/extracted/14.1-14.6-interchange-basics.spec.txt`
  - `src/reader/public_api_wbtest.mbt`
  - `src/graphics/icc_profile.mbt`
  - `src/graphics/form_xobject.mbt`
  - `.kiro/steering/product.md`
  - `.kiro/steering/tech.md`
- **Findings**:
  - Metadata streams must have `/Type /Metadata` and `/Subtype /XML`.
  - Metadata stream payload is XML governed by ISO 16684-1 XMP, but project steering currently allows only the MoonBit standard library and local packages.
  - Existing code preserves metadata entries raw in several places, including Catalog raw access, ICC profile streams, and Form XObject descriptors.
- **Implications**:
  - Validate metadata stream dictionary shape and expose decoded XML bytes, while treating XMP schema interpretation as out of boundary.
  - Do not introduce an XML parser dependency in this spec.
  - Provide read-side source summaries that expose both Info dictionary dates and metadata streams, allowing consumers to make their own reconciliation decisions.

### Page-Piece Dictionaries
- **Context**: Requirement 4 covers `PieceInfo` on Catalog, Page, and Form XObject dictionaries, including private processor data keyed by second-class names.
- **Sources Consulted**:
  - `spec/extracted/14.1-14.6-interchange-basics.spec.txt`
  - `src/reader/document_structure.mbt`
  - `src/graphics/form_xobject.mbt`
  - `src/reader/structural_helpers.mbt`
  - `.kiro/specs/pdf-xobjects-images/design.md`
- **Findings**:
  - `PdfPage` exposes direct page dictionary entries and can resolve indirect page entry values.
  - `FormXObject` currently preserves `Metadata` and associated-file entries but not `PieceInfo`.
  - Page-piece data dictionaries require `LastModified` and optional `Private`, but private payload semantics belong to the producer and should remain raw.
- **Implications**:
  - Define shared interchange value models for page-piece dictionaries so both reader and graphics can expose the same shape.
  - Validate `PieceInfo` entry shape, data dictionaries, required `LastModified` text bytes, and raw `Private` preservation.
  - Compare modification dates only for exact byte equality when diagnostics need freshness checks; never order dates.

### External Dependency Verification
- **Context**: Discovery requires checking new dependencies and compatibility.
- **Sources Consulted**:
  - `.kiro/steering/tech.md`
  - Existing `moon.pkg` files under `src/`
  - MoonBit local package layout observed in the repository
- **Findings**:
  - Steering requires standard-library-only implementation.
  - Existing local packages provide the needed inputs: `objects`, `filters`, `content`, `graphics`, and `reader`.
  - No third-party PDF, XML, date, hashing, or PostScript dependency is required for this read-side structural layer.
- **Implications**:
  - No web or library-version research is needed.
  - File-identifier generation and XMP semantic parsing stay out of boundary until the project explicitly adds writer or XML support.

## Architecture Pattern Evaluation

| Option | Description | Strengths | Risks / Limitations | Notes |
|--------|-------------|-----------|---------------------|-------|
| Add all interchange logic to `src/reader` | Reader parses metadata, piece info, proc sets, and marked content | Simple for document metadata | Blurs content syntax ownership and cannot be reused by graphics marked-content consumers | Rejected |
| Add all interchange logic to `src/content` | Content parser owns marked content, metadata, page pieces, and file IDs | Good for marked content | Content would need file and document knowledge, reversing boundaries | Rejected |
| Shared `src/interchange` plus package-specific bridges | Shared value models and validators for generic interchange dictionaries; reader/content/graphics expose owner-specific APIs | Avoids duplicate metadata and page-piece validation while preserving dependency direction | Adds one local package and public API surface | Selected |
| Adopt XML and date parsing dependencies | Parse XMP and date equivalence fully | Richer metadata summaries | Violates current no-external-dependency steering and exceeds read-only scope | Rejected |

## Design Decisions

### Decision: Preserve Metadata Sources Without XMP Interpretation
- **Context**: Requirements 2.1 through 2.4 mention XMP metadata streams, document information dictionaries, and reconciliation rules.
- **Alternatives Considered**:
  1. Parse XMP into a typed metadata model.
  2. Preserve stream bytes and validate stream dictionary shape only.
  3. Ignore metadata streams as raw Catalog entries.
- **Selected Approach**: Validate metadata stream `/Type /Metadata` and `/Subtype /XML`, decode stream bytes through the existing filter pipeline when the reader owns loading, and expose the raw XML bytes and raw stream.
- **Rationale**: This satisfies read-side structural requirements and keeps the design aligned with standard-library-only steering.
- **Trade-offs**: Consumers do not receive parsed `dc:title`, `xmp:CreateDate`, or `xmp:ModifyDate` values from this spec.
- **Follow-up**: Revalidate if a future XMP parser or PDF writer spec is introduced.

### Decision: Treat Writer Rules as Read-Side Boundary Notes
- **Context**: Requirements 2.4 and 3 include writing rules for metadata reconciliation and file identifier generation.
- **Alternatives Considered**:
  1. Add writer mutation APIs now.
  2. Add generator stubs for IDs and metadata updates.
  3. Expose read-side data and explicit diagnostics while excluding mutation.
- **Selected Approach**: Expose `PdfFileId`, document information dictionary data, and metadata stream data. Do not generate identifiers, update IDs, or reconcile metadata during writing.
- **Rationale**: Product steering states that PDF generation is out of scope for Phase 1.
- **Trade-offs**: Some normative writer behavior is documented but not executable in this library phase.
- **Follow-up**: A future writer spec must revalidate identifier generation, MD5 or replacement digest policy, incremental update behavior, and XMP equivalence rules.

### Decision: Shared Interchange Package for Generic Dictionaries
- **Context**: Metadata streams and page-piece dictionaries can appear on Catalog, Pages, Page, Form XObjects, and other stream or dictionary components.
- **Alternatives Considered**:
  1. Duplicate parsing in `reader` and `graphics`.
  2. Move shared parsing into `objects`.
  3. Add a small `src/interchange` package downstream of `objects`, `filters`, and `content`.
- **Selected Approach**: Add `src/interchange` for shared metadata stream, document info, page-piece, procedure-set, and marked-content data models where they do not require reader-owned object loading.
- **Rationale**: `objects` should stay a low-level PDF object model, while interchange is a higher-level ISO clause 14 concern.
- **Trade-offs**: A new package requires `moon.pkg` updates and API review with `moon info`.
- **Follow-up**: Keep package dependencies acyclic: `objects, filters, content -> interchange -> graphics/reader`.

### Decision: Validate Marked-Content Structure Over Parsed Instructions
- **Context**: Requirement 4.1 requires balanced marked-content sequences and proper nesting with text objects.
- **Alternatives Considered**:
  1. Enforce all marked-content rules inside `ContentStreamParser`.
  2. Enforce marked-content rules only in the graphics interpreter.
  3. Add a separate analyzer over parsed `ContentInstruction` arrays.
- **Selected Approach**: Add a `MarkedContentAnalyzer` that consumes parsed instructions, validates operands and scope nesting, resolves named property-list references through `ContentResources`, and returns a structural summary.
- **Rationale**: The content parser remains a syntactic iterator, and non-rendering consumers can validate marked content without constructing a graphics interpreter.
- **Trade-offs**: Consumers must opt into structural analysis after parsing.
- **Follow-up**: Revalidate when logical structure, Tagged PDF, or associated-files specs need richer marked-content reference semantics.

## Risks & Mitigations
- XMP metadata may contain important fields that this spec does not parse - mitigate by exposing exact decoded XML bytes and raw streams.
- Adding a shared `src/interchange` package could create dependency cycles - mitigate by allowing it to import only `objects`, `filters`, and `content`, never `graphics` or `reader`.
- Tightening `ProcSet` validation may break permissive existing resource lookups - mitigate by adding typed `proc_sets()` validation while keeping raw `lookup_resource(ProcSet, name)` behavior.
- Marked-content analysis may overlap with optional-content visibility - mitigate by making optional-content evaluation continue to live in `graphics`, while `interchange` owns only generic property-list shape and scope balance.
- Page-piece `LastModified` date ordering is explicitly unreliable - mitigate by comparing exact bytes only and never using chronological ordering.

## References
- `spec/extracted/14.1-14.6-interchange-basics.spec.txt` - Local ISO 32000-2:2020 source excerpt for this spec.
- `.kiro/specs/pdf-file-structure/design.md` - Existing trailer, `Info`, and `ID` ownership boundary.
- `.kiro/specs/pdf-document-structure/design.md` - Existing Catalog and Page ownership boundary.
- `.kiro/specs/pdf-content-streams/design.md` - Existing content operator and resource dictionary boundary.
- `.kiro/specs/pdf-graphics/design.md` - Existing graphics object context and marked-content event boundary.
- `.kiro/specs/pdf-xobjects-images/design.md` - Existing Form XObject and optional-content boundary.
- `.kiro/steering/product.md` - Read-only product scope and writer non-goals.
- `.kiro/steering/tech.md` - MoonBit, package, dependency, and validation constraints.
