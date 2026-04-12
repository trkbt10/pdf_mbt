///|
priv struct ObjectStreamHeaderPair {
  object_number : Int
  relative_offset : Int
} derive(Eq, Debug)

///|
priv struct ObjectStreamMember {
  object_number : Int
  object : @objects.PdfObject
} derive(Eq, Debug)

///|
priv struct ObjectStreamTable {
  offset : Int64
  members : Array[ObjectStreamMember]
} derive(Eq, Debug)

///|
fn parse_object_stream(
  stream : @objects.PdfStream,
  offset~ : Int64,
) -> ObjectStreamTable raise PdfReaderError {
  require_object_stream_type(stream.dict, offset)
  let member_count = read_object_stream_required_int(stream.dict, b"N", offset)
  let first = read_object_stream_required_int(stream.dict, b"First", offset)
  let decoded = decode_structural_stream(stream, ObjectStream, offset~)
  let header_pairs = read_object_stream_header_pairs(
    decoded, member_count, first, offset,
  )
  let members = read_object_stream_members(decoded, first, header_pairs, offset)
  ObjectStreamTable::{ offset, members }
}

///|
fn ObjectStreamTable::entry_at(
  self : ObjectStreamTable,
  index : Int,
) -> ObjectStreamMember raise PdfReaderError {
  match self.members.get(index) {
    Some(entry) => entry
    None =>
      raise PdfReaderError::InvalidObjectStream(
        self.offset,
        "object stream member index is out of range",
      )
  }
}

///|
fn require_object_stream_type(
  dict : @objects.PdfDictionary,
  offset : Int64,
) -> Unit raise PdfReaderError {
  let key = @objects.PdfName::new(b"Type")
  let expected = @objects.PdfName::new(b"ObjStm")
  match dict.get(key) {
    Some(@objects.PdfObject::Name(name)) if name == expected => ()
    Some(_) =>
      raise PdfReaderError::InvalidObjectStream(
        offset, "object stream must have /Type /ObjStm",
      )
    None =>
      raise PdfReaderError::InvalidObjectStream(
        offset, "object stream must have /Type /ObjStm",
      )
  }
}

///|
fn read_object_stream_required_int(
  dict : @objects.PdfDictionary,
  key : Bytes,
  offset : Int64,
) -> Int raise PdfReaderError {
  let field_name = @objects.PdfName::new(key).to_text()
  match dict.get(@objects.PdfName::new(key)) {
    Some(@objects.PdfObject::Integer(value)) =>
      require_object_stream_int(value, offset, field_name)
    Some(_) =>
      raise PdfReaderError::InvalidObjectStream(
        offset,
        "\{field_name} entry must be a direct non-negative integer",
      )
    None =>
      raise PdfReaderError::InvalidObjectStream(
        offset,
        "missing \{field_name} entry",
      )
  }
}

///|
fn require_object_stream_int(
  value : Int64,
  offset : Int64,
  field_name : String,
) -> Int raise PdfReaderError {
  if value < 0L {
    raise PdfReaderError::InvalidObjectStream(
      offset,
      "\{field_name} entry must be a direct non-negative integer",
    )
  }
  if value > 2147483647L {
    raise PdfReaderError::InvalidObjectStream(
      offset,
      "\{field_name} entry is too large for Int",
    )
  }
  value.to_int()
}

///|
fn read_object_stream_header_pairs(
  decoded : Bytes,
  member_count : Int,
  first : Int,
  offset : Int64,
) -> Array[ObjectStreamHeaderPair] raise PdfReaderError {
  if first > decoded.length() {
    raise PdfReaderError::InvalidObjectStream(
      offset, "First entry exceeds decoded object stream length",
    )
  }

  let header_bytes = decoded[0:first].to_bytes()
  let parsed_result : Result[Array[@objects.PdfObject], @objects.PdfParseError] = try? @parser.parse_all_objects(
    header_bytes,
  )
  let parsed = match parsed_result {
    Ok(values) => values
    Err(_) =>
      raise PdfReaderError::InvalidObjectStream(
        offset, "invalid object stream header",
      )
  }

  if parsed.length().to_int64() != member_count.to_int64() * 2L {
    raise PdfReaderError::InvalidObjectStream(
      offset, "object stream header must contain N object/offset pairs",
    )
  }

  let pairs : Array[ObjectStreamHeaderPair] = []
  let mut index = 0
  while index < parsed.length() {
    let object_number = read_object_stream_header_int(
      parsed[index],
      offset,
      "object stream header object number",
    )
    let relative_offset = read_object_stream_header_int(
      parsed[index + 1],
      offset,
      "object stream header relative offset",
    )
    pairs.push(ObjectStreamHeaderPair::{ object_number, relative_offset })
    index = index + 2
  }

  pairs
}

