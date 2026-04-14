# Research & Design Decisions

## Summary
- **Feature**: `pdf-common-data`
- **Discovery Scope**: Extension
- **Key Findings**:
  - The existing object model intentionally stores PDF strings as raw `Bytes`; clause 7.9 needs a document-hierarchy-only interpretation layer instead of changing `PdfObject::String`.
  - Rectangle, name-tree, and number-tree behavior already exists in `src/reader`, but the reusable value validation is mixed with reader-owned indirect-object loading.
  - A new standard-library-only `src/common_data` package can own pure clause 7.9 value semantics while `src/reader` keeps lazy tree traversal and public compatibility facades.

## Research Log

### Existing Object and Parser Boundaries
- **Context**: 7.9 common data structures are built from 7.3 object types, so the design must avoid breaking low-level syntax parsing.
- **Sources Consulted**:
  - `src/objects/types.mbt`
  - `src/objects/accessors.mbt`
  - `.kiro/specs/pdf-objects/design.md`
  - `.kiro/steering/tech.md`
- **Findings**:
  - `PdfObject::String(Bytes)` represents literal and hexadecimal string bytes without contextual qualification.
  - `PdfName` equality is byte-sequence based, with UTF-8 lossy conversion only for display.
  - Existing parser and lexer packages do not import reader-level semantics and should remain unchanged.
- **Implications**:
  - Text string, ASCII string, byte string, date, and text stream interpretation must be an opt-in layer over raw bytes.
  - The design must not alter `PdfObject`, `PdfStream`, `PdfName`, parser entry points, or lexer string decoding.

### Existing Reader Common Data Surfaces
- **Context**: The project already has reader features that partially implement 7.9 concepts.
- **Sources Consulted**:
  - `src/reader/document_types.mbt`
  - `src/reader/navigation_common.mbt`
  - `src/reader/name_dictionary.mbt`
  - `src/reader/number_tree.mbt`
  - `src/reader/page_labels.mbt`
  - `src/reader/annotations.mbt`
- **Findings**:
  - `PdfRectangle` is currently a reader public type, and rectangle parsing exists in multiple reader helpers.
  - Catalog name-tree APIs expose category-specific lookup and enumeration, backed by byte-wise key comparison.
  - Number-tree traversal is private and currently used by page labels and structure-tagged features.
  - Existing tree traversal requires `PdfFile::load_object`, cycle tracking, and reader error wrapping.
- **Implications**:
  - Public reader APIs should remain stable; implementation may delegate to `common_data` while preserving reader-facing names.
  - Tree traversal stays in `src/reader`; `common_data` should provide node-shape validation, byte/integer ordering helpers, and reusable entry models only where this does not force a dependency cycle.

### Cross-Package Consumers
- **Context**: Clause 7.9 values appear in reader, graphics, and interchange features, but content streams use different string conventions.
- **Sources Consulted**:
  - `src/interchange/types.mbt`
  - `src/interchange/page_piece.mbt`
  - `src/graphics/geometry.mbt`
  - `src/graphics/pattern_validation.mbt`
  - `src/graphics/form_xobject.mbt`
  - `src/content/operator.mbt`
- **Findings**:
  - Interchange currently preserves Info and page-piece dates as exact bytes and does not parse or normalize them.
  - Graphics defines `GraphicsRect` for geometry and form/pattern bounding boxes, separate from reader `PdfRectangle`.
  - Content stream parsing treats strings as operands for text and graphics operators and must not adopt document-hierarchy text-string rules.
- **Implications**:
  - `src/common_data` may be imported by `reader`, `interchange`, and `graphics`, but not by `content` for content-stream string interpretation.
  - Text stream validation must accept unencoded bytes from callers; stream filter decoding remains owned by `filters` and reader/graphics integration points.

