# Research & Design Decisions

## Summary
- **Feature**: `pdf-xobjects-images`
- **Discovery Scope**: Extension / Integration-focused discovery
- **Key Findings**:
  - Existing `content` parsing already recognizes `Do`, inline images, marked-content operators, and `XObject` or `Properties` resource categories; this feature should add semantic validation downstream instead of changing content tokenization.
  - Existing `graphics` interpretation is device-independent and event-oriented. XObjects, images, forms, and optional content must follow that boundary by validating structures and controlling event visibility without rendering pixels, fonts, transparency, or external files.
  - Object loading and Catalog-level `OCProperties` access belong in `reader`; `graphics` can interpret only direct or caller-materialized resources so dependency direction remains unchanged.

## Research Log

### Existing content and graphics extension points
- **Context**: Requirements `0.1` through `0.36` connect content-stream syntax, resource dictionaries, graphics events, images, form XObjects, and optional content state.
- **Sources Consulted**:
  - `src/content/operator.mbt`
  - `src/content/parser.mbt`
  - `src/content/inline_image.mbt`
  - `src/content/resources.mbt`
  - `src/graphics/interpreter.mbt`
  - `src/graphics/object_context.mbt`
  - `.kiro/specs/pdf-content-streams/design.md`
  - `.kiro/specs/pdf-graphics/design.md`
  - `.kiro/specs/pdf-patterns/design.md`
- **Findings**:
  - `StandardContentOperator` already includes `InvokeXObject`, `BI`, `ID`, `EI`, `BDC`, `DP`, and `EMC`.
  - `ContentResources` already exposes `XObject` and `Properties` named resource lookup and form-resource scoping.
  - `PdfInlineImage` already preserves expanded dictionary keys, raw image data bytes, and offsets, but it does not validate image dictionary consistency or PDF 2.0 `Length`.
  - `GraphicsEvent::ExternalObjectInvoked` records only the `Do` name, and `MarkedContentSeen` records only the operator. Existing implementation does not resolve XObject resources or evaluate optional content.
- **Implications**:
  - Add semantic XObject and optional-content handling in `graphics` without changing content syntax ownership.
  - Inline image parsing remains in `content`; inline image validation and image events belong in `graphics`.
  - Marked-content optional visibility requires `graphics` to inspect operands from `ContentOperation`, not only operator names.

### Reader-owned materialization boundary
- **Context**: Image XObjects, form XObjects, optional content groups, membership dictionaries, and `OCProperties` are usually indirect objects.
- **Sources Consulted**:
  - `src/reader/catalog.mbt`
  - `src/reader/document.mbt`
  - `src/reader/document_types.mbt`
  - `src/reader/page_content.mbt`
  - `src/reader/graphics.mbt`
  - `src/reader/patterns.mbt`
  - `.kiro/steering/structure.md`
- **Findings**:
  - `reader` owns `PdfFile::load_object`, the Catalog dictionary, page resources, page content decoding, and document-level error wrapping.
  - `graphics` already imports `objects`, `content`, `filters`, and `math`; it does not import `reader`.
  - The existing pattern design uses direct validation in `graphics` with reader helpers for indirect resource loading.
- **Implications**:
  - Preserve dependency direction by introducing a reader-side XObject and optional-content materializer.
  - `graphics.interpret_content` can validate direct resources and report unresolved references. Page-level APIs can provide loaded resources and optional-content state.
  - Recursive form XObject execution must be guarded by reader-owned cycle detection and a bounded depth policy.

### Image dictionary and sample metadata scope
- **Context**: Requirements `0.2` through `0.14` define sampled image metadata, decode arrays, masks, alternates, and inline image restrictions.
- **Sources Consulted**:
  - `spec/extracted/8.8-8.11-xobjects-images-optional.spec.txt`
  - `src/graphics/colour_space.mbt`
  - `src/filters/pipeline.mbt`
  - `src/filters/types.mbt`
  - `.kiro/specs/pdf-colour-spaces/design.md`
  - `.kiro/specs/pdf-filters/design.md`
- **Findings**:
  - Existing colour-space support provides component counts and component ranges, including Indexed, ICCBased, Separation, and DeviceN.
  - Existing filters decode ASCIIHexDecode, ASCII85Decode, FlateDecode, LZWDecode, and RunLengthDecode; CCITTFaxDecode, JBIG2Decode, DCTDecode, JPXDecode, and Crypt are currently unsupported filter names.
  - Image validation can check dictionary shape, dimensions, bit depth, component count, decode-array length, mask invariants, colour-key ranges, and inline image filter restrictions without decoding unsupported image codecs.
