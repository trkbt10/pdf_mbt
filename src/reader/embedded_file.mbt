///|
fn parse_embedded_file_stream(
  file : PdfFile,
  key : @objects.PdfName,
  value : @objects.PdfObject,
  owner : @objects.ObjectId?,
) -> PdfEmbeddedFile raise PdfDocumentError {
  let resolved = resolve_file_spec_child_object(
    file, value, owner, "embedded file stream",
  )
  let stream = match resolved.object {
    @objects.PdfObject::Stream(stream) => stream
    _ => raise file_spec_error(owner, "embedded file entry must be a stream")
  }
  validate_optional_stream_type(
    stream.dict,
    file_spec_key(b"EmbeddedFile"),
    owner,
    "embedded file stream Type",
  )
  let subtype = match stream.dict.get(file_spec_key(b"Subtype")) {
    Some(object) => Some(file_spec_name(object, owner, "embedded file Subtype"))
    None => None
  }
  let params = match stream.dict.get(file_spec_key(b"Params")) {
    Some(object) => Some(parse_embedded_file_params(object, owner))
    None => None
  }
  PdfEmbeddedFile::{
    key,
    source_object_id: resolved.source_object_id,
    raw_stream: stream,
    subtype,
    params,
    raw_dict: stream.dict,
    raw_object: resolved.raw_object,
  }
}

///|
fn parse_embedded_file_params(
  value : @objects.PdfObject,
  owner : @objects.ObjectId?,
) -> PdfEmbeddedFileParams raise PdfDocumentError {
  let dict = file_spec_dictionary(value, owner, "embedded file Params")
  let size = match dict.get(file_spec_key(b"Size")) {
    Some(object) => Some(file_spec_integer(object, owner, "embedded file Size"))
    None => None
  }
  let creation_date = match dict.get(file_spec_key(b"CreationDate")) {
    Some(object) =>
      Some(file_spec_string(object, owner, "embedded file CreationDate"))
    None => None
  }
  let modification_date = match dict.get(file_spec_key(b"ModDate")) {
    Some(object) =>
      Some(file_spec_string(object, owner, "embedded file ModDate"))
    None => None
  }
  let mac = match dict.get(file_spec_key(b"Mac")) {
    Some(object) =>
      Some(file_spec_dictionary(object, owner, "embedded file Mac"))
    None => None
  }
  let checksum = match dict.get(file_spec_key(b"CheckSum")) {
    Some(object) => {
      let bytes = file_spec_string(object, owner, "embedded file CheckSum")
      if bytes.length() != 16 {
        raise file_spec_error(owner, "embedded file CheckSum must be 16 bytes")
      }
      Some(bytes)
    }
    None => None
  }
  PdfEmbeddedFileParams::{
    size,
    creation_date,
    modification_date,
    mac,
    checksum,
    raw_dict: dict,
  }
}

///|
fn parse_file_spec_stream_descriptor(
  file : PdfFile,
  value : @objects.PdfObject,
  owner : @objects.ObjectId?,
  label : String,
) -> PdfFileSpecStream raise PdfDocumentError {
  let resolved = resolve_file_spec_child_object(file, value, owner, label)
  match resolved.object {
    @objects.PdfObject::Stream(stream) =>
      PdfFileSpecStream::{
        source_object_id: resolved.source_object_id,
        raw_stream: stream,
        raw_object: resolved.raw_object,
      }
    _ => raise file_spec_error(owner, label + " must be a stream")
  }
}

///|
fn validate_optional_stream_type(
  dict : @objects.PdfDictionary,
  expected : @objects.PdfName,
  owner : @objects.ObjectId?,
  label : String,
) -> Unit raise PdfDocumentError {
  match dict.get(file_spec_key(b"Type")) {
    Some(object) => {
      let name = file_spec_name(object, owner, label)
      if name != expected {
        raise file_spec_error(owner, label + " has invalid value")
      }
    }
    None => ()
  }
}
