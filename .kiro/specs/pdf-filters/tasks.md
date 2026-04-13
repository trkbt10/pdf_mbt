# Implementation Plan

- [ ] 1. Establish the filter decoding foundation
- [x] 1.1 Set up the reusable filter package boundary
  - Add the package configuration needed for a standard-library-only filter layer that depends on the object model and no runtime compression bindings.
  - Provide stream-decoding entry points that can accept a parsed stream or an equivalent dictionary plus raw bytes.
  - Return the original byte sequence unchanged when a stream has no `Filter` entry.
  - The package builds as an independent layer and exposes only the intended decoding surface.
  - _Requirements: 1.5, 8.3_

- [x] 1.2 Define typed filter diagnostics
  - Distinguish malformed filter specifications, invalid decode parameters, malformed encoded data, and unsupported filters.
  - Include the responsible filter name for unsupported filters and filter-specific decode failures.
  - Keep reader offsets out of filter errors so callers can wrap failures with their own context.
  - Tests can assert the error category, filter name, and reason without parsing a formatted message.
  - _Requirements: 7.1, 7.2, 7.3, 8.4_

- [ ] 1.3 Normalize filter and decode-parameter entries
  - Accept `Filter` as either one name or an ordered array of names.
  - Accept omitted, dictionary, array, and null decode-parameter forms according to the filter count.
  - Reject mismatched parameter arrays, malformed filter entries, indirect parameter references, and unsupported parameter shapes before any bytes are decoded.
  - Black-box pipeline tests show each normalized filter receives the parameter dictionary aligned to its position.
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 7.3_
  - _Blocked: Task 1.3 requires black-box public-pipeline proof of DecodeParms alignment, but the current public API has no legitimate observable parameter-sensitive behavior before real decoders exist. Human review is needed to split this task, defer the black-box assertion to a parameter-sensitive decoder task, or explicitly approve a narrow test seam._

## Implementation Notes
- `Filter` null entries are rejected as malformed input; only an absent `Filter` entry is treated as an identity decode path.
- Pipeline normalization completes before any filter is applied, so malformed later entries fail before partial output can be produced.

- [ ] 2. Implement independent byte-oriented filters
- [x] 2.1 (P) Decode ASCII hexadecimal streams
  - Decode uppercase and lowercase hexadecimal digit pairs into bytes while ignoring PDF white-space bytes.
  - Stop decoding at the `>` end marker and pad an odd final digit with zero.
  - Reject invalid non-whitespace bytes that appear before the end marker.
  - White-box tests cover pairs, whitespace, odd digit padding, end-marker handling, and malformed input.
  - _Requirements: 2.1, 2.2, 2.3, 2.4_
  - _Boundary: ASCIIHexDecoder_

- [x] 2.2 (P) Decode ASCII base-85 streams
  - Decode five-character base-85 groups into four binary bytes using PDF's accepted character range.
  - Support the `z` abbreviation only as a complete zero group and reject invalid placement inside partial groups.
  - Decode final partial groups by padding with `u`, emitting only the corresponding output bytes.
  - White-box tests cover normal groups, `z`, partial groups, `~>` handling, whitespace, impossible values, and malformed terminators.
  - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5_
  - _Boundary: ASCII85Decoder_

- [x] 2.3 (P) Decode run-length streams
  - Copy literal runs for length bytes 0 through 127.
  - Expand repeated-byte runs for length bytes 129 through 255.
  - Stop at the 128 end marker without letting following bytes affect output.
  - White-box tests cover literal runs, repeated runs, end-marker behavior, truncated literals, and truncated repeats.
  - _Requirements: 6.1, 6.2, 6.3_
  - _Boundary: RunLengthDecoder_

- [ ] 3. Implement shared predictor reconstruction
- [x] 3.1 Parse predictor parameters and row geometry
  - Apply defaults for `Predictor`, `Colors`, `BitsPerComponent`, and `Columns` at the predictor boundary.
  - Calculate row byte width from colors, component bits, and columns using byte rounding.
  - Reject unsupported predictor values and invalid non-positive row parameters with filter-specific diagnostics.
  - Predictor tests demonstrate default no-op behavior and invalid-parameter failures before row reconstruction begins.
  - _Requirements: 4.2, 4.3, 4.5, 5.4_

