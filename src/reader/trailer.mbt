///|
fn parse_trailer_info(
  dict : @objects.PdfDictionary,
  version : PdfVersion,
  offset~ : Int64,
) -> TrailerInfo raise PdfReaderError {
  parse_trailer_info_impl(dict, version, offset)
}

///|
fn parse_trailer_info_impl(
  dict : @objects.PdfDictionary,
  version : PdfVersion,
  offset : Int64,
) -> TrailerInfo raise PdfReaderError {
  let size = read_required_trailer_size(dict, offset)
  let root = read_required_trailer_ref(dict, b"Root", "Root", offset)
  let prev = read_optional_trailer_offset(dict, b"Prev", "Prev", offset)
  let encrypt = read_optional_trailer_ref(dict, b"Encrypt", "Encrypt", offset)
  let info = read_optional_trailer_ref(dict, b"Info", "Info", offset)
  let id = read_trailer_file_id(dict, version, offset)
  let xref_stm = read_optional_trailer_offset(
    dict, b"XRefStm", "XRefStm", offset,
  )
  TrailerInfo::{ size, root, prev, encrypt, info, id, xref_stm, raw_dict: dict }
}

///|
fn read_required_trailer_size(
  dict : @objects.PdfDictionary,
  offset : Int64,
) -> Int raise PdfReaderError {
  let value = read_required_trailer_integer(dict, b"Size", "Size", offset)
  if value <= 0L {
    raise PdfReaderError::InvalidTrailer(
      offset, "Size entry must be a positive integer",
    )
  }
  if value > 2147483647L {
    raise PdfReaderError::InvalidTrailer(
      offset, "Size entry is too large for TrailerInfo.size",
    )
  }
  value.to_int()
}

///|
fn read_optional_trailer_offset(
  dict : @objects.PdfDictionary,
  key : Bytes,
  field_name : String,
  offset : Int64,
) -> Int64? raise PdfReaderError {
  match read_optional_trailer_integer(dict, key, field_name, offset) {
    Some(value) => {
      if value < 0L {
        raise PdfReaderError::InvalidTrailer(
          offset,
          "\{field_name} entry must be a non-negative integer",
        )
      }
      Some(value)
    }
    None => None
  }
}

///|
fn read_required_trailer_integer(
  dict : @objects.PdfDictionary,
  key : Bytes,
  field_name : String,
  offset : Int64,
) -> Int64 raise PdfReaderError {
  match dict.get(@objects.PdfName::new(key)) {
    Some(Integer(value)) => value
    Some(_) =>
      raise PdfReaderError::InvalidTrailer(
        offset,
        "\{field_name} entry must be a direct integer",
      )
    None =>
      raise PdfReaderError::InvalidTrailer(
        offset,
        "missing \{field_name} entry",
      )
  }
}

///|
fn read_optional_trailer_integer(
  dict : @objects.PdfDictionary,
  key : Bytes,
  field_name : String,
  offset : Int64,
) -> Int64? raise PdfReaderError {
  match dict.get(@objects.PdfName::new(key)) {
    Some(Integer(value)) => Some(value)
    Some(_) =>
      raise PdfReaderError::InvalidTrailer(
        offset,
        "\{field_name} entry must be a direct integer",
      )
    None => None
  }
}

///|
fn read_required_trailer_ref(
  dict : @objects.PdfDictionary,
  key : Bytes,
  field_name : String,
  offset : Int64,
) -> @objects.ObjectId raise PdfReaderError {
  match dict.get(@objects.PdfName::new(key)) {
    Some(Ref(value)) => value
    Some(_) =>
      raise PdfReaderError::InvalidTrailer(
        offset,
        "\{field_name} entry must be an indirect reference",
      )
    None =>
      raise PdfReaderError::InvalidTrailer(
        offset,
        "missing \{field_name} entry",
      )
  }
}

///|
fn read_optional_trailer_ref(
  dict : @objects.PdfDictionary,
  key : Bytes,
  field_name : String,
  offset : Int64,
) -> @objects.ObjectId? raise PdfReaderError {
  match dict.get(@objects.PdfName::new(key)) {
    Some(Ref(value)) => Some(value)
    Some(_) =>
      raise PdfReaderError::InvalidTrailer(
        offset,
        "\{field_name} entry must be an indirect reference",
      )
    None => None
  }
}

///|
fn read_trailer_file_id(
  dict : @objects.PdfDictionary,
  version : PdfVersion,
  offset : Int64,
) -> PdfFileId? raise PdfReaderError {
  let key = @objects.PdfName::new(b"ID")
  match dict.get(key) {
    Some(Array(values)) => Some(read_trailer_file_id_values(values, offset))
    Some(_) =>
      raise PdfReaderError::InvalidTrailer(
        offset, "ID entry must be an array of two byte strings",
      )
    None =>
      if requires_file_id(version) {
        raise PdfReaderError::InvalidTrailer(
          offset, "missing ID entry for PDF 2.0 trailer",
        )
      } else {
        None
      }
  }
}

///|
fn read_trailer_file_id_values(
  values : Array[@objects.PdfObject],
  offset : Int64,
) -> PdfFileId raise PdfReaderError {
  if values.length() != 2 {
    raise PdfReaderError::InvalidTrailer(
      offset, "ID entry must be an array of two byte strings",
    )
  }

  let first = read_trailer_file_id_value(values[0], offset)
  let second = read_trailer_file_id_value(values[1], offset)
  PdfFileId::{ first, second }
}

///|
fn read_trailer_file_id_value(
  value : @objects.PdfObject,
  offset : Int64,
) -> Bytes raise PdfReaderError {
  match value {
    String(bytes) => bytes
    _ =>
      raise PdfReaderError::InvalidTrailer(
        offset, "ID entry must be an array of two byte strings",
      )
  }
}

///|
fn requires_file_id(version : PdfVersion) -> Bool {
  version.major == 2 && version.minor == 0
}
