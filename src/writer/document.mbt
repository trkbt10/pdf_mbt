///|
pub fn create_pdf(content : Bytes) -> Bytes {
  create_page_pdf(content, compress_streams=false)
}

///|
pub fn create_compressed_pdf(content : Bytes) -> Bytes {
  create_page_pdf(content, compress_streams=true)
}

///|
fn create_page_pdf(content : Bytes, compress_streams~ : Bool) -> Bytes {
  let objects = create_page_objects(content, compress_streams~)
  serialize_new_document(objects, default_file_id())
}

///|
fn create_text_pdf(text : Bytes) -> Bytes {
  create_pdf(text_content(text))
}

///|
fn serialize_new_document(
  objects : Array[@objects.IndirectObject],
  file_id : PdfWriterFileId,
) -> Bytes {
  let header = b"%PDF-2.0\r\n%\x80\x80\x80\x80\r\n"
  let (body, xref_entries) = serialize_object_body(header, 0L, objects)
  let xref_offset = body.length().to_int64()
  let trailer = PdfTrailerSpec::new(
    max_object_number(objects) + 1,
    @objects.ObjectId::{ object_number: 1, generation_number: 0 },
    None,
    Some(file_id),
  )
  body +
  serialize_xref_section(xref_entries, trailer) +
  b"startxref\r\n" +
  decimal_bytes(xref_offset) +
  b"\r\n%%EOF\r\n"
}

///|
fn serialize_object_body(
  prefix : Bytes,
  header_base : Int64,
  objects : Array[@objects.IndirectObject],
) -> (Bytes, Array[PdfXrefEntry]) {
  let mut bytes = prefix
  let entries : Array[PdfXrefEntry] = []
  for object in objects {
    let offset = bytes.length().to_int64() - header_base
    entries.push(PdfXrefEntry::new(object.id, offset))
    bytes = bytes + serialize_indirect_object(object)
  }
  (bytes, entries)
}

///|
fn create_page_objects(
  content : Bytes,
  compress_streams~ : Bool,
) -> Array[@objects.IndirectObject] {
  [
    writer_object(1, 0, Dictionary(catalog_dictionary())),
    writer_object(2, 0, Dictionary(pages_dictionary())),
    writer_object(3, 0, Dictionary(page_dictionary())),
    writer_object(4, 0, Dictionary(helvetica_font_dictionary())),
    writer_object(5, 0, Stream(content_stream(content, compress_streams~))),
  ]
}

///|
fn catalog_dictionary() -> @objects.PdfDictionary {
  let dict : @objects.PdfDictionary = Map::new()
  dict[pdf_key(b"Type")] = Name(pdf_key(b"Catalog"))
  dict[pdf_key(b"Pages")] = Ref(@objects.ObjectId::{
    object_number: 2,
    generation_number: 0,
  })
  dict
}

///|
fn pages_dictionary() -> @objects.PdfDictionary {
  let dict : @objects.PdfDictionary = Map::new()
  dict[pdf_key(b"Type")] = Name(pdf_key(b"Pages"))
  dict[pdf_key(b"Kids")] = Array([
    Ref(@objects.ObjectId::{ object_number: 3, generation_number: 0 }),
  ])
  dict[pdf_key(b"Count")] = Integer(1L)
  dict
}

///|
fn page_dictionary() -> @objects.PdfDictionary {
  let dict : @objects.PdfDictionary = Map::new()
  dict[pdf_key(b"Type")] = Name(pdf_key(b"Page"))
  dict[pdf_key(b"Parent")] = Ref(@objects.ObjectId::{
    object_number: 2,
    generation_number: 0,
  })
  dict[pdf_key(b"MediaBox")] = Array([
    Integer(0L),
    Integer(0L),
    Integer(612L),
    Integer(792L),
  ])
  dict[pdf_key(b"Resources")] = Dictionary(page_resources_dictionary())
  dict[pdf_key(b"Contents")] = Ref(@objects.ObjectId::{
    object_number: 5,
    generation_number: 0,
  })
  dict
}

///|
fn page_resources_dictionary() -> @objects.PdfDictionary {
  let resources : @objects.PdfDictionary = Map::new()
  let fonts : @objects.PdfDictionary = Map::new()
  fonts[pdf_key(b"F1")] = Ref(@objects.ObjectId::{
    object_number: 4,
    generation_number: 0,
  })
  resources[pdf_key(b"Font")] = Dictionary(fonts)
  resources
}

///|
fn helvetica_font_dictionary() -> @objects.PdfDictionary {
  let dict : @objects.PdfDictionary = Map::new()
  dict[pdf_key(b"Type")] = Name(pdf_key(b"Font"))
  dict[pdf_key(b"Subtype")] = Name(pdf_key(b"Type1"))
  dict[pdf_key(b"BaseFont")] = Name(pdf_key(b"Helvetica"))
  dict
}

///|
fn content_stream(
  content : Bytes,
  compress_streams~ : Bool,
) -> @objects.PdfStream {
  let dict : @objects.PdfDictionary = Map::new()
  let data = if compress_streams {
    dict[pdf_key(b"Filter")] = Name(pdf_key(b"FlateDecode"))
    encode_flate_stored(content)
  } else {
    content
  }
  @objects.PdfStream::{ dict, data }
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
fn default_file_id() -> PdfWriterFileId {
  PdfWriterFileId::{
    first: b"moonbit-pdf-writer-id-0000000001",
    second: b"moonbit-pdf-writer-id-0000000001",
  }
}

///|
fn writer_object(
  object_number : Int,
  generation_number : Int,
  value : @objects.PdfObject,
) -> @objects.IndirectObject {
  @objects.IndirectObject::{
    id: @objects.ObjectId::{ object_number, generation_number },
    value,
    start_offset: 0L,
    end_offset: 0L,
  }
}

///|
fn pdf_key(bytes : Bytes) -> @objects.PdfName {
  @objects.PdfName::new(bytes)
}
