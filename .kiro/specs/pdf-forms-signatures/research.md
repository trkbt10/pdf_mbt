# Research & Design Decisions

## Summary
- **Feature**: `pdf-forms-signatures`
- **Discovery Scope**: Extension / Complex Integration
- **Key Findings**:
  - The existing `src/reader` package already owns Catalog, Page, annotation, action, destination, name-tree, page-tree, and lazy object-loading contracts. Forms, FDF, signatures, measurement dictionaries, geospatial dictionaries, and document requirements should extend this reader layer rather than introduce a package that needs private file access.
  - Existing annotation and action implementations deliberately preserve form, widget, submit/reset/import, measure, and signature operands raw. This feature should replace those raw boundaries with typed structural parsing while continuing to avoid rendering, form filling, networking, PDF writing, JavaScript execution, and cryptographic signing.
  - Digital signature requirements span PDF object structure, byte ranges, CMS/CAdES/PAdES containers, PKIX certificate paths, CRL/OCSP revocation data, RFC 3161 timestamps, DSS/VRI storage, DocMDP/FieldMDP permissions, and legal attestations. The current project has no approved cryptographic dependency, so the design exposes verification inputs and validation plans while leaving cryptographic trust decisions to explicit handler boundaries.

## Research Log

### Existing Reader Integration Points
- **Context**: Requirements 0.1 through 0.64 describe Catalog entries (`AcroForm`, `Perms`, `Legal`, `DSS`, `Requirements`), Page entries (`VP`), annotation/widget overlaps, action overlaps, name dictionary `Pages` and `Templates`, and FDF files.
- **Sources Consulted**:
  - `src/reader/document_types.mbt`
  - `src/reader/document_structure.mbt`
  - `src/reader/catalog.mbt`
  - `src/reader/name_dictionary.mbt`
  - `src/reader/annotations.mbt`
  - `src/reader/actions.mbt`
  - `src/reader/action_types.mbt`
  - `src/reader/action_external.mbt`
  - `src/reader/document_error.mbt`
  - `src/reader/moon.pkg`
  - `.kiro/specs/pdf-document-structure/design.md`
  - `.kiro/specs/pdf-annotations/design.md`
  - `.kiro/specs/pdf-actions/design.md`
- **Findings**:
  - `PdfDocument` has private access to the loaded `PdfFile` and validated `PdfCatalog`, which is required for AcroForm, permissions, DSS, legal attestations, requirement dictionaries, and named page lookup.
  - `PdfPage` already exposes raw page entries and annotations; annotation parsing stores widget form-field data and `Measure` operands raw.
  - `PdfActionKind::SubmitForm`, `ResetForm`, and `ImportData` currently use `PdfFormActionRaw` and preserve form semantics for this spec.
  - Reader errors already distinguish invalid navigation, annotation, action, graphics, and content structures from lower-level parse failures.
- **Implications**:
  - Implement this feature in `src/reader` with cohesive files for forms, FDF, signatures, LTV, permissions, legal attestations, measurement, geospatial data, and requirements.
  - Preserve package dependency direction and standard-library-only policy.
  - Add new reader diagnostics for forms, FDF, signatures, measures, and document requirements instead of overloading action or annotation errors.

### ISO 32000-2 Clause 12.7 Form and FDF Scope
- **Context**: Requirements 0.1 through 0.29 cover interactive forms, field dictionaries, field inheritance, variable text descriptors, button/text/choice/signature fields, form actions, named pages, FDF files, FDF fields/pages/annotations, and non-interactive form markers.
- **Sources Consulted**:
  - `.kiro/specs/pdf-forms-signatures/requirements.md`
  - `spec/extracted/12.7-12.11-forms-signatures.spec.txt`
  - `.kiro/specs/pdf-actions/design.md`
  - `.kiro/specs/pdf-annotations/design.md`
