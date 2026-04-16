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
/// Reader-facing Standard security-handler permission bits from the Encrypt
/// dictionary. Unencrypted documents report unrestricted permissions.
pub type PdfPermissions = @encryption.DocumentPermissions

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
/// Page Tabs annotation navigation order from ISO 32000-2 12.5.1
/// "General". Row (R), column (C), structure (S), annotation array (A),
/// and widget (W) order are exposed as structure only; this reader does not
/// compute keyboard focus traversal.
pub(all) enum PdfAnnotationTabOrder {
  Row
  Column
  Structure
  AnnotationArray
  Widget
  Unknown(@objects.PdfName)
} derive(Eq, Debug)

///|
/// Standard annotation types from ISO 32000-2 12.5.6.1 "General" and
/// Table 171 "Annotation types". Values mirror annotation dictionary Subtype
/// names: Text, Link, FreeText, Line, Square, Circle, Polygon, PolyLine,
/// Highlight, Underline, Squiggly, StrikeOut, Caret, Stamp, Ink, Popup,
/// FileAttachment, Sound, Movie, Screen, Widget, PrinterMark, TrapNet,
/// Watermark, 3D, Redact, Projection, RichMedia, and extensible unknown names.
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
/// Typed page annotation record for ISO 32000-2 12.5 "Annotations".
/// It associates an annotation dictionary from a page Annots array with its
/// page index, array position, common annotation dictionary entries, optional
/// markup annotation data, subtype-specific data, and preserved raw dictionary.
/// Vocabulary source: /users/terukichi/workspaces/moonbit/pdf/spec/extracted/12.5-annotations.spec.txt.
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
/// Entries common to all annotation dictionaries from ISO 32000-2 12.5.2
/// and Table 166. This includes Type Annot validation, required Subtype and
/// Rect, accessibility Contents, P, NM, M, F annotation flags, AP appearance
/// streams, AS appearance state, Border or BS, C colour, StructParent, OC,
/// AF associated files, ca and CA opacity, BM blend mode, Lang, and raw data.
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
  additional_actions : @objects.PdfObject?
  associated_files : Array[@objects.PdfObject]
  nonstroking_opacity : Double
  stroking_opacity : Double
  blend_mode : @objects.PdfName?
  language : Bytes?
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
/// Annotation flags from ISO 32000-2 12.5.3 and Table 167. The F entry
/// defaults to 0 and stores bits for Invisible, Hidden, Print, NoZoom,
/// NoRotate, NoView, ReadOnly, Locked, ToggleNoView, and LockedContents.
pub(all) struct PdfAnnotationFlags {
  bits : Int
} derive(Eq, Debug)

///|
/// Annotation border model for ISO 32000-2 12.5.4 "Border styles". It
/// represents legacy Border arrays from Table 166, BS border style
/// dictionaries from Table 168, BE border effect dictionaries from Table 169,
/// default [0 0 1] borders, width, dash pattern, and raw border/style data.
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
/// Border style names from ISO 32000-2 Table 168: S solid, D dashed,
/// B beveled, I inset, U underline, plus unknown extension names.
pub(all) enum PdfBorderStyle {
  Solid
  Dashed
  Beveled
  Inset
  Underline
  Unknown(@objects.PdfName)
} derive(Eq, Debug)

///|
/// Border effect style names from ISO 32000-2 Table 169: S no effect and
/// C cloudy, plus unknown extension names.
pub(all) enum PdfBorderEffectStyle {
  None
  Cloudy
  Unknown(@objects.PdfName)
} derive(Eq, Debug)

