# Implementation Plan

- [ ] 1. Establish package foundations and object contracts
- [x] 1.1 Create the package boundaries and validation baseline
  - Establish separate object, lexer, and parser package boundaries using only MoonBit standard-library dependencies.
  - Preserve the existing root library and CLI scaffold while making the new packages discoverable by the MoonBit toolchain.
  - The package graph is complete when `moon check` succeeds with the intended object -> lexer -> parser dependency direction and no external dependency additions.
  - _Requirements: 16.1, 16.5_

- [ ] 1.2 Define type-safe PDF values, names, streams, and identifiers
  - Represent every required PDF value, indirect reference, object identifier, indirect object wrapper, dictionary, stream dictionary, and encoded byte payload as strongly typed public values.
  - Preserve byte-sequence equality for names while keeping text conversion explicit and non-authoritative for lookup.
  - The model is complete when black-box tests can construct, compare, and pattern-match booleans, integers, reals, strings, names, arrays, dictionaries, streams, nulls, and references.
  - _Requirements: 9.6, 12.5, 13.2, 14.3, 16.1, 16.2, 16.3, 16.4_

- [ ] 1.3 Add typed diagnostics and object expectation helpers
  - Report parse failures with narrow error categories and byte offsets for lexical, numeric, dictionary, stream, indirect-object, and unexpected-token conditions.
  - Provide object expectation helpers that distinguish integer-only contexts from number contexts and leave indirect references unresolved.
  - The helpers are complete when tests assert integer-vs-real behavior, absent dictionary lookup as null, and representative error kind plus offset values.
  - _Requirements: 5.3, 6.3, 6.4, 11.2, 11.4, 12.3, 12.5, 16.5_

- [ ] 2. Build lexical byte handling
- [ ] 2.1 Implement byte cursor movement, offsets, EOL normalization, and raw byte reads
  - Track byte offsets for every read, peek, and end-of-input condition.
  - Normalize CR, LF, and CRLF as one EOL marker outside raw stream data while preserving exact raw reads for stream payloads.
  - The cursor is complete when unit tests show correct offsets for normal tokens, line continuations, unescaped string EOLs, stream EOL validation, and fixed-length raw reads.
  - _Requirements: 2.1, 7.5, 7.6, 12.2, 12.3, 12.4_

- [ ] 2.2 (P) Implement byte classification outside special lexical regions
  - Classify exactly the PDF white-space bytes, delimiter bytes, and all remaining bytes including high-bit bytes.
  - Keep classification out of literal strings, streams, and comments by limiting it to ordinary lexical scanning and name boundaries.
  - The classifier is complete when exhaustive byte tests prove every byte maps to exactly one class and the required delimiter and white-space sets match ISO 32000-2.
  - _Requirements: 1.1, 1.2, 1.3, 1.4_
  - _Boundary: CharClassifier_

- [ ] 2.3 Implement ordinary token scanning, separator collapse, comments, and structural markers
  - Collapse consecutive white-space and ordinary comments into token separators without exposing ordinary comments as object tokens.
  - Terminate regular tokens at delimiters while preserving delimiter tokens, dictionary delimiters, header markers, EOF markers, and token offsets.
  - The lexer is complete when tests cover separator collapse, delimiter token boundaries, ordinary comment skipping, `%PDF-n.m`, and `%%EOF` marker emission.
  - _Depends: 2.1, 2.2_
  - _Requirements: 2.2, 2.3, 3.1, 3.2, 3.3_
  - _Boundary: Lexer_

- [ ] 2.4 (P) Implement literal and hexadecimal string decoding
  - Decode balanced literal strings with named escapes, octal escapes, line continuations, unescaped EOL normalization, unknown escape handling, and empty strings.
  - Decode hexadecimal strings with ignored internal white-space, uppercase and lowercase digits, odd-digit padding, and empty strings.
  - The string readers are complete when tests cover every literal-string and hex-string example and verify delimiter bytes are excluded from decoded output.
  - _Depends: 2.1_
  - _Requirements: 1.4, 7.1, 7.2, 7.3, 7.4, 7.5, 7.6, 7.7, 7.8, 8.1, 8.2, 8.3, 8.4, 8.5_
  - _Boundary: StringReader_

