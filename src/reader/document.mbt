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
  let trailer = resolve_merged_trailer(sections)
  let xref_index = merge_sections(sections)
  let file = PdfFile::{
    bytes: input,
    header,
    trailer,
    sections,
    xref_index,
    encryption: None,
    cache: Map::new(),
    object_stream_tables: Map::new(),
  }
  initialize_encryption(file)
  file
}

///|
/// Returns the parsed PDF header version for the opened file.
pub fn PdfFile::version(self : PdfFile) -> PdfVersion {
  self.header.version
}

///|
/// Returns trailer metadata resolved from the cross-reference chain, including
/// the Root entry used by the document-structure Catalog.
pub fn PdfFile::trailer(self : PdfFile) -> TrailerInfo {
  self.trailer
}

///|
/// Returns the trailer Root indirect reference that identifies the Catalog
/// dictionary for document structure access.
pub fn PdfFile::root_ref(self : PdfFile) -> @objects.ObjectId {
  match self.trailer.root {
    Some(root) => root
    None => abort("opened PdfFile must have a resolved trailer Root")
  }
}

///|
/// Reports whether the latest trailer declares an Encrypt dictionary.
pub fn PdfFile::is_encrypted(self : PdfFile) -> Bool {
  self.trailer.encrypt is Some(_)
}

///|
/// Returns Standard security-handler permission flags, or unrestricted
/// permissions for unencrypted files.
pub fn PdfFile::permissions(self : PdfFile) -> @encryption.DocumentPermissions {
  match self.encryption {
    Some(context) => context.permissions
    None => @encryption.DocumentPermissions::unrestricted()
  }
}
