# Research & Design Decisions

## Summary
- **Feature**: `pdf-multimedia`
- **Discovery Scope**: Complex Integration
- **Key Findings**:
  - The existing `src/reader` package already owns document, annotation, action, name-tree, measure, geospatial, and graphics integration boundaries. Multimedia parsing belongs there as a structural extension, not in `objects`, `parser`, `graphics`, or `rendering`.
  - ISO 32000-2 clause 13 mixes pure dictionary structure with viewer-time behavior. The design separates side-effect-free structural parsing from optional pure viability evaluation and keeps playback, rendering, ECMAScript, network, and player runtime behavior out of scope.
  - 3D and RichMedia share view, activation, animation, window, asset, and node concepts. Shared value objects should be reused where the PDF contracts align, while preserving distinct public types where names, defaults, or required entries differ.

## Research Log

### Existing reader architecture and integration points
- **Context**: The feature must extend an existing MoonBit PDF parser without changing lower-level syntax or file-structure packages.
- **Sources Consulted**: `.kiro/steering/product.md`, `.kiro/steering/tech.md`, `.kiro/steering/structure.md`, `src/reader/document_types.mbt`, `src/reader/annotations.mbt`, `src/reader/actions.mbt`, `src/reader/name_dictionary.mbt`, `src/reader/structural_helpers.mbt`.
- **Findings**:
  - `PdfObject`, `PdfDictionary`, `PdfStream`, `PdfName`, and `ObjectId` are stable upstream object primitives.
  - `PdfDocument` and `PdfPage` provide lazy access to catalog, names, pages, annotations, actions, and object loading.
  - Existing action parsing already treats Sound, Movie, Rendition, GoTo3DView, and RichMediaExecute actions as structural metadata only.
  - `PdfAnnotationSpecific` currently parses Sound, Movie, Screen, Projection, 3D, and RichMedia annotation subtypes at different depths; 3D and RichMedia are raw today.
  - `structural_helpers.mbt` centralizes typed dictionary/array/name/string/number validation for several adjacent structural domains.
- **Implications**:
  - Add a multimedia structural domain and reuse lazy object resolution, cycle detection, name-tree enumeration, and annotation raw fields.
  - Keep lower packages unchanged and avoid a new external dependency.
  - Preserve raw dictionary fields for forward compatibility and public API stability.

### Multimedia framework and viability boundary
- **Context**: Requirements 1.1-1.21 define rendition, media clip, play/screen parameter, media player, software identifier, timespan, and monitor-specifier dictionaries. Many entries affect whether content is viable on a specific viewer.
- **Sources Consulted**: `.kiro/specs/pdf-multimedia/requirements.md`, `src/reader/action_media.mbt`, RFC 3986, RFC 2045.
- **Findings**:
  - MH and BE dictionaries recur across renditions, media clips, play parameters, screen parameters, and related objects with special default and precedence rules.
  - Viability depends on viewer capabilities such as media players, content type support, language, PDF version, bandwidth, screen depth, screen size, operating system, and user accessibility preferences.
  - The parser cannot know host player capabilities unless the caller supplies an environment.
  - Media clip data can reference embedded streams, file specifications, form XObjects, or external URLs; stream extraction and network access are outside the parser's read-only goal.
- **Implications**:
  - Model MH/BE entries explicitly and expose a pure `PdfMediaEnvironment` based evaluator that returns structural viability results without side effects.
  - Preserve unknown MH entries as non-viable in strict contexts and ignored in BE contexts according to the specification.
  - Treat content types and URIs as bytes or names from PDF objects; do not fetch, decode, or play media.

### Legacy sound, movie, and alternate presentation handling
- **Context**: Requirements 2, 3, and 4 cover deprecated features that still appear in valid PDFs.
- **Sources Consulted**: `.kiro/specs/pdf-multimedia/requirements.md`, `src/reader/annotations.mbt`, `src/reader/name_dictionary.mbt`.
- **Findings**:
  - Sound and Movie annotation shells already exist, but sound object streams and movie dictionaries remain raw.
  - Alternate presentations are exposed through the `AlternatePresentations` name-tree category but slideshow dictionaries are not typed.
  - These features require structural parsing and defaults, not playback.
- **Implications**:
  - Add typed accessors for sound object dictionaries, movie dictionaries, movie activation dictionaries, and slideshow dictionaries.
  - Reuse catalog name-tree enumeration for alternate presentations.
  - Keep all deprecated feature parsing available because PDF 2.0 deprecates but does not erase these structures.

