# SDD Draft: CCITTFaxDecode Filter

Reference: ISO 32000-2 §7.4.6

## Requirements

### Requirement 1: CCITT Group 3 (1D) decoding
The filter SHALL decode CCITTFaxDecode streams using Group 3 one-dimensional
encoding (T.4 / ITU-T Recommendation T.4).

#### 1.1: Huffman code table
The decoder SHALL implement the standard CCITT white and black run-length
Huffman code tables for runs from 0 to 2560+ pixels.

#### 1.2: Make-up codes
The decoder SHALL handle make-up codes for runs longer than 63 pixels
by combining make-up and terminating codes.

#### 1.3: EOL handling
The decoder SHALL recognize end-of-line (EOL) markers and handle both
byte-aligned and non-aligned EOL patterns.

### Requirement 2: CCITT Group 4 (2D) decoding
The filter SHALL decode Group 4 two-dimensional encoding
(T.6 / ITU-T Recommendation T.6).

#### 2.1: Reference line
Group 4 uses a reference line (previous row). The decoder SHALL maintain
the reference line and apply pass, horizontal, and vertical mode codes.

#### 2.2: First row
The first row SHALL use an imaginary all-white reference line.

### Requirement 3: DecodeParms handling
The decoder SHALL respect CCITTFaxDecode parameters from the DecodeParms
dictionary:
- `K`: negative = Group 4, 0 = Group 3 1D, positive = mixed
- `Columns`: image width in pixels (default 1728)
- `Rows`: image height (0 = determine from data)
- `BlackIs1`: if true, 1-bits are black (default false: 0-bits are black)
- `EncodedByteAlign`: if true, each encoded line starts on byte boundary
- `EndOfLine`: if true, EOL markers are expected
- `EndOfBlock`: if true (default), EOFB/RTC marks end of data

### Requirement 4: Output format
The decoded output SHALL be 1 bit per pixel, packed 8 pixels per byte
(MSB first), with rows padded to byte boundaries. This matches the PDF
image sample format for 1-BPC images.
