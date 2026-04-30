# Implementation Plan

- [x] 1. Establish the text interpretation foundation
- [x] 1.1 Create the text package boundary and failure model
  - Add the text interpretation package with only the approved object, content, and filter dependencies.
  - Define deterministic text failures for bad operands, invalid text state, missing resources, invalid fonts, invalid CMaps, Unicode conversion failures, and wrapped content or filter failures.
  - Preserve source instruction offsets and resource context in failures so page-level callers can report actionable diagnostics.
  - Done when the package can be checked independently and malformed fixtures can assert stable error categories before reader integration exists.
  - _Requirements: 1.1, 1.2, 1.13, 2.1, 2.11_
  - _Boundary: TextInterpreter_

- [x] 1.2 Implement text-space value primitives
  - Represent text matrices, writing modes, rendering modes, glyph metrics, text rendering matrix snapshots, and text paint intent without renderer-specific output.
  - Support identity, replacement, line translation, glyph advance translation, horizontal scaling, text rise, and CTM-like composition in PDF matrix order.
  - Expose predicates for fill, stroke, invisible, and clipping rendering modes while keeping Type 3 exceptions observable for later interpretation.
  - Done when matrix tests reproduce ISO text-space equations and rendering-mode predicates cover modes 0 through 7.
  - _Requirements: 1.3, 1.4, 1.8, 1.10, 1.11, 1.16_
  - _Boundary: TextStateMachine_

- [x] 1.3 Define text program, event, resource, and extraction summaries
  - Model ordered text events, source strings, decoded glyphs, Unicode mappings, text spans, text resources, and final text state as inspectable values.
  - Keep glyph identity, source bytes, fallback flags, text matrix snapshots, and Unicode output separate so extraction does not erase display semantics.
  - Preserve empty strings and per-operator grouping in events while allowing consecutive extracted mappings to form spans.
  - Done when public tests can construct a text program summary without loading indirect objects or executing a renderer.
  - _Requirements: 1.2, 1.15, 2.29, 2.30_
  - _Boundary: TextInterpreter, UnicodeMapper_

- [x] 1.4 Establish bounded parsing and cache prerequisites
  - Add shared guards for bounded CMap recursion, bounded codespace lengths, bounded range expansion, and per-interpretation cache ownership.
  - Normalize malformed untrusted stream data into text errors without executing embedded font programs or using runtime network or system font APIs.
  - Keep static generated data source-controlled and reachable through direct lookups rather than linear scans in common paths.
  - Done when guard tests reject excessive CMap and mapping-table inputs while valid small fixtures still parse.
  - _Requirements: 2.18, 2.19, 2.27, 2.30, 2.31_
  - _Boundary: CMapResolver, FontResourceResolver, UnicodeMapper_

- [x] 2. Build font descriptor, static data, and encoding foundations
- [x] 2.1 (P) Parse common font descriptors, flags, and embedded program metadata
  - Validate common font descriptor entries, required metrics, optional style metrics, and the mutual exclusion of embedded font program streams.
  - Interpret descriptor flags for symbolic and nonsymbolic classification, fixed pitch, serif, script, italic, all-cap, small-cap, and force-bold characteristics.
  - Preserve embedded font stream organization and subtype metadata without interpreting Type 1, TrueType, CFF, or OpenType programs.
  - Done when descriptor fixtures accept complete dictionaries, reject malformed required fields, and expose embedded program metadata without bytecode execution.
  - _Requirements: 2.23, 2.24, 2.27_
  - _Boundary: FontDescriptorModel_

- [x] 2.2 Parse CIDFont descriptor extensions and style overrides
  - Validate CIDFont descriptor additions for language, CID subset streams, style dictionaries, and descriptor override dictionaries.
  - Preserve Panose bytes and FD override metrics while rejecting forbidden embedded font streams inside override descriptors.
  - Keep CIDFont descriptor data compatible with later CIDFont validation without depending on Type 0 parsing.
  - Done when CID descriptor fixtures expose style and FD summaries and reject override dictionaries that contain disallowed font-file entries.
  - _Requirements: 2.25, 2.26_
  - _Boundary: FontDescriptorModel_

