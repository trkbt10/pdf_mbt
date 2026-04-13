///|
test "decode_deflate decodes a single stored block" {
  let data = Bytes::from_array([
    b'\x01', b'\x03', b'\x00', b'\xfc', b'\xff', b'a', b'b', b'c',
  ])

  let decoded : Result[Bytes, PdfFilterError] = try? decode_deflate(data)
  match decoded {
    Ok(bytes) => assert_eq(bytes, Bytes::from_array([b'a', b'b', b'c']))
    _ => fail("expected a single stored block to decode")
  }
}

///|
test "decode_deflate decodes multiple stored blocks and honors the final marker" {
  let data = Bytes::from_array([
    b'\x00', b'\x02', b'\x00', b'\xfd', b'\xff', b'a', b'b', b'\x01', b'\x01', b'\x00',
    b'\xfe', b'\xff', b'c',
  ])

  let decoded : Result[Bytes, PdfFilterError] = try? decode_deflate(data)
  match decoded {
    Ok(bytes) => assert_eq(bytes, Bytes::from_array([b'a', b'b', b'c']))
    _ => fail("expected stored blocks to decode across block boundaries")
  }
}

///|
test "decode_deflate rejects invalid stored block length pairs" {
  let data = Bytes::from_array([
    b'\x01', b'\x03', b'\x00', b'\x00', b'\xff', b'a', b'b', b'c',
  ])

  let decoded : Result[Bytes, PdfFilterError] = try? decode_deflate(data)
  match decoded {
    Err(DecodeError(filter_name, reason)) => {
      assert_eq(filter_name, "FlateDecode")
      assert_eq(reason.contains("length"), true)
    }
    _ => fail("expected mismatched LEN/NLEN values to be rejected")
  }
}

///|
test "decode_deflate rejects truncated stored block payloads" {
  let data = Bytes::from_array([
    b'\x01', b'\x03', b'\x00', b'\xfc', b'\xff', b'a', b'b',
  ])

  let decoded : Result[Bytes, PdfFilterError] = try? decode_deflate(data)
  match decoded {
    Err(DecodeError(filter_name, reason)) => {
      assert_eq(filter_name, "FlateDecode")
      assert_eq(reason.contains("truncated"), true)
    }
    _ => fail("expected truncated stored block payload to fail")
  }
}

///|
test "decode_deflate decodes a fixed Huffman block of literals" {
  let data = Bytes::from_array([b'\x73', b'\x74', b'\x72', b'\x06', b'\x00'])

  let decoded : Result[Bytes, PdfFilterError] = try? decode_deflate(data)
  match decoded {
    Ok(bytes) => assert_eq(bytes, Bytes::from_array([b'A', b'B', b'C']))
    _ => fail("expected fixed Huffman literal output to decode")
  }
}

///|
test "decode_zlib_stored accepts non-zero unused final-byte bits after a fixed Huffman block" {
  let data = Bytes::from_array([
    b'\x78', b'\x9c', b'\x73', b'\x74', b'\x72', b'\x06', b'\x80', b'\x01', b'\x8d',
    b'\x00', b'\xc7',
  ])

  let decoded : Result[Bytes, PdfFilterError] = try? decode_zlib_stored(data)
  match decoded {
    Ok(bytes) => assert_eq(bytes, Bytes::from_array([b'A', b'B', b'C']))
    _ => fail("expected non-zero unused final-byte bits to be ignored")
  }
}

///|
test "decode_deflate rejects whole trailing bytes after the final fixed block" {
  let data = Bytes::from_array([
    b'\x73', b'\x74', b'\x72', b'\x06', b'\x80', b'\x00',
  ])

  let decoded : Result[Bytes, PdfFilterError] = try? decode_deflate(data)
  match decoded {
    Err(DecodeError(filter_name, reason)) => {
      assert_eq(filter_name, "FlateDecode")
      assert_eq(reason.contains("trailing"), true)
    }
    _ => fail("expected trailing whole bytes to be rejected")
  }
}

