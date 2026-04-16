///|
/// CCITT run-length Huffman table entry for white or black pixels. The code
/// bits are stored MSB first with an explicit bit length and the decoded run
/// length, including terminating and make-up codes.
pub struct CcittCode {
  bits : Int
  length : Int
  run : Int
}

///|
fn CcittCode::matches(self : CcittCode, bits : Int, length : Int) -> Bool {
  self.length == length && self.bits == bits
}

///|
/// Reports whether this CCITT Huffman table entry is a make-up run code
/// rather than a terminating run-length code.
pub fn CcittCode::is_makeup_code(self : CcittCode) -> Bool {
  if self.run < 64 {
    false
  } else {
    self.run % 64 == 0
  }
}

///|
/// CCITT Group 3 Group 4 Huffman code lookup white black run-length table
/// helper. It matches an MSB-first Huffman bit pattern against the selected
/// white or black run-length table and returns the decoded code entry.
pub fn lookup_ccitt_huffman_code(
  table : Array[CcittCode],
  bits : Int,
  length : Int,
) -> CcittCode? {
  for entry in table {
    if entry.matches(bits, length) {
      return Some(entry)
    }
  }
  None
}

///|
fn ccitt_code(pattern : String, run : Int) -> CcittCode {
  let mut bits = 0
  let mut index = 0
  while index < pattern.length() {
    bits = bits << 1
    if pattern.code_unit_at(index) == '1' {
      bits = bits | 1
    }
    index += 1
  }
  CcittCode::{ bits, length: pattern.length(), run }
}

///|
let ccitt_white_codes : Array[CcittCode] = [
  ccitt_code("00110101", 0),
  ccitt_code("000111", 1),
  ccitt_code("0111", 2),
  ccitt_code("1000", 3),
  ccitt_code("1011", 4),
  ccitt_code("1100", 5),
  ccitt_code("1110", 6),
  ccitt_code("1111", 7),
  ccitt_code("10011", 8),
  ccitt_code("10100", 9),
  ccitt_code("00111", 10),
  ccitt_code("01000", 11),
  ccitt_code("001000", 12),
  ccitt_code("000011", 13),
  ccitt_code("110100", 14),
  ccitt_code("110101", 15),
  ccitt_code("101010", 16),
  ccitt_code("101011", 17),
  ccitt_code("0100111", 18),
  ccitt_code("0001100", 19),
  ccitt_code("0001000", 20),
  ccitt_code("0010111", 21),
  ccitt_code("0000011", 22),
  ccitt_code("0000100", 23),
  ccitt_code("0101000", 24),
  ccitt_code("0101011", 25),
  ccitt_code("0010011", 26),
  ccitt_code("0100100", 27),
  ccitt_code("0011000", 28),
  ccitt_code("00000010", 29),
  ccitt_code("00000011", 30),
  ccitt_code("00011010", 31),
  ccitt_code("00011011", 32),
  ccitt_code("00010010", 33),
  ccitt_code("00010011", 34),
  ccitt_code("00010100", 35),
  ccitt_code("00010101", 36),
  ccitt_code("00010110", 37),
  ccitt_code("00010111", 38),
  ccitt_code("00101000", 39),
  ccitt_code("00101001", 40),
  ccitt_code("00101010", 41),
  ccitt_code("00101011", 42),
  ccitt_code("00101100", 43),
  ccitt_code("00101101", 44),
  ccitt_code("00000100", 45),
  ccitt_code("00000101", 46),
  ccitt_code("00001010", 47),
  ccitt_code("00001011", 48),
  ccitt_code("01010010", 49),
  ccitt_code("01010011", 50),
  ccitt_code("01010100", 51),
  ccitt_code("01010101", 52),
  ccitt_code("00100100", 53),
  ccitt_code("00100101", 54),
  ccitt_code("01011000", 55),
  ccitt_code("01011001", 56),
  ccitt_code("01011010", 57),
  ccitt_code("01011011", 58),
  ccitt_code("01001010", 59),
  ccitt_code("01001011", 60),
  ccitt_code("00110010", 61),
  ccitt_code("00110011", 62),
  ccitt_code("00110100", 63),
  ccitt_code("11011", 64),
  ccitt_code("10010", 128),
  ccitt_code("010111", 192),
  ccitt_code("0110111", 256),
  ccitt_code("00110110", 320),
  ccitt_code("00110111", 384),
  ccitt_code("01100100", 448),
  ccitt_code("01100101", 512),
  ccitt_code("01101000", 576),
  ccitt_code("01100111", 640),
  ccitt_code("011001100", 704),
  ccitt_code("011001101", 768),
  ccitt_code("011010010", 832),
  ccitt_code("011010011", 896),
  ccitt_code("011010100", 960),
  ccitt_code("011010101", 1024),
  ccitt_code("011010110", 1088),
  ccitt_code("011010111", 1152),
  ccitt_code("011011000", 1216),
  ccitt_code("011011001", 1280),
  ccitt_code("011011010", 1344),
  ccitt_code("011011011", 1408),
  ccitt_code("010011000", 1472),
  ccitt_code("010011001", 1536),
  ccitt_code("010011010", 1600),
  ccitt_code("011000", 1664),
  ccitt_code("010011011", 1728),
  ccitt_code("00000001000", 1792),
  ccitt_code("00000001100", 1856),
  ccitt_code("00000001101", 1920),
  ccitt_code("000000010010", 1984),
  ccitt_code("000000010011", 2048),
  ccitt_code("000000010100", 2112),
  ccitt_code("000000010101", 2176),
  ccitt_code("000000010110", 2240),
  ccitt_code("000000010111", 2304),
  ccitt_code("000000011100", 2368),
  ccitt_code("000000011101", 2432),
  ccitt_code("000000011110", 2496),
  ccitt_code("000000011111", 2560),
]

