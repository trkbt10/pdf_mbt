///|
fn multimedia_resolve_dictionary_with_owner(
  file : PdfFile,
  value : @objects.PdfObject,
  label : String,
) -> (@objects.ObjectId?, @objects.PdfDictionary) raise PdfDocumentError {
  let (object_id, resolved) = resolve_multimedia_object(file, value, label)
  (object_id, multimedia_dictionary(resolved, object_id, label))
}

///|
fn multimedia_resolve_stream_with_owner(
  file : PdfFile,
  value : @objects.PdfObject,
  label : String,
) -> (@objects.ObjectId?, @objects.PdfStream) raise PdfDocumentError {
  let (object_id, resolved) = resolve_multimedia_object(file, value, label)
  (object_id, multimedia_stream(resolved, object_id, label))
}

///|
fn multimedia_optional_resolved_dict(
  file : PdfFile,
  dict : @objects.PdfDictionary,
  key : @objects.PdfName,
  owner : @objects.ObjectId?,
  label : String,
) -> (@objects.ObjectId?, @objects.PdfDictionary)? raise PdfDocumentError {
  match dict.get(key) {
    Some(value) =>
      Some(multimedia_resolve_dictionary_with_owner(file, value, label))
    None => None
  }
}

///|
fn multimedia_optional_object(
  dict : @objects.PdfDictionary,
  key : @objects.PdfName,
) -> @objects.PdfObject? {
  dict.get(key)
}

///|
fn multimedia_optional_int_default(
  dict : @objects.PdfDictionary,
  key : @objects.PdfName,
  owner : @objects.ObjectId?,
  label : String,
  default : Int,
) -> Int raise PdfDocumentError {
  match dict.get(key) {
    Some(value) => multimedia_int(value, owner, label)
    None => default
  }
}

///|
fn multimedia_optional_name_default(
  dict : @objects.PdfDictionary,
  key : @objects.PdfName,
  owner : @objects.ObjectId?,
  label : String,
  default : Bytes,
) -> @objects.PdfName raise PdfDocumentError {
  match dict.get(key) {
    Some(value) => multimedia_name(value, owner, label)
    None => multimedia_key(default)
  }
}

///|
fn multimedia_dict_array(
  file : PdfFile,
  value : @objects.PdfObject,
  owner : @objects.ObjectId?,
  label : String,
) -> Array[(@objects.ObjectId?, @objects.PdfDictionary)] raise PdfDocumentError {
  let objects = multimedia_array(value, owner, label)
  let result : Array[(@objects.ObjectId?, @objects.PdfDictionary)] = []
  for item in objects {
    result.push(multimedia_resolve_dictionary_with_owner(file, item, label))
  }
  result
}

///|
fn parse_multimedia_common_rendition(
  file : PdfFile,
  object_id : @objects.ObjectId?,
  dict : @objects.PdfDictionary,
) -> PdfRenditionCommon raise PdfDocumentError {
  match dict.get(multimedia_key(b"Type")) {
    Some(value) =>
      require_multimedia_name_equals(
        dict,
        multimedia_key(b"Type"),
        multimedia_key(b"Rendition"),
        object_id,
        "Type",
      )
    None => ()
  }
  ignore(
    require_multimedia_name_value(dict, multimedia_key(b"S"), object_id, "S"),
  )
  PdfRenditionCommon::{
    object_id,
    name: multimedia_optional_string(dict, multimedia_key(b"N"), object_id, "N"),
    must_honor_best_effort: parse_multimedia_mh_be_policy(file, dict, object_id),
    raw_dict: dict,
  }
}

///|
pub fn parse_media_duration(
  file : PdfFile,
  value : @objects.PdfObject,
  owner : @objects.ObjectId?,
) -> PdfMediaDuration raise PdfDocumentError {
  let (_, dict) = multimedia_resolve_dictionary_with_owner(file, value, "D")
  let subtype = require_multimedia_name_value(
    dict,
    multimedia_key(b"S"),
    owner,
    "D.S",
  )
  if subtype == multimedia_key(b"I") {
    PdfMediaDuration::Intrinsic
  } else if subtype == multimedia_key(b"F") {
    PdfMediaDuration::Infinite
  } else if subtype == multimedia_key(b"T") {
    PdfMediaDuration::Seconds(
      multimedia_number(
        multimedia_required(dict, multimedia_key(b"T"), owner, "D.T"),
        owner,
        "D.T",
      ),
    )
  } else {
    PdfMediaDuration::Raw(@objects.PdfObject::Dictionary(dict))
  }
}

///|
pub fn parse_media_offset(
  file : PdfFile,
  value : @objects.PdfObject,
  owner : @objects.ObjectId?,
) -> PdfMediaOffset raise PdfDocumentError {
  let (_, dict) = multimedia_resolve_dictionary_with_owner(
    file, value, "offset",
  )
  let subtype = require_multimedia_name_value(
    dict,
    multimedia_key(b"S"),
    owner,
    "offset.S",
  )
  if subtype == multimedia_key(b"T") {
    PdfMediaOffset::Time(
      multimedia_number(
        multimedia_required(dict, multimedia_key(b"T"), owner, "offset.T"),
        owner,
        "offset.T",
      ),
    )
  } else if subtype == multimedia_key(b"F") {
    let frame = multimedia_int(
      multimedia_required(dict, multimedia_key(b"F"), owner, "offset.F"),
      owner,
      "offset.F",
    )
    if frame < 0 {
      raise multimedia_error(owner, "offset.F is out of range")
    }
    PdfMediaOffset::Frame(frame)
  } else if subtype == multimedia_key(b"M") {
    PdfMediaOffset::Marker(
      multimedia_string(
        multimedia_required(dict, multimedia_key(b"M"), owner, "offset.M"),
        owner,
        "offset.M",
      ),
    )
  } else {
    PdfMediaOffset::Raw(@objects.PdfObject::Dictionary(dict))
  }
}

