///|
/// Public facade placeholder for document-structure access. The concrete
/// fields are introduced by later tasks when the reader facade is wired up.
pub struct PdfDocument {}

///|
/// Validated Catalog state resolved from the trailer root reference.
pub struct PdfCatalog {
  object_id : @objects.ObjectId
  dict : @objects.PdfDictionary
  pages_ref : @objects.ObjectId
} derive(Eq, Debug)

///|
/// Public page handle placeholder for later page access methods.
pub struct PdfPage {}

///|
/// Four-number page rectangle normalized from page-box arrays.
pub(all) struct PdfRectangle {
  left : Double
  bottom : Double
  right : Double
  top : Double
} derive(Eq, Debug)

///|
/// Known catalog name-tree categories required by this spec.
pub(all) enum NameTreeCategory {
  Dests
  AP
  JavaScript
  Pages
  Templates
  EmbeddedFiles
  AlternatePresentations
} derive(Eq, Debug)

///|
/// Internal page-tree record carrying the validated leaf page, its location,
/// and ancestry used by later traversal and inheritance logic.
struct PageTreeRecord {
  object_id : @objects.ObjectId
  dict : @objects.PdfDictionary
  index : Int
  parent_ref : @objects.ObjectId?
  ancestor_refs : Array[@objects.ObjectId]
} derive(Eq, Debug)

///|
/// Internal page-tree cache that stores the complete leaf-page order.
struct PageTreeIndex {
  pages : Array[PageTreeRecord]
} derive(Eq, Debug)
