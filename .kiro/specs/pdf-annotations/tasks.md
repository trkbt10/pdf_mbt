# Implementation Plan

- [x] 1. Establish annotation model foundations and diagnostics
- [x] 1.1 Define the common annotation shell and annotation diagnostics
  - Add externally inspectable values for annotation identity, page association, common dictionary data, known and unknown subtype names, and flag state.
  - Add an annotation-specific reader-layer diagnostic that preserves existing catalog, page, navigation, content, and graphics error behavior.
  - Keep the existing raw page annotation accessor compatible while reserving the typed annotation surface for structural parsing.
  - Completion: public API review exposes the common annotation shell and diagnostic category, and existing document-structure callers compile without source changes.
  - _Requirements: 0.1, 0.2, 0.3, 0.6_

- [x] 1.2 Define shared descriptor model contracts
  - Add externally inspectable values for borders, border effects, appearance descriptors, appearance states, geometry operands, colours, markup metadata, annotation states, widget appearance characteristics, and fixed-print descriptors.
  - Model documented defaults as structural values rather than renderer behavior.
  - Completion: public API review shows descriptor records are available for parser results without adding rendering, action, form, or media execution contracts.
  - _Requirements: 0.4, 0.5, 0.7, 0.8, 0.10, 0.11, 0.12, 0.13, 0.14, 0.15, 0.16, 0.18, 0.24, 0.27, 0.28_

- [x] 1.3 Define visual and markup subtype model contracts
  - Add externally inspectable records for text, link, free text, line, square, circle, polygon, polyline, text markup, caret, stamp, ink, and popup subtype payloads.
  - Preserve extensible names and raw subtype dictionaries where the specification allows implementation-specific behavior.
  - Completion: API review shows each visual or markup subtype can carry its owned fields and raw dictionary without requiring adjacent-domain parsing.
  - _Requirements: 0.6, 0.9, 0.10, 0.11, 0.12, 0.13, 0.14, 0.15, 0.16, 0.17, 0.18, 0.19_

- [x] 1.4 Define raw, media, widget, and special subtype model contracts
  - Add externally inspectable records for file attachment, sound, movie, screen, widget, printer mark, trap network, watermark, redaction, projection, 3D raw, RichMedia raw, and unknown subtype payloads.
  - Store adjacent-domain fields as exact raw objects with field identity preserved for future specs.
  - Completion: API review shows raw and special subtype records can represent all required 12.5-owned fields without executing actions, opening files, playing media, applying redactions, or interpreting 3D and RichMedia payloads.
  - _Requirements: 0.6, 0.20, 0.21, 0.22, 0.23, 0.24, 0.25, 0.26, 0.27, 0.28, 0.29_

- [x] 1.5 Add shared annotation object-reading and primitive validation helpers
  - Provide cycle-safe indirect resolution for annotation-owned dictionaries, streams, and raw objects.
  - Provide reusable validation for names, booleans, integers, numbers, byte strings, arrays, rectangles, colours, opacity values, and byte-preserving text fields.
  - Ensure malformed present values raise annotation diagnostics while absent optional values remain available for parser-level defaults.
  - Completion: white-box tests exercise successful primitive extraction, malformed-shape failures, and indirect-reference cycle detection without touching lower parser packages.
  - _Requirements: 0.2, 0.3, 0.4, 0.5, 0.7, 0.10, 0.11, 0.12, 0.13, 0.14, 0.15, 0.16, 0.18, 0.24, 0.27, 0.28_

- [x] 1.6 Build annotation fixture coverage for page-owned object graphs
  - Add reusable in-memory document fixtures for missing, direct, and indirect page annotation arrays.
  - Include fixtures for reused indirect annotation references, popup or reply cycles, appearance streams, and raw adjacent-domain payloads.
  - Completion: fixture tests can open a minimal document, locate a page, and supply direct and indirect annotation dictionaries in page order for later parser tests.
  - _Requirements: 0.1, 0.2, 0.26_

- [x] 2. Resolve page/document annotation sources and tab metadata
- [x] 2.1 Resolve page annotation source entries for later typed parsing
  - Treat an absent page annotation entry as an empty annotation source list.
  - Require a present annotation entry to be an array and require each direct or resolved entry to be an annotation dictionary.
  - Preserve page annotation array order, page index, array position, and source indirect object identity when present.
  - Completion: source-entry tests show empty pages yield no sources, direct and indirect dictionaries are collected in array order, and malformed present entries raise annotation diagnostics before subtype parsing.
  - _Requirements: 0.1, 0.2, 0.26_

