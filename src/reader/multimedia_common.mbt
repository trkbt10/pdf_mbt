///|
let multimedia_max_indirect_depth = 64

///|
fn multimedia_key(bytes : Bytes) -> @objects.PdfName {
  @objects.PdfName::new(bytes)
}

///|
fn multimedia_error(
  object_id : @objects.ObjectId?,
  reason : String,
) -> PdfDocumentError {
  PdfDocumentError::InvalidMultimedia(object_id, reason)
}

///|
fn multimedia_object_id_path_contains(
  path : Array[@objects.ObjectId],
  object_id : @objects.ObjectId,
) -> Bool {
  for existing in path {
    if existing == object_id {
      return true
    }
  }
  false
}

///|
fn multimedia_copy_object_id_path(
  path : Array[@objects.ObjectId],
) -> Array[@objects.ObjectId] {
  let copy : Array[@objects.ObjectId] = []
  for object_id in path {
    copy.push(object_id)
  }
  copy
}

///|
fn load_multimedia_object(
  file : PdfFile,
  object_id : @objects.ObjectId,
) -> @objects.PdfObject raise PdfDocumentError {
  try file.load_object(object_id) catch {
    error => raise PdfDocumentError::ReaderError(error)
  } noraise {
    value => value
  }
}

///|
fn resolve_multimedia_object_path(
  file : PdfFile,
  value : @objects.PdfObject,
  context : String,
  path : Array[@objects.ObjectId],
) -> (@objects.ObjectId?, @objects.PdfObject, Array[@objects.ObjectId]) raise PdfDocumentError {
  match value {
    @objects.PdfObject::Ref(object_id) => {
      if multimedia_object_id_path_contains(path, object_id) {
        raise multimedia_error(
          Some(object_id),
          context + " indirect-object cycle detected",
        )
      }
      if path.length() >= multimedia_max_indirect_depth {
        raise multimedia_error(
          Some(object_id),
          context + " indirect-object traversal limit exceeded",
        )
      }
      let next_path = multimedia_copy_object_id_path(path)
      next_path.push(object_id)
      let loaded = load_multimedia_object(file, object_id)
      if loaded == @objects.PdfObject::Null {
        raise multimedia_error(Some(object_id), context + " object is missing")
      }
      let (_, resolved, final_path) = resolve_multimedia_object_path(
        file, loaded, context, next_path,
      )
      (Some(object_id), resolved, final_path)
    }
    _ => (None, value, path)
  }
}

///|
fn resolve_multimedia_object(
  file : PdfFile,
  value : @objects.PdfObject,
  context : String,
) -> (@objects.ObjectId?, @objects.PdfObject) raise PdfDocumentError {
  let (object_id, resolved, _) = resolve_multimedia_object_path(
    file,
    value,
    context,
    [],
  )
  (object_id, resolved)
}

///|
fn multimedia_dictionary(
  value : @objects.PdfObject,
  owner : @objects.ObjectId?,
  label : String,
) -> @objects.PdfDictionary raise PdfDocumentError {
  match value {
    @objects.PdfObject::Dictionary(dict) => dict
    _ => raise multimedia_error(owner, label + " must be a dictionary")
  }
}

///|
fn multimedia_stream(
  value : @objects.PdfObject,
  owner : @objects.ObjectId?,
  label : String,
) -> @objects.PdfStream raise PdfDocumentError {
  match value {
    @objects.PdfObject::Stream(stream) => stream
    _ => raise multimedia_error(owner, label + " must be a stream")
  }
}

///|
fn multimedia_array(
  value : @objects.PdfObject,
  owner : @objects.ObjectId?,
  label : String,
) -> Array[@objects.PdfObject] raise PdfDocumentError {
  match value {
    @objects.PdfObject::Array(values) => values
    _ => raise multimedia_error(owner, label + " must be an array")
  }
}

///|
fn multimedia_name(
  value : @objects.PdfObject,
  owner : @objects.ObjectId?,
  label : String,
) -> @objects.PdfName raise PdfDocumentError {
  match value {
    @objects.PdfObject::Name(name) => name
    _ => raise multimedia_error(owner, label + " must be a name")
  }
}