### Technology and Dependency Check
- **Context**: The design must align with standard-library-only steering and MoonBit package boundaries.
- **Sources Consulted**:
  - `moon.mod.json`
  - `src/reader/moon.pkg`
  - `.kiro/steering/structure.md`
  - `moonbit-agent-guide` skill instructions
- **Findings**:
  - The project has no external dependencies and uses package directories with explicit `moon.pkg` imports.
  - Existing generated interface files are committed and should be regenerated with `moon info` after public API changes.
  - MoonBit files in one package share declarations, so cohesive file splitting is organizational rather than namespace-defining.
- **Implications**:
  - The design adds no external library.
  - `src/common_data/moon.pkg` imports only `trkbt10/pdf/src/objects`.
  - Downstream packages import `src/common_data`; upstream object, lexer, parser, filters, and content contracts remain unchanged.

## Architecture Pattern Evaluation

| Option | Description | Strengths | Risks / Limitations | Notes |
|--------|-------------|-----------|---------------------|-------|
| Reader-only helpers | Keep all 7.9 interpretation inside `src/reader`. | Minimal package churn and preserves current tree loading implementation. | Interchange and graphics cannot reuse date, text-string, or rectangle validation without depending on reader. | Rejected because 7.9 data structures are shared outside reader APIs. |
| Common pure value package plus reader traversal | Add `src/common_data` for pure value semantics and keep indirect tree traversal in `src/reader`. | Preserves dependency direction, avoids changing `PdfObject`, and supports cross-package reuse. | Requires compatibility wrappers for existing reader public types and careful API review. | Selected. |
| Full common traversal engine | Move name and number tree traversal into `src/common_data` with a resolver callback. | Maximizes reuse and centralizes all tree logic. | MoonBit callback and raised-error shape would add abstraction around the existing `PdfFile::load_object` path. | Rejected for initial scope; use pure validation helpers and keep traversal near object loading. |
| External Unicode or PDF utility dependency | Adopt a library for PDFDocEncoding, UTF-16BE, UTF-8, BCP 47, or date parsing. | Could reduce manual table work. | Violates current no-external-dependency steering and introduces version/license surface. | Rejected. |

## Design Decisions

### Decision: Preserve Raw Object Semantics and Add Opt-In Interpretation
- **Context**: `PdfObject::String(Bytes)` is the shared low-level representation across parser, reader, content, graphics, and interchange packages.
- **Alternatives Considered**:
  1. Change `PdfObject::String` to store qualified text/byte/ASCII variants.
  2. Add `src/common_data` APIs that classify and decode raw bytes when a document-hierarchy consumer asks for a qualified value.
- **Selected Approach**: Keep `PdfObject::String(Bytes)` unchanged and add opt-in text, ASCII, byte-string, date, and text-stream parsers in `src/common_data`.
- **Rationale**: Clause 7.9 string conventions apply outside content streams; changing the object model would incorrectly leak document semantics into content parsing.
- **Trade-offs**: Callers must explicitly choose the expected qualification, but low-level parser compatibility and content-stream behavior remain stable.
- **Follow-up**: Implementation tests must prove content-stream parser behavior and `PdfObject` public interfaces are unchanged.

### Decision: Build PDFDocEncoding Locally
- **Context**: PDFDocEncoding is required for text string decoding and is referenced by clause 7.9 through Annex D.
- **Alternatives Considered**:
  1. Use an external encoding library.
  2. Embed a fixed table in `src/common_data/pdf_doc_encoding.mbt`.
- **Selected Approach**: Embed the PDFDocEncoding byte-to-Unicode mapping as a local table with focused tests for ASCII, documented special bytes, undefined bytes, and round-trip-free decode behavior.
- **Rationale**: The project forbids external dependencies, and PDFDocEncoding is a fixed PDF standard mapping.
- **Trade-offs**: The implementation must carefully transcribe and test the table.
- **Follow-up**: Validate the table against available ISO Annex D material during implementation review.