- [ ] 2.3 (P) Provide standard font metrics and subset-name recognition
  - Add standard 14 font metric summaries and descriptor defaults used when legacy Type 1 dictionaries omit widths and descriptors.
  - Recognize six-uppercase-letter subset tags on font and descriptor names without merging subset fonts.
  - Keep standard font and subset metadata independent of system font lookup.
  - Done when standard 14 fixtures can obtain fallback widths and subset names produce tag and base-name summaries.
  - _Requirements: 2.3, 2.28_
  - _Boundary: Standard14Metrics, FontResourceResolver_

- [ ] 2.4 (P) Implement named encodings and Differences processing
  - Provide StandardEncoding, MacRomanEncoding, MacExpertEncoding, and WinAnsiEncoding code-to-glyph-name tables.
  - Apply encoding dictionaries with optional base encodings and non-overlapping Differences arrays in any allowed order.
  - Derive default base encodings from embedded font status and symbolic or nonsymbolic descriptor flags when no base encoding is supplied.
  - Done when encoding fixtures resolve named encodings, dictionary overrides, `.notdef`, symbolic defaults, and malformed Differences arrays deterministically.
  - _Requirements: 2.7, 2.8, 2.9, 2.24_
  - _Boundary: EncodingResolver_

- [ ] 2.5 (P) Provide glyph-name Unicode lookup data
  - Add Adobe glyph-name lookup coverage needed for standard Latin names, symbolic names, ligatures, and names used by Differences arrays.
  - Represent missing glyph-name mappings as unknown extraction results rather than text interpretation failures.
  - Keep lookup tables deterministic across native and wasm targets.
  - Done when glyph-name fixtures map known names to Unicode strings and unknown names preserve source glyph identity.
  - _Requirements: 2.29, 2.30_
  - _Boundary: UnicodeMapper_

- [ ] 3. Implement simple fonts and Type 3 glyph metadata
- [ ] 3.1 Validate simple Type 1, MMType1, and TrueType font dictionaries
  - Parse simple font dictionaries with required type, subtype, base font, character range, widths, descriptors, encodings, and optional ToUnicode streams.
  - Preserve MMType1 base-name conventions and TrueType or OpenType metadata while applying the simple-font single-byte code model.
  - Use descriptor missing width or standard 14 fallback metrics for codes outside declared widths where the specification permits.
  - Done when simple-font fixtures produce typed font summaries and invalid required entries fail before text showing reaches them.
  - _Requirements: 1.1, 1.2, 1.4, 2.1, 2.2, 2.3, 2.4, 2.5_
  - _Boundary: FontResourceResolver_
  - _Depends: 2.1, 2.3, 2.4_

- [ ] 3.2 Validate TrueType encoding plans
  - Represent the PDF TrueType character-code selection rules for named encodings, nonsymbolic fonts, symbolic fonts, and missing encoding entries.
  - Preserve platform cmap selection constraints and post-table fallback intent as metadata because font-program interpretation is deferred.
  - Reject encoding shapes that the PDF font dictionary cannot legally express while allowing processor-choice gaps as explicit fallbacks.
  - Done when TrueType fixtures distinguish nonsymbolic named encodings, symbolic no-encoding cases, ignored symbolic encodings, and unmappable processor-choice cases.
  - _Requirements: 2.5, 2.10_
  - _Boundary: EncodingResolver, FontResourceResolver_
  - _Depends: 3.1_

