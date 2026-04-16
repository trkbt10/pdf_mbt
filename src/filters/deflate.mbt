///|
fn decode_deflate(data : Bytes) -> Bytes raise PdfFilterError {
  let reader = LsbBitReader::new(data)
  let output : Array[Byte] = []
  let mut final_block_seen = false

  while !final_block_seen {
    let is_final = reader.read_bits(1)
    let block_type = reader.read_bits(2)

    match block_type {
      0 => decode_stored_block(reader, output)
      1 => decode_fixed_huffman_block(reader, output)
      2 => decode_dynamic_huffman_block(reader, output)
      _ =>
        raise PdfFilterError::DecodeError(
          "FlateDecode", "unsupported DEFLATE block type",
        )
    }

    final_block_seen = is_final == 1
  }

  reader.align_to_byte()
  if reader.byte_position() != data.length() {
    raise PdfFilterError::DecodeError(
      "FlateDecode", "trailing data after final DEFLATE block",
    )
  }

  Bytes::from_array(output)
}

///|
/// Decodes a FlateDecode zlib stream and applies optional DecodeParms predictors.
pub fn decode_flate(
  data : Bytes,
  params : DecodeParams,
) -> Bytes raise PdfFilterError {
  let decoded = decode_zlib_stream(data)
  apply_predictor("FlateDecode", decoded, params)
}

///|
fn decode_zlib_stream(data : Bytes) -> Bytes raise PdfFilterError {
  let zlib = parse_zlib_stream(data)
  let decoded = decode_deflate(zlib.deflate_data)
  validate_adler32("FlateDecode", decoded, zlib.expected_adler32)
  decoded
}

///|
fn decode_stored_block(
  reader : LsbBitReader,
  output : Array[Byte],
) -> Unit raise PdfFilterError {
  reader.align_to_byte()

  let stored_length = read_u16_le(reader)
  let stored_length_complement = read_u16_le(reader)
  if (stored_length ^ 0xffff) != stored_length_complement {
    raise PdfFilterError::DecodeError(
      "FlateDecode", "stored block length check failed",
    )
  }

  let mut remaining = stored_length
  while remaining > 0 {
    output.push(reader.read_bits(8).to_byte())
    remaining = remaining - 1
  }
}

///|
fn decode_fixed_huffman_block(
  reader : LsbBitReader,
  output : Array[Byte],
) -> Unit raise PdfFilterError {
  let literal_length_table = build_fixed_literal_length_table()
  let distance_table = build_fixed_distance_table()
  decode_huffman_block(reader, output, literal_length_table, distance_table)
}

///|
fn decode_dynamic_huffman_block(
  reader : LsbBitReader,
  output : Array[Byte],
) -> Unit raise PdfFilterError {
  let tables = build_dynamic_huffman_tables(reader)
  decode_huffman_block(
    reader,
    output,
    tables.literal_length_table,
    tables.distance_table,
  )
}

///|
fn decode_huffman_block(
  reader : LsbBitReader,
  output : Array[Byte],
  literal_length_table : HuffmanTable,
  distance_table : HuffmanTable,
) -> Unit raise PdfFilterError {
  while true {
    let symbol = literal_length_table.decode_symbol(reader)
    if symbol < 256 {
      output.push(symbol.to_byte())
    } else if symbol == 256 {
      break
    } else {
      let length = decode_length_symbol(symbol, reader)
      let distance_symbol = distance_table.decode_symbol(reader)
      let distance = decode_distance_symbol(distance_symbol, reader)
      copy_back_reference(output, length, distance)
    }
  }
}

///|
fn copy_back_reference(
  output : Array[Byte],
  length : Int,
  distance : Int,
) -> Unit raise PdfFilterError {
  if distance > output.length() {
    raise PdfFilterError::DecodeError(
      "FlateDecode", "distance reference reaches before already produced output",
    )
  }

  let start = output.length() - distance
  let mut copied = 0
  while copied < length {
    output.push(output[start + copied])
    copied = copied + 1
  }
}

///|
fn read_u16_le(reader : LsbBitReader) -> Int raise PdfFilterError {
  let low = reader.read_bits(8)
  let high = reader.read_bits(8)
  low | (high << 8)
}
