///|
let aes_nb = 4

///|
pub fn aes_encrypt_block(
  key : Bytes,
  block : Bytes,
) -> Bytes raise PdfCryptoError {
  let schedule = AesSchedule::new(key)
  require_fixed_length(block, 16, "AES block")
  let state = block.to_array()
  add_round_key(state, schedule.round_keys, 0)
  for round in 1..<schedule.rounds {
    sub_bytes(state)
    shift_rows(state)
    mix_columns(state)
    add_round_key(state, schedule.round_keys, round)
  }
  sub_bytes(state)
  shift_rows(state)
  add_round_key(state, schedule.round_keys, schedule.rounds)
  Bytes::from_array(state)
}

///|
pub fn aes_decrypt_block(
  key : Bytes,
  block : Bytes,
) -> Bytes raise PdfCryptoError {
  let schedule = AesSchedule::new(key)
  require_fixed_length(block, 16, "AES block")
  let state = block.to_array()
  add_round_key(state, schedule.round_keys, schedule.rounds)
  let mut round = schedule.rounds - 1
  while round >= 1 {
    inv_shift_rows(state)
    inv_sub_bytes(state)
    add_round_key(state, schedule.round_keys, round)
    inv_mix_columns(state)
    round -= 1
  }
  inv_shift_rows(state)
  inv_sub_bytes(state)
  add_round_key(state, schedule.round_keys, 0)
  Bytes::from_array(state)
}

///|
pub fn aes_ecb_decrypt_block(
  key : Bytes,
  data : Bytes,
) -> Bytes raise PdfCryptoError {
  aes_decrypt_block(key, data)
}

///|
priv struct AesSchedule {
  rounds : Int
  round_keys : Array[Byte]
}

///|
fn AesSchedule::new(key : Bytes) -> AesSchedule raise PdfCryptoError {
  let nk = match key.length() {
    16 => 4
    32 => 8
    other =>
      raise PdfCryptoError::InvalidKey(
        "AES key must be 16 or 32 bytes, got " + other.to_string(),
      )
  }
  let rounds = match nk {
    4 => 10
    8 => 14
    _ => abort("unreachable AES key word count")
  }
  let words = aes_nb * (rounds + 1)
  let expanded = Array::make(words * 4, b'\x00')
  for index in 0..<key.length() {
    expanded[index] = key[index]
  }

  let temp = Array::make(4, b'\x00')
  let mut i = nk
  while i < words {
    for j in 0..<4 {
      temp[j] = expanded[(i - 1) * 4 + j]
    }
    if i % nk == 0 {
      rot_word(temp)
      sub_word(temp)
      temp[0] = temp[0] ^ aes_rcon(i / nk)
    } else if nk > 6 && i % nk == 4 {
      sub_word(temp)
    }
    for j in 0..<4 {
      expanded[i * 4 + j] = expanded[(i - nk) * 4 + j] ^ temp[j]
    }
    i += 1
  }
  AesSchedule::{ rounds, round_keys: expanded }
}

///|
fn add_round_key(
  state : Array[Byte],
  round_keys : Array[Byte],
  round : Int,
) -> Unit {
  let offset = round * 16
  for index in 0..<16 {
    state[index] = state[index] ^ round_keys[offset + index]
  }
}

///|
fn sub_bytes(state : Array[Byte]) -> Unit {
  for index in 0..<16 {
    state[index] = aes_sbox(state[index])
  }
}

///|
fn inv_sub_bytes(state : Array[Byte]) -> Unit {
  for index in 0..<16 {
    state[index] = aes_inv_sbox(state[index])
  }
}

///|
fn shift_rows(state : Array[Byte]) -> Unit {
  let copy = state.copy()
  for row in 0..<4 {
    for col in 0..<4 {
      state[row + 4 * col] = copy[row + 4 * ((col + row) % 4)]
    }
  }
}

///|
fn inv_shift_rows(state : Array[Byte]) -> Unit {
  let copy = state.copy()
  for row in 0..<4 {
    for col in 0..<4 {
      state[row + 4 * col] = copy[row + 4 * ((col - row + 4) % 4)]
    }
  }
}

