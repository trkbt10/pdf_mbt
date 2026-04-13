///|
let fixed_length_base : Array[Int] = [
  3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31, 35, 43, 51, 59, 67, 83,
  99, 115, 131, 163, 195, 227, 258,
]

///|
let fixed_length_extra_bits : Array[Int] = [
  0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5,
  5, 0,
]

///|
let fixed_distance_base : Array[Int] = [
  1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193, 257, 385, 513, 769,
  1025, 1537, 2049, 3073, 4097, 6145, 8193, 12289, 16385, 24577,
]

///|
let fixed_distance_extra_bits : Array[Int] = [
  0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 11, 11,
  12, 12, 13, 13,
]

///|
let code_length_order : Array[Int] = [
  16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15,
]

///|
priv struct HuffmanTable {
  rows : Array[Array[Int?]]
  max_bits : Int
}

///|
priv struct DynamicHuffmanTables {
  literal_length_table : HuffmanTable
  distance_table : HuffmanTable
}

///|
fn HuffmanTable::decode_symbol(
  self : HuffmanTable,
  reader : LsbBitReader,
) -> Int raise PdfFilterError {
  let mut code = 0
  let mut bits_read = 1

  while bits_read <= self.max_bits {
    code = code | (reader.read_bits(1) << (bits_read - 1))
    let row = self.rows[bits_read]
    if code < row.length() {
      match row[code] {
        Some(symbol) => return symbol
        None => ()
      }
    }
    bits_read = bits_read + 1
  }

  raise PdfFilterError::DecodeError("FlateDecode", "invalid Huffman code")
}

///|
fn build_fixed_literal_length_table() -> HuffmanTable raise PdfFilterError {
  let lengths = Array::make(288, 0)
  let mut symbol = 0
  while symbol < 144 {
    lengths[symbol] = 8
    symbol = symbol + 1
  }
  while symbol < 256 {
    lengths[symbol] = 9
    symbol = symbol + 1
  }
  while symbol < 280 {
    lengths[symbol] = 7
    symbol = symbol + 1
  }
  while symbol < 288 {
    lengths[symbol] = 8
    symbol = symbol + 1
  }

  build_huffman_table(lengths, 9)
}

///|
fn build_fixed_distance_table() -> HuffmanTable raise PdfFilterError {
  build_huffman_table(Array::make(32, 5), 5)
}

///|
fn build_huffman_table(
  lengths : Array[Int],
  max_bits : Int,
) -> HuffmanTable raise PdfFilterError {
  let counts = Array::make(max_bits + 1, 0)
  let mut symbol = 0
  while symbol < lengths.length() {
    let length = lengths[symbol]
    if length < 0 || length > max_bits {
      raise PdfFilterError::DecodeError(
        "FlateDecode", "Huffman code length out of range",
      )
    }
    if length > 0 {
      counts[length] = counts[length] + 1
    }
    symbol = symbol + 1
  }

  let mut left = 1
  let mut bits = 1
  while bits <= max_bits {
    left = (left << 1) - counts[bits]
    if left < 0 {
      raise PdfFilterError::DecodeError(
        "FlateDecode", "over-subscribed Huffman table",
      )
    }
    bits = bits + 1
  }

  if left != 0 {
    raise PdfFilterError::DecodeError("FlateDecode", "incomplete Huffman table")
  }

  let rows : Array[Array[Int?]] = []
  let mut bits = 0
  while bits <= max_bits {
    rows.push(Array::make(1 << bits, None))
    bits = bits + 1
  }

  let next_code = Array::make(max_bits + 1, 0)
  let mut code = 0
  bits = 1
  while bits <= max_bits {
    code = (code + counts[bits - 1]) << 1
    next_code[bits] = code
    bits = bits + 1
  }

  symbol = 0
  while symbol < lengths.length() {
    let length = lengths[symbol]
    if length > 0 {
      let code_value = next_code[length]
      next_code[length] = code_value + 1
      let encoded_code = reverse_bits(code_value, length)

      let row = rows[length]
      if encoded_code >= row.length() {
        raise PdfFilterError::DecodeError(
          "FlateDecode", "over-subscribed Huffman table",
        )
      }

      match row[encoded_code] {
        Some(_) =>
          raise PdfFilterError::DecodeError(
            "FlateDecode", "over-subscribed Huffman table",
          )
        None => row[encoded_code] = Some(symbol)
      }
    }
    symbol = symbol + 1
  }

  HuffmanTable::{ rows, max_bits }
}

