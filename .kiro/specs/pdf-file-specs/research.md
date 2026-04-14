# Research & Design Decisions

## Summary
- **Feature**: `pdf-file-specs`
- **Discovery Scope**: Extension
- **Key Findings**:
  - File specifications are currently preserved as raw `PdfObject` values by navigation, action, annotation, multimedia, structure, and form-related reader models. This feature should become the typed reader-layer owner for those raw hand-off values without changing lower object, parser, filter, or xref packages.
  - ISO 32000-2:2020 clause 7.11 combines byte-level file-specification strings, dictionary metadata, embedded-file stream descriptors, related-file arrays, URL file-system rules, and collection item dictionaries. The parser should expose these as structural data and pure helpers, not as filesystem, network, launch, extraction, decryption, or viewer behavior.
  - Existing `src/reader` infrastructure already provides `PdfDocument`, `PdfFile::load_object`, name-tree enumeration for `EmbeddedFiles`, structural validation helpers, and adjacent raw file-spec hand-off fields. A focused set of `src/reader` files is sufficient; no new package or external dependency is required.

## Research Log

### Existing Reader Integration Points
- **Context**: File specifications are referenced by multiple existing reader features and must fit the current package dependency direction.
- **Sources Consulted**:
  - `src/reader/document_types.mbt`
  - `src/reader/name_dictionary.mbt`
  - `src/reader/collection.mbt`
  - `src/reader/action_types.mbt`
  - `src/reader/action_destinations.mbt`
  - `src/reader/action_external.mbt`
  - `src/reader/annotations.mbt`
  - `src/reader/structural_helpers.mbt`
  - `src/reader/document_error.mbt`
  - `.kiro/specs/pdf-interactive-navigation/design.md`
  - `.kiro/specs/pdf-actions/design.md`
  - `.kiro/specs/pdf-annotations/design.md`
  - `.kiro/specs/pdf-multimedia/design.md`
- **Findings**:
  - `PdfCollectionFile` stores `file_spec` as a raw object from the `EmbeddedFiles` name tree.
  - Action models store remote Go-To, embedded Go-To, Launch, Thread, and form-action file specifications as raw `PdfObject` fields.
  - Annotation models store file attachment `FS` and associated-file `AF` entries as raw values.
  - Existing name-tree enumeration already exposes `NameTreeCategory::EmbeddedFiles`, so document-level embedded file access can be additive.
  - `structural_helpers.mbt` contains generic dictionary, array, name, string, reference, and indirect-resolution helpers used by adjacent domains.
- **Implications**:
  - Implement typed file-specification parsing in `src/reader`, not in lower `objects`, `lexer`, `parser`, or `filters`.
  - Add generic public parsing methods that can accept raw file-specification objects from action, annotation, collection, structure, form, multimedia, and future call sites.
  - Add document-level embedded-file enumeration by parsing `EmbeddedFiles` name-tree values, while leaving existing raw collection/action/annotation fields compatible.

### ISO 32000-2 Clause 7.11 File Specification Contracts
- **Context**: Requirements were generated from `spec/extracted/7.11-file-specifications.spec.txt`.
- **Sources Consulted**:
  - `spec/extracted/7.11-file-specifications.spec.txt`
  - `.kiro/specs/pdf-file-specs/requirements.md`
  - `.kiro/specs/pdf-document-structure/design.md`
  - `.kiro/specs/pdf-interactive-navigation/design.md`
- **Findings**:
  - A simple file specification may be a byte string or dictionary. A full file specification is dictionary-only.
  - Simple file-specification strings are byte-oriented path strings separated by `/`; escaped literal `/` uses a preceding reverse solidus convention and is unescaped only for component parsing.
  - Dictionary entries include `Type`, `FS`, `F`, `UF`, deprecated `DOS`, `Mac`, `Unix`, `ID`, `V`, `EF`, `RF`, `Desc`, `CI`, `Thumb`, `EP`, and `AFRelationship`.
  - `UF` takes precedence over `F` for readers when present, but `F` remains the backward-compatible entry.
  - `EF` maps file-name keys to embedded-file streams and requires `Type /Filespec` and an indirect file-spec dictionary. `RF` requires `EF`, mirrors EF keys, and maps each key to a related-files array.
  - Embedded-file streams are normal PDF streams plus optional `Type /EmbeddedFile`, `Subtype`, and `Params`. Parameters include size, dates, Mac metadata, and a 16-byte MD5 checksum signal.
  - Collection items are dictionaries with optional `Type /CollectionItem`; their schema-dependent field values are owned by collection semantics and should be preserved structurally.
