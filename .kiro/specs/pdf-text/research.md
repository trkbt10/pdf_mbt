# Research & Design Decisions

## Summary
- **Feature**: `pdf-text`
- **Discovery Scope**: Extension / Complex Integration
- **Key Findings**:
  - Text support sits downstream of `src/content`: content already recognizes `BT`, `ET`, text state, text showing, Type 3 `d0` and `d1` operators, while `src/graphics` currently classifies text operators as future-domain events.
  - Font dictionaries, encodings, CMaps, metrics, and Unicode extraction need a dedicated `src/text` package. Page object loading and resource materialization remain in `src/reader` to avoid package cycles.
  - Full Type 1, TrueType, CFF, and OpenType glyph program interpretation is larger than the current parser/extraction scope. The design records font program streams, validates PDF dictionary contracts, computes metrics from PDF dictionaries, and emits abstract glyph/text events without rasterizing or hinting glyph outlines.

## Research Log

### Existing Content and Graphics Boundaries
- **Context**: Requirements 1.5 through 1.16 require text state and text object semantics over parsed content stream operators.
- **Sources Consulted**:
  - `src/content/pkg.generated.mbti`
  - `src/content/operator.mbt`
  - `src/graphics/interpreter.mbt`
  - `src/graphics/object_context.mbt`
  - `src/graphics/state.mbt`
- **Findings**:
  - `src/content` already exposes all text operators as `StandardContentOperator` variants and preserves raw operands as `PdfObject` values.
  - `src/graphics` enforces `BT` and `ET` object context and emits begin/end text events, but it ignores text-domain operators.
  - `GraphicsState` already stores the `text_knockout` graphics state parameter from ExtGState `/TK`, but no text-specific state object exists.
- **Implications**:
  - Text semantics should consume `@content.ContentStream` directly rather than changing the content parser.
  - The text interpreter needs its own text state stack for `q` and `Q`, text object lifecycle, text matrix, line matrix, and text rendering matrix computations.
  - `src/graphics` should remain unchanged for this spec unless implementation discovers a narrow API reuse need.

### Reader Integration and Resource Materialization
- **Context**: Requirements 1.2, 2.2 through 2.31 require font resources, descendant fonts, CMaps, ToUnicode streams, and embedded font streams that can be indirect objects.
- **Sources Consulted**:
  - `src/reader/page_content.mbt`
  - `src/reader/xobjects.mbt`
  - `src/reader/graphics.mbt`
  - `src/reader/pkg.generated.mbti`
  - `src/content/resources.mbt`
- **Findings**:
  - Page content parsing already resolves inherited page Resources and decodes Contents streams.
  - XObject support introduced a useful reader pattern: materialize selected resource categories by loading indirect references in `src/reader`, then pass a plain `ContentResources` value to downstream interpreters.
  - Font resources are currently left as raw direct objects or indirect references.
- **Implications**:
  - Add reader-side `PdfPage::text_program` and materialized font resource APIs rather than making `src/text` load indirect objects.
  - Font, CMap, ToUnicode, FontDescriptor, CharProcs, and embedded font streams that appear as indirect references are loaded by `src/reader`.
  - The reusable text interpreter receives already materialized resource objects and remains independent of `PdfFile`.

### Font Dictionary and Metrics Scope
- **Context**: Requirements 2.1 through 2.28 cover simple fonts, Type 0 fonts, CIDFonts, font descriptors, embedded font programs, and subsets.
- **Sources Consulted**:
  - `.kiro/specs/pdf-text/requirements.md`
  - `spec/extracted/9-text.spec.txt`
  - `src/objects/types.mbt`
  - `src/filters/pkg.generated.mbti`
- **Findings**:
  - The existing object model can represent every required font dictionary and stream structure.
  - PDF dictionaries contain the metrics needed for positioning: simple font `Widths`, Type 3 `FontMatrix` and `Widths`, CIDFont `DW`, `W`, `DW2`, and `W2`.
  - Embedded font programs are important for rendering and some glyph-selection algorithms, but the project has no font-program interpreter or third-party dependency policy allowance.
- **Implications**:
  - The design owns structural font dictionary parsing and metric lookup.
  - The design explicitly does not own Type 1, TrueType, CFF, OpenType, hinting, or outline program interpretation.
  - Embedded font streams are preserved and lightly validated for PDF-level keys, then exposed as metadata for future renderer/font-program work.

