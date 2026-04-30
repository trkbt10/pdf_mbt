# Implementation Plan

- [x] 1. Foundation: content package setup and diagnostics
- [x] 1.1 Establish the content parsing package and byte-offset foundation
  - Add the package manifest with only the allowed dependencies needed for content parsing.
  - Align decoded-byte inputs with the existing byte cursor and offset conventions used by lower parsing layers.
  - Add package-local build and test scaffolding so later parser, operator, image, and resource work can be validated independently.
  - Done: the content package builds on its own and has a neutral decoded-byte parsing foundation for subsequent components.
  - _Requirements: 4.1, 4.4_
  - _Boundary: ContentPackage_

- [x] 1.2 Add content-stream diagnostic and wrapping behavior
  - Add a content error boundary for malformed syntax, unknown operators, illegal operands, inline-image failures, resource failures, and filter failures.
  - Include byte offsets in syntax and inline-image errors so callers can locate malformed decoded content.
  - Convert lower-level lexer, object, and filter failures into content-stream context without changing their owning packages.
  - Done: malformed content can be reported as a typed content error with a stable offset and reason.
  - _Requirements: 4.4_
  - _Boundary: PdfContentError_

- [x] 2. Core content syntax parsing
- [x] 2.1 (P) Recognize the standard content operator vocabulary
  - Define the public standard operator model and map exact operator keywords from Annex A to stable variants.
  - Include graphics state, path construction, path painting, clipping, text, color, XObject, inline image, marked content, compatibility, shading, and glyph-width operators.
  - Treat inline-image grammar markers as recognized keywords while preserving their special parsing role for the parser.
  - Done: every required operator keyword is recognized byte-for-byte and unknown keywords remain distinguishable.
  - _Depends: 1.1_
  - _Requirements: 1.2, 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7, 2.8, 2.9, 2.10_
  - _Boundary: OperatorRegistry_

- [x] 2.2 (P) Parse direct PDF operands in content streams
  - Parse numbers, strings, names, arrays, dictionaries, booleans, and null values before operators.
  - Reuse existing byte-level lexical behavior for names and strings while applying content-stream restrictions.
  - Reject indirect references, stream-like constructs, unexpected delimiters, invalid numbers, and unterminated aggregate operands with content errors.
  - Done: a token sequence of operands followed by an operator candidate yields direct operand values without creating indirect references.
  - _Depends: 1.1, 1.2_
  - _Requirements: 1.1, 4.2, 4.4_
  - _Boundary: ContentOperandReader_

- [x] 2.3 Track compatibility sections and unknown operator behavior
  - Maintain balanced compatibility depth for begin and end compatibility operators.
  - Raise clear errors for unknown operators outside compatibility sections.
  - Ignore unknown operators and their accumulated operands while inside compatibility sections.
  - Done: the same unknown keyword errors outside compatibility mode and is skipped inside a balanced compatibility block.
  - _Requirements: 2.9, 4.4_
  - _Boundary: CompatibilityTracker, ContentStreamParser_

- [x] 2.4 Parse inline image dictionaries and raw data
  - Define the inline image value model owned by the inline image parser.
  - After the inline-image begin marker, collect key-value pairs until the image-data marker.
  - Consume the required single whitespace byte before raw image data and scan for a valid end-image marker without tokenizing image bytes.
  - Expand required abbreviated image dictionary keys into canonical names.
  - Done: the inline image reader returns the expanded dictionary, exact raw bytes, and start/data/end offsets.
  - _Depends: 2.1, 2.2_
  - _Requirements: 1.4, 5.1, 5.2, 5.3, 5.4_
  - _Boundary: InlineImageReader_

- [x] 2.5 Build decoded-byte instruction iteration
  - Define the public instruction and content stream aggregate that use the operator, operand, inline image, and resource models from their owning components.
  - Iterate decoded content bytes one instruction at a time, collecting operands until an operator is emitted.
  - Clear operands after each emitted instruction and preserve source order and instruction start offsets.
  - Delegate inline image sequences to the inline-image reader and return them as distinct instructions.
  - Done: a decoded content stream produces an ordered sequence of normal and inline-image instructions or stops at end of input.
  - _Depends: 2.1, 2.2, 2.3, 2.4_
  - _Requirements: 1.3, 1.4, 4.1, 4.2, 4.4, 5.3_
  - _Boundary: ContentStreamParser, ContentStream_

