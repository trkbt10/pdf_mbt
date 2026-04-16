///|
#external
type JSUint8Array

///|
fn uint8array_length(arr : JSUint8Array) -> Int = "pdf" "uint8array_length"

///|
fn uint8array_get(arr : JSUint8Array, index : Int) -> Int = "pdf" "uint8array_get"

///|
fn uint8array_new(length : Int) -> JSUint8Array = "pdf" "uint8array_new"

///|
fn uint8array_set(arr : JSUint8Array, index : Int, value : Int) -> Unit = "pdf" "uint8array_set"

///|
let documents : Map[Int, @pdfapi.PdfDocument] = Map::new()

///|
let contexts : Map[Int, @context.PdfContext] = Map::new()

///|
priv struct HandleCounter {
  mut value : Int
}

///|
let document_counter : HandleCounter = { value: 1 }

///|
let context_counter : HandleCounter = { value: 1 }

///|
pub fn pdf_open(data : JSUint8Array) -> Int {
  let bytes = uint8array_to_bytes(data)
  let result : Result[@pdfapi.PdfDocument, @reader.PdfDocumentError] = try? @pdfapi.open(
    bytes,
  )
  match result {
    Ok(document) => {
      let handle = next_document_handle()
      documents[handle] = document
      handle
    }
    Err(_) => -1
  }
}

///|
pub fn pdf_page_count(handle : Int) -> Int {
  match documents.get(handle) {
    Some(document) => {
      let result : Result[Int, @reader.PdfDocumentError] = try? document.page_count()
      match result {
        Ok(count) => count
        Err(_) => -1
      }
    }
    None => -1
  }
}

///|
pub fn pdf_extract_text(handle : Int, page : Int) -> String {
  match get_page(handle, page) {
    Some(pdf_page) => pdf_page.extract_text()
    None => ""
  }
}

///|
pub fn pdf_extract_text_layout(handle : Int, page : Int) -> String {
  match get_page(handle, page) {
    Some(pdf_page) => pdf_page.extract_text_layout()
    None => ""
  }
}

///|
pub fn pdf_page_images_count(handle : Int, page : Int) -> Int {
  match get_page(handle, page) {
    Some(pdf_page) => pdf_page.images().length()
    None => -1
  }
}

///|
pub fn pdf_image_rgba(handle : Int, page : Int, index : Int) -> JSUint8Array {
  match get_image(handle, page, index) {
    Some(image) => bytes_to_uint8array(image.to_rgba())
    None => bytes_to_uint8array(b"")
  }
}

///|
pub fn pdf_image_width(handle : Int, page : Int, index : Int) -> Int {
  match get_image(handle, page, index) {
    Some(image) => image.width()
    None => -1
  }
}

///|
pub fn pdf_image_height(handle : Int, page : Int, index : Int) -> Int {
  match get_image(handle, page, index) {
    Some(image) => image.height()
    None => -1
  }
}

///|
pub fn pdf_info_json(handle : Int) -> String {
  match documents.get(handle) {
    Some(document) => document_info_json(document)
    None => "{\"error\":\"invalid document handle\"}"
  }
}

///|
pub fn pdf_check_json(handle : Int) -> String {
  match documents.get(handle) {
    Some(document) => {
      let result : Result[@pdfapi.PdfCapabilityReport, @reader.PdfDocumentError] = try? document.check()
      match result {
        Ok(report) => capability_report_json(report)
        Err(_) => "{\"error\":\"failed to build capability report\"}"
      }
    }
    None => "{\"error\":\"invalid document handle\"}"
  }
}

///|
pub fn pdf_close(handle : Int) -> Unit {
  documents.remove(handle)
}

///|
pub fn ctx_new() -> Int {
  let handle = next_context_handle()
  contexts[handle] = @context.PdfContext::new()
  handle
}

///|
pub fn ctx_from_document(handle : Int) -> Int {
  match documents.get(handle) {
    Some(document) => {
      let result : Result[@context.PdfContext, @context.PdfContextError] = try? @context.PdfContext::from_document(
        document.reader_document(),
      )
      match result {
        Ok(context) => {
          let context_handle = next_context_handle()
          contexts[context_handle] = context
          context_handle
        }
        Err(_) => -1
      }
    }
    None => -1
  }
}

///|
pub fn ctx_add_page(ctx : Int, width : Double, height : Double) -> Int {
  match contexts.get(ctx) {
    Some(context) => context.add_page(width, height).object_number
    None => -1
  }
}

///|
pub fn ctx_set_title(ctx : Int, title : String) -> Unit {
  match contexts.get(ctx) {
    Some(context) => context.set_title(@utf8.encode(title))
    None => ()
  }
}

///|
pub fn ctx_to_bytes(ctx : Int) -> JSUint8Array {
  match contexts.get(ctx) {
    Some(context) => bytes_to_uint8array(context.to_bytes())
    None => bytes_to_uint8array(b"")
  }
}

