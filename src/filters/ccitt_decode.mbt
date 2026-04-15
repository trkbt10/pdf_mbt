///|
let ccitt_filter_name = "CCITTFaxDecode"

///|
let ccitt_eol_bits = 12

///|
let ccitt_eofb_bits = 24

///|
/// CCITTFaxDecode output format for decoded bilevel image samples. The
/// decoded output is 1 bit per pixel, packed 8 pixels per byte, MSB first,
/// with rows padded to byte boundaries; this is the PDF image sample format
/// for 1-BPC images.
priv struct CcittPackedOutputFormat {
  bits_per_pixel : Int
  pixels_per_byte : Int
  msb_first : Bool
  row_bytes : Int
}

///|
fn CcittPackedOutputFormat::from_columns(
  columns : Int,
) -> CcittPackedOutputFormat raise PdfFilterError {
  if columns <= 0 {
    raise PdfFilterError::InvalidDecodeParms(
      ccitt_filter_name, "Columns must be positive for packed output",
    )
  }
  CcittPackedOutputFormat::{
    bits_per_pixel: 1,
    pixels_per_byte: 8,
    msb_first: true,
    row_bytes: (columns + 7) / 8,
  }
}

///|
fn CcittPackedOutputFormat::from_params(
  config : CcittParams,
) -> CcittPackedOutputFormat raise PdfFilterError {
  let row_bytes = config.packed_row_bytes()
  CcittPackedOutputFormat::{
    bits_per_pixel: 1,
    pixels_per_byte: 8,
    msb_first: true,
    row_bytes,
  }
}

///|
fn CcittPackedOutputFormat::validate_row_boundary(
  self : CcittPackedOutputFormat,
  output_length : Int,
) -> Unit raise PdfFilterError {
  if self.bits_per_pixel != 1 || self.pixels_per_byte != 8 || !self.msb_first {
    raise PdfFilterError::DecodeError(
      ccitt_filter_name, "invalid CCITT 1-BPC packed output format",
    )
  }
  if output_length % self.row_bytes != 0 {
    raise PdfFilterError::DecodeError(
      ccitt_filter_name, "packed CCITT row did not end on byte boundary",
    )
  }
}

///|
/// CCITTFaxDecode DecodeParms normalized for Group 3 one-dimensional,
/// mixed Group 3 two-dimensional, and Group 4 decoding. The same parameters
/// control the final output format: 1 bit per pixel, MSB first, with rows
/// padded to byte boundaries.
priv struct CcittParams {
  k : Int
  columns : Int
  rows : Int
  black_is_1 : Bool
  encoded_byte_align : Bool
  end_of_line : Bool
  end_of_block : Bool
}

///|
/// Group 4 two-dimensional mode code decoded from the CCITT bit stream.
/// Pass, Horizontal, and Vertical modes update the changing-element position
/// against the previous reference line.
priv enum CcittMode {
  Pass
  Horizontal
  Vertical(Int)
}

///|
/// Bit reader for CCITT Group 3 and Group 4 Huffman streams. CCITT codes are
/// consumed MSB first, while EncodedByteAlign can advance to the next byte
/// boundary between encoded rows.
priv struct CcittBitReader {
  data : Bytes
  mut bit_position : Int
}

///|
fn decode_ccitt_fax(
  data : Bytes,
  params : DecodeParams,
) -> Bytes raise PdfFilterError {
  let config = read_ccitt_params(params)
  let reader = CcittBitReader::new(data)
  let rows = if config.is_group4() {
    decode_ccitt_group4(reader, config)
  } else if config.is_group3_1d() {
    decode_ccitt_group3_1d(reader, config)
  } else {
    decode_ccitt_mixed(reader, config)
  }
  pack_ccitt_rows(rows, config)
}

///|
fn read_ccitt_params(params : DecodeParams) -> CcittParams raise PdfFilterError {
  let raw = params.raw
  let k = read_integer_parameter(ccitt_filter_name, raw, "K", 0)
  let columns = read_positive_parameter(ccitt_filter_name, raw, "Columns", 1728)
  let rows = read_integer_parameter(ccitt_filter_name, raw, "Rows", 0)
  if rows < 0 {
    raise PdfFilterError::InvalidDecodeParms(
      ccitt_filter_name, "Rows must be zero or a positive integer",
    )
  }
  CcittParams::{
    k,
    columns,
    rows,
    black_is_1: read_boolean_parameter(
      ccitt_filter_name, raw, "BlackIs1", false,
    ),
    encoded_byte_align: read_boolean_parameter(
      ccitt_filter_name, raw, "EncodedByteAlign", false,
    ),
    end_of_line: read_boolean_parameter(
      ccitt_filter_name, raw, "EndOfLine", false,
    ),
    end_of_block: read_boolean_parameter(
      ccitt_filter_name, raw, "EndOfBlock", true,
    ),
  }
}