///|
fn multimedia_string(
  value : @objects.PdfObject,
  owner : @objects.ObjectId?,
  label : String,
) -> Bytes raise PdfDocumentError {
  match value {
    @objects.PdfObject::String(bytes) => bytes
    _ => raise multimedia_error(owner, label + " must be a string")
  }
}

///|
fn multimedia_number(
  value : @objects.PdfObject,
  owner : @objects.ObjectId?,
  label : String,
) -> Double raise PdfDocumentError {
  match value {
    @objects.PdfObject::Integer(number) => number.to_double()
    @objects.PdfObject::Real(number) => number
    _ => raise multimedia_error(owner, label + " must be a number")
  }
}

///|
#warnings("-unused_value")
fn multimedia_number_in_range(
  value : @objects.PdfObject,
  owner : @objects.ObjectId?,
  label : String,
  min : Double,
  max : Double,
) -> Double raise PdfDocumentError {
  let number = multimedia_number(value, owner, label)
  if number < min || number > max {
    raise multimedia_error(owner, label + " is out of range")
  }
  number
}

///|
#warnings("-unused_value")
fn multimedia_int(
  value : @objects.PdfObject,
  owner : @objects.ObjectId?,
  label : String,
) -> Int raise PdfDocumentError {
  match value {
    @objects.PdfObject::Integer(number) => number.to_int()
    _ => raise multimedia_error(owner, label + " must be an integer")
  }
}

///|
#warnings("-unused_value")
fn multimedia_optional_number_default(
  dict : @objects.PdfDictionary,
  key : @objects.PdfName,
  owner : @objects.ObjectId?,
  label : String,
  default : Double,
) -> Double raise PdfDocumentError {
  match dict.get(key) {
    Some(value) => multimedia_number(value, owner, label)
    None => default
  }
}

///|
#warnings("-unused_value")
fn multimedia_optional_bool_default(
  dict : @objects.PdfDictionary,
  key : @objects.PdfName,
  owner : @objects.ObjectId?,
  label : String,
  default : Bool,
) -> Bool raise PdfDocumentError {
  match dict.get(key) {
    Some(value) => multimedia_bool(value, owner, label)
    None => default
  }
}

///|
fn multimedia_bool(
  value : @objects.PdfObject,
  owner : @objects.ObjectId?,
  label : String,
) -> Bool raise PdfDocumentError {
  match value {
    @objects.PdfObject::Boolean(value) => value
    _ => raise multimedia_error(owner, label + " must be a boolean")
  }
}

///|
fn resolve_multimedia_dictionary(
  file : PdfFile,
  value : @objects.PdfObject,
  context : String,
) -> PdfRawDictionaryPayload raise PdfDocumentError {
  let (object_id, resolved) = resolve_multimedia_object(file, value, context)
  PdfRawDictionaryPayload::{
    object_id,
    raw_dict: multimedia_dictionary(resolved, object_id, context),
  }
}

///|
#warnings("-unused_value")
fn resolve_multimedia_stream(
  file : PdfFile,
  value : @objects.PdfObject,
  context : String,
) -> PdfRawStreamPayload raise PdfDocumentError {
  let (object_id, resolved) = resolve_multimedia_object(file, value, context)
  PdfRawStreamPayload::{
    object_id,
    raw_stream: multimedia_stream(resolved, object_id, context),
  }
}

///|
#warnings("-unused_value")
fn resolve_multimedia_payload(
  file : PdfFile,
  value : @objects.PdfObject,
  context : String,
) -> PdfMultimediaPayload raise PdfDocumentError {
  let (object_id, resolved) = resolve_multimedia_object(file, value, context)
  match resolved {
    @objects.PdfObject::Dictionary(dict) =>
      PdfMultimediaPayload::Dictionary(PdfRawDictionaryPayload::{
        object_id,
        raw_dict: dict,
      })
    @objects.PdfObject::Stream(stream) =>
      PdfMultimediaPayload::Stream(PdfRawStreamPayload::{
        object_id,
        raw_stream: stream,
      })
    @objects.PdfObject::String(bytes) =>
      PdfMultimediaPayload::ByteString(PdfMultimediaByteString::{ bytes, })
    _ => PdfMultimediaPayload::Object(resolved)
  }
}

///|
fn multimedia_required(
  dict : @objects.PdfDictionary,
  key : @objects.PdfName,
  owner : @objects.ObjectId?,
  label : String,
) -> @objects.PdfObject raise PdfDocumentError {
  match dict.get(key) {
    Some(value) => value
    None => raise multimedia_error(owner, label + " is required")
  }
}