///|
test "decode_deflate decodes a fixed Huffman block with distance copies" {
  let data = Bytes::from_array([
    b'\x4b', b'\x4c', b'\x4a', b'\x4e', b'\x84', b'\x21', b'\x00',
  ])

  let decoded : Result[Bytes, PdfFilterError] = try? decode_deflate(data)
  match decoded {
    Ok(bytes) =>
      assert_eq(
        bytes,
        Bytes::from_array([
          b'a', b'b', b'c', b'a', b'b', b'c', b'a', b'b', b'c', b'a', b'b', b'c',
        ]),
      )
    _ => fail("expected fixed Huffman distance copies to decode")
  }
}

///|
test "decode_deflate rejects a reserved fixed Huffman length code" {
  let data = Bytes::from_array([b'\x1b', b'\x03'])

  let decoded : Result[Bytes, PdfFilterError] = try? decode_deflate(data)
  match decoded {
    Err(DecodeError(filter_name, reason)) => {
      assert_eq(filter_name, "FlateDecode")
      assert_eq(reason.contains("reserved"), true)
    }
    _ => fail("expected reserved length code to fail")
  }
}

///|
test "decode_deflate rejects distance references before any output exists" {
  let data = Bytes::from_array([b'\x03', b'\x02'])

  let decoded : Result[Bytes, PdfFilterError] = try? decode_deflate(data)
  match decoded {
    Err(DecodeError(filter_name, reason)) => {
      assert_eq(filter_name, "FlateDecode")
      assert_eq(reason.contains("distance"), true)
    }
    _ => fail("expected invalid distance reference to fail")
  }
}

///|
test "decode_deflate rejects a reserved fixed Huffman distance code" {
  let data = Bytes::from_array([b'\x73', b'\x04', b'\x3e'])

  let decoded : Result[Bytes, PdfFilterError] = try? decode_deflate(data)
  match decoded {
    Err(DecodeError(filter_name, reason)) => {
      assert_eq(filter_name, "FlateDecode")
      assert_eq(reason.contains("reserved"), true)
    }
    _ => fail("expected reserved distance code to fail")
  }
}

///|
test "decode_zlib_stored returns stored-block bytes only after checksum verification" {
  let data = Bytes::from_array([
    b'\x78', b'\x01', b'\x01', b'\x03', b'\x00', b'\xfc', b'\xff', b'a', b'b', b'c',
    b'\x02', b'M', b'\x01', b'\'',
  ])

  let decoded : Result[Bytes, PdfFilterError] = try? decode_zlib_stored(data)
  match decoded {
    Ok(bytes) => assert_eq(bytes, Bytes::from_array([b'a', b'b', b'c']))
    _ => fail("expected zlib-wrapped stored blocks to decode")
  }
}

///|
test "decode_zlib_stored rejects checksum mismatches after stored block decoding" {
  let data = Bytes::from_array([
    b'\x78', b'\x01', b'\x01', b'\x03', b'\x00', b'\xfc', b'\xff', b'a', b'b', b'c',
    b'\x02', b'M', b'\x01', b'(',
  ])

  let decoded : Result[Bytes, PdfFilterError] = try? decode_zlib_stored(data)
  match decoded {
    Err(DecodeError(filter_name, reason)) => {
      assert_eq(filter_name, "FlateDecode")
      assert_eq(reason.contains("checksum"), true)
    }
    _ => fail("expected checksum mismatches to be rejected")
  }
}

///|
test "lsb bit reader returns deterministic least-significant-bit-first values" {
  let reader = LsbBitReader::new(Bytes::from_array([b'\x6d', b'\x3a']))

  assert_eq(reader.read_bits(3), 5)
  assert_eq(reader.read_bits(5), 13)
  assert_eq(reader.read_bits(4), 10)
  assert_eq(reader.read_bits(4), 3)
}

///|
test "lsb bit reader can align to the next byte boundary" {
  let reader = LsbBitReader::new(Bytes::from_array([b'\x6d', b'\x3a']))

  assert_eq(reader.read_bits(3), 5)
  reader.align_to_byte()
  assert_eq(reader.read_bits(8), 58)
}

///|
test "parse_zlib_stream accepts a minimal empty zlib stream" {
  let stream = Bytes::from_array([
    b'\x78', b'\x01', b'\x01', b'\x00', b'\x00', b'\xff', b'\xff', b'\x00', b'\x00',
    b'\x00', b'\x01',
  ])

  let parsed : Result[ZlibStream, PdfFilterError] = try? parse_zlib_stream(
    stream,
  )
  match parsed {
    Ok(zlib) => {
      assert_eq(
        zlib.deflate_data,
        Bytes::from_array([b'\x01', b'\x00', b'\x00', b'\xff', b'\xff']),
      )
      assert_eq(zlib.expected_adler32, 1L)
    }
    _ => fail("expected valid zlib header and checksum layout")
  }
}

