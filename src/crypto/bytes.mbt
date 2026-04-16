///|
pub fn bytes_xor(left : Bytes, right : Bytes) -> Bytes raise PdfCryptoError {
  if left.length() != right.length() {
    raise PdfCryptoError::InvalidLength("xor inputs must have equal length")
  }
  Bytes::makei(left.length(), index => left[index] ^ right[index])
}

///|
pub fn zero_iv(length : Int) -> Bytes raise PdfCryptoError {
  if length < 0 {
    raise PdfCryptoError::InvalidIv("IV length must be non-negative")
  }
  Bytes::make(length, b'\x00')
}

///|
pub fn require_fixed_length(
  bytes : Bytes,
  expected : Int,
  label : String,
) -> Unit raise PdfCryptoError {
  if bytes.length() != expected {
    raise PdfCryptoError::InvalidLength(
      label + " must be " + expected.to_string() + " bytes",
    )
  }
}

///|
pub fn require_block_aligned(
  bytes : Bytes,
  block_size : Int,
  label : String,
) -> Unit raise PdfCryptoError {
  if block_size <= 0 {
    raise PdfCryptoError::InvalidBlockSize("block size must be positive")
  }
  if bytes.length() % block_size != 0 {
    raise PdfCryptoError::InvalidBlockSize(
      label + " length must be a multiple of " + block_size.to_string(),
    )
  }
}

///|
pub fn le_u32_bytes(value : Int64) -> Bytes {
  Bytes::from_array([
    (value & 0xffL).to_byte(),
    ((value >> 8) & 0xffL).to_byte(),
    ((value >> 16) & 0xffL).to_byte(),
    ((value >> 24) & 0xffL).to_byte(),
  ])
}

///|
pub fn be_u32_bytes(value : Int64) -> Bytes {
  Bytes::from_array([
    ((value >> 24) & 0xffL).to_byte(),
    ((value >> 16) & 0xffL).to_byte(),
    ((value >> 8) & 0xffL).to_byte(),
    (value & 0xffL).to_byte(),
  ])
}

///|
pub fn le_u64_bytes(value : UInt64) -> Bytes {
  value.to_le_bytes()
}

///|
pub fn be_u64_bytes(value : UInt64) -> Bytes {
  value.to_be_bytes()
}

///|
fn read_be_u64(data : Bytes, offset : Int) -> UInt64 {
  let mut value = 0UL
  for index in 0..<8 {
    value = (value << 8) | data[offset + index].to_uint64()
  }
  value
}

///|
fn write_be_u64_words(words : Array[UInt64], count : Int) -> Bytes {
  let out : Array[Byte] = []
  for index in 0..<count {
    out.append(words[index].to_be_bytes().to_array().view())
  }
  Bytes::from_array(out)
}

///|
fn bytes_slice(data : Bytes, start : Int, end : Int) -> Bytes {
  Bytes::from_array(data.view(start~, end~).to_array().view())
}
