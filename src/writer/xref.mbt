///|
/// Incremental save support: stores PDF file identifiers used when appending
/// a new cross-reference table and trailer with /Prev while preserving the
/// original file content.
priv struct PdfWriterFileId {
  first : Bytes
  second : Bytes
} derive(Eq, Debug)

///|
/// New cross-reference section trailer data: /Size, /Root, optional /Prev,
/// and /ID entries for traditional xref table serialization.
priv struct PdfTrailerSpec {
  size : Int
  root : @objects.ObjectId
  prev : Int64?
  file_id : PdfWriterFileId?
} derive(Eq, Debug)

///|
/// Cross-reference table entry for a modified indirect object; the byte offset
/// is updated for the new xref subsection.
priv struct PdfXrefEntry {
  id : @objects.ObjectId
  offset : Int64
} derive(Eq, Debug)

///|
fn PdfXrefEntry::new(id : @objects.ObjectId, offset : Int64) -> PdfXrefEntry {
  PdfXrefEntry::{ id, offset }
}

///|
fn PdfTrailerSpec::new(
  size : Int,
  root : @objects.ObjectId,
  prev : Int64?,
  file_id : PdfWriterFileId?,
) -> PdfTrailerSpec {
  PdfTrailerSpec::{ size, root, prev, file_id }
}

///|
fn serialize_xref_section(
  entries : Array[PdfXrefEntry],
  trailer : PdfTrailerSpec,
) -> Bytes {
  let size = max_trailer_size(entries, trailer.size)
  let body : Array[Byte] = []
  body.append(b"xref\r\n".to_array())
  body.append(decimal_bytes(0L).to_array())
  body.push(b' ')
  body.append(decimal_bytes(1L).to_array())
  body.append(b"\r\n".to_array())
  body.append(xref_entry_line(0L, 65535, b'f').to_array())
  for entry in entries {
    if entry.id.object_number != 0 {
      body.append(decimal_bytes(entry.id.object_number.to_int64()).to_array())
      body.push(b' ')
      body.append(decimal_bytes(1L).to_array())
      body.append(b"\r\n".to_array())
      body.append(
        xref_entry_line(entry.offset, entry.id.generation_number, b'n').to_array(),
      )
    }
  }
  body.append(b"trailer\r\n".to_array())
  body.append(
    serialize_object(Dictionary(trailer_dictionary(size, trailer))).to_array(),
  )
  body.append(b"\r\n".to_array())
  Bytes::from_array(body)
}

///|
fn trailer_dictionary(
  size : Int,
  trailer : PdfTrailerSpec,
) -> @objects.PdfDictionary {
  let dict : @objects.PdfDictionary = Map::new()
  dict[@objects.PdfName::new(b"Size")] = Integer(size.to_int64())
  dict[@objects.PdfName::new(b"Root")] = Ref(trailer.root)
  match trailer.prev {
    Some(offset) => dict[@objects.PdfName::new(b"Prev")] = Integer(offset)
    None => ()
  }
  match trailer.file_id {
    Some(id) =>
      dict[@objects.PdfName::new(b"ID")] = Array([
        String(id.first),
        String(id.second),
      ])
    None => ()
  }
  dict
}

///|
fn max_trailer_size(entries : Array[PdfXrefEntry], declared : Int) -> Int {
  let mut size = declared
  for entry in entries {
    let candidate = entry.id.object_number + 1
    if candidate > size {
      size = candidate
    }
  }
  size
}

///|
fn xref_entry_line(
  next_or_offset : Int64,
  generation : Int,
  marker : Byte,
) -> Bytes {
  fixed_width_decimal(next_or_offset, 10) +
  b" " +
  fixed_width_decimal(generation.to_int64(), 5) +
  b" " +
  Bytes::from_array([marker, b'\r', b'\n'])
}

///|
fn fixed_width_decimal(value : Int64, width : Int) -> Bytes {
  let digits = decimal_bytes(value)
  let out : Array[Byte] = []
  let mut padding = width - digits.length()
  while padding > 0 {
    out.push(b'0')
    padding = padding - 1
  }
  for digit in digits {
    out.push(digit)
  }
  Bytes::from_array(out)
}

///|
fn decimal_bytes(value : Int64) -> Bytes {
  if value < 0L {
    b"-" + positive_decimal_bytes(0L - value)
  } else {
    positive_decimal_bytes(value)
  }
}

///|
fn positive_decimal_bytes(value : Int64) -> Bytes {
  let digits : Array[Byte] = []
  let mut current = value
  if current == 0L {
    digits.push(b'0')
  } else {
    while current > 0L {
      let digit = (current % 10L).to_int()
      digits.push((b'0'.to_int() + digit).to_byte())
      current = current / 10L
    }
  }

  let out : Array[Byte] = []
  let mut index = digits.length() - 1
  while index >= 0 {
    out.push(digits[index])
    index = index - 1
  }
  Bytes::from_array(out)
}

///|
fn text_bytes(text : String) -> Bytes {
  @utf8.encode(text.to_string_view())
}