- [ ] 3.3 Validate Type 3 font dictionaries and encoding rules
  - Require Type 3 font bbox, font matrix, CharProcs, Encoding, character range, and widths while accepting optional resources, descriptors, and ToUnicode streams.
  - Enforce the complete Encoding requirement and the absence of a default glyph name for missing CharProcs entries.
  - Compute Type 3 widths through the font matrix while preserving horizontal simple-font displacement semantics.
  - Done when Type 3 fixtures accept complete font dictionaries, reject missing Encoding or CharProcs, and report no-paint glyphs when names are absent.
  - _Requirements: 1.4, 1.10, 2.6, 2.9_
  - _Boundary: Type3GlyphModel, FontResourceResolver_
  - _Depends: 2.4_

- [ ] 3.4 Validate Type 3 glyph streams and resource scope
  - Decode Type 3 CharProcs streams through the existing content and filter pipeline supplied by the caller.
  - Require `d0` or `d1` as the first glyph operator, validate declared widths and bounding boxes, and preserve color-bearing versus shape-only glyph behavior.
  - Resolve glyph resource scope from Type 3 font resources first and page resources when font resources are absent.
  - Done when glyph fixtures validate `d0` and `d1`, reject missing first operators, preserve glyph bbox metadata, and demonstrate graphics-state isolation for glyph invocation summaries.
  - _Requirements: 1.10, 2.6, 2.9_
  - _Boundary: Type3GlyphModel_
  - _Depends: 3.3_

- [ ] 3.5 Decode simple-font show strings to glyph metrics
  - Decode each source byte as one character code, map it through the font encoding, and attach glyph names, widths, `.notdef` fallback status, and word-spacing eligibility.
  - Apply Type 1 override behavior, Type 3 no-default-glyph behavior, and TrueType metadata-driven fallback behavior without executing font programs.
  - Keep decoded glyphs usable by both text matrix advancement and Unicode mapping.
  - Done when show-string fixtures expose one decoded glyph per byte with correct widths, fallback flags, and ASCII space eligibility.
  - _Requirements: 1.2, 1.4, 1.7, 1.15, 2.1, 2.8, 2.9, 2.10_
  - _Boundary: FontResourceResolver, EncodingResolver_
  - _Depends: 3.1, 3.2, 3.3_

- [ ] 4. Implement CIDFonts, CMaps, and Type 0 composite fonts
- [ ] 4.1 (P) Validate CIDSystemInfo and CIDFont dictionaries
  - Parse Registry, Ordering, and Supplement values and validate compatibility rules used between CMaps and CIDFonts.
  - Validate CIDFontType0 and CIDFontType2 dictionary entries, descriptor requirements, base names, and descendant-only usage.
  - Preserve CID glyph-selection metadata for CFF, TrueType, embedded, non-embedded, and CIDToGIDMap cases without interpreting font programs.
  - Done when CIDFont fixtures accept valid descendants, reject direct resource use, and expose compatibility metadata for Type 0 validation.
  - _Requirements: 2.11, 2.12, 2.13, 2.14, 2.15_
  - _Boundary: FontResourceResolver_
  - _Depends: 2.1, 2.2_

- [ ] 4.2 Compute CIDFont horizontal and vertical metrics
  - Parse default horizontal widths, explicit W arrays, default vertical metrics, explicit W2 arrays, duplicate-CID first-wins behavior, and CIDToGIDMap stream or Identity metadata.
  - Provide horizontal and vertical displacement plus vertical origin vectors according to the active writing mode.
  - Substitute CID 0 metrics when a CID or GID cannot be selected.
  - Done when CID metric fixtures cover DW, W, DW2, W2, duplicates, Identity mapping, stream-backed mapping, and CID 0 fallback.
  - _Requirements: 1.4, 2.15, 2.16, 2.22_
  - _Boundary: FontResourceResolver_
  - _Depends: 4.1_

- [ ] 4.3 (P) Model CMaps, predefined CMaps, and Identity mappings
  - Represent codespace ranges, character mappings, notdef mappings, writing mode, CMap names, and CIDSystemInfo summaries.
  - Support Identity-H and Identity-V directly, including two-byte big-endian CID decoding and writing-mode selection.
  - Register predefined CMap metadata and character-collection support without runtime downloads.
  - Done when predefined CMap fixtures resolve writing mode, Identity decoding, supported collection metadata, and disallowed non-embedded Identity usage.
  - _Requirements: 2.17, 2.18_
  - _Boundary: CMapResolver, PredefinedCMapTables_
  - _Depends: 1.4_