### CMap and Unicode Extraction
- **Context**: Requirements 2.17 through 2.22 and 2.29 through 2.31 require CMap decoding, undefined character handling, and Unicode extraction.
- **Sources Consulted**:
  - `.kiro/specs/pdf-text/requirements.md`
  - `spec/extracted/9-text.spec.txt`
  - `src/content/stream_input.mbt`
- **Findings**:
  - Embedded CMap and ToUnicode streams use a PostScript-like CMap syntax distinct from the existing PDF object parser.
  - Identity-H and Identity-V are deterministic and small. Full predefined CJK CMap and Adobe CID-to-Unicode mappings are data-heavy, but they can be represented as generated MoonBit tables without adding runtime dependencies.
  - ToUnicode CMaps are the most reliable extraction source and must take precedence over glyph-name and predefined-CMap fallbacks.
- **Implications**:
  - Add a focused CMap parser for codespace ranges, CID mappings, notdef mappings, and ToUnicode `bfchar`/`bfrange` mappings.
  - Add built-in encoding and glyph-name tables for StandardEncoding, MacRomanEncoding, MacExpertEncoding, WinAnsiEncoding, the standard 14 font metrics, and Adobe glyph-name Unicode lookup.
  - Add a generated-data boundary for predefined CMaps and Adobe CID Unicode maps. Runtime network access is out of boundary.

### External Dependency Verification
- **Context**: Discovery rules require checking new dependencies and compatibility.
- **Sources Consulted**:
  - `.kiro/steering/tech.md`
  - `.kiro/steering/structure.md`
  - Existing `moon.pkg` files
- **Findings**:
  - Project steering requires MoonBit standard library only.
  - Existing packages already provide object modeling, byte parsing, content instruction parsing, stream decoding, and document/page loading.
  - No new package or service dependency is required. Static mapping data may be source-controlled or generated during implementation, but it is not a runtime dependency.
- **Implications**:
  - Do not add FFI, system font APIs, web fetches, or external font libraries.
  - If generated mapping data is added, implementation must verify source licensing before committing data.

## Architecture Pattern Evaluation

| Option | Description | Strengths | Risks / Limitations | Notes |
|--------|-------------|-----------|---------------------|-------|
| Extend `src/graphics` to own text | Add text state, fonts, CMaps, and extraction into the graphics interpreter | Reuses graphics state machinery | Makes graphics own font and extraction concerns; grows an already broad package | Rejected |
| Add all text APIs in `src/reader` | Implement page text extraction and font loading together | Direct access to indirect objects | Hard to test without whole PDFs; couples reusable text semantics to document loading | Rejected |
| New `src/text` package plus reader bridge | Reusable text/font/CMap interpreter; reader materializes font resources | Preserves package direction and isolates font/text contracts | Requires explicit conversion between page resources and text resources | Selected |
| Adopt a font engine | Use an external library for font programs and CMaps | Potentially complete glyph selection and metrics | Violates no-external-dependency steering and native/wasm portability assumptions | Rejected |

## Design Decisions

### Decision: Dedicated Text Package
- **Context**: Clause 9 combines content operators, font dictionaries, CMaps, metrics, and extraction. These are not pure graphics state or pure content syntax.
- **Alternatives Considered**:
  1. Add text execution to `src/graphics`.
  2. Add page-only text extraction to `src/reader`.
  3. Create a downstream `src/text` package and reader bridge.
- **Selected Approach**: Create `src/text` with text state, font models, encodings, CMaps, Unicode mapping, and text interpretation APIs. `src/reader` adds page-level APIs that materialize font resources and call `src/text`.
- **Rationale**: The package boundary keeps syntax parsing, graphics interpretation, and document loading independently testable.
- **Trade-offs**: Some CTM-related logic is duplicated as text-specific matrix state instead of sharing mutable graphics interpreter internals.
- **Follow-up**: Verify `moon info` shows only intended `text` and `reader` API additions.

### Decision: Dictionary-Driven Font Semantics
- **Context**: Requirements require glyph positioning, text matrices, font metrics, font descriptors, and Unicode extraction, but the project does not have a font-program interpreter.
- **Alternatives Considered**:
  1. Parse and execute Type 1, TrueType, CFF, and OpenType programs now.
  2. Use only PDF font dictionaries and embedded CMaps for current behavior.
- **Selected Approach**: Use PDF dictionaries, Widths, FontDescriptor, CMap, and ToUnicode data as the authoritative current scope. Preserve embedded font streams as typed metadata.
- **Rationale**: PDF dictionaries provide the metrics needed for text positioning and extraction in many files, while full font engines are a separate large subsystem.
- **Trade-offs**: Some glyph selection cases that depend entirely on malformed or environment-specific TrueType/OpenType font internals will produce abstract or unknown glyph results.
- **Follow-up**: Record unknown mappings in text events so future font-program work can improve them without changing the text interpreter contract.

