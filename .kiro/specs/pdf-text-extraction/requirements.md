# SDD Draft: PDF Text Extraction Integration

## Requirements

### Requirement 1: TextResources and interpret_text for Simple PDF
The text package SHALL use text resources to extract Unicode text from a
standard PDF page containing simple font references and show-string operators.

#### 1.1: Font resource materialization
PdfPage::text_resources SHALL resolve indirect font references from the
page Resources dictionary, materializing Encoding, ToUnicode, and
FontDescriptor entries for each font used by the page content streams.

#### 1.2: Content stream decoding and concatenation
When a page has multiple content streams (Contents array), the library
SHALL decode each stream via the filter pipeline (FlateDecode, etc.) and
concatenate the decoded bytes before parsing content instructions.

#### 1.3: Text operator interpretation
The text interpreter SHALL process BT/ET text objects, Tf (set font),
Td/TD (move position), Tj (show string), and TJ (show adjusted string)
operators, maintaining text matrix and text state across operators.

#### 1.4: Simple font character code to Unicode mapping
For simple fonts (Type1, TrueType), each byte of a show-string operand
SHALL be decoded as a character code. The code SHALL be mapped to a glyph
name via the font Encoding (StandardEncoding if absent), then the glyph
name SHALL be mapped to Unicode via the Adobe Glyph List or ToUnicode CMap.

### Requirement 2: TextState and TextMatrix for incremental-save text
The text package SHALL keep text extraction independent of reader object
revision handling by interpreting the resolved content stream with
`TextState`, `TextObjectState`, `TextMatrix`, `TextRenderingMatrix`,
`TextSourceString`, and `TextSpan`.

#### 2.1: Incremental update resolution
The reader SHALL follow the chain of cross-reference sections and trailers,
resolving each indirect object to its latest revision. Deleted objects
(free entries) SHALL resolve to Null.

### Requirement 3: Text extraction from CalRGB colour-space PDF
The library SHALL extract text from "PDF image with BPC.pdf".
Expected text includes "This text is in a Calibrated RGB (CalRGB) colorspace".

### Requirement 4: Text extraction from UTF-8 annotated PDF
The library SHALL extract text from "pdf20-utf8-test.pdf".
Expected text includes "PDF 2.0 with UTF-8 test file" and "Heading Level 2".

### Requirement 5: Text extraction with offset start
The library SHALL extract text from "PDF 2.0 with offset start.pdf"
where the PDF header does not begin at byte 0. Expected text includes
"This is a PDF 2.0 document".

### Requirement 6: Multi-page text extraction
The library SHALL extract text from each page independently via
`PdfPage::extracted_text`. For multi-page documents like
"PDF 2.0 with page level output intent.pdf", text from page N SHALL
only contain content from page N, not from other pages.
