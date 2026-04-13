# Research & Design Decisions

## Summary
- **Feature**: `pdf-filters`
- **Discovery Scope**: Extension
- **Key Findings**:
  - The existing `reader` package already isolates structural stream decoding in `decode_structural_stream`; the filter subsystem can replace that rejection boundary without moving xref or object-stream parsing responsibilities.
  - The project steering currently permits only MoonBit standard-library dependencies. A local scan found no existing zlib/flate package in the project or installed MoonBit library metadata, so FlateDecode must be implemented in-project unless the dependency policy is deliberately changed.
  - PDF filter handling is a general stream concern, not a reader concern. The new package should depend only on `objects`, and `reader` should depend on `filters` for structural stream decoding.

## Research Log

### Existing Stream Decode Boundary
- **Context**: Requirement 8 requires xref streams and object streams to call the filter decoder.
- **Sources Consulted**: `src/reader/stream_decode.mbt`, `src/reader/xref_stream.mbt`, `src/reader/object_stream.mbt`, `.kiro/specs/pdf-file-structure/design.md`, `.kiro/specs/pdf-file-structure/research.md`.
- **Findings**:
  - `decode_structural_stream` accepts a `PdfStream`, a structural purpose, and an offset, then currently passes through unfiltered data or raises `PdfReaderError::UnsupportedFilter`.
  - `parse_xref_stream_section` and `parse_object_stream` already call this boundary before interpreting xref or object stream bytes.
  - `PdfStream.data` remains encoded raw stream data by design; decoding must not be pushed into `parser` or `objects`.
- **Implications**:
  - Add `src/filters` as a downstream package of `src/objects`.
  - Change `src/reader/stream_decode.mbt` to delegate supported filters to `@filters.decode_stream` while retaining xref-specific encryption and Crypt rejection.
  - Preserve `PdfStream.data` as raw encoded bytes.

### ISO 32000-2 Filter Rules
- **Context**: Requirements 1 through 7 reference ISO 32000-2:2020 section 7.4.
- **Sources Consulted**: `spec/extracted/7.4-filters.spec.txt`, `spec/extracted/7.3-objects.md`, `spec/extracted/7.5-file-structure.md`.
- **Findings**:
  - `Filter` may be one name or an array of names; `DecodeParms` may be omitted, a dictionary for a single filter, or an array aligned with the filter array where `null` means default parameters.
  - ASCIIHexDecode, ASCII85Decode, LZWDecode, FlateDecode, and RunLengthDecode are the in-scope decoders for this phase.
  - CCITTFaxDecode, JBIG2Decode, DCTDecode, JPXDecode, and Crypt are valid standard filters but remain out of scope and must fail explicitly.
  - LZW and Flate share predictor parameters: `Predictor`, `Colors`, `BitsPerComponent`, and `Columns`; LZW alone uses `EarlyChange`.
- **Implications**:
  - Normalize the stream dictionary into a typed `FilterPipeline` before running decoders.
  - Share predictor parsing and reconstruction between FlateDecode and LZWDecode.
  - Keep unsupported-filter errors in the filter package and include the filter name.

### FlateDecode Dependency Check
- **Context**: Requirement 4 requires zlib/deflate decoding, but steering says external dependencies are not currently allowed.
- **Sources Consulted**: `.kiro/steering/tech.md`, `.kiro/steering/structure.md`, `moon.mod.json`, `moon.pkg` files, `rg` scan for `deflate|inflate|zlib|LZW`, local MoonBit library metadata scan, `moon check --target all`.
- **Findings**:
  - The repository has no Flate, zlib, compression, or checksum implementation.
  - `moon.mod.json` currently declares no dependencies beyond the module metadata.
  - `moon check --target all` succeeds with existing warnings, so a pure MoonBit filter package preserves native and wasm targets without new runtime prerequisites.
- **Implications**:
  - Design FlateDecode as a pure MoonBit zlib container and DEFLATE decoder inside `src/filters`.
  - Include Adler-32 validation as part of zlib stream validation.
  - Treat future adoption of a native zlib binding as a revalidation trigger because it changes target compatibility and dependency policy.