- [ ] 2.5 (P) Implement slash-prefixed name decoding
  - Read name bodies until white-space, delimiter, or end of input and expand valid two-digit hexadecimal escapes.
  - Allow the empty name, reject decoded NUL bytes, and keep equality based on exact decoded bytes rather than UTF-8 text.
  - The name reader is complete when tests pass for all required examples, empty names, invalid NUL escapes, high-bit bytes, and byte-equality comparisons.
  - _Depends: 1.2, 2.1, 2.2_
  - _Requirements: 1.4, 9.1, 9.2, 9.3, 9.4, 9.5, 9.6_
  - _Boundary: NameReader_

- [ ] 3. Parse scalar and direct object forms
- [ ] 3.1 Parse booleans, nulls, integers, and real numbers
  - Recognize `true`, `false`, and `null` case-sensitively while rejecting lookalike keywords as those object types.
  - Parse signed decimal integers and PERIOD-containing real numbers, including leading and trailing PERIOD forms, while rejecting radix and exponent notation.
  - Scalar parsing is complete when parser tests produce exact values for all required numeric examples and typed errors for invalid numeric syntaxes.
  - _Depends: 1.3, 2.3_
  - _Requirements: 4.1, 4.2, 4.3, 5.1, 5.2, 5.3, 6.1, 6.2, 13.1_
  - _Boundary: ObjectParser_

- [ ] 3.2 Parse string and name objects through the object parser
  - Dispatch literal strings, hexadecimal strings, and slash-prefixed names from object parsing without re-tokenizing their payload regions.
  - Convert decoded bytes into the shared object model so arrays, dictionaries, and later indirect objects can reuse the same value representation.
  - The integration is complete when public parser tests parse representative literal strings, hex strings, and names into exact byte values.
  - _Depends: 2.4, 2.5, 3.1_
  - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5, 7.6, 7.7, 7.8, 8.1, 8.2, 8.3, 8.4, 8.5, 9.1, 9.2, 9.3, 9.4, 9.5, 9.6_
  - _Boundary: ObjectParser_

- [ ] 3.3 Implement bounded lookahead for indirect references and integer fallback
  - Use at most two tokens of lookahead to recognize integer pairs followed by `R` as references.
  - Preserve the second integer for re-parsing when two integers are not followed by `R` or `obj`.
  - Lookahead is complete when tests distinguish `1 2 R`, `1 2 true`, and standalone integer streams without consuming the wrong token.
  - _Depends: 1.2, 3.1_
  - _Requirements: 14.2, 15.1, 15.3, 15.4, 16.2_
  - _Boundary: ObjectParser_

- [ ] 4. Parse aggregate direct objects
- [ ] 4.1 Parse recursive arrays
  - Read bracket-delimited arrays containing heterogeneous direct objects and nested arrays.
  - Preserve empty arrays and element ordering exactly.
  - Array parsing is complete when tests parse `[]`, nested arrays, and `[549 3.14 false (Ralph) /SomeName]` with the expected element count and values.
  - _Depends: 3.2, 3.3_
  - _Requirements: 10.1, 10.2, 10.3, 10.4_
  - _Boundary: ObjectParser_

- [ ] 4.2 Parse dictionaries with key validation and normalized entries
  - Distinguish dictionary delimiters from hexadecimal string delimiters and read name-keyed value pairs until the closing delimiter.
  - Reject non-name keys and duplicate keys, including duplicates where one syntactic value is null, while omitting null-valued entries from the final dictionary.
  - Dictionary parsing is complete when tests cover `<<>>`, nested dictionaries, null omission, duplicate-key errors, non-name key errors, and hex-string disambiguation.
  - _Depends: 3.2, 3.3_
  - _Requirements: 11.1, 11.2, 11.3, 11.4, 11.5, 11.6, 13.1, 16.3_
  - _Boundary: DictionaryBuilder_

- [ ] 4.3 Integrate recursive direct-object parsing across arrays and dictionaries
  - Ensure arrays and dictionary values can contain any direct object type already implemented, including nested arrays, nested dictionaries, strings, names, numbers, booleans, nulls, and references.
  - Keep parse cursor position correct after each nested object so following tokens remain available to the caller.
  - Recursive parsing is complete when combined fixtures parse nested aggregate values and leave no unconsumed object bytes except expected trailing separators.
  - _Depends: 4.1, 4.2_
  - _Requirements: 10.2, 11.1, 14.2, 15.3, 16.1_
  - _Boundary: ObjectParser, DictionaryBuilder_

