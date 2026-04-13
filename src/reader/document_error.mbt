///|
/// Document-structure failures are distinct from low-level reader failures so
/// downstream document APIs can report malformed catalog, page tree, page,
/// inheritance, name-tree, page-index, and cycle conditions without altering
/// the file-structure contract.
pub(all) suberror PdfDocumentError {
  ReaderError(PdfReaderError)
  InvalidCatalog(@objects.ObjectId, String)
  InvalidPageTree(@objects.ObjectId, String)
  InvalidPage(@objects.ObjectId, String)
  InvalidInheritedAttribute(@objects.ObjectId, @objects.PdfName, String)
  InvalidNameTree(@objects.PdfName, String)
  ContentError(@content.PdfContentError)
  PageIndexOutOfRange(Int, Int)
  CycleDetected(@objects.ObjectId, String)
} derive(Eq, Debug)
