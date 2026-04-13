///|
let lzw_initial_code_width = 9

///|
let lzw_clear_code = 256

///|
let lzw_end_of_data_code = 257

///|
let lzw_table_capacity = 4096

///|
priv struct LzwDecoder {
  reader : MsbBitReader
  mut table : Array[Array[Byte]?]
  mut next_code : Int
  mut code_width : Int
  early_change : Int
  mut previous_sequence : Array[Byte]?
}

///|
fn decode_lzw(
  data : Bytes,
  params : DecodeParams,
) -> Bytes raise PdfFilterError {
  let early_change = read_lzw_early_change(params)
  let decoded = LzwDecoder::new(data, early_change).decode()
  apply_predictor("LZWDecode", decoded, params)
}

///|
fn LzwDecoder::new(data : Bytes, early_change : Int) -> LzwDecoder {
  LzwDecoder::{
    reader: MsbBitReader::new(data),
    table: build_lzw_table(),
    next_code: lzw_end_of_data_code + 1,
    code_width: lzw_initial_code_width,
    early_change,
    previous_sequence: None,
  }
}

///|
fn LzwDecoder::decode(self : LzwDecoder) -> Bytes raise PdfFilterError {
  let first_code = match self.read_code() {
    Some(code) => code
    None =>
      raise PdfFilterError::DecodeError(
        "LZWDecode", "stream must start with a clear-table code",
      )
  }
  if first_code != lzw_clear_code {
    raise PdfFilterError::DecodeError(
      "LZWDecode", "stream must start with a clear-table code",
    )
  }

  self.reset_state()

  let output : Array[Byte] = []
  let mut finished = false
  while !finished {
    match self.read_code() {
      Some(code) =>
        if code == lzw_clear_code {
          self.reset_state()
        } else if code == lzw_end_of_data_code {
          finished = true
        } else {
          self.decode_code(code, output)
        }
      None =>
        raise PdfFilterError::DecodeError(
          "LZWDecode", "missing LZW end-of-data code",
        )
    }
  }
  Bytes::from_array(output)
}

///|
fn LzwDecoder::decode_code(
  self : LzwDecoder,
  code : Int,
  output : Array[Byte],
) -> Unit raise PdfFilterError {
  let sequence = self.resolve_sequence(code)
  output.append(sequence)
  self.record_sequence(sequence)
}

///|
fn LzwDecoder::record_sequence(
  self : LzwDecoder,
  sequence : Array[Byte],
) -> Unit {
  match self.previous_sequence {
    Some(previous_sequence) => self.extend_table(previous_sequence, sequence)
    None => ()
  }
  self.previous_sequence = Some(sequence)
}

///|
fn LzwDecoder::extend_table(
  self : LzwDecoder,
  previous_sequence : Array[Byte],
  sequence : Array[Byte],
) -> Unit {
  if self.next_code < lzw_table_capacity && sequence.length() > 0 {
    let new_entry : Array[Byte] = []
    new_entry.append(previous_sequence)
    new_entry.push(sequence[0])
    if self.next_code == self.table.length() {
      self.table.push(Some(new_entry))
    } else {
      self.table[self.next_code] = Some(new_entry)
    }
    self.next_code = self.next_code + 1
    self.maybe_grow_code_width()
  }
}

///|
fn LzwDecoder::reset_state(self : LzwDecoder) -> Unit {
  self.table = build_lzw_table()
  self.next_code = lzw_end_of_data_code + 1
  self.code_width = lzw_initial_code_width
  self.previous_sequence = None
}

///|
fn LzwDecoder::read_code(self : LzwDecoder) -> Int? {
  self.reader.read_bits(self.code_width)
}

///|
fn LzwDecoder::resolve_sequence(
  self : LzwDecoder,
  code : Int,
) -> Array[Byte] raise PdfFilterError {
  if code == self.next_code {
    match self.previous_sequence {
      Some(previous_sequence) => build_current_sequence(previous_sequence)
      None => raise PdfFilterError::DecodeError("LZWDecode", "invalid LZW code")
    }
  } else if code >= 0 && code < self.table.length() {
    match self.table[code] {
      Some(sequence) => sequence
      None => raise PdfFilterError::DecodeError("LZWDecode", "invalid LZW code")
    }
  } else {
    raise PdfFilterError::DecodeError("LZWDecode", "invalid LZW code")
  }
}

///|
fn build_current_sequence(previous_sequence : Array[Byte]) -> Array[Byte] {
  let sequence : Array[Byte] = []
  sequence.append(previous_sequence)
  sequence.push(previous_sequence[0])
  sequence
}

///|
fn LzwDecoder::maybe_grow_code_width(self : LzwDecoder) -> Unit {
  if self.code_width < 12 {
    let threshold = (1 << self.code_width) - self.early_change
    if self.next_code == threshold {
      self.code_width = self.code_width + 1
    }
  }
}

///|
fn read_lzw_early_change(params : DecodeParams) -> Int raise PdfFilterError {
  match read_integer_parameter("LZWDecode", params.raw, "EarlyChange", 1) {
    0 => 0
    1 => 1
    _ =>
      raise PdfFilterError::InvalidDecodeParms(
        "LZWDecode", "EarlyChange must be 0 or 1",
      )
  }
}

///|
fn build_lzw_table() -> Array[Array[Byte]?] {
  let table : Array[Array[Byte]?] = []
  let mut value = 0
  while value < 256 {
    table.push(Some([value.to_byte()]))
    value = value + 1
  }
  table.push(None)
  table.push(None)
  table
}