///|
fn read_object_stream_header_int(
  value : @objects.PdfObject,
  offset : Int64,
  context : String,
) -> Int raise PdfReaderError {
  match value {
    @objects.PdfObject::Integer(number) =>
      require_object_stream_int(number, offset, context)
    _ =>
      raise PdfReaderError::InvalidObjectStream(
        offset,
        "\{context} must be a direct non-negative integer",
      )
  }
}

///|
fn read_object_stream_members(
  decoded : Bytes,
  first : Int,
  header_pairs : Array[ObjectStreamHeaderPair],
  offset : Int64,
) -> Array[ObjectStreamMember] raise PdfReaderError {
  if header_pairs.length() > 0 && header_pairs[0].relative_offset != 0 {
    raise PdfReaderError::InvalidObjectStream(
      offset, "first object stream member relative offset must be 0",
    )
  }

  let members : Array[ObjectStreamMember] = []
  let body_end = decoded.length()
  let mut index = 0
  while index < header_pairs.length() {
    let pair = header_pairs[index]
    let member_start = checked_object_stream_add(
      first,
      pair.relative_offset,
      offset,
      "object stream member offset",
    )
    if member_start >= body_end {
      raise PdfReaderError::InvalidObjectStream(
        offset, "object stream member offset exceeds decoded object stream length",
      )
    }

    let member_end = if index + 1 < header_pairs.length() {
      let next = checked_object_stream_add(
        first,
        header_pairs[index + 1].relative_offset,
        offset,
        "object stream member offset",
      )
      if next <= member_start {
        raise PdfReaderError::InvalidObjectStream(
          offset, "object stream member offsets must be strictly increasing",
        )
      }
      if next > body_end {
        raise PdfReaderError::InvalidObjectStream(
          offset, "object stream member offset exceeds decoded object stream length",
        )
      }
      next
    } else {
      body_end
    }

    let member_bytes = decoded[member_start:member_end].to_bytes()
    let member_offset = checked_object_stream_pdf_offset(
      offset, member_start, offset, "object stream member parse offset",
    )
    let member_object = parse_object_stream_member(member_bytes, member_offset)
    members.push(ObjectStreamMember::{
      object_number: pair.object_number,
      object: member_object,
    })
    index = index + 1
  }

  members
}

///|
fn parse_object_stream_member(
  bytes : Bytes,
  member_offset : Int64,
) -> @objects.PdfObject raise PdfReaderError {
  let parsed_result : Result[Array[@objects.PdfObject], @objects.PdfParseError] = try? @parser.parse_all_objects(
    bytes,
  )
  let parsed = match parsed_result {
    Ok(values) => values
    Err(error) =>
      match error {
        @objects.PdfParseError::UnexpectedToken(_, _, actual) if actual ==
          "stream" ||
          actual == "obj" ||
          actual == "endstream" =>
          raise PdfReaderError::InvalidObjectStream(
            member_offset, "stream objects are not allowed inside an object stream",
          )
        _ => raise PdfReaderError::ParseObjectError(member_offset, error)
      }
  }

  if parsed.length() != 1 {
    raise PdfReaderError::InvalidObjectStream(
      member_offset, "object stream member must contain exactly one direct object",
    )
  }

  match parsed[0] {
    @objects.PdfObject::Stream(_) =>
      raise PdfReaderError::InvalidObjectStream(
        member_offset, "stream objects are not allowed inside an object stream",
      )
    value => value
  }
}

///|
fn checked_object_stream_add(
  left : Int,
  right : Int,
  offset : Int64,
  context : String,
) -> Int raise PdfReaderError {
  let total = left.to_int64() + right.to_int64()
  if total > 2147483647L {
    raise PdfReaderError::InvalidObjectStream(
      offset,
      "\{context} is too large for Int",
    )
  }
  total.to_int()
}

///|
fn checked_object_stream_pdf_offset(
  base : Int64,
  delta : Int,
  offset : Int64,
  context : String,
) -> Int64 raise PdfReaderError {
  let delta64 = delta.to_int64()
  let max_int64 = 9223372036854775807L
  if base > max_int64 - delta64 {
    raise PdfReaderError::InvalidObjectStream(
      offset,
      "\{context} is too large for Int64",
    )
  }
  base + delta64
}