### Existing MoonBit Patterns
- **Context**: The design must produce implementable tasks that match the current project style.
- **Sources Consulted**: `src/objects/types.mbt`, `src/objects/error.mbt`, `src/reader/error.mbt`, `src/reader/*_wbtest.mbt`, `pkg.generated.mbti`, `src/reader/pkg.generated.mbti`, `moonbit-agent-guide`.
- **Findings**:
  - Public matchable errors use `pub(all) suberror` and derive `Eq, Debug`.
  - Packages are organized by directory and many small cohesive `.mbt` files.
  - Tests use black-box `*_test.mbt` for public APIs and white-box `*_wbtest.mbt` for package-local decoders and edge cases.
  - Public API changes are reviewed with `moon info` and `pkg.generated.mbti`.
- **Implications**:
  - Define `PdfFilterError` in `src/filters/error.mbt`.
  - Keep decoder internals package-private and expose one public decode entry point plus typed errors.
  - Add focused white-box tests for each algorithm and black-box tests for pipeline behavior.

## Architecture Pattern Evaluation

| Option | Description | Strengths | Risks / Limitations | Notes |
|--------|-------------|-----------|---------------------|-------|
| Dedicated `filters` package | Add `src/filters` importing only `objects`; reader imports filters at the structural decode boundary. | Preserves dependency direction, keeps filter logic reusable for later content and image streams, isolates algorithm tests. | Requires one reader integration update and public error mapping. | Selected. |
| Implement filters inside `reader` | Put all decoders behind `decode_structural_stream`. | Minimal package wiring for Phase 2 integration. | Mixes general stream decoding with file structure, cannot be reused cleanly by future content/image layers. | Rejected. |
| Decode streams in `parser` | Make `PdfStream.data` decoded by default. | Callers see decoded bytes immediately. | Violates existing raw-stream contract, requires object parser to understand filter dictionaries and external compression. | Rejected. |
| Native zlib binding plus local simple filters | Use platform zlib through FFI for FlateDecode. | Smaller Flate implementation on native. | Conflicts with standard-library-only steering, complicates wasm, introduces build prerequisites. | Rejected for this spec; future revalidation trigger. |
| Pure MoonBit all-decoder implementation | Implement ASCIIHex, ASCII85, RunLength, LZW, predictors, and zlib/deflate locally. | No external dependencies, works across native and wasm, testable package boundary. | Flate implementation is the largest risk and needs careful vectors. | Selected. |

## Design Decisions

### Decision: Normalize filters into a typed pipeline
- **Context**: Requirement 1 allows both single-name and array filter declarations with optional aligned decode parameters.
- **Alternatives Considered**:
  1. Inspect `Filter` and `DecodeParms` directly in each decoder call.
  2. Normalize once into `FilterPipeline` and run a simple byte-to-byte pipeline.
- **Selected Approach**: Parse stream dictionary entries into `FilterSpec` values containing `FilterName` and optional `DecodeParams`, then apply each filter in order.
- **Rationale**: A normalized pipeline makes array alignment errors and unsupported filters explicit before mutating decoded bytes.
- **Trade-offs**: Adds small model and dictionary parsing code, but removes repeated object-shape checks from individual filters.
- **Follow-up**: Tests must cover single filter, filter array, parameter dictionary, parameter array, null parameter entries, malformed shapes, and mismatched array lengths.

### Decision: Keep filter errors independent from reader errors
- **Context**: Filter decoding will be used by reader now and content/image streams later.
- **Alternatives Considered**:
  1. Reuse `PdfReaderError::UnsupportedFilter` and reader offsets inside `filters`.
  2. Define `PdfFilterError` in `filters` and let callers wrap or propagate it.
- **Selected Approach**: `filters` exposes `PdfFilterError` with filter name and reason. `reader` wraps it in a new reader error variant at structural stream call sites.
- **Rationale**: Filters should not depend on reader offsets or file-structure error categories.
- **Trade-offs**: Reader integration needs a small public error change.
- **Follow-up**: `moon info` must show the intended `src/filters` API and reader error addition.