///|
pub fn parse_timespan(
  file : PdfFile,
  value : @objects.PdfObject,
  owner : @objects.ObjectId?,
) -> PdfTimespan raise PdfDocumentError {
  let (_, dict) = multimedia_resolve_dictionary_with_owner(
    file, value, "timespan",
  )
  let subtype = require_multimedia_name_value(
    dict,
    multimedia_key(b"S"),
    owner,
    "timespan.S",
  )
  PdfTimespan::{
    subtype,
    begin: match dict.get(multimedia_key(b"B")) {
      Some(value) => Some(parse_media_offset(file, value, owner))
      None => None
    },
    end: match dict.get(multimedia_key(b"E")) {
      Some(value) => Some(parse_media_offset(file, value, owner))
      None => None
    },
    raw_dict: dict,
  }
}

///|
pub fn parse_media_permissions(
  file : PdfFile,
  value : @objects.PdfObject,
  owner : @objects.ObjectId?,
) -> PdfMediaPermissions raise PdfDocumentError {
  let (_, dict) = multimedia_resolve_dictionary_with_owner(file, value, "P")
  let tf = multimedia_optional_name_default(
    dict,
    multimedia_key(b"TF"),
    owner,
    "TF",
    b"TEMPNEVER",
  )
  let temp_file = if tf == multimedia_key(b"TEMPALWAYS") {
    PdfTempFilePermission::Always
  } else if tf == multimedia_key(b"TEMPEXTRACT") {
    PdfTempFilePermission::Extract
  } else if tf == multimedia_key(b"TEMPNEVER") {
    PdfTempFilePermission::Never
  } else if tf == multimedia_key(b"TEMPACCESS") {
    PdfTempFilePermission::TempAccess
  } else {
    PdfTempFilePermission::Unknown(tf)
  }
  PdfMediaPermissions::{ temp_file, raw_dict: dict }
}

///|
pub fn parse_media_clip(
  file : PdfFile,
  value : @objects.PdfObject,
) -> PdfMediaClip raise PdfDocumentError {
  let (object_id, dict) = multimedia_resolve_dictionary_with_owner(
    file, value, "media clip",
  )
  let subtype = require_multimedia_name_value(
    dict,
    multimedia_key(b"S"),
    object_id,
    "S",
  )
  let kind = if subtype == multimedia_key(b"MCD") {
    PdfMediaClipKind::Data
  } else if subtype == multimedia_key(b"MCS") {
    PdfMediaClipKind::Section
  } else {
    PdfMediaClipKind::Unknown(subtype)
  }
  let data = multimedia_optional_object(dict, multimedia_key(b"D"))
  if kind == PdfMediaClipKind::Data && data is None {
    raise multimedia_error(object_id, "D is required")
  }
  PdfMediaClip::{
    object_id,
    kind,
    name: multimedia_optional_string(dict, multimedia_key(b"N"), object_id, "N"),
    data,
    permissions: match dict.get(multimedia_key(b"P")) {
      Some(value) => Some(parse_media_permissions(file, value, object_id))
      None => None
    },
    content_type: multimedia_optional_string(
      dict,
      multimedia_key(b"CT"),
      object_id,
      "CT",
    ),
    base_url: multimedia_optional_string(
      dict,
      multimedia_key(b"BU"),
      object_id,
      "BU",
    ),
    section: if kind == PdfMediaClipKind::Section {
      Some(PdfTimespan::{
        subtype,
        begin: match dict.get(multimedia_key(b"B")) {
          Some(value) => Some(parse_media_offset(file, value, object_id))
          None => None
        },
        end: match dict.get(multimedia_key(b"E")) {
          Some(value) => Some(parse_media_offset(file, value, object_id))
          None => None
        },
        raw_dict: dict,
      })
    } else {
      None
    },
    must_honor_best_effort: parse_multimedia_mh_be_policy(file, dict, object_id),
    raw_dict: dict,
  }
}

///|
pub fn parse_media_play_params(
  file : PdfFile,
  value : @objects.PdfObject?,
) -> PdfMediaPlayParams raise PdfDocumentError {
  match value {
    Some(value) => {
      let (object_id, dict) = multimedia_resolve_dictionary_with_owner(
        file, value, "P",
      )
      PdfMediaPlayParams::{
        object_id,
        controls: multimedia_optional_bool_default(
          dict,
          multimedia_key(b"C"),
          object_id,
          "C",
          true,
        ),
        duration: match dict.get(multimedia_key(b"D")) {
          Some(value) => parse_media_duration(file, value, object_id)
          None => PdfMediaDuration::Intrinsic
        },
        repeat: multimedia_optional_number_default(
          dict,
          multimedia_key(b"RC"),
          object_id,
          "RC",
          1.0,
        ),
        volume: multimedia_number_in_range(
          match dict.get(multimedia_key(b"V")) {
            Some(value) => value
            None => @objects.PdfObject::Real(1.0)
          },
          object_id,
          "V",
          -1.0,
          1.0,
        ),
        raw_dict: dict,
      }
    }
    None =>
      PdfMediaPlayParams::{
        object_id: None,
        controls: true,
        duration: PdfMediaDuration::Intrinsic,
        repeat: 1.0,
        volume: 1.0,
        raw_dict: Map::new(),
      }
  }
}