///|
fn CcittParams::is_group4(self : CcittParams) -> Bool {
  self.k < 0
}

///|
fn CcittParams::is_group3_1d(self : CcittParams) -> Bool {
  self.k == 0
}

///|
fn CcittParams::packed_row_bytes(
  self : CcittParams,
) -> Int raise PdfFilterError {
  CcittPackedOutputFormat::from_columns(self.columns).row_bytes
}

///|
fn read_boolean_parameter(
  filter_name : String,
  raw : @objects.PdfDictionary?,
  key : String,
  default : Bool,
) -> Bool raise PdfFilterError {
  match raw {
    None => default
    Some(dict) => {
      let name = @objects.PdfName::new(@utf8.encode(key))
      match dict.get(name) {
        None => default
        Some(@objects.PdfObject::Boolean(value)) => value
        Some(@objects.PdfObject::Ref(_)) =>
          raise PdfFilterError::InvalidDecodeParms(
            filter_name,
            key + " must be a direct boolean",
          )
        Some(_) =>
          raise PdfFilterError::InvalidDecodeParms(
            filter_name,
            key + " must be a boolean",
          )
      }
    }
  }
}

///|
fn CcittBitReader::new(data : Bytes) -> CcittBitReader {
  CcittBitReader::{ data, bit_position: 0 }
}

///|
fn CcittBitReader::remaining_bits(self : CcittBitReader) -> Int {
  self.data.length() * 8 - self.bit_position
}

///|
fn CcittBitReader::read_bit(self : CcittBitReader) -> Int? {
  if self.bit_position >= self.data.length() * 8 {
    None
  } else {
    let byte_index = self.bit_position / 8
    let shift = 7 - self.bit_position % 8
    let bit = (self.data[byte_index].to_int() >> shift) & 1
    self.bit_position += 1
    Some(bit)
  }
}

///|
fn CcittBitReader::peek_bits(self : CcittBitReader, bit_count : Int) -> Int? {
  if bit_count < 0 || self.bit_position + bit_count > self.data.length() * 8 {
    None
  } else {
    let mut value = 0
    let mut offset = 0
    while offset < bit_count {
      let bit_position = self.bit_position + offset
      let byte_index = bit_position / 8
      let shift = 7 - bit_position % 8
      value = (value << 1) | ((self.data[byte_index].to_int() >> shift) & 1)
      offset += 1
    }
    Some(value)
  }
}

///|
fn CcittBitReader::consume_bits(
  self : CcittBitReader,
  bit_count : Int,
) -> Unit raise PdfFilterError {
  if bit_count < 0 || self.remaining_bits() < bit_count {
    raise PdfFilterError::DecodeError(ccitt_filter_name, "truncated bit stream")
  }
  self.bit_position += bit_count
}

///|
fn CcittBitReader::align_to_byte(self : CcittBitReader) -> Unit {
  let extra = self.bit_position % 8
  if extra != 0 {
    self.bit_position += 8 - extra
  }
}

///|
fn CcittBitReader::has_eofb(self : CcittBitReader) -> Bool {
  self.peek_bits(ccitt_eofb_bits) == Some(0x1001)
}

///|
fn CcittBitReader::consume_eofb(
  self : CcittBitReader,
) -> Unit raise PdfFilterError {
  self.consume_bits(ccitt_eofb_bits)
}

///|
fn CcittBitReader::consume_eol(
  self : CcittBitReader,
  required : Bool,
) -> Bool raise PdfFilterError {
  let start = self.bit_position
  let mut zero_count = 0
  while true {
    match self.read_bit() {
      Some(0) => zero_count += 1
      Some(1) =>
        if zero_count >= ccitt_eol_bits - 1 {
          return true
        } else {
          self.bit_position = start
          if required {
            raise PdfFilterError::DecodeError(
              ccitt_filter_name, "missing CCITT end-of-line marker",
            )
          }
          return false
        }
      Some(_) => {
        self.bit_position = start
        if required {
          raise PdfFilterError::DecodeError(
            ccitt_filter_name, "invalid CCITT end-of-line marker",
          )
        }
        return false
      }
      None => {
        self.bit_position = start
        if required {
          raise PdfFilterError::DecodeError(
            ccitt_filter_name, "truncated CCITT end-of-line marker",
          )
        }
        return false
      }
    }
  }
  false
}

