///|
/// Opens a PDF file by following ISO 32000-2 section 7.5.5: it performs
/// reverse parsing from file end, chooses the last %%EOF in the file as the %%EOF marker,
/// locates the preceding startxref keyword, and parses the byte offset of cross-reference section
/// used for the latest body revision and incremental updates.
///
/// This public entry point also validates the reader contract exercised by
/// ISO 32000-2 Annex H sample coverage: Annex H minimal PDF structure with
/// Catalog, Pages, Content stream, and Metadata objects, plus PDF 2.0 example files
/// that include incremental save data.
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
/// Returns the parsed PDF header version for the opened file.
pub fn PdfFile::version(self : PdfFile) -> PdfVersion {
  self.header.version
}

///|
/// Returns trailer metadata from the latest cross-reference section, including
/// the Root entry used by the document-structure Catalog.
pub fn PdfFile::trailer(self : PdfFile) -> TrailerInfo {
  self.trailer
}

///|
/// Returns the trailer Root indirect reference that identifies the Catalog
/// dictionary for document structure access.
pub fn PdfFile::root_ref(self : PdfFile) -> @objects.ObjectId {
  self.trailer.root
}