///|
fn parse_monitor_specifier(name : @objects.PdfName) -> PdfMonitorSpecifier {
  if name == multimedia_key(b"L") {
    Largest
  } else if name == multimedia_key(b"S") {
    Smallest
  } else if name == multimedia_key(b"P") {
    Primary
  } else {
    Unknown(name)
  }
}

///|
pub fn parse_media_screen_params(
  file : PdfFile,
  value : @objects.PdfObject?,
) -> PdfMediaScreenParams raise PdfDocumentError {
  match value {
    Some(value) => {
      let (object_id, dict) = multimedia_resolve_dictionary_with_owner(
        file, value, "SP",
      )
      PdfMediaScreenParams::{
        object_id,
        subtype: multimedia_optional_name(
          dict,
          multimedia_key(b"S"),
          object_id,
          "S",
        ),
        monitor: match dict.get(multimedia_key(b"M")) {
          Some(@objects.PdfObject::Integer(index)) =>
            PdfMonitorSpecifier::Monitor(index.to_int())
          Some(value) =>
            parse_monitor_specifier(multimedia_name(value, object_id, "M"))
          None => PdfMonitorSpecifier::Largest
        },
        floating_window: match
          multimedia_optional_resolved_dict(
            file,
            dict,
            multimedia_key(b"F"),
            object_id,
            "F",
          ) {
          Some((_, raw_dict)) => Some(PdfFloatingWindowParams::{ raw_dict, })
          None => None
        },
        raw_dict: dict,
      }
    }
    None =>
      PdfMediaScreenParams::{
        object_id: None,
        subtype: None,
        monitor: PdfMonitorSpecifier::Largest,
        floating_window: None,
        raw_dict: Map::new(),
      }
  }
}

///|
pub fn parse_rendition(
  file : PdfFile,
  value : @objects.PdfObject,
) -> PdfRendition raise PdfDocumentError {
  let (object_id, dict) = multimedia_resolve_dictionary_with_owner(
    file, value, "rendition",
  )
  let common = parse_multimedia_common_rendition(file, object_id, dict)
  let subtype = require_multimedia_name_value(
    dict,
    multimedia_key(b"S"),
    object_id,
    "S",
  )
  if subtype == multimedia_key(b"MR") {
    PdfRendition::Media(PdfMediaRendition::{
      common,
      media_clip: match dict.get(multimedia_key(b"C")) {
        Some(value) => Some(parse_media_clip(file, value))
        None => None
      },
      play_params: parse_media_play_params(file, dict.get(multimedia_key(b"P"))),
      screen_params: parse_media_screen_params(
        file,
        dict.get(multimedia_key(b"SP")),
      ),
    })
  } else if subtype == multimedia_key(b"SR") {
    let values = match dict.get(multimedia_key(b"R")) {
      Some(value) => multimedia_array(value, object_id, "R")
      None => []
    }
    let renditions : Array[PdfRendition] = []
    for item in values {
      renditions.push(parse_rendition(file, item))
    }
    PdfRendition::Selector(PdfSelectorRendition::{ common, renditions })
  } else {
    raise multimedia_error(object_id, "S has invalid name")
  }
}

///|
fn parse_software_name_uri(value : Bytes) -> PdfSoftwareNameUri {
  let scheme_prefix = b"vnd.adobe.swname:"
  let mut matches_prefix = value.length() > scheme_prefix.length()
  if matches_prefix {
    for index in 0..<scheme_prefix.length() {
      if multimedia_ascii_lower(value[index]) != scheme_prefix[index] {
        matches_prefix = false
      }
    }
  }
  if matches_prefix {
    let name = value[scheme_prefix.length():].to_bytes()
    PdfSoftwareNameUri::{ scheme: Some(b"vnd.adobe.swname"), name, raw: value }
  } else {
    PdfSoftwareNameUri::{ scheme: None, name: value, raw: value }
  }
}

///|
fn parse_version_array(
  value : @objects.PdfObject,
  owner : @objects.ObjectId?,
  label : String,
) -> PdfVersionArray raise PdfDocumentError {
  let values = multimedia_array(value, owner, label)
  let components : Array[Int] = []
  for item in values {
    let component = multimedia_int(item, owner, label)
    if component < 0 {
      raise multimedia_error(owner, label + " contains a negative component")
    }
    components.push(component)
  }
  PdfVersionArray::{ components, is_infinite: components.length() == 0 }
}

///|
pub fn parse_software_identifier(
  file : PdfFile,
  value : @objects.PdfObject,
) -> PdfSoftwareIdentifier raise PdfDocumentError {
  let (object_id, dict) = multimedia_resolve_dictionary_with_owner(
    file, value, "software identifier",
  )
  let names : Array[PdfSoftwareNameUri] = []
  match dict.get(multimedia_key(b"U")) {
    Some(@objects.PdfObject::Array(values)) =>
      for item in values {
        names.push(
          parse_software_name_uri(multimedia_string(item, object_id, "U")),
        )
      }
    Some(value) =>
      names.push(
        parse_software_name_uri(multimedia_string(value, object_id, "U")),
      )
    None => raise multimedia_error(object_id, "U is required")
  }
  let operating_systems : Array[Bytes] = []
  match dict.get(multimedia_key(b"OS")) {
    Some(value) =>
      for item in multimedia_array(value, object_id, "OS") {
        operating_systems.push(multimedia_string(item, object_id, "OS"))
      }
    None => ()
  }
  PdfSoftwareIdentifier::{
    names,
    operating_systems,
    lower_version: match dict.get(multimedia_key(b"L")) {
      Some(value) => Some(parse_version_array(value, object_id, "L"))
      None => None
    },
    upper_version: match dict.get(multimedia_key(b"H")) {
      Some(value) => Some(parse_version_array(value, object_id, "H"))
      None => None
    },
    lower_inclusive: multimedia_optional_bool_default(
      dict,
      multimedia_key(b"LI"),
      object_id,
      "LI",
      true,
    ),
    upper_inclusive: multimedia_optional_bool_default(
      dict,
      multimedia_key(b"HI"),
      object_id,
      "HI",
      true,
    ),
    raw_dict: dict,
  }
}

