# SDD Draft: PDF Context — Mutable Intermediate Representation

The PDF pipeline SHALL have a three-layer architecture:

```
Parser (reader) → PdfContext (mutable IR) → Builder (writer)
```

`PdfContext` is the mutable intermediate representation that captures
the full state of a PDF document. It is the single authoritative model
that both the parser produces and the builder consumes.

## Requirements

### Requirement 1: PdfContext as mutable document model
The library SHALL provide `PdfContext` as a mutable struct that represents
the complete state of a PDF document, independent of serialization format.

#### 1.1: Object store
PdfContext SHALL contain a mutable object store that maps object IDs to
PdfObject values. Any indirect object in the document SHALL be accessible
and modifiable through this store.

#### 1.2: Document structure
PdfContext SHALL maintain the document structure: catalog reference,
page tree, metadata, and trailer information. These SHALL be accessible
as typed views over the object store, not separate copies.

#### 1.3: Construction from scratch
`PdfContext::new()` SHALL create an empty context with a minimal valid
structure (catalog + empty page tree). Pages, fonts, and content can
then be added incrementally.

#### 1.4: Construction from parsed document
`PdfContext::from_document(doc : PdfDocument)` SHALL populate the
context from a parsed PDF, copying all indirect objects into the
mutable store. After construction, the context is independent of
the original byte source.

### Requirement 2: Page manipulation
PdfContext SHALL support page-level operations.

#### 2.1: Add page
`PdfContext::add_page(width, height)` SHALL append a new blank page
with the given MediaBox dimensions and return a page reference for
further operations (adding content, resources).

#### 2.2: Remove page
`PdfContext::remove_page(index)` SHALL remove a page from the page tree.

#### 2.3: Page content
`PdfContext::set_page_content(page_ref, content_bytes)` SHALL set or
replace the content stream for a page.

### Requirement 3: Metadata manipulation
PdfContext SHALL support document metadata operations.

#### 3.1: Info dictionary
`PdfContext::set_title(title)`, `set_author(author)`, etc. SHALL
modify the document Info dictionary entries.

#### 3.2: Version
`PdfContext::set_version(major, minor)` SHALL set the PDF version.

### Requirement 4: Resource management
PdfContext SHALL manage page resources.

#### 4.1: Add font
`PdfContext::add_font(page_ref, name, font_object)` SHALL register
a font resource on a page.

#### 4.2: Add image
`PdfContext::add_image(page_ref, name, image_stream)` SHALL register
an image XObject resource on a page.

### Requirement 5: Serialization (Builder)
PdfContext SHALL serialize to valid PDF bytes.

#### 5.1: Full serialization
`PdfContext::to_bytes()` SHALL produce a complete, valid PDF file
from the current state: header, all objects, xref, trailer.

#### 5.2: Incremental serialization
`PdfContext::to_incremental_bytes(original)` SHALL produce an
incremental update appended to the original PDF bytes, writing
only modified/added objects.

#### 5.3: Stream compression
Serialization SHALL optionally compress stream data using FlateDecode.

### Requirement 6: Roundtrip fidelity
The parser → context → builder pipeline SHALL preserve document
structure.

#### 6.1: Roundtrip test
For any PDF that can be parsed: `parse → PdfContext::from_document →
to_bytes → parse again` SHALL produce a document with the same page
count, text content, and object structure.

#### 6.2: Edit roundtrip
`parse → context → modify → to_bytes → parse` SHALL reflect the
modifications in the re-parsed document.

### Requirement 7: Refactor existing writer
The existing `src/writer/` code (serializer, xref, document, content,
incremental) SHALL be refactored to operate on PdfContext rather than
standalone functions. The public API surface SHALL change from
`create_pdf(content_bytes)` to `PdfContext::new() → add pages →
to_bytes()`.