- [x] 2.2 Resolve document annotation sources with cross-page ownership validation
  - Traverse pages in document order and reuse page-level source entry resolution.
  - Reject the same indirect annotation dictionary when it is referenced from more than one page.
  - Preserve page grouping and page-local order in the flattened source list.
  - Completion: document-source tests show valid multi-page sources flatten deterministically and reused indirect annotations across pages are rejected before typed subtype parsing.
  - _Requirements: 0.1, 0.2_

- [x] 2.3 Parse page annotation tab-order metadata as structure
  - Parse row, column, structure, annotation-array, and widget tab-order names.
  - Preserve unknown tab-order names and return no value when the entry is absent.
  - Avoid sorting annotations, consulting viewer preferences, traversing logical structure, or computing keyboard focus order.
  - Completion: tab-order tests cover absent, known, and unknown names and show annotation source order remains unchanged.
  - _Requirements: 0.1_

- [x] 3. Parse common annotation dictionaries
- [x] 3.1 Parse common fields, defaults, flags, and common raw values
  - Require a subtype name and annotation rectangle before subtype parsing begins.
  - Accept the annotation type marker only when absent or valid, and preserve byte strings without text normalization.
  - Parse page reference, annotation name, modification date, flags with default zero, appearance state, common colour, structure parent, optional content, associated files, opacity, blend mode, language, and raw dictionary data.
  - Provide structural flag helpers for screen visibility, print eligibility, read-only state, and text-annotation implicit no-zoom/no-rotate behavior.
  - Completion: common-field tests cover required-field failures, defaults, reserved or malformed flags, screen and print helper outcomes, opacity fallback rules, associated files, language, and unknown subtype preservation.
  - _Requirements: 0.2, 0.3, 0.6, 0.9_

- [x] 4. Build annotation descriptor parsers
- [x] 4.1 (P) Parse border arrays, border style dictionaries, and border effects
  - Apply default border behavior when neither legacy nor style dictionary data is present.
  - Parse border width, dash patterns, style names, unknown style fallback, cloudy effects, and intensity bounds.
  - Completion: border tests show defaults, valid border/style/effect combinations, ignored legacy border behavior when a style dictionary exists, and malformed values raising annotation diagnostics.
  - _Requirements: 0.2, 0.4, 0.11, 0.12, 0.13, 0.14, 0.18_
  - _Boundary: AnnotationBorderParser_

- [x] 4.2 (P) Parse appearance dictionaries and appearance state descriptors
  - Validate normal, rollover, and down appearance entries as streams or state maps.
  - Apply rollover and down fallback to normal appearance when optional entries are absent.
  - Preserve selected appearance state names and raw form XObject or state-map values without rendering.
  - Completion: appearance tests cover stream entries, state subdictionaries, missing optional fallbacks, selected state preservation, and malformed appearance shapes.
  - _Requirements: 0.2, 0.5, 0.23, 0.24_
  - _Boundary: AnnotationAppearanceParser_

- [x] 4.3 (P) Parse annotation geometry and colour operands
  - Parse quadrilaterals, line coordinates, vertices, ink lists, PDF 2.0 path arrays, callout lines, caption offsets, difference rectangles, and fixed-print matrices.
  - Validate operand counts, numeric ranges, rectangle difference constraints, and colour component counts.
  - Completion: geometry tests cover valid operands and malformed counts or bounds for every geometry shape consumed by subtype parsers.
  - _Requirements: 0.10, 0.11, 0.12, 0.13, 0.14, 0.15, 0.16, 0.18, 0.27, 0.28_
  - _Boundary: AnnotationGeometryParser_

- [x] 4.4 Establish raw hand-off preservation helpers
  - Preserve action, destination, additional action, file specification, sound, movie, widget parent, icon fit, measure, overlay, external data, 3D, RichMedia, optional content, and appearance payloads exactly as raw objects where this feature does not own deep semantics.
  - Store named raw fields in subtype-specific records as well as retaining the original annotation dictionary for audit and future reparsing.
  - Completion: raw hand-off tests compare preserved objects object-for-object and show no filesystem, network, media, action, or rendering behavior is invoked.
  - _Requirements: 0.5, 0.10, 0.20, 0.21, 0.22, 0.23, 0.24, 0.28, 0.29_

- [x] 4.5 Parse markup metadata, replies, groups, states, and external data
  - Parse markup title, popup reference, rich content, creation date, reply target, reply type, subject, intent, external data, and grouping metadata.
  - Validate reply-type prerequisites, same-page reply references where identity is available, and cycle limits for reply or popup relationships.
  - Parse state and state-model records for text annotation replies with documented defaults.
  - Completion: markup tests cover normal markup data, grouped annotations, state transitions, external data preservation, prerequisite failures, and cycle detection.
  - _Requirements: 0.7, 0.8, 0.9, 0.19, 0.29_