///|
pub fn parse_media_player_info(
  file : PdfFile,
  value : @objects.PdfObject,
) -> PdfMediaPlayerInfo raise PdfDocumentError {
  let (object_id, dict) = multimedia_resolve_dictionary_with_owner(
    file, value, "media player info",
  )
  let ids : Array[PdfSoftwareIdentifier] = []
  for
    item in multimedia_array(
      multimedia_required(dict, multimedia_key(b"PID"), object_id, "PID"),
      object_id,
      "PID",
    ) {
    ids.push(parse_software_identifier(file, item))
  }
  PdfMediaPlayerInfo::{
    software_identifiers: ids,
    must_honor_best_effort: parse_multimedia_mh_be_policy(file, dict, object_id),
    raw_dict: dict,
  }
}

///|
pub fn parse_media_player_policy(
  file : PdfFile,
  value : @objects.PdfObject,
) -> PdfMediaPlayerPolicy raise PdfDocumentError {
  let (object_id, dict) = multimedia_resolve_dictionary_with_owner(
    file, value, "media players",
  )
  fn parse_infos(
    file : PdfFile,
    value : @objects.PdfObject?,
    object_id : @objects.ObjectId?,
    label : String,
  ) -> Array[PdfMediaPlayerInfo] raise PdfDocumentError {
    let infos : Array[PdfMediaPlayerInfo] = []
    match value {
      Some(value) =>
        for item in multimedia_array(value, object_id, label) {
          infos.push(parse_media_player_info(file, item))
        }
      None => ()
    }
    infos
  }
  PdfMediaPlayerPolicy::{
    must_use: parse_infos(
      file,
      dict.get(multimedia_key(b"MU")),
      object_id,
      "MU",
    ),
    allowed: parse_infos(file, dict.get(multimedia_key(b"A")), object_id, "A"),
    not_allowed: parse_infos(
      file,
      dict.get(multimedia_key(b"NU")),
      object_id,
      "NU",
    ),
    raw_dict: dict,
  }
}

///|
pub fn evaluate_rendition_viability(
  rendition : PdfRendition,
  player : PdfSoftwareIdentity?,
) -> PdfViabilityReport {
  let trace : Array[PdfViabilityTraceEntry] = []
  match rendition {
    Media(media) => {
      if media.common.must_honor_best_effort.must_honor is Some(dict) {
        for key, _ in dict {
          trace.push(PdfViabilityTraceEntry::{
            key: Some(key),
            decision: PdfViabilityDecision::NonViable("unknown MH key"),
            reason: "unknown MH key",
          })
          return PdfViabilityReport::{
            decision: PdfViabilityDecision::NonViable("unknown MH key"),
            trace,
          }
        }
      }
      match player {
        Some(_) =>
          PdfViabilityReport::{ decision: PdfViabilityDecision::Viable, trace }
        None =>
          PdfViabilityReport::{
            decision: PdfViabilityDecision::Unknown("environment is unknown"),
            trace,
          }
      }
    }
    Selector(selector) => {
      for child in selector.renditions {
        let report = evaluate_rendition_viability(child, player)
        if report.decision == PdfViabilityDecision::Viable {
          return report
        }
      }
      PdfViabilityReport::{
        decision: PdfViabilityDecision::NonViable("no viable selector child"),
        trace,
      }
    }
    Unknown(_) =>
      PdfViabilityReport::{
        decision: PdfViabilityDecision::NonViable("unknown rendition subtype"),
        trace,
      }
  }
}

///|
pub fn parse_sound_object(
  file : PdfFile,
  value : @objects.PdfObject,
) -> PdfSoundObject raise PdfDocumentError {
  let (object_id, stream) = multimedia_resolve_stream_with_owner(
    file, value, "sound",
  )
  PdfSoundObject::{
    object_id,
    sampling_rate: multimedia_optional_number_default(
      stream.dict,
      multimedia_key(b"R"),
      object_id,
      "R",
      8000.0,
    ),
    channels: multimedia_optional_int_default(
      stream.dict,
      multimedia_key(b"C"),
      object_id,
      "C",
      1,
    ),
    bits_per_sample: multimedia_optional_int_default(
      stream.dict,
      multimedia_key(b"B"),
      object_id,
      "B",
      8,
    ),
    encoding: multimedia_optional_name_default(
      stream.dict,
      multimedia_key(b"E"),
      object_id,
      "E",
      b"Raw",
    ),
    compression: multimedia_optional_name(
      stream.dict,
      multimedia_key(b"CO"),
      object_id,
      "CO",
    ),
    raw_stream: stream,
  }
}

///|
pub fn parse_movie_activation(
  dict : @objects.PdfDictionary,
  owner : @objects.ObjectId?,
) -> PdfMovieActivation raise PdfDocumentError {
  let mode_name = multimedia_optional_name_default(
    dict,
    multimedia_key(b"Mode"),
    owner,
    "Mode",
    b"Once",
  )
  let mode = if mode_name == multimedia_key(b"Once") {
    PdfMovieActivationMode::Once
  } else if mode_name == multimedia_key(b"Open") {
    Open
  } else if mode_name == multimedia_key(b"Repeat") {
    Repeat
  } else if mode_name == multimedia_key(b"Palindrome") {
    Palindrome
  } else {
    Unknown(mode_name)
  }
  PdfMovieActivation::{
    start: dict.get(multimedia_key(b"Start")),
    duration: dict.get(multimedia_key(b"Duration")),
    rate: multimedia_optional_number_default(
      dict,
      multimedia_key(b"Rate"),
      owner,
      "Rate",
      1.0,
    ),
    volume: multimedia_optional_number_default(
      dict,
      multimedia_key(b"Volume"),
      owner,
      "Volume",
      1.0,
    ),
    mode,
    raw_dict: dict,
  }
}

