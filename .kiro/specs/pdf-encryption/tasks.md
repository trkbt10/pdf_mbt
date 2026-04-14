# Implementation Plan

- [ ] 1. Establish encryption and crypto foundations
- [ ] 1.1 Define the package boundaries and typed diagnostics
  - Create the standard-library-only crypto and encryption boundaries without adding external packages, native bindings, CMS runtimes, or platform key stores.
  - Add separate crypto, encryption, and reader-facing diagnostic categories for invalid primitives, malformed encryption dictionaries, credential failures, unsupported handlers, unsupported algorithms, and authorization failures.
  - Preserve the existing parser, object, filter, and reader ownership boundaries while allowing reader errors to wrap encryption failures.
  - Done: the new boundaries build independently and tests can assert stable error categories without parsing formatted messages.
  - _Requirements: 0.1, 0.2, 0.3, 0.6, 0.24, 0.26, 0.27_
  - _Boundary: CryptoPrimitives, EncryptionDictionaryParser, ReaderEncryptionIntegration_

- [ ] 1.2 Add byte-order, block, and padding helpers
  - Provide little-endian and big-endian integer byte conversion, XOR, fixed-length validation, zero IV construction, and block-size checks for encryption algorithms.
  - Implement PKCS 7 padding addition and removal, including the full-block padding case and malformed-padding rejection.
  - Keep helpers byte-oriented and independent of PDF dictionaries or credentials.
  - Done: white-box tests prove padding, endian conversion, XOR, and block validation behavior for valid and invalid inputs.
  - _Requirements: 0.3, 0.4, 0.5, 0.9, 0.10, 0.20, 0.23_
  - _Boundary: CryptoPrimitives_

- [ ] 1.3 Add the MD5 digest primitive for deprecated standard security
  - Implement MD5 for deprecated revision 4 and earlier key derivation.
  - Support repeated digest use in password algorithms without retaining document-level state.
  - Validate the digest against independent known-answer vectors before revision 4 authentication depends on it.
  - Done: MD5 vector tests pass and malformed or oversized internal state cannot leak as a non-typed failure.
  - _Requirements: 0.3, 0.9_
  - _Boundary: CryptoPrimitives_

- [ ] 1.4 Add SHA-2 digest primitives for revision 6 hashing
  - Implement SHA-256, SHA-384, and SHA-512 for revision 6 Algorithm 2.B.
  - Keep hash selection explicit so Algorithm 2.B can choose the next digest family from encrypted round output.
  - Validate each digest against independent known-answer vectors before revision 6 authentication depends on it.
  - Done: SHA-2 vector tests pass for all three digest sizes and return exact byte lengths for downstream algorithms.
  - _Requirements: 0.3, 0.10, 0.11, 0.26_
  - _Boundary: CryptoPrimitives_

- [ ] 1.5 Add the RC4 transform for deprecated V2 paths
  - Implement the symmetric RC4 byte transform used by revision 4 and earlier password and object algorithms.
  - Preserve input length exactly and support repeated invocations with iteration-specific keys.
  - Reject invalid empty keys with typed crypto diagnostics.
  - Done: RC4 known-answer tests and revision-style repeated-key tests pass before standard-handler code calls the transform.
  - _Requirements: 0.3, 0.4, 0.9, 0.13, 0.14, 0.15, 0.27_
  - _Boundary: CryptoPrimitives_

- [ ] 1.6 Add AES block operations for PDF key sizes
  - Implement AES block encryption and decryption for 128-bit and 256-bit keys.
  - Validate key schedule behavior, block length, and unsupported key-size rejection at the primitive boundary.
  - Keep the block operation independent from CBC, ECB, padding, and PDF dictionary logic.
  - Done: AES block known-answer tests pass for the key sizes used by AESV2, AESV3, Algorithm 2.B, OE, UE, and Perms.
  - _Requirements: 0.3, 0.5, 0.10, 0.11, 0.20, 0.26, 0.27_
  - _Boundary: CryptoPrimitives_

