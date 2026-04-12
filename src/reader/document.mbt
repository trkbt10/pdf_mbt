///|
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
