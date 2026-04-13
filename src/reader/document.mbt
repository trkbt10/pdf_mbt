///|
/// Opens a PDF file by parsing its structure per ISO 32000-2 section 7.5.
/// Reverse parses the file tail to find the latest `%%EOF` marker and
/// `startxref` keyword (section 7.5.5), resolving the byte offset to the
/// most recent cross-reference section even when incremental updates are
/// present. Then follows the `Prev` chain to merge all cross-reference
/// sections. Validates the file header, trailer dictionary, and produces a
/// merged xref index for random-access object loading.
/// Sample file validation covers Annex H minimal PDF (Catalog, Pages, Page,
/// Content stream, Metadata) and bundled PDF 2.0 examples including
/// incremental save variants.
pub fn PdfFile::open(input : Bytes) -> PdfFile raise PdfReaderError {
  let header = parse_header(input)
  let source = ByteSource::new(input, header.base_offset)
  let latest_startxref = find_latest_startxref(source)
  let sections = read_section_chain(source, latest_startxref, header.version)
  let trailer = sections[0].trailer
  let xref_index = merge_sections(sections)
  PdfFile::{
    bytes: input,
    header,
    trailer,
    sections,
    xref_index,
    cache: Map::new(),
    object_stream_tables: Map::new(),
  }
}

///|
pub fn PdfFile::version(self : PdfFile) -> PdfVersion {
  self.header.version
}

///|
pub fn PdfFile::trailer(self : PdfFile) -> TrailerInfo {
  self.trailer
}

///|
pub fn PdfFile::root_ref(self : PdfFile) -> @objects.ObjectId {
  self.trailer.root
}