///|
pub fn parse_movie_dictionary(
  file : PdfFile,
  value : @objects.PdfObject,
) -> PdfMovieDictionary raise PdfDocumentError {
  let (object_id, dict) = multimedia_resolve_dictionary_with_owner(
    file, value, "movie",
  )
  let aspect : Array[Int] = []
  match dict.get(multimedia_key(b"Aspect")) {
    Some(value) => {
      let values = multimedia_array(value, object_id, "Aspect")
      if values.length() != 2 {
        raise multimedia_error(object_id, "Aspect has invalid length")
      }
      for item in values {
        aspect.push(multimedia_int(item, object_id, "Aspect"))
      }
    }
    None => ()
  }
  PdfMovieDictionary::{
    object_id,
    file_specification: multimedia_required(
      dict,
      multimedia_key(b"F"),
      object_id,
      "F",
    ),
    aspect,
    rotation: multimedia_optional_int_default(
      dict,
      multimedia_key(b"Rotate"),
      object_id,
      "Rotate",
      0,
    ),
    poster: dict.get(multimedia_key(b"Poster")),
    activation: match
      multimedia_optional_resolved_dict(
        file,
        dict,
        multimedia_key(b"A"),
        object_id,
        "A",
      ) {
      Some((_, value)) => Some(parse_movie_activation(value, object_id))
      None => None
    },
    raw_dict: dict,
  }
}

///|
pub fn parse_slideshow(
  file : PdfFile,
  value : @objects.PdfObject,
) -> PdfSlideShow raise PdfDocumentError {
  let (object_id, dict) = multimedia_resolve_dictionary_with_owner(
    file, value, "slideshow",
  )
  require_multimedia_name_equals(
    dict,
    multimedia_key(b"Type"),
    multimedia_key(b"SlideShow"),
    object_id,
    "Type",
  )
  require_multimedia_name_equals(
    dict,
    multimedia_key(b"Subtype"),
    multimedia_key(b"Embedded"),
    object_id,
    "Subtype",
  )
  PdfSlideShow::{
    object_id,
    start_resource: multimedia_string(
      multimedia_required(
        dict,
        multimedia_key(b"StartResource"),
        object_id,
        "StartResource",
      ),
      object_id,
      "StartResource",
    ),
    resources: dict.get(multimedia_key(b"Resources")),
    raw_dict: dict,
  }
}

///|
pub fn PdfDocument::alternate_presentations(
  self : PdfDocument,
) -> Array[PdfAlternatePresentation] raise PdfDocumentError {
  let entries = self.name_tree_entries(NameTreeCategory::AlternatePresentations)
  let result : Array[PdfAlternatePresentation] = []
  for entry in entries {
    result.push(PdfAlternatePresentation::{
      name: entry.key,
      slideshow: parse_slideshow(self.file, entry.value),
      raw_value: entry.value,
    })
  }
  result
}

///|
fn parse_three_d_view_from_dict(
  file : PdfFile,
  object_id : @objects.ObjectId?,
  dict : @objects.PdfDictionary,
) -> PdfThreeDView raise PdfDocumentError {
  PdfThreeDView::{
    object_id,
    name: match dict.get(multimedia_key(b"IN")) {
      Some(value) => Some(multimedia_string(value, object_id, "IN"))
      None =>
        multimedia_optional_string(dict, multimedia_key(b"XN"), object_id, "XN")
    },
    camera_to_world: match dict.get(multimedia_key(b"C2W")) {
      Some(value) => Some(parse_multimedia_matrix(value, object_id, "C2W"))
      None => None
    },
    center_of_orbit: match dict.get(multimedia_key(b"CO")) {
      Some(value) => Some(parse_multimedia_vector(value, object_id, "CO"))
      None => None
    },
    projection: match
      multimedia_optional_resolved_dict(
        file,
        dict,
        multimedia_key(b"P"),
        object_id,
        "P",
      ) {
      Some((_, proj)) => {
        let subtype = require_multimedia_name_value(
          proj,
          multimedia_key(b"Subtype"),
          object_id,
          "P.Subtype",
        )
        Some(
          if subtype == multimedia_key(b"P") {
            PdfThreeDProjection::Perspective(proj)
          } else if subtype == multimedia_key(b"O") {
            Orthographic(proj)
          } else {
            Unknown(subtype, proj)
          },
        )
      }
      None => None
    },
    raw_dict: dict,
  }
}

///|
pub fn parse_three_d_view(
  file : PdfFile,
  value : @objects.PdfObject,
) -> PdfThreeDView raise PdfDocumentError {
  let (object_id, dict) = multimedia_resolve_dictionary_with_owner(
    file, value, "3D view",
  )
  parse_three_d_view_from_dict(file, object_id, dict)
}

///|
pub fn parse_three_d_stream(
  file : PdfFile,
  value : @objects.PdfObject,
) -> PdfThreeDStream raise PdfDocumentError {
  let (object_id, stream) = multimedia_resolve_stream_with_owner(
    file, value, "3D stream",
  )
  let views : Array[PdfThreeDView] = []
  match stream.dict.get(multimedia_key(b"VA")) {
    Some(value) =>
      for view_payload in multimedia_dict_array(file, value, object_id, "VA") {
        let (view_id, view_dict) = view_payload
        views.push(parse_three_d_view_from_dict(file, view_id, view_dict))
      }
    None => ()
  }
  PdfThreeDStream::{
    object_id,
    subtype: multimedia_optional_name(
      stream.dict,
      multimedia_key(b"Subtype"),
      object_id,
      "Subtype",
    ),
    views,
    raw_stream: stream,
  }
}

