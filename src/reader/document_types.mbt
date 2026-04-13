///|
/// Public facade for ISO 32000-2 document-structure access backed by
/// pdf-file-structure and pdf-filters. It resolves the trailer Root Catalog,
/// keeps the root Pages node internal, and lazily enumerates page objects from
/// the page tree when page count or index access is first requested.
///
/// The public surface tracks the vocabulary in
/// spec/extracted/7.7-document-structure.spec.txt and sample validation for
/// spec/pdf20examples/Simple PDF 2.0 file.pdf.
pub struct PdfDocument {
  priv file : PdfFile
  priv catalog : PdfCatalog
  priv mut page_index : PageTreeIndex?
}

///|
/// Validated Catalog dictionary resolved from the trailer Root reference. The
/// Catalog Type is checked as Catalog, the required Pages indirect reference
/// points to the root page tree node, and optional entries such as PageLabels,
/// Names, Outlines, Metadata, MarkInfo, StructTreeRoot, and Lang remain
/// available through dictionary access.
pub struct PdfCatalog {
  object_id : @objects.ObjectId
  dict : @objects.PdfDictionary
  pages_ref : @objects.ObjectId
} derive(Eq, Debug)

///|
/// Public Page object handle. It exposes page entries such as MediaBox,
/// CropBox, Resources, Contents, Rotate, UserUnit, Annots, and Parent, and it
/// carries the ancestor Pages path used for page attribute inheritance.
pub struct PdfPage {
  priv file : PdfFile
  priv record : PageTreeRecord
}

///|
/// Four-number page rectangle normalized from MediaBox or CropBox arrays.
pub(all) struct PdfRectangle {
  left : Double
  bottom : Double
  right : Double
  top : Double
} derive(Eq, Debug)

///|
/// Known Catalog name-tree categories required by the Names dictionary:
/// Dests, AP, JavaScript, Pages, Templates, EmbeddedFiles, and
/// AlternatePresentations.
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
