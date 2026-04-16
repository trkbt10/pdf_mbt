///|
/// Roundtrip fidelity bridge: builds PdfContext from a parsed PdfDocument so
/// parser -> context -> builder preserves document structure.
pub fn PdfContext::from_document(
  document : @reader.PdfDocument,
) -> PdfContext raise PdfContextError {
  let file = document.file()
  PdfContext::from_file(file)
}

///|
pub fn PdfContext::from_file(
  file : @reader.PdfFile,
) -> PdfContext raise PdfContextError {
  let trailer = file.trailer()
  let catalog = try file.document() catch {
    error => raise PdfContextError::DocumentError(error)
  } noraise {
    document => document.catalog()
  }
  let context = PdfContext::{
    objects: Map::new(),
    generations: Map::new(),
    dirty_objects: Map::new(),
    catalog_ref: file.root_ref(),
    pages_ref: catalog.pages_ref,
    page_tree_refs: [catalog.pages_ref],
    info_ref: trailer.info,
    version: file.version(),
    next_object_number: 1,
    compress_streams: false,
    file_id: context_file_id(trailer.id),
  }
  for entry in file.xref_index.to_array() {
    let (id, _) = entry
    let object = try file.load_object(id) catch {
      error => raise PdfContextError::ReaderError(error)
    } noraise {
      value => value
    }
    if object != @objects.PdfObject::Null {
      context.store_object(id, clone_object(object), dirty=false)
    }
  }
  context
}

///|
fn context_file_id(id : @reader.PdfFileId?) -> PdfContextFileId? {
  match id {
    Some(value) =>
      Some(PdfContextFileId::{ first: value.first, second: value.second })
    None => Some(default_context_file_id())
  }
}
