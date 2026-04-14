# Research & Design Decisions

## Summary
- **Feature**: `pdf-encryption`
- **Discovery Scope**: Comprehensive extension discovery for a security-sensitive reader feature.
- **Key Findings**:
  - Existing `PdfStream.data` is raw encoded stream data, and the `pdf-filters` design explicitly left `Crypt` and encryption out of scope. Encryption must therefore be inserted before ordinary stream filter decoding without changing object parser semantics.
  - `TrailerInfo` already exposes an optional `encrypt` reference and raw trailer dictionary. The reader can detect encrypted files at open time, but object loading currently has no object context for decrypting strings and streams by object number and generation.
  - MoonBit core in the local toolchain does not expose AES, MD5, SHA, RC4, CMS, or X.509 primitives. Steering also requires standard-library-only dependencies, so this design keeps cryptographic primitives in a focused internal package and gates conformance with official algorithm vectors and PDF fixtures.

## Research Log

### Existing reader and filter integration
- **Context**: PDF encryption applies to strings and streams, but filters operate on encoded stream bytes.
- **Sources Consulted**: `src/objects/types.mbt`, `src/parser/stream.mbt`, `src/reader/types.mbt`, `src/reader/object_loader.mbt`, `src/reader/stream_decode.mbt`, `.kiro/specs/pdf-filters/design.md`.
- **Findings**:
  - `PdfObject::String` stores decoded string bytes after literal escape or hexadecimal decoding.
  - `PdfStream.data` stores the exact raw bytes read from the `Length` entry.
  - `@filters.decode_stream` consumes raw stream bytes and applies ordinary PDF stream filters.
  - Structural streams already pass through `src/reader/stream_decode.mbt`, which is the natural insertion point for decryption before filter decoding.
  - General downstream code in `reader`, `content`, `graphics`, and `interchange` still calls `@filters.decode_stream` directly for non-structural streams.
- **Implications**:
  - The encryption design must add file-aware stream decode helpers and migrate downstream reader-owned paths away from direct filter calls when encrypted files are possible.
  - Parser and object model changes should be avoided except for adding encrypted-load state in the reader package.

### Encryption dictionary and object context
- **Context**: Algorithm 1 requires the containing indirect object id, and Algorithm 1.A uses the file key directly.
- **Sources Consulted**: `.kiro/specs/pdf-encryption/requirements.md`, `src/reader/trailer.mbt`, `src/reader/object_loader.mbt`, `spec/extracted/7.6-encryption.spec.txt`.
- **Findings**:
  - Trailer `/Encrypt` absence means the document is not encrypted.
  - Trailer `/ID` is required for PDF 2.0 and already parsed as `PdfFileId`.
  - Encrypted object streams create two layers: the object stream itself must be decrypted and decoded before its member objects can be parsed, then string members inside the object stream are already plaintext because the enclosing stream was encrypted as a whole.
  - The encryption dictionary and trailer `/ID` values are not decrypted, and signature `/Contents` hexadecimal strings are exempt.
- **Implications**:
  - Object loading must decrypt exactly at indirect-object boundaries and must carry an `ObjectId` into string and stream decryption.
  - Compressed object stream member parsing must mark members as already decrypted to avoid double-decrypting strings inside encrypted object streams.

### Cryptographic primitive availability
- **Context**: Standard security handlers require MD5, SHA-256, SHA-384, SHA-512, RC4, AES-CBC, AES-ECB, PKCS padding, and no-padding AES modes.
- **Sources Consulted**: local MoonBit core package files under `~/.moon/lib/core`, `moon.mod.json`, `.kiro/steering/tech.md`.
- **Findings**:
  - The local core library contains data-structure hashers but no cryptographic digest or cipher packages.
  - The project currently has no external dependencies and targets native primarily with wasm as a secondary target.
  - Native-only C bindings would violate the secondary wasm target and add runtime prerequisites not present in steering.
