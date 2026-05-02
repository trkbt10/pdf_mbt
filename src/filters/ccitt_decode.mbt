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
/// against the previous reference line. ExtensionAbort represents the
/// reserved 7-bit code `0000001` (uncompressed-mode and other T.6 extensions
/// such as the alternate run definition); we don't implement the extension
/// payload, but we recognise it so the row decoder can clip the trailing
/// portion of the row to white rather than failing the whole image.
priv enum CcittMode {
  Pass
  Horizontal
  Vertical(Int)
  ExtensionAbort
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
/// Decodes CCITTFaxDecode Group 3 1D Group 4 2D DecodeParms output format
/// 1 bit per pixel MSB first padded at row boundaries.
///
/// PDF and ITU-T T.4/T.6 mandate MSB-first bit ordering inside each input
/// byte, but a long-standing ecosystem quirk surfaces in scan-PDFs produced
/// by EPSON Scan (and a handful of other consumer scanner drivers): the
/// CCITT stream is written with each byte's bits in reverse order
/// (LSB-first), without any DecodeParms entry to declare it. Acrobat,
/// poppler and pdf.js all silently accept the LSB-first variant — they have
/// to, because users would otherwise be left with blank scanned pages. We
/// match that behaviour by attempting an MSB-first decode first; if it
/// fails (either by raising a Huffman/structural error or by producing the
/// wrong row count), we retry with each byte's bits reversed. Successful
/// decodes therefore return the original bit order without overhead, while
/// EPSON-style streams now decode on the second attempt instead of being
/// reported as `InvalidImage`.
pub fn decode_ccitt_fax(
  data : Bytes,
  params : DecodeParams,
) -> Bytes raise PdfFilterError {
  let config = read_ccitt_params(params)
  let primary : Result[Bytes, PdfFilterError] = try? decode_ccitt_with_bytes(
    data, config,
  )
  match primary {
    Ok(decoded) => decoded
    Err(primary_error) => {
      let reversed_data = bit_reversed_bytes(data)
      let fallback : Result[Bytes, PdfFilterError] = try? decode_ccitt_with_bytes(
        reversed_data, config,
      )
      match fallback {
        Ok(decoded) => decoded
        // The MSB-first attempt is the spec-correct path, so if neither
        // bit order can decode we surface the *primary* error — that's the
        // diagnostic users want to chase first.
        Err(_) => raise primary_error
      }
    }
  }
}

///|
fn decode_ccitt_with_bytes(
  data : Bytes,
  config : CcittParams,
) -> Bytes raise PdfFilterError {
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
/// Returns a copy of `data` with each byte's bits reversed (bit 0 swaps with
/// bit 7, bit 1 with bit 6, and so on). Used to retry CCITT decoding when
/// the input was written in LSB-first order.
fn bit_reversed_bytes(data : Bytes) -> Bytes {
  let out : Array[Byte] = []
  for byte in data {
    out.push(reverse_bits_in_byte(byte))
  }
  Bytes::from_array(out)
}

///|
fn reverse_bits_in_byte(byte : Byte) -> Byte {
  let value = byte.to_int()
  let step1 = ((value & 0xF0) >> 4) | ((value & 0x0F) << 4)
  let step2 = ((step1 & 0xCC) >> 2) | ((step1 & 0x33) << 2)
  let step3 = ((step2 & 0xAA) >> 1) | ((step2 & 0x55) << 1)
  (step3 & 0xFF).to_byte()
}

///|
fn read_ccitt_params(params : DecodeParams) -> CcittParams raise PdfFilterError {
  let raw = params.raw
  let k = read_integer_parameter(ccitt_filter_name, raw, "K", 0)
  let columns = params.columns(ccitt_filter_name, 1728)
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
      ExtensionAbort => {
        // T.6 extension code (`0000001`) marks uncompressed mode and other
        // reserved sub-modes. We don't implement the variable-length payload;
        // libtiff and similar decoders treat unimplemented extensions as a
        // signal to clip the rest of the row as white and continue, which
        // typically loses a single corrupt row rather than the whole image.
        append_ccitt_to_position(row, false, columns, columns)
        return row
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
      (7, 0b0000001) => return ExtensionAbort
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
  // `start` is the previous changing element on the coding line; the spec
  // initialises it to a position one column to the left of the first
  // pixel (i.e. `-1`), and our regression-tolerant 2D decoder may leave it
  // further negative still when an upstream code referenced a position
  // before the row origin. Clamp to 0 before indexing so we never trap on
  // `line[-N]`; conceptually we're starting the search at the very first
  // column, which preserves the algorithm's intent (find the first
  // changing element to the right of `start`).
  let mut index = if start + 1 < 0 { 0 } else { start + 1 }
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
) -> Unit {
  // Real-world CCITT scanner output (notably EPSON Scan) routinely emits
  // codes whose target position falls outside the current emission window:
  //   * Overruns past `Columns` happen when the encoder rounded the trailing
  //     run up instead of ending the row at the exact column.
  //   * Regressions below the current emission position happen when the
  //     encoder's reference-line model briefly disagrees with the decoder's;
  //     this is common around damaged or extension-coded rows.
  // libtiff, poppler and pdf.js all tolerate both cases silently — pdf.js
  // models the row as a list of changing-element positions so a regression
  // simply yields a zero-length (or notionally negative-length) run, and an
  // overrun is clamped to the row width. We mirror that lenience: clamp the
  // target to `[row.length(), columns]` and emit only forward pixels.
  // Importantly, even when no pixels are emitted we still let the caller
  // update `a0` and the running color, because the algorithm relies on
  // those state updates to find the next changing element on the reference
  // line. The caller's loop is bounded by bit-stream consumption, not by
  // row.length(), so failing to advance the row here cannot cause an
  // infinite loop — it just lets the row recover when subsequent codes
  // resync the model. Failing the whole image strands an entire scanned
  // page as blank, which is much worse than retaining a possibly-damaged
  // single row.
  let clamped_high = if position > columns { columns } else { position }
  let target = if clamped_high < row.length() { row.length() } else { clamped_high }
  while row.length() < target {
    row.push(black)
  }
}

///|
fn append_ccitt_run(
  row : Array[Bool],
  black : Bool,
  run : Int,
  columns : Int,
) -> Unit {
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
