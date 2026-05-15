///|
/// Parsed inline image instruction data per ISO 32000-2 §8.9.7 from a `BI`
/// dictionary, `ID` image data marker, and `EI` end marker. The instruction
/// contains the image dictionary and raw byte data. The dictionary stores
/// expanded abbreviated key names: `W` for `Width`, `H` for `Height`, `BPC`
/// for `BitsPerComponent`, `CS` for `ColorSpace`, and related inline image
/// abbreviations, while `data` preserves the exact raw image bytes between
/// `ID` and `EI`.
pub(all) struct PdfInlineImage {
  dictionary : @objects.PdfDictionary
  data : Bytes
  start_offset : Int64
  data_offset : Int64
  end_offset : Int64
} derive(Eq, Debug)

///|
/// Reads inline image dictionaries and raw image data without tokenizing image
/// bytes after the `ID` operator. It collects key-value pairs until `ID`,
/// consumes the single white-space byte before image data, and scans for `EI`.
pub(all) struct InlineImageReader {
  reader : ContentOperandReader
}

///|
/// Creates an inline image reader over bytes positioned after the `BI` begin
/// marker. The reader collects key-value pairs until `ID` and scans raw bytes
/// until a valid `EI` marker.
pub fn InlineImageReader::new(input : Bytes) -> InlineImageReader {
  InlineImageReader::{ reader: ContentOperandReader::new(input) }
}

///|
/// Parses one inline image value, expanding abbreviated image dictionary keys
/// before returning the dictionary, raw data bytes, and start/data/end offsets.
/// This handles inline image data introduced by `BI`, `ID`, and `EI` as a
/// special case for content stream tokenization.
pub fn InlineImageReader::parse(
  self : InlineImageReader,
  start_offset : Int64,
) -> PdfInlineImage raise PdfContentError {
  let dictionary = self.read_dictionary_until_id()
  let data_offset = self.consume_required_data_space()
  let (data, end_offset) = self.read_data_until_ei()
  PdfInlineImage::{ dictionary, data, start_offset, data_offset, end_offset }
}

///|
fn InlineImageReader::read_dictionary_until_id(
  self : InlineImageReader,
) -> @objects.PdfDictionary raise PdfContentError {
  let dictionary : @objects.PdfDictionary = Map::new()
  while true {
    match self.reader.read_next() {
      OperatorCandidate(keyword, _) if keyword == b"ID" => break
      OperatorCandidate(keyword, offset) =>
        raise InlineImageFailure(
          offset,
          "expected inline image dictionary key or ID but found " +
          @lexer.bytes_to_text(keyword),
        )
      Operand(Name(key)) => {
        let value = self.reader.read_direct_operand()
        dictionary[expand_inline_image_key(key)] = expand_inline_image_value(
          value,
        )
      }
      Operand(_) =>
        raise InlineImageFailure(
          self.reader.cursor.offset(),
          "inline image dictionary key must be a name before ID",
        )
      EndOfInput(offset) =>
        raise InlineImageFailure(offset, "missing ID inline image data marker")
    }
  }
  dictionary
}

///|
fn InlineImageReader::consume_required_data_space(
  self : InlineImageReader,
) -> Int64 raise PdfContentError {
  let offset = self.reader.cursor.offset()
  match self.reader.cursor.peek() {
    Some(byte) if @lexer.is_white_space(byte) => {
      if self.reader.cursor.read_eol() {
        ()
      } else {
        self.read_raw_byte() |> ignore
      }
      self.reader.cursor.offset()
    }
    Some(_) =>
      raise InlineImageFailure(
        offset, "ID inline image data marker must be followed by one white-space byte",
      )
    None =>
      raise InlineImageFailure(
        offset, "missing inline image data after ID marker",
      )
  }
}

///|
fn InlineImageReader::read_data_until_ei(
  self : InlineImageReader,
) -> (Bytes, Int64) raise PdfContentError {
  let output : Array[Byte] = []
  while true {
    let offset = self.reader.cursor.offset()
    match self.reader.cursor.peek() {
      None => raise InlineImageFailure(offset, "missing EI inline image marker")
      Some(byte) if @lexer.is_white_space(byte) =>
        match self.inline_image_end_delta_after_space() {
          Some(delta) => {
            self.consume_inline_image_end_marker(delta)
            return (Bytes::from_array(output), offset + delta.to_int64())
          }
          None => {
            self.read_raw_byte() |> ignore
            output.push(byte)
          }
        }
      Some(byte) => {
        self.read_raw_byte() |> ignore
        output.push(byte)
      }
    }
  } nobreak {
    raise InlineImageFailure(
      self.reader.cursor.offset(),
      "missing EI inline image marker",
    )
  }
}

