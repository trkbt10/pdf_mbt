///|
let sha256_k : Array[Int64] = [
  0x428a2f98L, 0x71374491L, 0xb5c0fbcfL, 0xe9b5dba5L, 0x3956c25bL, 0x59f111f1L, 0x923f82a4L,
  0xab1c5ed5L, 0xd807aa98L, 0x12835b01L, 0x243185beL, 0x550c7dc3L, 0x72be5d74L, 0x80deb1feL,
  0x9bdc06a7L, 0xc19bf174L, 0xe49b69c1L, 0xefbe4786L, 0x0fc19dc6L, 0x240ca1ccL, 0x2de92c6fL,
  0x4a7484aaL, 0x5cb0a9dcL, 0x76f988daL, 0x983e5152L, 0xa831c66dL, 0xb00327c8L, 0xbf597fc7L,
  0xc6e00bf3L, 0xd5a79147L, 0x06ca6351L, 0x14292967L, 0x27b70a85L, 0x2e1b2138L, 0x4d2c6dfcL,
  0x53380d13L, 0x650a7354L, 0x766a0abbL, 0x81c2c92eL, 0x92722c85L, 0xa2bfe8a1L, 0xa81a664bL,
  0xc24b8b70L, 0xc76c51a3L, 0xd192e819L, 0xd6990624L, 0xf40e3585L, 0x106aa070L, 0x19a4c116L,
  0x1e376c08L, 0x2748774cL, 0x34b0bcb5L, 0x391c0cb3L, 0x4ed8aa4aL, 0x5b9cca4fL, 0x682e6ff3L,
  0x748f82eeL, 0x78a5636fL, 0x84c87814L, 0x8cc70208L, 0x90befffaL, 0xa4506cebL, 0xbef9a3f7L,
  0xc67178f2L,
]

///|
pub fn sha256_digest(input : Bytes) -> Bytes raise PdfCryptoError {
  require_hashable_input(input)
  sha256_with_initial(input, [
    0x6a09e667L, 0xbb67ae85L, 0x3c6ef372L, 0xa54ff53aL, 0x510e527fL, 0x9b05688cL,
    0x1f83d9abL, 0x5be0cd19L,
  ])
}

///|
fn sha256_with_initial(input : Bytes, initial : Array[Int64]) -> Bytes {
  let message = sha256_pad(input)
  let h = initial.copy()
  let mut offset = 0
  while offset < message.length() {
    let w = Array::make(64, 0L)
    for i in 0..<16 {
      w[i] = read_be_u32(message, offset + i * 4)
    }
    for i in 16..<64 {
      let s0 = rotr32(w[i - 15], 7) ^ rotr32(w[i - 15], 18) ^ (w[i - 15] >> 3)
      let s1 = rotr32(w[i - 2], 17) ^ rotr32(w[i - 2], 19) ^ (w[i - 2] >> 10)
      w[i] = add32_4(w[i - 16], s0, w[i - 7], s1)
    }

    let mut a = h[0]
    let mut b = h[1]
    let mut c = h[2]
    let mut d = h[3]
    let mut e = h[4]
    let mut f = h[5]
    let mut g = h[6]
    let mut hh = h[7]

    for i in 0..<64 {
      let s1 = rotr32(e, 6) ^ rotr32(e, 11) ^ rotr32(e, 25)
      let ch = (e & f) ^ ((e ^ mask32) & mask32 & g)
      let temp1 = add32_5(hh, s1, ch, sha256_k[i], w[i])
      let s0 = rotr32(a, 2) ^ rotr32(a, 13) ^ rotr32(a, 22)
      let maj = (a & b) ^ (a & c) ^ (b & c)
      let temp2 = add32(s0, maj)
      hh = g
      g = f
      f = e
      e = add32(d, temp1)
      d = c
      c = b
      b = a
      a = add32(temp1, temp2)
    }

    h[0] = add32(h[0], a)
    h[1] = add32(h[1], b)
    h[2] = add32(h[2], c)
    h[3] = add32(h[3], d)
    h[4] = add32(h[4], e)
    h[5] = add32(h[5], f)
    h[6] = add32(h[6], g)
    h[7] = add32(h[7], hh)
    offset += 64
  }
  write_be_u32_words(h, 8)
}

