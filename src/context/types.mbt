///|
/// Mutable intermediate representation for a PDF document. The object store is
/// keyed by indirect object number; generation numbers are tracked separately
/// for serialization and parsed-document roundtrips.
pub struct PdfContext {
  objects : Map[Int, @objects.PdfObject]
  generations : Map[Int, Int]
  dirty_objects : Map[Int, Bool]
  catalog_ref : @objects.ObjectId
  pages_ref : @objects.ObjectId
  page_tree_refs : Array[@objects.ObjectId]
  mut info_ref : @objects.ObjectId?
  mut version : @reader.PdfVersion
  mut next_object_number : Int
  mut compress_streams : Bool
  file_id : PdfContextFileId?
}

///|
/// PdfContext as mutable document model: reports how many indirect objects are
/// currently held in the mutable object store.
pub fn PdfContext::object_count(self : PdfContext) -> Int {
  let mut count = 0
  for entry in self.objects.to_array() {
    entry |> ignore
    count += 1
  }
  count
}

///|
/// Page manipulation: reports the number of leaf Page objects addressable
/// through the mutable context page tree.
pub fn PdfContext::page_count(self : PdfContext) -> Int raise PdfContextError {
  let refs = self.page_refs()
  let mut count = 0
  for page_ref in refs {
    page_ref |> ignore
    count += 1
  }
  count
}

///|
pub(all) struct PdfContextFileId {
  first : Bytes
  second : Bytes
} derive(Eq, Debug)

///|
pub(all) suberror PdfContextError {
  ReaderError(@reader.PdfReaderError)
  DocumentError(@reader.PdfDocumentError)
  MissingObject(@objects.ObjectId)
  InvalidObject(@objects.ObjectId, String)
  PageIndexOutOfRange(Int, Int)
  InvalidPageReference(@objects.ObjectId, String)
} derive(Eq, Debug)

///|
/// Page manipulation location for PdfContext page-level operations.
priv struct ContextPageLocation {
  page_ref : @objects.ObjectId
  parent_ref : @objects.ObjectId
}