- [x] 3.2 Reconstruct TIFF predictor rows
  - Implement predictor value 2 using the configured component geometry.
  - Preserve predictor value 1 as an exact no-op for already decompressed data.
  - Reject data whose length cannot be divided into complete reconstructed rows.
  - Tests show TIFF predictor output for single-color and multi-color rows.
  - _Requirements: 4.2, 4.3, 4.5, 5.4_

- [x] 3.3 Reconstruct PNG predictor rows
  - Consume one filter-type byte per row for predictor values 10 through 15.
  - Implement PNG None, Sub, Up, Average, and Paeth reconstruction using the prior row when required.
  - Reject unknown row filter bytes and inconsistent row lengths.
  - Tests cover all PNG row filter types and confirm reconstructed bytes match expected row data.
  - _Requirements: 4.2, 4.3, 4.4, 4.5, 5.4_

- [ ] 4. Implement FlateDecode decompression
- [x] 4.1 Build bit-level reading and zlib container validation
  - Provide deterministic bit reading for least-significant-bit-first DEFLATE fields.
  - Validate zlib header method, window flags, check bits, and preset dictionary rejection.
  - Compute and validate Adler-32 over the uncompressed DEFLATE output.
  - Tests reject invalid headers, preset dictionaries, truncated payloads, and checksum mismatches.
  - _Requirements: 4.1_

- [x] 4.2 Decode stored DEFLATE blocks
  - Parse block headers, final-block markers, stored block lengths, and one's-complement length checks.
  - Emit uncompressed bytes for stored blocks and reject malformed stored block boundaries.
  - Validate that the zlib wrapper returns the stored-block output only after checksum verification.
  - Tests decode valid stored-block streams and reject invalid length pairs.
  - _Requirements: 4.1_

- [x] 4.3 Decode fixed-Huffman DEFLATE blocks
  - Build the fixed literal/length and distance code tables required by DEFLATE.
  - Decode literals, end-of-block markers, and length/distance back-references.
  - Reject distance references that reach before already produced output.
  - Tests decode fixed-Huffman streams with literals and repeated distance copies.
  - _Requirements: 4.1_

- [x] 4.4 Decode dynamic-Huffman DEFLATE blocks
  - Parse code-length alphabets, repeated code-length instructions, and dynamic literal/distance tables.
  - Reject over-subscribed, incomplete, or otherwise invalid Huffman table definitions.
  - Decode dynamic blocks through the same literal, length, and distance execution path as fixed blocks.
  - Tests cover valid dynamic-Huffman streams and bounded rejection of malformed table definitions.
  - _Requirements: 4.1_

- [x] 4.5 Apply Flate predictors and expose FlateDecode behavior through the pipeline
  - Pass decompressed bytes through predictor reconstruction when `Predictor` is greater than 1.
  - Surface malformed zlib, DEFLATE, checksum, and predictor failures as named FlateDecode errors.
  - Pipeline tests decode Flate streams with no predictor, TIFF predictor, and PNG predictors.
  - The FlateDecode stage returns fully decompressed and reconstructed bytes for supported inputs.
  - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5_

- [ ] 5. Implement LZWDecode decompression
- [x] 5.1 Decode the LZW code stream lifecycle
  - Read high-order-bit-first LZW codes starting at 9 bits.
  - Initialize the table with byte values plus clear-table and end-of-data codes.
  - Require a valid clear-table startup and stop only at the end-of-data code.
  - Tests cover clear-table startup, normal byte sequence output, table reset, and missing end-of-data failures.
  - _Requirements: 5.1, 5.2_

- [x] 5.2 Handle LZW code-width growth and EarlyChange
  - Increase code width up to 12 bits as the table reaches the configured threshold.
  - Implement the special current-code case using the previous sequence plus its first byte.
  - Support `EarlyChange` values 0 and 1, defaulting to 1, and reject unsupported values.
  - Tests cover 9-to-12-bit transitions, table limit behavior, both EarlyChange modes, and invalid code failures.
  - _Requirements: 5.1, 5.2, 5.3, 5.5_

- [x] 5.3 Apply LZW predictors and expose LZWDecode behavior through the pipeline
  - Pass LZW output through the shared predictor reconstruction when requested.
  - Surface malformed code streams, table overflows, invalid parameters, and predictor failures as named LZWDecode errors.
  - Pipeline tests decode LZW streams with and without predictor parameters.
  - The LZWDecode stage returns decompressed and reconstructed bytes for supported inputs.
  - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5_

