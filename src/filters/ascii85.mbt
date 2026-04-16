///|
/// Decodes an ASCII85Decode stream, requiring the PDF `~>` end marker.
pub fn decode_ascii85(data : Bytes) -> Bytes raise PdfFilterError {
  let output : Array[Byte] = []
  let mut index = 0
  let mut group_len = 0
  let mut group_value : Int64 = 0L

  while index < data.length() {
    let byte = data[index]
    if is_pdf_ascii85_white_space(byte) {
      ()
    } else if byte == b'z' {
      if group_len != 0 {
        raise PdfFilterError::DecodeError(
          "ASCII85Decode", "z abbreviation is only allowed between complete groups",
        )
      }
      output.push(b'\x00')
      output.push(b'\x00')
      output.push(b'\x00')
      output.push(b'\x00')
    } else if byte == b'~' {
      return decode_ascii85_terminated(
        data, index, group_len, group_value, output,
      )
    } else if byte >= b'!' && byte <= b'u' {
      group_value = group_value * 85L + (byte.to_int64() - b'!'.to_int64())
      group_len = group_len + 1
      if group_len == 5 {
        decode_ascii85_group(group_value, output)
        group_len = 0
        group_value = 0L
      }
    } else {
      raise PdfFilterError::DecodeError("ASCII85Decode", "invalid ASCII85 byte")
    }
    index = index + 1
  }

  raise PdfFilterError::DecodeError(
    "ASCII85Decode", "ASCII85 data must end with ~>",
  )
}

///|
fn decode_ascii85_terminated(
  data : Bytes,
  tilde_index : Int,
  group_len : Int,
  group_value : Int64,
  output : Array[Byte],
) -> Bytes raise PdfFilterError {
  if tilde_index + 1 >= data.length() || data[tilde_index + 1] != b'>' {
    raise PdfFilterError::DecodeError(
      "ASCII85Decode", "ASCII85 data must terminate with ~>",
    )
  }

  if group_len == 0 {
    return Bytes::from_array(output)
  }

  if group_len == 1 {
    raise PdfFilterError::DecodeError(
      "ASCII85Decode", "final ASCII85 group must contain 2 to 4 characters",
    )
  }

  let mut padded_value = group_value
  let mut padded_len = group_len
  while padded_len < 5 {
    padded_value = padded_value * 85L + 84L
    padded_len = padded_len + 1
  }

  if is_ascii85_impossible(padded_value) {
    raise PdfFilterError::DecodeError(
      "ASCII85Decode", "base85 value exceeds 32-bit range",
    )
  }

  decode_ascii85_value(padded_value, group_len - 1, output)
  Bytes::from_array(output)
}

///|
fn decode_ascii85_group(
  group_value : Int64,
  output : Array[Byte],
) -> Unit raise PdfFilterError {
  if is_ascii85_impossible(group_value) {
    raise PdfFilterError::DecodeError(
      "ASCII85Decode", "base85 value exceeds 32-bit range",
    )
  }
  decode_ascii85_value(group_value, 4, output)
}

///|
fn decode_ascii85_value(
  value : Int64,
  byte_count : Int,
  output : Array[Byte],
) -> Unit {
  let first = (value / 16777216L).to_byte()
  let second = (value / 65536L % 256L).to_byte()
  let third = (value / 256L % 256L).to_byte()
  let fourth = (value % 256L).to_byte()

  if byte_count >= 1 {
    output.push(first)
  }
  if byte_count >= 2 {
    output.push(second)
  }
  if byte_count >= 3 {
    output.push(third)
  }
  if byte_count >= 4 {
    output.push(fourth)
  }
}

///|
fn is_ascii85_impossible(value : Int64) -> Bool {
  value > 4294967295L
}

///|
fn is_pdf_ascii85_white_space(byte : Byte) -> Bool {
  match byte {
    b'\x00' | b'\t' | b'\n' | b'\x0c' | b'\r' | b' ' => true
    _ => false
  }
}
