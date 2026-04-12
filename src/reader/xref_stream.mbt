///|
priv struct XrefStreamWidths {
  type_width : Int
  field2_width : Int
  field3_width : Int
} derive(Eq, Debug)

///|
priv struct XrefStreamIndexRange {
  first_object_number : Int
  entry_count : Int
} derive(Eq, Debug)

///|
fn parse_xref_stream_section(
  source : ByteSource,
  pdf_offset : Int64,
  version : PdfVersion,
) -> XrefSection raise PdfReaderError {
  let bytes = source.slice_from_pdf_offset(pdf_offset)
  let indirect_result : Result[@objects.IndirectObject, @objects.PdfParseError] = try? @parser.parse_indirect_object(
    bytes,
  )
  let indirect = match indirect_result {
    Ok(value) => value
    Err(error) => raise PdfReaderError::ParseObjectError(pdf_offset, error)
  }

  let stream = match indirect.value {
    @objects.PdfObject::Stream(stream) => stream
    _ =>
      raise PdfReaderError::InvalidXref(
        pdf_offset, "xref stream section must be a stream object",
      )
  }

  require_xref_stream_type(stream.dict, pdf_offset)
  let decoded = decode_structural_stream(stream, XrefStream, offset=pdf_offset)
  let trailer = parse_trailer_info(stream.dict, version, offset=pdf_offset)
  let widths = read_xref_stream_widths(stream.dict, pdf_offset)
  let index_ranges = read_xref_stream_index_ranges(
    stream.dict,
    trailer.size,
    pdf_offset,
  )
  let entries = parse_xref_stream_entries(
    decoded, widths, index_ranges, pdf_offset,
  )
  XrefSection::{
    provenance: XrefSectionProvenance::{
      source: XrefSectionSource::Stream,
      pdf_offset,
    },
    entries,
    trailer,
  }
}

///|
fn require_xref_stream_type(
  dict : @objects.PdfDictionary,
  offset : Int64,
) -> Unit raise PdfReaderError {
  let key = @objects.PdfName::new(b"Type")
  let expected = @objects.PdfName::new(b"XRef")
  match dict.get(key) {
    Some(@objects.PdfObject::Name(name)) if name == expected => ()
    Some(_) =>
      raise PdfReaderError::InvalidXref(
        offset, "xref stream must have /Type /XRef",
      )
    None =>
      raise PdfReaderError::InvalidXref(
        offset, "xref stream must have /Type /XRef",
      )
  }
}

///|
fn read_xref_stream_widths(
  dict : @objects.PdfDictionary,
  offset : Int64,
) -> XrefStreamWidths raise PdfReaderError {
  let key = @objects.PdfName::new(b"W")
  match dict.get(key) {
    Some(@objects.PdfObject::Array(values)) =>
      parse_xref_stream_widths(values, offset)
    Some(_) =>
      raise PdfReaderError::InvalidXref(
        offset, "xref stream W entry must be an array of three integers",
      )
    None =>
      raise PdfReaderError::InvalidXref(offset, "missing xref stream W entry")
  }
}

///|
fn parse_xref_stream_widths(
  values : Array[@objects.PdfObject],
  offset : Int64,
) -> XrefStreamWidths raise PdfReaderError {
  if values.length() != 3 {
    raise PdfReaderError::InvalidXref(
      offset, "xref stream W entry must be an array of three integers",
    )
  }

  let widths = XrefStreamWidths::{
    type_width: read_xref_stream_width_value(
      values[0],
      offset,
      "xref stream W[0]",
    ),
    field2_width: read_xref_stream_width_value(
      values[1],
      offset,
      "xref stream W[1]",
    ),
    field3_width: read_xref_stream_width_value(
      values[2],
      offset,
      "xref stream W[2]",
    ),
  }

  if widths.field2_width == 0 {
    raise PdfReaderError::InvalidXref(
      offset, "xref stream W[1] must not be zero",
    )
  }

  widths
}