///|
/// Border effect dictionary from ISO 32000-2 Table 169. The style and
/// intensity describe the optional BE entry used by square, circle, polygon,
/// and free text annotations.
pub(all) struct PdfBorderEffect {
  style : PdfBorderEffectStyle
  intensity : Double
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
/// Appearance dictionary descriptor for ISO 32000-2 12.5.5 "Appearance
/// streams" and Table 170. Normal (N), rollover (R), and down (D)
/// appearances are kept as stream or appearance subdictionary structure,
/// with the selected AS appearance state preserved.
pub(all) struct PdfAnnotationAppearance {
  normal : PdfAppearanceEntry
  rollover : PdfAppearanceEntry
  down : PdfAppearanceEntry
  selected_state : @objects.PdfName?
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
/// Appearance stream entry from ISO 32000-2 Table 170. An AP N, R, or D entry
/// may be a single appearance stream or an appearance subdictionary that maps
/// appearance states to streams.
pub(all) enum PdfAppearanceEntry {
  Stream(@objects.PdfStream)
  StateMap(@objects.PdfDictionary)
  Raw(@objects.PdfObject)
} derive(Eq, Debug)

///|
/// Point in default user space used by annotation geometry: Rect,
/// QuadPoints, callout lines, Line L arrays, Vertices, InkList, and Path data.
pub(all) struct PdfPoint {
  x : Double
  y : Double
} derive(Eq, Debug)

///|
/// QuadPoints group from link, text markup, and redaction annotations.
/// ISO 32000-2 Tables 176, 182, and 195 define each group as eight numbers
/// naming four quadrilateral vertices in default user space.
pub(all) struct PdfQuadPoints {
  points : Array[PdfPoint]
} derive(Eq, Debug)

///|
/// Annotation path made from coordinate pairs. It covers PDF 2.0 Path arrays
/// for polygon, polyline, and ink annotations in 12.5.6.9 and 12.5.6.13.
pub(all) struct PdfAnnotationPath {
  points : Array[PdfPoint]
} derive(Eq, Debug)

///|
/// Free text callout line from ISO 32000-2 Table 177 CL. Four numbers encode
/// a start/end callout; six numbers include the knee point.
pub(all) struct PdfAnnotationCallout {
  points : Array[PdfPoint]
} derive(Eq, Debug)

///|
/// Line annotation L entry from ISO 32000-2 Table 178, holding start and end
/// coordinates in default user space.
pub(all) struct PdfLineCoordinates {
  start : PdfPoint
  end : PdfPoint
} derive(Eq, Debug)

///|
/// Line ending styles from ISO 32000-2 Table 179: Square, Circle, Diamond,
/// OpenArrow, ClosedArrow, None, Butt, ROpenArrow, RClosedArrow, and Slash.
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
/// Link and widget highlighting mode from ISO 32000-2 Tables 176 and 191:
/// N none, I invert, O outline, P push, and unknown extension names.
pub(all) enum PdfHighlightMode {
  None
  Invert
  Outline
  Push
  Unknown(@objects.PdfName)
} derive(Eq, Debug)

///|
/// Quadding or justification code used by free text and redaction
/// annotations in ISO 32000-2 Tables 177 and 195: 0 left, 1 center, 2 right.
pub(all) enum PdfJustification {
  Left
  Center
  Right
  Unknown(Int)
} derive(Eq, Debug)

///|
/// Annotation state model names from ISO 32000-2 12.5.6.3 and Table 174:
/// Marked and Review, plus unknown extension names.
pub(all) enum PdfAnnotationStateModel {
  Marked
  Review
  Unknown(@objects.PdfName)
} derive(Eq, Debug)

///|
/// Annotation states from ISO 32000-2 12.5.6.3 and Table 174. Marked,
/// Unmarked, Accepted, Rejected, Cancelled, Completed, and None are exposed
/// for text-annotation state replies.
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
/// External data dictionary carried by markup and projection annotations.
/// ISO 32000-2 Table 173 uses ExData Subtype names such as Markup3D, 3DM,
/// and MarkupGeo; raw dictionary data is preserved for adjacent clauses.
pub(all) struct PdfMarkupExternalData {
  subtype : @objects.PdfName?
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
/// Markup annotation common entries from ISO 32000-2 12.5.6.2 and
/// Tables 172 and 173. It preserves T title, Popup, RC rich contents,
/// CreationDate, IRT, RT reply type, Subj, IT intent, ExData, State, and
/// StateModel without executing interactive comments-pane behavior.
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
/// Text annotation data from ISO 32000-2 12.5.6.4 and Table 175. Text
/// annotations use Open, Name icon defaults, State, and StateModel and behave
/// structurally as if NoZoom and NoRotate annotation flags were set.
pub(all) struct PdfTextAnnotation {
  open : Bool
  icon_name : @objects.PdfName
} derive(Eq, Debug)

///|
/// Link annotation data from ISO 32000-2 12.5.6.5 and Table 176. Actions,
/// Dest destinations, PA previous URI action, H highlight mode, QuadPoints,
/// and BS border style are preserved structurally without executing links.
pub(all) struct PdfLinkAnnotation {
  action : @objects.PdfObject?
  previous_uri_action : @objects.PdfObject?
  destination : @objects.PdfObject?
  highlight_mode : PdfHighlightMode
  quad_points : Array[PdfQuadPoints]
} derive(Eq, Debug)

///|
/// Free text annotation data from ISO 32000-2 12.5.6.6 and Table 177.
/// DA default appearance, Q justification, RC rich text, DS default style,
/// CL callout, IT intent, BE border effect, RD difference rectangle, and BS
/// border style are parsed as annotation-owned structure.
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
/// Line annotation data from ISO 32000-2 12.5.6.7 and Table 178. It includes
/// required L coordinates, BS border style, LE line endings, IC interior
/// colour, LL/LLE/LLO leader lines, Cap caption, IT intent, Measure, and CO.
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
/// Shape discriminator for ISO 32000-2 12.5.6.8 square and circle
/// annotations from Table 180.
pub(all) enum PdfShapeKind {
  Square
  Circle
} derive(Eq, Debug)

///|
/// Square and circle annotation data from ISO 32000-2 12.5.6.8 and
/// Table 180. It stores IC interior colour, BE border effect, RD difference
/// rectangle, and the Square or Circle shape kind.
pub(all) struct PdfShapeAnnotation {
  kind : PdfShapeKind
  interior_color : Array[Double]
  border_effect : PdfBorderEffect?
  difference_rectangle : PdfRectangle?
} derive(Eq, Debug)

///|
/// Polygon family discriminator for ISO 32000-2 12.5.6.9 polygon and
/// polyline annotations from Table 181.
pub(all) enum PdfPolygonKind {
  Polygon
  PolyLine
} derive(Eq, Debug)

///|
/// Polygon and polyline annotation data from ISO 32000-2 12.5.6.9 and
/// Table 181. It represents Vertices or PDF 2.0 Path data, LE line endings,
/// IC interior colour, IT intent, Measure, and raw border/effect ownership.
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
/// Text markup annotation kinds from ISO 32000-2 12.5.6.10 and Table 182:
/// Highlight, Underline, Squiggly, and StrikeOut.
pub(all) enum PdfTextMarkupKind {
  Highlight
  Underline
  Squiggly
  StrikeOut
} derive(Eq, Debug)

///|
/// Text markup annotation data from ISO 32000-2 12.5.6.10 and Table 182.
/// QuadPoints are required and define highlighted, underlined, squiggly, or
/// strikeout quadrilaterals in default user space.
pub(all) struct PdfTextMarkupAnnotation {
  kind : PdfTextMarkupKind
  quad_points : Array[PdfQuadPoints]
} derive(Eq, Debug)

///|
/// Caret annotation data from ISO 32000-2 12.5.6.11 and Table 183. RD
/// difference rectangle and Sy symbol values such as P or None are exposed.
pub(all) struct PdfCaretAnnotation {
  difference_rectangle : PdfRectangle?
  symbol : @objects.PdfName
} derive(Eq, Debug)

///|
/// Rubber stamp annotation data from ISO 32000-2 12.5.6.12 and Table 184.
/// It preserves Name icon defaults such as Draft and IT intents Stamp,
/// StampImage, and StampSnapshot.
pub(all) struct PdfStampAnnotation {
  icon_name : @objects.PdfName
  intent : @objects.PdfName
} derive(Eq, Debug)

///|
/// Ink annotation data from ISO 32000-2 12.5.6.13 and Table 185. InkList
/// stroked paths and PDF 2.0 Path arrays are parsed without rendering.
pub(all) struct PdfInkAnnotation {
  ink_list : Array[PdfAnnotationPath]
  paths : Array[PdfAnnotationPath]
} derive(Eq, Debug)

///|
/// Popup annotation data from ISO 32000-2 12.5.6.14 and Table 186. Parent
/// markup annotation reference and Open state are preserved without creating
/// popup windows or editing UI.
pub(all) struct PdfPopupAnnotation {
  parent : @objects.PdfObject?
  open : Bool
} derive(Eq, Debug)

///|
/// File attachment annotation data from ISO 32000-2 12.5.6.15 and
/// Table 187. FS file specification is preserved as a raw hand-off value and
/// Name icon defaults such as PushPin are parsed.
pub(all) struct PdfFileAttachmentAnnotation {
  file_specification : @objects.PdfObject
  icon_name : @objects.PdfName
} derive(Eq, Debug)

///|
/// Sound annotation data from ISO 32000-2 12.5.6.16 and Table 188. The
/// deprecated PDF 2.0 Sound stream is preserved as raw structure with Name
/// icon defaults such as Speaker, without playing audio.
pub(all) struct PdfSoundAnnotation {
  sound : @objects.PdfObject
  icon_name : @objects.PdfName
} derive(Eq, Debug)

///|
/// Movie annotation data from ISO 32000-2 12.5.6.17 and Table 189. T title,
/// Movie dictionary, and A activation are preserved without movie playback.
pub(all) struct PdfMovieAnnotation {
  title : Bytes?
  movie : @objects.PdfObject
  activation : @objects.PdfObject?
} derive(Eq, Debug)

///|
/// Screen annotation data from ISO 32000-2 12.5.6.18 and Table 190. T title,
/// A action, AA additional actions, MK appearance characteristics, rendition
/// action linkage, and AP default appearance remain structural only.
pub(all) struct PdfScreenAnnotation {
  title : Bytes?
  action : @objects.PdfObject?
  additional_actions : @objects.PdfObject?
  appearance_characteristics : PdfWidgetAppearanceCharacteristics?
} derive(Eq, Debug)

///|
/// Appearance characteristics dictionary from ISO 32000-2 Table 192. Widget
/// and screen annotations use MK entries R, BC, BG, CA, RC, AC, I, RI, IX,
/// IF, and TP; icon and icon-fit values are preserved as raw hand-off data.
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
/// Widget annotation data from ISO 32000-2 12.5.6.19 and Table 191. It keeps
/// H highlighting mode, MK appearance characteristics, A and AA action
/// dictionaries, BS border style, and Parent field reference without merging
/// interactive form field semantics.
pub(all) struct PdfWidgetAnnotation {
  highlight_mode : PdfHighlightMode
  action : @objects.PdfObject?
  additional_actions : @objects.PdfObject?
  border_style : PdfAnnotationBorder
  parent : @objects.PdfObject?
  appearance_characteristics : PdfWidgetAppearanceCharacteristics?
} derive(Eq, Debug)

///|
/// Printer's mark annotation data from ISO 32000-2 12.5.6.20. PrinterMark
/// annotations preserve PMD production mark data for print production use.
pub(all) struct PdfPrinterMarkAnnotation {
  production_mark : @objects.PdfObject?
} derive(Eq, Debug)

///|
/// Trap network annotation data from ISO 32000-2 12.5.6.21. TrapNet is
/// deprecated in PDF 2.0; a page may have no more than one and it must be the
/// final element of the page Annots array.
pub(all) struct PdfTrapNetworkAnnotation {
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
/// Fixed print dictionary from ISO 32000-2 Table 194. Watermark annotations
/// use Matrix, H, and V to describe size and position relative to target media.
pub(all) struct PdfFixedPrint {
  matrix : Array[Double]
  horizontal_translation : Double
  vertical_translation : Double
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
/// Watermark annotation data from ISO 32000-2 12.5.6.22 and Table 193.
/// FixedPrint is exposed structurally; this reader does not render or print
/// watermark appearances.
pub(all) struct PdfWatermarkAnnotation {
  fixed_print : PdfFixedPrint?
} derive(Eq, Debug)

///|
/// Redaction annotation data from ISO 32000-2 12.5.6.23 and Table 195.
/// QuadPoints, IC, RO overlay, OverlayText, Repeat, DA, and Q are parsed for
/// non-destructive redaction intent; this reader never applies redactions.
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
/// Projection annotation data from ISO 32000-2 12.5.6.24. Projection is a
/// markup annotation subtype used with run-time environments and optional
/// ExData such as 3DM projection measurement data.
pub(all) struct PdfProjectionAnnotation {
  external_data : PdfMarkupExternalData?
} derive(Eq, Debug)

///|
/// Raw annotation hand-off for extensible or adjacent-clause subtypes,
/// including ISO Table 171 3D and RichMedia annotation names and unknown
/// Subtype values. Common annotation dictionary fields remain parsed.
pub(all) struct PdfRawAnnotation {
  subtype_name : @objects.PdfName
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
/// Subtype-specific annotation payloads for ISO 32000-2 12.5.6 annotation
/// types. This enum covers Text, Link, FreeText, Line, Square/Circle Shape,
/// Polygon/PolyLine, text markup, Caret, Stamp, Ink, Popup, FileAttachment,
/// Sound, Movie, Screen, Widget, PrinterMark, TrapNet, Watermark, Redact,
/// Projection, 3D raw, RichMedia raw, and unknown raw records.
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

///|
/// Catalog MarkInfo flags with ISO defaults for absent entries. The raw
/// dictionary is retained when the producer supplied one.
pub(all) struct PdfMarkInfo {
  marked : Bool
  user_properties : Bool
  suspects : Bool
  raw_dict : @objects.PdfDictionary?
} derive(Eq, Debug)

///|
pub(all) enum PdfStructureParent {
  Root
  Element(@objects.ObjectId?)
  Raw(@objects.PdfObject)
} derive(Eq, Debug)

///|
pub(all) struct PdfStructureDiagnostic {
  code : @objects.PdfName
  message : String
  object_id : @objects.ObjectId?
  raw_object : @objects.PdfObject?
} derive(Eq, Debug)

///|
pub(all) struct PdfMarkedContentIdentifier {
  mcid : Int
  page_ref : @objects.ObjectId?
  raw_object : @objects.PdfObject
} derive(Eq, Debug)

///|
pub(all) struct PdfMarkedContentReference {
  mcid : Int
  page_ref : @objects.ObjectId?
  stream_ref : @objects.ObjectId?
  stream_owner_ref : @objects.ObjectId?
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
pub(all) struct PdfObjectReferenceContent {
  object_ref : @objects.ObjectId
  page_ref : @objects.ObjectId?
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
pub(all) enum PdfStructureContentItem {
  MCID(PdfMarkedContentIdentifier)
  MCR(PdfMarkedContentReference)
  OBJR(PdfObjectReferenceContent)
} derive(Eq, Debug)

///|
pub(all) enum PdfStructureChild {
  Element(Int, @objects.ObjectId?)
  Content(PdfStructureContentItem)
  Diagnostic(PdfStructureDiagnostic)
  Raw(@objects.PdfObject)
} derive(Eq, Debug)

///|
pub(all) enum PdfStructureAttributeSourceKind {
  Direct
  ClassMap(Bytes)
  Inherited(@objects.ObjectId?)
  Default
} derive(Eq, Debug)

///|
pub(all) struct PdfUserProperty {
  name : Bytes
  value : @objects.PdfObject
  formatted_value : Bytes?
  hidden : Bool
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
pub(all) struct PdfStructureAttributeObject {
  owner : @objects.PdfName?
  namespace_owner : @objects.ObjectId?
  revision : Int?
  raw_object : @objects.PdfObject
  raw_dict : @objects.PdfDictionary?
  raw_stream : @objects.PdfStream?
  user_properties : Array[PdfUserProperty]
} derive(Eq, Debug)

///|
pub(all) struct PdfStructureClassReference {
  name : Bytes
  revision : Int?
  raw_object : @objects.PdfObject
} derive(Eq, Debug)

///|
pub(all) struct PdfStructureClassMapEntry {
  name : Bytes
  attributes : Array[PdfStructureAttributeObject]
  raw_value : @objects.PdfObject
} derive(Eq, Debug)

///|
pub(all) struct PdfResolvedAttribute {
  key : @objects.PdfName
  value : @objects.PdfObject
  owner : @objects.PdfName?
  namespace_owner : @objects.ObjectId?
  source : PdfStructureAttributeSourceKind
  inherited : Bool
  defaulted : Bool
  revision : Int?
  raw_origin : @objects.PdfObject
} derive(Eq, Debug)

///|
pub(all) struct PdfAccessibilityProperties {
  alternate_description : Bytes?
  replacement_text : Bytes?
  expansion_text : Bytes?
  phoneme : Bytes?
  phonetic_alphabet : @objects.PdfName?
} derive(Eq, Debug)

///|
pub(all) enum PdfEffectiveLanguageSource {
  Absent
  Catalog
  Element(@objects.ObjectId?)
} derive(Eq, Debug)

///|
pub(all) struct PdfEffectiveLanguage {
  language : Bytes?
  source : PdfEffectiveLanguageSource
} derive(Eq, Debug)

///|
pub(all) struct PdfStructureElement {
  index : Int
  object_id : @objects.ObjectId?
  structure_type : @objects.PdfName
  parent : PdfStructureParent
  id : Bytes?
  references : @objects.PdfObject?
  page_ref : @objects.ObjectId?
  children : Array[PdfStructureChild]
  attributes : Array[PdfStructureAttributeObject]
  class_refs : Array[PdfStructureClassReference]
  revision : Int?
  title : Bytes?
  language : Bytes?
  accessibility : PdfAccessibilityProperties
  namespace_ref : @objects.ObjectId?
  associated_files : @objects.PdfObject?
  raw_dict : @objects.PdfDictionary
  diagnostics : Array[PdfStructureDiagnostic]
} derive(Eq, Debug)

///|
pub(all) struct PdfNamespaceRoleMapEntry {
  source : @objects.PdfName
  target : @objects.PdfName
  target_namespace_ref : @objects.ObjectId?
  raw_target : @objects.PdfObject
} derive(Eq, Debug)

///|
pub(all) struct PdfStructureNamespace {
  index : Int
  object_id : @objects.ObjectId?
  name : Bytes?
  schema : @objects.PdfObject?
  role_map : Array[PdfNamespaceRoleMapEntry]
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
pub(all) enum PdfStandardStructureCategory {
  Document
  Grouping
  Block
  SubBlock
  Inline
  Ruby
  Warichu
  List
  Table
  Caption
  Figure
  Formula
  Artifact
  Contextual
} derive(Eq, Debug)

///|
pub(all) struct PdfStandardStructureType {
  name : @objects.PdfName
  category : PdfStandardStructureCategory
  heading_level : Int?
} derive(Eq, Debug)

///|
pub(all) struct PdfResolvedStructureType {
  original : @objects.PdfName
  namespace_ref : @objects.ObjectId?
  chain : Array[@objects.PdfName]
  standard_target : PdfStandardStructureType?
  custom_terminal : @objects.PdfName?
  cycle : Bool
} derive(Eq, Debug)

///|
pub(all) struct PdfStructureParentLookup {
  element_index : Int?
  element_ref : @objects.ObjectId?
  raw_value : @objects.PdfObject
} derive(Eq, Debug)

///|
pub(all) struct PdfStructureContentReport {
  diagnostics : Array[PdfStructureDiagnostic]
  unchecked : Array[PdfTaggedPdfReportItem]
} derive(Eq, Debug)

///|
pub(all) enum PdfTaggedPdfSeverity {
  Error
  Warning
  Unchecked
} derive(Eq, Debug)

///|
pub(all) struct PdfTaggedPdfReportItem {
  code : @objects.PdfName
  severity : PdfTaggedPdfSeverity
  message : String
  element_index : Int?
  object_id : @objects.ObjectId?
  raw_object : @objects.PdfObject?
} derive(Eq, Debug)

///|
pub(all) struct PdfStandardNestingDiagnostic {
  code : @objects.PdfName
  message : String
  element_index : Int?
  severity : PdfTaggedPdfSeverity
} derive(Eq, Debug)

///|
pub(all) struct PdfTaggedPdfReport {
  errors : Array[PdfTaggedPdfReportItem]
  warnings : Array[PdfTaggedPdfReportItem]
  unchecked : Array[PdfTaggedPdfReportItem]
  is_marked : Bool
  has_structure_tree : Bool
} derive(Eq, Debug)

///|
pub(all) struct PdfStructureTree {
  root_object_id : @objects.ObjectId?
  root_dict : @objects.PdfDictionary
  root_children : Array[PdfStructureChild]
  elements : Array[PdfStructureElement]
  id_tree_entries : Array[PdfNameTreeEntry]
  parent_tree_entries : Array[PdfNumberTreeEntry]
  parent_tree_next_key : Int?
  role_map : Map[@objects.PdfName, @objects.PdfName]
  class_map : Array[PdfStructureClassMapEntry]
  namespaces : Array[PdfStructureNamespace]
  pronunciation_lexicons : Array[@objects.PdfObject]
  associated_files : @objects.PdfObject?
  document_language : Bytes?
  mark_info : PdfMarkInfo
} derive(Eq, Debug)

///|
/// Computes a non-negative rectangle area after normalizing coordinate order.
pub fn PdfRectangle::normalized_area(self : PdfRectangle) -> Double {
  let width = if self.right >= self.left {
    self.right - self.left
  } else {
    self.left - self.right
  }
  let height = if self.top >= self.bottom {
    self.top - self.bottom
  } else {
    self.bottom - self.top
  }
  width * height
}

///|
/// True when viewer preferences contain print-related policy beyond defaults.
pub fn PdfViewerPreferences::has_print_policy(
  self : PdfViewerPreferences,
) -> Bool {
  if self.print_page_ranges.length() > 0 {
    true
  } else if self.num_copies is Some(_) || self.duplex is Some(_) {
    true
  } else {
    self.pick_tray_by_pdf_size || self.enforce.length() > 0
  }
}

///|
/// True when a destination points outside the current document page tree.
pub fn PdfDestinationTarget::is_remote(self : PdfDestinationTarget) -> Bool {
  match self {
    RemotePageIndex(index) => index >= 0
    RemoteStructureId(bytes) => bytes.length() > 0
    LocalPage(_) => false
    LocalStructure(_, _) => false
  }
}

///|
/// True when a collection carries a usable folder hierarchy or file listing.
pub fn PdfCollection::has_navigation_payload(self : PdfCollection) -> Bool {
  if self.folders.length() > 0 {
    true
  } else if self.files.length() > 0 {
    true
  } else {
    self.navigator is Some(_)
  }
}

///|
/// Checks whether a label range can produce labels for the given page index.
pub fn PdfPageLabelRange::covers_page_index(
  self : PdfPageLabelRange,
  page_index : Int,
) -> Bool {
  if self.start_index < 0 || self.start_number < 1 {
    false
  } else if page_index < self.start_index {
    false
  } else {
    self.prefix.length() > 0 || self.style != PdfPageLabelStyle::PrefixOnly
  }
}

///|
/// True for annotation subtypes that use markup common fields.
pub fn PdfAnnotationSubtype::is_markup_family(
  self : PdfAnnotationSubtype,
) -> Bool {
  match self {
    Text | FreeText | Line | Square | Circle => true
    Polygon | PolyLine | Highlight | Underline | Squiggly => true
    StrikeOut | Caret | Stamp | Ink | FileAttachment => true
    Sound | Projection | Redact => true
    Link | Popup | Movie | Screen | Widget | PrinterMark => false
    TrapNet | Watermark | ThreeD | RichMedia | Unknown(_) => false
  }
}

///|
/// True when common annotation entries carry accessible text or language data.
pub fn PdfAnnotationCommon::has_accessibility_text(
  self : PdfAnnotationCommon,
) -> Bool {
  if self.contents is Some(bytes) && bytes.length() > 0 {
    true
  } else if self.language is Some(bytes) && bytes.length() > 0 {
    true
  } else {
    self.name is Some(bytes) && bytes.length() > 0
  }
}

///|
/// True when border information can produce visible annotation stroke output.
pub fn PdfAnnotationBorder::visible(self : PdfAnnotationBorder) -> Bool {
  if self.width <= 0.0 {
    false
  } else {
    match self.style {
      Unknown(name) =>
        name.to_text().length() > 0 || self.dash_pattern.length() > 0
      Underline => self.width > 0.0
      Solid | Dashed | Beveled | Inset => true
    }
  }
}

///|
/// True when appearance data includes rollover, down, or selected-state data.
pub fn PdfAnnotationAppearance::has_interactive_state(
  self : PdfAnnotationAppearance,
) -> Bool {
  if self.selected_state is Some(_) {
    true
  } else {
    match (self.rollover, self.down) {
      (Raw(@objects.PdfObject::Null), Raw(@objects.PdfObject::Null)) => false
      _ => true
    }
  }
}

///|
/// Validates that a path has enough non-degenerate coordinate data.
pub fn PdfAnnotationPath::has_usable_geometry(self : PdfAnnotationPath) -> Bool {
  if self.points.length() < 2 {
    false
  } else {
    let first = self.points[0]
    let last = self.points[self.points.length() - 1]
    first.x != last.x || first.y != last.y || self.points.length() > 2
  }
}

///|
/// True when a callout line contains the optional knee point.
pub fn PdfAnnotationCallout::is_kneed(self : PdfAnnotationCallout) -> Bool {
  if self.points.length() == 3 {
    let start = self.points[0]
    let knee = self.points[1]
    let end = self.points[2]
    (start.x != knee.x || start.y != knee.y) &&
    (knee.x != end.x || knee.y != end.y)
  } else {
    false
  }
}

///|
/// True when line coordinates span at least one axis in user space.
pub fn PdfLineCoordinates::has_extent(self : PdfLineCoordinates) -> Bool {
  if self.start.x != self.end.x {
    true
  } else if self.start.y != self.end.y {
    true
  } else {
    false
  }
}

///|
/// True when markup data is a reply or review-state carrier.
pub fn PdfMarkupAnnotation::is_threaded_reply(
  self : PdfMarkupAnnotation,
) -> Bool {
  if self.in_reply_to is Some(_) {
    true
  } else if self.reply_type is Some(_) {
    true
  } else {
    self.state is Some(_) || self.state_model is Some(_)
  }
}

///|
/// True when a link can activate a navigation or action target.
pub fn PdfLinkAnnotation::has_activation_target(
  self : PdfLinkAnnotation,
) -> Bool {
  if self.action is Some(_) {
    true
  } else if self.destination is Some(_) {
    true
  } else {
    self.previous_uri_action is Some(_)
  }
}

///|
/// True when line annotation layout includes leader, caption, or measure data.
pub fn PdfLineAnnotation::has_extended_layout(self : PdfLineAnnotation) -> Bool {
  if self.leader_line_length != 0.0 || self.leader_line_extension != 0.0 {
    true
  } else if self.leader_line_offset != 0.0 || self.caption {
    true
  } else {
    self.measure is Some(_) || self.caption_offset is Some(_)
  }
}

///|
/// True for subtype payloads that hand off external media, files, or raw data.
pub fn PdfAnnotationSpecific::requires_external_payload(
  self : PdfAnnotationSpecific,
) -> Bool {
  match self {
    FileAttachment(_) | Sound(_) | Movie(_) | Screen(_) => true
    ThreeDRaw(_) | RichMediaRaw(_) | UnknownRaw(_) => true
    Link(_) | Widget(_) | Projection(_) => true
    Text(_) | FreeText(_) | Line(_) | Shape(_) | Polygon(_) => false
    TextMarkup(_) | Caret(_) | Stamp(_) | Ink(_) | Popup(_) => false
    PrinterMark(_) | TrapNetwork(_) | Watermark(_) | Redaction(_) => false
  }
}

///|
/// True when redaction data carries overlay content or visible replacement text.
pub fn PdfRedactionAnnotation::has_overlay_instruction(
  self : PdfRedactionAnnotation,
) -> Bool {
  if self.overlay is Some(_) {
    true
  } else if self.overlay_text is Some(bytes) && bytes.length() > 0 {
    true
  } else {
    self.repeat || self.default_appearance is Some(_)
  }
}