///|
pub fn ctx_close(ctx : Int) -> Unit {
  contexts.remove(ctx)
}

///|
fn next_document_handle() -> Int {
  let handle = document_counter.value
  document_counter.value = document_counter.value + 1
  handle
}

///|
fn next_context_handle() -> Int {
  let handle = context_counter.value
  context_counter.value = context_counter.value + 1
  handle
}

///|
fn uint8array_to_bytes(data : JSUint8Array) -> Bytes {
  let length = uint8array_length(data)
  Bytes::makei(length, fn(i) { uint8array_get(data, i).to_byte() })
}

///|
fn bytes_to_uint8array(bytes : Bytes) -> JSUint8Array {
  let out = uint8array_new(bytes.length())
  for i in 0..<bytes.length() {
    uint8array_set(out, i, bytes[i].to_int())
  }
  out
}

///|
fn get_page(handle : Int, page : Int) -> @pdfapi.PdfPage? {
  match documents.get(handle) {
    Some(document) => {
      let result : Result[@pdfapi.PdfPage, @reader.PdfDocumentError] = try? document.page(
        page,
      )
      match result {
        Ok(pdf_page) => Some(pdf_page)
        Err(_) => None
      }
    }
    None => None
  }
}

///|
fn get_image(handle : Int, page : Int, index : Int) -> @pdfapi.PdfImage? {
  match get_page(handle, page) {
    Some(pdf_page) => {
      let images = pdf_page.images()
      if index >= 0 && index < images.length() {
        Some(images[index])
      } else {
        None
      }
    }
    None => None
  }
}

///|
fn document_info_json(document : @pdfapi.PdfDocument) -> String {
  let builder = StringBuilder::new()
  builder.write_string("{")
  builder.write_string("\"pageCount\":")
  builder.write_string(pdf_page_count_for_json(document).to_string())
  builder.write_string(",\"title\":")
  builder.write_string(json_string_option(document.title()))
  builder.write_string(",\"author\":")
  builder.write_string(json_string_option(document.author()))
  builder.write_string(",\"subject\":")
  builder.write_string(json_string_option(document.subject()))
  builder.write_string(",\"creator\":")
  builder.write_string(json_string_option(document.creator()))
  builder.write_string("}")
  builder.to_string()
}

///|
fn pdf_page_count_for_json(document : @pdfapi.PdfDocument) -> Int {
  let result : Result[Int, @reader.PdfDocumentError] = try? document.page_count()
  match result {
    Ok(count) => count
    Err(_) => -1
  }
}

///|
fn capability_report_json(report : @pdfapi.PdfCapabilityReport) -> String {
  let builder = StringBuilder::new()
  builder.write_string("{\"entries\":[")
  for index in 0..<report.entries.length() {
    if index > 0 {
      builder.write_string(",")
    }
    capability_entry_json(builder, report.entries[index])
  }
  builder.write_string("]}")
  builder.to_string()
}

///|
fn capability_entry_json(
  builder : StringBuilder,
  entry : @pdfapi.PdfCapabilityEntry,
) -> Unit {
  builder.write_string("{\"featureName\":")
  builder.write_string(json_string(entry.feature_name))
  builder.write_string(",\"category\":")
  builder.write_string(json_string(entry.category))
  builder.write_string(",\"status\":")
  builder.write_string(json_string(capability_status_text(entry.status)))
  builder.write_string(",\"description\":")
  builder.write_string(json_string(entry.description))
  builder.write_string("}")
}

///|
fn capability_status_text(status : @pdfapi.PdfCapabilityStatus) -> String {
  match status {
    Supported => "supported"
    Partial => "partial"
    Unsupported => "unsupported"
    Unused => "unused"
  }
}

///|
fn json_string_option(value : String?) -> String {
  match value {
    Some(text) => json_string(text)
    None => "null"
  }
}

///|
fn json_string(value : String) -> String {
  let builder = StringBuilder::new()
  builder.write_char('"')
  for char in value {
    match char {
      '"' => builder.write_string("\\\"")
      '\\' => builder.write_string("\\\\")
      '\n' => builder.write_string("\\n")
      '\r' => builder.write_string("\\r")
      '\t' => builder.write_string("\\t")
      _ => builder.write_char(char)
    }
  }
  builder.write_char('"')
  builder.to_string()
}

///|
fn keep_requested_imports_alive() -> Unit {
  let spans : Array[@text.TextSpan] = []
  @layout.layout_text_spans(spans) |> ignore
  let colour_space : @graphics.ColourSpace? = None
  colour_space |> ignore
  let object_id : @objects.ObjectId? = None
  object_id |> ignore
}

///|
fn main {
  keep_requested_imports_alive()
}
