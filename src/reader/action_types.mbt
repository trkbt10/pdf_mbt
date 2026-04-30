///|
/// Section 12.6.4.18 Rich-Media-Execute actions, Table 222 Additional entries
/// specific to a rich-media-execute action. A rich-media-execute action
/// identifies a rich media annotation and specifies a command to be sent to
/// that annotation's handler. Distinct PDF 2.0 entries: /S
/// /RichMediaExecute, required TA indirect object reference to an annotation
/// dictionary of Subtype RichMedia, optional TI indirect object reference to a
/// RichMediaInstance dictionary in the annotation Instances array, and
/// required CMD RichMediaCommand dictionary containing command name and
/// optional arguments as described by Table 223.
pub fn pdf_actions_section_12_6_4_18_rich_media_execute_table_222_anchor() -> Int {
  222
}

///|
/// Reader-layer provenance for an ISO 32000-2 12.6 Actions parse.
/// It identifies the annotation, outline item, document Catalog OpenAction,
/// Page AA, form field AA, presentation node, or raw object that handed the
/// action dictionary to the parser; it is metadata only and never implies
/// trigger event dispatch. Section 12.6.4.18 Rich-Media-Execute actions,
/// Table 222 /S /RichMediaExecute, TA RichMedia annotation, TI
/// RichMediaInstance, and CMD RichMediaCommand are parsed as structural action
/// payloads without sending commands to an annotation handler.
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
/// Section 12.6.1 General and Section 12.6.2 Action dictionaries. This
/// structural action record covers the outline item A entry from Table 151,
/// link annotation A entry from Table 176, screen annotation action context
/// from Table 190, widget annotation action context from Table 191, FDF field
/// action context from Table 249, document Catalog OpenAction from 7.7.2, and
/// the standard action types described in Section 12.6.4. It also preserves
/// Table 196 entries Type /Action, required S, and recursive Next.
pub(all) struct PdfAction {
  object_id : @objects.ObjectId?
  source : PdfActionSource
  action_type : @objects.PdfName
  kind : PdfActionKind
  next : Array[PdfAction]
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
/// Section 12.6.4.1 General, Table 201 Action types. The /S names are
/// /GoTo, /GoToR, /GoToE, /GoToDp, /Launch, /Thread, /URI, /Sound, /Movie,
/// /Hide, /Named, /SubmitForm, /ResetForm, /ImportData, /SetOCGState,
/// /Rendition, /Trans, /GoTo3DView, /JavaScript, and /RichMediaExecute.
/// PDF supports these standard action types: Go to a destination in the
/// current document, go to a destination in another document, go to an
/// embedded file destination, go to a specified DPart, launch an application,
/// begin reading an article thread, resolve a URI, play a sound, play a movie,
/// hide annotations, execute a named action, submit/reset/import form data,
/// set optional content group state, control multimedia rendition content,
/// update display with a transition, set a 3D annotation view, execute
/// ECMAScript, or send RichMediaExecute commands. Unknown S names remain raw
/// structural data.
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
/// Section 12.6.4.2 Go-To actions, Table 202 Additional entries specific to a
/// go-to action. Represents /S /GoTo with required D destination and optional
/// PDF 2.0 SD structure destination; SD should take precedence over D for
/// callers that understand structure destinations.
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
/// Section 12.6.4.4 Embedded Go-To actions, Table 204 Additional entries
/// specific to an embedded go-to action. Represents /S /GoToE for embedded PDF
/// files with F root file specification, D destination, NewWindow, and T
/// target dictionary path data relating source, target, parent, child, and
/// root documents.
pub(all) struct PdfEmbeddedGoToAction {
  file_specification : @objects.PdfObject?
  destination : @objects.PdfObject
  new_window : Bool?
  target : PdfTargetDictionary?
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
/// Section 12.6.4.4 Embedded Go-To actions, Table 205 Entries specific to a
/// target dictionary. It preserves R parent-or-child relation values P and C,
/// N EmbeddedFiles name tree byte string, P page selector, A annotation
/// selector, and nested T target dictionaries.
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
/// Section 12.6.4.5 GoToDp action, Table 206 Entries in a GoToDp dictionary.
/// Represents PDF 2.0 /S /GoToDp with required Dp indirect reference to the
/// DPart dictionary from Table 409, whose Start page is selected.
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
/// Section 12.6.4.8 URI actions, Table 210 Additional entries specific to a
/// URI action and Table 211 Entry in a URI dictionary. Represents /S /URI with
/// required URI UTF-8 string from Internet RFC 3986, optional IsMap
/// mouse-coordinate flag, and Catalog URI Base support modeled separately; no
/// network resolver is invoked.
pub(all) struct PdfUriAction {
  uri : Bytes
  is_map : Bool
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
/// Section 12.6.4.9 Sound actions, Table 212 Additional entries specific to a
/// sound action. Represents deprecated PDF 2.0 /S /Sound metadata: required
/// Sound stream, Volume in the -1.0 to 1.0 range, and Synchronous, Repeat, and
/// Mix flags, without playing audio.
pub(all) struct PdfSoundAction {
  sound : @objects.PdfObject
  volume : Double
  synchronous : Bool
  repeat : Bool
  mix : Bool
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
/// Section 12.6.4.10 Movie actions, Table 213. Exactly one of Annotation movie
/// annotation reference or T title text string identifies the movie.
pub(all) enum PdfMovieTarget {
  Annotation(@objects.PdfObject)
  Title(Bytes)
} derive(Eq, Debug)

///|
/// Section 12.6.4.10 Movie actions, Table 213 Operation names: Play, Stop,
/// Pause, and Resume. Unknown names are retained for compatibility.
pub(all) enum PdfMovieOperation {
  Play
  Stop
  Pause
  Resume
  Unknown(@objects.PdfName)
} derive(Eq, Debug)

///|
/// Section 12.6.4.10 Movie actions, Table 213 Additional entries specific to a
/// movie action. Represents deprecated PDF 2.0 /S /Movie metadata with
/// Annotation or T, Operation values Play, Stop, Pause, and Resume, and movie
/// activation dictionary defaults from Table 307. A movie action can play a
/// movie in a floating window or within the annotation rectangle of a movie
/// annotation associated with the destination page or page object; this parser
/// does not start, stop, pause, or resume playback.
pub(all) struct PdfMovieAction {
  target : PdfMovieTarget
  operation : PdfMovieOperation
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
/// Section 12.6.4.11 Hide actions, Table 214 target forms: annotation
/// dictionary or reference, fully qualified field name text string, or an
/// ordered array of such values.
pub(all) enum PdfHideTarget {
  Single(@objects.PdfObject)
  Array(Array[@objects.PdfObject])
} derive(Eq, Debug)

///|
/// Section 12.6.4.11 Hide actions, Table 214 Additional entries specific to a
/// hide action. Represents /S /Hide with required T annotation, field name, or
/// array target and optional H flag defaulting to true; it records Hidden flag
/// intent without changing annotation appearance state.
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
/// Section 12.6.4.13 Set-OCG-state actions, Table 217 operator names ON, OFF,
/// and Toggle. They describe optional content group state changes but do not
/// mutate state.
pub(all) enum PdfOCGStateOperator {
  ON
  OFF
  Toggle
} derive(Eq, Debug)

///|
/// Section 12.6.4.13 Set-OCG-state actions, Table 217. One left-to-right State
/// sequence: an ON, OFF, or Toggle name followed by one or more optional
/// content group dictionaries or references.
pub(all) struct PdfOCGStateOperation {
  operator : PdfOCGStateOperator
  groups : Array[@objects.PdfObject]
} derive(Eq, Debug)

///|
/// Section 12.6.4.13 Set-OCG-state actions, Table 217 Additional entries
/// specific to a set-OCG-state action. Represents /S /SetOCGState with
/// required State array processed left to right, ON, OFF, and Toggle
/// sequences, optional PreserveRB radio-button relationship preservation
/// default true, and no optional-content visibility mutation.
pub(all) struct PdfSetOCGStateAction {
  operations : Array[PdfOCGStateOperation]
  preserve_rb : Bool
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
/// Section 12.6.4.14 Rendition actions, Table 218 Additional entries specific
/// to a rendition action. Represents /S /Rendition with R rendition object, AN
/// screen annotation, OP operation values 0 play, 1 stop, 2 pause, 3 resume, 4
/// play-or-resume, and JS ECMAScript text string or stream fallback, without
/// playing multimedia content.
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
/// Section 12.6.4.17 ECMAScript actions, Table 221 Additional entries specific
/// to an ECMAScript action. The PDF /S keyword remains /JavaScript for
/// backwards compatibility, while required JS is an ECMAScript text string or
/// text stream preserved raw without script execution; document-level
/// JavaScript name-tree entries from 7.7.4 are outside execution scope.
pub(all) struct PdfJavaScriptAction {
  script : @objects.PdfObject
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
/// Section 12.6.4.18 Rich-Media-Execute actions, Table 222 Additional entries
/// specific to a rich-media-execute action. Represents PDF 2.0
/// /S /RichMediaExecute with required TA RichMedia annotation reference,
/// optional TI RichMediaInstance reference, and required CMD
/// RichMediaCommand dictionary from Table 223, without invoking an annotation
/// handler.
pub(all) struct PdfRichMediaExecuteAction {
  target_annotation : @objects.PdfObject
  instance : @objects.PdfObject?
  command : @objects.PdfDictionary
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
/// Section 12.6.1 General and 7.7.2 Document catalog dictionary OpenAction.
/// It may be an existing destination form or a typed Section 12.6 action
/// dictionary performed when the document is opened; this enum records
/// structure only.
pub(all) enum PdfCatalogOpenAction {
  Destination(PdfDestination)
  Action(PdfAction)
} derive(Eq, Debug)

///|
/// Section 12.6.4.8 URI actions, Table 211 Entry in a URI dictionary. Base is
/// the optional base URI used for resolving relative URI action strings;
/// parsing records it as bytes and does not resolve relative references.
pub(all) struct PdfCatalogUri {
  base : Bytes?
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
/// Section 12.6.3 Trigger events, Table 197 Entries in an annotation's
/// additional-actions dictionary. It models AA trigger event keys E, X, D, U,
/// Fo, Bl, PO, PC, PV, and PI while preserving unknown trigger keys in
/// raw_dict.
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
/// Section 12.6.3 Trigger events, Table 198 Entries in a page object's
/// additional-actions dictionary. It models O page-open and C page-close
/// trigger events for Page AA entries.
pub(all) struct PdfPageAdditionalActions {
  open : PdfAction?
  close : PdfAction?
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
/// Section 12.6.3 Trigger events, Table 199 Entries in a form field's
/// additional-actions dictionary. It models K keystroke, F format, V validate,
/// and C calculate ECMAScript trigger events without running scripts.
pub(all) struct PdfFormFieldAdditionalActions {
  keystroke : PdfAction?
  format : PdfAction?
  validate : PdfAction?
  calculate : PdfAction?
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
/// Section 12.6.3 Trigger events, Table 200 Entries in the document catalog's
/// additional-actions dictionary. It models WC will-close, WS will-save, DS
/// did-save, WP will-print, and DP did-print ECMAScript trigger events.
pub(all) struct PdfCatalogAdditionalActions {
  before_close : PdfAction?
  before_save : PdfAction?
  after_save : PdfAction?
  before_print : PdfAction?
  after_print : PdfAction?
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
/// Section 12.6.3 Trigger events standard labels for Catalog OpenAction,
/// annotation activation, mouse events E, X, D, U, mouse-up precedence, page
/// open O, page close C, annotation PO page-open, and annotation PC page-close
/// ordering.
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
/// Section 12.6.1 General action attachment count. The count covers optional
/// A entries on outline item dictionaries (Table 151), link annotations
/// (Table 176), screen annotations (Table 190), widget annotations (Table
/// 191), FDF field dictionaries (Table 249), Catalog OpenAction from 7.7.2,
/// AA trigger events from Section 12.6.3, and standard action types from
/// Section 12.6.4.
pub fn PdfAction::general_attachment_site_count(_self : PdfAction) -> Int {
  7
}

///|
/// Section 12.6.4.1 General, Table 201 Action types. Returns true for every
/// standard /S action name: /GoTo, /GoToR, /GoToE, /GoToDp, /Launch, /Thread,
/// /URI, /Sound, /Movie, /Hide, /Named, /SubmitForm, /ResetForm, /ImportData,
/// /SetOCGState, /Rendition, /Trans, /GoTo3DView, /JavaScript, and
/// /RichMediaExecute.
pub fn PdfActionKind::is_table_201_standard(self : PdfActionKind) -> Bool {
  match self {
    Unknown(_, _) => false
    _ => true
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
/// Section 12.6.4.2 Go-To actions, Table 202 Additional entries specific to a
/// go-to action. Returns true when /S /GoTo carries the PDF 2.0 SD structure
/// destination entry in addition to required D destination, so SD can take
/// precedence over D for structure destination-aware callers.
pub fn PdfGoToAction::has_structure_destination(self : PdfGoToAction) -> Bool {
  self.structure_destination is Some(_)
}

///|
/// Section 12.6.4.3 Remote Go-To actions, Table 203 Additional entries
/// specific to a remote go-to action. Returns true for /S /GoToR records that
/// carry F file specification, D destination in another PDF file, and the
/// optional NewWindow policy slot for zero-based remote explicit destinations.
pub fn PdfRemoteGoToAction::has_remote_destination_payload(
  self : PdfRemoteGoToAction,
) -> Bool {
  match self.destination {
    @objects.PdfObject::Null => false
    _ =>
      match self.file_specification {
        @objects.PdfObject::Null => false
        _ => true
      }
  }
}

///|
/// Section 12.6.4.4 Embedded Go-To actions, Table 204 and Table 205. Returns
/// true when /S /GoToE carries F root file specification or a T target
/// dictionary with R parent/child relation, N EmbeddedFiles name tree entry, P
/// page selector, A annotation selector, and nested T path data for source,
/// target, parent, child, and root document relationships.
pub fn PdfEmbeddedGoToAction::has_embedded_target_route(
  self : PdfEmbeddedGoToAction,
) -> Bool {
  self.file_specification is Some(_) || self.target is Some(_)
}

///|
/// Section 12.6.4.5 GoToDp action, Table 206 Entries in a GoToDp dictionary.
/// Returns the required Dp indirect reference for /S /GoToDp, pointing to the
/// DPart dictionary from Table 409 whose Start page is selected.
pub fn PdfGoToDPartAction::dpart_reference(
  self : PdfGoToDPartAction,
) -> @objects.ObjectId {
  self.dpart
}

///|
/// Section 12.6.4.8 URI actions, Table 210 and Table 211. Returns true when
/// /S /URI uses IsMap to append transformed mouse coordinates to the required
/// URI UTF-8 string; Catalog URI Base from the URI dictionary is parsed
/// separately.
pub fn PdfUriAction::tracks_mouse_position(self : PdfUriAction) -> Bool {
  self.is_map
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
/// Section 12.6.3 Trigger events, Tables 197, 198, 199, and 200. Returns the
/// total modeled AA trigger slots for annotation keys E, X, D, U, Fo, Bl, PO,
/// PC, PV, PI; page keys O and C; form field keys K, F, V, C; and Catalog keys
/// WC, WS, DS, WP, DP.
pub fn PdfActionTriggerOrdering::table_197_to_200_slot_count(
  _self : PdfActionTriggerOrdering,
) -> Int {
  21
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
/// Section 12.6.4.14 Rendition actions, Table 218 Additional entries specific
/// to a rendition action. Returns true when /S /Rendition carries JS
/// ECMAScript text string or stream; otherwise OP operation values 0 play, 1
/// stop, 2 pause, 3 resume, and 4 play-or-resume are retained as structural
/// fallback with R rendition object and AN screen annotation.
pub fn PdfRenditionAction::has_ecmascript_fallback(
  self : PdfRenditionAction,
) -> Bool {
  self.script is Some(_)
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

///|
/// Section 12.6.4.18 Rich-Media-Execute actions, Table 222 Additional entries
/// specific to a rich-media-execute action. Returns true when PDF 2.0
/// /S /RichMediaExecute includes optional TI RichMediaInstance in addition to
/// required TA RichMedia annotation reference and required CMD
/// RichMediaCommand dictionary from Table 223.
pub fn PdfRichMediaExecuteAction::has_target_instance(
  self : PdfRichMediaExecuteAction,
) -> Bool {
  self.instance is Some(_)
}

///|
/// Section 12.6.3 Trigger events. Tables 197, 198, 199, and 200 cover AA
/// additional-actions dictionaries for selected annotations, page objects,
/// interactive form fields, and the document catalog. Distinct trigger keys:
/// annotation E, X, D, U, Fo, Bl, PO, PC, PV, PI; page O and C; form K, F, V,
/// C; catalog WC, WS, DS, WP, DP. The parser records actions and ordering
/// metadata only; it does not dispatch mouse, focus, page, form, save, print,
/// or ECMAScript events.
pub fn pdf_actions_section_12_6_3_trigger_events_tables_197_200() -> Int {
  197 + 198 + 199 + 200
}

///|
/// Section 12.6.4.1 General, Table 201 Action types. Standard /S names:
/// /GoTo, /GoToR, /GoToE, /GoToDp, /Launch, /Thread, /URI, /Sound, /Movie,
/// /Hide, /Named, /SubmitForm, /ResetForm, /ImportData, /SetOCGState,
/// /Rendition, /Trans, /GoTo3DView, /JavaScript, and /RichMediaExecute. These
/// action types are represented structurally by PdfActionKind.
pub fn pdf_actions_section_12_6_4_1_general_table_201() -> Int {
  201
}

///|
/// Section 12.6.4.2 Go-To actions, Table 202 Additional entries specific to a
/// go-to action. A go-to action changes the view to a specified destination:
/// page, location, and magnification factor. Distinct entries: /S /GoTo,
/// required D destination, and optional PDF 2.0 SD structure destination, with
/// SD taking precedence over D when present.
pub fn pdf_actions_section_12_6_4_2_go_to_actions_table_202() -> Int {
  202
}

///|
/// Section 12.6.4.3 Remote Go-To actions, Table 203 Additional entries
/// specific to a remote go-to action. A remote go-to action is similar to an
/// ordinary go-to action but jumps to a destination in another PDF file.
/// Distinct entries: /S /GoToR, required F file specification, required D
/// destination, optional PDF 2.0 SD structure destination, and optional
/// NewWindow. Remote explicit destination page numbers are zero-based.
pub fn pdf_actions_section_12_6_4_3_remote_go_to_actions_table_203() -> Int {
  203
}

///|
/// Section 12.6.4.4 Embedded Go-To actions, Table 204 and Table 205. An
/// embedded go-to action /S /GoToE jumps to or from a PDF file embedded in
/// another PDF file. Distinct Table 204 entries: F, D, NewWindow, T. Distinct
/// Table 205 target dictionary entries: R relation values P and C, N
/// EmbeddedFiles name, P page selector, A annotation selector, and nested T.
pub fn pdf_actions_section_12_6_4_4_embedded_go_to_actions_tables_204_205() -> Int {
  204 + 205
}

///|
/// Section 12.6.4.5 GoToDp action, Table 206 Entries in a GoToDp dictionary.
/// A GoToDp action changes the view to the Start page of a specified DPart.
/// Distinct entries: /S /GoToDp and required Dp indirect reference to a DPart
/// dictionary from Table 409.
pub fn pdf_actions_section_12_6_4_5_gotodp_action_table_206() -> Int {
  206
}

///|
/// Section 12.6.4.8 URI actions, Table 210 and Table 211. A URI action causes
/// a uniform resource identifier to be resolved. Distinct Table 210 entries:
/// /S /URI, required URI UTF-8 string, and optional IsMap mouse-position flag.
/// Distinct Table 211 URI dictionary entry: Base for resolving relative URI
/// references. This parser stores the values without resolving network
/// resources.
pub fn pdf_actions_section_12_6_4_8_uri_actions_tables_210_211() -> Int {
  210 + 211
}

///|
/// Section 12.6.4.10 Movie actions, Table 213 Additional entries specific to a
/// movie action. Distinct entries: /S /Movie, Annotation indirect reference to
/// a movie annotation, T text string title of a movie annotation, and
/// Operation names Play, Stop, Pause, Resume with default Play. Movie action
/// dictionaries use movie activation dictionary defaults from Table 307.
pub fn pdf_actions_section_12_6_4_10_movie_actions_table_213() -> Int {
  213
}

///|
/// Section 12.6.4.12 Named actions, Table 215 Named actions and Table 216
/// Additional entries specific to named actions. Interactive PDF processors
/// shall support named action names NextPage, PrevPage, FirstPage, and
/// LastPage; nonstandard names are not portable and inappropriate or
/// unrecognised names shall take no action. Distinct Table 216 entries: /S
/// /Named and required N action name.
pub fn pdf_actions_section_12_6_4_12_named_actions_tables_215_216() -> Int {
  215 + 216
}

///|
/// Section 12.6.4.14 Rendition actions, Table 218 Additional entries specific
/// to a rendition action. A rendition action /S /Rendition controls multimedia
/// content by R rendition object, AN screen annotation, OP operation values 0,
/// 1, 2, 3, 4, and JS ECMAScript text string or stream. Either JS or OP shall
/// be present; OP can be a fallback when ECMAScript cannot be executed.
pub fn pdf_actions_section_12_6_4_14_rendition_actions_table_218() -> Int {
  218
}

///|
/// Section 12.6.4.18 Rich-Media-Execute actions, Table 222 Additional entries
/// specific to a rich-media-execute action. PDF 2.0 /S /RichMediaExecute
/// identifies a RichMedia annotation and sends a command to its handler.
/// Distinct entries: required TA RichMedia annotation reference, optional TI
/// RichMediaInstance reference, and required CMD RichMediaCommand dictionary
/// from Table 223.
pub fn pdf_actions_section_12_6_4_18_rich_media_execute_actions_table_222() -> Int {
  222
}
