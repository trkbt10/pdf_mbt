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
priv struct RenderImageResource {
  stream : @objects.PdfStream
  resources : @objects.PdfDictionary?
}

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
pub fn pdf_page_render_json(handle : Int, page : Int) -> String {
  match get_page(handle, page) {
    Some(pdf_page) => page_render_json(pdf_page)
    None => "{\"error\":\"invalid page handle\"}"
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
fn page_render_json(page : @pdfapi.PdfPage) -> String {
  let builder = StringBuilder::new()
  builder.write_string("{\"width\":")
  builder.write_string(page.width().to_string())
  builder.write_string(",\"height\":")
  builder.write_string(page.height().to_string())
  builder.write_string(",\"texts\":[")
  page_render_texts_json(builder, page)
  builder.write_string("],\"images\":[")
  page_render_images_json(builder, page)
  builder.write_string("]}")
  builder.to_string()
}

///|
fn page_render_texts_json(
  builder : StringBuilder,
  page : @pdfapi.PdfPage,
) -> Unit {
  let result : Result[@text.TextProgram, @reader.PdfDocumentError] = try? page
    .reader_page()
    .text_program(@reader.TextPageOptions::default())
  match result {
    Ok(program) => {
      let font_sizes = text_program_font_sizes(program)
      let mut written = 0
      for index in 0..<program.spans.length() {
        let span = program.spans[index]
        if span.text.length() > 0 {
          if written > 0 {
            builder.write_string(",")
          }
          page_render_text_json(
            builder,
            span,
            span_font_size(font_sizes, index),
          )
          written += 1
        }
      }
    }
    Err(_) => ()
  }
}

///|
fn page_render_text_json(
  builder : StringBuilder,
  span : @text.TextSpan,
  font_size : Double,
) -> Unit {
  builder.write_string("{\"text\":")
  builder.write_string(json_string(span.text))
  builder.write_string(",\"x\":")
  builder.write_string(span.text_matrix.e.to_string())
  builder.write_string(",\"y\":")
  builder.write_string(span.text_matrix.f.to_string())
  builder.write_string(",\"fontSize\":")
  builder.write_string(font_size.to_string())
  builder.write_string(",\"fontName\":")
  builder.write_string(
    json_string_option(span.font_name.map(fn(name) { name.to_text() })),
  )
  builder.write_string("}")
}

///|
fn text_program_font_sizes(program : @text.TextProgram) -> Array[Double] {
  let sizes : Array[Double] = []
  let mut saw_glyph = false
  for event in program.events {
    match event {
      SourceString(_) => saw_glyph = false
      GlyphShown(glyph) =>
        if !saw_glyph {
          sizes.push(text_rendering_font_size(glyph.rendering_matrix.matrix))
          saw_glyph = true
        }
      _ => ()
    }
  }
  sizes
}

///|
fn text_rendering_font_size(matrix : @text.TextMatrix) -> Double {
  let size = matrix.a.abs().max(matrix.d.abs())
  if size > 0.0 {
    size
  } else {
    12.0
  }
}

///|
fn span_font_size(font_sizes : Array[Double], index : Int) -> Double {
  if index >= 0 && index < font_sizes.length() {
    font_sizes[index]
  } else {
    12.0
  }
}

///|
fn page_render_images_json(
  builder : StringBuilder,
  page : @pdfapi.PdfPage,
) -> Unit {
  let resources_result : Result[
    @content.ContentResources,
    @reader.PdfDocumentError,
  ] = try? page.reader_page().materialized_content_resources()
  let events_result : Result[
    Array[@graphics.GraphicsEvent],
    @reader.PdfDocumentError,
  ] = try? page
    .reader_page()
    .graphics_events(
      @reader.GraphicsPageOptions::with_materialized_xobjects(None),
    )
  match (resources_result, events_result) {
    (Ok(resources), Ok(events)) => {
      let mut written = 0
      for event in events {
        match event {
          ImagePainted(offset, descriptor, state) => {
            let image = render_image_data(resources, offset, descriptor, state)
            match image {
              Some(json) => {
                if written > 0 {
                  builder.write_string(",")
                }
                builder.write_string(json)
                written += 1
              }
              None => ()
            }
          }
          _ => ()
        }
      }
    }
    _ => ()
  }
}

///|
fn render_image_data(
  resources : @content.ContentResources,
  offset : Int64,
  descriptor : @graphics.ImageDescriptor,
  state : @graphics.GraphicsState,
) -> String? {
  match image_resource_for_descriptor(resources, descriptor) {
    Some(resource) => {
      let stream = prepare_render_image_stream(
        resource.stream,
        resource.resources,
      )
      let extracted_result : Result[
        @graphics.ExtractedImage,
        @graphics.PdfGraphicsError,
      ] = try? @graphics.extract_image_xobject(
        image_descriptor_name(descriptor),
        stream,
        offset,
      )
      match extracted_result {
        Ok(extracted) => {
          let rgba = extracted_image_rgba(extracted.data)
          if rgba.length() > 0 {
            Some(render_image_json(descriptor, state, rgba))
          } else {
            None
          }
        }
        Err(_) => None
      }
    }
    None => None
  }
}

///|
fn render_image_json(
  descriptor : @graphics.ImageDescriptor,
  state : @graphics.GraphicsState,
  rgba : Bytes,
) -> String {
  let bounds = @graphics.GraphicsRect::new(0.0, 0.0, 1.0, 1.0).transform_bounds(
    state.ctm,
  )
  let builder = StringBuilder::new()
  builder.write_string("{\"x\":")
  builder.write_string(bounds.left.to_string())
  builder.write_string(",\"y\":")
  builder.write_string(bounds.bottom.to_string())
  builder.write_string(",\"width\":")
  builder.write_string((bounds.right - bounds.left).abs().to_string())
  builder.write_string(",\"height\":")
  builder.write_string((bounds.top - bounds.bottom).abs().to_string())
  builder.write_string(",\"pixelWidth\":")
  builder.write_string(descriptor.width.to_string())
  builder.write_string(",\"pixelHeight\":")
  builder.write_string(descriptor.height.to_string())
  builder.write_string(",\"rgbaBase64\":")
  builder.write_string(json_string(base64_encode(rgba)))
  builder.write_string("}")
  builder.to_string()
}

///|
fn image_resource_for_descriptor(
  resources : @content.ContentResources,
  descriptor : @graphics.ImageDescriptor,
) -> RenderImageResource? {
  match image_descriptor_name(descriptor) {
    Some(name) => find_image_resource(resources.dictionary, name)
    None => None
  }
}

///|
fn image_descriptor_name(
  descriptor : @graphics.ImageDescriptor,
) -> @objects.PdfName? {
  match descriptor.source {
    XObjectImage(name) => name
    InlineImageSource => None
  }
}

///|
fn find_image_resource(
  resources : @objects.PdfDictionary?,
  name : @objects.PdfName,
) -> RenderImageResource? {
  match resources {
    Some(dictionary) => find_image_resource_in_dictionary(dictionary, name)
    None => None
  }
}

///|
fn find_image_resource_in_dictionary(
  resources : @objects.PdfDictionary,
  name : @objects.PdfName,
) -> RenderImageResource? {
  match resources.get(@objects.PdfName::new(b"XObject")) {
    Some(@objects.PdfObject::Dictionary(xobjects)) =>
      match find_named_image_resource(xobjects, resources, name) {
        Some(resource) => Some(resource)
        None => find_nested_image_resource(xobjects, resources, name)
      }
    _ => None
  }
}

///|
fn find_named_image_resource(
  xobjects : @objects.PdfDictionary,
  resources : @objects.PdfDictionary,
  name : @objects.PdfName,
) -> RenderImageResource? {
  match xobjects.get(name) {
    Some(@objects.PdfObject::Stream(stream)) if stream_subtype_is(
        stream, b"Image",
      ) => Some(RenderImageResource::{ stream, resources: Some(resources) })
    _ => None
  }
}

///|
fn find_nested_image_resource(
  xobjects : @objects.PdfDictionary,
  resources : @objects.PdfDictionary,
  name : @objects.PdfName,
) -> RenderImageResource? {
  for _, object in xobjects {
    match object {
      @objects.PdfObject::Stream(stream) if stream_subtype_is(stream, b"Form") => {
        let nested = match
          stream.dict.get(@objects.PdfName::new(b"Resources")) {
          Some(@objects.PdfObject::Dictionary(form_resources)) =>
            find_image_resource_in_dictionary(form_resources, name)
          _ => find_image_resource_in_dictionary(resources, name)
        }
        match nested {
          Some(resource) => return Some(resource)
          None => ()
        }
      }
      _ => ()
    }
  }
  None
}

///|
fn prepare_render_image_stream(
  stream : @objects.PdfStream,
  resources : @objects.PdfDictionary?,
) -> @objects.PdfStream {
  let dict = stream.dict.copy()
  materialize_render_resource_entry(dict, resources, b"ColorSpace")
  @objects.PdfStream::{ dict, data: stream.data }
}

///|
fn materialize_render_resource_entry(
  dict : @objects.PdfDictionary,
  resources : @objects.PdfDictionary?,
  key_bytes : Bytes,
) -> Unit {
  let key = @objects.PdfName::new(key_bytes)
  match (dict.get(key), resources) {
    (Some(@objects.PdfObject::Name(name)), Some(resource_dict)) =>
      match resource_dict.get(key) {
        Some(@objects.PdfObject::Dictionary(named_resources)) =>
          match named_resources.get(name) {
            Some(value) => dict[key] = value
            None => ()
          }
        _ => ()
      }
    _ => ()
  }
}

///|
fn stream_subtype_is(stream : @objects.PdfStream, expected : Bytes) -> Bool {
  match stream.dict.get(@objects.PdfName::new(b"Subtype")) {
    Some(@objects.PdfObject::Name(name)) =>
      name == @objects.PdfName::new(expected)
    _ => false
  }
}

///|
fn extracted_image_rgba(data : @graphics.ExtractedImageData) -> Bytes {
  match data {
    DeviceRgbRaster(raster) => raster.rgba
    StencilMaskRaster(mask) => stencil_mask_to_rgba(mask)
    EncodedImageData(_, _) => b""
  }
}

///|
fn stencil_mask_to_rgba(mask : @graphics.ImageAlphaMaskRaster) -> Bytes {
  let rgba : Array[Byte] = []
  for alpha in mask.alpha {
    rgba.push(0x00)
    rgba.push(0x00)
    rgba.push(0x00)
    rgba.push(alpha)
  }
  Bytes::from_array(rgba)
}

///|
fn base64_encode(bytes : Bytes) -> String {
  let builder = StringBuilder::new()
  let mut index = 0
  while index < bytes.length() {
    let byte0 = bytes[index].to_int()
    let has_byte1 = index + 1 < bytes.length()
    let has_byte2 = index + 2 < bytes.length()
    let byte1 = if has_byte1 { bytes[index + 1].to_int() } else { 0 }
    let byte2 = if has_byte2 { bytes[index + 2].to_int() } else { 0 }
    builder.write_char(base64_char(byte0 / 4))
    builder.write_char(base64_char(byte0 % 4 * 16 + byte1 / 16))
    if has_byte1 {
      builder.write_char(base64_char(byte1 % 16 * 4 + byte2 / 64))
    } else {
      builder.write_char('=')
    }
    if has_byte2 {
      builder.write_char(base64_char(byte2 % 64))
    } else {
      builder.write_char('=')
    }
    index += 3
  }
  builder.to_string()
}

///|
fn base64_char(index : Int) -> Char {
  if index < 26 {
    (65 + index).to_byte().to_char()
  } else if index < 52 {
    (97 + index - 26).to_byte().to_char()
  } else if index < 62 {
    (48 + index - 52).to_byte().to_char()
  } else if index == 62 {
    '+'
  } else {
    '/'
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