- **Findings**:
  - AcroForm is a document-global field tree rooted at Catalog `AcroForm.Fields`, while widget annotations remain page-owned appearances.
  - Field inheritance resembles page attribute inheritance but uses form-field ancestry and has field-type-specific value rules.
  - Variable text appearance rules require resource and default appearance descriptors, but appearance stream regeneration is a PDF writing/rendering responsibility outside the parser phase.
  - FDF is PDF-like but not a normal PDF document. It has a `%FDF-1.2` header, optional xref and trailer, a single root catalog, and dictionaries for fields, pages, annotations, JavaScript, embedded FDFs, and differences.
- **Implications**:
  - Design a typed form field tree with fully qualified names, inherited attributes, widget links, and raw hand-off for appearances and actions.
  - Provide structural submit/reset/import action parsing and field-selection plans without performing HTTP requests, mutation, or file imports.
  - Add an FDF reader that reuses lower object syntax concepts but has its own header/catalog/trailer validation and no incremental-update writer semantics.

### Digital Signature and LTV Scope
- **Context**: Requirements 0.30 through 0.56 cover signature dictionaries, byte ranges, transform methods, DocMDP, FieldMDP, UR, PKCS #1, CMS, PAdES, revocation, DSS, VRI, document timestamps, permissions, and legal attestations.
- **Sources Consulted**:
  - `.kiro/specs/pdf-forms-signatures/requirements.md`
  - `spec/extracted/12.7-12.11-forms-signatures.spec.txt`
  - RFC 5652 Cryptographic Message Syntax: https://www.rfc-editor.org/rfc/rfc5652
  - RFC 5280 PKIX certificate and CRL profile: https://www.rfc-editor.org/rfc/rfc5280
  - RFC 6960 OCSP: https://www.rfc-editor.org/rfc/rfc6960
  - RFC 3161 Time-Stamp Protocol: https://www.rfc-editor.org/rfc/rfc3161
  - RFC 5816 ESSCertIDv2 update for RFC 3161: https://www.rfc-editor.org/rfc/rfc5816
  - RFC 5035 ESSCertIDv2 signing-certificate attribute: https://www.rfc-editor.org/rfc/rfc5035
  - ETSI EN 319 142-1 PAdES official delivery directory: https://www.etsi.org/deliver/etsi_en/319100_319199/31914201/
  - ETSI EN 319 122-1 CAdES official delivery directory: https://www.etsi.org/deliver/etsi_en/319100_319199/31912201/
- **Findings**:
  - CMS, PKIX path validation, CRLs, OCSP, and timestamp tokens are established standards and should not be hand-implemented inside a PDF parser without an approved cryptographic stack.
  - PDF-specific responsibilities are structural: parse signature dictionaries, ensure ByteRange shape, extract signed byte slices, classify SubFilter and transform methods, parse DocMDP/FieldMDP/UR parameters, locate DSS/VRI evidence, and prepare handler inputs.
  - PAdES support requires recognizing `ETSI.CAdES.detached`, `ETSI.RFC3161`, DSS/VRI, timestamp dictionaries, and validation-time selection, while actual CMS attribute validation remains handler-owned.
  - Legal attestations are catalog-level structural counts and text, not proof of legal validity.
- **Implications**:
  - Add a `PdfSignatureValidationPlan` contract that identifies byte ranges, contents bytes, subfilter, expected standards, transform restrictions, DSS/VRI evidence, timestamps, and required handler work.
  - Do not add a MoonBit crypto dependency in this design. Any future built-in CMS/PKIX/PAdES implementation must revalidate dependencies, security model, and public API.
  - Implement structural checks and evidence collection in `src/reader`; expose handler boundaries for digest, CMS, certificate path, revocation, timestamp, and policy validation.

### Measurement, Geospatial, and Document Requirements
- **Context**: Requirements 0.57 through 0.64 cover viewport dictionaries, measure dictionaries, number format arrays, rectilinear measurement formatting, geospatial dictionaries, coordinate system dictionaries, point data, and Catalog `Requirements`.
- **Sources Consulted**:
  - `.kiro/specs/pdf-forms-signatures/requirements.md`
  - `src/reader/annotations.mbt`
  - `src/reader/document_structure.mbt`
  - `src/reader/name_dictionary.mbt`
