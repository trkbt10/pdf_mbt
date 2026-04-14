///|
fn file_spec_key(bytes : Bytes) -> @objects.PdfName {
  @objects.PdfName::new(bytes)
}

///|
fn file_spec_error(
  owner : @objects.ObjectId?,
  reason : String,
) -> PdfDocumentError {
  PdfDocumentError::InvalidFileSpecification(owner, reason)
}

///|
fn load_file_spec_object(
  file : PdfFile,
  object_id : @objects.ObjectId,
) -> @objects.PdfObject raise PdfDocumentError {
  try file.load_object(object_id) catch {
    error => raise PdfDocumentError::ReaderError(error)
  } noraise {
    object => object
  }
}

///|
fn resolve_file_spec_object(
  file : PdfFile,
  value : @objects.PdfObject,
  context : String,
) -> PdfResolvedFileSpecObject raise PdfDocumentError {
  let seen : Map[@objects.ObjectId, Bool] = Map::new()
  resolve_file_spec_object_inner(file, value, context, seen, None, false, value)
}

///|
fn resolve_file_spec_object_inner(
  file : PdfFile,
  value : @objects.PdfObject,
  context : String,
  seen : Map[@objects.ObjectId, Bool],
  source_object_id : @objects.ObjectId?,
  indirect : Bool,
  raw_object : @objects.PdfObject,
) -> PdfResolvedFileSpecObject raise PdfDocumentError {
  match value {
    @objects.PdfObject::Ref(object_id) => {
      if seen.contains(object_id) {
        raise PdfDocumentError::CycleDetected(
          object_id,
          context + " indirect-object cycle detected",
        )
      }
      seen[object_id] = true
      let loaded = load_file_spec_object(file, object_id)
      let source = match source_object_id {
        Some(id) => Some(id)
        None => Some(object_id)
      }
      resolve_file_spec_object_inner(
        file, loaded, context, seen, source, true, raw_object,
      )
    }
    _ =>
      PdfResolvedFileSpecObject::{
        object: value,
        source_object_id,
        indirect,
        raw_object,
      }
  }
}

///|
fn resolve_file_spec_child_object(
  file : PdfFile,
  value : @objects.PdfObject,
  owner : @objects.ObjectId?,
  context : String,
) -> PdfResolvedFileSpecObject raise PdfDocumentError {
  try resolve_file_spec_object(file, value, context) catch {
    PdfDocumentError::CycleDetected(id, reason) =>
      raise PdfDocumentError::CycleDetected(id, reason)
    PdfDocumentError::ReaderError(error) =>
      raise PdfDocumentError::ReaderError(error)
    _ => raise file_spec_error(owner, context + " could not be resolved")
  } noraise {
    resolved => resolved
  }
}

///|
fn file_spec_name(
  value : @objects.PdfObject,
  owner : @objects.ObjectId?,
  label : String,
) -> @objects.PdfName raise PdfDocumentError {
  match value {
    @objects.PdfObject::Name(name) => name
    _ => raise file_spec_error(owner, label + " must be a name")
  }
}

///|
fn file_spec_string(
  value : @objects.PdfObject,
  owner : @objects.ObjectId?,
  label : String,
) -> Bytes raise PdfDocumentError {
  match value {
    @objects.PdfObject::String(bytes) => bytes
    _ => raise file_spec_error(owner, label + " must be a string")
  }
}

///|
fn file_spec_boolean(
  value : @objects.PdfObject,
  owner : @objects.ObjectId?,
  label : String,
) -> Bool raise PdfDocumentError {
  match value {
    @objects.PdfObject::Boolean(value) => value
    _ => raise file_spec_error(owner, label + " must be a boolean")
  }
}

///|
fn file_spec_dictionary(
  value : @objects.PdfObject,
  owner : @objects.ObjectId?,
  label : String,
) -> @objects.PdfDictionary raise PdfDocumentError {
  match value {
    @objects.PdfObject::Dictionary(dict) => dict
    _ => raise file_spec_error(owner, label + " must be a dictionary")
  }
}

///|
fn file_spec_array(
  value : @objects.PdfObject,
  owner : @objects.ObjectId?,
  label : String,
) -> Array[@objects.PdfObject] raise PdfDocumentError {
  match value {
    @objects.PdfObject::Array(values) => values
    _ => raise file_spec_error(owner, label + " must be an array")
  }
}

///|
fn file_spec_integer(
  value : @objects.PdfObject,
  owner : @objects.ObjectId?,
  label : String,
) -> Int64 raise PdfDocumentError {
  match value {
    @objects.PdfObject::Integer(number) => number
    _ => raise file_spec_error(owner, label + " must be an integer")
  }
}

///|
fn file_spec_append_bytes(out : Array[Byte], bytes : Bytes) -> Unit {
  for index in 0..<bytes.length() {
    out.push(bytes[index])
  }
}

///|
fn file_spec_join_components(
  components : Array[Bytes],
  absolute : Bool,
) -> Bytes {
  let out : Array[Byte] = []
  if absolute {
    out.push(b'/')
  }
  let mut index = 0
  let mut emitted_component = false
  while index < components.length() {
    if absolute && index == 0 && components[index].length() == 0 {
      index += 1
      continue
    }
    if emitted_component {
      out.push(b'/')
    }
    file_spec_append_bytes(out, components[index])
    emitted_component = true
    index += 1
  }
  Bytes::from_array(out)
}
