///|
/// Appends new or modified indirect objects to an existing PDF as an
/// incremental update, preserving the original bytes and writing a new xref
/// table and trailer whose /Prev points to the previous xref section.
pub fn append_incremental_update(
  original : Bytes,
  objects : Array[@objects.IndirectObject],
) -> Bytes raise @reader.PdfReaderError {
  let file = @reader.PdfFile::open(original)
  let trailer = file.trailer()
  let header_base = find_header_base(original)
  let previous_xref = find_latest_startxref(original)
  let prefix = original + b"\r\n"
  let (body, xref_entries) = serialize_object_body(prefix, header_base, objects)
  let xref_offset = body.length().to_int64() - header_base
  let writer_trailer = PdfTrailerSpec::new(
    max_int(trailer.size, max_object_number(objects) + 1),
    trailer.root,
    Some(previous_xref),
    writer_file_id(trailer.id),
  )
  body +
  serialize_xref_section(xref_entries, writer_trailer) +
  b"startxref\r\n" +
  decimal_bytes(xref_offset) +
  b"\r\n%%EOF\r\n"
}

///|
fn writer_file_id(id : @reader.PdfFileId?) -> PdfWriterFileId? {
  match id {
    Some(value) =>
      Some(PdfWriterFileId::{ first: value.first, second: value.second })
    None =>
      Some(PdfWriterFileId::{
        first: b"moonbit-pdf-writer-incremental",
        second: b"moonbit-pdf-writer-incremental",
      })
  }
}

///|
fn find_latest_startxref(bytes : Bytes) -> Int64 raise @reader.PdfReaderError {
  match bytes.rev_find(b"startxref") {
    Some(index) => parse_startxref_value(bytes, index + b"startxref".length())
    None =>
      raise @reader.PdfReaderError::MissingTailMarker(
        "startxref keyword not found",
      )
  }
}

///|
fn parse_startxref_value(
  bytes : Bytes,
  start : Int,
) -> Int64 raise @reader.PdfReaderError {
  let mut index = skip_pdf_whitespace(bytes, start)
  let value_start = index
  let mut value = 0L
  while index < bytes.length() && bytes[index] >= b'0' && bytes[index] <= b'9' {
    value = value * 10L + (bytes[index].to_int64() - b'0'.to_int64())
    index += 1
  }
  if index == value_start {
    raise @reader.PdfReaderError::InvalidXref(
      start.to_int64(),
      "startxref must be followed by a decimal offset",
    )
  }
  value
}

///|
fn find_header_base(bytes : Bytes) -> Int64 {
  match bytes.find(b"%PDF-") {
    Some(index) => index.to_int64()
    None => 0L
  }
}

///|
fn skip_pdf_whitespace(bytes : Bytes, start : Int) -> Int {
  let mut index = start
  while index < bytes.length() && is_pdf_whitespace(bytes[index]) {
    index += 1
  }
  index
}

///|
fn is_pdf_whitespace(byte : Byte) -> Bool {
  byte == b'\x00' ||
  byte == b'\t' ||
  byte == b'\n' ||
  byte == b'\x0c' ||
  byte == b'\r' ||
  byte == b' '
}

///|
fn max_int(left : Int, right : Int) -> Int {
  if left > right {
    left
  } else {
    right
  }
}