- [ ] 5. Parse standard annotation subtype families
- [ ] 5.1 Parse text and stamp annotation metadata
  - Parse text annotation open state, icon name defaults, and implicit no-zoom/no-rotate behavior as structural data.
  - Parse rubber stamp icon names and PDF 2.0 stamp intents, including the invalid combination where a non-stamp intent also supplies an icon name.
  - Completion: subtype tests cover text defaults, state-bearing text replies, stamp defaults, custom names, and invalid stamp intent/name combinations.
  - _Requirements: 0.8, 0.9, 0.17_

- [ ] 5.2 Parse link annotations without executing navigation or actions
  - Preserve action, previous URI action, and destination values according to the raw hand-off boundary.
  - Parse highlight mode defaults, link activation quadrilaterals, and link border style data.
  - Completion: link tests cover action-only, destination-only, highlight defaults, quadrilateral validation, and non-execution of action payloads.
  - _Requirements: 0.10_

- [ ] 5.3 Parse free text and line annotations
  - Parse default appearance strings, justification, rich text, default style, free-text callouts, intents, border effects, difference rectangles, border styles, and callout line endings.
  - Parse line endpoints, line ending styles, interior colour, leader lines, caption settings, measure raw data, and caption offsets.
  - Completion: tests cover required free-text and line fields, defaults, malformed callouts or leader data, caption options, and raw measure preservation.
  - _Requirements: 0.11, 0.12_

- [ ] 5.4 Parse square, circle, polygon, and polyline annotations
  - Parse shape border styles, interior colours, border effects, and difference rectangles.
  - Parse polygon and polyline vertices, line endings, intents, measure raw data, and PDF 2.0 paths with the documented vertices/path exclusivity rule.
  - Completion: tests cover square, circle, polygon, and polyline defaults, required geometry, path precedence, malformed geometry, and raw measure preservation.
  - _Requirements: 0.13, 0.14_

- [ ] 5.5 Parse text markup, caret, and ink annotations
  - Parse required text-markup quadrilaterals for highlight, underline, squiggly, and strikeout variants.
  - Parse caret difference rectangles and symbol defaults.
  - Parse ink lists, ink border styles, and PDF 2.0 ink paths.
  - Completion: tests cover all text-markup variants, caret defaults and bounds, ink required paths, PDF 2.0 path alternatives, and malformed operand counts.
  - _Requirements: 0.15, 0.16, 0.18_

- [ ] 5.6 Parse popup, file attachment, and sound annotations
  - Parse popup parent references and open-state defaults without creating UI behavior.
  - Preserve file specifications and sound streams as raw hand-off values.
  - Parse icon defaults for file attachment and sound metadata where owned by annotation dictionaries.
  - Completion: tests cover required raw payloads, default icon behavior, popup parent validation, and non-execution of file or sound payloads.
  - _Requirements: 0.19, 0.20, 0.21_

- [ ] 5.7 Parse movie and screen annotations
  - Preserve movie dictionaries, movie activation data, screen actions, additional actions, and screen appearance characteristics as raw hand-off values.
  - Parse movie titles, screen titles, and screen page-reference requirements for rendition-action contexts without playing media or executing actions.
  - Completion: tests cover required movie payloads, default activation behavior, screen page-reference validation, appearance hand-off, and non-execution of media or actions.
  - _Requirements: 0.22, 0.23_

- [ ] 5.8 Parse widget annotation-owned metadata and appearance characteristics
  - Parse widget highlighting mode, action raw values, additional-actions raw values, border style, parent field reference, and widget-owned appearance characteristics.
  - Parse widget rotation, border/background colours, captions, icon references, icon-fit raw data, and text/icon placement defaults.
  - Completion: widget tests cover highlight defaults, appearance-characteristic fields, parent validation, icon raw preservation, and no form-field semantic merging beyond annotation-owned entries.
  - _Requirements: 0.24_

- [ ] 5.9 Parse printer mark and trap network annotation records
  - Parse printer mark as a structural subtype with raw production-mark context preserved.
  - Parse trap network as a deprecated structural subtype while leaving page-placement enforcement to integration.
  - Completion: subtype tests cover printer mark records, trap network records, deprecated subtype preservation, and no trapping execution.
  - _Requirements: 0.25, 0.26_

