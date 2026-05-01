///|
fn structure_key(bytes : Bytes) -> @objects.PdfName {
  @objects.PdfName::new(bytes)
}

///|
fn structure_error(
  object_id : @objects.ObjectId?,
  reason : String,
) -> PdfDocumentError {
  PdfDocumentError::InvalidStructure(object_id, reason)
}

///|
fn structure_resolve_object(
  file : PdfFile,
  value : @objects.PdfObject,
  label : String,
  seen : Map[@objects.ObjectId, Bool],
) -> (@objects.ObjectId?, @objects.PdfObject) raise PdfDocumentError {
  let _ = label
  let _ = seen
  let object_id = match value {
    @objects.PdfObject::Ref(id) => Some(id)
    _ => None
  }
  (object_id, resolve_indirect(file, value))
}

///|
fn structure_resolve_dictionary(
  file : PdfFile,
  value : @objects.PdfObject,
  label : String,
) -> (@objects.ObjectId?, @objects.PdfDictionary) raise PdfDocumentError {
  let seen : Map[@objects.ObjectId, Bool] = Map::new()
  let (object_id, resolved) = structure_resolve_object(file, value, label, seen)
  match resolved {
    @objects.PdfObject::Dictionary(dict) => (object_id, dict)
    @objects.PdfObject::Stream(stream) => (object_id, stream.dict)
    _ =>
      raise structure_error(object_id, label + " must resolve to a dictionary")
  }
}

///|
fn structure_bool(
  value : @objects.PdfObject,
  owner : @objects.ObjectId?,
  label : String,
) -> Bool raise PdfDocumentError {
  match value {
    @objects.PdfObject::Boolean(flag) => flag
    _ => raise structure_error(owner, label + " must be a boolean")
  }
}

///|
fn structure_int(
  value : @objects.PdfObject,
  owner : @objects.ObjectId?,
  label : String,
) -> Int raise PdfDocumentError {
  match value {
    @objects.PdfObject::Integer(number) => number.to_int()
    _ => raise structure_error(owner, label + " must be an integer")
  }
}

///|
fn structure_name(
  value : @objects.PdfObject,
  owner : @objects.ObjectId?,
  label : String,
) -> @objects.PdfName raise PdfDocumentError {
  match value {
    @objects.PdfObject::Name(name) => name
    _ => raise structure_error(owner, label + " must be a name")
  }
}

///|
fn structure_string(
  value : @objects.PdfObject,
  owner : @objects.ObjectId?,
  label : String,
) -> Bytes raise PdfDocumentError {
  match value {
    @objects.PdfObject::String(bytes) => bytes
    _ => raise structure_error(owner, label + " must be a string")
  }
}

///|
fn structure_ref(
  value : @objects.PdfObject,
  owner : @objects.ObjectId?,
  label : String,
) -> @objects.ObjectId raise PdfDocumentError {
  match value {
    @objects.PdfObject::Ref(object_id) => object_id
    _ => raise structure_error(owner, label + " must be an indirect reference")
  }
}

///|
fn structure_optional_ref(
  dict : @objects.PdfDictionary,
  key : @objects.PdfName,
  owner : @objects.ObjectId?,
  label : String,
) -> @objects.ObjectId? raise PdfDocumentError {
  match dict.get(key) {
    Some(value) => Some(structure_ref(value, owner, label))
    None => None
  }
}

///|
fn structure_optional_string(
  dict : @objects.PdfDictionary,
  key : @objects.PdfName,
  owner : @objects.ObjectId?,
  label : String,
) -> Bytes? raise PdfDocumentError {
  match dict.get(key) {
    Some(value) => Some(structure_string(value, owner, label))
    None => None
  }
}

///|
fn structure_optional_int(
  dict : @objects.PdfDictionary,
  key : @objects.PdfName,
  owner : @objects.ObjectId?,
  label : String,
) -> Int? raise PdfDocumentError {
  match dict.get(key) {
    Some(value) => Some(structure_int(value, owner, label))
    None => None
  }
}

///|
fn structure_diagnostic(
  code : Bytes,
  message : String,
  object_id : @objects.ObjectId?,
  raw_object : @objects.PdfObject?,
) -> PdfStructureDiagnostic {
  PdfStructureDiagnostic::{
    code: structure_key(code),
    message,
    object_id,
    raw_object,
  }
}

///|
fn structure_report_item(
  code : Bytes,
  severity : PdfTaggedPdfSeverity,
  message : String,
  element_index : Int?,
  object_id : @objects.ObjectId?,
  raw_object : @objects.PdfObject?,
) -> PdfTaggedPdfReportItem {
  PdfTaggedPdfReportItem::{
    code: structure_key(code),
    severity,
    message,
    element_index,
    object_id,
    raw_object,
  }
}