///|
fn sha256_pad(input : Bytes) -> Bytes {
  let out = input.to_array()
  out.push(b'\x80')
  while out.length() % 64 != 56 {
    out.push(b'\x00')
  }
  let bit_len = input.length().to_int64().reinterpret_as_uint64() * 8UL
  out.append(bit_len.to_be_bytes().to_array().view())
  Bytes::from_array(out)
}

///|
let sha512_k : Array[UInt64] = [
  0x428a2f98d728ae22UL, 0x7137449123ef65cdUL, 0xb5c0fbcfec4d3b2fUL, 0xe9b5dba58189dbbcUL,
  0x3956c25bf348b538UL, 0x59f111f1b605d019UL, 0x923f82a4af194f9bUL, 0xab1c5ed5da6d8118UL,
  0xd807aa98a3030242UL, 0x12835b0145706fbeUL, 0x243185be4ee4b28cUL, 0x550c7dc3d5ffb4e2UL,
  0x72be5d74f27b896fUL, 0x80deb1fe3b1696b1UL, 0x9bdc06a725c71235UL, 0xc19bf174cf692694UL,
  0xe49b69c19ef14ad2UL, 0xefbe4786384f25e3UL, 0x0fc19dc68b8cd5b5UL, 0x240ca1cc77ac9c65UL,
  0x2de92c6f592b0275UL, 0x4a7484aa6ea6e483UL, 0x5cb0a9dcbd41fbd4UL, 0x76f988da831153b5UL,
  0x983e5152ee66dfabUL, 0xa831c66d2db43210UL, 0xb00327c898fb213fUL, 0xbf597fc7beef0ee4UL,
  0xc6e00bf33da88fc2UL, 0xd5a79147930aa725UL, 0x06ca6351e003826fUL, 0x142929670a0e6e70UL,
  0x27b70a8546d22ffcUL, 0x2e1b21385c26c926UL, 0x4d2c6dfc5ac42aedUL, 0x53380d139d95b3dfUL,
  0x650a73548baf63deUL, 0x766a0abb3c77b2a8UL, 0x81c2c92e47edaee6UL, 0x92722c851482353bUL,
  0xa2bfe8a14cf10364UL, 0xa81a664bbc423001UL, 0xc24b8b70d0f89791UL, 0xc76c51a30654be30UL,
  0xd192e819d6ef5218UL, 0xd69906245565a910UL, 0xf40e35855771202aUL, 0x106aa07032bbd1b8UL,
  0x19a4c116b8d2d0c8UL, 0x1e376c085141ab53UL, 0x2748774cdf8eeb99UL, 0x34b0bcb5e19b48a8UL,
  0x391c0cb3c5c95a63UL, 0x4ed8aa4ae3418acbUL, 0x5b9cca4f7763e373UL, 0x682e6ff3d6b2b8a3UL,
  0x748f82ee5defb2fcUL, 0x78a5636f43172f60UL, 0x84c87814a1f0ab72UL, 0x8cc702081a6439ecUL,
  0x90befffa23631e28UL, 0xa4506cebde82bde9UL, 0xbef9a3f7b2c67915UL, 0xc67178f2e372532bUL,
  0xca273eceea26619cUL, 0xd186b8c721c0c207UL, 0xeada7dd6cde0eb1eUL, 0xf57d4f7fee6ed178UL,
  0x06f067aa72176fbaUL, 0x0a637dc5a2c898a6UL, 0x113f9804bef90daeUL, 0x1b710b35131c471bUL,
  0x28db77f523047d84UL, 0x32caab7b40c72493UL, 0x3c9ebe0a15c9bebcUL, 0x431d67c49c100d4cUL,
  0x4cc5d4becb3e42b6UL, 0x597f299cfc657e2aUL, 0x5fcb6fab3ad6faecUL, 0x6c44198c4a475817UL,
]

