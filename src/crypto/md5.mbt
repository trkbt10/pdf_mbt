///|
let md5_s : Array[Int] = [
  7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22, 5, 9, 14, 20, 5, 9,
  14, 20, 5, 9, 14, 20, 5, 9, 14, 20, 4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23,
  4, 11, 16, 23, 6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21,
]

///|
let md5_k : Array[Int64] = [
  0xd76aa478L, 0xe8c7b756L, 0x242070dbL, 0xc1bdceeeL, 0xf57c0fafL, 0x4787c62aL, 0xa8304613L,
  0xfd469501L, 0x698098d8L, 0x8b44f7afL, 0xffff5bb1L, 0x895cd7beL, 0x6b901122L, 0xfd987193L,
  0xa679438eL, 0x49b40821L, 0xf61e2562L, 0xc040b340L, 0x265e5a51L, 0xe9b6c7aaL, 0xd62f105dL,
  0x02441453L, 0xd8a1e681L, 0xe7d3fbc8L, 0x21e1cde6L, 0xc33707d6L, 0xf4d50d87L, 0x455a14edL,
  0xa9e3e905L, 0xfcefa3f8L, 0x676f02d9L, 0x8d2a4c8aL, 0xfffa3942L, 0x8771f681L, 0x6d9d6122L,
  0xfde5380cL, 0xa4beea44L, 0x4bdecfa9L, 0xf6bb4b60L, 0xbebfbc70L, 0x289b7ec6L, 0xeaa127faL,
  0xd4ef3085L, 0x04881d05L, 0xd9d4d039L, 0xe6db99e5L, 0x1fa27cf8L, 0xc4ac5665L, 0xf4292244L,
  0x432aff97L, 0xab9423a7L, 0xfc93a039L, 0x655b59c3L, 0x8f0ccc92L, 0xffeff47dL, 0x85845dd1L,
  0x6fa87e4fL, 0xfe2ce6e0L, 0xa3014314L, 0x4e0811a1L, 0xf7537e82L, 0xbd3af235L, 0x2ad7d2bbL,
  0xeb86d391L,
]

///|
pub fn md5_digest(input : Bytes) -> Bytes raise PdfCryptoError {
  require_hashable_input(input)
  let message = md5_pad(input)
  let mut a0 = 0x67452301L
  let mut b0 = 0xefcdab89L
  let mut c0 = 0x98badcfeL
  let mut d0 = 0x10325476L

  let mut offset = 0
  while offset < message.length() {
    let m = Array::make(16, 0L)
    for index in 0..<16 {
      m[index] = read_le_u32(message, offset + index * 4)
    }

    let mut a = a0
    let mut b = b0
    let mut c = c0
    let mut d = d0

    for i in 0..<64 {
      let (f, g) = if i < 16 {
        (((b & c) | ((b ^ mask32) & mask32 & d)) & mask32, i)
      } else if i < 32 {
        (((d & b) | ((d ^ mask32) & mask32 & c)) & mask32, (5 * i + 1) % 16)
      } else if i < 48 {
        ((b ^ c ^ d) & mask32, (3 * i + 5) % 16)
      } else {
        ((c ^ (b | ((d ^ mask32) & mask32))) & mask32, 7 * i % 16)
      }
      let temp = d
      d = c
      c = b
      b = add32(b, rotl32(add32_4(a, f, md5_k[i], m[g]), md5_s[i]))
      a = temp
    }

    a0 = add32(a0, a)
    b0 = add32(b0, b)
    c0 = add32(c0, c)
    d0 = add32(d0, d)
    offset += 64
  }

  concat_bytes([
    le_u32_bytes(a0),
    le_u32_bytes(b0),
    le_u32_bytes(c0),
    le_u32_bytes(d0),
  ])
}

///|
fn require_hashable_input(input : Bytes) -> Unit raise PdfCryptoError {
  if input.length().to_int64() > 0x1fffffffffffffffL {
    raise PdfCryptoError::InvalidLength("hash input is too large")
  }
}

///|
fn md5_pad(input : Bytes) -> Bytes {
  let out = input.to_array()
  out.push(b'\x80')
  while out.length() % 64 != 56 {
    out.push(b'\x00')
  }
  let bit_len = input.length().to_int64() * 8L
  out.append(bit_len.reinterpret_as_uint64().to_le_bytes().to_array().view())
  Bytes::from_array(out)
}
