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
fn helvetica_font_dictionary() -> @objects.PdfDictionary {
  let dict : @objects.PdfDictionary = Map::new()
  dict[pdf_key(b"Type")] = Name(pdf_key(b"Font"))
  dict[pdf_key(b"Subtype")] = Name(pdf_key(b"Type1"))
  dict[pdf_key(b"BaseFont")] = Name(pdf_key(b"Helvetica"))
  dict
}

///|
fn pdf_key(bytes : Bytes) -> @objects.PdfName {
  @objects.PdfName::new(bytes)
}