///|
pub fn sha512_digest(input : Bytes) -> Bytes raise PdfCryptoError {
  require_hashable_input(input)
  sha512_with_initial(
    input,
    [
      0x6a09e667f3bcc908UL, 0xbb67ae8584caa73bUL, 0x3c6ef372fe94f82bUL, 0xa54ff53a5f1d36f1UL,
      0x510e527fade682d1UL, 0x9b05688c2b3e6c1fUL, 0x1f83d9abfb41bd6bUL, 0x5be0cd19137e2179UL,
    ],
    8,
  )
}

///|
pub fn sha384_digest(input : Bytes) -> Bytes raise PdfCryptoError {
  require_hashable_input(input)
  sha512_with_initial(
    input,
    [
      0xcbbb9d5dc1059ed8UL, 0x629a292a367cd507UL, 0x9159015a3070dd17UL, 0x152fecd8f70e5939UL,
      0x67332667ffc00b31UL, 0x8eb44a8768581511UL, 0xdb0c2e0d64f98fa7UL, 0x47b5481dbefa4fa4UL,
    ],
    6,
  )
}

///|
fn sha512_with_initial(
  input : Bytes,
  initial : Array[UInt64],
  output_words : Int,
) -> Bytes {
  let message = sha512_pad(input)
  let h = initial.copy()
  let mut offset = 0
  while offset < message.length() {
    let w = Array::make(80, 0UL)
    for i in 0..<16 {
      w[i] = read_be_u64(message, offset + i * 8)
    }
    for i in 16..<80 {
      let s0 = rotr64(w[i - 15], 1) ^ rotr64(w[i - 15], 8) ^ (w[i - 15] >> 7)
      let s1 = rotr64(w[i - 2], 19) ^ rotr64(w[i - 2], 61) ^ (w[i - 2] >> 6)
      w[i] = w[i - 16] + s0 + w[i - 7] + s1
    }

    let mut a = h[0]
    let mut b = h[1]
    let mut c = h[2]
    let mut d = h[3]
    let mut e = h[4]
    let mut f = h[5]
    let mut g = h[6]
    let mut hh = h[7]

    for i in 0..<80 {
      let s1 = rotr64(e, 14) ^ rotr64(e, 18) ^ rotr64(e, 41)
      let ch = (e & f) ^ ((e ^ 0xffffffffffffffffUL) & g)
      let temp1 = hh + s1 + ch + sha512_k[i] + w[i]
      let s0 = rotr64(a, 28) ^ rotr64(a, 34) ^ rotr64(a, 39)
      let maj = (a & b) ^ (a & c) ^ (b & c)
      let temp2 = s0 + maj
      hh = g
      g = f
      f = e
      e = d + temp1
      d = c
      c = b
      b = a
      a = temp1 + temp2
    }

    h[0] = h[0] + a
    h[1] = h[1] + b
    h[2] = h[2] + c
    h[3] = h[3] + d
    h[4] = h[4] + e
    h[5] = h[5] + f
    h[6] = h[6] + g
    h[7] = h[7] + hh
    offset += 128
  }
  write_be_u64_words(h, output_words)
}

///|
fn sha512_pad(input : Bytes) -> Bytes {
  let out = input.to_array()
  out.push(b'\x80')
  while out.length() % 128 != 112 {
    out.push(b'\x00')
  }
  for _ in 0..<8 {
    out.push(b'\x00')
  }
  let bit_len = input.length().to_int64().reinterpret_as_uint64() * 8UL
  out.append(bit_len.to_be_bytes().to_array().view())
  Bytes::from_array(out)
}

///|
fn rotr64(value : UInt64, amount : Int) -> UInt64 {
  (value >> amount) | (value << (64 - amount))
}