### Decision: Keep Tree Traversal in Reader
- **Context**: Name and number tree lookup requires lazy indirect-object loading, missing-object behavior, and cycle diagnostics.
- **Alternatives Considered**:
  1. Move traversal to `src/common_data` with a generic resolver contract.
  2. Keep traversal in `src/reader` and call common helpers for ordering, pair validation, and limits validation.
- **Selected Approach**: Keep traversal in `src/reader`, use `common_data` for pure checks, and retain existing reader error wrapping.
- **Rationale**: The reader package already owns `PdfFile::load_object` and document-level lazy traversal. A generic callback layer would add complexity without changing the current consumers.
- **Trade-offs**: Tree traversal is not directly reusable by graphics or interchange, but those packages currently do not own tree loading.
- **Follow-up**: Revisit a resolver abstraction only if a second package needs indirect tree traversal.

### Decision: Preserve Reader Public Compatibility While Introducing Common Types
- **Context**: Existing specs and generated interfaces already expose `@reader.PdfRectangle`, `PdfNameTreeEntry`, and `PdfNumberTreeEntry`.
- **Alternatives Considered**:
  1. Replace reader public types with `@common_data` types immediately.
  2. Keep reader public facades and delegate implementation to `common_data` where possible.
- **Selected Approach**: Prefer compatibility aliases when MoonBit interface generation preserves existing names; otherwise keep reader structs and add conversion helpers.
- **Rationale**: `pdf-common-data` should reduce duplication without forcing unrelated downstream specs to absorb an API break.
- **Trade-offs**: Some short-term wrappers may remain in `src/reader`.
- **Follow-up**: `moon info` must be reviewed to confirm only intentional public API additions or aliases appear.

## Synthesis Outcomes
- **Generalization**: Text strings, dates, and text streams are all byte interpretation problems over raw string or unencoded stream bytes; they share one `PdfTextString` decoder instead of separate ad hoc parsers.
- **Generalization**: Name trees and number trees share pair-array validation, ordering, duplicate-key rejection, and cycle-aware traversal shape; common helpers should parameterize key comparison without moving reader-owned object loading.
- **Build vs. Adopt**: The design builds local PDFDocEncoding, UTF-16BE BOM handling, date parsing, and tree validation because no external dependencies are allowed and the algorithms are small, deterministic, and PDF-specific.
- **Simplification**: No writer, normalization, BCP 47 registry validation, Unicode normalization, calendar arithmetic, or generic callback traversal is included in this spec.

## Risks & Mitigations
- PDFDocEncoding table transcription errors - Mitigate with table-focused tests for ASCII identity, documented special characters, undefined byte rejection, and known examples.
- Public API churn from moving rectangle and tree entry models - Mitigate with reader compatibility facades and `moon info` review before completion.
- Content-stream string semantics accidentally using document-hierarchy text rules - Mitigate by keeping `content` out of `common_data` for string interpretation and adding regression tests.
- Tree traversal over malformed or cyclic structures can be expensive or recursive - Mitigate with visited indirect-object sets, limits pruning for name trees, duplicate-key checks, pair-array validation, and bounded lookup tests.
- Date parser may over-normalize legacy or incomplete strings - Mitigate by preserving raw bytes and deriving defaulted fields without converting to system time.

## References
- `spec/extracted/7.9-common-data-structures.spec.txt` - Source excerpt for text strings, dates, rectangles, name trees, and number trees.
- `spec/extracted/7.9-common-data.md` - Extracted ISO pages for clause 7.9 context.
- `.kiro/steering/product.md` - Read-side, standards-first project goal.
- `.kiro/steering/tech.md` - MoonBit tooling, dependency, and architecture constraints.
- `.kiro/steering/structure.md` - Package layout and dependency direction.
- `src/objects/types.mbt` - Existing raw PDF object model.
- `src/reader/name_dictionary.mbt` and `src/reader/number_tree.mbt` - Current tree traversal implementation.
