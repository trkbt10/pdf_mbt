///|
pub fn PdfContext::to_bytes(self : PdfContext) -> Bytes {
  let header = version_header(self.version)
  let objects = self.indirect_objects(dirty_only=false)
  let (body, xref_entries) = serialize_object_body(
    header,
    0L,
    objects,
    compress_streams=self.compress_streams,
  )
  let xref_offset = body.length().to_int64()
  let trailer = PdfContextTrailerSpec::new(
    max_object_number(objects) + 1,
    self.catalog_ref,
    None,
    self.info_ref,
    self.file_id,
  )
  body +
  serialize_xref_section(xref_entries, trailer) +
  b"startxref\r\n" +
  decimal_bytes(xref_offset) +
  b"\r\n%%EOF\r\n"
}

///|
pub fn PdfContext::to_incremental_bytes(
  self : PdfContext,
  original : Bytes,
) -> Bytes raise PdfContextError {
  let file = try @reader.PdfFile::open(original) catch {
    error => raise PdfContextError::ReaderError(error)
  } noraise {
    file => file
  }
  let previous_trailer = file.trailer()
  let header_base = find_header_base(original)
  let previous_xref = find_latest_startxref(original)
  let objects = self.indirect_objects(dirty_only=true)
  let prefix = original + b"\r\n"
  let (body, xref_entries) = serialize_object_body(
    prefix,
    header_base,
    objects,
    compress_streams=self.compress_streams,
  )
  let xref_offset = body.length().to_int64() - header_base
  let trailer = PdfContextTrailerSpec::new(
    max_int(
      previous_trailer.size,
      max_object_number(self.indirect_objects(dirty_only=false)) + 1,
    ),
    self.catalog_ref,
    Some(previous_xref),
    self.info_ref,
    self.file_id,
  )
  body +
  serialize_xref_section(xref_entries, trailer) +
  b"startxref\r\n" +
  decimal_bytes(xref_offset) +
  b"\r\n%%EOF\r\n"
}

///|
pub fn serialize_object(object : @objects.PdfObject) -> Bytes {
  serialize_object_with_options(object, compress_streams=false)
}

///|
pub fn serialize_indirect_object(object : @objects.IndirectObject) -> Bytes {
  serialize_indirect_object_with_options(object, compress_streams=false)
}

///|
fn PdfContext::indirect_objects(
  self : PdfContext,
  dirty_only~ : Bool,
) -> Array[@objects.IndirectObject] {
  let numbers = sorted_object_numbers(self.objects)
  let objects : Array[@objects.IndirectObject] = []
  for object_number in numbers {
    if !dirty_only || self.dirty_objects.contains(object_number) {
      match self.objects.get(object_number) {
        Some(value) =>
          objects.push(@objects.IndirectObject::{
            id: @objects.ObjectId::{
              object_number,
              generation_number: self.generation_for(object_number),
            },
            value,
            start_offset: 0L,
            end_offset: 0L,
          })
        None => ()
      }
    }
  }
  objects
}

///|
fn serialize_object_body(
  prefix : Bytes,
  header_base : Int64,
  objects : Array[@objects.IndirectObject],
  compress_streams~ : Bool,
) -> (Bytes, Array[PdfContextXrefEntry]) {
  let mut bytes = prefix
  let entries : Array[PdfContextXrefEntry] = []
  for object in objects {
    let offset = bytes.length().to_int64() - header_base
    entries.push(PdfContextXrefEntry::new(object.id, offset))
    bytes = bytes +
      serialize_indirect_object_with_options(object, compress_streams~)
  }
  (bytes, entries)
}

///|
fn serialize_indirect_object_with_options(
  object : @objects.IndirectObject,
  compress_streams~ : Bool,
) -> Bytes {
  decimal_bytes(object.id.object_number.to_int64()) +
  b" " +
  decimal_bytes(object.id.generation_number.to_int64()) +
  b" obj\r\n" +
  serialize_object_with_options(object.value, compress_streams~) +
  b"\r\nendobj\r\n"
}