- [ ] 1.7 Add AES modes used by encrypted strings, streams, and permissions
  - Provide AES-CBC with PKCS 7 padding for encrypted strings and streams.
  - Provide AES-CBC without padding for OE and UE and AES-ECB single-block decryption for Perms.
  - Reject invalid IV lengths, non-block-aligned no-padding data, and malformed padding with typed crypto errors.
  - Done: CBC, ECB, and padding-mode vectors pass before the encryption layer calls these modes.
  - _Depends: 1.2, 1.6_
  - _Requirements: 0.3, 0.4, 0.5, 0.10, 0.20, 0.27_
  - _Boundary: CryptoPrimitives_

- [ ] 2. Parse encryption dictionaries and metadata
- [ ] 2.1 Parse common encryption dictionary entries and crypt-filter references
  - Parse the common handler name, optional subfilter, cipher version, key length, crypt filter map, stream default, string default, and embedded-file default.
  - Validate V values, Length constraints, standard crypt-filter names, and CF references before authentication begins.
  - Preserve trailer absence as reader state while requiring a resolved dictionary for this parser.
  - Done: valid common dictionaries produce typed configuration, and each missing, wrong-typed, unknown, or inconsistent common entry raises a field-specific encryption error.
  - _Requirements: 0.2, 0.7, 0.27_
  - _Boundary: EncryptionDictionaryParser, CryptFilterRegistry_

- [ ] 2.2 Parse standard security handler fields and permissions
  - Parse revision, O, U, OE, UE, P, Perms, and EncryptMetadata entries with revision-specific length and required-field validation.
  - Interpret standard permission bits while retaining the raw permission value for audit and compatibility.
  - Reject unsupported revision 5, malformed permission flags, invalid direct-object shapes, and incompatible V/R combinations before password authentication.
  - Done: standard dictionaries for revisions 2, 3, 4, and 6 produce typed handler input, and malformed dictionaries fail deterministically.
  - _Requirements: 0.6, 0.7, 0.12, 0.20, 0.23_
  - _Boundary: EncryptionDictionaryParser, StandardSecurityHandler, Permissions_

- [ ] 2.3 Parse public-key handler metadata and unsupported diagnostics
  - Parse public-key handler names, permitted subfilter values, recipient arrays, crypt-filter recipient placement, and public-key permission bits.
  - Preserve enough metadata to explain why CMS, X.509, private-key matching, or custom handler decryption is unsupported in this phase.
  - Avoid attempting CMS decoding or private-key discovery while still validating dictionary shapes relevant to diagnostics.
  - Done: public-key dictionaries produce typed metadata or precise unsupported-security-handler errors without exposing protected content.
  - _Depends: 2.1_
  - _Requirements: 0.24, 0.25, 0.26, 0.27_
  - _Boundary: PublicKeyDictionaryParser, Permissions_

- [ ] 2.4 (P) Parse encrypted payload metadata for wrapper documents
  - Parse encrypted payload dictionaries, including optional type validation, required subtype, and optional version bytes.
  - Keep collection, associated-file, embedded-file name tree, and payload opening behavior outside the parser boundary.
  - Return metadata that reader integration can attach to wrapper diagnostics without auto-opening the embedded encrypted PDF.
  - Done: wrapper payload dictionaries yield typed payload information, and missing or malformed subtype data raises encryption diagnostics.
  - _Depends: 1.1_
  - _Requirements: 0.28_
  - _Boundary: EncryptedPayloadParser_

- [ ] 3. Implement standard password authentication and file-key derivation
- [ ] 3.1 Normalize password bytes for supported revisions
  - Apply revision 4 and earlier password padding, truncation, empty-password substitution, and PDFDocEncoding-compatible byte handling.
  - Apply revision 6 Unicode preprocessing, UTF-8 conversion, and 127-byte truncation, returning an explicit preprocessing error when supported normalization cannot be performed correctly.
  - Keep password preprocessing separate from dictionary parsing and file-key retrieval.
  - Done: tests prove empty, short, exact-length, truncated, PDFDocEncoding, UTF-8, and preprocessing-error password cases produce the expected bytes or errors.
  - _Requirements: 0.6, 0.9, 0.10, 0.12_
  - _Boundary: PasswordPreprocessor_

- [ ] 3.2 Implement revision 4 and earlier file-key derivation
  - Compute the revision 2 through 4 file encryption key with MD5 input ordering, P low-order bytes, file identifier use, metadata exclusion bytes, and 50-round strengthening when required.
  - Validate key-length choices for revisions 2, 3, and 4 before returning any key material.
  - Keep file identifier handling explicit so incremental update edge cases can be tested.
  - Done: known vectors and internal consistency tests prove Algorithm 2 reproduces expected file keys.
  - _Requirements: 0.8, 0.9_
  - _Boundary: StandardR4Handler_