- [ ] 4.4 Parse embedded CMap streams and UseCMap composition
  - Decode embedded CMap streams and parse stream dictionaries, CMapName, CIDSystemInfo, WMode, codespace ranges, character mappings, notdef mappings, and UseCMap references.
  - Compose differing mappings over referenced CMaps while respecting recursion limits and caller-supplied materialization.
  - Reject overlapping codespaces, invalid code lengths, malformed mapping ranges, and incompatible CIDSystemInfo values.
  - Done when embedded CMap fixtures parse direct mappings, inherited UseCMap mappings, WMode overrides, and malformed stream failures.
  - _Requirements: 2.13, 2.19, 2.21, 2.22_
  - _Boundary: CMapResolver_
  - _Depends: 4.3_

- [ ] 4.5 Validate Type 0 font dictionaries and descendant integration
  - Parse Type 0 root font dictionaries with required base font, Encoding CMap, single descendant CIDFont, and optional ToUnicode stream.
  - Enforce CMap and CIDFont compatibility, descendant count, predefined CMap constraints for non-embedded Type 2 CIDFonts, and Type 0 font naming expectations.
  - Connect the Type 0 root to descendant metrics and composite character decoding without making `src/text` load indirect objects.
  - Done when Type 0 fixtures validate Identity-H, Identity-V, embedded CMap, incompatible CIDSystemInfo, invalid descendant count, and non-embedded constraints.
  - _Requirements: 1.2, 2.11, 2.12, 2.13, 2.18, 2.20_
  - _Boundary: FontResourceResolver, CMapResolver_
  - _Depends: 4.1, 4.2, 4.4_

- [ ] 4.6 Decode composite show strings and undefined characters
  - Decode one-to-four-byte character codes through CMap codespaces and mappings, selecting descendant 0 and CID values as required by PDF.
  - Apply notdef mappings, CID 0 fallback, invalid-code partial range consumption, and Type 2 CIDToGIDMap fallback behavior.
  - Preserve consumed source bytes and fallback reason in decoded glyph events.
  - Done when composite decoding fixtures cover valid mappings, missing mappings, notdef ranges, invalid partial matches, and byte-consumption edge cases.
  - _Requirements: 1.15, 2.21, 2.22_
  - _Boundary: CMapResolver, FontResourceResolver_
  - _Depends: 4.5_

- [ ] 5. Implement Unicode mapping and extracted text
- [ ] 5.1 Parse ToUnicode CMaps
  - Parse ToUnicode codespaces, bfchar mappings, bfrange string increments, bfrange destination arrays, UseCMap references, and UTF-16BE destination strings up to the permitted length.
  - Validate surrogate pairs, multi-codepoint destination strings, destination-array counts, and invalid range increment overflow.
  - Preserve source-code lengths for simple and CID-keyed fonts according to the font encoding.
  - Done when ToUnicode fixtures map single characters, ligatures, surrogate pairs, range increments, and destination arrays while rejecting malformed UTF-16BE.
  - _Requirements: 2.31_
  - _Boundary: CMapResolver, UnicodeMapper_
  - _Depends: 4.4_

- [ ] 5.2 Apply Unicode mapping priority
  - Map decoded glyphs through ToUnicode first, then simple-font glyph names, then predefined CMap and Adobe CID Unicode data, then unknown fallback.
  - Keep unknown mappings observable with source bytes, glyph identifier, and fallback reason instead of inventing character content.
  - Preserve one source code mapping to zero, one, or multiple Unicode scalar values as one extraction unit.
  - Done when mapping fixtures prove priority order, glyph-name fallback, predefined CID fallback, Identity unknown behavior, and multi-scalar output.
  - _Requirements: 2.29, 2.30, 2.31_
  - _Boundary: UnicodeMapper_
  - _Depends: 2.5, 4.6, 5.1_

