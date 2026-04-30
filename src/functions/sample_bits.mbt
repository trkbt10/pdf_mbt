///|
priv struct SampleBitReader {
  data : Bytes
  mut bit_position : Int
}

///|
fn SampleBitReader::new(data : Bytes) -> SampleBitReader {
  SampleBitReader::{ data, bit_position: 0 }
}

///|
fn SampleBitReader::read_sample(
  self : SampleBitReader,
  bits_per_sample : Int,
  offset : Int64,
) -> Double raise PdfFunctionError {
  if bits_per_sample <= 0 || bits_per_sample > 32 {
    raise function_error(offset, "BitsPerSample must be between 1 and 32")
  }
  let bit_limit = self.data.length() * 8
  if self.bit_position + bits_per_sample > bit_limit {
    raise function_error(
      offset, "sample stream is too short for declared Size and Range",
    )
  }
  let mut value = 0L
  let mut remaining = bits_per_sample
  while remaining > 0 {
    let bit_index = self.bit_position
    let byte_index = bit_index / 8
    let shift = 7 - bit_index % 8
    let bit = (self.data[byte_index].to_int() >> shift) & 1
    value = (value << 1) | bit.to_int64()
    self.bit_position = self.bit_position + 1
    remaining = remaining - 1
  }
  value.to_double()
}