- **Implications**:
  - Build an `ImageDescriptor` structural model rather than a raster image model.
  - Decode supported filter chains only when structural byte-length validation is explicitly possible; preserve unsupported filters as metadata instead of failing all common images.
  - Keep colour conversion, interpolation, mask compositing, soft-mask rendering, and pixel output out of scope.

### Form XObject and optional content interaction
- **Context**: Requirements `0.15` through `0.36` define form invocation semantics, group and reference XObjects, optional content groups, membership dictionaries, marked-content spans, XObject `OC`, and configuration dictionaries.
- **Sources Consulted**:
  - `spec/extracted/8.8-8.11-xobjects-images-optional.spec.txt`
  - `src/graphics/state.mbt`
  - `src/graphics/path.mbt`
  - `src/graphics/interpreter.mbt`
  - `src/content/resources.mbt`
  - `.kiro/specs/pdf-graphics/design.md`
- **Findings**:
  - Existing graphics state stack, CTM concatenation, and clipping models can express form XObject invocation as save, form matrix concatenation, BBox clipping, child content interpretation, and restore.
  - Optional content in marked-content spans differs from optional XObjects: hidden marked-content still applies graphics-state side effects, while hidden XObjects are skipped entirely.
  - Optional content state depends on Catalog `OCProperties`, OCG dictionaries, OCMD policies, visibility expressions, configuration intent, and usage application dictionaries.
  - Reference XObjects import external PDF pages, which requires file specification handling and external document loading outside current project scope.
- **Implications**:
  - Add `OptionalContentState` and visibility evaluation as a separate component used by both marked-content and XObject invocation.
  - Model reference XObjects structurally and continue to interpret their proxy form stream when imported content is unavailable or unsupported.
  - Keep transparency group compositing, external target PDF import, annotations, UI layer controls, and actions outside this spec.

### Dependency verification
- **Context**: Discovery rules require checking new dependencies.
- **Sources Consulted**:
  - `.kiro/steering/tech.md`
  - `src/graphics/moon.pkg`
  - `src/content/moon.pkg`
  - `src/reader/moon.pkg`
- **Findings**:
  - Project steering requires standard-library-only implementation.
  - Existing local packages provide all needed APIs: `objects`, `content`, `filters`, `graphics`, and `reader`.
  - No external image codec, rendering, PDF import, or UI library is needed for structural interpretation.
- **Implications**:
  - No third-party dependencies are introduced.
  - Unsupported image filters and external reference XObject targets remain explicit deferred structures.

## Architecture Pattern Evaluation

| Option | Description | Strengths | Risks / Limitations | Notes |
|--------|-------------|-----------|---------------------|-------|
| Keep `Do` as raw names | Preserve `ExternalObjectInvoked` without resolving resources | Minimal change | Does not satisfy XObject, image, form, or optional-content requirements | Rejected |
| Structural XObject interpretation | Validate loaded XObject dictionaries, image metadata, form dictionaries, and optional-content state, then emit typed graphics events | Preserves existing architecture and parser-first scope | Adds public graphics API and reader materialization work | Selected |
| Full renderer | Decode images, composite masks, execute transparency groups, import reference XObjects, and produce pixels | Closest to visible output | Violates product non-goals and requires fonts, colour management, transparency, external files, and codecs | Rejected |
| External image/PDF libraries | Adopt existing codecs and PDF import support | Broad feature coverage | Conflicts with standard-library-only steering and native/wasm portability | Rejected |

## Design Decisions

### Decision: Interpret XObjects structurally, not as pixels
- **Context**: Requirements require image and form XObject semantics, but project steering keeps rendering out of scope.
- **Alternatives Considered**:
  1. Emit only raw `Do` name events.
  2. Decode and render XObjects to pixels.
  3. Validate XObject dictionaries and emit typed image or form events with graphics-state snapshots.
- **Selected Approach**: Add typed `XObjectResource`, `ImageDescriptor`, `FormXObject`, and invocation events. The system records placement, matrix, BBox clipping, sample metadata, masks, alternates, and optional visibility without raster output.
- **Rationale**: This satisfies conformance-oriented parsing while preserving the library's device-independent boundary.
- **Trade-offs**: Downstream renderers must later implement image codecs, colour conversion, compositing, and pixel placement.
- **Follow-up**: Rendering specs must revalidate the image and form event contracts before using them for pixels.