### 3D artwork and PRC/U3D boundary
- **Context**: Requirements 4.1-4.8 define 3D annotations, streams, views, projections, coordinate systems, markup, units, and persistent measurements.
- **Sources Consulted**: `.kiro/specs/pdf-multimedia/requirements.md`, ISO 14739-1 public overview, `src/reader/graphics.mbt`, `src/reader/measurement_types.mbt`, `src/reader/geospatial_types.mbt`.
- **Findings**:
  - PDF 2.0 allows U3D and PRC 3D streams; ISO 14739-1 describes PRC as a 3D content data format designed for inclusion in PDF and similar document formats.
  - Existing `graphics` and `rendering` packages cover 2D PDF graphics, not U3D or PRC decoding.
  - 3D views contain structural camera, projection, render-mode, lighting, cross-section, node, overlay, unit, and measurement metadata.
  - Geospatial 3D references existing geospatial measure concepts but extends point arrays to 3D in annotation context.
- **Implications**:
  - Parse 3D stream dictionaries and preserve raw stream bytes; do not decode U3D or PRC payloads.
  - Add 3D vector, matrix, projection, units, and measurement value objects in `src/reader`.
  - Cross-link 3D markup and projection annotation ExData structurally, but do not compute MD5 checksums or render comment visibility.

### RichMedia annotation structure
- **Context**: Requirements 4.9-4.24 define RichMedia annotation settings, activation/deactivation, animation, presentation windows, content assets, configurations, instances, views, and state data.
- **Sources Consulted**: `.kiro/specs/pdf-multimedia/requirements.md`, `src/reader/action_media.mbt`, `src/reader/name_dictionary.mbt`.
- **Findings**:
  - RichMedia annotations are a common framework for media and 3D interactive presentation metadata.
  - RichMedia content assets depend on embedded file specifications in a name tree and require filename validation rules.
  - RichMedia activation may reference scripts and view/configuration objects that must also appear in content arrays.
  - View Params carry opaque state data for instances; saving/loading state is runtime behavior, but the data relationship is structural.
- **Implications**:
  - Parse settings and content independently so shared `RichMediaContent` dictionaries can be reused by multiple annotations.
  - Validate asset filename restrictions and cross-membership for activation configuration, views, and instances where the referenced arrays are available.
  - Preserve opaque script and state data without executing ECMAScript or communicating with media runtimes.

### External standards and stable references
- **Context**: Several requirement clauses refer to URI escaping, MIME content type, MD5 checksum, and PRC 3D content.
- **Sources Consulted**:
  - RFC 3986, "Uniform Resource Identifier (URI): Generic Syntax": https://www.rfc-editor.org/rfc/rfc3986
  - RFC 2045, "Multipurpose Internet Mail Extensions (MIME) Part One": https://www.rfc-editor.org/rfc/rfc2045
  - RFC 1321, "The MD5 Message-Digest Algorithm": https://www.rfc-editor.org/rfc/rfc1321
  - ISO 14739-1:2014 overview: https://www.iso.org/standard/54948.html
- **Findings**:
  - URI and content-type strings should be preserved exactly at parse time; normalization would cross into a higher-level interpretation boundary.
  - MD5 is used by PDF 3D markup as a checksum signal, not as a security primitive.
  - PRC is a separate 3D format standard; PDF parsing only needs to identify and preserve PRC stream payloads.
- **Implications**:
  - Add optional syntactic checks only when ISO requires local shape validation. Do not normalize URIs or parse full MIME parameter grammar in this feature.
  - Store MD5 bytes and expose a helper only if checksum validation can be implemented without bringing in a dependency; otherwise preserve raw bytes and defer checksum computation.

## Architecture Pattern Evaluation

| Option | Description | Strengths | Risks / Limitations | Notes |
|--------|-------------|-----------|---------------------|-------|
| Reader-layer structural extension | Add typed multimedia models and accessors in `src/reader`; preserve raw payloads | Matches existing actions, annotations, measure, geospatial, and name-tree patterns; no new dependencies | Adds many public types in one package | Selected |
| Dedicated `src/multimedia` package | Move multimedia parsing to a new package above reader | Smaller reader files | Would need access to `PdfFile`, lazy loading, page annotations, and catalog names; risks circular dependency | Rejected |
| Runtime/player abstraction | Define media player and 3D renderer interfaces | Closer to interactive PDF processor behavior | Violates read-only parser goals; introduces side effects and dependency questions | Rejected |
| Raw-only preservation | Keep all multimedia dictionaries as `PdfObject` | Minimal implementation | Does not satisfy typed inspection or requirement traceability | Rejected |

## Design Decisions

### Decision: Keep multimedia parsing in `src/reader`
- **Context**: Multimedia dictionaries are reached from catalog name trees, annotations, actions, streams, and indirect references.
- **Alternatives Considered**:
  1. New package - isolates code but complicates dependency direction.
  2. `src/reader` extension - reuses existing object loading and public document facade.
