///|
/// Decodes a raw DEFLATE stream and returns only the decoded bytes. Use
/// `decode_deflate_with_position` when the caller also needs the input
/// byte offset where decoding stopped (zlib needs that to locate the
/// trailing Adler-32 immediately after the final block, since some
/// producers leave padding bytes between the deflate body and the
/// checksum).
fn decode_deflate(data : Bytes) -> Bytes raise PdfFilterError {
  decode_deflate_with_position(data).0
}

///|
/// Like `decode_deflate`, but also returns the byte offset in `data` at
/// which the decoder stopped after consuming the final block and aligning
/// to the next byte boundary. The wrapping zlib stream parser uses this to
/// locate the 4-byte Adler-32 checksum exactly where the encoder placed it
/// — `data.length() - 4` is wrong whenever the producer appended extra
/// padding bytes after the checksum (a common quirk of CID-font ToUnicode
/// CMaps emitted by Acrobat-derived pipelines, where a stray EOL byte
/// after the deflate body makes the trailing-4-bytes heuristic point one
/// byte past the real Adler-32 and corrupt the entire document).
fn decode_deflate_with_position(
  data : Bytes,
) -> (Bytes, Int) raise PdfFilterError {
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
  (Bytes::from_array(output), reader.byte_position())
}

///|
/// Decodes a FlateDecode zlib stream and applies optional DecodeParms predictors.
pub fn decode_flate_with_params(
  data : Bytes,
  params : DecodeParams,
) -> Bytes raise PdfFilterError {
  let decoded = decode_zlib_stream(data)
  apply_predictor("FlateDecode", decoded, params)
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