- **Implications**:
  - The core parser must distinguish string, dictionary, embedded file stream, and collection item contracts.
  - Models need to preserve raw dictionaries and raw streams while surfacing validated typed fields and defaults.
  - The dictionary parser must know whether the source object was an indirect reference so it can enforce indirect-only requirements for `EF` and `RF`.

### External Standards and Runtime Boundary
- **Context**: Clause 7.11 references RFC 3986 URL resolution, RFC 2046 media types, RFC 8118 PDF media type registration, and RFC 1321 MD5 checksums.
- **Sources Consulted**:
  - `spec/extracted/7.11-file-specifications.spec.txt`
  - `.kiro/steering/product.md`
  - `.kiro/steering/tech.md`
  - `.kiro/steering/structure.md`
  - Existing `src/filters` stream-decoding design and reader integration notes.
- **Findings**:
  - URL file specifications use `FS /URL` and interpret `F` as a URL string. Relative URL file specifications are constrained to path-only relative references before being resolved against a caller-supplied base URL.
  - Embedded-file `Subtype` uses MIME media type names encoded as PDF names. Full MIME parsing is unnecessary for structural PDF parsing.
  - Embedded-file `CheckSum` is an MD5 digest of uncompressed file bytes, but the note treats it as a checksum rather than a security mechanism.
  - The project steering requires no third-party dependencies and a read-only parser library. External file access, network access, URL fetching, process launching, and security prompts are outside this phase.
- **Implications**:
  - Build small byte-oriented helpers for path-component splitting, relative path normalization, and RFC 3986 path escaping rather than adopting a library.
  - Store `Subtype` as a `PdfName` and `CheckSum` as a validated 16-byte string. Do not compute MD5 or treat it as a security primitive in this feature.
  - Provide pure URL/path resolution helpers only when the caller supplies a base file specification or base URL. The parser does not infer a filesystem path from raw PDF bytes.

### MoonBit Implementation Constraints
- **Context**: The design must generate implementation tasks that fit the current MoonBit repository.
- **Sources Consulted**:
  - `.kiro/steering/product.md`
  - `.kiro/steering/tech.md`
  - `.kiro/steering/structure.md`
  - `<local>/.codex/skills/moonbit-agent-guide/SKILL.md`
  - `<local>/.codex/skills/moonbit-lang/SKILL.md`
  - `src/reader/moon.pkg`
  - `moon.mod.json`
- **Findings**:
  - `src/reader` already imports `objects`, `lexer`, `parser`, `filters`, `content`, `graphics`, and `interchange`; this feature needs no new import.
  - Public models should use explicit structs and `pub(all)` enums where downstream users need pattern matching.
  - Reader errors already have domain-specific variants. A new file-specification diagnostic keeps malformed file specs distinct from low-level reader, navigation, action, annotation, and multimedia failures.
  - Public API changes must be reviewed through `moon info`, and tests should be white-box focused for package-private helpers plus public method coverage.
- **Implications**:
  - Add cohesive files under `src/reader`: model types, common parser helpers, string parsing/resolution, dictionary parsing, embedded-file parsing, document-level embedded-file accessors, and tests.
  - Preserve package dependency direction and standard-library-only implementation.
  - Update only `src/reader/pkg.generated.mbti` through `moon info` during implementation.

## Architecture Pattern Evaluation