- **Selected Approach**: Implement public models, accessors, and parsers under `src/reader`.
- **Rationale**: The existing dependency direction is `objects -> lexer -> parser -> reader`, and reader already owns document-level semantics.
- **Trade-offs**: Reader grows larger, so files must be split by multimedia subdomain.
- **Follow-up**: Use `moon info` to review the intended public API growth.

### Decision: Parse structure and provide pure viability evaluation, but do not execute runtime behavior
- **Context**: Clause 13 repeatedly describes play-time and viewer-time behavior.
- **Alternatives Considered**:
  1. Only parse raw dictionaries.
  2. Add a pure environment-driven evaluator.
  3. Add real playback, rendering, and scripting hooks.
- **Selected Approach**: Parse all structural dictionaries and expose optional pure evaluation against caller-provided capabilities.
- **Rationale**: This satisfies read-only parser users and keeps security-sensitive behavior outside the library.
- **Trade-offs**: Some runtime outcomes remain `Unknown` when the caller does not supply capabilities.
- **Follow-up**: Document every side-effectful operation as out of boundary in `design.md`.

### Decision: Preserve raw payloads for embedded files, U3D/PRC data, ECMAScript, and state data
- **Context**: Multimedia, 3D, and RichMedia structures reference external standards and opaque runtime data.
- **Alternatives Considered**:
  1. Decode formats now.
  2. Preserve raw data and type only surrounding dictionaries.
- **Selected Approach**: Preserve raw `PdfObject`, `PdfStream`, `PdfDictionary`, and bytes while adding typed wrappers and validation.
- **Rationale**: The project is a PDF parser, and no rendering or media runtime exists in the current stack.
- **Trade-offs**: Consumers that need U3D, PRC, media playback, or script execution must build on top.
- **Follow-up**: Revalidate if future rendering or extraction specs add supported runtime engines.

### Decision: Add typed accessors beside raw annotation variants
- **Context**: `PdfAnnotationSpecific::ThreeDRaw` and `RichMediaRaw` already exist.
- **Alternatives Considered**:
  1. Replace raw variants with typed enum variants.
  2. Keep raw variants and add `PdfDocument` typed accessors.
- **Selected Approach**: Keep raw variants for compatibility and expose typed parsing methods that need `PdfDocument` for indirect resolution.
- **Rationale**: Deep structures require object loading and cycle detection; annotations alone do not carry that behavior.
- **Trade-offs**: Callers must make an extra method call for deep multimedia data.
- **Follow-up**: Public enum replacement would require a later major revalidation.

### Decision: Generalize shared 3D and RichMedia value objects only where contracts match
- **Context**: 3D and RichMedia both use animation styles, views, windows, nodes, and instance state, but names and defaults differ.
- **Alternatives Considered**:
  1. Single generic model for every shared-looking dictionary.
  2. Separate public models with shared private helpers and shared small value objects.
- **Selected Approach**: Reuse small value objects like 3D vectors, matrices, dimensions, window position, and animation-style enums; keep public dictionary structs distinct.
- **Rationale**: Prevents incorrect default sharing while still reducing duplicated parsing logic.
- **Trade-offs**: More types appear in public API.
- **Follow-up**: Tests must cover default differences between 3D activation and RichMedia activation.

## Risks & Mitigations
- Public API size may become large - split types and parsers by subdomain and keep raw payload retention so consumers can ignore deep structures.
- Requirement coverage may drift because clause 13 is broad - keep a full traceability table in `design.md` and map every numeric requirement ID.
- Runtime behavior may accidentally leak into parser responsibilities - keep execution, playback, rendering, network, MD5 security use, and ECMAScript explicitly out of boundary.
- Unknown future dictionary keys may be mishandled - preserve raw dictionaries and implement MH/BE unknown-key behavior only for viability evaluation contexts.
- 3D and RichMedia validation may over-resolve indirect graphs - use bounded path-based cycle detection and lazy parsing accessors.

## References
- Local requirements: `.kiro/specs/pdf-multimedia/requirements.md`
- Local steering: `.kiro/steering/product.md`, `.kiro/steering/tech.md`, `.kiro/steering/structure.md`
- Existing reader patterns: `src/reader/actions.mbt`, `src/reader/annotations.mbt`, `src/reader/name_dictionary.mbt`, `src/reader/structural_helpers.mbt`
- RFC 3986 URI syntax: https://www.rfc-editor.org/rfc/rfc3986
- RFC 2045 MIME content type context: https://www.rfc-editor.org/rfc/rfc2045
- RFC 1321 MD5 checksum context: https://www.rfc-editor.org/rfc/rfc1321
- ISO 14739-1:2014 PRC overview: https://www.iso.org/standard/54948.html
