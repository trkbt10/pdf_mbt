///|
/// Reader-layer provenance for an ISO 32000-2 12.6 Actions parse.
/// It identifies the annotation, outline item, document Catalog OpenAction,
/// Page AA, form field AA, presentation node, or raw object that handed the
/// action dictionary to the parser; it is metadata only and never implies
/// trigger event dispatch.
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
/// ISO source: spec/extracted/12.6-actions.spec.txt.
/// Structural action dictionary metadata for 12.6.1 General and 12.6.2
/// Action dictionaries. The optional Type /Action, required S action type,
/// recursive Next action sequence, and raw dictionary are retained without
/// launching applications, resolving URI values, running ECMAScript, playing
/// media, rendering transitions, or mutating the document.
pub(all) struct PdfAction {
  object_id : @objects.ObjectId?
  source : PdfActionSource
  action_type : @objects.PdfName
  kind : PdfActionKind
  next : Array[PdfAction]
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
/// Standard action types from ISO 32000-2 12.6.4.1 Table 201: GoTo, GoToR,
/// GoToE, GoToDp, Launch, Thread, URI, Sound, Movie, Hide, Named, SubmitForm,
/// ResetForm, ImportData, SetOCGState, Rendition, Trans, GoTo3DView,
/// JavaScript, and RichMediaExecute. Unknown S names remain raw structural
/// data for forward-compatible action dictionaries.
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
/// 12.6.4.2 Go-To actions, Table 202. Represents S /GoTo with required D
/// destination and optional PDF 2.0 SD structure destination; SD takes
/// precedence for callers that understand structure destinations.
pub(all) struct PdfGoToAction {
  destination : PdfDestination
  structure_destination : PdfDestination?
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
/// 12.6.4.3 Remote Go-To actions, Table 203. Represents S /GoToR with
/// required F file specification, required D destination in another PDF file,
/// and optional NewWindow flag. Remote explicit page numbers are zero-based
/// and are preserved raw for downstream policy.
pub(all) struct PdfRemoteGoToAction {
  file_specification : @objects.PdfObject
  destination : @objects.PdfObject
  new_window : Bool?
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
/// 12.6.4.4 Embedded Go-To actions, Table 204. Represents S /GoToE for a
/// destination in an embedded PDF file, preserving F file specification, D
/// destination, NewWindow, and recursive T target dictionary path data.
pub(all) struct PdfEmbeddedGoToAction {
  file_specification : @objects.PdfObject?
  destination : @objects.PdfObject
  new_window : Bool?
  target : PdfTargetDictionary?
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
/// Target dictionary from 12.6.4.4 Table 205 for Embedded Go-To actions.
/// It preserves R parent-or-child relation, N embedded-file name, P page
/// selector, A annotation selector, and nested T target dictionaries.
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
/// 12.6.4.5 GoToDp action, Table 206. Represents S /GoToDp from PDF 2.0:
/// Dp is an indirect reference to the DPart dictionary whose Start page is
/// selected, such as the example form `/Dp 92 0 R`.
pub(all) struct PdfGoToDPartAction {
  dpart : @objects.ObjectId
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
/// 12.6.4.6 Launch actions, Table 207. Represents S /Launch with F file
/// specification or deprecated PDF 2.0 Win, Mac, or Unix platform launch
/// dictionaries and optional NewWindow, without opening files or applications.
pub(all) struct PdfLaunchAction {
  file_specification : @objects.PdfObject?
  windows : PdfWindowsLaunchParams?
  mac : @objects.PdfObject?
  unix : @objects.PdfObject?
  new_window : Bool?
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
/// Microsoft Windows launch parameter dictionary from 12.6.4.6 Table 208.
/// It preserves F byte string, D default directory, O operation such as open
/// or print, and P parameter string as raw PDF objects.
pub(all) struct PdfWindowsLaunchParams {
  file : @objects.PdfObject
  directory : @objects.PdfObject?
  operation : @objects.PdfObject?
  parameter : @objects.PdfObject?
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
/// 12.6.4.7 Thread actions, Table 209. Represents S /Thread with optional F
/// external file specification, D thread selector, and B bead selector. Thread
/// and bead index values are zero-based and preserved structurally.
pub(all) struct PdfThreadAction {
  file_specification : @objects.PdfObject?
  thread : @objects.PdfObject?
  bead : @objects.PdfObject?
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
/// 12.6.4.8 URI actions, Table 210 and Table 211. Represents S /URI with the
/// required URI UTF-8 string from Internet RFC 3986 and IsMap mouse-coordinate
/// flag; Catalog URI Base data is modeled separately and no network resolver
/// is invoked.
pub(all) struct PdfUriAction {
  uri : Bytes
  is_map : Bool
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
/// 12.6.4.9 Sound actions, Table 212. Represents deprecated PDF 2.0 S /Sound
/// metadata: required Sound stream, Volume in the -1.0 to 1.0 range, and the
/// Synchronous, Repeat, and Mix flags, without playing audio.
pub(all) struct PdfSoundAction {
  sound : @objects.PdfObject
  volume : Double
  synchronous : Bool
  repeat : Bool
  mix : Bool
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
/// Movie action target from 12.6.4.10 Table 213. Exactly one of Annotation
/// movie annotation reference or T title text string identifies the movie.
pub(all) enum PdfMovieTarget {
  Annotation(@objects.PdfObject)
  Title(Bytes)
} derive(Eq, Debug)

///|
/// Movie Operation names from 12.6.4.10 Table 213: Play, Stop, Pause, and
/// Resume. Unknown names are retained for compatibility.
pub(all) enum PdfMovieOperation {
  Play
  Stop
  Pause
  Resume
  Unknown(@objects.PdfName)
} derive(Eq, Debug)

///|
/// 12.6.4.10 Movie actions, Table 213. Represents deprecated PDF 2.0
/// S /Movie metadata for a movie annotation or title, plus the Operation
/// default Play, without starting, stopping, pausing, or resuming playback.
pub(all) struct PdfMovieAction {
  target : PdfMovieTarget
  operation : PdfMovieOperation
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
/// Hide action target forms from 12.6.4.11 Table 214: annotation dictionary or
/// reference, fully qualified field name text string, or an ordered array of
/// such values.
pub(all) enum PdfHideTarget {
  Single(@objects.PdfObject)
  Array(Array[@objects.PdfObject])
} derive(Eq, Debug)

///|
/// 12.6.4.11 Hide actions, Table 214. Represents S /Hide with required T
/// target and optional H flag defaulting to true; it records annotation Hidden
/// flag intent without changing annotation appearance state.
pub(all) struct PdfHideAction {
  target : PdfHideTarget
  hide : Bool
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
/// 12.6.4.12 Named actions, Table 215 and Table 216. Represents S /Named and
/// required N action name such as NextPage, PrevPage, FirstPage, or LastPage;
/// nonstandard names are retained as portable structural data.
pub(all) struct PdfNamedAction {
  name : @objects.PdfName
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
/// Raw structural boundary for ISO 32000-2 12.7.6 and Tables 201, 239,
/// 240, 241, 242, and 243 form actions SubmitForm, ResetForm, and
/// ImportData. F file specification, Fields selection array, Flags bitset,
/// PDF 2.0 CharSet values such as utf-8 or utf-16, and raw_dict are
/// preserved without form submission, reset, import, URL fetch, XFDF, FDF, or
/// PDF payload generation.
pub(all) struct PdfFormActionRaw {
  file_specification : @objects.PdfObject?
  fields : @objects.PdfObject?
  flags : Int?
  char_set : Bytes?
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
/// Set-OCG-state operator names from 12.6.4.13 Table 217: ON, OFF, and Toggle.
/// They describe optional content group state changes but do not mutate state.
pub(all) enum PdfOCGStateOperator {
  ON
  OFF
  Toggle
} derive(Eq, Debug)

///|
/// One left-to-right State sequence from 12.6.4.13 Table 217: an ON, OFF, or
/// Toggle operator followed by one or more optional content group dictionaries
/// or references.
pub(all) struct PdfOCGStateOperation {
  operator : PdfOCGStateOperator
  groups : Array[@objects.PdfObject]
} derive(Eq, Debug)

///|
/// 12.6.4.13 Set-OCG-state actions, Table 217. Represents S /SetOCGState with
/// ordered State operation sequences and PreserveRB default true while leaving
/// optional-content visibility unchanged.
pub(all) struct PdfSetOCGStateAction {
  operations : Array[PdfOCGStateOperation]
  preserve_rb : Bool
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
/// 12.6.4.14 Rendition actions, Table 218. Represents S /Rendition with R
/// rendition object, AN screen annotation, OP operation values 0, 1, 2, 3, or
/// 4, and JS ECMAScript fallback payload, without playing multimedia content.
pub(all) struct PdfRenditionAction {
  rendition : @objects.PdfObject?
  annotation : @objects.PdfObject?
  operation : Int?
  script : @objects.PdfObject?
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
/// 12.6.4.15 Transition actions, Table 219. Represents S /Trans and required
/// Trans transition dictionary used for display update metadata only; no
/// drawing is suspended or rendered by the parser.
pub(all) struct PdfTransitionAction {
  transition : PdfTransition
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
/// 12.6.4.16 Go-To-3D-View actions, Table 220. Represents S /GoTo3DView with
/// required TA target annotation and V selector, which may be a 3D view
/// dictionary, VA array index, IN text string, or F, L, N, P, D view name.
pub(all) struct PdfGoTo3DViewAction {
  target_annotation : @objects.PdfObject
  view : @objects.PdfObject?
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
/// 12.6.4.17 ECMAScript actions, Table 221. The PDF keyword remains
/// JavaScript for backwards compatibility, while the payload is an ECMAScript
/// JS text string or stream preserved raw without script execution.
pub(all) struct PdfJavaScriptAction {
  script : @objects.PdfObject
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
/// 12.6.4.18 Rich-Media-Execute actions, Table 222. Represents PDF 2.0
/// S /RichMediaExecute with required TA RichMedia annotation reference,
/// optional TI instance reference, and required CMD RichMediaCommand
/// dictionary, without invoking any annotation handler.
pub(all) struct PdfRichMediaExecuteAction {
  target_annotation : @objects.PdfObject
  instance : @objects.PdfObject?
  command : @objects.PdfDictionary
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
/// Catalog OpenAction from 12.6.1 General and 7.7.2. It may be an existing
/// destination form or a typed 12.6 action dictionary performed when the
/// document is opened; this enum records structure only.
pub(all) enum PdfCatalogOpenAction {
  Destination(PdfDestination)
  Action(PdfAction)
} derive(Eq, Debug)

///|
/// Catalog URI dictionary from 12.6.4.8 Table 211. Base is the optional base
/// URI used for resolving relative URI action strings; parsing records it as
/// bytes and does not resolve relative references.
pub(all) struct PdfCatalogUri {
  base : Bytes?
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
/// Annotation additional-actions dictionary from 12.6.3 Table 197. It models
/// AA trigger events E, X, D, U, Fo, Bl, PO, PC, PV, and PI while preserving
/// unknown trigger keys in raw_dict.
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
/// Page object additional-actions dictionary from 12.6.3 Table 198. It models
/// O page-open and C page-close trigger events for Page AA entries.
pub(all) struct PdfPageAdditionalActions {
  open : PdfAction?
  close : PdfAction?
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
/// Form field additional-actions dictionary from 12.6.3 Table 199. It models
/// K keystroke, F format, V validate, and C calculate ECMAScript trigger
/// events without running scripts.
pub(all) struct PdfFormFieldAdditionalActions {
  keystroke : PdfAction?
  format : PdfAction?
  validate : PdfAction?
  calculate : PdfAction?
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
/// Document Catalog additional-actions dictionary from 12.6.3 Table 200. It
/// models WC will-close, WS will-save, DS did-save, WP will-print, and DP
/// did-print ECMAScript trigger events.
pub(all) struct PdfCatalogAdditionalActions {
  before_close : PdfAction?
  before_save : PdfAction?
  after_save : PdfAction?
  before_print : PdfAction?
  after_print : PdfAction?
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
/// Standard trigger event labels from 12.6.3 for Catalog OpenAction,
/// annotation activation, mouse-up precedence, page open, page close,
/// annotation PO page-open, and annotation PC page-close ordering.
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
/// Structural ordering notes from 12.6.3 Trigger events. The arrays record
/// annotation A precedence over U, OpenAction before Page O before annotation
/// PO, and annotation PC before Page C; no viewer event loop is dispatched.
pub(all) struct PdfActionTriggerOrdering {
  activation_precedence : Array[PdfActionTrigger]
  page_open_order : Array[PdfActionTrigger]
  page_close_order : Array[PdfActionTrigger]
} derive(Eq, Debug)

///|
/// True when the source is tied to page-local event or annotation context.
pub fn PdfActionSource::requires_page_context(self : PdfActionSource) -> Bool {
  match self {
    Page(_) => true
    Annotation(_) => true
    Presentation(_) => true
    Catalog(_) | Outline | FormField(_) | RawObject(_) => false
  }
}

///|
/// True for actions whose structural payload may identify data outside the
/// current PDF file or viewer sandbox.
pub fn PdfActionKind::is_external_boundary(self : PdfActionKind) -> Bool {
  match self {
    GoToR(_) | GoToE(_) | Launch(_) | URI(_) => true
    SubmitForm(_) | ImportData(_) | RichMediaExecute(_) => true
    GoTo(_) | GoToDp(_) | Thread(_) | Sound(_) | Movie(_) => false
    Hide(_) | Named(_) | ResetForm(_) | SetOCGState(_) => false
    Rendition(_) | Trans(_) | GoTo3DView(_) | JavaScript(_) => false
    Unknown(_, _) => true
  }
}

///|
/// True when the parsed action has a non-empty Next chain or a raw dictionary
/// entry that may have been intentionally retained for deferred inspection.
pub fn PdfAction::has_follow_up_actions(self : PdfAction) -> Bool {
  if self.next.length() > 0 {
    true
  } else if self.raw_dict.contains(@objects.PdfName::new(b"Next")) {
    true
  } else {
    false
  }
}

///|
/// Resolves the optional NewWindow flag with a caller-supplied viewer default
/// while treating malformed absent file specifications conservatively.
pub fn PdfRemoteGoToAction::requests_new_window(
  self : PdfRemoteGoToAction,
  default_value : Bool,
) -> Bool {
  let chosen = match self.new_window {
    Some(value) => value
    None => default_value
  }
  match self.file_specification {
    @objects.PdfObject::Null => false
    _ => chosen
  }
}

///|
/// Checks the recursive embedded target path against a caller-supplied depth.
pub fn PdfTargetDictionary::exceeds_depth(
  self : PdfTargetDictionary,
  max_depth : Int,
) -> Bool {
  if max_depth < 0 {
    true
  } else {
    let mut depth = 1
    let mut current = self.target
    while current is Some(target) {
      depth += 1
      if depth > max_depth {
        return true
      }
      current = target.target
    }
    false
  }
}

///|
/// Counts the optional-content group operands carried by all State operators.
pub fn PdfSetOCGStateAction::state_group_count(
  self : PdfSetOCGStateAction,
) -> Int {
  let mut count = 0
  for operation in self.operations {
    if operation.groups.length() > 0 {
      count += operation.groups.length()
    }
  }
  count
}

///|
/// Counts Catalog additional-action trigger entries that contain an action.
pub fn PdfCatalogAdditionalActions::event_count(
  self : PdfCatalogAdditionalActions,
) -> Int {
  let mut count = 0
  if self.before_close is Some(_) {
    count += 1
  }
  if self.before_save is Some(_) {
    count += 1
  }
  if self.after_save is Some(_) {
    count += 1
  }
  if self.before_print is Some(_) {
    count += 1
  }
  if self.after_print is Some(_) {
    count += 1
  }
  count
}

///|
/// True when a rendition action carries any deferred media or script payload.
pub fn PdfRenditionAction::has_deferred_payload(
  self : PdfRenditionAction,
) -> Bool {
  if self.rendition is Some(_) {
    true
  } else if self.annotation is Some(_) {
    true
  } else {
    self.script is Some(_) || self.operation is Some(_)
  }
}
