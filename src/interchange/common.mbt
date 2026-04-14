///|
fn pdf_name(bytes : Bytes) -> @objects.PdfName {
  @objects.PdfName::new(bytes)
}

///|
fn object_kind(object : @objects.PdfObject) -> String {
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
    @objects.PdfObject::Ref(_) => "reference"
  }
}

///|
fn name_text(name : @objects.PdfName) -> String {
  @utf8.decode_lossy(name.bytes)
}

///|
fn common_data_reason(error : @common_data.PdfCommonDataError) -> String {
  match error {
    @common_data.PdfCommonDataError::ExpectedString(reason) => reason
    @common_data.PdfCommonDataError::InvalidTextString(reason) => reason
    @common_data.PdfCommonDataError::InvalidAsciiString(reason) => reason
    @common_data.PdfCommonDataError::InvalidDate(_, reason) => reason
    @common_data.PdfCommonDataError::InvalidRectangle(reason) => reason
    @common_data.PdfCommonDataError::InvalidTreeNode(reason) => reason
  }
}

///|
fn required_name_entry(
  dict : @objects.PdfDictionary,
  key : Bytes,
  expected : Bytes,
  owner_id : @objects.ObjectId?,
  component : String,
) -> Unit raise PdfInterchangeError {
  let key_name = pdf_name(key)
  match dict.get(key_name) {
    Some(@objects.PdfObject::Name(value)) if value == pdf_name(expected) => ()
    Some(@objects.PdfObject::Name(value)) =>
      raise PdfInterchangeError::InvalidMetadata(
        owner_id,
        component +
        " /" +
        @utf8.decode_lossy(key) +
        " must be /" +
        @utf8.decode_lossy(expected) +
        " but found /" +
        name_text(value),
      )
    Some(value) =>
      raise PdfInterchangeError::InvalidMetadata(
        owner_id,
        component +
        " /" +
        @utf8.decode_lossy(key) +
        " must be a name, not " +
        object_kind(value),
      )
    None =>
      raise PdfInterchangeError::InvalidMetadata(
        owner_id,
        component +
        " is missing /" +
        @utf8.decode_lossy(key) +
        " /" +
        @utf8.decode_lossy(expected),
      )
  }
}

///|
fn contains_ref(object : @objects.PdfObject) -> Bool {
  match object {
    @objects.PdfObject::Ref(_) => true
    @objects.PdfObject::Array(values) => {
      for value in values {
        if contains_ref(value) {
          return true
        }
      }
      false
    }
    @objects.PdfObject::Dictionary(dict) => {
      for _, value in dict {
        if contains_ref(value) {
          return true
        }
      }
      false
    }
    @objects.PdfObject::Stream(_) => true
    _ => false
  }
}