- [x] 3. Resource context support
- [x] 3.1 Build resource category lookup
  - Define the public resource context and category model for graphics state, color spaces, patterns, shadings, XObjects, fonts, properties, and procedure sets.
  - Return absent categories and absent names as missing values while preserving malformed explicit category values as content errors.
  - Resolve named resources by exact resource name from the selected category without recursively loading indirect objects.
  - Done: callers can look up a resource category/name pair and receive the raw resource object or a missing result.
  - _Requirements: 3.2, 3.3_
  - _Boundary: ContentResources_

- [x] 3.2 Select Form XObject resource scope
  - Detect whether a Form XObject stream dictionary provides its own resource dictionary.
  - Use the Form XObject resources when present and fall back to the parent/page resource context when absent.
  - Report malformed Form XObject resource shapes through content errors.
  - Done: resource lookup for a form scope prefers form-local resources and otherwise returns parent resources.
  - _Requirements: 3.4_
  - _Boundary: ContentResources_

- [x] 4. Stream input and page integration
- [x] 4.1 Connect decoded and stream-based content parsing workflows
  - Provide the decoded-byte entry point that accepts a resource context and returns a parsed content stream.
  - Provide the stream-based helper that decodes stream bytes through the filter pipeline before parsing.
  - Preserve byte offsets relative to the decoded input supplied to the parser.
  - Done: callers can parse already-decoded bytes directly or parse a stream through filters and receive the same instruction model.
  - _Depends: 2.5, 3.1_
  - _Requirements: 4.1, 4.2, 4.4, 6.2_
  - _Boundary: ContentStreamParser, ContentStream, PdfContentError_

- [x] 4.2 Resolve page contents and inherited resources
  - Resolve the page resource dictionary through existing page inheritance behavior.
  - Resolve absent, single-stream, and array-of-stream page contents through the document structure layer.
  - Decode each content stream with the filter pipeline and concatenate multiple decoded streams with one line-feed separator in document order.
  - Done: a page with no contents returns an empty content stream, and pages with one or many streams parse from decoded bytes in the correct order.
  - _Depends: 3.1, 4.1_
  - _Requirements: 3.1, 4.3, 6.1, 6.2, 6.3_
  - _Boundary: ReaderPageContentBridge, ContentResources, FilterPipeline_

- [x] 4.3 Expose page-level content APIs and document error wrapping
  - Add page-level APIs for content resources, parsed content streams, and instruction arrays.
  - Wrap content and filter failures as document-layer errors at the page integration boundary.
  - Regenerate public package interfaces after the reader and content APIs are in place.
  - Done: document users can request page content instructions and receive either parsed instructions or a document error that preserves content-error context.
  - _Depends: 4.2_
  - _Requirements: 6.1, 6.2, 6.3_
  - _Boundary: ReaderPageContentBridge, PdfDocumentError_

- [ ] 5. Unit-level validation
- [x] 5.1 (P) Verify operator recognition coverage
  - Cover every required standard operator keyword, including punctuation and starred variants.
  - Cover inline-image marker keyword recognition and compatibility begin/end keyword recognition at the operator table boundary.
  - Keep unknown operator checks limited to distinguishable table misses, leaving parser skip/error behavior to parser tests.
  - Done: unit tests prove the Annex A vocabulary maps exactly to the intended operator variants.
  - _Depends: 2.1_
  - _Requirements: 1.2, 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7, 2.8, 2.9, 2.10_
  - _Boundary: OperatorRegistry_

- [x] 5.2 Verify operand parsing, parser iteration, and compatibility behavior
  - Cover direct operands for numbers, strings, names, arrays, dictionaries, booleans, and null.
  - Cover invalid indirect references, invalid aggregate syntax, unexpected delimiters, and byte-offset diagnostics.
  - Cover operand clearing, ordered operation emission, and unknown operator skip/error behavior across compatibility sections.
  - Done: parser tests prove operands become `PdfObject` values and each emitted normal instruction has the expected operator, operands, and offset.
  - _Depends: 2.2, 2.3, 2.5_
  - _Requirements: 1.1, 1.3, 2.9, 4.1, 4.2, 4.4_
  - _Boundary: ContentOperandReader, ContentStreamParser, CompatibilityTracker_

