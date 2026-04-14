///|
let mask32 : Int64 = 0xffffffffL

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
fn read_le_u32(data : Bytes, offset : Int) -> Int64 {
  (
    data[offset].to_int64() |
    (data[offset + 1].to_int64() << 8) |
    (data[offset + 2].to_int64() << 16) |
    (data[offset + 3].to_int64() << 24)
  ) &
  mask32
}

///|
fn read_be_u32(data : Bytes, offset : Int) -> Int64 {
  (
    (data[offset].to_int64() << 24) |
    (data[offset + 1].to_int64() << 16) |
    (data[offset + 2].to_int64() << 8) |
    data[offset + 3].to_int64()
  ) &
  mask32
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
fn write_be_u32_words(words : Array[Int64], count : Int) -> Bytes {
  let out : Array[Byte] = []
  for index in 0..<count {
    out.append(be_u32_bytes(words[index]).to_array().view())
  }
  Bytes::from_array(out)
}

///|
fn concat_bytes(chunks : Array[Bytes]) -> Bytes {
  let out : Array[Byte] = []
  for chunk in chunks {
    out.append(chunk.to_array().view())
  }
  Bytes::from_array(out)
}

///|
fn bytes_slice(data : Bytes, start : Int, end : Int) -> Bytes {
  Bytes::from_array(data.view(start~, end~).to_array().view())
}

///|
fn add32(a : Int64, b : Int64) -> Int64 {
  (a + b) & mask32
}

///|
fn add32_4(a : Int64, b : Int64, c : Int64, d : Int64) -> Int64 {
  (a + b + c + d) & mask32
}

///|
fn add32_5(a : Int64, b : Int64, c : Int64, d : Int64, e : Int64) -> Int64 {
  (a + b + c + d + e) & mask32
}

///|
fn rotr32(value : Int64, amount : Int) -> Int64 {
  let v = value & mask32
  ((v >> amount) | ((v << (32 - amount)) & mask32)) & mask32
}

///|
fn rotl32(value : Int64, amount : Int) -> Int64 {
  let v = value & mask32
  (((v << amount) & mask32) | (v >> (32 - amount))) & mask32
}
