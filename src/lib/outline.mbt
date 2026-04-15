///|
/// Implements Requirement 5 outline bookmarks API. `OutlineItem` is the
/// public table-of-contents entry returned by `PdfDocument::outline()`;
/// each item SHALL expose title, destination page index, and nesting level.
pub(all) struct OutlineItem {
  title : String
  destination_page_index : Int?
  level : Int
} derive(Eq, Debug)

///|
/// Returns flattened outline bookmarks from the document outline tree. Items
/// preserve nesting with the `level` field and expose local destination page
/// indexes when an outline item points at a page in this PDF.
pub fn PdfDocument::outline(
  self : PdfDocument,
) -> Array[OutlineItem] raise @reader.PdfDocumentError {
  match self.inner.outline() {
    Some(outline) => {
      let items : Array[OutlineItem] = []
      flatten_outline_items(self, outline.items, 0, items)
      items
    }
    None => []
  }
}

///|
fn flatten_outline_items(
  document : PdfDocument,
  source : Array[@reader.PdfOutlineItem],
  level : Int,
  out : Array[OutlineItem],
) -> Unit raise @reader.PdfDocumentError {
  for item in source {
    out.push(OutlineItem::{
      title: bytes_to_text(item.title),
      destination_page_index: outline_destination_page_index(document, item),
      level,
    })
    flatten_outline_items(document, item.children, level + 1, out)
  }
}

///|
fn outline_destination_page_index(
  document : PdfDocument,
  item : @reader.PdfOutlineItem,
) -> Int? raise @reader.PdfDocumentError {
  match item.destination {
    Some(destination) =>
      match destination.target {
        LocalPage(object_id) =>
          find_page_index_by_object_id(document, object_id)
        RemotePageIndex(index) => Some(index)
        LocalStructure(_, object_id) =>
          match object_id {
            Some(id) => find_page_index_by_object_id(document, id)
            None => None
          }
        RemoteStructureId(_) => None
      }
    None => None
  }
}

///|
fn find_page_index_by_object_id(
  document : PdfDocument,
  object_id : @objects.ObjectId,
) -> Int? raise @reader.PdfDocumentError {
  for page in document.inner.pages() {
    if page.object_id() == object_id {
      return Some(page.index())
    }
  }
  None
}
