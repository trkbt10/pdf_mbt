///|
test "decode_run_length copies literal runs" {
  let encoded = Bytes::from_array([b'\x03', b'A', b'B', b'C', b'D', b'\x80'])
  let decoded = decode_run_length(encoded)
  assert_eq(decoded, Bytes::from_array([b'A', b'B', b'C', b'D']))
}

///|
test "decode_run_length expands repeated-byte runs" {
  let encoded = Bytes::from_array([b'\xfe', b'Z', b'\x80'])
  let decoded = decode_run_length(encoded)
  assert_eq(decoded, Bytes::from_array([b'Z', b'Z', b'Z']))
}

///|
test "decode_run_length expands large repeated-byte runs" {
  let encoded = Bytes::from_array([b'\x81', b'Q', b'\x80'])
  let decoded = decode_run_length(encoded)

  let expected : Array[Byte] = []
  let mut index = 0
  while index < 128 {
    expected.push(b'Q')
    index = index + 1
  }

  assert_eq(decoded, Bytes::from_array(expected))
}

///|
test "decode_run_length stops at the end marker" {
  let encoded = Bytes::from_array([
    b'\x00', b'A', b'\x80', b'\x03', b'B', b'C', b'D', b'E',
  ])
  let decoded = decode_run_length(encoded)
  assert_eq(decoded, Bytes::from_array([b'A']))
}

///|
test "decode_run_length rejects truncated literal runs" {
  let encoded : Result[Bytes, PdfFilterError] = try? decode_run_length(
    Bytes::from_array([b'\x02', b'A', b'B']),
  )
  match encoded {
    Err(DecodeError(filter_name, reason)) => {
      assert_eq(filter_name, "RunLengthDecode")
      assert_eq(reason.contains("literal"), true)
    }
    _ => fail("expected truncated literal run to fail")
  }
}

///|
test "decode_run_length rejects truncated repeated runs" {
  let encoded : Result[Bytes, PdfFilterError] = try? decode_run_length(
    Bytes::from_array([b'\x82']),
  )
  match encoded {
    Err(DecodeError(filter_name, reason)) => {
      assert_eq(filter_name, "RunLengthDecode")
      assert_eq(reason.contains("repeat"), true)
    }
    _ => fail("expected truncated repeated run to fail")
  }
}