///|
fn read_xref_stream_width_value(
  value : @objects.PdfObject,
  offset : Int64,
  context : String,
) -> Int raise PdfReaderError {
  match value {
    @objects.PdfObject::Integer(width) => {
      if width < 0L {
        raise PdfReaderError::InvalidXref(
          offset,
          "\{context} must be a non-negative integer",
        )
      }
      if width > 2147483647L {
        raise PdfReaderError::InvalidXref(
          offset,
          "\{context} is too large for Int",
        )
      }
      width.to_int()
    }
    _ =>
      raise PdfReaderError::InvalidXref(
        offset,
        "\{context} must be a non-negative integer",
      )
  }
}

///|
fn read_xref_stream_index_ranges(
  dict : @objects.PdfDictionary,
  size : Int,
  offset : Int64,
) -> Array[XrefStreamIndexRange] raise PdfReaderError {
  let key = @objects.PdfName::new(b"Index")
  match dict.get(key) {
    Some(@objects.PdfObject::Array(values)) =>
      parse_xref_stream_index_ranges(values, size, offset)
    Some(_) =>
      raise PdfReaderError::InvalidXref(
        offset, "xref stream Index entry must be an array of integers",
      )
    None =>
      [XrefStreamIndexRange::{ first_object_number: 0, entry_count: size }]
  }
}

///|
fn parse_xref_stream_index_ranges(
  values : Array[@objects.PdfObject],
  size : Int,
  offset : Int64,
) -> Array[XrefStreamIndexRange] raise PdfReaderError {
  if values.length() == 0 {
    return []
  }
  if values.length() % 2 != 0 {
    raise PdfReaderError::InvalidXref(
      offset, "xref stream Index entry must contain integer pairs",
    )
  }

  let ranges : Array[XrefStreamIndexRange] = []
  let mut index = 0
  let mut previous_end = 0L
  while index < values.length() {
    let first_object_number = read_xref_stream_index_value(
      values[index],
      offset,
      "xref stream Index entry first object number",
    )
    let entry_count = read_xref_stream_index_value(
      values[index + 1],
      offset,
      "xref stream Index entry count",
    )
    require_xref_stream_index_range(
      first_object_number, entry_count, size, previous_end, offset,
    )
    ranges.push(XrefStreamIndexRange::{ first_object_number, entry_count })
    previous_end = first_object_number.to_int64() + entry_count.to_int64()
    index = index + 2
  }

  ranges
}

///|
fn read_xref_stream_index_value(
  value : @objects.PdfObject,
  offset : Int64,
  context : String,
) -> Int raise PdfReaderError {
  match value {
    @objects.PdfObject::Integer(number) => {
      if number < 0L {
        raise PdfReaderError::InvalidXref(
          offset,
          "\{context} must be a non-negative integer",
        )
      }
      if number > 2147483647L {
        raise PdfReaderError::InvalidXref(
          offset,
          "\{context} is too large for Int",
        )
      }
      number.to_int()
    }
    _ =>
      raise PdfReaderError::InvalidXref(
        offset,
        "\{context} must be a non-negative integer",
      )
  }
}

///|
fn require_xref_stream_index_range(
  first_object_number : Int,
  entry_count : Int,
  size : Int,
  previous_end : Int64,
  offset : Int64,
) -> Unit raise PdfReaderError {
  let first_object_number64 = first_object_number.to_int64()
  let entry_count64 = entry_count.to_int64()
  if first_object_number64 < previous_end {
    raise PdfReaderError::InvalidXref(
      offset, "xref stream Index ranges must be sorted in ascending order and non-overlapping",
    )
  }

  let last_object_number = first_object_number64 + entry_count64
  if last_object_number > size.to_int64() {
    raise PdfReaderError::InvalidXref(
      offset, "xref stream Index entry exceeds trailer Size",
    )
  }

  if last_object_number > 2147483647L {
    raise PdfReaderError::InvalidXref(
      offset, "xref stream Index entry overflows Int",
    )
  }
}

