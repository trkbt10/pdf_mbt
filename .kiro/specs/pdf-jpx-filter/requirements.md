# SDD Draft: JPXDecode Filter (JPEG 2000)

Reference: ISO 32000-2 §7.4.9

## Requirements

### Requirement 1: JPXDecode filter integration
The filter pipeline SHALL decode JPXDecode streams by delegating to the
`trkbt10/jpeg2000` package's `decode(data : Bytes) -> ImageData` function.

#### 1.1: Filter name recognition
The filter pipeline SHALL recognize the name `JPXDecode` and route stream
data to the JPEG 2000 decoder instead of returning UnsupportedFilter.

#### 1.2: Raw stream passthrough
JPXDecode streams in PDF carry raw JPEG 2000 codestream data. The filter
SHALL pass the undecoded stream bytes directly to `@jpeg2000.decode()`.

#### 1.3: Decoded sample output
The filter SHALL return the decoded sample bytes from `ImageData.data` in
interleaved component order matching the JPEG 2000 output layout.

#### 1.4: Error mapping
Decode errors from `@jpeg2000.DecodeError` SHALL be mapped to
`PdfFilterError::DecodeError("JPXDecode", reason)` with the original
error description preserved.

### Requirement 2: Image pipeline integration
When `extract_image_xobject` encounters a JPXDecode-filtered image stream,
the image extraction pipeline SHALL use the decoded sample data and the
JPEG 2000 image dimensions (from `ImageData.width`, `ImageData.height`,
`ImageData.num_components`) instead of the PDF dictionary values.

#### 2.1: Component count override
Per §7.4.9, the number of colour components in the JPXDecode data SHALL
override the PDF image dictionary's component count when they differ.