///|
#warnings("-unused_value")
fn multimedia_optional_name(
  dict : @objects.PdfDictionary,
  key : @objects.PdfName,
  owner : @objects.ObjectId?,
  label : String,
) -> @objects.PdfName? raise PdfDocumentError {
  match dict.get(key) {
    Some(value) => Some(multimedia_name(value, owner, label))
    None => None
  }
}

///|
#warnings("-unused_value")
fn multimedia_optional_string(
  dict : @objects.PdfDictionary,
  key : @objects.PdfName,
  owner : @objects.ObjectId?,
  label : String,
) -> Bytes? raise PdfDocumentError {
  match dict.get(key) {
    Some(value) => Some(multimedia_string(value, owner, label))
    None => None
  }
}

///|
fn multimedia_optional_dictionary_payload(
  file : PdfFile,
  dict : @objects.PdfDictionary,
  key : @objects.PdfName,
  owner : @objects.ObjectId?,
  label : String,
) -> PdfRawDictionaryPayload? raise PdfDocumentError {
  match dict.get(key) {
    Some(value) =>
      match value {
        @objects.PdfObject::Ref(_) =>
          Some(resolve_multimedia_dictionary(file, value, label))
        _ =>
          Some(PdfRawDictionaryPayload::{
            object_id: None,
            raw_dict: multimedia_dictionary(value, owner, label),
          })
      }
    None => None
  }
}

///|
#warnings("-unused_value")
fn parse_multimedia_mh_be_policy(
  file : PdfFile,
  dict : @objects.PdfDictionary,
  owner : @objects.ObjectId?,
) -> PdfMhBePolicy raise PdfDocumentError {
  let must_honor = match
    multimedia_optional_dictionary_payload(
      file,
      dict,
      multimedia_key(b"MH"),
      owner,
      "MH",
    ) {
    Some(payload) => Some(payload.raw_dict)
    None => None
  }
  let best_effort = match
    multimedia_optional_dictionary_payload(
      file,
      dict,
      multimedia_key(b"BE"),
      owner,
      "BE",
    ) {
    Some(payload) => Some(payload.raw_dict)
    None => None
  }
  PdfMhBePolicy::{ must_honor, best_effort }
}

///|
fn require_multimedia_name_value(
  dict : @objects.PdfDictionary,
  key : @objects.PdfName,
  owner : @objects.ObjectId?,
  label : String,
) -> @objects.PdfName raise PdfDocumentError {
  multimedia_name(multimedia_required(dict, key, owner, label), owner, label)
}

///|
#warnings("-unused_value")
fn require_multimedia_name_equals(
  dict : @objects.PdfDictionary,
  key : @objects.PdfName,
  expected : @objects.PdfName,
  owner : @objects.ObjectId?,
  label : String,
) -> Unit raise PdfDocumentError {
  let actual = require_multimedia_name_value(dict, key, owner, label)
  if actual != expected {
    raise multimedia_error(owner, label + " has invalid name")
  }
}

///|
fn multimedia_number_array(
  value : @objects.PdfObject,
  owner : @objects.ObjectId?,
  label : String,
  expected_length : Int,
) -> Array[Double] raise PdfDocumentError {
  let values = multimedia_array(value, owner, label)
  if values.length() != expected_length {
    raise multimedia_error(owner, label + " has invalid length")
  }
  let numbers : Array[Double] = []
  for item in values {
    numbers.push(multimedia_number(item, owner, label))
  }
  numbers
}

///|
#warnings("-unused_value")
fn parse_multimedia_vector(
  value : @objects.PdfObject,
  owner : @objects.ObjectId?,
  label : String,
) -> PdfThreeDVector raise PdfDocumentError {
  let values = multimedia_number_array(value, owner, label, 3)
  PdfThreeDVector::{ x: values[0], y: values[1], z: values[2] }
}

///|
#warnings("-unused_value")
fn parse_multimedia_matrix(
  value : @objects.PdfObject,
  owner : @objects.ObjectId?,
  label : String,
) -> PdfThreeDMatrix raise PdfDocumentError {
  PdfThreeDMatrix::{ values: multimedia_number_array(value, owner, label, 12) }
}
