///|
fn parse_go_to_action(
  document : PdfDocument,
  object_id : @objects.ObjectId?,
  action_name : @objects.PdfName,
  dict : @objects.PdfDictionary,
) -> PdfGoToAction raise PdfDocumentError {
  PdfGoToAction::{
    destination: parse_destination_object(
      document,
      action_required_raw(dict, action_key(b"D"), object_id, action_name),
      action_name,
    ),
    structure_destination: match dict.get(action_key(b"SD")) {
      Some(value) =>
        Some(parse_destination_object(document, value, action_name))
      None => None
    },
    raw_dict: dict,
  }
}

///|
fn parse_remote_go_to_action(
  object_id : @objects.ObjectId?,
  action_name : @objects.PdfName,
  dict : @objects.PdfDictionary,
) -> PdfRemoteGoToAction raise PdfDocumentError {
  PdfRemoteGoToAction::{
    file_specification: action_required_raw(
      dict,
      action_key(b"F"),
      object_id,
      action_name,
    ),
    destination: action_required_raw(
      dict,
      action_key(b"D"),
      object_id,
      action_name,
    ),
    new_window: action_optional_bool_value(
      dict,
      action_key(b"NewWindow"),
      object_id,
      action_name,
    ),
    raw_dict: dict,
  }
}

///|
fn parse_embedded_go_to_action(
  file : PdfFile,
  object_id : @objects.ObjectId?,
  action_name : @objects.PdfName,
  dict : @objects.PdfDictionary,
) -> PdfEmbeddedGoToAction raise PdfDocumentError {
  let file_specification = dict.get(action_key(b"F"))
  let target = match dict.get(action_key(b"T")) {
    Some(value) =>
      Some(parse_target_dictionary(file, value, object_id, action_name, []))
    None => None
  }
  if file_specification is None && target is None {
    raise action_error(
      object_id,
      Some(action_name),
      "GoToE requires /T when /F is absent",
    )
  }
  PdfEmbeddedGoToAction::{
    file_specification,
    destination: action_required_raw(
      dict,
      action_key(b"D"),
      object_id,
      action_name,
    ),
    new_window: action_optional_bool_value(
      dict,
      action_key(b"NewWindow"),
      object_id,
      action_name,
    ),
    target,
    raw_dict: dict,
  }
}

///|
fn parse_target_dictionary(
  file : PdfFile,
  value : @objects.PdfObject,
  action_object_id : @objects.ObjectId?,
  action_name : @objects.PdfName,
  path : Array[@objects.ObjectId],
) -> PdfTargetDictionary raise PdfDocumentError {
  let (object_id, dict, next_path) = resolve_target_dictionary(
    file, value, action_object_id, action_name, path,
  )
  let relation = match dict.get(action_key(b"R")) {
    Some(value) =>
      Some(action_name_value(value, action_object_id, action_name, "target R"))
    None => None
  }
  let name = match dict.get(action_key(b"N")) {
    Some(value) =>
      Some(action_string(value, action_object_id, action_name, "target N"))
    None => None
  }
  let target = match dict.get(action_key(b"T")) {
    Some(value) =>
      Some(
        parse_target_dictionary(
          file, value, action_object_id, action_name, next_path,
        ),
      )
    None => None
  }
  PdfTargetDictionary::{
    object_id,
    relation,
    name,
    page: dict.get(action_key(b"P")),
    annotation: dict.get(action_key(b"A")),
    target,
    raw_dict: dict,
  }
}

///|
fn resolve_target_dictionary(
  file : PdfFile,
  value : @objects.PdfObject,
  action_object_id : @objects.ObjectId?,
  action_name : @objects.PdfName,
  path : Array[@objects.ObjectId],
) -> (@objects.ObjectId?, @objects.PdfDictionary, Array[@objects.ObjectId]) raise PdfDocumentError {
  match value {
    @objects.PdfObject::Ref(object_id) => {
      if action_path_contains(path, object_id) {
        raise PdfDocumentError::CycleDetected(
          object_id, "target dictionary cycle detected",
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
        _ =>
          raise action_error(
            action_object_id,
            Some(action_name),
            "target dictionary must resolve to a dictionary",
          )
      }
    }
    @objects.PdfObject::Dictionary(dict) => (None, dict, path)
    _ =>
      raise action_error(
        action_object_id,
        Some(action_name),
        "target dictionary must be a dictionary",
      )
  }
}

///|
fn parse_go_to_dpart_action(
  object_id : @objects.ObjectId?,
  action_name : @objects.PdfName,
  dict : @objects.PdfDictionary,
) -> PdfGoToDPartAction raise PdfDocumentError {
  match action_required_raw(dict, action_key(b"Dp"), object_id, action_name) {
    @objects.PdfObject::Ref(dpart) =>
      PdfGoToDPartAction::{ dpart, raw_dict: dict }
    _ =>
      raise action_error(
        object_id,
        Some(action_name),
        "Dp must be an indirect reference",
      )
  }
}

///|
fn parse_thread_action(dict : @objects.PdfDictionary) -> PdfThreadAction {
  PdfThreadAction::{
    file_specification: dict.get(action_key(b"F")),
    thread: dict.get(action_key(b"D")),
    bead: dict.get(action_key(b"B")),
    raw_dict: dict,
  }
}
