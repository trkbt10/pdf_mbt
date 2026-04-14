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
/// Ordered entry returned by Catalog name-tree enumeration. Keys are preserved
/// as exact PDF byte strings and values remain raw until the consuming
/// navigation parser owns their interpretation.
pub(all) struct PdfNameTreeEntry {
  key : Bytes
  value : @objects.PdfObject
} derive(Eq, Debug)

///|
/// Entry returned by number-tree traversal. Number trees are used by
/// PageLabels and are kept package-generic so additional reader consumers can
/// reuse the same bounded traversal policy.
pub(all) struct PdfNumberTreeEntry {
  key : Int
  value : @objects.PdfObject
} derive(Eq, Debug)

///|
/// Viewer presentation mode names shared by Catalog OpenAction and viewer
/// preferences. Unknown names are preserved where ISO defines extensible
/// behavior.
pub(all) enum PdfPageMode {
  UseNone
  UseOutlines
  UseThumbs
  FullScreen
  UseOC
  UseAttachments
  Unknown(@objects.PdfName)
} derive(Eq, Debug)

///|
pub(all) enum PdfReadingDirection {
  LeftToRight
  RightToLeft
} derive(Eq, Debug)

///|
pub(all) enum PdfPageBoundary {
  MediaBox
  CropBox
  BleedBox
  TrimBox
  ArtBox
  Unknown(@objects.PdfName)
} derive(Eq, Debug)

///|
pub(all) enum PdfPrintScaling {
  None
  AppDefault
} derive(Eq, Debug)

///|
pub(all) enum PdfDuplex {
  Simplex
  DuplexFlipShortEdge
  DuplexFlipLongEdge
} derive(Eq, Debug)

///|
pub(all) enum PdfViewerPreferenceEnforceName {
  PrintScaling
  Duplex
  PickTrayByPDFSize
  PrintPageRange
  NumCopies
  Unknown(@objects.PdfName)
} derive(Eq, Debug)

///|
pub(all) struct PdfPageRange {
  first : Int
  last : Int
} derive(Eq, Debug)

