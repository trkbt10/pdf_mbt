///|
priv struct LsbBitReader {
  data : Bytes
  mut byte_index : Int
  mut bit_index : Int
}

///|
fn LsbBitReader::new(data : Bytes) -> LsbBitReader {
  LsbBitReader::{ data, byte_index: 0, bit_index: 0 }
}

///|
fn LsbBitReader::read_bits(
  self : LsbBitReader,
  bit_count : Int,
) -> Int raise PdfFilterError {
  if bit_count < 0 {
    raise PdfFilterError::DecodeError(
      "FlateDecode", "bit count must be non-negative",
    )
  }

  let mut value : Int64 = 0L
  let mut shift = 0
  while shift < bit_count {
    if self.byte_index >= self.data.length() {
      raise PdfFilterError::DecodeError(
        "FlateDecode", "truncated DEFLATE bit stream",
      )
    }

    let current_byte = self.data[self.byte_index].to_int()
    let bit = (current_byte >> self.bit_index) & 1
    value = value | (bit.to_int64() << shift)
    self.bit_index = self.bit_index + 1
    if self.bit_index == 8 {
      self.bit_index = 0
      self.byte_index = self.byte_index + 1
    }
    shift = shift + 1
  }

  value.to_int()
}

///|
fn LsbBitReader::align_to_byte(self : LsbBitReader) -> Unit {
  if self.bit_index != 0 {
    self.bit_index = 0
    self.byte_index = self.byte_index + 1
  }
}

///|
fn LsbBitReader::byte_position(self : LsbBitReader) -> Int {
  self.byte_index
}

///|
priv struct MsbBitReader {
  data : Bytes
  mut bit_position : Int
}

///|
fn MsbBitReader::new(data : Bytes) -> MsbBitReader {
  MsbBitReader::{ data, bit_position: 0 }
}

///|
fn MsbBitReader::read_bits(self : MsbBitReader, bit_count : Int) -> Int? {
  if bit_count < 0 {
    None
  } else {
    let bit_limit = self.data.length() * 8
    if self.bit_position + bit_count > bit_limit {
      None
    } else {
      let mut value = 0
      let mut remaining = bit_count
      while remaining > 0 {
        let bit_index = self.bit_position
        let byte_index = bit_index / 8
        let shift = 7 - bit_index % 8
        let bit = (self.data[byte_index].to_int() >> shift) & 1
        value = (value << 1) | bit
        self.bit_position = self.bit_position + 1
        remaining = remaining - 1
      }
      Some(value)
    }
  }
}