///|
let ccitt_black_codes : Array[CcittCode] = [
  ccitt_code("0000110111", 0),
  ccitt_code("010", 1),
  ccitt_code("11", 2),
  ccitt_code("10", 3),
  ccitt_code("011", 4),
  ccitt_code("0011", 5),
  ccitt_code("0010", 6),
  ccitt_code("00011", 7),
  ccitt_code("000101", 8),
  ccitt_code("000100", 9),
  ccitt_code("0000100", 10),
  ccitt_code("0000101", 11),
  ccitt_code("0000111", 12),
  ccitt_code("00000100", 13),
  ccitt_code("00000111", 14),
  ccitt_code("000011000", 15),
  ccitt_code("0000010111", 16),
  ccitt_code("0000011000", 17),
  ccitt_code("0000001000", 18),
  ccitt_code("00001100111", 19),
  ccitt_code("00001101000", 20),
  ccitt_code("00001101100", 21),
  ccitt_code("00000110111", 22),
  ccitt_code("00000101000", 23),
  ccitt_code("00000010111", 24),
  ccitt_code("00000011000", 25),
  ccitt_code("000011001010", 26),
  ccitt_code("000011001011", 27),
  ccitt_code("000011001100", 28),
  ccitt_code("000011001101", 29),
  ccitt_code("000001101000", 30),
  ccitt_code("000001101001", 31),
  ccitt_code("000001101010", 32),
  ccitt_code("000001101011", 33),
  ccitt_code("000011010010", 34),
  ccitt_code("000011010011", 35),
  ccitt_code("000011010100", 36),
  ccitt_code("000011010101", 37),
  ccitt_code("000011010110", 38),
  ccitt_code("000011010111", 39),
  ccitt_code("000001101100", 40),
  ccitt_code("000001101101", 41),
  ccitt_code("000011011010", 42),
  ccitt_code("000011011011", 43),
  ccitt_code("000001010100", 44),
  ccitt_code("000001010101", 45),
  ccitt_code("000001010110", 46),
  ccitt_code("000001010111", 47),
  ccitt_code("000001100100", 48),
  ccitt_code("000001100101", 49),
  ccitt_code("000001010010", 50),
  ccitt_code("000001010011", 51),
  ccitt_code("000000100100", 52),
  ccitt_code("000000110111", 53),
  ccitt_code("000000111000", 54),
  ccitt_code("000000100111", 55),
  ccitt_code("000000101000", 56),
  ccitt_code("000001011000", 57),
  ccitt_code("000001011001", 58),
  ccitt_code("000000101011", 59),
  ccitt_code("000000101100", 60),
  ccitt_code("000001011010", 61),
  ccitt_code("000001100110", 62),
  ccitt_code("000001100111", 63),
  ccitt_code("0000001111", 64),
  ccitt_code("000011001000", 128),
  ccitt_code("000011001001", 192),
  ccitt_code("000001011011", 256),
  ccitt_code("000000110011", 320),
  ccitt_code("000000110100", 384),
  ccitt_code("000000110101", 448),
  ccitt_code("0000001101100", 512),
  ccitt_code("0000001101101", 576),
  ccitt_code("0000001001010", 640),
  ccitt_code("0000001001011", 704),
  ccitt_code("0000001001100", 768),
  ccitt_code("0000001001101", 832),
  ccitt_code("0000001110010", 896),
  ccitt_code("0000001110011", 960),
  ccitt_code("0000001110100", 1024),
  ccitt_code("0000001110101", 1088),
  ccitt_code("0000001110110", 1152),
  ccitt_code("0000001110111", 1216),
  ccitt_code("0000001010010", 1280),
  ccitt_code("0000001010011", 1344),
  ccitt_code("0000001010100", 1408),
  ccitt_code("0000001010101", 1472),
  ccitt_code("0000001011010", 1536),
  ccitt_code("0000001011011", 1600),
  ccitt_code("0000001100100", 1664),
  ccitt_code("0000001100101", 1728),
  ccitt_code("00000001000", 1792),
  ccitt_code("00000001100", 1856),
  ccitt_code("00000001101", 1920),
  ccitt_code("000000010010", 1984),
  ccitt_code("000000010011", 2048),
  ccitt_code("000000010100", 2112),
  ccitt_code("000000010101", 2176),
  ccitt_code("000000010110", 2240),
  ccitt_code("000000010111", 2304),
  ccitt_code("000000011100", 2368),
  ccitt_code("000000011101", 2432),
  ccitt_code("000000011110", 2496),
  ccitt_code("000000011111", 2560),
]