///|
fn InlineImageReader::inline_image_end_delta_after_space(
  self : InlineImageReader,
) -> Int? {
  let delta = if self.reader.cursor.peek() == Some(b'\r') &&
    self.reader.cursor.peek_n(1) == Some(b'\n') {
    2
  } else {
    1
  }
  if self.reader.cursor.peek_n(delta) == Some(b'E') &&
    self.reader.cursor.peek_n(delta + 1) == Some(b'I') &&
    self.is_valid_inline_image_end_follow(delta + 2) {
    Some(delta)
  } else {
    None
  }
}

///|
fn InlineImageReader::is_valid_inline_image_end_follow(
  self : InlineImageReader,
  index : Int,
) -> Bool {
  match self.reader.cursor.peek_n(index) {
    None => true
    Some(byte) => @lexer.is_white_space(byte) || @lexer.is_delimiter(byte)
  }
}

///|
fn InlineImageReader::consume_inline_image_end_marker(
  self : InlineImageReader,
  delta : Int,
) -> Unit raise PdfContentError {
  if delta == 2 {
    self.reader.cursor.read_eol() |> ignore
  } else {
    self.read_raw_byte() |> ignore
  }
  self.read_raw_byte() |> ignore
  self.read_raw_byte() |> ignore
}

///|
fn InlineImageReader::read_raw_byte(
  self : InlineImageReader,
) -> Byte? raise PdfContentError {
  try self.reader.cursor.read_byte() catch {
    error => raise wrap_parse_error(error)
  } noraise {
    byte => byte
  }
}

///|
fn expand_inline_image_key(key : @objects.PdfName) -> @objects.PdfName {
  if key == @objects.PdfName::new(b"W") {
    @objects.PdfName::new(b"Width")
  } else if key == @objects.PdfName::new(b"H") {
    @objects.PdfName::new(b"Height")
  } else if key == @objects.PdfName::new(b"BPC") {
    @objects.PdfName::new(b"BitsPerComponent")
  } else if key == @objects.PdfName::new(b"CS") {
    @objects.PdfName::new(b"ColorSpace")
  } else if key == @objects.PdfName::new(b"IM") {
    @objects.PdfName::new(b"ImageMask")
  } else if key == @objects.PdfName::new(b"I") {
    @objects.PdfName::new(b"Interpolate")
  } else if key == @objects.PdfName::new(b"D") {
    @objects.PdfName::new(b"Decode")
  } else if key == @objects.PdfName::new(b"DP") {
    @objects.PdfName::new(b"DecodeParms")
  } else if key == @objects.PdfName::new(b"F") {
    @objects.PdfName::new(b"Filter")
  } else if key == @objects.PdfName::new(b"L") {
    @objects.PdfName::new(b"Length")
  } else {
    key
  }
}

///|
fn expand_inline_image_value(value : @objects.PdfObject) -> @objects.PdfObject {
  match value {
    Name(name) => Name(expand_inline_image_name_value(name))
    Array(values) => {
      let expanded : Array[@objects.PdfObject] = []
      for item in values {
        expanded.push(expand_inline_image_value(item))
      }
      Array(expanded)
    }
    _ => value
  }
}

///|
fn expand_inline_image_name_value(name : @objects.PdfName) -> @objects.PdfName {
  if name == @objects.PdfName::new(b"G") {
    @objects.PdfName::new(b"DeviceGray")
  } else if name == @objects.PdfName::new(b"RGB") {
    @objects.PdfName::new(b"DeviceRGB")
  } else if name == @objects.PdfName::new(b"CMYK") {
    @objects.PdfName::new(b"DeviceCMYK")
  } else if name == @objects.PdfName::new(b"I") {
    @objects.PdfName::new(b"Indexed")
  } else if name == @objects.PdfName::new(b"AHx") {
    @objects.PdfName::new(b"ASCIIHexDecode")
  } else if name == @objects.PdfName::new(b"A85") {
    @objects.PdfName::new(b"ASCII85Decode")
  } else if name == @objects.PdfName::new(b"LZW") {
    @objects.PdfName::new(b"LZWDecode")
  } else if name == @objects.PdfName::new(b"Fl") {
    @objects.PdfName::new(b"FlateDecode")
  } else if name == @objects.PdfName::new(b"RL") {
    @objects.PdfName::new(b"RunLengthDecode")
  } else if name == @objects.PdfName::new(b"CCF") {
    @objects.PdfName::new(b"CCITTFaxDecode")
  } else if name == @objects.PdfName::new(b"DCT") {
    @objects.PdfName::new(b"DCTDecode")
  } else {
    name
  }
}