- [ ] 3.3 Implement revision 4 and earlier stored-entry algorithms
  - Compute owner entries with Algorithm 3, including owner-password fallback, RC4 iteration, and XOR key variation.
  - Compute user entries with Algorithm 4 for revision 2 and Algorithm 5 for revisions 3 and 4.
  - Preserve the 32-byte U entry shape and revision-specific comparison bytes for later authentication.
  - Done: known vectors and internal consistency tests prove Algorithms 3, 4, and 5 reproduce expected O and U entries.
  - _Depends: 3.2_
  - _Requirements: 0.13, 0.14, 0.15_
  - _Boundary: StandardR4Handler_

- [ ] 3.4 Authenticate revision 4 and earlier user and owner passwords
  - Authenticate user passwords with Algorithm 6, including the 16-byte comparison rule for revisions 3 and 4.
  - Authenticate owner passwords with Algorithm 7, including revision-specific RC4 decryption order and delegation to user-password validation.
  - Return owner access, user access, or invalid credentials without exposing partial key material.
  - Done: tests distinguish valid user passwords, valid owner passwords, empty user passwords, invalid passwords, and revision-specific comparison behavior.
  - _Depends: 3.2, 3.3_
  - _Requirements: 0.16, 0.17_
  - _Boundary: StandardR4Handler_

- [ ] 3.5 (P) Implement revision 6 iterative hash behavior
  - Implement Algorithm 2.B with SHA-256 initialization, AES-128-CBC no-padding rounds, hash-family selection from encrypted output, and termination after the required dynamic round condition.
  - Keep memory growth bounded to password-sized and key-sized inputs rather than document-sized data.
  - Validate owner-key hashing with the 48-byte U string and user-key hashing without it.
  - Done: tests prove round selection, dynamic termination, owner and user input composition, and final 32-byte output behavior.
  - _Depends: 3.1_
  - _Requirements: 0.10, 0.11, 0.18, 0.19, 0.21, 0.22_
  - _Boundary: StandardR6Handler_

- [ ] 3.6 Implement revision 6 authentication and key retrieval
  - Retrieve the file key through owner and user paths using Algorithms 2.A, 11, and 12 with OE and UE AES-256-CBC no-padding decryption.
  - Compute U, O, UE, and OE values for Algorithms 8 and 9 so deterministic revision 6 fixtures can be generated and verified.
  - Return owner access, user access, or invalid credentials without exposing partial key material.
  - Done: tests distinguish user access, owner access, invalid credentials, malformed O/U/OE/UE lengths, and expected file-key recovery for revision 6.
  - _Depends: 3.5_
  - _Requirements: 0.10, 0.18, 0.19, 0.21, 0.22_
  - _Boundary: StandardR6Handler, Permissions_

- [ ] 3.7 Validate and compute revision 6 permission data
  - Compute Perms values for Algorithm 10 and validate Perms values with Algorithm 13.
  - Validate marker bytes, little-endian permissions, and EncryptMetadata consistency before returning an authorized context.
  - Surface invalid permission state as a typed encryption error rather than a credential error.
  - Done: tests distinguish valid permissions, invalid marker bytes, permission mismatch, and EncryptMetadata mismatch for revision 6.
  - _Depends: 3.6_
  - _Requirements: 0.20, 0.23_
  - _Boundary: StandardR6Handler, Permissions_

- [ ] 3.8 Build the standard handler authentication result
  - Combine revision-specific authentication into a single standard handler workflow that returns file key, access mode, permissions, cipher version, metadata encryption flag, and crypt-filter configuration.
  - Attempt the default empty user password when requested by the reader and return a typed missing-credentials result when it does not authenticate.
  - Enforce standard handler crypt-filter limits for revisions 4 and 6, including supported CFM values and DocOpen authorization expectations.
  - Done: reader-facing authentication tests receive an authorized context for supported standard-security documents and typed failures for invalid credentials or unsupported standard-handler shapes.
  - _Depends: 2.2, 3.2, 3.4, 3.6, 3.7_
  - _Requirements: 0.6, 0.7, 0.8, 0.12, 0.27_
  - _Boundary: StandardSecurityHandler, EncryptionContext_