### Decision: ToUnicode-First Extraction
- **Context**: Requirements 2.29 through 2.31 define extraction with ToUnicode, glyph names, and predefined CMap fallbacks.
- **Alternatives Considered**:
  1. Emit only glyph codes and leave Unicode mapping to callers.
  2. Resolve Unicode inside the text interpreter with layered fallbacks.
- **Selected Approach**: Resolve Unicode in this order: ToUnicode CMap, simple-font glyph names through built-in glyph-name tables, predefined CMap plus Adobe CID Unicode tables, then unknown mapping metadata.
- **Rationale**: This matches the standard's extraction priority and gives callers direct searchable text while preserving unresolved source codes.
- **Trade-offs**: Full predefined CMap coverage requires generated data and licensing verification.
- **Follow-up**: Add focused tests for ligature strings, surrogate-pair UTF-16BE values, Identity-H, notdef fallback, and unknown code preservation.

### Decision: Type 3 Glyphs as Abstract Invocations
- **Context**: Requirement 2.6 requires Type 3 glyph descriptions, `d0`, `d1`, glyph resources, and graphics-state save/restore behavior.
- **Alternatives Considered**:
  1. Execute Type 3 glyph streams through `src/graphics` during text interpretation.
  2. Record validated Type 3 glyph invocations and leave rendering to a later renderer.
- **Selected Approach**: Validate Type 3 font dictionaries, CharProcs, `d0`/`d1` first-operator contracts, widths, bounding boxes, resources, and color-restriction metadata, then emit `Type3GlyphInvocation` events with decoded glyph content instructions.
- **Rationale**: This satisfies parser and structural semantics without forcing rendering or creating a package cycle.
- **Trade-offs**: The graphics clipping path is not updated with real glyph outlines in this phase.
- **Follow-up**: Future rendering work can consume `Type3GlyphInvocation` and existing `src/graphics` primitives.

### Decision: Reader Owns Font Resource Materialization
- **Context**: Font dictionaries, descriptors, streams, CMaps, and CharProcs commonly appear through indirect references.
- **Alternatives Considered**:
  1. Let `src/text` import `src/reader` and load references.
  2. Materialize font-related resource graphs in `src/reader`.
- **Selected Approach**: `src/reader/text.mbt` loads font resource dictionaries, descendant fonts, descriptors, CMap streams, ToUnicode streams, CharProcs, embedded font streams, and ExtGState dictionaries needed by text interpretation.
- **Rationale**: Existing reader owns lazy object loading and document errors. Keeping that ownership prevents package cycles.
- **Trade-offs**: Reusable `src/text` APIs require callers outside `reader` to supply materialized objects.
- **Follow-up**: Add materialization recursion guards for Type 3 glyph resources and nested ToUnicode `UseCMap`.

## Risks & Mitigations
- Full predefined CMap and Adobe CID-to-Unicode data can be large - isolate generated tables in dedicated files, verify licensing, and keep runtime APIs table-driven.
- Font program dependent glyph selection can be implementation-dependent - preserve embedded font metadata and emit unknown glyph mappings instead of guessing.
- Text state is a graphics state subset and can drift from `src/graphics` - test shared operators such as `q`, `Q`, `cm`, `gs`, and `TK` against expected state transitions.
- Type 3 glyph streams can recursively use content resources - materialize CharProcs and resources in `src/reader` with recursion guards and clear errors.
- Unicode mapping can produce multiple Unicode scalar values per source code - model extracted text as arrays of scalar values or UTF-8 strings per glyph, not as one-codepoint assumptions.

## References
- `spec/extracted/9-text.spec.txt` - ISO 32000-2:2020 clause 9 text, font, CMap, and extraction requirements.
- `.kiro/specs/pdf-text/requirements.md` - Numeric requirement IDs and extracted source clauses.
- `.kiro/steering/product.md` - PDF 2.0 parser goals and non-goals.
- `.kiro/steering/tech.md` - MoonBit tooling, no external dependency policy, and parser architecture principles.
- `.kiro/steering/structure.md` - Package layout and dependency direction.
- `src/content/pkg.generated.mbti` - Existing content instruction and operator contract.
- `src/graphics/pkg.generated.mbti` - Existing graphics event and state contract.
- `src/reader/pkg.generated.mbti` - Existing page bridge and materialization contract.