///|
fn parse_xref_stream_entries(
  bytes : Bytes,
  widths : XrefStreamWidths,
  ranges : Array[XrefStreamIndexRange],
  pdf_offset : Int64,
) -> Array[XrefSectionEntry] raise PdfReaderError {
  let entries : Array[XrefSectionEntry] = []
  let entry_width = require_xref_stream_entry_width(widths, pdf_offset)
  let mut index = 0
  for range in ranges {
    for i in 0..<range.entry_count {
      let object_number = range.first_object_number + i
      let entry_offset = pdf_offset + index.to_int64()
      let next_index = checked_xref_stream_add(
        index, entry_width, entry_offset, "xref stream entry width",
      )
      if next_index > bytes.length() {
        raise PdfReaderError::InvalidXref(
          entry_offset, "unexpected end of xref stream data",
        )
      }
      match
        parse_xref_stream_entry(
          bytes, index, object_number, widths, entry_offset,
        ) {
        Some(entry) => entries.push(entry)
        None => ()
      }
      index = next_index
    }
  }

  if index != bytes.length() {
    raise PdfReaderError::InvalidXref(
      pdf_offset + index.to_int64(),
      "xref stream has trailing bytes",
    )
  }

  entries
}

///|
fn parse_xref_stream_entry(
  bytes : Bytes,
  index : Int,
  object_number : Int,
  widths : XrefStreamWidths,
  offset : Int64,
) -> XrefSectionEntry? raise PdfReaderError {
  let entry_type = if widths.type_width == 0 {
    1L
  } else {
    read_xref_stream_unsigned(
      bytes,
      index,
      widths.type_width,
      offset,
      "xref stream entry type",
    )
  }

  let field2_index = checked_xref_stream_add(
    index,
    widths.type_width,
    offset,
    "xref stream entry field2",
  )
  let field2 = read_xref_stream_unsigned(
    bytes,
    field2_index,
    widths.field2_width,
    offset,
    "xref stream entry field2",
  )
  let field3_index = checked_xref_stream_add(
    field2_index,
    widths.field2_width,
    offset,
    "xref stream entry field3",
  )
  let field3 = read_xref_stream_unsigned(
    bytes,
    field3_index,
    widths.field3_width,
    offset,
    "xref stream entry field3",
  )

  let entry = match entry_type {
    0L =>
      XrefEntry::Free(
        require_xref_stream_int(
          field2, offset, "xref stream free entry next object number",
        ),
        require_xref_stream_int(
          field3, offset, "xref stream free entry generation number",
        ),
      )
    1L =>
      XrefEntry::InUse(
        field2,
        require_xref_stream_int(
          field3, offset, "xref stream in-use entry generation number",
        ),
      )
    2L =>
      XrefEntry::Compressed(
        require_xref_stream_int(
          field2, offset, "xref stream compressed entry object stream number",
        ),
        require_xref_stream_int(
          field3, offset, "xref stream compressed entry object index",
        ),
      )
    _ => return None
  }

  Some(XrefSectionEntry::{ object_number, entry })
}

///|
fn read_xref_stream_unsigned(
  bytes : Bytes,
  index : Int,
  width : Int,
  offset : Int64,
  context : String,
) -> Int64 raise PdfReaderError {
  let mut value = 0L
  let mut current = index
  let end = checked_xref_stream_add(index, width, offset, context)
  while current < end {
    match bytes.get(current) {
      Some(byte) => {
        let digit = byte.to_int64()
        let max_before_digit = (9223372036854775807L - digit) / 256L
        if value > max_before_digit {
          raise PdfReaderError::InvalidXref(offset, "\{context} is too large")
        }
        value = value * 256L + digit
        current = current + 1
      }
      None =>
        raise PdfReaderError::InvalidXref(
          offset, "unexpected end of xref stream data",
        )
    }
  }

  value
}

///|
fn require_xref_stream_entry_width(
  widths : XrefStreamWidths,
  offset : Int64,
) -> Int raise PdfReaderError {
  let total = checked_xref_stream_add(
    widths.type_width,
    widths.field2_width,
    offset,
    "xref stream entry widths",
  )
  checked_xref_stream_add(
    total,
    widths.field3_width,
    offset,
    "xref stream entry widths",
  )
}

///|
fn checked_xref_stream_add(
  left : Int,
  right : Int,
  offset : Int64,
  context : String,
) -> Int raise PdfReaderError {
  let total = left.to_int64() + right.to_int64()
  if total > 2147483647L {
    raise PdfReaderError::InvalidXref(offset, "\{context} overflow Int")
  }
  total.to_int()
}

///|
fn require_xref_stream_int(
  value : Int64,
  offset : Int64,
  context : String,
) -> Int raise PdfReaderError {
  if value > 2147483647L {
    raise PdfReaderError::InvalidXref(offset, "\{context} is too large for Int")
  }
  value.to_int()
}
