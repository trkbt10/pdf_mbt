///|
fn parse_launch_action(
  object_id : @objects.ObjectId?,
  action_name : @objects.PdfName,
  dict : @objects.PdfDictionary,
) -> PdfLaunchAction raise PdfDocumentError {
  let file_specification = dict.get(action_key(b"F"))
  let windows = match dict.get(action_key(b"Win")) {
    Some(value) =>
      Some(parse_windows_launch_params(value, object_id, action_name))
    None => None
  }
  let mac = dict.get(action_key(b"Mac"))
  let unix = dict.get(action_key(b"Unix"))
  if file_specification is None &&
    windows is None &&
    mac is None &&
    unix is None {
    raise action_error(
      object_id,
      Some(action_name),
      "Launch requires /F when platform launch dictionaries are absent",
    )
  }
  PdfLaunchAction::{
    file_specification,
    windows,
    mac,
    unix,
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
fn parse_windows_launch_params(
  value : @objects.PdfObject,
  object_id : @objects.ObjectId?,
  action_name : @objects.PdfName,
) -> PdfWindowsLaunchParams raise PdfDocumentError {
  let dict = action_dictionary(value, object_id, action_name, "Win")
  PdfWindowsLaunchParams::{
    file: action_required_raw(dict, action_key(b"F"), object_id, action_name),
    directory: dict.get(action_key(b"D")),
    operation: dict.get(action_key(b"O")),
    parameter: dict.get(action_key(b"P")),
    raw_dict: dict,
  }
}

///|
fn parse_uri_action(
  object_id : @objects.ObjectId?,
  action_name : @objects.PdfName,
  dict : @objects.PdfDictionary,
) -> PdfUriAction raise PdfDocumentError {
  PdfUriAction::{
    uri: action_string(
      action_required_raw(dict, action_key(b"URI"), object_id, action_name),
      object_id,
      action_name,
      "URI",
    ),
    is_map: action_optional_bool(
      dict,
      action_key(b"IsMap"),
      object_id,
      action_name,
      false,
    ),
    raw_dict: dict,
  }
}

///|
fn parse_javascript_action(
  object_id : @objects.ObjectId?,
  action_name : @objects.PdfName,
  dict : @objects.PdfDictionary,
) -> PdfJavaScriptAction raise PdfDocumentError {
  let script = action_required_raw(
    dict,
    action_key(b"JS"),
    object_id,
    action_name,
  )
  match script {
    @objects.PdfObject::String(_) | @objects.PdfObject::Stream(_) =>
      PdfJavaScriptAction::{ script, raw_dict: dict }
    _ =>
      raise action_error(
        object_id,
        Some(action_name),
        "JS must be a text string or stream",
      )
  }
}

///|
fn parse_form_action_raw(
  dict : @objects.PdfDictionary,
) -> PdfFormActionRaw raise PdfDocumentError {
  let action_name = match dict.get(action_key(b"S")) {
    Some(@objects.PdfObject::Name(name)) => name
    _ => action_key(b"SubmitForm")
  }
  PdfFormActionRaw::{
    file_specification: dict.get(action_key(b"F")),
    fields: dict.get(action_key(b"Fields")),
    flags: action_optional_int(dict, action_key(b"Flags"), None, action_name),
    raw_dict: dict,
  }
}
