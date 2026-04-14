# Implementation Plan

- [ ] 1. Establish file-specification foundations
- [ ] 1.1 Add file-specification diagnostics and resolved-object provenance
  - Distinguish invalid file-specification structures from lower reader, action, annotation, navigation, and collection errors.
  - Resolve direct and indirect file-specification operands with owner context, source object identity when known, direct-versus-indirect provenance, and cycle rejection.
  - Keep context messages concise and stable so malformed structures produce deterministic diagnostics.
  - Done when raw string, dictionary, stream, reference, and invalid-object inputs can be classified or rejected through a shared reader-layer path without triggering external effects.
  - _Requirements: 0.1, 0.4, 0.5, 0.6_

- [ ] 1.2 Define public structural models and raw payload retention
  - Represent simple and full file specifications, path components, embedded file descriptors, related file entries, collection item data, file identifiers, and associated-file relationship names as inspectable reader values.
  - Preserve exact raw strings, dictionaries, streams, names, object identities, unknown keys, extension file-system names, encrypted-payload dictionaries, thumbnails, and deprecated platform entries.
  - Model reader-selected file names so `UF` can override `F` without losing either raw value.
  - Done when the reader public interface can expose clause 7.11 metadata structurally while all file contents and adjacent-domain payloads remain raw.
  - _Requirements: 0.1, 0.4, 0.5, 0.6, 0.8_

- [ ] 1.3 Create reusable file-specification fixture coverage
  - Provide synthetic PDF object fixtures for simple strings, full dictionaries, indirect embedded streams, related-file arrays, URL file-system dictionaries, collection items, thumbnails, and malformed cases.
  - Reuse existing reader object loading and name-tree behavior so tests exercise real direct and indirect resolution.
  - Done when later parser tests can build valid and invalid file-specification scenarios without duplicating low-level PDF setup.
  - _Requirements: 0.1, 0.4, 0.5, 0.6, 0.7, 0.8_

- [ ] 2. Implement isolated clause 7.11 parsers
- [ ] 2.1 Parse simple file-specification paths and pure resolution helpers
  - Split byte strings into ordered components on unescaped solidus characters while preserving empty components and raw byte values.
  - Remove file-specification reverse-solidus markers only for escaped literal solidus values inside components.
  - Classify absolute and relative paths, normalize `..` components only through explicit helper behavior, and leave host filesystem resolution outside the parser.
  - Provide URL path conversion and resolution behavior that accepts only relative path input, percent-escapes unsafe or non-ASCII bytes, and rejects scheme, authority, query, fragment, and parameter constructs.
  - Done when byte path parsing and pure resolution helpers return deterministic values for valid inputs and file-specification diagnostics for ambiguous or disallowed inputs.
  - _Requirements: 0.2, 0.3, 0.7_
  - _Boundary: FileSpecStringParser_

- [ ] 2.2 (P) Describe embedded-file streams and parameter dictionaries
  - Resolve embedded-file mapping values to stream descriptors through the existing reader loading policy.
  - Validate optional embedded stream type, preserve subtype names, and parse parameter metadata for size, dates, Mac data, and checksum bytes.
  - Require a 16-byte checksum only when the checksum entry is present, and never compute or trust checksum content.
  - Preserve raw stream dictionaries and stream data without decoding, decrypting, copying to disk, or interpreting payload bytes.
  - Done when embedded-file stream descriptors expose metadata and raw payload identity while malformed stream or parameter shapes raise file-specification diagnostics.
  - _Requirements: 0.5_
  - _Boundary: EmbeddedFileParser_
  - _Depends: 1.1, 1.2_

- [ ] 3. Convert full file-specification dictionaries
- [ ] 3.1 Parse file-system names and filename entries
  - Accept dictionary-form file specifications and reject non-dictionary values in the full file-specification path.
  - Validate optional file-system names, preserve extension names, and recognize URL file-system dictionaries without fetching or interpreting remote resources.
  - Validate `F`, `UF`, deprecated platform filename entries, file identifiers, volatility defaults, descriptions, and required filename fallback rules.
  - Apply reader-selected filename precedence so `UF` is used when present and `F` remains available for backward compatibility.
  - Done when valid full dictionaries expose all filename-related metadata and malformed filename, identifier, or required-entry cases fail deterministically.
  - _Requirements: 0.1, 0.4, 0.7_
  - _Boundary: FileSpecDictionaryParser_
  - _Depends: 2.1_