- **Findings**:
  - Annotation parsing already preserves `Measure` raw values for line and polygon annotations, and Page entries can expose raw `VP`.
  - Measurement support is structural and computational but not rendering: parse viewports, choose the last matching viewport for a point, parse rectilinear and geospatial measure dictionaries, and format number arrays.
  - Geospatial coordinate conversion from EPSG or WKT requires GIS/projection logic that is not in the current stack. The parser can validate dictionary shape and preserve EPSG/WKT data.
  - Catalog `Requirements` must be evaluated before ECMAScript execution by interactive processors. This library has no ECMAScript runtime, so it can expose parsed requirement dictionaries and a deterministic support assessment.
- **Implications**:
  - Add typed `PdfViewport`, `PdfMeasure`, `PdfNumberFormat`, geospatial coordinate system, point-data, and requirement dictionary models.
  - Implement rectilinear number-format output because the algorithm is self-contained and standard-library-only.
  - Preserve geospatial coordinate transformation as raw metadata and handler-owned behavior until a projection dependency is approved.

### MoonBit Implementation Constraints
- **Context**: The design must produce executable implementation tasks for the current MoonBit repository.
- **Sources Consulted**:
  - `.kiro/steering/product.md`
  - `.kiro/steering/tech.md`
  - `.kiro/steering/structure.md`
  - `<local>/.codex/skills/moonbit-agent-guide/SKILL.md`
  - `<local>/.codex/skills/moonbit-lang/SKILL.md`
  - `moon.mod.json`
  - `src/reader/moon.pkg`
- **Findings**:
  - The project is standard-library-only and targets native first, wasm second.
  - MoonBit packages share declarations across files, so cohesive `*_types.mbt` files plus parser files in `src/reader` can extend the public API without new import paths.
  - Public enums should use `pub(all)` when external consumers need to pattern-match, while internal parser state should remain private.
  - `moon info` is the required public API review step after adding exported types.
- **Implications**:
  - Add only `src/reader` files and generated interface changes.
  - Use explicit types, `suberror` diagnostics, `raise`, package-private helpers, and white-box tests.
  - Keep PDF writing, network I/O, file I/O beyond caller-provided bytes, cryptography, rendering, JavaScript, and external process behavior out of implementation tasks.

## Architecture Pattern Evaluation

| Option | Description | Strengths | Risks / Limitations | Notes |
|--------|-------------|-----------|---------------------|-------|
| Keep all fields raw | Preserve current raw `AcroForm`, submit actions, widget, measure, and signature values | Minimal work | Does not satisfy typed structural access, field inheritance, FDF, signature evidence, measurement, or requirement dictionary needs | Rejected |
| New downstream packages | Add separate `forms`, `fdf`, `signatures`, and `measure` packages | Domain names are explicit | Requires widening private reader internals or duplicating object loading; increases dependency complexity | Rejected for this phase |
| Focused reader-layer structural extension | Add typed models, parsers, validation plans, and accessors inside `src/reader` | Reuses `PdfDocument`, `PdfPage`, `PdfFile::load_object`, annotations, actions, and name trees; preserves package direction | `src/reader` grows and needs strict file boundaries | Selected |
| Built-in cryptographic validation | Add CMS, PKIX, OCSP, CRL, timestamp, and PAdES validation inside this feature | Could offer end-to-end validation | Violates no-new-dependency steering or requires risky custom crypto | Rejected |
| Handler-backed signature validation plan | Parse PDF-owned structures and expose cryptographic inputs to explicit handlers | Satisfies parser scope, keeps security boundary visible, allows future adoption | Does not by itself prove trust | Selected |