///|
/// Typed ViewerPreferences dictionary with ISO defaults for absent booleans
/// and boundary names. Implementation-dependent entries remain optional data;
/// no viewer behavior is executed.
pub(all) struct PdfViewerPreferences {
  hide_toolbar : Bool
  hide_menubar : Bool
  hide_window_ui : Bool
  fit_window : Bool
  center_window : Bool
  display_doc_title : Bool
  non_full_screen_page_mode : PdfPageMode
  direction : PdfReadingDirection
  view_area : PdfPageBoundary
  view_clip : PdfPageBoundary
  print_area : PdfPageBoundary
  print_clip : PdfPageBoundary
  print_scaling : PdfPrintScaling
  duplex : PdfDuplex?
  pick_tray_by_pdf_size : Bool
  print_page_ranges : Array[PdfPageRange]
  num_copies : Int?
  enforce : Array[PdfViewerPreferenceEnforceName]
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
pub(all) enum PdfDestinationTarget {
  LocalPage(@objects.ObjectId)
  LocalStructure(@objects.PdfObject, @objects.ObjectId?)
  RemotePageIndex(Int)
  RemoteStructureId(Bytes)
} derive(Eq, Debug)

///|
pub(all) enum PdfDestinationView {
  XYZ(Double?, Double?, Double?)
  Fit
  FitH(Double?)
  FitV(Double?)
  FitR(Double, Double, Double, Double)
  FitB
  FitBH(Double?)
  FitBV(Double?)
  Unknown(@objects.PdfName, Array[@objects.PdfObject])
} derive(Eq, Debug)

///|
pub(all) struct PdfDestination {
  target : PdfDestinationTarget
  view : PdfDestinationView
  raw_array : Array[@objects.PdfObject]
  raw_attributes : @objects.PdfDictionary?
} derive(Eq, Debug)

///|
pub(all) struct PdfNamedDestination {
  name : Bytes
  destination : PdfDestination
  raw_value : @objects.PdfObject
} derive(Eq, Debug)

///|
pub(all) struct PdfOutline {
  count : Int?
  items : Array[PdfOutlineItem]
} derive(Eq, Debug)

///|
pub(all) struct PdfOutlineItem {
  title : Bytes
  count : Int?
  color : Array[Double]
  italic : Bool
  bold : Bool
  destination : PdfDestination?
  action : @objects.PdfObject?
  structure_element : @objects.PdfObject?
  children : Array[PdfOutlineItem]
} derive(Eq, Debug)

///|
pub(all) enum PdfThumbnailColorSpace {
  DeviceGray
  DeviceRGB
  DeviceCMYK
  Indexed
  Other(@objects.PdfObject)
  Absent
} derive(Eq, Debug)

///|
pub(all) struct PdfThumbnail {
  page_index : Int
  width : Int
  height : Int
  color_space : PdfThumbnailColorSpace
  bits_per_component : Int?
  decode : @objects.PdfObject?
  raw_stream : @objects.PdfStream
} derive(Eq, Debug)

///|
pub(all) enum PdfCollectionView {
  Details
  Tile
  Hidden
  Custom(@objects.PdfName)
} derive(Eq, Debug)

///|
pub(all) struct PdfCollectionSchemaField {
  key : @objects.PdfName
  subtype : @objects.PdfName?
  name : Bytes?
  order : Int?
  visible : Bool
  editable : Bool
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
pub(all) struct PdfCollectionSort {
  keys : Array[@objects.PdfName]
  ascending : Array[Bool]
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
pub(all) struct PdfCollectionFile {
  name : Bytes
  file_spec : @objects.PdfObject
  folder_id : Int?
} derive(Eq, Debug)

///|
pub(all) struct PdfCollectionFolder {
  id : Int
  name : Bytes
  parent_id : Int?
  children : Array[PdfCollectionFolder]
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
pub(all) struct PdfNavigator {
  layout : @objects.PdfName
  fallback_layouts : Array[@objects.PdfName]
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
pub(all) struct PdfCollection {
  schema : Array[PdfCollectionSchemaField]
  initial_document : Bytes?
  view : PdfCollectionView
  sort : PdfCollectionSort?
  colors : Array[Double]
  files : Array[PdfCollectionFile]
  folders : Array[PdfCollectionFolder]
  navigator : PdfNavigator?
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
pub(all) enum PdfPageLabelStyle {
  Decimal
  UpperRoman
  LowerRoman
  UpperLetters
  LowerLetters
  PrefixOnly
} derive(Eq, Debug)

///|
pub(all) struct PdfPageLabelRange {
  start_index : Int
  style : PdfPageLabelStyle
  prefix : Bytes
  start_number : Int
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
pub(all) struct PdfPageLabel {
  page_index : Int
  label : Bytes
  range_start : Int
} derive(Eq, Debug)

///|
pub(all) struct PdfArticleThread {
  info : @objects.PdfDictionary?
  metadata : @objects.PdfObject?
  beads : Array[PdfArticleBead]
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
pub(all) struct PdfArticleBead {
  page_index : Int?
  page_ref : @objects.ObjectId?
  rectangle : PdfRectangle?
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
pub(all) enum PdfTransitionStyle {
  Split
  Blinds
  Box
  Wipe
  Dissolve
  Glitter
  R
  Fly
  Push
  Cover
  Uncover
  Fade
  Unknown(@objects.PdfName)
} derive(Eq, Debug)

///|
pub(all) struct PdfTransition {
  style : PdfTransitionStyle
  duration : Double
  dimension : @objects.PdfName?
  motion : @objects.PdfName?
  direction : Double?
  scale : Double?
  opaque_area : Bool
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
pub(all) struct PdfPresentation {
  duration : Double?
  transition : PdfTransition?
} derive(Eq, Debug)

///|
pub(all) struct PdfNavigationNode {
  forward_action : @objects.PdfObject?
  backward_action : @objects.PdfObject?
  raw_dict : @objects.PdfDictionary
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
