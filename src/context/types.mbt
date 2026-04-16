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
priv struct ContextPageLocation {
  page_ref : @objects.ObjectId
  parent_ref : @objects.ObjectId
}