///|
fn mix_columns(state : Array[Byte]) -> Unit {
  for col in 0..<4 {
    let offset = col * 4
    let a0 = state[offset]
    let a1 = state[offset + 1]
    let a2 = state[offset + 2]
    let a3 = state[offset + 3]
    state[offset] = gf_mul(a0, 2) ^ gf_mul(a1, 3) ^ a2 ^ a3
    state[offset + 1] = a0 ^ gf_mul(a1, 2) ^ gf_mul(a2, 3) ^ a3
    state[offset + 2] = a0 ^ a1 ^ gf_mul(a2, 2) ^ gf_mul(a3, 3)
    state[offset + 3] = gf_mul(a0, 3) ^ a1 ^ a2 ^ gf_mul(a3, 2)
  }
}

///|
fn inv_mix_columns(state : Array[Byte]) -> Unit {
  for col in 0..<4 {
    let offset = col * 4
    let a0 = state[offset]
    let a1 = state[offset + 1]
    let a2 = state[offset + 2]
    let a3 = state[offset + 3]
    state[offset] = gf_mul(a0, 14) ^
      gf_mul(a1, 11) ^
      gf_mul(a2, 13) ^
      gf_mul(a3, 9)
    state[offset + 1] = gf_mul(a0, 9) ^
      gf_mul(a1, 14) ^
      gf_mul(a2, 11) ^
      gf_mul(a3, 13)
    state[offset + 2] = gf_mul(a0, 13) ^
      gf_mul(a1, 9) ^
      gf_mul(a2, 14) ^
      gf_mul(a3, 11)
    state[offset + 3] = gf_mul(a0, 11) ^
      gf_mul(a1, 13) ^
      gf_mul(a2, 9) ^
      gf_mul(a3, 14)
  }
}

///|
fn rot_word(word : Array[Byte]) -> Unit {
  let first = word[0]
  word[0] = word[1]
  word[1] = word[2]
  word[2] = word[3]
  word[3] = first
}

///|
fn sub_word(word : Array[Byte]) -> Unit {
  for index in 0..<4 {
    word[index] = aes_sbox(word[index])
  }
}

///|
fn aes_rcon(index : Int) -> Byte {
  let mut value = b'\x01'
  if index == 0 {
    b'\x00'
  } else {
    for _ in 1..<index {
      value = xtime(value)
    }
    value
  }
}

///|
fn xtime(value : Byte) -> Byte {
  let shifted = value.to_int() << 1
  let reduced = if (value.to_int() & 0x80) != 0 {
    shifted ^ 0x1b
  } else {
    shifted
  }
  (reduced & 0xff).to_byte()
}

///|
fn gf_mul(left : Byte, right : Int) -> Byte {
  let mut a = left
  let mut b = right
  let mut result = b'\x00'
  while b > 0 {
    if (b & 1) != 0 {
      result = result ^ a
    }
    a = xtime(a)
    b = b >> 1
  }
  result
}

///|
fn aes_sbox(value : Byte) -> Byte {
  let inv = gf_inverse(value)
  let x = inv.to_int()
  let transformed = x ^
    rot_byte_left(x, 1) ^
    rot_byte_left(x, 2) ^
    rot_byte_left(x, 3) ^
    rot_byte_left(x, 4) ^
    0x63
  (transformed & 0xff).to_byte()
}

///|
fn aes_inv_sbox(value : Byte) -> Byte {
  let target = value
  let mut candidate = 0
  while candidate < 256 {
    if aes_sbox(candidate.to_byte()) == target {
      return candidate.to_byte()
    }
    candidate += 1
  }
  abort("AES inverse S-box search failed")
}

///|
fn gf_inverse(value : Byte) -> Byte {
  if value == b'\x00' {
    b'\x00'
  } else {
    gf_pow(value, 254)
  }
}

///|
fn gf_pow(base : Byte, exponent : Int) -> Byte {
  let mut result = b'\x01'
  let mut power = base
  let mut exp = exponent
  while exp > 0 {
    if (exp & 1) != 0 {
      result = gf_mul(result, power.to_int())
    }
    power = gf_mul(power, power.to_int())
    exp = exp >> 1
  }
  result
}

///|
fn rot_byte_left(value : Int, amount : Int) -> Int {
  ((value << amount) | (value >> (8 - amount))) & 0xff
}