///|
test "parse_zlib_stream rejects an invalid compression method" {
  let stream = Bytes::from_array([
    b'\x70', b'\x01', b'\x01', b'\x00', b'\x00', b'\xff', b'\xff', b'\x00', b'\x00',
    b'\x00', b'\x01',
  ])
  let parsed : Result[ZlibStream, PdfFilterError] = try? parse_zlib_stream(
    stream,
  )
  match parsed {
    Err(DecodeError(filter_name, reason)) => {
      assert_eq(filter_name, "FlateDecode")
      assert_eq(reason.contains("method"), true)
    }
    _ => fail("expected invalid zlib compression method to fail")
  }
}

///|
test "parse_zlib_stream rejects an invalid window size" {
  let stream = Bytes::from_array([
    b'\x88', b'\x1c', b'\x01', b'\x00', b'\x00', b'\xff', b'\xff', b'\x00', b'\x00',
    b'\x00', b'\x01',
  ])
  let parsed : Result[ZlibStream, PdfFilterError] = try? parse_zlib_stream(
    stream,
  )
  match parsed {
    Err(DecodeError(filter_name, reason)) => {
      assert_eq(filter_name, "FlateDecode")
      assert_eq(reason.contains("window"), true)
    }
    _ => fail("expected invalid zlib window size to fail")
  }
}

///|
test "parse_zlib_stream rejects invalid header check bits" {
  let stream = Bytes::from_array([
    b'\x78', b'\x00', b'\x01', b'\x00', b'\x00', b'\xff', b'\xff', b'\x00', b'\x00',
    b'\x00', b'\x01',
  ])
  let parsed : Result[ZlibStream, PdfFilterError] = try? parse_zlib_stream(
    stream,
  )
  match parsed {
    Err(DecodeError(filter_name, reason)) => {
      assert_eq(filter_name, "FlateDecode")
      assert_eq(reason.contains("check"), true)
    }
    _ => fail("expected invalid zlib header check bits to fail")
  }
}

///|
test "parse_zlib_stream rejects preset dictionary streams" {
  let stream = Bytes::from_array([
    b'\x78', b'\x20', b'\x01', b'\x00', b'\x00', b'\xff', b'\xff', b'\x00', b'\x00',
    b'\x00', b'\x01',
  ])
  let parsed : Result[ZlibStream, PdfFilterError] = try? parse_zlib_stream(
    stream,
  )
  match parsed {
    Err(DecodeError(filter_name, reason)) => {
      assert_eq(filter_name, "FlateDecode")
      assert_eq(reason.contains("dictionary"), true)
    }
    _ => fail("expected preset dictionary streams to be rejected")
  }
}

///|
test "parse_zlib_stream rejects truncated payloads" {
  let stream = Bytes::from_array([b'\x78', b'\x01', b'\x01', b'\x00', b'\x00'])
  let parsed : Result[ZlibStream, PdfFilterError] = try? parse_zlib_stream(
    stream,
  )
  match parsed {
    Err(DecodeError(filter_name, reason)) => {
      assert_eq(filter_name, "FlateDecode")
      assert_eq(reason.contains("truncated"), true)
    }
    _ => fail("expected truncated zlib payload to fail")
  }
}

///|
test "adler32 computes and validates checksums" {
  let decoded = Bytes::from_array([b'a', b'b', b'c'])
  assert_eq(adler32(decoded), 0x024d0127L)

  let ok : Result[Unit, PdfFilterError] = try? validate_adler32(
    "FlateDecode", decoded, 0x024d0127L,
  )
  match ok {
    Ok(_) => ()
    _ => fail("expected matching Adler-32 to validate")
  }

  let bad : Result[Unit, PdfFilterError] = try? validate_adler32(
    "FlateDecode", decoded, 0x024d0128L,
  )
  match bad {
    Err(DecodeError(filter_name, reason)) => {
      assert_eq(filter_name, "FlateDecode")
      assert_eq(reason.contains("Adler"), true)
    }
    _ => fail("expected checksum mismatch to fail")
  }
}
