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
priv struct PageImageEntry {
  name : @objects.PdfName?
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
pub fn pdf_page_geometry_json(handle : Int, page : Int) -> String {
  match get_page(handle, page) {
    Some(pdf_page) => page_geometry_json(pdf_page)
    None => "{\"error\":\"invalid page handle\"}"
  }
}

///|
pub fn pdf_page_text_positions_json(handle : Int, page : Int) -> String {
  match get_page(handle, page) {
    Some(pdf_page) => page_text_positions_json(pdf_page)
    None => "{\"error\":\"invalid page handle\"}"
  }
}

///|
pub fn pdf_page_to_svg(handle : Int, page : Int) -> String {
  match get_page(handle, page) {
    Some(pdf_page) => page_to_svg(pdf_page)
    None => ""
  }
}

///|
pub fn pdf_page_image_count(handle : Int, page : Int) -> Int {
  match get_page(handle, page) {
    Some(pdf_page) => page_image_entries(pdf_page).length()
    None => -1
  }
}

///|
pub fn pdf_page_image_info_json(
  handle : Int,
  page : Int,
  index : Int,
) -> String {
  match get_page_image_entry(handle, page, index) {
    Some(entry) => page_image_info_json(entry)
    None => "{\"error\":\"invalid image handle\"}"
  }
}

///|
pub fn pdf_page_image_rgba(
  handle : Int,
  page : Int,
  index : Int,
) -> JSUint8Array {
  match get_page_image_entry(handle, page, index) {
    Some(entry) => bytes_to_uint8array(page_image_rgba(entry))
    None => bytes_to_uint8array(b"")
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
fn get_page_image_entry(
  handle : Int,
  page : Int,
  index : Int,
) -> PageImageEntry? {
  match get_page(handle, page) {
    Some(pdf_page) => {
      let entries = page_image_entries(pdf_page)
      if index >= 0 && index < entries.length() {
        Some(entries[index])
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
fn page_geometry_json(page : @pdfapi.PdfPage) -> String {
  let builder = StringBuilder::new()
  builder.write_string("{\"width\":")
  builder.write_string(page.width().to_string())
  builder.write_string(",\"height\":")
  builder.write_string(page.height().to_string())
  builder.write_string(",\"rotation\":")
  builder.write_string(page_rotation(page).to_string())
  builder.write_string("}")
  builder.to_string()
}

///|
fn page_rotation(page : @pdfapi.PdfPage) -> Int {
  let result : Result[Int?, @reader.PdfDocumentError] = try? page
    .reader_page()
    .rotate()
  match result {
    Ok(Some(value)) => positive_mod(value, 360)
    _ => 0
  }
}

///|
fn page_text_positions_json(page : @pdfapi.PdfPage) -> String {
  let builder = StringBuilder::new()
  builder.write_string("{\"texts\":[")
  page_render_texts_json(builder, page)
  builder.write_string("]}")
  builder.to_string()
}

///|
fn page_to_svg(page : @pdfapi.PdfPage) -> String {
  let width = page.width()
  let height = page.height()
  let builder = StringBuilder::new()
  builder.write_string(
    "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 ",
  )
  builder.write_string(width.to_string())
  builder.write_string(" ")
  builder.write_string(height.to_string())
  builder.write_string("\" width=\"")
  builder.write_string(width.to_string())
  builder.write_string("\" height=\"")
  builder.write_string(height.to_string())
  builder.write_string("\">")
  builder.write_string("<rect x=\"0\" y=\"0\" width=\"")
  builder.write_string(width.to_string())
  builder.write_string("\" height=\"")
  builder.write_string(height.to_string())
  builder.write_string("\" fill=\"#ffffff\"/>")
  builder.write_string("<g transform=\"scale(1,-1) translate(0,-")
  builder.write_string(height.to_string())
  builder.write_string(")\">")
  page_render_graphics_svg(builder, page)
  page_render_texts_svg(builder, page)
  builder.write_string("</g></svg>")
  builder.to_string()
}

///|
fn positive_mod(value : Int, base : Int) -> Int {
  let result = value % base
  if result < 0 {
    result + base
  } else {
    result
  }
}

///|
fn page_render_graphics_svg(
  builder : StringBuilder,
  page : @pdfapi.PdfPage,
) -> Unit {
  let result : Result[Array[@graphics.GraphicsEvent], @reader.PdfDocumentError] = try? page
    .reader_page()
    .graphics_events(
      @reader.GraphicsPageOptions::with_materialized_xobjects(None),
    )
  match result {
    Ok(events) =>
      for event in events {
        match event {
          @graphics.GraphicsEvent::PathPainted(_, operation, path, state) =>
            page_render_path_svg(builder, operation, path, state)
          @graphics.GraphicsEvent::ImagePainted(_, descriptor, state) =>
            page_render_image_svg(builder, page, descriptor, state)
          _ => ()
        }
      }
    Err(_) => ()
  }
}

///|
fn page_render_path_svg(
  builder : StringBuilder,
  operation : @graphics.PathPaintOperation,
  path : @graphics.GraphicsPath,
  state : @graphics.GraphicsState,
) -> Unit {
  let d = svg_path_data(path, state.ctm)
  if d.length() == 0 {
    return
  }
  builder.write_string("<path d=\"")
  builder.write_string(d)
  builder.write_string("\"")
  write_svg_paint_attributes(builder, operation, state)
  builder.write_string("/>")
}

///|
fn write_svg_paint_attributes(
  builder : StringBuilder,
  operation : @graphics.PathPaintOperation,
  state : @graphics.GraphicsState,
) -> Unit {
  match operation {
    @graphics.PathPaintOperation::StrokePath
    | @graphics.PathPaintOperation::CloseStrokePath => {
      builder.write_string(" fill=\"none\" stroke=\"")
      builder.write_string(svg_colour(state, @graphics.ColourUse::Stroking))
      builder.write_string("\"")
      write_svg_stroke_attributes(builder, state)
    }
    @graphics.PathPaintOperation::FillPath(rule) => {
      builder.write_string(" fill=\"")
      builder.write_string(svg_colour(state, @graphics.ColourUse::Nonstroking))
      builder.write_string("\" stroke=\"none\"")
      write_svg_fill_rule(builder, rule)
    }
    @graphics.PathPaintOperation::FillStrokePath(rule)
    | @graphics.PathPaintOperation::CloseFillStrokePath(rule) => {
      builder.write_string(" fill=\"")
      builder.write_string(svg_colour(state, @graphics.ColourUse::Nonstroking))
      builder.write_string("\" stroke=\"")
      builder.write_string(svg_colour(state, @graphics.ColourUse::Stroking))
      builder.write_string("\"")
      write_svg_fill_rule(builder, rule)
      write_svg_stroke_attributes(builder, state)
    }
    @graphics.PathPaintOperation::EndPath =>
      builder.write_string(" fill=\"none\" stroke=\"none\"")
  }
}

///|
fn write_svg_stroke_attributes(
  builder : StringBuilder,
  state : @graphics.GraphicsState,
) -> Unit {
  builder.write_string(" stroke-width=\"")
  builder.write_string(svg_stroke_width(state).to_string())
  builder.write_string("\" stroke-linecap=\"")
  builder.write_string(svg_line_cap(state.line_cap))
  builder.write_string("\" stroke-linejoin=\"")
  builder.write_string(svg_line_join(state.line_join))
  builder.write_string("\"")
  if state.dash_pattern.array.length() > 0 {
    builder.write_string(" stroke-dasharray=\"")
    for index in 0..<state.dash_pattern.array.length() {
      if index > 0 {
        builder.write_string(" ")
      }
      builder.write_string(state.dash_pattern.array[index].to_string())
    }
    builder.write_string("\" stroke-dashoffset=\"")
    builder.write_string(state.dash_pattern.phase.to_string())
    builder.write_string("\"")
  }
}

///|
fn write_svg_fill_rule(
  builder : StringBuilder,
  rule : @graphics.FillRule,
) -> Unit {
  match rule {
    @graphics.FillRule::NonZero => ()
    @graphics.FillRule::EvenOdd =>
      builder.write_string(" fill-rule=\"evenodd\"")
  }
}

///|
fn svg_path_data(
  path : @graphics.GraphicsPath,
  ctm : @graphics.GraphicsMatrix,
) -> String {
  let builder = StringBuilder::new()
  for subpath in path.subpaths {
    let start = ctm.transform_point(subpath.start)
    builder.write_string("M ")
    builder.write_string(start.x.to_string())
    builder.write_string(" ")
    builder.write_string(start.y.to_string())
    for segment in subpath.segments {
      match segment {
        @graphics.PathSegment::LineTo(point) => {
          let p = ctm.transform_point(point)
          builder.write_string(" L ")
          builder.write_string(p.x.to_string())
          builder.write_string(" ")
          builder.write_string(p.y.to_string())
        }
        @graphics.PathSegment::CurveTo(control1, control2, end_point) => {
          let p1 = ctm.transform_point(control1)
          let p2 = ctm.transform_point(control2)
          let p3 = ctm.transform_point(end_point)
          builder.write_string(" C ")
          builder.write_string(p1.x.to_string())
          builder.write_string(" ")
          builder.write_string(p1.y.to_string())
          builder.write_string(" ")
          builder.write_string(p2.x.to_string())
          builder.write_string(" ")
          builder.write_string(p2.y.to_string())
          builder.write_string(" ")
          builder.write_string(p3.x.to_string())
          builder.write_string(" ")
          builder.write_string(p3.y.to_string())
        }
        @graphics.PathSegment::ClosePath => builder.write_string(" Z")
      }
    }
    builder.write_string(" ")
  }
  builder.to_string()
}

///|
fn page_render_image_svg(
  builder : StringBuilder,
  page : @pdfapi.PdfPage,
  descriptor : @graphics.ImageDescriptor,
  state : @graphics.GraphicsState,
) -> Unit {
  match descriptor.source {
    @graphics.ImageSource::XObjectImage(Some(name)) =>
      match page_image_entry_by_name(page, name) {
        Some(entry) => {
          let href = page_image_data_url(entry, state)
          if href.length() > 0 {
            builder.write_string(
              "<image x=\"0\" y=\"0\" width=\"1\" height=\"1\" href=\"",
            )
            builder.write_string(href)
            builder.write_string("\" transform=\"matrix(")
            write_svg_matrix(builder, state.ctm)
            builder.write_string(")\"/>")
          }
        }
        None => ()
      }
    _ => ()
  }
}

///|
fn write_svg_matrix(
  builder : StringBuilder,
  matrix : @graphics.GraphicsMatrix,
) -> Unit {
  builder.write_string(matrix.a.to_string())
  builder.write_string(" ")
  builder.write_string(matrix.b.to_string())
  builder.write_string(" ")
  builder.write_string(matrix.c.to_string())
  builder.write_string(" ")
  builder.write_string(matrix.d.to_string())
  builder.write_string(" ")
  builder.write_string(matrix.e.to_string())
  builder.write_string(" ")
  builder.write_string(matrix.f.to_string())
}

///|
fn page_render_texts_svg(
  builder : StringBuilder,
  page : @pdfapi.PdfPage,
) -> Unit {
  let result : Result[@text.TextProgram, @reader.PdfDocumentError] = try? page
    .reader_page()
    .text_program(@reader.TextPageOptions::default())
  match result {
    Ok(program) => {
      let matrices = text_program_span_rendering_matrices(program)
      for index in 0..<program.spans.length() {
        let span = program.spans[index]
        if span.text.length() > 0 {
          page_render_text_svg(builder, span, span_svg_matrix(matrices, index))
        }
      }
    }
    Err(_) => ()
  }
}

///|
fn page_render_text_svg(
  builder : StringBuilder,
  span : @text.TextSpan,
  matrix : @text.TextMatrix,
) -> Unit {
  builder.write_string("<text transform=\"matrix(")
  write_svg_text_matrix(builder, matrix)
  builder.write_string(
    ")\" font-size=\"1\" font-family=\"sans-serif\" fill=\"#111111\">",
  )
  write_xml_escaped(builder, span.text)
  builder.write_string("</text>")
}

///|
fn write_svg_text_matrix(
  builder : StringBuilder,
  matrix : @text.TextMatrix,
) -> Unit {
  builder.write_string(matrix.a.to_string())
  builder.write_string(" ")
  builder.write_string(matrix.b.to_string())
  builder.write_string(" ")
  builder.write_string(matrix.c.to_string())
  builder.write_string(" ")
  builder.write_string(matrix.d.to_string())
  builder.write_string(" ")
  builder.write_string(matrix.e.to_string())
  builder.write_string(" ")
  builder.write_string(matrix.f.to_string())
}

///|
fn text_program_span_rendering_matrices(
  program : @text.TextProgram,
) -> Array[@text.TextMatrix] {
  let matrices : Array[@text.TextMatrix] = []
  let mut saw_glyph = false
  for event in program.events {
    match event {
      SourceString(_) => saw_glyph = false
      GlyphShown(glyph) =>
        if !saw_glyph {
          matrices.push(glyph.rendering_matrix.matrix)
          saw_glyph = true
        }
      _ => ()
    }
  }
  matrices
}

///|
fn span_svg_matrix(
  matrices : Array[@text.TextMatrix],
  index : Int,
) -> @text.TextMatrix {
  if index >= 0 && index < matrices.length() {
    matrices[index]
  } else {
    @text.TextMatrix::identity()
  }
}

///|
fn svg_colour(
  state : @graphics.GraphicsState,
  colour_use : @graphics.ColourUse,
) -> String {
  let result : Result[@graphics.DeviceRgbColour, @graphics.PdfGraphicsError] = try? state.current_colour_as_rgb(
    colour_use,
  )
  match result {
    Ok(rgb) => rgb_hex_colour(rgb)
    Err(_) => "#000000"
  }
}

///|
fn rgb_hex_colour(rgb : @graphics.DeviceRgbColour) -> String {
  let builder = StringBuilder::new()
  builder.write_char('#')
  write_hex_byte(builder, unit_to_int_byte(rgb.red))
  write_hex_byte(builder, unit_to_int_byte(rgb.green))
  write_hex_byte(builder, unit_to_int_byte(rgb.blue))
  builder.to_string()
}

///|
fn unit_to_int_byte(value : Double) -> Int {
  @math.floor(clamp_unit(value) * 255.0 + 0.5).to_int()
}

///|
fn clamp_unit(value : Double) -> Double {
  if value < 0.0 {
    0.0
  } else if value > 1.0 {
    1.0
  } else {
    value
  }
}

///|
fn write_hex_byte(builder : StringBuilder, value : Int) -> Unit {
  builder.write_char(hex_digit((value >> 4) & 0x0f).to_char())
  builder.write_char(hex_digit(value & 0x0f).to_char())
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
fn svg_stroke_width(state : @graphics.GraphicsState) -> Double {
  let sx = (state.ctm.a * state.ctm.a + state.ctm.b * state.ctm.b).sqrt()
  let sy = (state.ctm.c * state.ctm.c + state.ctm.d * state.ctm.d).sqrt()
  let scale = if sx > sy { sx } else { sy }
  if scale > 0.0 {
    state.line_width * scale
  } else {
    state.line_width
  }
}

///|
fn svg_line_cap(cap : @graphics.LineCapStyle) -> String {
  match cap {
    @graphics.LineCapStyle::ButtCap => "butt"
    @graphics.LineCapStyle::RoundCap => "round"
    @graphics.LineCapStyle::ProjectingSquareCap => "square"
  }
}

///|
fn svg_line_join(join : @graphics.LineJoinStyle) -> String {
  match join {
    @graphics.LineJoinStyle::MiterJoin => "miter"
    @graphics.LineJoinStyle::RoundJoin => "round"
    @graphics.LineJoinStyle::BevelJoin => "bevel"
  }
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
fn page_image_entries(page : @pdfapi.PdfPage) -> Array[PageImageEntry] {
  let resources_result : Result[
    @content.ContentResources,
    @reader.PdfDocumentError,
  ] = try? page.reader_page().materialized_content_resources()
  match resources_result {
    Ok(resources) => page_image_entries_from_resources(resources)
    Err(_) => []
  }
}

///|
fn page_image_entries_from_resources(
  resources : @content.ContentResources,
) -> Array[PageImageEntry] {
  let entries : Array[PageImageEntry] = []
  let result : Result[@objects.PdfObject?, @content.PdfContentError] = try? resources.category_object(
    @content.ResourceCategory::XObject,
  )
  match result {
    Ok(Some(@objects.PdfObject::Dictionary(xobjects))) =>
      collect_xobject_image_entries(xobjects, resources.dictionary, entries)
    _ => ()
  }
  entries
}

///|
fn page_image_entry_by_name(
  page : @pdfapi.PdfPage,
  name : @objects.PdfName,
) -> PageImageEntry? {
  for entry in page_image_entries(page) {
    match entry.name {
      Some(entry_name) if entry_name == name => return Some(entry)
      _ => ()
    }
  }
  None
}

///|
fn collect_xobject_image_entries(
  xobjects : @objects.PdfDictionary,
  resources : @objects.PdfDictionary?,
  entries : Array[PageImageEntry],
) -> Unit {
  for name, object in xobjects {
    match object {
      @objects.PdfObject::Stream(stream) if stream_subtype_is(stream, b"Image") =>
        entries.push(PageImageEntry::{ name: Some(name), stream, resources })
      @objects.PdfObject::Stream(stream) if stream_subtype_is(stream, b"Form") =>
        collect_form_image_entries(stream, resources, entries)
      _ => ()
    }
  }
}

///|
fn collect_form_image_entries(
  stream : @objects.PdfStream,
  parent_resources : @objects.PdfDictionary?,
  entries : Array[PageImageEntry],
) -> Unit {
  let resources = match stream.dict.get(@objects.PdfName::new(b"Resources")) {
    Some(@objects.PdfObject::Dictionary(form_resources)) => Some(form_resources)
    _ => parent_resources
  }
  match resources {
    Some(resource_dict) =>
      match resource_dict.get(@objects.PdfName::new(b"XObject")) {
        Some(@objects.PdfObject::Dictionary(xobjects)) =>
          collect_xobject_image_entries(xobjects, resources, entries)
        _ => ()
      }
    None => ()
  }
}

///|
fn page_image_info_json(entry : PageImageEntry) -> String {
  match page_image_descriptor(entry) {
    Some(descriptor) => image_descriptor_json(descriptor)
    None => "{\"error\":\"failed to read image metadata\"}"
  }
}

///|
fn image_descriptor_json(descriptor : @graphics.ImageDescriptor) -> String {
  let builder = StringBuilder::new()
  builder.write_string("{\"width\":")
  builder.write_string(descriptor.width.to_string())
  builder.write_string(",\"height\":")
  builder.write_string(descriptor.height.to_string())
  builder.write_string(",\"colorSpace\":")
  builder.write_string(
    json_string_option(descriptor.color_space.map(colour_space_label)),
  )
  builder.write_string("}")
  builder.to_string()
}

///|
fn page_image_descriptor(entry : PageImageEntry) -> @graphics.ImageDescriptor? {
  let result : Result[@graphics.ImageDescriptor, @graphics.PdfGraphicsError] = try? @graphics.validate_image_stream(
    entry.name,
    prepare_render_image_stream(entry.stream, entry.resources),
    0L,
  )
  match result {
    Ok(descriptor) => Some(descriptor)
    Err(_) => None
  }
}

///|
fn page_image_rgba(entry : PageImageEntry) -> Bytes {
  let result : Result[@graphics.ExtractedImage, @graphics.PdfGraphicsError] = try? @graphics.extract_image_xobject(
    entry.name,
    prepare_render_image_stream(entry.stream, entry.resources),
    0L,
  )
  match result {
    Ok(extracted) => extracted_image_rgba(extracted.data)
    Err(_) => b""
  }
}

///|
fn page_image_data_url(
  entry : PageImageEntry,
  state : @graphics.GraphicsState,
) -> String {
  let result : Result[@graphics.ExtractedImage, @graphics.PdfGraphicsError] = try? @graphics.extract_image_xobject(
    entry.name,
    prepare_render_image_stream(entry.stream, entry.resources),
    0L,
  )
  match result {
    Ok(extracted) =>
      match extracted.data {
        @graphics.ExtractedImageData::DeviceRgbRaster(raster) =>
          png_data_url(raster.width, raster.height, raster.rgba)
        @graphics.ExtractedImageData::StencilMaskRaster(mask) => {
          let paint_result : Result[
            @graphics.DeviceRgbColour,
            @graphics.PdfGraphicsError,
          ] = try? state.current_colour_as_rgb(@graphics.ColourUse::Nonstroking)
          let paint = match paint_result {
            Ok(rgb) => rgb
            Err(_) =>
              @graphics.DeviceRgbColour::{ red: 0.0, green: 0.0, blue: 0.0 }
          }
          let raster = @graphics.paint_stencil_mask_with_colour(mask, paint)
          png_data_url(raster.width, raster.height, raster.rgba)
        }
        @graphics.ExtractedImageData::EncodedImageData(_, _) => ""
      }
    Err(_) => ""
  }
}

///|
fn colour_space_label(space : @graphics.ColourSpace) -> String {
  match space {
    Device(device) =>
      match device {
        DeviceGray => "DeviceGray"
        DeviceRGB => "DeviceRGB"
        DeviceCMYK => "DeviceCMYK"
      }
    CalGray(_) => "CalGray"
    CalRGB(_) => "CalRGB"
    Lab(_) => "Lab"
    ICCBased(_) => "ICCBased"
    Pattern(_) => "Pattern"
    Indexed(_) => "Indexed"
    Separation(_) => "Separation"
    DeviceN(_) => "DeviceN"
  }
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
fn png_data_url(width : Int, height : Int, rgba : Bytes) -> String {
  if width <= 0 || height <= 0 || rgba.length() != width * height * 4 {
    return ""
  }
  "data:image/png;base64," + base64_encode(rgba_png_bytes(width, height, rgba))
}

///|
fn rgba_png_bytes(width : Int, height : Int, rgba : Bytes) -> Bytes {
  let out : Array[Byte] = []
  out.push(b'\x89')
  out.append(b"PNG\r\n\x1a\n".to_array())
  let ihdr : Array[Byte] = []
  append_u32_be(ihdr, width.to_int64())
  append_u32_be(ihdr, height.to_int64())
  ihdr.push(b'\x08')
  ihdr.push(b'\x06')
  ihdr.push(b'\x00')
  ihdr.push(b'\x00')
  ihdr.push(b'\x00')
  append_png_chunk(out, b"IHDR", Bytes::from_array(ihdr))
  append_png_chunk(
    out,
    b"IDAT",
    encode_zlib_stored(png_scanlines(width, height, rgba)),
  )
  append_png_chunk(out, b"IEND", b"")
  Bytes::from_array(out)
}

///|
fn png_scanlines(width : Int, height : Int, rgba : Bytes) -> Bytes {
  let out : Array[Byte] = []
  let stride = width * 4
  for row in 0..<height {
    out.push(b'\x00')
    let start = row * stride
    for index in start..<(start + stride) {
      out.push(rgba[index])
    }
  }
  Bytes::from_array(out)
}

///|
fn append_png_chunk(
  out : Array[Byte],
  chunk_type : Bytes,
  data : Bytes,
) -> Unit {
  append_u32_be(out, data.length().to_int64())
  out.append(chunk_type.to_array())
  out.append(data.to_array())
  let crc_data : Array[Byte] = []
  crc_data.append(chunk_type.to_array())
  crc_data.append(data.to_array())
  append_u32_be(out, crc32(Bytes::from_array(crc_data)))
}

///|
fn encode_zlib_stored(data : Bytes) -> Bytes {
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
fn crc32(data : Bytes) -> Int64 {
  let mut crc = 0xffffffffL
  for byte in data {
    crc = crc ^ byte.to_int64()
    for _ in 0..<8 {
      if (crc & 1L) == 1L {
        crc = (crc >> 1) ^ 0xedb88320L
      } else {
        crc = crc >> 1
      }
    }
  }
  (crc ^ 0xffffffffL) & 0xffffffffL
}

///|
fn base64_encode(data : Bytes) -> String {
  let builder = StringBuilder::new()
  let mut index = 0
  while index < data.length() {
    let first = data[index].to_int()
    let second = if index + 1 < data.length() {
      data[index + 1].to_int()
    } else {
      0
    }
    let third = if index + 2 < data.length() {
      data[index + 2].to_int()
    } else {
      0
    }
    let packed = (first << 16) | (second << 8) | third
    builder.write_char(base64_char((packed >> 18) & 0x3f))
    builder.write_char(base64_char((packed >> 12) & 0x3f))
    if index + 1 < data.length() {
      builder.write_char(base64_char((packed >> 6) & 0x3f))
    } else {
      builder.write_char('=')
    }
    if index + 2 < data.length() {
      builder.write_char(base64_char(packed & 0x3f))
    } else {
      builder.write_char('=')
    }
    index = index + 3
  }
  builder.to_string()
}

///|
fn base64_char(value : Int) -> Char {
  if value < 26 {
    (b'A'.to_int() + value).unsafe_to_char()
  } else if value < 52 {
    (b'a'.to_int() + value - 26).unsafe_to_char()
  } else if value < 62 {
    (b'0'.to_int() + value - 52).unsafe_to_char()
  } else if value == 62 {
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
fn write_xml_escaped(builder : StringBuilder, value : String) -> Unit {
  for char in value {
    match char {
      '&' => builder.write_string("&amp;")
      '<' => builder.write_string("&lt;")
      '>' => builder.write_string("&gt;")
      '"' => builder.write_string("&quot;")
      '\'' => builder.write_string("&apos;")
      _ => builder.write_char(char)
    }
  }
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