///|
fn CcittBitReader::has_rtc(self : CcittBitReader) -> Bool raise PdfFilterError {
  let start = self.bit_position
  let mut count = 0
  while count < 6 {
    if !self.consume_eol(false) {
      self.bit_position = start
      return false
    }
    count += 1
  }
  self.bit_position = start
  true
}

///|
fn decode_ccitt_group3_1d(
  reader : CcittBitReader,
  config : CcittParams,
) -> Array[Array[Bool]] raise PdfFilterError {
  let rows : Array[Array[Bool]] = []
  while should_decode_ccitt_row(reader, config, rows.length()) {
    if config.end_of_block && config.rows == 0 && reader.has_rtc() {
      break
    }
    if config.end_of_line {
      reader.consume_eol(true) |> ignore
    }
    rows.push(decode_ccitt_1d_line(reader, config.columns))
    if config.encoded_byte_align {
      reader.align_to_byte()
    }
  }
  rows
}

///|
fn decode_ccitt_group4(
  reader : CcittBitReader,
  config : CcittParams,
) -> Array[Array[Bool]] raise PdfFilterError {
  let rows : Array[Array[Bool]] = []
  let mut reference = Array::make(config.columns, false)
  while should_decode_ccitt_row(reader, config, rows.length()) {
    if config.end_of_block && reader.has_eofb() {
      reader.consume_eofb()
      break
    }
    let row = decode_ccitt_2d_line(reader, reference, config.columns)
    rows.push(row)
    reference = row
  }
  rows
}

///|
fn decode_ccitt_mixed(
  reader : CcittBitReader,
  config : CcittParams,
) -> Array[Array[Bool]] raise PdfFilterError {
  let rows : Array[Array[Bool]] = []
  let mut reference = Array::make(config.columns, false)
  while should_decode_ccitt_row(reader, config, rows.length()) {
    if config.end_of_block && config.rows == 0 && reader.has_rtc() {
      break
    }
    let one_dimensional = if config.end_of_line {
      reader.consume_eol(true) |> ignore
      match reader.read_bit() {
        Some(1) => true
        Some(0) => false
        Some(_) =>
          raise PdfFilterError::DecodeError(
            ccitt_filter_name, "invalid Group 3 line type tag",
          )
        None =>
          raise PdfFilterError::DecodeError(
            ccitt_filter_name, "truncated Group 3 line type tag",
          )
      }
    } else {
      rows.length() % config.k == 0
    }
    let row = if one_dimensional {
      decode_ccitt_1d_line(reader, config.columns)
    } else {
      decode_ccitt_2d_line(reader, reference, config.columns)
    }
    rows.push(row)
    reference = row
    if config.encoded_byte_align {
      reader.align_to_byte()
    }
  }
  rows
}

///|
fn should_decode_ccitt_row(
  reader : CcittBitReader,
  config : CcittParams,
  decoded_rows : Int,
) -> Bool {
  if config.rows > 0 {
    decoded_rows < config.rows
  } else {
    reader.remaining_bits() > 0
  }
}

///|
fn decode_ccitt_1d_line(
  reader : CcittBitReader,
  columns : Int,
) -> Array[Bool] raise PdfFilterError {
  let row : Array[Bool] = []
  let mut black = false
  while row.length() < columns {
    let run = decode_ccitt_run(reader, black)
    append_ccitt_run(row, black, run, columns)
    black = !black
  }
  row
}

///|
fn decode_ccitt_2d_line(
  reader : CcittBitReader,
  reference : Array[Bool],
  columns : Int,
) -> Array[Bool] raise PdfFilterError {
  let row : Array[Bool] = []
  let mut a0 = -1
  let mut black = false
  while row.length() < columns {
    match decode_ccitt_mode(reader) {
      Pass => {
        let b1 = ccitt_next_change(reference, a0, black, columns)
        let b2 = ccitt_next_change(reference, b1, !black, columns)
        append_ccitt_to_position(row, black, b2, columns)
        a0 = b2
      }
      Horizontal => {
        let first = decode_ccitt_run(reader, black)
        append_ccitt_run(row, black, first, columns)
        let second = decode_ccitt_run(reader, !black)
        append_ccitt_run(row, !black, second, columns)
        a0 = row.length() - 1
      }
      Vertical(offset) => {
        let b1 = ccitt_next_change(reference, a0, black, columns)
        let a1 = b1 + offset
        append_ccitt_to_position(row, black, a1, columns)
        a0 = a1
        black = !black
      }
    }
  }
  row
}