///|
pub fn parse_three_d_reference(
  file : PdfFile,
  value : @objects.PdfObject,
) -> PdfThreeDReference raise PdfDocumentError {
  let (object_id, dict) = multimedia_resolve_dictionary_with_owner(
    file, value, "3D reference",
  )
  PdfThreeDReference::{
    object_id,
    target: multimedia_required(dict, multimedia_key(b"3DD"), object_id, "3DD"),
    raw_dict: dict,
  }
}

///|
fn parse_three_d_artwork(
  file : PdfFile,
  value : @objects.PdfObject,
) -> PdfThreeDArtworkSource raise PdfDocumentError {
  let (_, resolved) = resolve_multimedia_object(file, value, "3DD")
  match resolved {
    @objects.PdfObject::Stream(_) =>
      PdfThreeDArtworkSource::Stream(parse_three_d_stream(file, value))
    @objects.PdfObject::Dictionary(dict) =>
      if dict.get(multimedia_key(b"Type")) ==
        Some(@objects.PdfObject::Name(multimedia_key(b"3DRef"))) {
        PdfThreeDArtworkSource::Reference(
          parse_three_d_reference(file, @objects.PdfObject::Dictionary(dict)),
        )
      } else {
        PdfThreeDArtworkSource::Raw(@objects.PdfObject::Dictionary(dict))
      }
    _ => PdfThreeDArtworkSource::Raw(resolved)
  }
}

///|
pub fn parse_three_d_annotation(
  file : PdfFile,
  value : @objects.PdfObject,
) -> PdfThreeDAnnotation? raise PdfDocumentError {
  let (object_id, dict) = multimedia_resolve_dictionary_with_owner(
    file, value, "3D annotation",
  )
  match dict.get(multimedia_key(b"Subtype")) {
    Some(@objects.PdfObject::Name(name)) if name == multimedia_key(b"3D") => ()
    _ => return None
  }
  PdfThreeDAnnotation::{
    object_id,
    artwork: parse_three_d_artwork(
      file,
      multimedia_required(dict, multimedia_key(b"3DD"), object_id, "3DD"),
    ),
    default_view: dict.get(multimedia_key(b"3DV")),
    activation: match
      multimedia_optional_resolved_dict(
        file,
        dict,
        multimedia_key(b"3DA"),
        object_id,
        "3DA",
      ) {
      Some((_, value)) => Some(value)
      None => None
    },
    raw_dict: dict,
  }
  |> Some
}

///|
fn richmedia_asset_name_valid(name : Bytes) -> Bool {
  if name.length() == 0 {
    return false
  }
  if name[name.length() - 1] == b'.' {
    return false
  }
  for byte in name {
    if byte == 0 || byte == b'/' || byte == b'\\' {
      return false
    }
  }
  true
}

///|
pub fn parse_richmedia_assets(
  _file : PdfFile,
  names_value : @objects.PdfObject,
  owner : @objects.ObjectId?,
) -> Array[PdfRichMediaAsset] raise PdfDocumentError {
  let values = multimedia_array(names_value, owner, "Assets.Names")
  if values.length() % 2 != 0 {
    raise multimedia_error(owner, "Assets.Names has invalid length")
  }
  let assets : Array[PdfRichMediaAsset] = []
  let mut index = 0
  while index < values.length() {
    let name = multimedia_string(values[index], owner, "Assets name")
    assets.push(PdfRichMediaAsset::{
      name,
      file_specification: values[index + 1],
      valid_name: richmedia_asset_name_valid(name),
    })
    index += 2
  }
  assets
}

///|
pub fn parse_richmedia_view_params(
  file : PdfFile,
  value : @objects.PdfObject,
) -> PdfRichMediaViewParams raise PdfDocumentError {
  let (object_id, dict) = multimedia_resolve_dictionary_with_owner(
    file, value, "RichMediaParams",
  )
  PdfRichMediaViewParams::{
    object_id,
    binding: multimedia_optional_name(
      dict,
      multimedia_key(b"Binding"),
      object_id,
      "Binding",
    ),
    data: dict.get(multimedia_key(b"Data")),
    raw_dict: dict,
  }
}

///|
pub fn parse_richmedia_instance(
  file : PdfFile,
  value : @objects.PdfObject,
) -> PdfRichMediaInstance raise PdfDocumentError {
  let (object_id, dict) = multimedia_resolve_dictionary_with_owner(
    file, value, "RichMediaInstance",
  )
  PdfRichMediaInstance::{
    object_id,
    subtype: multimedia_optional_name(
      dict,
      multimedia_key(b"Subtype"),
      object_id,
      "Subtype",
    ),
    asset: dict.get(multimedia_key(b"Asset")),
    params: match dict.get(multimedia_key(b"Params")) {
      Some(value) => Some(parse_richmedia_view_params(file, value))
      None => None
    },
    raw_dict: dict,
  }
}

