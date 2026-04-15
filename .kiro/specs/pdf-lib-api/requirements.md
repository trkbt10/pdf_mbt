# SDD Draft: PDF Library Public API

## Requirements

### Requirement 1: High-level document access
The library SHALL provide a single-import public API package (`trkbt10/pdf`)
that re-exports the essential types and functions for opening and inspecting
PDF documents without requiring users to import internal subpackages.

#### 1.1: Document opening
`Pdf::open(bytes : Bytes) -> PdfDocument` SHALL open a PDF from raw bytes,
returning a document handle for page access, metadata queries, and
structure traversal. Errors SHALL be reported via `PdfError` suberror.

#### 1.2: Page iteration
`PdfDocument::pages() -> Array[PdfPage]` and `PdfDocument::page(index)`
SHALL provide indexed and enumerated access to document pages.
`PdfDocument::page_count() -> Int` SHALL return the total page count.

### Requirement 2: Text extraction API
The library SHALL provide a page-level text extraction API that returns
Unicode text from any page without requiring the caller to understand
fonts, encodings, or content stream operators.

#### 2.1: Simple text extraction
`PdfPage::extract_text() -> String` SHALL return the concatenated Unicode
text content of the page. This is the primary entry point for text-only
consumers (equivalent to `pdftotext` output for a single page).

#### 2.2: Structured text extraction
`PdfPage::text_spans() -> Array[TextSpan]` SHALL return text spans with
positional metadata (text matrix, font name) for layout-aware consumers.

#### 2.3: Document-level text extraction
`PdfDocument::extract_all_text() -> String` SHALL concatenate text from
all pages, separated by page breaks (`\f`), for whole-document text
extraction.

### Requirement 3: Image extraction API
The library SHALL provide a page-level image extraction API that returns
decoded pixel data from image XObjects.

#### 3.1: Page image enumeration
`PdfPage::images() -> Array[PdfImage]` SHALL enumerate all image XObjects
referenced by the page content. Each `PdfImage` SHALL expose width, height,
bits per component, and colour space information.

#### 3.2: Image pixel access
`PdfImage::to_rgba() -> Bytes` SHALL return the image as RGBA pixel data
(4 bytes per pixel, row-major). For JPEG-compressed images, DCTDecode SHALL
be applied automatically. For unsupported filters, an error SHALL be raised.

#### 3.3: Image metadata
`PdfImage::width() -> Int`, `PdfImage::height() -> Int`,
`PdfImage::color_space() -> String` SHALL expose image properties without
requiring pixel decoding.

### Requirement 4: Document metadata API
The library SHALL expose document-level metadata.

#### 4.1: Document info dictionary
`PdfDocument::title() -> String?`, `PdfDocument::author() -> String?`,
`PdfDocument::subject() -> String?`, `PdfDocument::creator() -> String?`
SHALL return Info dictionary entries when present.

#### 4.2: PDF version
`PdfDocument::version() -> (Int, Int)` SHALL return the (major, minor)
PDF version from the file header.

#### 4.3: Page geometry
`PdfPage::media_box() -> (Double, Double, Double, Double)` SHALL return
the page MediaBox as (left, bottom, right, top).
`PdfPage::width() -> Double` and `PdfPage::height() -> Double` SHALL
return the effective page dimensions after rotation.

### Requirement 5: Outline (bookmarks) API
The library SHALL expose the document outline for table-of-contents access.

#### 5.1: Outline tree
`PdfDocument::outline() -> Array[OutlineItem]` SHALL return the flattened
or hierarchical outline. Each item SHALL expose title, destination page
index, and nesting level.

### Requirement 6: Capability introspection
The library SHALL allow callers to query what features a specific PDF uses
and whether the library can handle them, rather than failing silently.

#### 6.1: Document capability report
`PdfDocument::check() -> PdfCapabilityReport` SHALL analyze the document
and return a structured report of used features and their support status:
- Each entry SHALL have: feature name, category (filter, font, encryption,
  interactive), status (supported, partial, unsupported), and a human-readable
  description.

#### 6.2: Page-level warnings
`PdfPage::extract_text_with_warnings() -> (String, Array[PdfWarning])`
SHALL extract text AND collect non-fatal warnings (unsupported font type,
missing ToUnicode, unknown operator, etc.) instead of raising errors.
This allows partial results with visibility into what was skipped.