///|
fn decode_ccitt_mode(reader : CcittBitReader) -> CcittMode raise PdfFilterError {
  let mut code = 0
  let mut bits_read = 1
  while bits_read <= 7 {
    match reader.read_bit() {
      Some(bit) => code = (code << 1) | bit
      None =>
        raise PdfFilterError::DecodeError(
          ccitt_filter_name, "truncated Group 4 mode code",
        )
    }
    match (bits_read, code) {
      (1, 1) => return Vertical(0)
      (3, 0b011) => return Vertical(1)
      (3, 0b010) => return Vertical(-1)
      (3, 0b001) => return Horizontal
      (4, 0b0001) => return Pass
      (6, 0b000011) => return Vertical(2)
      (6, 0b000010) => return Vertical(-2)
      (7, 0b0000011) => return Vertical(3)
      (7, 0b0000010) => return Vertical(-3)
      (7, 0b0000001) =>
        raise PdfFilterError::DecodeError(
          ccitt_filter_name, "Group 4 extension mode is not supported",
        )
      _ => ()
    }
    bits_read += 1
  }
  raise PdfFilterError::DecodeError(
    ccitt_filter_name, "invalid Group 4 mode code",
  )
}

///|
fn decode_ccitt_run(
  reader : CcittBitReader,
  black : Bool,
) -> Int raise PdfFilterError {
  let mut total = 0
  let mut done = false
  while !done {
    let code = decode_ccitt_run_code(reader, black)
    total += code.run
    if code.run < 64 {
      done = true
    }
  }
  total
}

///|
fn decode_ccitt_run_code(
  reader : CcittBitReader,
  black : Bool,
) -> CcittCode raise PdfFilterError {
  let table = if black { ccitt_black_codes } else { ccitt_white_codes }
  let mut code = 0
  let mut bits_read = 1
  while bits_read <= 13 {
    match reader.read_bit() {
      Some(bit) => code = (code << 1) | bit
      None =>
        raise PdfFilterError::DecodeError(
          ccitt_filter_name, "truncated CCITT Huffman code",
        )
    }
    match lookup_ccitt_huffman_code(table, code, bits_read) {
      Some(entry) => return entry
      None => ()
    }
    bits_read += 1
  }
  raise PdfFilterError::DecodeError(
    ccitt_filter_name, "invalid CCITT Huffman code",
  )
}

///|
fn ccitt_next_change(
  line : Array[Bool],
  start : Int,
  color : Bool,
  columns : Int,
) -> Int {
  let mut index = start + 1
  while index < columns && line[index] == color {
    index += 1
  }
  index
}

///|
fn append_ccitt_to_position(
  row : Array[Bool],
  black : Bool,
  position : Int,
  columns : Int,
) -> Unit raise PdfFilterError {
  if position < row.length() || position > columns {
    raise PdfFilterError::DecodeError(
      ccitt_filter_name, "CCITT run crosses the row boundary",
    )
  }
  while row.length() < position {
    row.push(black)
  }
}

///|
fn append_ccitt_run(
  row : Array[Bool],
  black : Bool,
  run : Int,
  columns : Int,
) -> Unit raise PdfFilterError {
  append_ccitt_to_position(row, black, row.length() + run, columns)
}

///|
/// Packs decoded CCITTFaxDecode image rows as 1 bit per pixel, eight pixels
/// per byte, MSB first, with rows padded to byte boundaries. BlackIs1 controls
/// whether black pixels are written as 1-bits.
fn pack_ccitt_rows(
  rows : Array[Array[Bool]],
  config : CcittParams,
) -> Bytes raise PdfFilterError {
  let output_format = CcittPackedOutputFormat::from_params(config)
  let output : Array[Byte] = []
  for row in rows {
    if row.length() != config.columns {
      raise PdfFilterError::DecodeError(
        ccitt_filter_name, "decoded row length does not match Columns",
      )
    }
    let mut current_byte = 0
    let mut bits_filled = 0
    for black in row {
      let bit = if black {
        if config.black_is_1 {
          1
        } else {
          0
        }
      } else if config.black_is_1 {
        0
      } else {
        1
      }
      current_byte = (current_byte << 1) | bit
      bits_filled += 1
      if bits_filled == 8 {
        output.push(current_byte.to_byte())
        current_byte = 0
        bits_filled = 0
      }
    }
    if bits_filled > 0 {
      output.push((current_byte << (8 - bits_filled)).to_byte())
    }
    output_format.validate_row_boundary(output.length())
  }
  Bytes::from_array(output)
}
