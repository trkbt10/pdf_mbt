# Research & Design Decisions

## Summary
- **Feature**: `pdf-content-streams`
- **Discovery Scope**: Extension / Complex Integration
- **Key Findings**:
  - Content streams can reuse the existing byte cursor, lexical classifier, string reader, name reader, object model, and filter pipeline, but they need a dedicated parser because regular keywords become operators instead of object-parse errors.
  - Page-level integration belongs in `src/reader`, while the reusable content-stream parser belongs in a new `src/content` package. This avoids a package cycle and preserves the existing dependency direction.
  - Resource resolution is a scoped dictionary problem, not a rendering problem. The design exposes resource contexts and lookups without interpreting fonts, color spaces, XObjects, or graphics/text state.

## Research Log

### Existing Parser and Lexer Fit
- **Context**: Requirement 1 needs PDF object operands and operator keywords in one sequential stream.
- **Sources Consulted**:
  - `src/lexer/cursor.mbt`
  - `src/lexer/lexer.mbt`
  - `src/lexer/token.mbt`
  - `src/parser/parser.mbt`
  - `src/objects/types.mbt`
- **Findings**:
  - `@lexer.ByteCursor`, `@lexer.Lexer`, `read_literal_string`, `read_hex_string`, and `read_name` are public and can be reused by a downstream content package.
  - `@parser.ObjectParser` treats regular keywords that are not object keywords as object errors, which is correct for file object syntax but wrong for content streams.
  - The content parser must parse direct operands itself and stop an instruction when a regular token maps to an operator.
- **Implications**:
  - Add a `src/content` package that imports `objects`, `lexer`, and `filters`.
  - Do not change `src/parser` semantics for content-specific keywords.

### Reader and Document Integration
- **Context**: Requirement 6 needs page references, Contents resolution, inherited Resources, filter decoding, and single-stream or array-of-stream Contents handling.
- **Sources Consulted**:
  - `src/reader/document_types.mbt`
  - `src/reader/document_structure.mbt`
  - `src/reader/object_loader.mbt`
  - `src/reader/stream_decode.mbt`
  - `src/reader/pkg.generated.mbti`
  - `.kiro/specs/pdf-document-structure/design.md`
- **Findings**:
  - `PdfPage::contents()` returns the raw page Contents entry and `PdfPage::resources()` resolves inherited Resources.
  - `PdfPage::resolve_entry()` resolves indirect references in arrays, which matches Contents array handling.
  - `PdfFile::load_object()` already owns lazy indirect object loading and missing-object behavior.
  - `decode_structural_stream` is intentionally private and restricted to xref/object-stream structural decoding.
- **Implications**:
  - Add reader-side bridge APIs for page content parsing rather than making `src/content` import `src/reader`.
  - The bridge resolves Contents streams through `PdfFile::load_object`, decodes each stream with `@filters.decode_stream`, and concatenates decoded streams with an implicit LF byte.
  - Reader error contracts need a content-error wrapper for page parsing failures.

### PDF 2.0 Content Stream and Resource Rules
- **Context**: Requirements cite ISO 32000-2:2020 section 7.8 and Annex A.
- **Sources Consulted**:
  - `spec/extracted/7.8-content-streams.spec.txt`
  - `spec/extracted/annex-a-operators.spec.txt`
- **Findings**:
  - Content streams use ordinary PDF lexical rules after filter decoding, but operands are direct objects and indirect objects/references are not permitted.
  - Operators are regular keywords without a leading slash. Annex A enumerates the standard operator vocabulary.
  - Unknown operators are errors outside compatibility sections. `BX` and `EX` bracket compatibility sections where unrecognized operators and their operands are ignored.
  - Resource dictionaries are scoped to the current stream. Page contents use page/inherited Resources; Form XObjects use their own Resources when present and otherwise may inherit the page resource dictionary for older files.
- **Implications**:
  - The design includes a standard operator registry plus compatibility-depth tracking.
  - Inline image parsing is modeled as a special instruction because `BI`, `ID`, and `EI` do not fit ordinary operator/operand tokenization.
  - Resource context APIs are separate from instruction parsing so downstream interpreters can resolve names without forcing rendering semantics into this spec.

### External Dependency Verification
- **Context**: Discovery rules require dependency verification for new libraries.
- **Sources Consulted**:
  - `.kiro/steering/tech.md`
  - Existing `moon.pkg` files under `src/`
- **Findings**:
  - Project steering requires no external dependencies beyond the MoonBit standard library and existing local packages.
  - Existing local packages already provide all required primitives: object model, lexer, filter decoding, and document/page access.
- **Implications**:
  - No web or third-party package research is needed for this design.
  - The design preserves native and wasm suitability by avoiding FFI, file-system, and platform-specific runtime requirements.

## Architecture Pattern Evaluation

