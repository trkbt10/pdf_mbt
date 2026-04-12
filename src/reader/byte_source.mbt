///|
/// Owns the raw PDF byte buffer and rebases PDF-relative offsets against the
/// physical position of the `%` byte in `%PDF-`.
pub struct ByteSource {
  bytes : Bytes
  base_offset : Int64
}

///|
/// Creates a byte source over the original input buffer.
pub fn ByteSource::new(input : Bytes, base_offset : Int64) -> ByteSource {
  ByteSource::{ bytes: input, base_offset }
}

///|
/// Converts a PDF-relative offset into a physical byte offset in the owned
/// buffer.
pub fn ByteSource::physical_offset(
  self : ByteSource,
  pdf_offset : Int64,
) -> Int64 raise PdfReaderError {
  if pdf_offset < 0L {
    raise PdfReaderError::InvalidXref(pdf_offset, "offset must be non-negative")
  }
  self.base_offset + pdf_offset
}

///|
/// Returns a raw byte slice from the PDF-relative offset through the end of
/// the buffer.
pub fn ByteSource::slice_from_pdf_offset(
  self : ByteSource,
  pdf_offset : Int64,
) -> Bytes raise PdfReaderError {
  let physical_start = self.physical_offset(pdf_offset)
  let buffer_length = self.buffer_length()
  if physical_start > buffer_length {
    raise PdfReaderError::InvalidXref(
      physical_start, "offset outside input buffer",
    )
  }
  self.slice_range(physical_start, buffer_length - physical_start)
}

///|
/// Returns a raw byte slice from a physical byte offset and explicit length.
pub fn ByteSource::slice_range(
  self : ByteSource,
  physical_start : Int64,
  length : Int64,
) -> Bytes raise PdfReaderError {
  if physical_start < 0L {
    raise PdfReaderError::InvalidXref(
      physical_start, "offset must be non-negative",
    )
  }
  if length < 0L {
    raise PdfReaderError::InvalidXref(
      length, "slice length must be non-negative",
    )
  }
  let buffer_length = self.buffer_length()
  if physical_start > buffer_length {
    raise PdfReaderError::InvalidXref(
      physical_start, "offset outside input buffer",
    )
  }
  let remaining = buffer_length - physical_start
  if length > remaining {
    raise PdfReaderError::InvalidXref(
      physical_start, "slice extends beyond input buffer",
    )
  }
  let end = physical_start + length
  let start = physical_start.to_int()
  let stop = end.to_int()
  self.bytes[start:stop].to_bytes()
}

///|
fn ByteSource::buffer_length(self : ByteSource) -> Int64 {
  self.bytes.length().to_int64()
}
