///|
fn pdf_name(bytes : Bytes) -> @objects.PdfName {
  @objects.PdfName::new(bytes)
}

///|
fn graphics_resource_error(offset : Int64, reason : String) -> PdfGraphicsError {
  PdfGraphicsError::InvalidGraphicsState(offset, reason)
}

///|
fn object_kind_label(object : @objects.PdfObject) -> String {
  match object {
    @objects.PdfObject::Boolean(_) => "boolean"
    @objects.PdfObject::Integer(_) => "integer"
    @objects.PdfObject::Real(_) => "real"
    @objects.PdfObject::String(_) => "string"
    @objects.PdfObject::Name(_) => "name"
    @objects.PdfObject::Array(_) => "array"
    @objects.PdfObject::Dictionary(_) => "dictionary"
    @objects.PdfObject::Stream(_) => "stream"
    @objects.PdfObject::Null => "null"
    @objects.PdfObject::Ref(_) => "ref"
  }
}

///|
fn missing_required(key : Bytes, offset : Int64) -> PdfGraphicsError {
  graphics_resource_error(offset, "missing required /\{key.to_string()} entry")
}

///|
fn required_entry(
  dict : @objects.PdfDictionary,
  key : Bytes,
  offset : Int64,
) -> @objects.PdfObject raise PdfGraphicsError {
  match dict.get(pdf_name(key)) {
    Some(value) => value
    None => raise missing_required(key, offset)
  }
}

///|
fn optional_entry(
  dict : @objects.PdfDictionary,
  key : Bytes,
) -> @objects.PdfObject? {
  dict.get(pdf_name(key))
}

///|
fn require_name_value(
  object : @objects.PdfObject,
  offset : Int64,
  label : String,
) -> @objects.PdfName raise PdfGraphicsError {
  match object {
    @objects.PdfObject::Name(name) => name
    _ =>
      raise graphics_resource_error(
        offset,
        "\{label} must be a name, got \{object_kind_label(object)}",
      )
  }
}

///|
fn require_integer_value(
  object : @objects.PdfObject,
  offset : Int64,
  label : String,
) -> Int64 raise PdfGraphicsError {
  match object {
    @objects.PdfObject::Integer(value) => value
    _ =>
      raise graphics_resource_error(
        offset,
        "\{label} must be an integer, got \{object_kind_label(object)}",
      )
  }
}

///|
fn require_number_value(
  object : @objects.PdfObject,
  offset : Int64,
  label : String,
) -> Double raise PdfGraphicsError {
  match object {
    @objects.PdfObject::Integer(value) => value.to_double()
    @objects.PdfObject::Real(value) => value
    _ =>
      raise graphics_resource_error(
        offset,
        "\{label} must be a number, got \{object_kind_label(object)}",
      )
  }
}

///|
fn require_bool_value(
  object : @objects.PdfObject,
  offset : Int64,
  label : String,
) -> Bool raise PdfGraphicsError {
  match object {
    @objects.PdfObject::Boolean(value) => value
    _ =>
      raise graphics_resource_error(
        offset,
        "\{label} must be a boolean, got \{object_kind_label(object)}",
      )
  }
}

///|
fn require_dictionary_value(
  object : @objects.PdfObject,
  offset : Int64,
  label : String,
) -> @objects.PdfDictionary raise PdfGraphicsError {
  match object {
    @objects.PdfObject::Dictionary(dict) => dict
    _ =>
      raise graphics_resource_error(
        offset,
        "\{label} must be a dictionary, got \{object_kind_label(object)}",
      )
  }
}

///|
fn require_array_value(
  object : @objects.PdfObject,
  offset : Int64,
  label : String,
) -> Array[@objects.PdfObject] raise PdfGraphicsError {
  match object {
    @objects.PdfObject::Array(values) => values
    _ =>
      raise graphics_resource_error(
        offset,
        "\{label} must be an array, got \{object_kind_label(object)}",
      )
  }
}

///|
fn require_number_array_value(
  object : @objects.PdfObject,
  expected : Int,
  offset : Int64,
  label : String,
) -> Array[Double] raise PdfGraphicsError {
  let values = require_array_value(object, offset, label)
  if values.length() != expected {
    raise graphics_resource_error(
      offset,
      "\{label} must contain \{expected} numbers",
    )
  }
  let numbers : Array[Double] = []
  for value in values {
    numbers.push(require_number_value(value, offset, label))
  }
  numbers
}

///|
fn optional_number_array_value(
  dict : @objects.PdfDictionary,
  key : Bytes,
  expected : Int,
  default : Array[Double],
  offset : Int64,
  label : String,
) -> Array[Double] raise PdfGraphicsError {
  match optional_entry(dict, key) {
    Some(value) => require_number_array_value(value, expected, offset, label)
    None => default.copy()
  }
}

///|
fn required_graphics_rect(
  dict : @objects.PdfDictionary,
  key : Bytes,
  offset : Int64,
  label : String,
) -> GraphicsRect raise PdfGraphicsError {
  let rect = try
    @common_data.parse_pdf_rectangle(required_entry(dict, key, offset))
  catch {
    _ => raise graphics_resource_error(offset, "\{label} invalid rectangle")
  } noraise {
    value => value
  }
  GraphicsRect::new(rect.left, rect.bottom, rect.right, rect.top)
}

///|
fn optional_graphics_rect(
  dict : @objects.PdfDictionary,
  key : Bytes,
  offset : Int64,
  label : String,
) -> GraphicsRect? raise PdfGraphicsError {
  match optional_entry(dict, key) {
    Some(value) => {
      let rect = try @common_data.parse_pdf_rectangle(value) catch {
        _ => raise graphics_resource_error(offset, "\{label} invalid rectangle")
      } noraise {
        value => value
      }
      Some(GraphicsRect::new(rect.left, rect.bottom, rect.right, rect.top))
    }
    None => None
  }
}

///|
fn optional_graphics_matrix(
  dict : @objects.PdfDictionary,
  offset : Int64,
  label : String,
) -> GraphicsMatrix raise PdfGraphicsError {
  let values = optional_number_array_value(
    dict,
    b"Matrix",
    6,
    [1.0, 0.0, 0.0, 1.0, 0.0, 0.0],
    offset,
    label,
  )
  GraphicsMatrix::from_six(
    values[0],
    values[1],
    values[2],
    values[3],
    values[4],
    values[5],
  )
}

///|
fn optional_bool_entry(
  dict : @objects.PdfDictionary,
  key : Bytes,
  default : Bool,
  offset : Int64,
  label : String,
) -> Bool raise PdfGraphicsError {
  match optional_entry(dict, key) {
    Some(value) => require_bool_value(value, offset, label)
    None => default
  }
}

///|
fn require_type_marker(
  dict : @objects.PdfDictionary,
  expected : Bytes,
  offset : Int64,
  label : String,
) -> Unit raise PdfGraphicsError {
  match optional_entry(dict, b"Type") {
    Some(value) => {
      let name = require_name_value(value, offset, label + " Type")
      if name != pdf_name(expected) {
        raise graphics_resource_error(offset, label + " Type marker mismatch")
      }
    }
    None => ()
  }
}

///|
fn map_filter_error(
  offset : Int64,
  context : String,
  _error : @filters.PdfFilterError,
) -> PdfGraphicsError {
  PdfGraphicsError::InvalidGraphicsState(
    offset,
    context + " filter decode failed",
  )
}
