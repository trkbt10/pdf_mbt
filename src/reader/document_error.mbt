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
  InvalidNavigation(@objects.PdfName, String)
  InvalidAnnotation(@objects.ObjectId?, String)
  InvalidAction(@objects.ObjectId?, @objects.PdfName?, String)
  InvalidForm(@objects.ObjectId?, String)
  InvalidFDF(@objects.ObjectId?, String)
  InvalidSignature(@objects.ObjectId?, String)
  InvalidMeasure(@objects.ObjectId?, String)
  InvalidRequirement(@objects.ObjectId?, String)
  InvalidMultimedia(@objects.ObjectId?, String)
  InterchangeError(@interchange.PdfInterchangeError)
  ContentError(@content.PdfContentError)
  GraphicsError(@graphics.PdfGraphicsError)
  PageIndexOutOfRange(Int, Int)
  CycleDetected(@objects.ObjectId, String)
} derive(Eq, Debug)