- **Implications**:
  - The design uses a project-local `src/crypto` package with narrow primitives required by PDF decryption.
  - The cryptographic package is internal implementation support for parsing encrypted PDFs, not a general-purpose security product API.

### Public-key security handlers and wrapper documents
- **Context**: Section 7.6 includes CMS/X.509 public-key handlers and unencrypted wrapper documents.
- **Sources Consulted**: `.kiro/specs/pdf-encryption/requirements.md`, `src/reader/collection*.mbt`, `src/reader/interchange_file_id.mbt`, `src/reader/multimedia_types.mbt`.
- **Findings**:
  - CMS and X.509 require external key stores, private key access, ASN.1/CMS parsing, and platform integration that are not present elsewhere in the codebase.
  - Unencrypted wrapper detection is document-structure metadata and does not require decrypting the encrypted payload during initial parsing.
- **Implications**:
  - This spec parses public-key encryption dictionaries and reports typed unsupported-handler errors for decryption unless a later spec adds a CMS recipient resolver.
  - This spec models encrypted payload dictionaries and wrapper validation enough for consumers to identify the payload and required cryptographic filter.

## Architecture Pattern Evaluation

| Option | Description | Strengths | Risks / Limitations | Notes |
|--------|-------------|-----------|---------------------|-------|
| Parser-level decryption | Decrypt strings and streams while parsing indirect objects | Transparent to downstream code | Parser needs trailer state, passwords, object ids, and filter ordering; violates current layer boundaries | Rejected |
| Reader encryption context | Keep parser raw, let `PdfFile` own authentication, object-context decryption, and file-aware stream decoding | Fits existing lazy reader ownership and `TrailerInfo.encrypt`; keeps parser independent | Requires migrating direct downstream filter calls to reader-aware helpers | Selected |
| Filter package owns `Crypt` | Add `Crypt` handling directly to `src/filters` | Centralizes filter chains | Filters would need passwords and file encryption keys, reversing dependency direction | Rejected |
| Native crypto bindings | Bind to platform crypto libraries | Reuses audited primitives on native | Adds target-specific dependencies and weakens wasm support | Rejected for this phase |
| Internal crypto package | Implement only required PDF primitives with test vectors | Standard-library-only and target-independent | Higher validation burden; not a general hardened crypto library | Selected |

## Design Decisions

### Decision: Reader owns encrypted document state
- **Context**: Encryption depends on trailer `/Encrypt`, file identifier, passwords, and object ids.
- **Alternatives Considered**:
  1. Parser-level decryption during indirect-object parsing.
  2. Filter-level `Crypt` support with hidden global state.
  3. Reader-level encryption context.
- **Selected Approach**: `PdfFile` stores an optional `EncryptionContext` built from the latest trailer. Object loading and stream decoding pass through reader helpers that have object id and purpose context.
- **Rationale**: `reader` already owns file structure, trailer metadata, lazy object loading, and structural stream decode order.
- **Trade-offs**: Downstream modules that decode streams must call reader-aware APIs to support encrypted files.
- **Follow-up**: Implementation tasks must migrate reader-owned stream decoding paths and leave raw `@filters.decode_stream` only for byte streams known to be unencrypted.

### Decision: Decryption before ordinary filters
- **Context**: ISO 32000-2 section 7.6.3.3 requires stream data to be decrypted before applying decoding filters.
- **Alternatives Considered**:
  1. Decode filters first, then decrypt.
  2. Combine decryption into the filter pipeline.
  3. Decrypt raw stream bytes first, then call the existing filter pipeline.
- **Selected Approach**: `EncryptionContext::decrypt_stream_bytes` returns plaintext encoded stream bytes, then `@filters.decode_stream_bytes` applies normal filters.
- **Rationale**: This preserves the current filter package boundary and PDF filter semantics.
- **Trade-offs**: `Crypt` filter handling must be normalized before the normal filter pipeline sees it.
- **Follow-up**: Add integration tests with encrypted Flate streams and Identity crypt filters.