## Synthesis Outcomes
- **Generalization**: AcroForm fields, FDF fields, FieldMDP field lists, form actions, and signature locks all need the same fully qualified field-name index. The design defines one field-name resolver and selection model reused by form, FDF, action, and signature components.
- **Generalization**: Signature fields, DocMDP, FieldMDP, DSS/VRI, document timestamps, permissions, and legal attestations are variations of document integrity metadata. The design separates PDF-owned structural evidence from handler-owned cryptographic verification.
- **Generalization**: Viewport measurement, annotation measure entries, and geospatial dictionaries share a measure model. The design parses measure dictionaries once and lets Page and annotation consumers reuse it.
- **Build vs. Adopt**: PDF dictionary parsing is built inside `src/reader` because it depends on existing `PdfObject` contracts. Cryptographic standards are adopted as handler contracts rather than reimplemented.
- **Simplification**: The design does not include a form filler, appearance generator, FDF writer, network submitter, JavaScript engine, PDF writer, cryptographic library, GIS projection engine, or permission enforcement runtime.
- **Design finalization pass**: The finalized design keeps the feature in `src/reader`, uses file-level ownership boundaries for forms, FDF, signatures, LTV, permissions, measurement, geospatial metadata, and requirements, and maps every requirement ID from `0.1` through `0.64` to concrete components and interfaces.

## Design Decisions

### Decision: Keep Forms, FDF, Signatures, Measures, and Requirements in `src/reader`
- **Context**: These structures are reached through `PdfDocument`, `PdfPage`, Catalog entries, annotations, actions, and lazy indirect references.
- **Alternatives Considered**:
  1. Add new packages per domain.
  2. Extend lower object/parser packages.
  3. Add cohesive files to `src/reader`.
- **Selected Approach**: Add cohesive reader-layer files and public accessors.
- **Rationale**: `src/reader` already owns document-level interpretation and can reuse private object loading without expanding lower APIs.
- **Trade-offs**: The reader package grows, so each file must own one responsibility and tests must be split by domain.
- **Follow-up**: Run `moon info` and review `src/reader/pkg.generated.mbti` after implementation.

### Decision: Parse Interactive Forms Structurally, Not Interactively
- **Context**: AcroForm semantics include UI behavior, field filling, appearance regeneration, calculation order, and actions.
- **Alternatives Considered**:
  1. Implement an interactive form engine.
  2. Expose field tree, values, flags, widgets, variable text descriptors, and action plans.
- **Selected Approach**: Provide structural models and deterministic selection/reset/submit/import plans without mutating documents or running actions.
- **Rationale**: The project is a parser library and Phase 1 excludes PDF writing and interactive behavior.
- **Trade-offs**: Applications that fill or submit forms must build on top of this API.
- **Follow-up**: Revalidate if a future writer or form-filling spec is approved.

### Decision: Add an FDF Reader, Not an FDF Writer
- **Context**: FDF import/export appears in requirements, but the product steering excludes PDF generation.
- **Alternatives Considered**:
  1. Implement FDF read and write.
  2. Parse FDF structure and expose import/export payloads.
- **Selected Approach**: Parse FDF bytes, catalog, dictionaries, fields, pages, annotations, JavaScript entries, and differences structurally.
- **Rationale**: Reading FDF supports parser workflows while writing or importing into a PDF would mutate output documents.
- **Trade-offs**: Export and import actions become plans rather than side effects.
- **Follow-up**: Revisit when PDF writing enters scope.

### Decision: Use Handler Boundaries for Cryptographic Validation
- **Context**: Signature validation depends on CMS, PKIX, revocation, timestamps, and trust parameters.
- **Alternatives Considered**:
  1. Add built-in crypto and ASN.1 validation.
  2. Perform only PDF structural parsing.
  3. Parse PDF structures and expose a validation plan for handlers.
- **Selected Approach**: Option 3.
- **Rationale**: It keeps the parser standard-library-only while making byte ranges, signature contents, SubFilter, transform methods, DSS/VRI data, timestamps, and permission constraints explicit.
- **Trade-offs**: The library cannot claim cryptographic trust without a handler result.
- **Follow-up**: A future crypto-backed validation feature must define dependencies, trust-store configuration, revocation policy, and wasm/native compatibility.

