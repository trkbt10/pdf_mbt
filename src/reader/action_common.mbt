///|
fn action_key(bytes : Bytes) -> @objects.PdfName {
  @objects.PdfName::new(bytes)
}

///|
fn action_error(
  object_id : @objects.ObjectId?,
  action_name : @objects.PdfName?,
  reason : String,
) -> PdfDocumentError {
  PdfDocumentError::InvalidAction(object_id, action_name, reason)
}

///|
fn parse_action_object(
  document : PdfDocument,
  value : @objects.PdfObject,
  source : PdfActionSource,
) -> PdfAction raise PdfDocumentError {
  parse_action_object_path(document, value, source, [])
}

///|
fn parse_action_object_path(
  document : PdfDocument,
  value : @objects.PdfObject,
  source : PdfActionSource,
  path : Array[@objects.ObjectId],
) -> PdfAction raise PdfDocumentError {
  let (object_id, dict, next_path) = resolve_action_dictionary(
    document.file,
    value,
    source,
    path,
    "action",
  )
  let diagnostic_id = match object_id {
    Some(id) => Some(id)
    None => action_source_object_id(source)
  }
  validate_action_type(diagnostic_id, dict)
  let action_name = require_action_name(diagnostic_id, dict)
  let kind = parse_action_kind(
    document, diagnostic_id, action_name, dict, source,
  )
  let next = parse_action_next(
    document, diagnostic_id, action_name, dict, source, next_path,
  )
  PdfAction::{
    object_id,
    source,
    action_type: action_name,
    kind,
    next,
    raw_dict: dict,
  }
}

///|
fn resolve_action_dictionary(
  file : PdfFile,
  value : @objects.PdfObject,
  source : PdfActionSource,
  path : Array[@objects.ObjectId],
  context : String,
) -> (@objects.ObjectId?, @objects.PdfDictionary, Array[@objects.ObjectId]) raise PdfDocumentError {
  match value {
    @objects.PdfObject::Ref(object_id) => {
      if action_path_contains(path, object_id) {
        raise PdfDocumentError::CycleDetected(
          object_id,
          context + " cycle detected",
        )
      }
      let next_path = action_copy_object_ids(path)
      next_path.push(object_id)
      let loaded = try file.load_object(object_id) catch {
        error => raise PdfDocumentError::ReaderError(error)
      } noraise {
        object => object
      }
      match loaded {
        @objects.PdfObject::Dictionary(dict) =>
          (Some(object_id), dict, next_path)
        @objects.PdfObject::Null =>
          raise action_error(
            Some(object_id),
            None,
            context + " object is missing",
          )
        _ =>
          raise action_error(
            Some(object_id),
            None,
            context + " must be a dictionary",
          )
      }
    }
    @objects.PdfObject::Dictionary(dict) => {
      let _ = source
      (None, dict, path)
    }
    _ =>
      raise action_error(
        action_source_object_id(source),
        None,
        context + " must be a dictionary",
      )
  }
}

///|
fn validate_action_type(
  object_id : @objects.ObjectId?,
  dict : @objects.PdfDictionary,
) -> Unit raise PdfDocumentError {
  match dict.get(action_key(b"Type")) {
    Some(@objects.PdfObject::Name(name)) if name == action_key(b"Action") => ()
    Some(@objects.PdfObject::Name(_)) =>
      raise action_error(object_id, None, "action /Type entry must be /Action")
    Some(_) =>
      raise action_error(object_id, None, "action /Type entry must be a name")
    None => ()
  }
}

///|
fn require_action_name(
  object_id : @objects.ObjectId?,
  dict : @objects.PdfDictionary,
) -> @objects.PdfName raise PdfDocumentError {
  match dict.get(action_key(b"S")) {
    Some(@objects.PdfObject::Name(name)) => name
    Some(_) =>
      raise action_error(object_id, None, "action /S entry must be a name")
    None =>
      raise action_error(object_id, None, "action dictionary is missing /S")
  }
}

///|
fn parse_action_next(
  document : PdfDocument,
  object_id : @objects.ObjectId?,
  action_name : @objects.PdfName,
  dict : @objects.PdfDictionary,
  source : PdfActionSource,
  path : Array[@objects.ObjectId],
) -> Array[PdfAction] raise PdfDocumentError {
  match dict.get(action_key(b"Next")) {
    Some(@objects.PdfObject::Array(values)) => {
      let actions : Array[PdfAction] = []
      for value in values {
        actions.push(
          parse_action_next_item(
            document, value, source, path, object_id, action_name,
          ),
        )
      }
      actions
    }
    Some(value) =>
      [
        parse_action_next_item(
          document, value, source, path, object_id, action_name,
        ),
      ]
    None => []
  }
}