- [ ] 4. Resolve crypt filters and decrypt encrypted bytes
- [ ] 4.1 Resolve default and stream-specific crypt filters
  - Resolve Identity, StmF, StrF, EFF, and stream-level Crypt decode-parameter names according to the authenticated context.
  - Validate AuthEvent, CFM, Length, and referenced filter names, including unsupported None or custom methods that require external handler ownership.
  - Remove only the consumed Crypt filter entry before ordinary stream filters are applied.
  - Done: crypt-filter tests prove default resolution, Identity passthrough, stream override handling, embedded-file selection, and unsupported-method errors.
  - _Depends: 2.1, 3.8_
  - _Requirements: 0.2, 0.6, 0.27_
  - _Boundary: CryptFilterRegistry_

- [ ] 4.2 Decrypt data with deprecated Algorithm 1 object keys
  - Derive object-specific RC4 and AESV2 keys from file key bytes, object number, generation number, AES salt, and MD5 truncation rules.
  - Decrypt RC4 data without changing length and AESV2 data using CBC with the leading IV and PKCS 7 padding removal.
  - Use the containing indirect object identity for direct strings inside another object.
  - Done: object-key tests prove the specified byte order, key truncation, AES salt addition, IV handling, and decrypted output for strings and streams.
  - _Depends: 4.1_
  - _Requirements: 0.4, 0.9, 0.13, 0.14, 0.15, 0.16, 0.17, 0.27_
  - _Boundary: ObjectDecryptor, CryptoPrimitives_

- [ ] 4.3 Decrypt data with Algorithm 1.A AES-256 rules
  - Decrypt AESV3 strings and streams directly with the 32-byte file key, CBC mode, leading IV, and PKCS 7 padding.
  - Ensure stream decryption occurs after stream encoding filters were written and before ordinary decoding filters are read.
  - Treat the stream dictionary Length as the encrypted byte count owned by the raw stream object.
  - Done: AESV3 tests prove IV extraction, padding removal, unchanged file-key use, and decrypt-before-filter ordering at the byte boundary.
  - _Depends: 4.1_
  - _Requirements: 0.5, 0.10, 0.18, 0.19, 0.20, 0.21, 0.22, 0.23, 0.27_
  - _Boundary: ObjectDecryptor, CryptoPrimitives_

- [ ] 4.4 Transform encrypted PDF objects with exception rules
  - Recursively decrypt eligible strings and stream bytes while leaving integers, booleans, names, references, nulls, and container structure unchanged.
  - Exempt trailer ID values, strings in the encryption dictionary, signature dictionary Contents hexadecimal strings, and strings already inside encrypted streams or object streams.
  - Distinguish external file streams, embedded file streams, metadata streams, object streams, xref streams, and regular streams for crypt-filter purpose selection.
  - Done: object-transform tests prove eligible content is decrypted exactly once and every specified exception remains byte-identical.
  - _Depends: 4.2, 4.3_
  - _Requirements: 0.2, 0.4, 0.5, 0.27_
  - _Boundary: ObjectDecryptor, CryptFilterRegistry_

- [ ] 5. Integrate encryption into reader workflows
- [ ] 5.1 Attach authorized encryption context during document opening
  - Resolve trailer encryption references without decrypting the encryption dictionary or trailer ID values.
  - Preserve unencrypted open behavior, add credential-aware opening, and attempt empty-password authentication for no-credential opens.
  - Return missing credentials, invalid credentials, malformed dictionaries, unsupported public-key handlers, and unsupported custom handlers before protected content is exposed.
  - Done: opening tests show unencrypted files still open normally, empty-password encrypted files open when valid, password-protected files require credentials, and unsupported handlers fail explicitly.
  - _Depends: 2.1, 2.2, 2.3, 3.8_
  - _Requirements: 0.1, 0.2, 0.6, 0.24, 0.25, 0.26_
  - _Boundary: ReaderEncryptionIntegration, EncryptionContext_