### Decision: Parse Measurement Formatting, Preserve Geospatial Transform Metadata
- **Context**: Rectilinear number formatting is algorithmic and local, while EPSG/WKT coordinate transformations require projection logic.
- **Alternatives Considered**:
  1. Implement full GIS coordinate transformations.
  2. Preserve all measurement data raw.
  3. Parse measure dictionaries and implement only the local number-format algorithm.
- **Selected Approach**: Option 3.
- **Rationale**: It satisfies self-contained parser behavior without adding projection dependencies.
- **Trade-offs**: Applications needing coordinate conversion must use external GIS logic.
- **Follow-up**: Revalidate if a projection library is adopted later.

### Decision: Treat Catalog Requirements as Capability Metadata
- **Context**: Requirement dictionaries are intended to be evaluated before ECMAScript execution, but this library does not execute ECMAScript.
- **Alternatives Considered**:
  1. Ignore Catalog `Requirements`.
  2. Parse them and expose support assessment metadata.
- **Selected Approach**: Parse requirement dictionaries and report known support status, penalty, version, handler alternatives, encryption payloads, and digital-signature payloads.
- **Rationale**: This gives consumers deterministic metadata while preserving the no-JavaScript boundary.
- **Trade-offs**: Final processor behavior remains application-owned.
- **Follow-up**: Revalidate when encryption, JavaScript, or full signature validation support is added.

## Risks & Mitigations
- Broad feature surface may produce unbounded tasks - mitigate with file-level ownership, grouped components, and traceability rows by requirement.
- Signature language may imply built-in trust verification - mitigate with explicit validation-plan and handler contracts, and name results as structural unless a handler supplies cryptographic status.
- Form field trees can cycle or use conflicting names - mitigate with object-id visited sets, field ancestry validation, and field-name index diagnostics.
- FDF resembles PDF but has different file rules - mitigate with FDF-specific header/catalog/trailer validation and tests instead of reusing PDF assumptions blindly.
- Measurement and geospatial data may invite projection scope creep - mitigate with structural geospatial models and no coordinate-transform runtime.
- Public API growth in `src/reader` may be difficult to review - mitigate with `moon info`, generated interface diffs, and focused test files.
- Replacing existing raw form-action payloads may affect action consumers - mitigate with a compatibility wrapper or alias during implementation and explicit `pkg.generated.mbti` review.

## References
- `.kiro/specs/pdf-forms-signatures/requirements.md` - authoritative requirements generated from ISO 32000-2:2020 clauses 12.7 through 12.11.
- `spec/extracted/12.7-12.11-forms-signatures.spec.txt` - local extracted clause text.
- `.kiro/specs/pdf-document-structure/design.md` - existing Catalog, Page, page-tree, and name-tree boundary.
- `.kiro/specs/pdf-annotations/design.md` - widget, action, measure, and appearance raw hand-off boundary.
- `.kiro/specs/pdf-actions/design.md` - submit/reset/import form action raw boundary.
- [RFC 5652](https://www.rfc-editor.org/rfc/rfc5652) - CMS container standard used by signature contents.
- [RFC 5280](https://www.rfc-editor.org/rfc/rfc5280) - PKIX certificate path and CRL profile referenced by signature validation.
- [RFC 6960](https://www.rfc-editor.org/rfc/rfc6960) - OCSP revocation status standard referenced by DSS/VRI and PAdES validation.
- [RFC 3161](https://www.rfc-editor.org/rfc/rfc3161) and [RFC 5816](https://www.rfc-editor.org/rfc/rfc5816) - timestamp token standards used by document timestamps and PAdES.
- [RFC 5035](https://www.rfc-editor.org/rfc/rfc5035) - ESSCertIDv2 signing-certificate attribute used by PAdES validation.
- [ETSI EN 319 142-1 delivery directory](https://www.etsi.org/deliver/etsi_en/319100_319199/31914201/) - PAdES standards family.
- [ETSI EN 319 122-1 delivery directory](https://www.etsi.org/deliver/etsi_en/319100_319199/31912201/) - CAdES standards family.
