///|
priv struct PageImageEntry {
  name : @objects.PdfName?
  stream : @objects.PdfStream
  resources : @objects.PdfDictionary?
}

///|
pub fn render_page_svg(page : @reader.PdfPage) -> String {
  let width = page_width(page)
  let height = page_height(page)
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
  page_render_graphics_svg(builder, page, height)
  page_render_texts_svg(builder, page, height)
  builder.write_string("</svg>")
  builder.to_string()
}

///|
fn page_width(page : @reader.PdfPage) -> Double {
  let (width, height) = page_dimensions(page)
  if page_is_rotated_sideways(page) {
    height
  } else {
    width
  }
}

///|
fn page_height(page : @reader.PdfPage) -> Double {
  let (width, height) = page_dimensions(page)
  if page_is_rotated_sideways(page) {
    width
  } else {
    height
  }
}

///|
fn page_dimensions(page : @reader.PdfPage) -> (Double, Double) {
  let result : Result[@reader.PdfRectangle?, @reader.PdfDocumentError] = try? page
    .media_box()
  match result {
    Ok(Some(rect)) =>
      (abs_double(rect.right - rect.left), abs_double(rect.top - rect.bottom))
    _ => (0.0, 0.0)
  }
}

///|
fn page_is_rotated_sideways(page : @reader.PdfPage) -> Bool {
  let result : Result[Int?, @reader.PdfDocumentError] = try? page.rotate()
  match result {
    Ok(Some(value)) => {
      let normalized = positive_mod(value, 360)
      normalized == 90 || normalized == 270
    }
    _ => false
  }
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
fn abs_double(value : Double) -> Double {
  if value < 0.0 {
    0.0 - value
  } else {
    value
  }
}

///|
fn page_render_graphics_svg(
  builder : StringBuilder,
  page : @reader.PdfPage,
  page_height : Double,
) -> Unit {
  let result : Result[Array[@graphics.GraphicsEvent], @reader.PdfDocumentError] = try? page
    .graphics_events(@reader.GraphicsPageOptions::with_materialized_xobjects(None))
  match result {
    Ok(events) =>
      for event in events {
        match event {
          @graphics.GraphicsEvent::PathPainted(_, operation, path, state) =>
            page_render_path_svg(builder, operation, path, state, page_height)
          @graphics.GraphicsEvent::ImagePainted(_, descriptor, state) =>
            page_render_image_svg(builder, page, descriptor, state, page_height)
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
  page_height : Double,
) -> Unit {
  let d = svg_path_data(path, state.ctm, page_height)
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
  page_height : Double,
) -> String {
  let builder = StringBuilder::new()
  for subpath in path.subpaths {
    let start = svg_graphics_point(ctm.transform_point(subpath.start), page_height)
    builder.write_string("M ")
    builder.write_string(start.x.to_string())
    builder.write_string(" ")
    builder.write_string(start.y.to_string())
    for segment in subpath.segments {
      match segment {
        @graphics.PathSegment::LineTo(point) => {
          let p = svg_graphics_point(ctm.transform_point(point), page_height)
          builder.write_string(" L ")
          builder.write_string(p.x.to_string())
          builder.write_string(" ")
          builder.write_string(p.y.to_string())
        }
        @graphics.PathSegment::CurveTo(control1, control2, end_point) => {
          let p1 = svg_graphics_point(
            ctm.transform_point(control1), page_height,
          )
          let p2 = svg_graphics_point(
            ctm.transform_point(control2), page_height,
          )
          let p3 = svg_graphics_point(
            ctm.transform_point(end_point), page_height,
          )
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
fn svg_graphics_point(
  point : @graphics.GraphicsPoint,
  page_height : Double,
) -> @graphics.GraphicsPoint {
  @graphics.GraphicsPoint::{ x: point.x, y: page_height - point.y }
}

///|
fn page_render_image_svg(
  builder : StringBuilder,
  page : @reader.PdfPage,
  descriptor : @graphics.ImageDescriptor,
  state : @graphics.GraphicsState,
  page_height : Double,
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
            write_svg_image_matrix(builder, state.ctm, page_height)
            builder.write_string(")\"/>")
          }
        }
        None => ()
      }
    _ => ()
  }
}

///|
fn write_svg_image_matrix(
  builder : StringBuilder,
  matrix : @graphics.GraphicsMatrix,
  page_height : Double,
) -> Unit {
  builder.write_string(matrix.a.to_string())
  builder.write_string(" ")
  builder.write_string((0.0 - matrix.b).to_string())
  builder.write_string(" ")
  builder.write_string((0.0 - matrix.c).to_string())
  builder.write_string(" ")
  builder.write_string(matrix.d.to_string())
  builder.write_string(" ")
  builder.write_string((matrix.e + matrix.c).to_string())
  builder.write_string(" ")
  builder.write_string((page_height - matrix.f - matrix.d).to_string())
}

///|
fn page_render_texts_svg(
  builder : StringBuilder,
  page : @reader.PdfPage,
  page_height : Double,
) -> Unit {
  let result : Result[@text.TextProgram, @reader.PdfDocumentError] = try? page
    .text_program(@reader.TextPageOptions::default())
  match result {
    Ok(program) => {
      let matrices = text_program_span_rendering_matrices(program)
      for index in 0..<program.spans.length() {
        let span = program.spans[index]
        if span.text.length() > 0 {
          page_render_text_svg(
            builder,
            span,
            span_svg_matrix(matrices, index),
            page_height,
          )
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
  page_height : Double,
) -> Unit {
  builder.write_string("<text transform=\"matrix(")
  write_svg_text_matrix(builder, matrix, page_height)
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
  page_height : Double,
) -> Unit {
  builder.write_string(matrix.a.to_string())
  builder.write_string(" ")
  builder.write_string((0.0 - matrix.b).to_string())
  builder.write_string(" ")
  builder.write_string(matrix.c.to_string())
  builder.write_string(" ")
  builder.write_string((0.0 - matrix.d).to_string())
  builder.write_string(" ")
  builder.write_string(matrix.e.to_string())
  builder.write_string(" ")
  builder.write_string((page_height - matrix.f).to_string())
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
  let result : Result[@graphics.DeviceRgbColour, @graphics.PdfGraphicsError] = try? state
    .current_colour_as_rgb(colour_use)
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
fn page_image_entries(page : @reader.PdfPage) -> Array[PageImageEntry] {
  let resources_result : Result[
    @content.ContentResources,
    @reader.PdfDocumentError,
  ] = try? page.materialized_content_resources()
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
  let result : Result[@objects.PdfObject?, @content.PdfContentError] = try? resources
    .category_object(@content.ResourceCategory::XObject)
  match result {
    Ok(Some(@objects.PdfObject::Dictionary(xobjects))) =>
      collect_xobject_image_entries(xobjects, resources.dictionary, entries)
    _ => ()
  }
  entries
}

///|
fn page_image_entry_by_name(
  page : @reader.PdfPage,
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
fn page_image_data_url(
  entry : PageImageEntry,
  state : @graphics.GraphicsState,
) -> String {
  let result : Result[@graphics.ExtractedImage, @graphics.PdfGraphicsError] = try? @graphics
    .extract_image_xobject(
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
        @graphics.ExtractedImageData::EncodedImageData(data, filters) =>
          encoded_image_data_url(data, filters)
      }
    Err(_) => ""
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
fn png_data_url(width : Int, height : Int, rgba : Bytes) -> String {
  match image_data_from_rgba(width, height, rgba) {
    Some(image) =>
      match encode_png_bytes(image) {
        Some(bytes) => "data:image/png;base64," + base64_encode(bytes)
        None => ""
      }
    None => ""
  }
}

///|
fn encoded_image_data_url(
  data : Bytes,
  filters : Array[@objects.PdfName],
) -> String {
  match decode_external_image_bytes(data) {
    Some(image) => bmp_data_url(image)
    None => browser_encoded_image_data_url(data, filters)
  }
}

///|
fn bmp_data_url(image : @image.ImageData) -> String {
  match encode_bmp_bytes(image) {
    Some(bytes) => "data:image/bmp;base64," + base64_encode(bytes)
    None => ""
  }
}

///|
fn browser_encoded_image_data_url(
  data : Bytes,
  filters : Array[@objects.PdfName],
) -> String {
  if filters.length() != 1 {
    return ""
  }
  let filter = filters[0]
  if filter == @objects.PdfName::new(b"DCTDecode") {
    "data:image/jpeg;base64," + base64_encode(data)
  } else if filter == @objects.PdfName::new(b"JPXDecode") {
    "data:image/jp2;base64," + base64_encode(data)
  } else {
    ""
  }
}

///|
fn image_data_from_rgba(
  width : Int,
  height : Int,
  rgba : Bytes,
) -> @image.ImageData? {
  if width <= 0 || height <= 0 || rgba.length() != width * height * 4 {
    None
  } else {
    Some(@image.ImageData::{ width, height, data: rgba })
  }
}

///|
fn decode_external_image_bytes(data : Bytes) -> @image.ImageData? {
  match decode_png_image_bytes(data) {
    Some(image) => Some(image)
    None =>
      match decode_bmp_image_bytes(data) {
        Some(image) => Some(image)
        None => decode_jpeg_image_bytes(data)
      }
  }
}

///|
fn decode_png_image_bytes(data : Bytes) -> @image.ImageData? {
  let result : Result[@image.ImageData, @image.DecodeError] = try? @image
    .decode_png(data)
  match result {
    Ok(image) => Some(image)
    Err(_) => None
  }
}

///|
fn decode_bmp_image_bytes(data : Bytes) -> @image.ImageData? {
  let result : Result[@image.ImageData, @image.DecodeError] = try? @image
    .decode_bmp(data)
  match result {
    Ok(image) => Some(image)
    Err(_) => None
  }
}

///|
fn decode_jpeg_image_bytes(data : Bytes) -> @image.ImageData? {
  let result : Result[@image.ImageData, @image.DecodeError] = try? @image
    .decode_jpeg(data)
  match result {
    Ok(image) => Some(image)
    Err(_) => None
  }
}

///|
fn encode_png_bytes(image : @image.ImageData) -> Bytes? {
  let result : Result[Bytes, @image.EncodeError] = try? @image.encode_png(image)
  match result {
    Ok(bytes) => Some(bytes)
    Err(_) => None
  }
}

///|
fn encode_bmp_bytes(image : @image.ImageData) -> Bytes? {
  let result : Result[Bytes, @image.EncodeError] = try? @image.encode_bmp(image)
  match result {
    Ok(bytes) => Some(bytes)
    Err(_) => None
  }
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
