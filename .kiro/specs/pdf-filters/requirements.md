# Requirements Document

## Project Description (Input)
Implement PDF stream filter decoding in MoonBit, conforming to ISO 32000-2:2020 (PDF 2.0) §7.4. Stream filters transform encoded stream data into decoded data. This layer integrates with `pdf-file-structure` (Phase 2) to decode compressed cross-reference streams and object streams, and provides the foundation for decoding page content streams and image data in later phases.

Reference specification: `spec/extracted/7.4-filters.spec.txt`

Dependencies: `pdf-objects` spec (Phase 1), `pdf-file-structure` spec (Phase 2).

## Requirements

### Requirement 1: Filter Pipeline
The filter decoder shall apply one or more filters to stream data in the order specified by the stream dictionary `Filter` entry per §7.4.1.

#### Acceptance Criteria
- When the `Filter` entry is a single name, the filter decoder shall apply that single filter to the stream data
- When the `Filter` entry is an array of names, the filter decoder shall apply filters in array order (first filter applied first to the raw data, output feeds into the next filter)
- When `DecodeParms` is present, the filter decoder shall pass the corresponding parameter dictionary to each filter
- When `DecodeParms` is an array, each element shall correspond to the filter at the same index; a null element means no parameters for that filter
- The filter decoder shall return the fully decoded byte sequence after all filters have been applied

### Requirement 2: ASCIIHexDecode Filter
The filter decoder shall decode ASCIIHexDecode streams per §7.4.2.

#### Acceptance Criteria
- The filter decoder shall decode pairs of hexadecimal digits (0-9, A-F, a-f) into bytes
- The filter decoder shall ignore white-space characters between hex digits
- When the stream contains an odd number of hex digits before the EOD marker `>`, the filter decoder shall pad the final digit with 0
- The filter decoder shall recognize `>` as the end-of-data (EOD) marker and stop decoding

### Requirement 3: ASCII85Decode Filter
The filter decoder shall decode ASCII85Decode streams per §7.4.3.

#### Acceptance Criteria
- The filter decoder shall decode groups of 5 ASCII characters (range `!` to `u`, codes 33 to 117) into 4 bytes of binary data using base-85 arithmetic
- The filter decoder shall handle the `z` abbreviation as representing four zero bytes
- When the final group contains fewer than 5 characters, the filter decoder shall pad with `u` characters, decode, and use only the corresponding number of output bytes
- The filter decoder shall recognize `~>` as the end-of-data (EOD) marker
- The filter decoder shall ignore white-space characters within the encoded data

### Requirement 4: FlateDecode Filter
The filter decoder shall decode FlateDecode streams using zlib/deflate decompression per §7.4.4.

#### Acceptance Criteria
- The filter decoder shall decompress data using the zlib deflate algorithm (RFC 1950 / RFC 1951)
- When `DecodeParms` specifies a `Predictor` value greater than 1, the filter decoder shall apply the corresponding predictor function after decompression
- The filter decoder shall support predictor values: 1 (no prediction), 2 (TIFF predictor), 10-15 (PNG predictors: None, Sub, Up, Average, Paeth)
- When PNG predictors are used, each row of data is preceded by a filter-type byte; the filter decoder shall apply the corresponding PNG reconstruction filter
- The filter decoder shall use `Columns`, `Colors`, and `BitsPerComponent` from `DecodeParms` to determine row width for predictor calculations

### Requirement 5: LZWDecode Filter
The filter decoder shall decode LZWDecode streams per §7.4.4.

#### Acceptance Criteria
- The filter decoder shall implement the LZW decompression algorithm with variable-length codes starting at 9 bits
- The filter decoder shall recognize the clear-table code (256) and EOD code (257)
- The filter decoder shall increase code length when the code table exceeds the current bit width capacity
- The filter decoder shall apply the same predictor functions as FlateDecode when `DecodeParms` specifies a `Predictor` value
- The filter decoder shall support the `EarlyChange` parameter (default 1) controlling when code length increases

### Requirement 6: RunLengthDecode Filter
The filter decoder shall decode RunLengthDecode streams per §7.4.5.

#### Acceptance Criteria
- When the length byte is in the range 0 to 127, the filter decoder shall copy the next (length + 1) bytes literally
- When the length byte is in the range 129 to 255, the filter decoder shall replicate the next single byte (257 - length) times
- When the length byte is 128, the filter decoder shall treat it as the end-of-data (EOD) marker

### Requirement 7: Unsupported Filter Handling
The filter decoder shall gracefully handle filters that are not implemented in this phase.

#### Acceptance Criteria
- For CCITTFaxDecode, JBIG2Decode, DCTDecode, JPXDecode, and Crypt filters, the filter decoder shall return a descriptive error indicating the filter is not yet supported
- The error shall include the filter name so that callers can identify which filter caused the failure
- The filter decoder shall not silently skip unsupported filters or return corrupted data

### Requirement 8: Integration with File Structure Reader
The filter decoder shall integrate with the existing `pdf-file-structure` reader to decode compressed streams on demand.

#### Acceptance Criteria
- The filter decoder shall be callable from the reader's object stream decoding path to decode FlateDecode-compressed object streams
- The filter decoder shall be callable from the reader's cross-reference stream decoding path to decode FlateDecode-compressed xref streams
- The filter decoder shall accept the stream dictionary and raw stream bytes as input and return decoded bytes
- When a filter chain fails, the error shall propagate to the caller with the filter name and failure reason