| Option | Description | Strengths | Risks / Limitations | Notes |
|--------|-------------|-----------|---------------------|-------|
| Keep file specifications raw | Continue returning raw `PdfObject` values from actions, annotations, collections, and structures | Minimal implementation | Does not satisfy clause 7.11 structural parsing, embedded file stream metadata, related files, URL rules, or collection item requirements | Rejected |
| New `src/file_specs` package | Put file-specification models in a separate package | Clear domain name | Cannot use private `PdfDocument.file`, name-tree enumeration, and lazy object loading without widening public internals or changing dependency direction | Rejected |
| Focused reader-layer extension | Add file-specification models, parsers, accessors, and tests in `src/reader` | Preserves lazy loading, existing raw hand-off compatibility, and dependency direction | Expands `src/reader` public API and requires strict non-execution boundaries | Selected |
| External URI/MIME/checksum libraries | Adopt third-party parsers for RFC 3986, MIME, or MD5 | Potentially richer validation | Violates steering dependency constraint and exceeds structural parsing needs | Rejected |

## Synthesis Outcomes
- **Generalization**: Simple file specs, dictionary `F`/`UF` entries, platform entries, related file names, and `EmbeddedFiles` name-tree keys are all byte-oriented file-name values. The design uses one `PdfFileSpecPath` parser and keeps higher-level dictionary fields as wrappers around it.
- **Generalization**: `EF`, `RF`, `Thumb`, `CI`, `EP`, `AF`, and action/annotation file-spec fields all need the same bounded indirect-resolution policy. The design centralizes file-spec object resolution and source context, then reuses it from document, annotation, action, collection, and raw-object accessors.
- **Build vs. Adopt**: No external dependency is adopted. The required behavior is PDF-object interpretation tied to existing `PdfObject`, `PdfDictionary`, `PdfStream`, `PdfName`, `ObjectId`, and `PdfFile::load_object` contracts.
- **Simplification**: The design does not implement filesystem access, URL fetching, process launching, embedded-file extraction to disk, payload decryption, MD5 generation, MIME parameter parsing, collection UI, or PDF writing. It parses and exposes structural metadata only.

## Design Decisions

### Decision: Reader-Layer Typed File Specification Parsing
- **Context**: File specifications are reached from reader-owned document structures and require lazy indirect-object resolution.
- **Alternatives Considered**:
  1. Add parsing to `objects` or `parser`.
  2. Create a new downstream package.
  3. Add cohesive file-specification files inside `src/reader`.
- **Selected Approach**: Implement models, string parsing, dictionary parsing, embedded-file descriptors, collection item parsing, and public accessors under `src/reader`.
- **Rationale**: `reader` already owns document-level semantics and can parse raw file-spec objects from existing features without widening lower APIs.
- **Trade-offs**: `src/reader` gains another structural domain, so files and tests must stay explicitly bounded.
- **Follow-up**: Run `moon info` during implementation and verify intended `src/reader` public API additions only.

### Decision: Parse Structure, Do Not Access External Resources
- **Context**: File specifications can name external files, URLs, embedded payloads, launch targets, or encrypted payloads.
- **Alternatives Considered**:
  1. Resolve URLs, open files, launch targets, or extract embedded files automatically.
  2. Parse and expose structural metadata and raw streams, leaving effects to caller-owned code.
- **Selected Approach**: The parser returns typed file-specification metadata and raw embedded-file streams. It never opens, fetches, launches, writes, decrypts, or extracts resources.
- **Rationale**: The project is a read-only PDF parser library, and external effects are security-sensitive viewer/application behavior.
- **Trade-offs**: Applications must explicitly consume returned metadata and streams when they want extraction or network behavior.
- **Follow-up**: Boundary tests should prove file-spec parsing has no side effects and preserves raw payloads.

### Decision: Preserve Raw Payloads Beside Typed Fields
- **Context**: File-specification dictionaries contain extension keys, deprecated platform entries, collection item dictionaries, encrypted payload dictionaries, thumbnails, and embedded streams.
- **Alternatives Considered**:
  1. Parse only standard keys and discard unknowns.
  2. Keep the original raw dictionary and stream while exposing typed standard fields.
