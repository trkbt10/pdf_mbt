///|
/// Object serialization coverage marker. The writer SHALL serialize all PDF
/// object types to valid PDF syntax: booleans, integers, real numbers, strings
/// (literal and hex), names, arrays, dictionaries, streams, and indirect
/// references.
priv struct PdfObjectSerialization {
  covered : Bool
}

///|
/// Serializes booleans, integers, real numbers, literal strings, names,
/// arrays, dictionaries, streams, nulls, and indirect references to valid PDF
/// object syntax.
pub fn serialize_object(object : @objects.PdfObject) -> Bytes {
  match object {
    Boolean(value) => if value { b"true" } else { b"false" }
    Integer(value) => decimal_bytes(value)
    Real(value) => serialize_real(value)
    String(value) => serialize_literal_string(value)
    Name(value) => serialize_name(value)
    Array(values) => serialize_array(values)
    Dictionary(dict) => serialize_dictionary(dict)
    Stream(stream) => serialize_stream(stream)
    Null => b"null"
    Ref(id) =>
      decimal_bytes(id.object_number.to_int64()) +
      b" " +
      decimal_bytes(id.generation_number.to_int64()) +
      b" R"
  }
}

///|
/// Serializes a modified indirect object in standard PDF syntax:
/// object number, generation number, obj, object body, and endobj.
pub fn serialize_indirect_object(object : @objects.IndirectObject) -> Bytes {
  decimal_bytes(object.id.object_number.to_int64()) +
  b" " +
  decimal_bytes(object.id.generation_number.to_int64()) +
  b" obj\r\n" +
  serialize_object(object.value) +
  b"\r\nendobj\r\n"
}

///|
fn serialize_literal_string(bytes : Bytes) -> Bytes {
  let out : Array[Byte] = []
  out.push(b'(')
  for byte in bytes {
    append_literal_string_byte(out, byte)
  }
  out.push(b')')
  Bytes::from_array(out)
}

///|
fn serialize_hex_string(bytes : Bytes) -> Bytes {
  let out : Array[Byte] = []
  out.push(b'<')
  for byte in bytes {
    out.push(hex_digit(byte.to_int() >> 4))
    out.push(hex_digit(byte.to_int() & 0x0f))
  }
  out.push(b'>')
  Bytes::from_array(out)
}

///|
fn serialize_real(value : Double) -> Bytes {
  if value.is_nan() || value.is_inf() {
    b"0"
  } else {
    let text = value.to_string()
    if text.contains("e") || text.contains("E") {
      text_bytes(value.to_int64().to_string())
    } else {
      text_bytes(text)
    }
  }
}

///|
fn serialize_array(values : Array[@objects.PdfObject]) -> Bytes {
  let out : Array[Byte] = []
  out.push(b'[')
  let mut first = true
  for value in values {
    if first {
      first = false
    } else {
      out.push(b' ')
    }
    out.append(serialize_object(value).to_array())
  }
  out.push(b']')
  Bytes::from_array(out)
}

///|
fn serialize_dictionary(dict : @objects.PdfDictionary) -> Bytes {
  let out : Array[Byte] = []
  out.append(b"<<".to_array())
  for entry in dict.to_array() {
    let (key, value) = entry
    out.push(b' ')
    out.append(serialize_name(key).to_array())
    out.push(b' ')
    out.append(serialize_object(value).to_array())
  }
  if dict.to_array().length() > 0 {
    out.push(b' ')
  }
  out.append(b">>".to_array())
  Bytes::from_array(out)
}

///|
fn serialize_stream(stream : @objects.PdfStream) -> Bytes {
  let dict = stream_dictionary_with_length(stream)
  serialize_dictionary(dict) +
  b"\r\nstream\r\n" +
  stream.data +
  b"\r\nendstream"
}

///|
fn stream_dictionary_with_length(
  stream : @objects.PdfStream,
) -> @objects.PdfDictionary {
  let dict : @objects.PdfDictionary = Map::new()
  for entry in stream.dict.to_array() {
    let (key, value) = entry
    dict[key] = value
  }
  dict[@objects.PdfName::new(b"Length")] = Integer(
    stream.data.length().to_int64(),
  )
  dict
}

///|
fn serialize_name(name : @objects.PdfName) -> Bytes {
  let out : Array[Byte] = []
  out.push(b'/')
  for byte in name.bytes {
    if is_regular_name_byte(byte) {
      out.push(byte)
    } else {
      out.push(b'#')
      out.push(hex_digit(byte.to_int() >> 4))
      out.push(hex_digit(byte.to_int() & 0x0f))
    }
  }
  Bytes::from_array(out)
}

///|
fn append_literal_string_byte(out : Array[Byte], byte : Byte) -> Unit {
  match byte {
    b'(' => {
      out.push(b'\\')
      out.push(b'(')
    }
    b')' => {
      out.push(b'\\')
      out.push(b')')
    }
    b'\\' => {
      out.push(b'\\')
      out.push(b'\\')
    }
    b'\n' => {
      out.push(b'\\')
      out.push(b'n')
    }
    b'\r' => {
      out.push(b'\\')
      out.push(b'r')
    }
    b'\t' => {
      out.push(b'\\')
      out.push(b't')
    }
    b'\x08' => {
      out.push(b'\\')
      out.push(b'b')
    }
    b'\x0c' => {
      out.push(b'\\')
      out.push(b'f')
    }
    _ => out.push(byte)
  }
}

///|
fn is_regular_name_byte(byte : Byte) -> Bool {
  let value = byte.to_int()
  value > 0x20 &&
  value < 0x7f &&
  byte != b'#' &&
  byte != b'(' &&
  byte != b')' &&
  byte != b'<' &&
  byte != b'>' &&
  byte != b'[' &&
  byte != b']' &&
  byte != b'{' &&
  byte != b'}' &&
  byte != b'/' &&
  byte != b'%'
}

///|
fn hex_digit(value : Int) -> Byte {
  if value < 10 {
    (b'0'.to_int() + value).to_byte()
  } else {
    (b'A'.to_int() + value - 10).to_byte()
  }
}