///|
fn parse_action_next_item(
  document : PdfDocument,
  value : @objects.PdfObject,
  source : PdfActionSource,
  path : Array[@objects.ObjectId],
  object_id : @objects.ObjectId?,
  action_name : @objects.PdfName,
) -> PdfAction raise PdfDocumentError {
  match value {
    @objects.PdfObject::Dictionary(_) | @objects.PdfObject::Ref(_) =>
      parse_action_object_path(document, value, source, path)
    _ =>
      raise action_error(
        object_id,
        Some(action_name),
        "action /Next entries must be action dictionaries",
      )
  }
}

///|
fn parse_action_kind(
  document : PdfDocument,
  object_id : @objects.ObjectId?,
  action_name : @objects.PdfName,
  dict : @objects.PdfDictionary,
  source : PdfActionSource,
) -> PdfActionKind raise PdfDocumentError {
  if action_name == action_key(b"GoTo") {
    PdfActionKind::GoTo(
      parse_go_to_action(document, object_id, action_name, dict),
    )
  } else if action_name == action_key(b"GoToR") {
    PdfActionKind::GoToR(
      parse_remote_go_to_action(object_id, action_name, dict),
    )
  } else if action_name == action_key(b"GoToE") {
    PdfActionKind::GoToE(
      parse_embedded_go_to_action(document.file, object_id, action_name, dict),
    )
  } else if action_name == action_key(b"GoToDp") {
    PdfActionKind::GoToDp(
      parse_go_to_dpart_action(object_id, action_name, dict),
    )
  } else if action_name == action_key(b"Launch") {
    PdfActionKind::Launch(parse_launch_action(object_id, action_name, dict))
  } else if action_name == action_key(b"Thread") {
    PdfActionKind::Thread(parse_thread_action(dict))
  } else if action_name == action_key(b"URI") {
    PdfActionKind::URI(parse_uri_action(object_id, action_name, dict))
  } else if action_name == action_key(b"Sound") {
    PdfActionKind::Sound(parse_sound_action(object_id, action_name, dict))
  } else if action_name == action_key(b"Movie") {
    PdfActionKind::Movie(parse_movie_action(object_id, action_name, dict))
  } else if action_name == action_key(b"Hide") {
    PdfActionKind::Hide(parse_hide_action(object_id, action_name, dict))
  } else if action_name == action_key(b"Named") {
    PdfActionKind::Named(parse_named_action(object_id, action_name, dict))
  } else if action_name == action_key(b"SubmitForm") {
    PdfActionKind::SubmitForm(parse_form_action_raw(dict))
  } else if action_name == action_key(b"ResetForm") {
    PdfActionKind::ResetForm(parse_form_action_raw(dict))
  } else if action_name == action_key(b"ImportData") {
    PdfActionKind::ImportData(parse_form_action_raw(dict))
  } else if action_name == action_key(b"SetOCGState") {
    PdfActionKind::SetOCGState(
      parse_set_ocg_state_action(object_id, action_name, dict),
    )
  } else if action_name == action_key(b"Rendition") {
    PdfActionKind::Rendition(
      parse_rendition_action(object_id, action_name, dict),
    )
  } else if action_name == action_key(b"Trans") {
    PdfActionKind::Trans(
      parse_transition_action(document.file, object_id, action_name, dict),
    )
  } else if action_name == action_key(b"GoTo3DView") {
    PdfActionKind::GoTo3DView(
      parse_go_to_3d_view_action(object_id, action_name, dict),
    )
  } else if action_name == action_key(b"JavaScript") {
    PdfActionKind::JavaScript(
      parse_javascript_action(object_id, action_name, dict),
    )
  } else if action_name == action_key(b"RichMediaExecute") {
    PdfActionKind::RichMediaExecute(
      parse_rich_media_execute_action(object_id, action_name, dict),
    )
  } else {
    let _ = source
    PdfActionKind::Unknown(action_name, dict)
  }
}

///|
fn action_required_raw(
  dict : @objects.PdfDictionary,
  key : @objects.PdfName,
  object_id : @objects.ObjectId?,
  action_name : @objects.PdfName,
) -> @objects.PdfObject raise PdfDocumentError {
  match dict.get(key) {
    Some(value) => value
    None =>
      raise action_error(
        object_id,
        Some(action_name),
        key.to_text() + " is required",
      )
  }
}

