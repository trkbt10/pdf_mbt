///|
test "decode_ascii85 handles complete five-character groups" {
  let encoded = Bytes::from_array([b'!', b'!', b'!', b'!', b'u', b'~', b'>'])
  let decoded = decode_ascii85(encoded)
  assert_eq(decoded, Bytes::from_array([b'\x00', b'\x00', b'\x00', b'T']))
}

///|
test "decode_ascii85 expands z as a complete zero group" {
  let encoded = Bytes::from_array([b'z', b'~', b'>'])
  let decoded = decode_ascii85(encoded)
  assert_eq(decoded, Bytes::from_array([b'\x00', b'\x00', b'\x00', b'\x00']))
}

///|
test "decode_ascii85 pads a final partial group with u" {
  let encoded = Bytes::from_array([b'!', b'!', b'!', b'!', b'~', b'>'])
  let decoded = decode_ascii85(encoded)
  assert_eq(decoded, Bytes::from_array([b'\x00', b'\x00', b'\x00']))
}

///|
test "decode_ascii85 ignores whitespace and stops at the end marker" {
  let encoded = Bytes::from_array([
    b'!', b' ', b'\n', b'!', b'\t', b'!', b'\r', b'!', b' ', b'u', b'~', b'>', b'X',
    b'Y',
  ])
  let decoded = decode_ascii85(encoded)
  assert_eq(decoded, Bytes::from_array([b'\x00', b'\x00', b'\x00', b'T']))
}

///|
test "decode_ascii85 rejects impossible base85 values" {
  let encoded = Bytes::from_array([b'u', b'u', b'u', b'u', b'u', b'~', b'>'])
  let decoded : Result[Bytes, PdfFilterError] = try? decode_ascii85(encoded)
  match decoded {
    Err(DecodeError(filter_name, reason)) => {
      assert_eq(filter_name, "ASCII85Decode")
      assert_eq(reason.contains("range"), true)
    }
    _ => fail("expected impossible ASCII85 value to fail")
  }
}

///|
test "decode_ascii85 rejects z inside a partial group" {
  let encoded = Bytes::from_array([b'!', b'z', b'~', b'>'])
  let decoded : Result[Bytes, PdfFilterError] = try? decode_ascii85(encoded)
  match decoded {
    Err(DecodeError(filter_name, reason)) => {
      assert_eq(filter_name, "ASCII85Decode")
      assert_eq(reason.contains("z"), true)
    }
    _ => fail("expected misplaced z to fail")
  }
}

///|
test "decode_ascii85 rejects malformed terminators" {
  let dangling : Result[Bytes, PdfFilterError] = try? decode_ascii85(
    Bytes::from_array([b'!', b'~']),
  )
  match dangling {
    Err(DecodeError(filter_name, reason)) => {
      assert_eq(filter_name, "ASCII85Decode")
      assert_eq(reason.contains("~>"), true)
    }
    _ => fail("expected dangling tilde to fail")
  }

  let bad_follow : Result[Bytes, PdfFilterError] = try? decode_ascii85(
    Bytes::from_array([b'!', b'!', b'~', b'x']),
  )
  match bad_follow {
    Err(DecodeError(filter_name, reason)) => {
      assert_eq(filter_name, "ASCII85Decode")
      assert_eq(reason.contains("~>"), true)
    }
    _ => fail("expected malformed terminator sequence to fail")
  }
}

///|
test "decode_ascii85 rejects a complete group without a terminator" {
  let decoded : Result[Bytes, PdfFilterError] = try? decode_ascii85(
    Bytes::from_array([b'!', b'!', b'!', b'!', b'!']),
  )
  match decoded {
    Err(DecodeError(filter_name, reason)) => {
      assert_eq(filter_name, "ASCII85Decode")
      assert_eq(reason.contains("~>"), true)
    }
    _ => fail("expected complete ASCII85 group without terminator to fail")
  }
}

///|
test "decode_ascii85 rejects z without a terminator" {
  let decoded : Result[Bytes, PdfFilterError] = try? decode_ascii85(
    Bytes::from_array([b'z']),
  )
  match decoded {
    Err(DecodeError(filter_name, reason)) => {
      assert_eq(filter_name, "ASCII85Decode")
      assert_eq(reason.contains("~>"), true)
    }
    _ => fail("expected ASCII85 z without terminator to fail")
  }
}