- [ ] 5.3 Build extracted text spans from showing operations
  - Group Unicode and unknown mappings into extraction spans in content order while preserving source operator grouping, matrix snapshots, source bytes, and font identity.
  - Treat empty strings as valid events that do not force invented text content.
  - Keep extraction independent of ActualText, structure-tree reading order, reverse-order show strings, and paragraph reconstruction.
  - Done when extraction fixtures produce ordered spans for mixed known and unknown glyphs and preserve empty-string events without adding characters.
  - _Requirements: 1.15, 2.29, 2.30_
  - _Boundary: UnicodeMapper, TextInterpreter_
  - _Depends: 5.2_

- [ ] 6. Implement text state and interpreter semantics
- [ ] 6.1 Store text state defaults, stack behavior, and state operators
  - Initialize character spacing, word spacing, horizontal scaling, leading, missing current font, rendering mode, text rise, and text knockout defaults at page interpretation start.
  - Apply `Tc`, `Tw`, `Tz`, `TL`, `Tf`, `Tr`, and `Ts` inside or outside text objects and retain their values across text objects in one content stream.
  - Save and restore text state through graphics state stack operations and ignore ExtGState `/TK` changes between `BT` and `ET`.
  - Done when state tests show defaults, operator updates, q/Q restore behavior, negative font sizes, zero font sizes, rendering-mode validation, and `/TK` timing rules.
  - _Requirements: 1.5, 1.6, 1.7, 1.8, 1.9, 1.10, 1.11, 1.12_
  - _Boundary: TextStateMachine_
  - _Depends: 1.2_

- [ ] 6.2 Enforce text object lifecycle and positioning operators
  - Begin text objects with identity text matrix and line matrix and end text objects by discarding object-local matrices.
  - Reject nested `BT`, `ET` outside a text object, positioning outside a text object, and improperly interleaved q/Q with text objects.
  - Apply `Td`, `TD`, `Tm`, and `T*` exactly as matrix replacement or line movement operations require.
  - Done when lifecycle and positioning tests cover valid boundaries, invalid nesting, q/Q interleaving, leading side effects, matrix replacement, and next-line movement.
  - _Requirements: 1.13, 1.14_
  - _Boundary: TextStateMachine_
  - _Depends: 6.1_

- [ ] 6.3 Execute text showing operators and glyph advancement
  - Require a current font before showing text and apply `Tj`, quote, double quote, and `TJ` operators within text objects only.
  - Decode simple and composite strings through the selected font, apply character spacing, word spacing eligibility, horizontal scaling, writing mode, font size, and TJ numeric adjustments.
  - Update the text matrix for visible, invisible, clipping, empty, and fallback glyph cases while preserving source string grouping neutrality.
  - Done when showing tests cover all four showing operators, empty strings, one-glyph-per-call equivalence, horizontal and vertical writing, positive and negative TJ adjustments, and missing-font errors.
  - _Requirements: 1.2, 1.6, 1.7, 1.8, 1.9, 1.15, 1.16, 2.1, 2.11, 2.21_
  - _Boundary: TextInterpreter, TextStateMachine_
  - _Depends: 3.5, 4.6, 6.2_

- [ ] 6.4 Emit rendering matrices, paint intents, clipping summaries, and spans
  - Recompute text rendering matrix snapshots before each emitted glyph using font size, horizontal scaling, text rise, text matrix, and supplied CTM-like input.
  - Emit paint intent for fill, stroke, fill-stroke, invisible, and clipping modes while accumulating clipping summaries until `ET`.
  - Apply Type 3 rendering-mode exceptions and continue matrix updates for modes 3 and 7.
  - Done when interpreter tests show ordered glyph events, render matrix snapshots, clipping accumulation through ET, Type 3 no-clip behavior, and extracted spans from the same content pass.
  - _Requirements: 1.3, 1.10, 1.11, 1.15, 1.16, 2.6, 2.29, 2.30_
  - _Boundary: TextInterpreter, TextStateMachine, Type3GlyphModel, UnicodeMapper_
  - _Depends: 5.3, 6.3_