///|
pub fn parse_richmedia_configuration(
  file : PdfFile,
  value : @objects.PdfObject,
) -> PdfRichMediaConfiguration raise PdfDocumentError {
  let (object_id, dict) = multimedia_resolve_dictionary_with_owner(
    file, value, "RichMediaConfiguration",
  )
  let instances : Array[PdfRichMediaInstance] = []
  match dict.get(multimedia_key(b"Instances")) {
    Some(value) =>
      for item in multimedia_array(value, object_id, "Instances") {
        instances.push(parse_richmedia_instance(file, item))
      }
    None => ()
  }
  PdfRichMediaConfiguration::{
    object_id,
    subtype: multimedia_optional_name(
      dict,
      multimedia_key(b"Subtype"),
      object_id,
      "Subtype",
    ),
    instances,
    raw_dict: dict,
  }
}

///|
pub fn parse_richmedia_view(
  file : PdfFile,
  value : @objects.PdfObject,
) -> PdfRichMediaView raise PdfDocumentError {
  let (object_id, dict) = multimedia_resolve_dictionary_with_owner(
    file, value, "RichMediaView",
  )
  PdfRichMediaView::{
    object_id,
    name: multimedia_optional_string(
      dict,
      multimedia_key(b"Name"),
      object_id,
      "Name",
    ),
    params: match dict.get(multimedia_key(b"Params")) {
      Some(value) => Some(parse_richmedia_view_params(file, value))
      None => None
    },
    snapshot: dict.get(multimedia_key(b"Snapshot")),
    raw_dict: dict,
  }
}

///|
pub fn parse_richmedia_content(
  file : PdfFile,
  value : @objects.PdfObject,
) -> PdfRichMediaContent raise PdfDocumentError {
  let (object_id, dict) = multimedia_resolve_dictionary_with_owner(
    file, value, "RichMediaContent",
  )
  let assets : Array[PdfRichMediaAsset] = []
  match
    multimedia_optional_resolved_dict(
      file,
      dict,
      multimedia_key(b"Assets"),
      object_id,
      "Assets",
    ) {
    Some((_, asset_tree)) =>
      match asset_tree.get(multimedia_key(b"Names")) {
        Some(names) =>
          for asset in parse_richmedia_assets(file, names, object_id) {
            assets.push(asset)
          }
        None => ()
      }
    None => ()
  }
  let configurations : Array[PdfRichMediaConfiguration] = []
  match dict.get(multimedia_key(b"Configurations")) {
    Some(value) =>
      for item in multimedia_array(value, object_id, "Configurations") {
        configurations.push(parse_richmedia_configuration(file, item))
      }
    None => ()
  }
  let views : Array[PdfRichMediaView] = []
  match dict.get(multimedia_key(b"Views")) {
    Some(value) =>
      for item in multimedia_array(value, object_id, "Views") {
        views.push(parse_richmedia_view(file, item))
      }
    None => ()
  }
  PdfRichMediaContent::{
    object_id,
    assets,
    configurations,
    views,
    raw_dict: dict,
  }
}

///|
pub fn parse_richmedia_animation(
  dict : @objects.PdfDictionary,
  owner : @objects.ObjectId?,
) -> PdfRichMediaAnimation raise PdfDocumentError {
  PdfRichMediaAnimation::{
    subtype: multimedia_optional_name_default(
      dict,
      multimedia_key(b"Subtype"),
      owner,
      "Subtype",
      b"Linear",
    ),
    play_count: multimedia_optional_int_default(
      dict,
      multimedia_key(b"PlayCount"),
      owner,
      "PlayCount",
      -1,
    ),
    speed: multimedia_optional_number_default(
      dict,
      multimedia_key(b"Speed"),
      owner,
      "Speed",
      1.0,
    ),
    raw_dict: dict,
  }
}

///|
fn parse_richmedia_window_dimension(
  value : @objects.PdfObject?,
  owner : @objects.ObjectId?,
  label : String,
) -> PdfRichMediaWindowDimension raise PdfDocumentError {
  match value {
    Some(@objects.PdfObject::Array(values)) => {
      if values.length() != 3 {
        raise multimedia_error(owner, label + " has invalid length")
      }
      PdfRichMediaWindowDimension::{
        default_value: multimedia_number(values[0], owner, label),
        min: multimedia_number(values[1], owner, label),
        max: multimedia_number(values[2], owner, label),
      }
    }
    Some(value) => {
      let n = multimedia_number(value, owner, label)
      PdfRichMediaWindowDimension::{ default_value: n, min: n, max: n }
    }
    None =>
      PdfRichMediaWindowDimension::{ default_value: 0.0, min: 0.0, max: 0.0 }
  }
}

///|
pub fn parse_richmedia_presentation(
  file : PdfFile,
  value : @objects.PdfObject,
) -> PdfRichMediaPresentation raise PdfDocumentError {
  let (object_id, dict) = multimedia_resolve_dictionary_with_owner(
    file, value, "RichMediaPresentation",
  )
  PdfRichMediaPresentation::{
    style: multimedia_optional_name_default(
      dict,
      multimedia_key(b"Style"),
      object_id,
      "Style",
      b"Embedded",
    ),
    window: match
      multimedia_optional_resolved_dict(
        file,
        dict,
        multimedia_key(b"Window"),
        object_id,
        "Window",
      ) {
      Some((_, window)) =>
        Some(PdfRichMediaWindow::{
          width: parse_richmedia_window_dimension(
            window.get(multimedia_key(b"Width")),
            object_id,
            "Width",
          ),
          height: parse_richmedia_window_dimension(
            window.get(multimedia_key(b"Height")),
            object_id,
            "Height",
          ),
          position: None,
          raw_dict: window,
        })
      None => None
    },
    transparent: multimedia_optional_bool_default(
      dict,
      multimedia_key(b"Transparent"),
      object_id,
      "Transparent",
      false,
    ),
    navigation_pane: multimedia_optional_bool_default(
      dict,
      multimedia_key(b"NavigationPane"),
      object_id,
      "NavigationPane",
      false,
    ),
    toolbar: match dict.get(multimedia_key(b"Toolbar")) {
      Some(value) => Some(multimedia_bool(value, object_id, "Toolbar"))
      None => None
    },
    pass_context_click: multimedia_optional_bool_default(
      dict,
      multimedia_key(b"PassContextClick"),
      object_id,
      "PassContextClick",
      false,
    ),
    raw_dict: dict,
  }
}