- [ ] 5.2 Decrypt indirect object loading and object streams
  - Apply object-context decryption after raw indirect parsing and before decrypted objects enter the cache.
  - Decrypt and decode object streams through the containing stream context before parsing member objects.
  - Prevent object stream members from being decrypted a second time when they are returned through normal object loading.
  - Done: object loader tests prove encrypted strings, encrypted streams, encrypted object streams, cache reuse, and double-decryption guards behave as designed.
  - _Depends: 4.4, 5.1_
  - _Requirements: 0.2, 0.4, 0.5_
  - _Boundary: ReaderEncryptionIntegration, ObjectDecryptor_

- [ ] 5.3 Add file-aware stream decoding before ordinary filters
  - Provide a reader-owned stream decode path that decrypts raw stream bytes, strips consumed Crypt filter metadata, and then delegates remaining ordinary filters.
  - Preserve raw stream byte ownership and ensure cross-reference streams and object streams use the correct stream purpose.
  - Propagate encryption and ordinary filter failures through typed reader errors with object context where available.
  - Done: stream decode tests prove encrypted Flate, Identity metadata, AESV3 CBC, Crypt override, xref stream, and object stream ordering behavior.
  - _Depends: 4.1, 4.2, 4.3, 5.1_
  - _Requirements: 0.2, 0.5, 0.27_
  - _Boundary: ReaderEncryptionIntegration, CryptFilterRegistry, FilterPipeline_

- [ ] 5.4 Route page content and metadata consumers through file-aware decoding
  - Migrate page content and document metadata access so encrypted streams are decoded through the reader-owned stream workflow.
  - Respect metadata encryption flags and Identity crypt filters without changing content parsing or metadata object ownership.
  - Keep pure filter and content unit tests available for already-plaintext byte inputs.
  - Done: page content and metadata integration tests read encrypted and Identity-protected streams through public reader workflows.
  - _Depends: 5.3_
  - _Requirements: 0.1, 0.2, 0.5, 0.27_
  - _Boundary: ReaderEncryptionIntegration, ContentStreamBridge, InterchangeMetadata_

- [ ] 5.5 Route graphics, XObject, and embedded-file stream consumers through file-aware decoding
  - Preserve object identity and stream purpose for form XObjects, images, ICC profiles, patterns, shadings, transparency resources, multimedia streams, and embedded file streams.
  - Use EFF and EFOpen-aware selection for embedded files and related files while leaving permission enforcement out of rendering and editing paths.
  - Avoid changing ordinary graphics, image, or multimedia parsing for already-plaintext decoded data.
  - Done: representative graphics and embedded-file tests prove encrypted resource streams decrypt before their existing parsers consume bytes.
  - _Depends: 5.3_
  - _Requirements: 0.1, 0.2, 0.5, 0.6, 0.27_
  - _Boundary: ReaderEncryptionIntegration, GraphicsStreamAccess, MultimediaEmbeddedFiles_

- [ ] 5.6 Integrate encrypted wrapper payload metadata
  - Detect encrypted payload dictionaries from file specification paths used by wrapper documents.
  - Expose payload subtype and version metadata or precise malformed-wrapper diagnostics without auto-opening the embedded payload.
  - Preserve existing collection, name-tree, associated-file, and file-specification behavior outside the payload metadata addition.
  - Done: wrapper document tests identify a valid encrypted payload, reject malformed payload dictionaries, and leave unrelated embedded files unchanged.
  - _Depends: 2.4, 5.1_
  - _Requirements: 0.28_
  - _Boundary: ReaderEncryptionIntegration, EncryptedPayloadParser_

- [ ] 6. Validate algorithms, dictionaries, and encryption-layer behavior
- [ ] 6.1 Validate crypto primitives with independent vectors and malformed-input tests
  - Cover digest, RC4, AES, mode, padding, block-size, IV-size, and key-size behavior.
  - Include failure cases that prove typed crypto errors are returned before higher encryption logic executes.
  - Keep test data independent from PDF fixtures so primitive failures can be isolated quickly.
  - Done: the crypto package test suite passes on its own and gives deterministic evidence for every primitive used by encryption.
  - _Depends: 1.2, 1.3, 1.4, 1.5, 1.6, 1.7_
  - _Requirements: 0.3, 0.4, 0.5, 0.9, 0.10, 0.11, 0.20, 0.26, 0.27_
  - _Boundary: CryptoPrimitives tests_

