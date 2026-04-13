///|
fn decode_run_length(data : Bytes) -> Bytes raise PdfFilterError {
  let output : Array[Byte] = []
  let mut index = 0

  while index < data.length() {
    let length = data[index].to_int()
    index = index + 1

    if length == 128 {
      break
    } else if length <= 127 {
      let run_length = length + 1
      if index + run_length > data.length() {
        raise PdfFilterError::DecodeError(
          "RunLengthDecode", "truncated literal run",
        )
      }

      let mut copied = 0
      while copied < run_length {
        output.push(data[index + copied])
        copied = copied + 1
      }
      index = index + run_length
    } else {
      let repeat_count = 257 - length
      if index >= data.length() {
        raise PdfFilterError::DecodeError(
          "RunLengthDecode", "truncated repeat run",
        )
      }

      let repeated_byte = data[index]
      index = index + 1

      let mut repeated = 0
      while repeated < repeat_count {
        output.push(repeated_byte)
        repeated = repeated + 1
      }
    }
  }

  Bytes::from_array(output)
}
