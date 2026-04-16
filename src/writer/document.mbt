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
  let context = @context.PdfContext::new()
  context.set_stream_compression(compress_streams)
  let page_ref = context.add_page(612.0, 792.0)
  let font_result : Result[@objects.ObjectId, @context.PdfContextError] = try? context.add_font(
    page_ref,
    pdf_key(b"F1"),
    Dictionary(helvetica_font_dictionary()),
  )
  match font_result {
    Ok(_) => ()
    Err(_) => ()
  }
  let content_result : Result[@objects.ObjectId, @context.PdfContextError] = try? context.set_page_content(
    page_ref, content,
  )
  match content_result {
    Ok(_) => ()
    Err(_) => ()
  }
  context.to_bytes()
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
fn helvetica_font_dictionary() -> @objects.PdfDictionary {
  let dict : @objects.PdfDictionary = Map::new()
  dict[pdf_key(b"Type")] = Name(pdf_key(b"Font"))
  dict[pdf_key(b"Subtype")] = Name(pdf_key(b"Type1"))
  dict[pdf_key(b"BaseFont")] = Name(pdf_key(b"Helvetica"))
  dict
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
fn pdf_key(bytes : Bytes) -> @objects.PdfName {
  @objects.PdfName::new(bytes)
}