- [ ] 6.2 Validate encryption dictionary, public-key metadata, and wrapper parsing
  - Cover common encryption dictionaries, standard handler dictionaries, crypt filter dictionaries, public-key dictionaries, and encrypted payload dictionaries.
  - Cover direct-object requirements, missing required keys, wrong types, unsupported values, and default handling.
  - Verify requirement-specific permission bit decoding for standard and public-key handlers.
  - Done: encryption parser tests prove valid structures produce typed values and malformed structures produce exact diagnostics.
  - _Depends: 2.1, 2.2, 2.3, 2.4_
  - _Requirements: 0.2, 0.6, 0.7, 0.24, 0.25, 0.26, 0.27, 0.28_
  - _Boundary: EncryptionDictionaryParser tests, PublicKeyDictionaryParser tests, EncryptedPayloadParser tests_

- [ ] 6.3 Validate standard handler algorithms and object transformations
  - Cover revision 4 and earlier Algorithms 2 through 7, revision 6 Algorithms 2.A, 2.B, and 8 through 13, and supported object-level encryption methods.
  - Cover string and stream exception paths, encrypted object streams, embedded file streams, metadata Identity filters, and unsupported custom crypt filters.
  - Verify invalid credentials, malformed Perms, and unsupported algorithms never return decrypted payload bytes.
  - Done: encryption-layer tests prove standard-password authentication and object decryption behavior before reader integration tests run.
  - _Depends: 3.8, 4.4_
  - _Requirements: 0.4, 0.5, 0.8, 0.9, 0.10, 0.11, 0.12, 0.13, 0.14, 0.15, 0.16, 0.17, 0.18, 0.19, 0.20, 0.21, 0.22, 0.23, 0.27_
  - _Boundary: StandardSecurityHandler tests, ObjectDecryptor tests, CryptFilterRegistry tests_

- [ ] 7. Validate reader integration and final public surface
- [ ] 7.1 Add encrypted PDF fixture coverage for public reader workflows
  - Add small synthetic fixtures for revision 4 AESV2, revision 6 AESV3, encrypted Flate streams, Identity metadata streams, encrypted object streams, invalid credentials, and unsupported public-key handlers.
  - Exercise credential-aware opening, object loading, page content access, metadata access, graphics resource stream access, and wrapper payload metadata.
  - Verify invalid credentials and unsupported handlers fail before protected content is returned.
  - Done: reader integration tests prove encrypted documents can be opened and decoded only through authorized, file-aware workflows.
  - _Depends: 5.2, 5.3, 5.4, 5.5, 5.6_
  - _Requirements: 0.1, 0.2, 0.5, 0.6, 0.24, 0.25, 0.26, 0.27, 0.28_
  - _Boundary: ReaderEncryptionIntegration tests_

- [ ] 7.2 Add performance and regression coverage for encryption state
  - Verify object cache entries store decrypted objects once and repeated loads do not repeat object decryption.
  - Verify Algorithm 2.B allocation and round behavior stay bounded for password-sized data.
  - Verify large encrypted streams progress linearly and do not change raw stream ownership.
  - Done: regression tests complete without hangs, repeated decryption, unbounded allocation, or raw-stream mutation.
  - _Depends: 5.2, 5.3, 6.3_
  - _Requirements: 0.2, 0.5, 0.10, 0.11, 0.27_
  - _Boundary: ReaderEncryptionIntegration tests, StandardR6Handler tests, PerformanceRegression tests_

- [ ] 7.3 Run final formatting, checks, tests, and public API review
  - Format all changed packages and run targeted tests for crypto, encryption, reader, filters, content, graphics, and interchange paths touched by the integration.
  - Run the full project check and test suite, then regenerate and review public interfaces.
  - Confirm generated interfaces expose only the intended crypto support surface, encryption models, reader credential APIs, permission accessors, and typed errors.
  - Done: validation commands pass and the public interface diff matches the design boundaries without new external dependencies.
  - _Depends: 7.1, 7.2_
  - _Requirements: 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 0.10, 0.11, 0.12, 0.13, 0.14, 0.15, 0.16, 0.17, 0.18, 0.19, 0.20, 0.21, 0.22, 0.23, 0.24, 0.25, 0.26, 0.27, 0.28_
  - _Boundary: BuildValidation, PublicInterfaces_