- [ ] 5.10 Parse watermark fixed-print descriptors
  - Parse fixed-print type, matrix, horizontal translation, and vertical translation defaults.
  - Preserve watermark appearance data as raw appearance descriptors without applying print-time transforms.
  - Completion: watermark tests cover absent fixed-print data, valid fixed-print dictionaries, defaults, malformed matrix or translation values, and non-rendering behavior.
  - _Requirements: 0.27_

- [ ] 5.11 Parse redaction and projection annotation descriptors
  - Parse redaction quadrilaterals, interior colour, overlay raw stream, overlay text, repeat flag, appearance string, and justification without applying redactions.
  - Parse projection markup context, external data, and zero-area appearance restrictions.
  - Completion: tests cover redaction precedence rules, required overlay appearance string when needed, projection external data, zero-area appearance rejection, and non-destructive behavior.
  - _Requirements: 0.28, 0.29_

- [ ] 5.12 Preserve 3D, RichMedia, and unknown subtype records
  - Recognize 3D and RichMedia subtype names as adjacent-clause raw hand-off records.
  - Preserve unknown subtype names and dictionaries when common annotation fields are valid.
  - Completion: tests cover 3D raw, RichMedia raw, and unknown subtype records with exact raw dictionary preservation.
  - _Requirements: 0.6_

- [ ] 6. Integrate subtype dispatch and public behavior
- [ ] 6.1 Connect source resolution, common parsing, markup parsing, and subtype-family parsing into page-level typed annotations
  - Dispatch all standard subtype names to the correct structural record and keep unknown names as typed unknown records.
  - Attach markup metadata only to subtypes classified as markup annotations while preserving common fields for all subtypes.
  - Return typed page annotations lazily from resolved page annotation sources.
  - Completion: end-to-end page annotation tests parse mixed page annotation arrays into common, markup, and subtype records with stable page index, array order, and object identity.
  - _Depends: 2.1, 3.1, 4.1, 4.2, 4.3, 4.4, 4.5, 5.1, 5.2, 5.3, 5.4, 5.5, 5.6, 5.7, 5.8, 5.9, 5.10, 5.11, 5.12_
  - _Requirements: 0.1, 0.2, 0.6, 0.7, 0.8, 0.9, 0.10, 0.11, 0.12, 0.13, 0.14, 0.15, 0.16, 0.17, 0.18, 0.19, 0.20, 0.21, 0.22, 0.23, 0.24, 0.25, 0.26, 0.27, 0.28, 0.29_

- [ ] 6.2 Connect document-level typed annotation enumeration and page-level trap network validation
  - Return typed document annotations by traversing validated document annotation sources and invoking page-level typed parsing.
  - Preserve document page order and page-local annotation order in the flattened result.
  - Enforce trap network annotations as no more than one per page and only as the final page annotation entry.
  - Completion: document-level integration tests cover valid multi-page annotation results, duplicate indirect-reference rejection, deterministic order, and trap network last-entry violations.
  - _Depends: 2.2, 5.9, 6.1_
  - _Requirements: 0.1, 0.2, 0.26_

- [ ] 6.3 Verify boundary protections for rendering, actions, media, forms, redaction, 3D, and RichMedia
  - Assert that appearance streams, optional content, actions, media, file attachments, widget field data, redaction overlays, 3D data, and RichMedia data remain structural or raw values only.
  - Confirm annotation parsing does not mutate document state, invoke content rendering, perform hit testing, apply redactions, open files, play media, execute actions, or enforce UI behavior.
  - Completion: security and boundary tests exercise representative raw payloads and prove only object parsing and validation occur.
  - _Requirements: 0.1, 0.5, 0.10, 0.20, 0.21, 0.22, 0.23, 0.24, 0.27, 0.28, 0.29_

- [ ] 6.4 Review the exported reader API and preserve existing compatibility
  - Regenerate and inspect the public reader interface so only intended annotation and tab-order additions appear.
  - Confirm the raw page annotation accessor still returns the original page entry while the typed accessors perform structural parsing lazily.
  - Completion: interface review and compatibility tests show existing reader, navigation, graphics, xobject, optional-content, and page-structure behavior remains unchanged.
  - _Requirements: 0.1, 0.2_

- [ ] 7. Run final validation and formatting
  - Run the full checker, targeted reader tests, full test suite, formatter, and public interface generation.
  - Confirm generated interface changes match the annotation API plan and no lower-layer package dependency direction changed.
  - Completion: validation commands pass, formatting is clean, and the final diff contains only annotation feature work plus intended generated interface updates.
  - _Requirements: 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 0.10, 0.11, 0.12, 0.13, 0.14, 0.15, 0.16, 0.17, 0.18, 0.19, 0.20, 0.21, 0.22, 0.23, 0.24, 0.25, 0.26, 0.27, 0.28, 0.29_
