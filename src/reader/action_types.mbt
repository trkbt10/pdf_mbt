///|
/// Reader-layer provenance for a typed action parse. It identifies the PDF
/// structure that handed the raw action object to the action parser; it is
/// metadata only and never implies event dispatch.
pub(all) enum PdfActionSource {
  Catalog(@objects.ObjectId)
  Page(@objects.ObjectId)
  Annotation(@objects.ObjectId?)
  Outline
  FormField(@objects.ObjectId?)
  Presentation(@objects.ObjectId?)
  RawObject(@objects.ObjectId?)
} derive(Eq, Debug)

///|
pub(all) struct PdfAction {
  object_id : @objects.ObjectId?
  source : PdfActionSource
  action_type : @objects.PdfName
  kind : PdfActionKind
  next : Array[PdfAction]
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
pub(all) enum PdfActionKind {
  GoTo(PdfGoToAction)
  GoToR(PdfRemoteGoToAction)
  GoToE(PdfEmbeddedGoToAction)
  GoToDp(PdfGoToDPartAction)
  Launch(PdfLaunchAction)
  Thread(PdfThreadAction)
  URI(PdfUriAction)
  Sound(PdfSoundAction)
  Movie(PdfMovieAction)
  Hide(PdfHideAction)
  Named(PdfNamedAction)
  SubmitForm(PdfFormActionRaw)
  ResetForm(PdfFormActionRaw)
  ImportData(PdfFormActionRaw)
  SetOCGState(PdfSetOCGStateAction)
  Rendition(PdfRenditionAction)
  Trans(PdfTransitionAction)
  GoTo3DView(PdfGoTo3DViewAction)
  JavaScript(PdfJavaScriptAction)
  RichMediaExecute(PdfRichMediaExecuteAction)
  Unknown(@objects.PdfName, @objects.PdfDictionary)
} derive(Eq, Debug)

///|
pub(all) struct PdfGoToAction {
  destination : PdfDestination
  structure_destination : PdfDestination?
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
pub(all) struct PdfRemoteGoToAction {
  file_specification : @objects.PdfObject
  destination : @objects.PdfObject
  new_window : Bool?
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
pub(all) struct PdfEmbeddedGoToAction {
  file_specification : @objects.PdfObject?
  destination : @objects.PdfObject
  new_window : Bool?
  target : PdfTargetDictionary?
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
pub(all) struct PdfTargetDictionary {
  object_id : @objects.ObjectId?
  relation : @objects.PdfName?
  name : Bytes?
  page : @objects.PdfObject?
  annotation : @objects.PdfObject?
  target : PdfTargetDictionary?
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
pub(all) struct PdfGoToDPartAction {
  dpart : @objects.ObjectId
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
pub(all) struct PdfLaunchAction {
  file_specification : @objects.PdfObject?
  windows : PdfWindowsLaunchParams?
  mac : @objects.PdfObject?
  unix : @objects.PdfObject?
  new_window : Bool?
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
pub(all) struct PdfWindowsLaunchParams {
  file : @objects.PdfObject
  directory : @objects.PdfObject?
  operation : @objects.PdfObject?
  parameter : @objects.PdfObject?
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
pub(all) struct PdfThreadAction {
  file_specification : @objects.PdfObject?
  thread : @objects.PdfObject?
  bead : @objects.PdfObject?
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
pub(all) struct PdfUriAction {
  uri : Bytes
  is_map : Bool
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
pub(all) struct PdfSoundAction {
  sound : @objects.PdfObject
  volume : Double
  synchronous : Bool
  repeat : Bool
  mix : Bool
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
pub(all) enum PdfMovieTarget {
  Annotation(@objects.PdfObject)
  Title(Bytes)
} derive(Eq, Debug)

///|
pub(all) enum PdfMovieOperation {
  Play
  Stop
  Pause
  Resume
  Unknown(@objects.PdfName)
} derive(Eq, Debug)

///|
pub(all) struct PdfMovieAction {
  target : PdfMovieTarget
  operation : PdfMovieOperation
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
pub(all) enum PdfHideTarget {
  Single(@objects.PdfObject)
  Array(Array[@objects.PdfObject])
} derive(Eq, Debug)

///|
pub(all) struct PdfHideAction {
  target : PdfHideTarget
  hide : Bool
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
pub(all) struct PdfNamedAction {
  name : @objects.PdfName
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
pub(all) struct PdfFormActionRaw {
  file_specification : @objects.PdfObject?
  fields : @objects.PdfObject?
  flags : Int?
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
pub(all) enum PdfOCGStateOperator {
  ON
  OFF
  Toggle
} derive(Eq, Debug)

///|
pub(all) struct PdfOCGStateOperation {
  operator : PdfOCGStateOperator
  groups : Array[@objects.PdfObject]
} derive(Eq, Debug)

///|
pub(all) struct PdfSetOCGStateAction {
  operations : Array[PdfOCGStateOperation]
  preserve_rb : Bool
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
pub(all) struct PdfRenditionAction {
  rendition : @objects.PdfObject?
  annotation : @objects.PdfObject?
  operation : Int?
  script : @objects.PdfObject?
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
pub(all) struct PdfTransitionAction {
  transition : PdfTransition
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
pub(all) struct PdfGoTo3DViewAction {
  target_annotation : @objects.PdfObject
  view : @objects.PdfObject?
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
pub(all) struct PdfJavaScriptAction {
  script : @objects.PdfObject
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
pub(all) struct PdfRichMediaExecuteAction {
  target_annotation : @objects.PdfObject
  instance : @objects.PdfObject?
  command : @objects.PdfDictionary
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
pub(all) enum PdfCatalogOpenAction {
  Destination(PdfDestination)
  Action(PdfAction)
} derive(Eq, Debug)

///|
pub(all) struct PdfCatalogUri {
  base : Bytes?
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
pub(all) struct PdfAnnotationAdditionalActions {
  enter : PdfAction?
  exit : PdfAction?
  down : PdfAction?
  up : PdfAction?
  focus : PdfAction?
  blur : PdfAction?
  page_open : PdfAction?
  page_close : PdfAction?
  page_visible : PdfAction?
  page_invisible : PdfAction?
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
pub(all) struct PdfPageAdditionalActions {
  open : PdfAction?
  close : PdfAction?
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
pub(all) struct PdfFormFieldAdditionalActions {
  keystroke : PdfAction?
  format : PdfAction?
  validate : PdfAction?
  calculate : PdfAction?
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
pub(all) struct PdfCatalogAdditionalActions {
  before_close : PdfAction?
  before_save : PdfAction?
  after_save : PdfAction?
  before_print : PdfAction?
  after_print : PdfAction?
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
pub(all) enum PdfActionTrigger {
  CatalogOpenAction
  PageOpen
  PageClose
  AnnotationActivation
  AnnotationMouseUp
  AnnotationPageOpen
  AnnotationPageClose
} derive(Eq, Debug)

///|
pub(all) struct PdfActionTriggerOrdering {
  activation_precedence : Array[PdfActionTrigger]
  page_open_order : Array[PdfActionTrigger]
  page_close_order : Array[PdfActionTrigger]
} derive(Eq, Debug)