///|
fn action_optional_bool(
  dict : @objects.PdfDictionary,
  key : @objects.PdfName,
  object_id : @objects.ObjectId?,
  action_name : @objects.PdfName,
  default : Bool,
) -> Bool raise PdfDocumentError {
  match dict.get(key) {
    Some(@objects.PdfObject::Boolean(value)) => value
    Some(_) =>
      raise action_error(
        object_id,
        Some(action_name),
        key.to_text() + " must be boolean",
      )
    None => default
  }
}

///|
fn action_optional_bool_value(
  dict : @objects.PdfDictionary,
  key : @objects.PdfName,
  object_id : @objects.ObjectId?,
  action_name : @objects.PdfName,
) -> Bool? raise PdfDocumentError {
  match dict.get(key) {
    Some(@objects.PdfObject::Boolean(value)) => Some(value)
    Some(_) =>
      raise action_error(
        object_id,
        Some(action_name),
        key.to_text() + " must be boolean",
      )
    None => None
  }
}

///|
fn action_int(
  value : @objects.PdfObject,
  object_id : @objects.ObjectId?,
  action_name : @objects.PdfName,
  label : String,
) -> Int raise PdfDocumentError {
  match value {
    @objects.PdfObject::Integer(number) => number.to_int()
    _ =>
      raise action_error(
        object_id,
        Some(action_name),
        label + " must be an integer",
      )
  }
}

///|
fn action_number(
  value : @objects.PdfObject,
  object_id : @objects.ObjectId?,
  action_name : @objects.PdfName,
  label : String,
) -> Double raise PdfDocumentError {
  match value {
    @objects.PdfObject::Integer(number) => number.to_double()
    @objects.PdfObject::Real(number) => number
    _ =>
      raise action_error(
        object_id,
        Some(action_name),
        label + " must be a number",
      )
  }
}

///|
fn action_name_value(
  value : @objects.PdfObject,
  object_id : @objects.ObjectId?,
  action_name : @objects.PdfName,
  label : String,
) -> @objects.PdfName raise PdfDocumentError {
  match value {
    @objects.PdfObject::Name(name) => name
    _ =>
      raise action_error(
        object_id,
        Some(action_name),
        label + " must be a name",
      )
  }
}

///|
fn action_string(
  value : @objects.PdfObject,
  object_id : @objects.ObjectId?,
  action_name : @objects.PdfName,
  label : String,
) -> Bytes raise PdfDocumentError {
  match value {
    @objects.PdfObject::String(bytes) => bytes
    _ =>
      raise action_error(
        object_id,
        Some(action_name),
        label + " must be a string",
      )
  }
}

///|
fn action_dictionary(
  value : @objects.PdfObject,
  object_id : @objects.ObjectId?,
  action_name : @objects.PdfName,
  label : String,
) -> @objects.PdfDictionary raise PdfDocumentError {
  match value {
    @objects.PdfObject::Dictionary(dict) => dict
    _ =>
      raise action_error(
        object_id,
        Some(action_name),
        label + " must be a dictionary",
      )
  }
}

///|
fn action_optional_int(
  dict : @objects.PdfDictionary,
  key : @objects.PdfName,
  object_id : @objects.ObjectId?,
  action_name : @objects.PdfName,
) -> Int? raise PdfDocumentError {
  match dict.get(key) {
    Some(value) =>
      Some(action_int(value, object_id, action_name, key.to_text()))
    None => None
  }
}

///|
fn action_path_contains(
  path : Array[@objects.ObjectId],
  object_id : @objects.ObjectId,
) -> Bool {
  for current in path {
    if current == object_id {
      return true
    }
  }
  false
}

///|
fn action_copy_object_ids(
  source : Array[@objects.ObjectId],
) -> Array[@objects.ObjectId] {
  let copy : Array[@objects.ObjectId] = []
  for object_id in source {
    copy.push(object_id)
  }
  copy
}

///|
fn action_source_object_id(source : PdfActionSource) -> @objects.ObjectId? {
  match source {
    PdfActionSource::Catalog(object_id) => Some(object_id)
    PdfActionSource::Page(object_id) => Some(object_id)
    PdfActionSource::Annotation(object_id) => object_id
    PdfActionSource::FormField(object_id) => object_id
    PdfActionSource::Presentation(object_id) => object_id
    PdfActionSource::RawObject(object_id) => object_id
    PdfActionSource::Outline => None
  }
}