#### 6.3: Image extraction with warnings
`PdfPage::images_with_warnings() -> (Array[PdfImage], Array[PdfWarning])`
SHALL enumerate images and collect warnings for images that could not be
fully decoded (unsupported filter, unsupported colour space, etc.).

### Requirement 7: Structured text helper function
The library SHALL expose `text_spans(page : PdfPage) -> Array[TextSpan]` as a
top-level helper equivalent to `PdfPage::text_spans()` for callers that prefer
function-style access. It SHALL return the same text spans with positional
metadata, text matrix, and font name.

### Requirement 8: Public page facade type
The library SHALL expose `PdfPage` as the public page handle returned by
`PdfDocument::pages()` and `PdfDocument::page(index)`. `PdfPage` SHALL be the
page-level entry point for text extraction, image extraction, page geometry,
and warning-producing extraction APIs.

### Requirement 9: Reader page bridge
The library SHALL expose `PdfPage::reader_page() -> reader.PdfPage` for
advanced callers that need to bridge from the high-level `trkbt10/pdf` API to
the internal reader page while keeping normal page access available from the
single-import package.

### Requirement 10: PdfImage public image facade type
The library SHALL expose `PdfImage` as the public image XObject handle returned
by `PdfPage::images()` and `page_images(page)`. `PdfImage` SHALL carry image
metadata needed by image extraction consumers: width, height, bits per
component, colour space, and decoded or encoded sample data.

### Requirement 11: Image RGBA conversion method
`PdfImage::to_rgba() -> Bytes` SHALL be the image pixel access method for RGBA
conversion. It SHALL return four bytes per pixel in row-major order when the
image can be decoded and SHALL make unsupported encoded data visible through
warning-producing image extraction.

### Requirement 12: Image width method
`PdfImage::width() -> Int` SHALL expose image width without requiring pixel
decoding.

### Requirement 13: Image height method
`PdfImage::height() -> Int` SHALL expose image height without requiring pixel
decoding.

### Requirement 14: Image colour space method
`PdfImage::color_space() -> String` SHALL expose image colour space information
without requiring pixel decoding.

### Requirement 15: Public outline item type
The library SHALL expose `OutlineItem` as the public bookmark item type
returned by `PdfDocument::outline()`. Each `OutlineItem` SHALL expose title,
destination page index, and nesting level for table-of-contents access.

### Requirement 16: Document subject helper function
The library SHALL expose `document_subject(doc : PdfDocument) -> String?` as a
top-level helper equivalent to `PdfDocument::subject()` for Info dictionary
Subject metadata.

### Requirement 17: Page width helper function
The library SHALL expose `page_width(page : PdfPage) -> Double` as a top-level
helper equivalent to `PdfPage::width()` for effective page width after
rotation, using MediaBox dimensions.

### Requirement 18: Page height helper function
The library SHALL expose `page_height(page : PdfPage) -> Double` as a
top-level helper equivalent to `PdfPage::height()` for effective page height
after rotation, using MediaBox dimensions.

### Requirement 19: Page width method
`PdfPage::width() -> Double` SHALL return the effective page width after page
rotation, using MediaBox dimensions.

### Requirement 20: Page height method
`PdfPage::height() -> Double` SHALL return the effective page height after page
rotation, using MediaBox dimensions.

### Requirement 21: Capability status type
The library SHALL expose `PdfCapabilityStatus` for capability introspection.
It SHALL represent supported, partial, unsupported, and unused statuses used by
`PdfDocument::check()` entries.

### Requirement 22: Warning type
The library SHALL expose `PdfWarning` for page-level warnings. Each warning
SHALL identify the feature name, category, and description for non-fatal
conditions such as unsupported font type, missing ToUnicode, unknown operator,
unsupported filter, or unsupported colour space.

### Requirement 23: Document check method
`PdfDocument::check() -> PdfCapabilityReport` SHALL be the document-level
capability introspection method. It SHALL report used PDF features and whether
the library status is supported, partial, unsupported, or unused.

### Requirement 24: Image extraction with warnings method
`PdfPage::images_with_warnings() -> (Array[PdfImage], Array[PdfWarning])`
SHALL enumerate image XObjects and collect warnings for images that could not
be fully decoded because of unsupported filters or unsupported colour spaces.