- [ ] 3.2 Integrate embedded-file mappings in full dictionaries
  - Validate `Type /Filespec` and indirect-source requirements whenever embedded-file mappings are present.
  - Parse each embedded-file mapping key through the embedded-file descriptor behavior while preserving extension keys and raw dictionary context.
  - Preserve PDF 2.0 encrypted-payload privacy constraints as structural boundaries without deriving original file names.
  - Done when dictionaries with embedded-file mappings return keyed descriptors and malformed direct, mistyped, or non-stream mappings raise file-specification diagnostics.
  - _Requirements: 0.4, 0.5_
  - _Boundary: FileSpecDictionaryParser, EmbeddedFileParser_
  - _Depends: 2.2, 3.1_

- [ ] 3.3 Integrate related-file mappings and EF key consistency
  - Require related-file mappings to appear only when embedded-file mappings are present.
  - Validate that every related-file key has a matching embedded-file key before parsing related-file arrays.
  - Resolve each related-file dictionary value, whether direct or indirect, to a related-files array through the existing reader loading and cycle policy.
  - Parse related-file arrays as ordered string and embedded-stream pairs with even length and preserved related-name bytes.
  - Done when related-file mappings reuse embedded-file stream descriptors and malformed key, reference, or pair structures fail before misleading data is exposed.
  - _Requirements: 0.4, 0.6_
  - _Boundary: RelatedFilesParser, FileSpecDictionaryParser_
  - _Depends: 3.2_

- [ ] 3.4 Preserve collection, thumbnail, encrypted-payload, and relationship metadata
  - Validate collection item entries as indirect references, resolve them only enough to confirm optional collection-item type, and preserve schema-dependent raw fields.
  - Validate `Type /Filespec` and indirect-source requirements whenever an encrypted-payload entry is present, and preserve the encrypted-payload dictionary without decryption or filename inference.
  - Validate thumbnail entries as stream descriptors and associated-file relationship entries as names, with malformed shapes reported as file-specification diagnostics.
  - Apply the default associated-file relationship and preserve standard, unspecified, encrypted-payload, and extension relationship names.
  - Done when full dictionaries expose collection, thumbnail, encrypted-payload, and associated-file metadata while direct collection items, malformed encrypted-payload entries, non-stream thumbnails, and non-name relationships fail deterministically.
  - _Requirements: 0.4, 0.8_
  - _Boundary: FileSpecDictionaryParser, FileSpecModel_
  - _Depends: 3.1_

- [ ] 4. Wire public reader access and raw-boundary integration
- [ ] 4.1 Parse raw file-specification operands on demand
  - Dispatch raw string values to simple file specifications and raw dictionary values to full file specifications through the same document-owned resolution policy.
  - Resolve indirect references with cycle detection while preserving source provenance for diagnostics and indirect-only validation.
  - Return file-specification diagnostics for invalid raw object shapes instead of adjacent-domain errors.
  - Done when document- and file-owned callers can parse representative raw operands into the same typed structural results.
  - _Requirements: 0.1, 0.4, 0.5, 0.6, 0.7, 0.8_
  - _Boundary: FileSpecAccessors_
  - _Depends: 3.3, 3.4_

- [ ] 4.2 Enumerate document-level embedded files from the name tree
  - Read the document `EmbeddedFiles` name-tree category through existing name-tree enumeration.
  - Return an empty result when the category is absent and preserve name-tree key bytes when entries are present.
  - Parse each present value as a typed file specification while keeping the raw name-tree value available.
  - Done when document-level embedded-file enumeration returns typed entries in name-tree order and malformed present values surface file-specification or name-tree diagnostics at the correct boundary.
  - _Requirements: 0.5_
  - _Boundary: FileSpecAccessors_
  - _Depends: 4.1_