///|
fn build_dynamic_huffman_tables(
  reader : LsbBitReader,
) -> DynamicHuffmanTables raise PdfFilterError {
  let literal_length_count = reader.read_bits(5) + 257
  let distance_count = reader.read_bits(5) + 1
  let code_length_count = reader.read_bits(4) + 4

  let code_length_lengths = Array::make(19, 0)
  let mut index = 0
  while index < code_length_count {
    let symbol = code_length_order[index]
    code_length_lengths[symbol] = reader.read_bits(3)
    index = index + 1
  }

  let code_length_table = build_huffman_table(code_length_lengths, 7)
  let total_length_count = literal_length_count + distance_count
  let combined_lengths = decode_code_lengths(
    reader, code_length_table, total_length_count,
  )

  let literal_length_lengths = Array::make(literal_length_count, 0)
  let mut literal_index = 0
  while literal_index < literal_length_count {
    literal_length_lengths[literal_index] = combined_lengths[literal_index]
    literal_index = literal_index + 1
  }

  if literal_length_lengths[256] == 0 {
    raise PdfFilterError::DecodeError(
      "FlateDecode", "missing end-of-block code",
    )
  }

  let distance_lengths = Array::make(distance_count, 0)
  let mut distance_index = 0
  while distance_index < distance_count {
    distance_lengths[distance_index] = combined_lengths[literal_length_count +
      distance_index]
    distance_index = distance_index + 1
  }

  DynamicHuffmanTables::{
    literal_length_table: build_huffman_table(literal_length_lengths, 15),
    distance_table: build_huffman_table(distance_lengths, 15),
  }
}

///|
fn decode_code_lengths(
  reader : LsbBitReader,
  code_length_table : HuffmanTable,
  total_count : Int,
) -> Array[Int] raise PdfFilterError {
  let lengths = Array::make(total_count, 0)
  let mut index = 0
  let mut last_length : Int? = None

  while index < total_count {
    let symbol = code_length_table.decode_symbol(reader)
    match symbol {
      0..<16 => {
        lengths[index] = symbol
        last_length = Some(symbol)
        index = index + 1
      }
      16 =>
        match last_length {
          Some(previous_length) => {
            let repeat_count = reader.read_bits(2) + 3
            if index + repeat_count > total_count {
              raise PdfFilterError::DecodeError(
                "FlateDecode", "repeated Huffman code lengths exceed the declared table size",
              )
            }
            let mut copied = 0
            while copied < repeat_count {
              lengths[index] = previous_length
              index = index + 1
              copied = copied + 1
            }
          }
          None =>
            raise PdfFilterError::DecodeError(
              "FlateDecode", "repeat code length without a previous length",
            )
        }
      17 => {
        let repeat_count = reader.read_bits(3) + 3
        if index + repeat_count > total_count {
          raise PdfFilterError::DecodeError(
            "FlateDecode", "repeated Huffman code lengths exceed the declared table size",
          )
        }
        let mut copied = 0
        while copied < repeat_count {
          lengths[index] = 0
          index = index + 1
          copied = copied + 1
        }
        last_length = Some(0)
      }
      18 => {
        let repeat_count = reader.read_bits(7) + 11
        if index + repeat_count > total_count {
          raise PdfFilterError::DecodeError(
            "FlateDecode", "repeated Huffman code lengths exceed the declared table size",
          )
        }
        let mut copied = 0
        while copied < repeat_count {
          lengths[index] = 0
          index = index + 1
          copied = copied + 1
        }
        last_length = Some(0)
      }
      _ =>
        raise PdfFilterError::DecodeError(
          "FlateDecode", "invalid Huffman code-length symbol",
        )
    }
  }

  lengths
}

///|
fn decode_fixed_length(
  symbol : Int,
  reader : LsbBitReader,
) -> Int raise PdfFilterError {
  if symbol < 257 || symbol > 285 {
    raise PdfFilterError::DecodeError(
      "FlateDecode", "reserved fixed Huffman length code",
    )
  }

  let index = symbol - 257
  let extra_bits = fixed_length_extra_bits[index]
  let base_length = fixed_length_base[index]
  base_length + read_optional_bits(reader, extra_bits)
}

///|
fn decode_length_symbol(
  symbol : Int,
  reader : LsbBitReader,
) -> Int raise PdfFilterError {
  decode_fixed_length(symbol, reader)
}

///|
fn decode_fixed_distance(
  symbol : Int,
  reader : LsbBitReader,
) -> Int raise PdfFilterError {
  if symbol < 0 || symbol > 29 {
    raise PdfFilterError::DecodeError(
      "FlateDecode", "reserved fixed Huffman distance code",
    )
  }

  let extra_bits = fixed_distance_extra_bits[symbol]
  let base_distance = fixed_distance_base[symbol]
  base_distance + read_optional_bits(reader, extra_bits)
}

///|
fn decode_distance_symbol(
  symbol : Int,
  reader : LsbBitReader,
) -> Int raise PdfFilterError {
  decode_fixed_distance(symbol, reader)
}

///|
fn read_optional_bits(
  reader : LsbBitReader,
  bit_count : Int,
) -> Int raise PdfFilterError {
  if bit_count == 0 {
    0
  } else {
    reader.read_bits(bit_count)
  }
}

///|
fn reverse_bits(value : Int, bit_count : Int) -> Int {
  let mut source = value
  let mut reversed = 0
  let mut bits = 0
  while bits < bit_count {
    reversed = (reversed << 1) | (source & 1)
    source = source >> 1
    bits = bits + 1
  }
  reversed
}