### Decision: Keep object loading in `reader`
- **Context**: Most XObject and optional-content structures are indirect objects, but `graphics` cannot import `reader`.
- **Alternatives Considered**:
  1. Let `graphics` load indirect objects.
  2. Reject indirect XObject and optional-content resources.
  3. Add reader-owned materialization and pass loaded resources or state into `graphics`.
- **Selected Approach**: `graphics` validates direct resources and consumes optional resolver/state inputs. `reader` loads Catalog `OCProperties`, XObject resources, form content streams, and indirect OC structures before invoking graphics APIs.
- **Rationale**: This preserves the existing package dependency direction and mirrors the pattern/shading boundary.
- **Trade-offs**: Pure `graphics.interpret_content` remains limited when resources are indirect.
- **Follow-up**: Reader tests must cover direct resources, indirect resources, missing resources, and recursive form cycles.

### Decision: Build optional-content evaluation as state, not as a renderer filter
- **Context**: Hidden marked-content still applies graphics-state side effects, while hidden XObjects are skipped entirely.
- **Alternatives Considered**:
  1. Drop all hidden instructions before graphics interpretation.
  2. Leave optional content as raw marked-content events.
  3. Maintain an optional visibility stack inside the interpreter and attach/suppress paint events according to the ISO rules.
- **Selected Approach**: Add `OptionalContentState` and `OptionalVisibilityStack`. Marked-content scopes control event visibility while state-changing operators still execute. XObject `OC` visibility gates the whole invocation.
- **Rationale**: The rules are semantic and depend on graphics execution context, not syntax alone.
- **Trade-offs**: Graphics events gain visibility metadata or new visible/skipped event variants.
- **Follow-up**: Tests must verify hidden marked-content state side effects and hidden XObject skipping separately.

### Decision: Preserve unsupported codecs and external references
- **Context**: Image filters such as DCTDecode and JPXDecode are common, and reference XObjects can import external PDFs.
- **Alternatives Considered**:
  1. Add codecs and external PDF import now.
  2. Fail every unsupported image or reference XObject.
  3. Validate dictionary-level metadata and preserve unsupported data sources explicitly.
- **Selected Approach**: Store image filter names, encoded stream metadata, and reference XObject dictionaries structurally. Decode only supported filter chains for optional validation.
- **Rationale**: This gives users faithful PDF structure without adding large rendering dependencies.
- **Trade-offs**: Some byte-level image conformance checks remain deferred for unsupported filters.
- **Follow-up**: Future codec or external-file specs must revalidate filter handling and reference XObject contracts.

## Risks & Mitigations
- Recursive form XObjects can loop through resource references - add materialization stack tracking and a maximum recursion depth with a typed `ResourceFailure`.
- Optional content can be over-expanded into a full viewer model - support deterministic state construction and visibility evaluation, but leave UI controls, actions, annotations, and live state mutation out of scope.
- Unsupported image filters can hide malformed sample data - validate dictionary invariants always and perform decoded-length checks only for supported filters.
- Public `GraphicsEvent` changes may affect existing tests - add new event variants compatibly where possible and regenerate `pkg.generated.mbti` with `moon info`.
- Form execution can accidentally absorb rendering concerns - emit nested device-independent events and state snapshots only; do not rasterize, composite, or evaluate fonts.

## References
- `spec/extracted/8.8-8.11-xobjects-images-optional.spec.txt` - local ISO 32000-2 extraction for XObjects, images, forms, and optional content.
- `.kiro/specs/pdf-xobjects-images/requirements.md` - canonical requirements for this design.
- `.kiro/specs/pdf-content-streams/design.md` - upstream content instruction, inline image, and resource parsing boundary.
- `.kiro/specs/pdf-graphics/design.md` - existing graphics interpreter and state/event boundary.
- `.kiro/specs/pdf-colour-spaces/design.md` - colour-space component and range contracts used by image dictionaries.
- `.kiro/specs/pdf-patterns/design.md` - prior direct-resource and reader-materialization pattern.
- `.kiro/steering/product.md` - parser-first product scope and rendering non-goals.
- `.kiro/steering/tech.md` - MoonBit tooling and standard-library-only dependency policy.
- `.kiro/steering/structure.md` - repository layout and package dependency direction.