- [ ] 6. Complete the filter pipeline behavior
- [x] 6.1 Apply single and chained filters in dictionary order
  - Execute a single named filter against the raw stream bytes.
  - Execute a filter array in order, passing each decoded result into the next stage.
  - Validate the full pipeline before the first transform so malformed later entries do not produce partial output.
  - Public pipeline tests prove chained filters return the fully decoded final byte sequence.
  - _Requirements: 1.1, 1.2, 1.5, 7.3_

- [x] 6.2 Align DecodeParms through end-to-end decoding
  - Pass a single parameter dictionary to a single filter.
  - Pass each parameter-array entry to the filter at the same index and treat null entries as no parameters.
  - Reject mismatched parameter arrays with an invalid filter specification error.
  - Pipeline tests demonstrate Flate and LZW predictor parameters are applied only to their corresponding filter stage.
  - _Requirements: 1.3, 1.4, 4.2, 5.4_

- [x] 6.3 Preserve unsupported-filter safety
  - Return descriptive unsupported-filter errors for CCITTFaxDecode, JBIG2Decode, DCTDecode, JPXDecode, and Crypt.
  - Return the same category for unknown filter names while preserving the name in the diagnostic.
  - Never treat unsupported filters as identity transforms or silently skip them in a chain.
  - Tests prove unsupported filters fail before any corrupted decoded data is returned.
  - _Requirements: 7.1, 7.2, 7.3_

- [ ] 7. Integrate filter decoding with structural stream reading
- [x] 7.1 Wrap filter failures in reader structural-stream errors
  - Add the reader dependency on the filter layer without changing parser or object ownership.
  - Preserve xref-specific encryption and Crypt rejection before general filter decoding.
  - Wrap filter failures with the structural stream offset while preserving the filter name and reason.
  - Reader tests can distinguish reader-side rejection from wrapped filter package failures.
  - _Requirements: 7.1, 7.2, 8.3, 8.4_

- [x] 7.2 Decode compressed cross-reference streams on demand
  - Delegate supported cross-reference stream filters to the filter pipeline.
  - Feed decoded xref stream bytes into the existing xref entry parser without changing raw stream storage.
  - Keep encrypted xref streams and Crypt-filtered xref streams rejected at the reader boundary.
  - Integration tests load FlateDecode-compressed xref streams and observe parsed xref entries.
  - _Requirements: 8.2, 8.3, 8.4_

- [x] 7.3 Decode compressed object streams on demand
  - Delegate supported object stream filters to the filter pipeline.
  - Feed decoded object stream bytes into the existing object member extraction path.
  - Propagate chain failures with the filter name and reader offset when object stream decoding fails.
  - Integration tests load FlateDecode-compressed object streams and observe resolved member objects.
  - _Requirements: 8.1, 8.3, 8.4_

- [ ] 7.4 Revalidate reader public behavior
  - Update reader-level public API and package-boundary checks to reflect the new filter dependency and error wrapping.
  - Preserve existing unfiltered xref and object stream behavior.
  - Preserve unsupported structural filter failures for filters outside this phase.
  - Reader regression tests pass for unfiltered, supported-filter, and unsupported-filter structural streams.
  - _Requirements: 7.1, 7.2, 7.3, 8.1, 8.2, 8.3, 8.4_

- [ ] 8. Validate the complete feature
- [ ] 8.1 Run the full package validation workflow
  - Format the updated MoonBit packages.
  - Run the complete test suite across object, parser, reader, and filter packages.
  - Regenerate and review public interface output so only the intended filter API and reader error additions are visible.
  - `moon fmt`, `moon test`, `moon check`, and `moon info` complete without failures.
  - _Requirements: 1.5, 7.3, 8.4_

- [ ] 8.2 Cover boundary and robustness regressions
  - Add regression coverage for large RunLength expansion, LZW table limit behavior, repeated DEFLATE distance copies, and malformed dynamic-Huffman rejection.
  - Add filter-chain failure tests that prove no partially decoded bytes are returned to reader callers.
  - Confirm unsupported filters and Crypt remain explicit failures after reader integration.
  - Robustness tests pass without changing raw `PdfStream` data ownership.
  - _Requirements: 4.1, 5.3, 6.1, 6.2, 7.1, 7.3, 8.4_