///|
pub fn parse_richmedia_settings(
  file : PdfFile,
  value : @objects.PdfObject?,
) -> PdfRichMediaSettings raise PdfDocumentError {
  match value {
    Some(value) => {
      let (object_id, dict) = multimedia_resolve_dictionary_with_owner(
        file, value, "RichMediaSettings",
      )
      PdfRichMediaSettings::{
        object_id,
        activation: match
          multimedia_optional_resolved_dict(
            file,
            dict,
            multimedia_key(b"Activation"),
            object_id,
            "Activation",
          ) {
          Some((_, value)) => Some(value)
          None => None
        },
        deactivation: match
          multimedia_optional_resolved_dict(
            file,
            dict,
            multimedia_key(b"Deactivation"),
            object_id,
            "Deactivation",
          ) {
          Some((_, value)) => Some(value)
          None => None
        },
        raw_dict: dict,
      }
    }
    None =>
      PdfRichMediaSettings::{
        object_id: None,
        activation: None,
        deactivation: None,
        raw_dict: Map::new(),
      }
  }
}

///|
pub fn parse_richmedia_annotation(
  file : PdfFile,
  value : @objects.PdfObject,
) -> PdfRichMediaAnnotation? raise PdfDocumentError {
  let (object_id, dict) = multimedia_resolve_dictionary_with_owner(
    file, value, "RichMedia annotation",
  )
  match dict.get(multimedia_key(b"Subtype")) {
    Some(@objects.PdfObject::Name(name)) if name == multimedia_key(b"RichMedia") =>
      ()
    _ => return None
  }
  PdfRichMediaAnnotation::{
    object_id,
    content: parse_richmedia_content(
      file,
      multimedia_required(
        dict,
        multimedia_key(b"RichMediaContent"),
        object_id,
        "RichMediaContent",
      ),
    ),
    settings: parse_richmedia_settings(
      file,
      dict.get(multimedia_key(b"RichMediaSettings")),
    ),
    raw_dict: dict,
  }
  |> Some
}

///|
pub fn parse_multimedia_object(
  file : PdfFile,
  value : @objects.PdfObject,
) -> PdfMultimediaObject raise PdfDocumentError {
  let (_, resolved) = resolve_multimedia_object(
    file, value, "multimedia object",
  )
  match resolved {
    @objects.PdfObject::Stream(stream) =>
      if stream.dict.get(multimedia_key(b"Subtype")) ==
        Some(@objects.PdfObject::Name(multimedia_key(b"U3D"))) ||
        stream.dict.get(multimedia_key(b"Subtype")) ==
        Some(@objects.PdfObject::Name(multimedia_key(b"PRC"))) {
        PdfMultimediaObject::ThreeDStream(parse_three_d_stream(file, value))
      } else {
        PdfMultimediaObject::RawStream(PdfRawStreamPayload::{
          object_id: None,
          raw_stream: stream,
        })
      }
    @objects.PdfObject::Dictionary(dict) =>
      match dict.get(multimedia_key(b"Type")) {
        Some(@objects.PdfObject::Name(name)) if name ==
          multimedia_key(b"Rendition") =>
          PdfMultimediaObject::Rendition(parse_rendition(file, value))
        Some(@objects.PdfObject::Name(name)) if name ==
          multimedia_key(b"MediaClip") =>
          PdfMultimediaObject::MediaClip(parse_media_clip(file, value))
        Some(@objects.PdfObject::Name(name)) if name == multimedia_key(b"Movie") =>
          PdfMultimediaObject::Movie(parse_movie_dictionary(file, value))
        Some(@objects.PdfObject::Name(name)) if name ==
          multimedia_key(b"RichMediaContent") =>
          PdfMultimediaObject::RichMediaContent(
            parse_richmedia_content(file, value),
          )
        _ =>
          PdfMultimediaObject::RawDictionary(PdfRawDictionaryPayload::{
            object_id: None,
            raw_dict: dict,
          })
      }
    _ =>
      PdfMultimediaObject::RawDictionary(PdfRawDictionaryPayload::{
        object_id: None,
        raw_dict: Map::new(),
      })
  }
}

///|
pub fn parse_multimedia_annotation(
  file : PdfFile,
  annotation : PdfAnnotation,
) -> PdfMultimediaAnnotation? raise PdfDocumentError {
  match annotation.specific {
    Sound(sound) =>
      Some(
        PdfMultimediaAnnotation::Sound(parse_sound_object(file, sound.sound)),
      )
    Movie(movie) =>
      Some(
        PdfMultimediaAnnotation::Movie(
          parse_movie_dictionary(file, movie.movie),
        ),
      )
    ThreeDRaw(raw) =>
      Some(
        PdfMultimediaAnnotation::ThreeD(
          match
            parse_three_d_annotation(
              file,
              @objects.PdfObject::Dictionary(raw.raw_dict),
            ) {
            Some(value) => value
            None => return None
          },
        ),
      )
    RichMediaRaw(raw) =>
      Some(
        PdfMultimediaAnnotation::RichMedia(
          match
            parse_richmedia_annotation(
              file,
              @objects.PdfObject::Dictionary(raw.raw_dict),
            ) {
            Some(value) => value
            None => return None
          },
        ),
      )
    _ => None
  }
}