- **Selected Approach**: Every public file-specification, embedded-file, parameter, collection item, and related-files model retains the raw source object or dictionary.
- **Rationale**: This keeps forward compatibility and allows adjacent specs to interpret fields that this feature does not own.
- **Trade-offs**: Some fields remain raw until future specs add deeper semantics.
- **Follow-up**: Revalidate when encryption, associated files, collection UI, or MIME-specific features add typed payload contracts.

### Decision: Pure Path and URL Helpers With Caller-Supplied Base
- **Context**: Relative file specifications require a containing PDF file specification or base URL, but `PdfDocument::open` receives bytes and does not know where those bytes came from.
- **Alternatives Considered**:
  1. Store a filesystem path inside `PdfFile`.
  2. Ignore relative resolution entirely.
  3. Provide pure helper methods that accept explicit base information.
- **Selected Approach**: Expose pure helpers for splitting, classifying, normalizing, and resolving file-specification paths and URL path references when the caller supplies a base path or URL.
- **Rationale**: This satisfies the specification's path semantics without adding ambient filesystem assumptions.
- **Trade-offs**: Callers must provide context when they need absolute paths.
- **Follow-up**: Revalidate if a future file-loading API stores source location metadata in `PdfFile`.

### Decision: Additive Accessors Over Existing Raw Fields
- **Context**: Several public models already expose raw file-specification values.
- **Alternatives Considered**:
  1. Replace existing raw fields with typed `PdfFileSpecification` values.
  2. Add typed parsing methods and document that raw fields remain compatibility hand-offs.
- **Selected Approach**: Add generic file-specification parser methods and document-level embedded-file enumeration. Existing action, annotation, collection, structure, form, and multimedia fields remain raw unless a future breaking API migration is approved.
- **Rationale**: Additive APIs avoid breaking existing users and adjacent specs.
- **Trade-offs**: A raw value and a typed parse result may both be visible for the same PDF entry.
- **Follow-up**: Public docs and tests should treat the new typed parser as authoritative for clause 7.11 semantics.

## Risks & Mitigations
- File specifications can appear in many existing domains, creating ownership drift — mitigate with a generic raw-object parser and explicit revalidation triggers for any raw field replacement.
- Relative URL and path rules can expand into a full URI library — mitigate by implementing only byte-preserving path-only helpers required by clause 7.11 and preserving raw URL bytes otherwise.
- Embedded-file streams may be confused with payload extraction — mitigate by exposing raw stream descriptors and keeping decoding or writing-to-disk outside this feature.
- `EF` and `RF` indirect-object requirements can be missed when parsing direct dictionaries — mitigate by carrying `object_id` source provenance through resolution and testing direct-dictionary rejection.
- Deprecated DOS, Mac, Unix entries and extensible file-system names can cause over-validation — mitigate by preserving them as optional byte strings or names while enforcing only required shape and precedence contracts.
- Checksum handling can be mistaken for a security feature — mitigate by validating the optional 16-byte string shape and documenting that no MD5 computation or trust decision occurs here.

## References
- `spec/extracted/7.11-file-specifications.spec.txt` - local ISO 32000-2:2020 clause 7.11 excerpt.
- `.kiro/specs/pdf-file-specs/requirements.md` - authoritative requirements for this feature.
- `.kiro/specs/pdf-document-structure/design.md` - upstream `PdfDocument`, Catalog, Page, and name-tree contracts.
- `.kiro/specs/pdf-interactive-navigation/design.md` and `.kiro/specs/pdf-interactive-navigation/research.md` - existing `EmbeddedFiles` name-tree and raw file-specification boundaries.
- `.kiro/specs/pdf-actions/design.md` and `.kiro/specs/pdf-actions/research.md` - existing raw action file-specification payloads.
- `.kiro/specs/pdf-annotations/design.md` - existing annotation file attachment and associated-file raw fields.
- `.kiro/specs/pdf-multimedia/design.md` and `.kiro/specs/pdf-multimedia/research.md` - existing embedded-file and media payload non-execution boundaries.
- `.kiro/steering/product.md`, `.kiro/steering/tech.md`, `.kiro/steering/structure.md` - project-wide MoonBit, dependency, and parser guidance.