///|
fn serialize_object_with_options(
  object : @objects.PdfObject,
  compress_streams~ : Bool,
) -> Bytes {
  match object {
    @objects.PdfObject::Boolean(value) => if value { b"true" } else { b"false" }
    @objects.PdfObject::Integer(value) => decimal_bytes(value)
    @objects.PdfObject::Real(value) => serialize_real(value)
    @objects.PdfObject::String(value) => serialize_literal_string(value)
    @objects.PdfObject::Name(value) => serialize_name(value)
    @objects.PdfObject::Array(values) =>
      serialize_array(values, compress_streams~)
    @objects.PdfObject::Dictionary(dict) =>
      serialize_dictionary(dict, compress_streams~)
    @objects.PdfObject::Stream(stream) =>
      serialize_stream(stream, compress_streams~)
    @objects.PdfObject::Null => b"null"
    @objects.PdfObject::Ref(id) =>
      decimal_bytes(id.object_number.to_int64()) +
      b" " +
      decimal_bytes(id.generation_number.to_int64()) +
      b" R"
  }
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
fn serialize_array(
  values : Array[@objects.PdfObject],
  compress_streams~ : Bool,
) -> Bytes {
  let out : Array[Byte] = []
  out.push(b'[')
  let mut first = true
  for value in values {
    if first {
      first = false
    } else {
      out.push(b' ')
    }
    out.append(
      serialize_object_with_options(value, compress_streams~).to_array(),
    )
  }
  out.push(b']')
  Bytes::from_array(out)
}

///|
fn serialize_dictionary(
  dict : @objects.PdfDictionary,
  compress_streams~ : Bool,
) -> Bytes {
  let out : Array[Byte] = []
  out.append(b"<<".to_array())
  for entry in dict.to_array() {
    let (key, value) = entry
    out.push(b' ')
    out.append(serialize_name(key).to_array())
    out.push(b' ')
    out.append(
      serialize_object_with_options(value, compress_streams~).to_array(),
    )
  }
  if dict.to_array().length() > 0 {
    out.push(b' ')
  }
  out.append(b">>".to_array())
  Bytes::from_array(out)
}

///|
fn serialize_stream(
  stream : @objects.PdfStream,
  compress_streams~ : Bool,
) -> Bytes {
  let prepared = prepare_stream(stream, compress_streams~)
  let dict = stream_dictionary_with_length(prepared)
  serialize_dictionary(dict, compress_streams=false) +
  b"\r\nstream\r\n" +
  prepared.data +
  b"\r\nendstream"
}

///|
fn prepare_stream(
  stream : @objects.PdfStream,
  compress_streams~ : Bool,
) -> @objects.PdfStream {
  if compress_streams && !stream.dict.contains(pdf_key(b"Filter")) {
    let dict = clone_dictionary(stream.dict)
    dict[pdf_key(b"Filter")] = @objects.PdfObject::Name(pdf_key(b"FlateDecode"))
    @objects.PdfStream::{ dict, data: encode_flate_stored(stream.data) }
  } else {
    stream
  }
}

///|
fn stream_dictionary_with_length(
  stream : @objects.PdfStream,
) -> @objects.PdfDictionary {
  let dict = clone_dictionary(stream.dict)
  dict[pdf_key(b"Length")] = @objects.PdfObject::Integer(
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

///|
priv struct PdfContextTrailerSpec {
  size : Int
  root : @objects.ObjectId
  prev : Int64?
  info : @objects.ObjectId?
  file_id : PdfContextFileId?
} derive(Eq, Debug)

///|
priv struct PdfContextXrefEntry {
  id : @objects.ObjectId
  offset : Int64
} derive(Eq, Debug)

///|
fn PdfContextXrefEntry::new(
  id : @objects.ObjectId,
  offset : Int64,
) -> PdfContextXrefEntry {
  PdfContextXrefEntry::{ id, offset }
}

///|
fn PdfContextTrailerSpec::new(
  size : Int,
  root : @objects.ObjectId,
  prev : Int64?,
  info : @objects.ObjectId?,
  file_id : PdfContextFileId?,
) -> PdfContextTrailerSpec {
  PdfContextTrailerSpec::{ size, root, prev, info, file_id }
}

///|
fn serialize_xref_section(
  entries : Array[PdfContextXrefEntry],
  trailer : PdfContextTrailerSpec,
) -> Bytes {
  let size = max_trailer_size(entries, trailer.size)
  let body : Array[Byte] = []
  body.append(b"xref\r\n".to_array())
  body.append(decimal_bytes(0L).to_array())
  body.push(b' ')
  body.append(decimal_bytes(1L).to_array())
  body.append(b"\r\n".to_array())
  body.append(xref_entry_line(0L, 65535, b'f').to_array())
  for entry in entries {
    if entry.id.object_number != 0 {
      body.append(decimal_bytes(entry.id.object_number.to_int64()).to_array())
      body.push(b' ')
      body.append(decimal_bytes(1L).to_array())
      body.append(b"\r\n".to_array())
      body.append(
        xref_entry_line(entry.offset, entry.id.generation_number, b'n').to_array(),
      )
    }
  }
  body.append(b"trailer\r\n".to_array())
  body.append(
    serialize_object_with_options(
      @objects.PdfObject::Dictionary(trailer_dictionary(size, trailer)),
      compress_streams=false,
    ).to_array(),
  )
  body.append(b"\r\n".to_array())
  Bytes::from_array(body)
}

///|
fn trailer_dictionary(
  size : Int,
  trailer : PdfContextTrailerSpec,
) -> @objects.PdfDictionary {
  let dict : @objects.PdfDictionary = Map::new()
  dict[pdf_key(b"Size")] = @objects.PdfObject::Integer(size.to_int64())
  dict[pdf_key(b"Root")] = @objects.PdfObject::Ref(trailer.root)
  match trailer.prev {
    Some(offset) => dict[pdf_key(b"Prev")] = @objects.PdfObject::Integer(offset)
    None => ()
  }
  match trailer.info {
    Some(info_ref) => dict[pdf_key(b"Info")] = @objects.PdfObject::Ref(info_ref)
    None => ()
  }
  match trailer.file_id {
    Some(id) =>
      dict[pdf_key(b"ID")] = @objects.PdfObject::Array([
        @objects.PdfObject::String(id.first),
        @objects.PdfObject::String(id.second),
      ])
    None => ()
  }
  dict
}

///|
fn max_trailer_size(
  entries : Array[PdfContextXrefEntry],
  declared : Int,
) -> Int {
  let mut size = declared
  for entry in entries {
    let candidate = entry.id.object_number + 1
    if candidate > size {
      size = candidate
    }
  }
  size
}

///|
fn xref_entry_line(
  next_or_offset : Int64,
  generation : Int,
  marker : Byte,
) -> Bytes {
  fixed_width_decimal(next_or_offset, 10) +
  b" " +
  fixed_width_decimal(generation.to_int64(), 5) +
  b" " +
  Bytes::from_array([marker, b'\r', b'\n'])
}

///|
fn fixed_width_decimal(value : Int64, width : Int) -> Bytes {
  let digits = decimal_bytes(value)
  let out : Array[Byte] = []
  let mut padding = width - digits.length()
  while padding > 0 {
    out.push(b'0')
    padding = padding - 1
  }
  for digit in digits {
    out.push(digit)
  }
  Bytes::from_array(out)
}

///|
fn decimal_bytes(value : Int64) -> Bytes {
  if value < 0L {
    b"-" + positive_decimal_bytes(0L - value)
  } else {
    positive_decimal_bytes(value)
  }
}

///|
fn positive_decimal_bytes(value : Int64) -> Bytes {
  let digits : Array[Byte] = []
  let mut current = value
  if current == 0L {
    digits.push(b'0')
  } else {
    while current > 0L {
      let digit = (current % 10L).to_int()
      digits.push((b'0'.to_int() + digit).to_byte())
      current = current / 10L
    }
  }

  let out : Array[Byte] = []
  let mut index = digits.length() - 1
  while index >= 0 {
    out.push(digits[index])
    index = index - 1
  }
  Bytes::from_array(out)
}

///|
fn text_bytes(text : String) -> Bytes {
  @utf8.encode(text.to_string_view())
}

///|
fn version_header(version : @reader.PdfVersion) -> Bytes {
  b"%PDF-" +
  decimal_bytes(version.major.to_int64()) +
  b"." +
  decimal_bytes(version.minor.to_int64()) +
  b"\r\n%\x80\x80\x80\x80\r\n"
}

///|
fn sorted_object_numbers(objects : Map[Int, @objects.PdfObject]) -> Array[Int] {
  let numbers : Array[Int] = []
  for entry in objects.to_array() {
    let (number, _) = entry
    insert_sorted_int(numbers, number)
  }
  numbers
}

///|
fn insert_sorted_int(numbers : Array[Int], value : Int) -> Unit {
  numbers.push(value)
  let mut index = numbers.length() - 1
  while index > 0 && numbers[index - 1] > value {
    numbers[index] = numbers[index - 1]
    index = index - 1
  }
  numbers[index] = value
}

///|
fn max_object_number(objects : Array[@objects.IndirectObject]) -> Int {
  let mut max_number = 0
  for object in objects {
    if object.id.object_number > max_number {
      max_number = object.id.object_number
    }
  }
  max_number
}

///|
fn encode_flate_stored(data : Bytes) -> Bytes {
  let out : Array[Byte] = []
  out.push(b'\x78')
  out.push(b'\x01')
  append_stored_deflate_blocks(out, data)
  append_u32_be(out, adler32(data))
  Bytes::from_array(out)
}

///|
fn append_stored_deflate_blocks(out : Array[Byte], data : Bytes) -> Unit {
  let mut offset = 0
  while offset < data.length() || offset == 0 {
    let remaining = data.length() - offset
    let length = if remaining > 65535 { 65535 } else { remaining }
    let final_block = offset + length >= data.length()
    out.push(if final_block { b'\x01' } else { b'\x00' })
    append_u16_le(out, length)
    append_u16_le(out, 0xffff ^ length)
    for index in offset..<(offset + length) {
      out.push(data[index])
    }
    offset = offset + length
    if data.length() == 0 {
      break
    }
  }
}

///|
fn append_u16_le(out : Array[Byte], value : Int) -> Unit {
  out.push((value & 0xff).to_byte())
  out.push(((value >> 8) & 0xff).to_byte())
}

///|
fn append_u32_be(out : Array[Byte], value : Int64) -> Unit {
  out.push(((value >> 24) & 0xffL).to_byte())
  out.push(((value >> 16) & 0xffL).to_byte())
  out.push(((value >> 8) & 0xffL).to_byte())
  out.push((value & 0xffL).to_byte())
}

///|
fn adler32(data : Bytes) -> Int64 {
  let modulus = 65521L
  let mut s1 = 1L
  let mut s2 = 0L
  for byte in data {
    s1 = (s1 + byte.to_int64()) % modulus
    s2 = (s2 + s1) % modulus
  }
  (s2 << 16) | s1
}

///|
fn find_latest_startxref(bytes : Bytes) -> Int64 raise PdfContextError {
  match bytes.rev_find(b"startxref") {
    Some(index) => parse_startxref_value(bytes, index + b"startxref".length())
    None =>
      raise PdfContextError::ReaderError(
        @reader.PdfReaderError::MissingTailMarker("startxref keyword not found"),
      )
  }
}

///|
fn parse_startxref_value(
  bytes : Bytes,
  start : Int,
) -> Int64 raise PdfContextError {
  let mut index = skip_pdf_whitespace(bytes, start)
  let value_start = index
  let mut value = 0L
  while index < bytes.length() && bytes[index] >= b'0' && bytes[index] <= b'9' {
    value = value * 10L + (bytes[index].to_int64() - b'0'.to_int64())
    index += 1
  }
  if index == value_start {
    raise PdfContextError::ReaderError(
      @reader.PdfReaderError::InvalidXref(
        start.to_int64(),
        "startxref must be followed by a decimal offset",
      ),
    )
  }
  value
}

///|
fn find_header_base(bytes : Bytes) -> Int64 {
  match bytes.find(b"%PDF-") {
    Some(index) => index.to_int64()
    None => 0L
  }
}

///|
fn skip_pdf_whitespace(bytes : Bytes, start : Int) -> Int {
  let mut index = start
  while index < bytes.length() && is_pdf_whitespace(bytes[index]) {
    index += 1
  }
  index
}

///|
fn is_pdf_whitespace(byte : Byte) -> Bool {
  byte == b'\x00' ||
  byte == b'\t' ||
  byte == b'\n' ||
  byte == b'\x0c' ||
  byte == b'\r' ||
  byte == b' '
}

///|
fn max_int(left : Int, right : Int) -> Int {
  if left > right {
    left
  } else {
    right
  }
}