- [ ] 6.5 Handle text-relevant graphics operators during interpretation
  - Interpret text-relevant `q`, `Q`, `cm`, and `gs` effects while ignoring non-text graphics, color, marked-content, image, and path semantics outside the text boundary.
  - Apply ExtGState `/TK` only when permitted and preserve inherited CTM-like state needed for text rendering matrices.
  - Report bad operands and malformed resources with source offsets without changing content parser behavior.
  - Done when mixed-content fixtures update text state and CTM input correctly while non-text operators remain non-rendering no-ops for the text program.
  - _Requirements: 1.3, 1.5, 1.12, 1.13, 1.16_
  - _Boundary: TextInterpreter_
  - _Depends: 6.4_

- [ ] 7. Integrate page-level reader text APIs
- [ ] 7.1 Materialize page text resource graphs
  - Resolve inherited page Resources and materialize Font and ExtGState entries needed for text interpretation through the reader boundary.
  - Load indirect FontDescriptor, DescendantFonts, Encoding, ToUnicode, CMap, CharProcs, Type 3 Resources, and embedded font streams before calling the text package.
  - Detect unresolved required references, resource recursion limits, and stream decode failures as document-level resource failures.
  - Done when reader fixtures materialize nested simple, Type 0, Type 3, ToUnicode, and ExtGState resources without making the text package load objects.
  - _Requirements: 1.2, 1.12, 2.2, 2.6, 2.19, 2.20, 2.23, 2.27, 2.31_
  - _Boundary: ReaderTextBridge_
  - _Depends: 3.4, 4.5, 5.1, 6.5_

- [ ] 7.2 Expose page text program and extracted text APIs
  - Add page-level APIs that return materialized text resources, interpreted text programs, and extracted text using caller-supplied text options.
  - Wrap text failures as document errors while preserving existing content parsing, page content, object loading, and stream decoding errors.
  - Keep reader-to-text dependency one-way and avoid changes to content, graphics, object parser, page tree traversal, or xref loading semantics.
  - Done when page API tests can extract text from decoded page content and package boundary checks show no reverse dependency from text to reader.
  - _Requirements: 1.2, 2.2, 2.11, 2.20, 2.29, 2.30, 2.31_
  - _Boundary: ReaderTextBridge_
  - _Depends: 7.1_

- [ ] 7.3 Cache font, encoding, CMap, and Unicode parsing per page interpretation
  - Cache parsed text resources within one page interpretation so repeated font switches and ToUnicode lookups reuse parsed results.
  - Ensure cache ownership does not leak across pages or require mutable global state.
  - Preserve deterministic native and wasm behavior without runtime network or system font access.
  - Done when repeated-resource tests show one parsed resource summary reused within a page and independent pages do not share mutable cache state.
  - _Requirements: 1.2, 2.18, 2.19, 2.27, 2.30, 2.31_
  - _Boundary: ReaderTextBridge, TextInterpreter_
  - _Depends: 7.2_

- [ ] 8. Validate behavior, regressions, and public interfaces
- [ ] 8.1 Complete text state and interpreter unit coverage
  - Cover state defaults, q/Q restore, text object lifecycle, positioning operators, state operators, showing operators, render matrices, clipping modes, Type 3 exceptions, and operand errors.
  - Include word-spacing single-byte eligibility, horizontal scaling, text rise, leading, zero-sized text, negative font size, invisible modes, empty strings, and TJ numeric adjustments.
  - `moon test` for the text package passes with state, matrix, and interpreter coverage.
  - _Requirements: 1.2, 1.3, 1.5, 1.6, 1.7, 1.8, 1.9, 1.10, 1.11, 1.12, 1.13, 1.14, 1.15, 1.16_
  - _Boundary: TextStateMachine, TextInterpreter_
  - _Depends: 6.5_