- [ ] 4.3 Preserve adjacent raw hand-off behavior while exposing typed parsing
  - Keep existing action, annotation, collection, multimedia, form, and structure file-related fields raw unless a caller explicitly requests typed file-specification parsing.
  - Provide boundary-local adapter behavior only where it delegates to the on-demand parser without changing enumeration timing or failure behavior.
  - Ensure no parser path opens files, fetches URLs, launches processes, decodes encrypted payloads, extracts embedded data, writes files, or mutates PDF objects.
  - Done when existing adjacent reader tests continue to pass and representative raw file-specification operands can be parsed opt-in through the new reader path.
  - _Requirements: 0.1, 0.4, 0.5_
  - _Boundary: RawBoundaryPolicy, FileSpecAccessors_
  - _Depends: 4.1_

- [ ] 5. Validate file-specification behavior and public integration
- [ ] 5.1 Validate path and URL behavior with focused tests
  - Cover escaped literal solidus handling, empty component preservation, absolute and relative classification, relative path resolution, and `..` normalization.
  - Cover URL relative-path conversion, percent escaping, and rejection of scheme, authority, query, fragment, or parameter constructs.
  - Done when the path parser tests fail on byte-handling regressions and prove helper behavior remains pure and effect-free.
  - _Requirements: 0.2, 0.3, 0.7_
  - _Boundary: FileSpecStringParser tests_
  - _Depends: 2.1_

- [ ] 5.2 (P) Validate dictionary filename, URL, collection, encrypted-payload, thumbnail, and relationship behavior
  - Cover required type rules, required filename fallback, `UF` precedence, URL file-system byte preservation, deprecated platform entry validation, file identifiers, volatility defaults, and associated-file relationship defaults.
  - Cover indirect collection item validation, direct or malformed collection item failures, encrypted-payload dictionary preservation, encrypted-payload `Type /Filespec` and indirect-source requirements, thumbnail stream validation, unknown file-system names, and second-class relationship names.
  - Cover malformed encrypted-payload entries, non-stream thumbnails, and non-name associated-file relationships as deterministic file-specification diagnostics.
  - Done when malformed dictionary structures raise file-specification diagnostics and valid dictionaries preserve all raw payloads promised by the design.
  - _Requirements: 0.1, 0.4, 0.7, 0.8_
  - _Boundary: FileSpecDictionaryParser tests_
  - _Depends: 3.4_

- [ ] 5.3 (P) Validate embedded-file and related-file behavior
  - Cover embedded-file stream resolution, indirect file-specification requirements for embedded mappings, optional stream type validation, subtype retention, parameter parsing, and 16-byte checksum validation.
  - Cover related-file requirements for embedded mappings, matching related keys, direct and indirect related-file array values, even string-and-stream pairs, malformed reference or pair rejection, and descriptor reuse for related streams.
  - Done when embedded-file and related-file tests prove payload data is retained raw and no decoding, decryption, extraction, or checksum computation occurs.
  - _Requirements: 0.5, 0.6_
  - _Boundary: EmbeddedFileParser tests, RelatedFilesParser tests_
  - _Depends: 3.3_

- [ ] 5.4 Validate accessor integration, name-tree enumeration, and raw-boundary compatibility
  - Cover string and dictionary dispatch through public raw-operand parsing, including invalid raw object diagnostics.
  - Cover absent and present document-level embedded-file name trees, sorted byte-key order, typed entry values, raw value retention, and malformed entry diagnostics.
  - Cover representative file-specification operands from actions, annotations, associated files, launch targets, and collection files through opt-in parsing while existing raw fields remain unchanged.
  - Cover lazy failure behavior so malformed file specifications do not break unrelated action, annotation, collection, page, or document enumeration.
  - Done when accessor integration tests and existing adjacent reader tests pass together without introducing external side effects.
  - _Requirements: 0.1, 0.4, 0.5_
  - _Boundary: FileSpecAccessors tests, RawBoundaryPolicy tests_
  - _Depends: 4.2, 4.3, 5.2, 5.3_

- [ ] 5.5 Run final MoonBit validation and public API review
  - Run formatting, type checking, targeted reader tests, full tests, and public interface generation for the project.
  - Inspect the public interface summary so only intended reader-layer file-specification APIs are added and lower package APIs remain unchanged.
  - Confirm no non-standard dependency, filesystem access, network access, process launch, payload extraction, decryption, checksum trust, or PDF mutation behavior was introduced.
  - Done when the validation commands complete successfully and the feature is ready for implementation review.
  - _Requirements: 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8_
