///|
fn parse_sound_action(
  object_id : @objects.ObjectId?,
  action_name : @objects.PdfName,
  dict : @objects.PdfDictionary,
) -> PdfSoundAction raise PdfDocumentError {
  let sound = action_required_raw(
    dict,
    action_key(b"Sound"),
    object_id,
    action_name,
  )
  match sound {
    @objects.PdfObject::Stream(_) | @objects.PdfObject::Ref(_) => ()
    _ =>
      raise action_error(
        object_id,
        Some(action_name),
        "Sound must be a stream or stream reference",
      )
  }
  PdfSoundAction::{
    sound,
    volume: match dict.get(action_key(b"Volume")) {
      Some(value) => action_number(value, object_id, action_name, "Volume")
      None => 1.0
    },
    synchronous: action_optional_bool(
      dict,
      action_key(b"Synchronous"),
      object_id,
      action_name,
      false,
    ),
    repeat: action_optional_bool(
      dict,
      action_key(b"Repeat"),
      object_id,
      action_name,
      false,
    ),
    mix: action_optional_bool(
      dict,
      action_key(b"Mix"),
      object_id,
      action_name,
      false,
    ),
    raw_dict: dict,
  }
}

///|
fn parse_movie_action(
  object_id : @objects.ObjectId?,
  action_name : @objects.PdfName,
  dict : @objects.PdfDictionary,
) -> PdfMovieAction raise PdfDocumentError {
  let annotation = dict.get(action_key(b"Annotation"))
  let title = match dict.get(action_key(b"T")) {
    Some(value) => Some(action_string(value, object_id, action_name, "T"))
    None => None
  }
  let target = match (annotation, title) {
    (Some(value), None) => PdfMovieTarget::Annotation(value)
    (None, Some(value)) => PdfMovieTarget::Title(value)
    (Some(_), Some(_)) =>
      raise action_error(
        object_id,
        Some(action_name),
        "Movie Annotation and T are mutually exclusive",
      )
    (None, None) =>
      raise action_error(
        object_id,
        Some(action_name),
        "Movie requires Annotation or T",
      )
  }
  PdfMovieAction::{
    target,
    operation: match dict.get(action_key(b"Operation")) {
      Some(value) =>
        parse_movie_operation(
          action_name_value(value, object_id, action_name, "Operation"),
        )
      None => PdfMovieOperation::Play
    },
    raw_dict: dict,
  }
}

///|
fn parse_movie_operation(name : @objects.PdfName) -> PdfMovieOperation {
  if name == action_key(b"Play") {
    PdfMovieOperation::Play
  } else if name == action_key(b"Stop") {
    PdfMovieOperation::Stop
  } else if name == action_key(b"Pause") {
    PdfMovieOperation::Pause
  } else if name == action_key(b"Resume") {
    PdfMovieOperation::Resume
  } else {
    PdfMovieOperation::Unknown(name)
  }
}

///|
fn parse_hide_action(
  object_id : @objects.ObjectId?,
  action_name : @objects.PdfName,
  dict : @objects.PdfDictionary,
) -> PdfHideAction raise PdfDocumentError {
  let target_value = action_required_raw(
    dict,
    action_key(b"T"),
    object_id,
    action_name,
  )
  let target = match target_value {
    @objects.PdfObject::Array(values) => PdfHideTarget::Array(values)
    @objects.PdfObject::String(_)
    | @objects.PdfObject::Dictionary(_)
    | @objects.PdfObject::Ref(_) => PdfHideTarget::Single(target_value)
    _ =>
      raise action_error(
        object_id,
        Some(action_name),
        "Hide T has unsupported shape",
      )
  }
  PdfHideAction::{
    target,
    hide: action_optional_bool(
      dict,
      action_key(b"H"),
      object_id,
      action_name,
      true,
    ),
    raw_dict: dict,
  }
}

///|
fn parse_named_action(
  object_id : @objects.ObjectId?,
  action_name : @objects.PdfName,
  dict : @objects.PdfDictionary,
) -> PdfNamedAction raise PdfDocumentError {
  PdfNamedAction::{
    name: action_name_value(
      action_required_raw(dict, action_key(b"N"), object_id, action_name),
      object_id,
      action_name,
      "N",
    ),
    raw_dict: dict,
  }
}

///|
fn parse_rendition_action(
  object_id : @objects.ObjectId?,
  action_name : @objects.PdfName,
  dict : @objects.PdfDictionary,
) -> PdfRenditionAction raise PdfDocumentError {
  let op = action_optional_int(dict, action_key(b"OP"), object_id, action_name)
  let script = dict.get(action_key(b"JS"))
  if op is None && script is None {
    raise action_error(
      object_id,
      Some(action_name),
      "Rendition requires OP or JS",
    )
  }
  if op is Some(value) {
    if (value < 0 || value > 4) && script is None {
      raise action_error(
        object_id,
        Some(action_name),
        "Rendition OP must be 0..4 when JS is absent",
      )
    }
    if (value == 0 || value == 4) && dict.get(action_key(b"R")) is None {
      raise action_error(
        object_id,
        Some(action_name),
        "Rendition R is required for OP 0 or 4",
      )
    }
    if value >= 0 && value <= 4 && dict.get(action_key(b"AN")) is None {
      raise action_error(
        object_id,
        Some(action_name),
        "Rendition AN is required for OP 0..4",
      )
    }
  }
  PdfRenditionAction::{
    rendition: dict.get(action_key(b"R")),
    annotation: dict.get(action_key(b"AN")),
    operation: op,
    script,
    raw_dict: dict,
  }
}

///|
fn parse_transition_action(
  file : PdfFile,
  object_id : @objects.ObjectId?,
  action_name : @objects.PdfName,
  dict : @objects.PdfDictionary,
) -> PdfTransitionAction raise PdfDocumentError {
  PdfTransitionAction::{
    transition: parse_transition(
      file,
      action_required_raw(dict, action_key(b"Trans"), object_id, action_name),
    ),
    raw_dict: dict,
  }
}

///|
fn parse_go_to_3d_view_action(
  object_id : @objects.ObjectId?,
  action_name : @objects.PdfName,
  dict : @objects.PdfDictionary,
) -> PdfGoTo3DViewAction raise PdfDocumentError {
  PdfGoTo3DViewAction::{
    target_annotation: action_required_raw(
      dict,
      action_key(b"TA"),
      object_id,
      action_name,
    ),
    view: Some(
      action_required_raw(dict, action_key(b"V"), object_id, action_name),
    ),
    raw_dict: dict,
  }
}

///|
fn parse_rich_media_execute_action(
  object_id : @objects.ObjectId?,
  action_name : @objects.PdfName,
  dict : @objects.PdfDictionary,
) -> PdfRichMediaExecuteAction raise PdfDocumentError {
  PdfRichMediaExecuteAction::{
    target_annotation: action_required_raw(
      dict,
      action_key(b"TA"),
      object_id,
      action_name,
    ),
    instance: dict.get(action_key(b"TI")),
    command: action_dictionary(
      action_required_raw(dict, action_key(b"CMD"), object_id, action_name),
      object_id,
      action_name,
      "CMD",
    ),
    raw_dict: dict,
  }
}