### Decision: Internal cryptographic primitives with conformance vectors
- **Context**: The local MoonBit environment does not provide required cryptographic packages, and steering currently disallows external dependencies.
- **Alternatives Considered**:
  1. Add external or native crypto dependencies.
  2. Implement a broad reusable crypto library.
  3. Implement a narrow internal crypto package required by PDF encryption.
- **Selected Approach**: Create `src/crypto` with AES block cipher modes, RC4, MD5, SHA-256, SHA-384, SHA-512, PKCS padding helpers, byte-order helpers, and fixed test vectors.
- **Rationale**: This keeps native and wasm support aligned while making crypto review localized.
- **Trade-offs**: Security review and vector coverage are mandatory; the package must not claim general-purpose security suitability.
- **Follow-up**: Revalidate if steering allows external dependencies or if target requirements change.

### Decision: Public-key handlers are parsed but not decrypted in this phase
- **Context**: Public-key decryption requires CMS, X.509, private key discovery, and user authentication outside current project infrastructure.
- **Alternatives Considered**:
  1. Implement CMS and certificate handling now.
  2. Ignore public-key dictionaries.
  3. Parse dictionary shape and fail with an explicit unsupported handler for decryption.
- **Selected Approach**: Parse public-key fields into typed metadata and return `UnsupportedSecurityHandler` for document opening unless a later resolver interface is approved.
- **Rationale**: This gives callers actionable diagnostics without absorbing a separate certificate subsystem into this spec.
- **Trade-offs**: Public-key encrypted content cannot be decrypted by this phase.
- **Follow-up**: A later spec can add a CMS recipient resolver behind the same security handler boundary.

### Decision: SASLprep is an explicit constrained boundary
- **Context**: Revision 6 passwords require SASLprep with Normalize and BiDi processing before UTF-8 truncation.
- **Alternatives Considered**:
  1. Treat MoonBit strings as UTF-8 without SASLprep.
  2. Implement the required stringprep subset internally.
  3. Reject non-ASCII passwords.
- **Selected Approach**: Add `PasswordPreprocessor` that applies the revision-specific byte rules and owns a stringprep profile implementation sufficient for RFC 4013 requirements.
- **Rationale**: Revision 6 authentication cannot be conformant without this preprocessing.
- **Trade-offs**: Unicode profile implementation increases test scope.
- **Follow-up**: Add RFC-derived positive and negative password preprocessing fixtures.

## Risks & Mitigations
- Double-decryption of compressed object-stream members - track decrypted object-stream membership and parse member objects from plaintext object stream data only.
- Incorrect stream order - enforce decryption before ordinary filters in one reader-owned helper and test encrypted Flate fixtures.
- Missing object id context for direct strings - decrypt direct strings using the containing indirect object id during recursive object transformation.
- Public-key scope creep - parse metadata and return typed unsupported errors until a dedicated CMS/X.509 spec exists.
- Weak crypto correctness - require independent vector tests for every primitive and PDF algorithm before enabling encrypted fixture parsing.
- Downstream direct filter calls bypass encryption - migrate reader/document/graphics/interchange decode paths that have `PdfFile` context to reader-aware helpers.

## References
- `spec/extracted/7.6-encryption.spec.txt` - ISO 32000-2:2020 encryption excerpt used as normative local source.
- `.kiro/specs/pdf-encryption/requirements.md` - Approved requirements IDs 0.1 through 0.28.
- `.kiro/specs/pdf-filters/design.md` - Existing filter boundary and explicit encryption non-goals.
- `.kiro/specs/pdf-file-structure/design.md` - Existing reader ownership of trailer, xref, object loading, and structural streams.
- `.kiro/steering/product.md`, `.kiro/steering/tech.md`, `.kiro/steering/structure.md` - Project goals, standard-library dependency policy, package direction, and MoonBit conventions.
- FIPS 197, RFC 1321, RFC 8018, RFC 3454, RFC 4013, RFC 5652 - External standards referenced by ISO 32000-2 section 7.6.
