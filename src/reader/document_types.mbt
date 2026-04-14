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
pub(all) enum PdfAnnotationTabOrder {
  Row
  Column
  Structure
  AnnotationArray
  Widget
  Unknown(@objects.PdfName)
} derive(Eq, Debug)

///|
pub(all) enum PdfAnnotationSubtype {
  Text
  Link
  FreeText
  Line
  Square
  Circle
  Polygon
  PolyLine
  Highlight
  Underline
  Squiggly
  StrikeOut
  Caret
  Stamp
  Ink
  Popup
  FileAttachment
  Sound
  Movie
  Screen
  Widget
  PrinterMark
  TrapNet
  Watermark
  Redact
  Projection
  ThreeD
  RichMedia
  Unknown(@objects.PdfName)
} derive(Eq, Debug)

///|
pub(all) struct PdfAnnotation {
  page_index : Int
  array_index : Int
  object_id : @objects.ObjectId?
  common : PdfAnnotationCommon
  markup : PdfMarkupAnnotation?
  specific : PdfAnnotationSpecific
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
pub(all) struct PdfAnnotationCommon {
  subtype : PdfAnnotationSubtype
  subtype_name : @objects.PdfName
  rect : PdfRectangle
  contents : Bytes?
  page_ref : @objects.ObjectId?
  name : Bytes?
  modified : @objects.PdfObject?
  flags : PdfAnnotationFlags
  appearance : PdfAnnotationAppearance?
  appearance_state : @objects.PdfName?
  border : PdfAnnotationBorder
  color : Array[Double]
  struct_parent : Int?
  optional_content : @objects.PdfObject?
  associated_files : Array[@objects.PdfObject]
  nonstroking_opacity : Double
  stroking_opacity : Double
  blend_mode : @objects.PdfName?
  language : Bytes?
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
pub(all) struct PdfAnnotationFlags {
  bits : Int
} derive(Eq, Debug)

///|
pub(all) struct PdfAnnotationBorder {
  horizontal_corner_radius : Double
  vertical_corner_radius : Double
  width : Double
  dash_pattern : Array[Double]
  style : PdfBorderStyle
  effect : PdfBorderEffect?
  raw_border : @objects.PdfObject?
  raw_style : @objects.PdfDictionary?
} derive(Eq, Debug)

///|
pub(all) enum PdfBorderStyle {
  Solid
  Dashed
  Beveled
  Inset
  Underline
  Unknown(@objects.PdfName)
} derive(Eq, Debug)

///|
pub(all) enum PdfBorderEffectStyle {
  None
  Cloudy
  Unknown(@objects.PdfName)
} derive(Eq, Debug)

///|
pub(all) struct PdfBorderEffect {
  style : PdfBorderEffectStyle
  intensity : Double
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
pub(all) struct PdfAnnotationAppearance {
  normal : PdfAppearanceEntry
  rollover : PdfAppearanceEntry
  down : PdfAppearanceEntry
  selected_state : @objects.PdfName?
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
pub(all) enum PdfAppearanceEntry {
  Stream(@objects.PdfStream)
  StateMap(@objects.PdfDictionary)
  Raw(@objects.PdfObject)
} derive(Eq, Debug)

///|
pub(all) struct PdfPoint {
  x : Double
  y : Double
} derive(Eq, Debug)

///|
pub(all) struct PdfQuadPoints {
  points : Array[PdfPoint]
} derive(Eq, Debug)

///|
pub(all) struct PdfAnnotationPath {
  points : Array[PdfPoint]
} derive(Eq, Debug)

///|
pub(all) struct PdfAnnotationCallout {
  points : Array[PdfPoint]
} derive(Eq, Debug)

///|
pub(all) struct PdfLineCoordinates {
  start : PdfPoint
  end : PdfPoint
} derive(Eq, Debug)

///|
pub(all) enum PdfLineEndingStyle {
  Square
  Circle
  Diamond
  OpenArrow
  ClosedArrow
  None
  Butt
  ROpenArrow
  RClosedArrow
  Slash
  Unknown(@objects.PdfName)
} derive(Eq, Debug)

///|
pub(all) enum PdfHighlightMode {
  None
  Invert
  Outline
  Push
  Unknown(@objects.PdfName)
} derive(Eq, Debug)

///|
pub(all) enum PdfJustification {
  Left
  Center
  Right
  Unknown(Int)
} derive(Eq, Debug)

///|
pub(all) enum PdfAnnotationStateModel {
  Marked
  Review
  Unknown(@objects.PdfName)
} derive(Eq, Debug)

///|
pub(all) enum PdfAnnotationState {
  Marked
  Unmarked
  Accepted
  Rejected
  Cancelled
  Completed
  None
  Unknown(@objects.PdfName)
} derive(Eq, Debug)

///|
pub(all) struct PdfMarkupExternalData {
  subtype : @objects.PdfName?
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
pub(all) struct PdfMarkupAnnotation {
  title : Bytes?
  popup : @objects.PdfObject?
  rich_contents : Bytes?
  creation_date : @objects.PdfObject?
  in_reply_to : @objects.PdfObject?
  reply_type : @objects.PdfName?
  subject : Bytes?
  intent : @objects.PdfName?
  external_data : PdfMarkupExternalData?
  state : PdfAnnotationState?
  state_model : PdfAnnotationStateModel?
} derive(Eq, Debug)

///|
pub(all) struct PdfTextAnnotation {
  open : Bool
  icon_name : @objects.PdfName
} derive(Eq, Debug)

///|
pub(all) struct PdfLinkAnnotation {
  action : @objects.PdfObject?
  previous_uri_action : @objects.PdfObject?
  destination : @objects.PdfObject?
  highlight_mode : PdfHighlightMode
  quad_points : Array[PdfQuadPoints]
} derive(Eq, Debug)

///|
pub(all) struct PdfFreeTextAnnotation {
  default_appearance : Bytes
  justification : PdfJustification
  rich_text : Bytes?
  default_style : Bytes?
  callout : PdfAnnotationCallout?
  intent : @objects.PdfName
  border_effect : PdfBorderEffect?
  difference_rectangle : PdfRectangle?
} derive(Eq, Debug)

///|
pub(all) struct PdfLineAnnotation {
  coordinates : PdfLineCoordinates
  line_endings : Array[PdfLineEndingStyle]
  interior_color : Array[Double]
  leader_line_length : Double
  leader_line_extension : Double
  leader_line_offset : Double
  caption : Bool
  intent : @objects.PdfName?
  measure : @objects.PdfObject?
  caption_offset : PdfPoint?
} derive(Eq, Debug)

///|
pub(all) enum PdfShapeKind {
  Square
  Circle
} derive(Eq, Debug)

///|
pub(all) struct PdfShapeAnnotation {
  kind : PdfShapeKind
  interior_color : Array[Double]
  border_effect : PdfBorderEffect?
  difference_rectangle : PdfRectangle?
} derive(Eq, Debug)

///|
pub(all) enum PdfPolygonKind {
  Polygon
  PolyLine
} derive(Eq, Debug)

///|
pub(all) struct PdfPolygonAnnotation {
  kind : PdfPolygonKind
  vertices : Array[PdfPoint]
  path : Array[PdfAnnotationPath]
  line_endings : Array[PdfLineEndingStyle]
  interior_color : Array[Double]
  intent : @objects.PdfName?
  measure : @objects.PdfObject?
} derive(Eq, Debug)

///|
pub(all) enum PdfTextMarkupKind {
  Highlight
  Underline
  Squiggly
  StrikeOut
} derive(Eq, Debug)

///|
pub(all) struct PdfTextMarkupAnnotation {
  kind : PdfTextMarkupKind
  quad_points : Array[PdfQuadPoints]
} derive(Eq, Debug)

///|
pub(all) struct PdfCaretAnnotation {
  difference_rectangle : PdfRectangle?
  symbol : @objects.PdfName
} derive(Eq, Debug)

///|
pub(all) struct PdfStampAnnotation {
  icon_name : @objects.PdfName
  intent : @objects.PdfName
} derive(Eq, Debug)

///|
pub(all) struct PdfInkAnnotation {
  ink_list : Array[PdfAnnotationPath]
  paths : Array[PdfAnnotationPath]
} derive(Eq, Debug)

///|
pub(all) struct PdfPopupAnnotation {
  parent : @objects.PdfObject?
  open : Bool
} derive(Eq, Debug)

///|
pub(all) struct PdfFileAttachmentAnnotation {
  file_specification : @objects.PdfObject
  icon_name : @objects.PdfName
} derive(Eq, Debug)

///|
pub(all) struct PdfSoundAnnotation {
  sound : @objects.PdfObject
  icon_name : @objects.PdfName
} derive(Eq, Debug)

///|
pub(all) struct PdfMovieAnnotation {
  title : Bytes?
  movie : @objects.PdfObject
  activation : @objects.PdfObject?
} derive(Eq, Debug)

///|
pub(all) struct PdfScreenAnnotation {
  title : Bytes?
  action : @objects.PdfObject?
  additional_actions : @objects.PdfObject?
  appearance_characteristics : PdfWidgetAppearanceCharacteristics?
} derive(Eq, Debug)

///|
pub(all) struct PdfWidgetAppearanceCharacteristics {
  rotation : Int
  border_color : Array[Double]
  background_color : Array[Double]
  normal_caption : Bytes?
  rollover_caption : Bytes?
  alternate_caption : Bytes?
  normal_icon : @objects.PdfObject?
  rollover_icon : @objects.PdfObject?
  alternate_icon : @objects.PdfObject?
  icon_fit : @objects.PdfObject?
  text_position : Int
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
pub(all) struct PdfWidgetAnnotation {
  highlight_mode : PdfHighlightMode
  action : @objects.PdfObject?
  additional_actions : @objects.PdfObject?
  border_style : PdfAnnotationBorder
  parent : @objects.PdfObject?
  appearance_characteristics : PdfWidgetAppearanceCharacteristics?
} derive(Eq, Debug)

///|
pub(all) struct PdfPrinterMarkAnnotation {
  production_mark : @objects.PdfObject?
} derive(Eq, Debug)

///|
pub(all) struct PdfTrapNetworkAnnotation {
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
pub(all) struct PdfFixedPrint {
  matrix : Array[Double]
  horizontal_translation : Double
  vertical_translation : Double
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
pub(all) struct PdfWatermarkAnnotation {
  fixed_print : PdfFixedPrint?
} derive(Eq, Debug)

///|
pub(all) struct PdfRedactionAnnotation {
  quad_points : Array[PdfQuadPoints]
  interior_color : Array[Double]
  overlay : @objects.PdfObject?
  overlay_text : Bytes?
  repeat : Bool
  default_appearance : Bytes?
  justification : PdfJustification
} derive(Eq, Debug)

///|
pub(all) struct PdfProjectionAnnotation {
  external_data : PdfMarkupExternalData?
} derive(Eq, Debug)

///|
pub(all) struct PdfRawAnnotation {
  subtype_name : @objects.PdfName
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
pub(all) enum PdfAnnotationSpecific {
  Text(PdfTextAnnotation)
  Link(PdfLinkAnnotation)
  FreeText(PdfFreeTextAnnotation)
  Line(PdfLineAnnotation)
  Shape(PdfShapeAnnotation)
  Polygon(PdfPolygonAnnotation)
  TextMarkup(PdfTextMarkupAnnotation)
  Caret(PdfCaretAnnotation)
  Stamp(PdfStampAnnotation)
  Ink(PdfInkAnnotation)
  Popup(PdfPopupAnnotation)
  FileAttachment(PdfFileAttachmentAnnotation)
  Sound(PdfSoundAnnotation)
  Movie(PdfMovieAnnotation)
  Screen(PdfScreenAnnotation)
  Widget(PdfWidgetAnnotation)
  PrinterMark(PdfPrinterMarkAnnotation)
  TrapNetwork(PdfTrapNetworkAnnotation)
  Watermark(PdfWatermarkAnnotation)
  Redaction(PdfRedactionAnnotation)
  Projection(PdfProjectionAnnotation)
  ThreeDRaw(PdfRawAnnotation)
  RichMediaRaw(PdfRawAnnotation)
  UnknownRaw(PdfRawAnnotation)
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