- [x] 5.3 Verify inline image parsing and parser emission
  - Cover key-value collection before image data, required whitespace after the image-data marker, and raw byte capture until a valid end marker.
  - Cover abbreviation expansion for required inline image dictionary names.
  - Cover malformed inline image cases such as missing data markers, missing end markers, and invalid key/value sequences.
  - Cover parser emission of one inline image instruction from a `BI`/`ID`/`EI` sequence.
  - Done: inline image tests prove the reader result and emitted instruction contain the expected dictionary, raw data, and offsets.
  - _Depends: 2.4, 2.5_
  - _Requirements: 1.4, 5.1, 5.2, 5.3, 5.4_
  - _Boundary: InlineImageReader, ContentStreamParser_

- [x] 5.4 (P) Verify resource lookup and Form XObject scope
  - Cover every supported resource category, absent categories, absent names, and malformed category values.
  - Cover exact name lookup without indirect object loading.
  - Cover Form XObject resource override and parent fallback behavior.
  - Done: resource tests prove category lookup and form scope selection return the expected raw resource values or errors.
  - _Depends: 3.1, 3.2_
  - _Requirements: 3.2, 3.3, 3.4_
  - _Boundary: ContentResources_

- [ ] 6. Reader integration and fixture validation
- [ ] 6.1 Test page content resolution, decoding, concatenation, and error wrapping
  - Cover inherited page resources, missing contents, direct single-stream contents, and arrays of referenced streams.
  - Cover filter-decoded page streams and line-feed separation between concatenated decoded streams.
  - Cover malformed page content being returned as a document-layer content error.
  - Done: reader integration tests parse page content through the public page workflow and verify resources, instruction order, and wrapped errors.
  - _Depends: 4.3_
  - _Requirements: 3.1, 4.3, 4.4, 6.1, 6.2, 6.3_
  - _Boundary: ReaderPageContentBridge, PdfDocumentError_

- [ ] 6.2 Add PDF 2.0 fixture and synthetic content smoke coverage
  - Parse bundled PDF 2.0 example page content and assert recognized drawing or text instructions are emitted.
  - Parse a synthetic inline-image page and verify one inline image instruction is emitted.
  - Parse a synthetic Form XObject resource scenario and verify form-local resources are selected.
  - Done: fixture tests exercise page-level parsing against representative PDF 2.0 and synthetic content cases.
  - _Depends: 6.1_
  - _Requirements: 1.4, 3.4, 5.3, 6.1, 6.2_
  - _Boundary: ReaderPageContentBridge, ContentResources, InlineImageReader_

- [ ] 7. Final validation and regression hardening
- [ ] 7.1 Add parser robustness and performance regression coverage
  - Cover a large synthetic content stream with thousands of simple operators to validate linear progress.
  - Cover multi-stream page concatenation with stable offsets around inserted line-feed separators.
  - Cover large inline image data with a missing or delayed end marker to validate bounded scanning and clear errors.
  - Done: regression tests complete without hangs, repeated whole-buffer reparsing, or out-of-bounds reads.
  - _Depends: 5.2, 5.3, 6.1_
  - _Requirements: 4.3, 4.4, 5.2, 6.3_
  - _Boundary: ContentStreamParser, InlineImageReader, ReaderPageContentBridge_

- [ ] 7.2 Run formatting, full checks, tests, and public API generation
  - Format the MoonBit codebase and regenerate public package interface files.
  - Run the project check and test commands for the content and reader changes.
  - Inspect the generated public interfaces for the intended content and page-level APIs.
  - Done: formatting, checks, tests, and generated interfaces are clean for the completed feature.
  - _Depends: 7.1_
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7, 2.8, 2.9, 2.10, 3.1, 3.2, 3.3, 3.4, 4.1, 4.2, 4.3, 4.4, 5.1, 5.2, 5.3, 5.4, 6.1, 6.2, 6.3_
  - _Boundary: BuildValidation, PublicInterfaces_

## Implementation Notes
- 2.2: Accepted from inherited green WIP using current spec-alignment evidence supplied in the resume context; `moon test src/content` and `moon check` pass.