### Decision: Share predictor reconstruction
- **Context**: Requirements 4 and 5 both require identical predictor behavior after Flate or LZW decompression.
- **Alternatives Considered**:
  1. Duplicate predictor code in both filters.
  2. Add one predictor module that consumes decompressed bytes and parsed parameters.
- **Selected Approach**: Implement `predictor.mbt` with one `apply_predictor` function for `Predictor` values 1, 2, and 10 through 15.
- **Rationale**: Predictor reconstruction is independent of the compression algorithm and should have one validation and test surface.
- **Trade-offs**: The predictor module must handle byte and bit-level row-width calculations carefully.
- **Follow-up**: Tests must include default parameters, PNG filter bytes per row, all PNG filter types, TIFF predictor with common bit depths, and invalid row lengths.

### Decision: Build pure MoonBit zlib and DEFLATE
- **Context**: Requirement 4 names zlib/deflate and project steering currently disallows external dependencies.
- **Alternatives Considered**:
  1. Add native zlib through FFI.
  2. Vendor an external compression package.
  3. Implement the zlib container and DEFLATE blocks locally.
- **Selected Approach**: Implement local zlib header validation, DEFLATE stored/fixed/dynamic Huffman blocks, LZ77 length/distance copying, and Adler-32 checksum validation.
- **Rationale**: This meets ISO, preserves wasm compatibility, and keeps dependency policy unchanged.
- **Trade-offs**: Implementation complexity is high. The design limits scope to decoding only and requires strong vectors before reader integration is considered complete.
- **Follow-up**: Use deterministic fixtures generated outside the library only as test data, and validate malformed Huffman, distance, and checksum errors.

### Decision: Leave image-specific filters unsupported
- **Context**: Requirement 7 explicitly excludes CCITTFaxDecode, JBIG2Decode, DCTDecode, JPXDecode, and Crypt from this phase.
- **Alternatives Considered**:
  1. Stub unsupported filters as identity transforms.
  2. Return a typed unsupported-filter error including the filter name.
- **Selected Approach**: Reject unsupported filters before applying subsequent filters.
- **Rationale**: Silent pass-through corrupts decoded data and hides missing functionality from callers.
- **Trade-offs**: Some PDFs remain unreadable until later image/encryption phases.
- **Follow-up**: Reader and future content-stream callers must surface unsupported filter names to users or tests.

## Risks & Mitigations
- FlateDecode is algorithmically complex - Keep zlib, bit reader, Huffman tables, and inflate state in separate files with targeted white-box vectors.
- Predictor row-width math can corrupt image data silently - Centralize row byte calculation and reject inconsistent input lengths.
- `DecodeParms` array alignment can apply wrong parameters to a filter - Normalize pipeline specs before decoding and test every accepted shape.
- LZW `EarlyChange` off-by-one errors can break common PDFs - Treat code-width transition as a dedicated state function and test both `0` and `1`.
- Reader may accidentally accept `Crypt` for xref streams - Preserve xref-specific rejection before general filter delegation.
- Large streams can cause memory growth during decoding - Decode into owned `Bytes` only at filter boundaries, validate expansion loops, and add performance-boundary tests for large literal runs and repeated back-references.

## References
- `spec/extracted/7.4-filters.spec.txt` - local ISO 32000-2 section 7.4 excerpt for filter pipeline, ASCIIHex, ASCII85, LZW, Flate, predictors, RunLength, and unsupported standard filter names.
- `spec/extracted/7.3-objects.md` - local ISO stream dictionary entries for `Filter` and `DecodeParms`.
- `spec/extracted/7.5-file-structure.md` - local ISO xref and object stream references that require decoded structural stream bytes.
- `.kiro/specs/pdf-file-structure/design.md` - existing structural stream decoder boundary and revalidation triggers.
- `.kiro/steering/product.md`, `.kiro/steering/tech.md`, `.kiro/steering/structure.md` - project goals, MoonBit tooling rules, and package dependency direction.