- [ ] 8.2 Complete font, encoding, CMap, Unicode, and Type 3 unit coverage
  - Cover simple fonts, standard 14 fallback metrics, Type 1 overrides, MMType1 naming, TrueType encoding plans, Type 3 CharProcs, CIDFonts, Type 0 fonts, embedded and predefined CMaps, ToUnicode, glyph-name Unicode, and unknown mappings.
  - Include malformed dictionaries, malformed widths, descriptor flag conflicts, CIDSystemInfo incompatibility, CMap undefined-character handling, surrogate pairs, ligature strings, subset tags, and embedded font stream metadata.
  - `moon test` for the text package passes with deterministic fixtures and no runtime network or system font dependency.
  - _Requirements: 1.1, 1.4, 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7, 2.8, 2.9, 2.10, 2.11, 2.12, 2.13, 2.14, 2.15, 2.16, 2.17, 2.18, 2.19, 2.20, 2.21, 2.22, 2.23, 2.24, 2.25, 2.26, 2.27, 2.28, 2.29, 2.30, 2.31_
  - _Boundary: FontResourceResolver, EncodingResolver, CMapResolver, UnicodeMapper, Type3GlyphModel, FontDescriptorModel_
  - _Depends: 5.3, 6.4_

- [ ] 8.3 Complete reader bridge integration coverage
  - Cover inherited page Resources, indirect font graph materialization, FontDescriptor, ToUnicode stream, DescendantFonts, CharProcs, Type 3 Resources, ExtGState `/TK`, and page content parsing through text APIs.
  - Assert document-error wrapping for text failures while preserving existing reader and content failures.
  - `moon test` for the reader package passes with page-level text program and extracted text coverage.
  - _Requirements: 1.2, 1.12, 2.2, 2.6, 2.19, 2.20, 2.23, 2.27, 2.29, 2.30, 2.31_
  - _Boundary: ReaderTextBridge_
  - _Depends: 7.3_

- [ ] 8.4 Validate sample extraction, performance boundaries, and security constraints
  - Extract text from Annex-style Type 1 examples and synthetic Type 0 Identity-H examples with ToUnicode ligatures and surrogate pairs.
  - Smoke-test bundled PDF 2.0 examples by invoking text APIs without regressing existing page parsing.
  - Cover large TJ arrays, large mapping tables, bounded UseCMap recursion, excessive range expansion, and absence of font-program execution or runtime network access.
  - Done when sample and load tests pass deterministically and security fixtures fail with bounded text errors.
  - _Requirements: 1.2, 1.15, 1.16, 2.18, 2.19, 2.21, 2.22, 2.27, 2.29, 2.30, 2.31_
  - _Boundary: TextInterpreter, CMapResolver, UnicodeMapper, ReaderTextBridge_
  - _Depends: 8.1, 8.2, 8.3_

- [ ] 8.5 Regenerate interfaces and run full project validation
  - Run formatting, type checking, targeted text and reader tests, full test coverage, and public interface generation after the feature is integrated.
  - Review generated interfaces to confirm only intended text and reader API additions are exposed.
  - Preserve existing content, graphics, filters, objects, parser, and reader behavior outside the documented text bridge.
  - Done when `moon fmt`, `moon check`, targeted tests, full `moon test`, and `moon info` complete successfully.
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8, 1.9, 1.10, 1.11, 1.12, 1.13, 1.14, 1.15, 1.16, 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7, 2.8, 2.9, 2.10, 2.11, 2.12, 2.13, 2.14, 2.15, 2.16, 2.17, 2.18, 2.19, 2.20, 2.21, 2.22, 2.23, 2.24, 2.25, 2.26, 2.27, 2.28, 2.29, 2.30, 2.31_
  - _Boundary: TextInterpreter, ReaderTextBridge_
  - _Depends: 8.4_