| Option | Description | Strengths | Risks / Limitations | Notes |
|--------|-------------|-----------|---------------------|-------|
| Add content parsing to `src/parser` | Extend object parser to understand operators | Reuses parser state directly | Blurs object syntax and content syntax; risks changing file object behavior | Rejected |
| Add content APIs directly in `src/reader` | Implement parser and page bridge together | Easy page integration | Parser would depend on reader state and be harder to test independently | Rejected |
| New `src/content` package plus reader bridge | Reusable content parser in its own package; page-specific APIs in reader | Preserves dependency direction, isolates syntax parser, supports raw and page-based entry points | Requires one reader import update and content-error wrapper | Selected |

## Design Decisions

### Decision: Dedicated Content Package
- **Context**: Content streams share lexical syntax with PDF objects but interpret regular keywords as operators.
- **Alternatives Considered**:
  1. Modify `src/parser` to accept an operator mode.
  2. Build a new content parser on top of `src/lexer`.
  3. Place all content parsing in `src/reader`.
- **Selected Approach**: Create `src/content` with its own parser, operand reader, operator registry, inline image reader, and resource context types.
- **Rationale**: This keeps file-object parsing stable and makes content parsing independently testable.
- **Trade-offs**: Some recursive direct-object parsing logic will mirror `src/parser`, but the content parser avoids stream and indirect-reference behavior that is illegal in content streams.
- **Follow-up**: During implementation, check whether small shared lexer helpers can reduce duplication without changing parser contracts.

### Decision: Reader Bridge Owns Page Integration
- **Context**: Requirement 6 needs page references, inherited Resources, Contents object loading, and filter decoding.
- **Alternatives Considered**:
  1. Make `src/content` import `src/reader`.
  2. Make `src/reader` import `src/content` and expose page content methods.
  3. Expose only raw decoded-byte APIs and leave page integration to callers.
- **Selected Approach**: Add reader-side APIs such as `PdfPage::content_stream()` and `PdfPage::content_instructions()` that delegate to `src/content`.
- **Rationale**: This avoids a dependency cycle and fulfills the page-reference integration requirement.
- **Trade-offs**: The public page API expands in `src/reader`, and `PdfDocumentError` must wrap content errors.
- **Follow-up**: Verify `moon info` shows only intended reader and content API additions.

### Decision: Parse Instructions, Do Not Execute Graphics
- **Context**: Requirements need tokenization, operator recognition, resources, and iteration, but not rendering or text extraction.
- **Alternatives Considered**:
  1. Validate operator arity and operand types for every standard operator.
  2. Parse instructions with raw `PdfObject` operands and leave semantic validation downstream.
- **Selected Approach**: Recognize operators and preserve operands exactly as direct `PdfObject` values, while rejecting malformed lexical content, illegal indirect references, streams, and unknown operators outside compatibility sections.
- **Rationale**: This layer is the syntactic bridge for future graphics state machines and text extraction. It should not own rendering semantics.
- **Trade-offs**: Some malformed operand/operator combinations are detected only by downstream interpreters.
- **Follow-up**: Add focused tests that prove dictionaries are accepted as operands syntactically without globally validating operator-specific arity.

### Decision: Inline Image as a Distinct Instruction
- **Context**: Inline images use `BI`, dictionary-like key/value pairs, `ID`, raw bytes, and `EI`.
- **Alternatives Considered**:
  1. Emit separate `BI`, `ID`, and `EI` instructions.
  2. Emit one `InlineImage` instruction with dictionary and raw data.
- **Selected Approach**: Represent inline images as `ContentInstruction::InlineImage(PdfInlineImage)`.
- **Rationale**: Raw image bytes are not ordinary PDF tokens, and downstream consumers need the dictionary and bytes as one unit.
- **Trade-offs**: `BI`, `ID`, and `EI` are recognized by the inline-image reader rather than exposed as normal operators.
- **Follow-up**: Test false `EI` byte sequences inside image data with the selected terminator scanner.

## Risks & Mitigations
- Inline image end detection can confuse raw image bytes containing `EI` - mitigate with a scanner that only accepts `EI` when preceded and followed by required delimiter/white-space conditions.
- Duplicating direct-object parsing for content streams can drift from object parser behavior - mitigate with shared lexer readers and test vectors covering numbers, strings, names, arrays, and dictionaries.
- Page Contents arrays may contain indirect references, direct streams, or malformed objects - mitigate with reader bridge validation and byte-offset-preserving content errors.
- Resource dictionaries can be indirect or malformed - mitigate by resolving through `PdfFile::load_object` at reader boundaries and validating resource-category shapes in content resource APIs.

## References
- `spec/extracted/7.8-content-streams.spec.txt` - content stream, operator, compatibility, and resource dictionary rules.
- `spec/extracted/annex-a-operators.spec.txt` - standard PDF content stream operator list.
- `.kiro/steering/product.md` - PDF 2.0 parser product goals and non-goals.
- `.kiro/steering/tech.md` - MoonBit tooling, no external dependency policy, byte-stream parser principles.
- `.kiro/steering/structure.md` - package layout and dependency direction.
