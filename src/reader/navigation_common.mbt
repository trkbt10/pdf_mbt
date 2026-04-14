///|
fn navigation_key(bytes : Bytes) -> @objects.PdfName {
  @objects.PdfName::new(bytes)
}

///|
fn navigation_error(
  key : @objects.PdfName,
  reason : String,
) -> PdfDocumentError {
  PdfDocumentError::InvalidNavigation(key, reason)
}

///|
fn load_navigation_object(
  file : PdfFile,
  object_id : @objects.ObjectId,
  key : @objects.PdfName,
  context : String,
) -> @objects.PdfObject raise PdfDocumentError {
  let _ = key
  let _ = context
  try file.load_object(object_id) catch {
    error => raise PdfDocumentError::ReaderError(error)
  } noraise {
    value => value
  }
}

///|
fn resolve_navigation_object(
  file : PdfFile,
  value : @objects.PdfObject,
  key : @objects.PdfName,
  context : String,
  seen : Map[@objects.ObjectId, Bool],
) -> @objects.PdfObject raise PdfDocumentError {
  match value {
    @objects.PdfObject::Ref(object_id) => {
      if seen.contains(object_id) {
        raise PdfDocumentError::CycleDetected(
          object_id,
          context + " indirect-object cycle detected",
        )
      }
      seen[object_id] = true
      let loaded = load_navigation_object(file, object_id, key, context)
      resolve_navigation_object(file, loaded, key, context, seen)
    }
    _ => value
  }
}

///|
fn resolve_navigation_direct(
  file : PdfFile,
  value : @objects.PdfObject,
  key : @objects.PdfName,
  context : String,
) -> @objects.PdfObject raise PdfDocumentError {
  let seen : Map[@objects.ObjectId, Bool] = Map::new()
  resolve_navigation_object(file, value, key, context, seen)
}

///|
fn require_navigation_dictionary(
  file : PdfFile,
  value : @objects.PdfObject,
  key : @objects.PdfName,
  context : String,
) -> @objects.PdfDictionary raise PdfDocumentError {
  match resolve_navigation_direct(file, value, key, context) {
    @objects.PdfObject::Dictionary(dict) => dict
    _ => raise navigation_error(key, context + " must be a dictionary")
  }
}

///|
fn require_navigation_stream(
  file : PdfFile,
  value : @objects.PdfObject,
  key : @objects.PdfName,
  context : String,
) -> @objects.PdfStream raise PdfDocumentError {
  match resolve_navigation_direct(file, value, key, context) {
    @objects.PdfObject::Stream(stream) => stream
    _ => raise navigation_error(key, context + " must be a stream")
  }
}

///|
fn navigation_bool_or_default(
  dict : @objects.PdfDictionary,
  key : @objects.PdfName,
  default : Bool,
  owner : @objects.PdfName,
) -> Bool raise PdfDocumentError {
  match dict.get(key) {
    Some(@objects.PdfObject::Boolean(value)) => value
    Some(_) => raise navigation_error(owner, key.to_text() + " must be boolean")
    None => default
  }
}

///|
fn navigation_int(
  value : @objects.PdfObject,
  owner : @objects.PdfName,
  label : String,
) -> Int raise PdfDocumentError {
  match value {
    @objects.PdfObject::Integer(number) => number.to_int()
    _ => raise navigation_error(owner, label + " must be an integer")
  }
}

///|
fn navigation_number(
  value : @objects.PdfObject,
  owner : @objects.PdfName,
  label : String,
) -> Double raise PdfDocumentError {
  match value {
    @objects.PdfObject::Integer(number) => number.to_double()
    @objects.PdfObject::Real(number) => number
    _ => raise navigation_error(owner, label + " must be a number")
  }
}

///|
fn navigation_optional_number(
  value : @objects.PdfObject,
  owner : @objects.PdfName,
  label : String,
) -> Double? raise PdfDocumentError {
  match value {
    @objects.PdfObject::Null => None
    _ => Some(navigation_number(value, owner, label))
  }
}

///|
fn navigation_name(
  value : @objects.PdfObject,
  owner : @objects.PdfName,
  label : String,
) -> @objects.PdfName raise PdfDocumentError {
  match value {
    @objects.PdfObject::Name(name) => name
    _ => raise navigation_error(owner, label + " must be a name")
  }
}

///|
fn navigation_string(
  value : @objects.PdfObject,
  owner : @objects.PdfName,
  label : String,
) -> Bytes raise PdfDocumentError {
  match value {
    @objects.PdfObject::String(bytes) => bytes
    _ => raise navigation_error(owner, label + " must be a string")
  }
}

///|
fn navigation_array(
  value : @objects.PdfObject,
  owner : @objects.PdfName,
  label : String,
) -> Array[@objects.PdfObject] raise PdfDocumentError {
  match value {
    @objects.PdfObject::Array(values) => values
    _ => raise navigation_error(owner, label + " must be an array")
  }
}

///|
fn navigation_rectangle(
  value : @objects.PdfObject,
  owner : @objects.PdfName,
  label : String,
) -> PdfRectangle raise PdfDocumentError {
  let values = navigation_array(value, owner, label)
  if values.length() != 4 {
    raise navigation_error(owner, label + " must contain four numbers")
  }
  PdfRectangle::{
    left: navigation_number(values[0], owner, label),
    bottom: navigation_number(values[1], owner, label),
    right: navigation_number(values[2], owner, label),
    top: navigation_number(values[3], owner, label),
  }
}

///|
fn navigation_color_components(
  value : @objects.PdfObject,
  owner : @objects.PdfName,
  label : String,
  max_components : Int,
) -> Array[Double] raise PdfDocumentError {
  let values = navigation_array(value, owner, label)
  if values.length() > max_components {
    raise navigation_error(owner, label + " has too many components")
  }
  let components : Array[Double] = []
  for item in values {
    let component = navigation_number(item, owner, label)
    if component < 0.0 || component > 1.0 {
      raise navigation_error(owner, label + " components must be in 0..1")
    }
    components.push(component)
  }
  components
}

///|
fn first_page_object_id(
  document : PdfDocument,
) -> @objects.ObjectId? raise PdfDocumentError {
  let page_index = ensure_page_index(document)
  if page_index.pages.length() == 0 {
    None
  } else {
    Some(page_index.pages[0].object_id)
  }
}

///|
fn page_index_for_object_id(
  document : PdfDocument,
  object_id : @objects.ObjectId,
) -> Int? raise PdfDocumentError {
  let page_index = ensure_page_index(document)
  for page in page_index.pages {
    if page.object_id == object_id {
      return Some(page.index)
    }
  }
  None
}

///|
fn require_page_object_id(
  document : PdfDocument,
  object_id : @objects.ObjectId,
  owner : @objects.PdfName,
) -> Unit raise PdfDocumentError {
  match page_index_for_object_id(document, object_id) {
    Some(_) => ()
    None =>
      raise navigation_error(owner, "destination page reference is not a page")
  }
}

///|
fn require_page_index_bounds(
  document : PdfDocument,
  page_index : Int,
  owner : @objects.PdfName,
) -> Unit raise PdfDocumentError {
  let count = document.page_count()
  if page_index < 0 || page_index >= count {
    raise navigation_error(owner, "page index is out of range")
  }
}