- [ ] 5. Parse indirect objects and stream objects
- [ ] 5.1 Parse indirect object definitions with validated object identifiers
  - Recognize positive object number plus non-negative generation number followed by `obj` as an indirect object definition.
  - Read the enclosed object value through `endobj`, recording start and end offsets without implementing reference resolution.
  - Indirect object parsing is complete when tests parse `12 0 obj (Brillig) endobj`, reject invalid object numbers or generations, and preserve object identity by object-number/generation pair.
  - _Depends: 3.3, 4.3_
  - _Requirements: 14.1, 14.3, 14.4, 15.2, 15.4_
  - _Boundary: IndirectObjectParser_

- [ ] 5.2 Parse stream envelopes using dictionary Length and exact raw data
  - Treat a dictionary immediately followed by `stream` as a stream only in indirect-object parsing mode.
  - Require LF or CRLF after `stream`, read exactly the required integer Length bytes, exclude the optional data EOL before `endstream`, and reject malformed envelopes without scanning heuristics.
  - Stream parsing is complete when tests cover exact-length data, zero-length data, CR-alone rejection, missing or non-integer Length, missing `endstream`, optional pre-`endstream` EOL, and recognized `Filter`, `DecodeParms`, and `DL` entries.
  - _Depends: 1.3, 2.1, 4.2, 5.1_
  - _Requirements: 6.4, 12.1, 12.2, 12.3, 12.4, 12.5_
  - _Boundary: StreamReader_

- [ ] 5.3 Enforce direct-object stream boundaries and indirect-object termination
  - Leave a dictionary followed by `stream` as a plain dictionary in direct-object contexts and keep the `stream` token available for the caller to reject or handle.
  - Validate that indirect stream objects consume the stream envelope and terminate cleanly at `endobj` without extra non-white-space bytes owned by the object.
  - Boundary enforcement is complete when tests show direct array and dictionary values do not consume streams, while indirect stream objects parse successfully with correct payload bytes.
  - _Depends: 5.1, 5.2_
  - _Requirements: 12.1, 12.4, 14.1, 16.5_
  - _Boundary: ObjectParser, StreamReader, IndirectObjectParser_

- [ ] 6. Validate public behavior, examples, and toolchain readiness
- [ ] 6.1 Expose and verify the intended public parser surface
  - Provide public entry points for parsing a single object, all object fragments, indirect references, and indirect object definitions according to the design contracts.
  - Keep future reader responsibilities out of scope: indirect references remain unresolved and nonexistent-reference lookup is not implemented here.
  - Public API integration is complete when `moon info` shows only intended object, error, lexer, and parser interfaces and downstream code can construct or consume `Null`, `Ref`, dictionaries, and streams.
  - _Depends: 5.3_
  - _Requirements: 13.2, 14.2, 16.1, 16.2, 16.3, 16.4, 16.5_

- [ ] 6.2 Validate ISO-derived object fragments and cross-feature parser examples
  - Add object-fragment fixtures from the extracted ISO 7.2 and 7.3 examples without implementing full file traversal or cross-reference lookup.
  - Cover booleans, numbers, strings, names, arrays, dictionaries, streams, nulls, references, and indirect object definitions through public parser tests.
  - Example validation is complete when `moon test` passes for representative fragments and confirms exact parsed values and offsets where errors are expected.
  - _Depends: 6.1_
  - _Requirements: 3.3, 4.1, 4.2, 5.2, 6.2, 7.8, 8.5, 9.5, 10.4, 11.5, 12.3, 13.1, 14.4, 15.1, 15.2, 15.3, 15.4_

- [ ] 6.3 Complete robustness, formatting, and full validation checks
  - Exercise malformed inputs for EOF, numeric overflow, invalid names, duplicate dictionary keys, invalid stream lengths, bounds-checked cursor movement, and invalid indirect-object headers.
  - Verify large strings and stream payloads advance offsets correctly without decoding stream data or adding filter support.
  - Final validation is complete when `moon fmt`, `moon check`, `moon test`, and `moon info` all pass and generated interface changes match the intended public contracts.
  - _Depends: 6.2_
  - _Requirements: 1.4, 2.1, 5.3, 6.4, 9.4, 11.4, 12.2, 12.3, 14.1, 16.5_
