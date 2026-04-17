///|
priv struct PageImageEntry {
  name : @objects.PdfName?
  stream : @objects.PdfStream
  resources : @objects.PdfDictionary?
}

///|
priv struct SvgPositionedText {
  text : String
  x_values : Array[Double]
  y_values : Array[Double]
}

///|
pub fn render_page_svg(page : @reader.PdfPage) -> String {
  let width = page_width(page)
  let height = page_height(page)
  let builder = StringBuilder::new()
  builder.write_string(
    "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 ",
  )
  builder.write_string(format_svg_number(width))
  builder.write_string(" ")
  builder.write_string(format_svg_number(height))
  builder.write_string("\" width=\"")
  builder.write_string(format_svg_number(width))
  builder.write_string("\" height=\"")
  builder.write_string(format_svg_number(height))
  builder.write_string("\">")
  builder.write_string("<rect x=\"0\" y=\"0\" width=\"")
  builder.write_string(format_svg_number(width + 1.0))
  builder.write_string("\" height=\"")
  builder.write_string(format_svg_number(height + 1.0))
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
  let result : Result[@reader.PdfRectangle?, @reader.PdfDocumentError] = try? page.media_box()
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
fn format_svg_number(value : Double) -> String {
  let rounded = @math.floor(abs_double(value) * 1000.0 + 0.5).to_int()
  if rounded == 0 {
    return "0"
  }
  let sign = if value < 0.0 && rounded != 0 { "-" } else { "" }
  let whole = (rounded / 1000).to_string()
  let fraction = rounded % 1000
  if fraction == 0 {
    sign + whole
  } else {
    sign + whole + "." + trimmed3_fraction(fraction)
  }
}

///|
fn fixed3_fraction(value : Int) -> String {
  let hundreds = value / 100
  let tens = value / 10 % 10
  let ones = value % 10
  String::from_array([
    (b'0'.to_int() + hundreds).unsafe_to_char(),
    (b'0'.to_int() + tens).unsafe_to_char(),
    (b'0'.to_int() + ones).unsafe_to_char(),
  ])
}

///|
fn trimmed3_fraction(value : Int) -> String {
  if value % 100 == 0 {
    String::from_array([(b'0'.to_int() + value / 100).unsafe_to_char()])
  } else if value % 10 == 0 {
    String::from_array([
      (b'0'.to_int() + value / 100).unsafe_to_char(),
      (b'0'.to_int() + value / 10 % 10).unsafe_to_char(),
    ])
  } else {
    fixed3_fraction(value)
  }
}

///|
fn page_render_graphics_svg(
  builder : StringBuilder,
  page : @reader.PdfPage,
  page_height : Double,
) -> Unit {
  let result : Result[Array[@graphics.GraphicsEvent], @reader.PdfDocumentError] = try? page.graphics_events(
    @reader.GraphicsPageOptions::with_materialized_xobjects(None),
  )
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
  write_svg_path_pixel_alignment(builder, operation, path, state)
  write_svg_paint_attributes(builder, operation, state)
  builder.write_string("/>")
}

///|
fn write_svg_path_pixel_alignment(
  builder : StringBuilder,
  operation : @graphics.PathPaintOperation,
  path : @graphics.GraphicsPath,
  state : @graphics.GraphicsState,
) -> Unit {
  let (dx, dy) = svg_path_pixel_offset(operation, path, state)
  if dx != 0.0 || dy != 0.0 {
    builder.write_string(" transform=\"translate(")
    builder.write_string(format_svg_number(dx))
    builder.write_string(" ")
    builder.write_string(format_svg_number(dy))
    builder.write_string(")\"")
  }
}

///|
fn svg_path_pixel_offset(
  operation : @graphics.PathPaintOperation,
  path : @graphics.GraphicsPath,
  state : @graphics.GraphicsState,
) -> (Double, Double) {
  if !svg_stroke_width_is_odd_pixel(state) {
    return (0.0, 0.0)
  }
  match operation {
    @graphics.PathPaintOperation::StrokePath
    | @graphics.PathPaintOperation::CloseStrokePath =>
      svg_axis_line_pixel_offset(path)
    @graphics.PathPaintOperation::FillStrokePath(_)
    | @graphics.PathPaintOperation::CloseFillStrokePath(_) =>
      if svg_path_is_axis_aligned_rectangle(path) {
        (0.5, 0.5)
      } else {
        (0.0, 0.0)
      }
    _ => (0.0, 0.0)
  }
}

///|
fn svg_stroke_width_is_odd_pixel(state : @graphics.GraphicsState) -> Bool {
  let width = svg_stroke_width(state)
  let rounded = @math.floor(width + 0.5).to_int()
  rounded % 2 == 1 && abs_double(width - rounded.to_double()) < 0.001
}

///|
fn svg_axis_line_pixel_offset(
  path : @graphics.GraphicsPath,
) -> (Double, Double) {
  if path.subpaths.length() != 1 {
    return (0.0, 0.0)
  }
  let subpath = path.subpaths[0]
  if subpath.segments.length() != 1 {
    return (0.0, 0.0)
  }
  match subpath.segments[0] {
    @graphics.PathSegment::LineTo(point) =>
      if abs_double(point.x - subpath.start.x) < 0.001 {
        (0.5, 0.0)
      } else if abs_double(point.y - subpath.start.y) < 0.001 {
        (0.0, 0.5)
      } else {
        (0.0, 0.0)
      }
    _ => (0.0, 0.0)
  }
}

///|
fn svg_path_is_axis_aligned_rectangle(path : @graphics.GraphicsPath) -> Bool {
  if path.subpaths.length() != 1 {
    return false
  }
  let subpath = path.subpaths[0]
  if subpath.segments.length() != 4 {
    return false
  }
  match
    (
      subpath.segments[0],
      subpath.segments[1],
      subpath.segments[2],
      subpath.segments[3],
    ) {
    (
      @graphics.PathSegment::LineTo(p1),
      @graphics.PathSegment::LineTo(p2),
      @graphics.PathSegment::LineTo(p3),
      @graphics.PathSegment::ClosePath,
    ) =>
      abs_double(subpath.start.y - p1.y) < 0.001 &&
      abs_double(p1.x - p2.x) < 0.001 &&
      abs_double(p2.y - p3.y) < 0.001 &&
      abs_double(p3.x - subpath.start.x) < 0.001
    _ => false
  }
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
  builder.write_string(format_svg_number(svg_stroke_width(state)))
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
      builder.write_string(format_svg_number(state.dash_pattern.array[index]))
    }
    builder.write_string("\" stroke-dashoffset=\"")
    builder.write_string(format_svg_number(state.dash_pattern.phase))
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
    let start = svg_graphics_point(
      ctm.transform_point(subpath.start),
      page_height,
    )
    builder.write_string("M ")
    builder.write_string(format_svg_number(start.x))
    builder.write_string(" ")
    builder.write_string(format_svg_number(start.y))
    for segment in subpath.segments {
      match segment {
        @graphics.PathSegment::LineTo(point) => {
          let p = svg_graphics_point(ctm.transform_point(point), page_height)
          builder.write_string(" L ")
          builder.write_string(format_svg_number(p.x))
          builder.write_string(" ")
          builder.write_string(format_svg_number(p.y))
        }
        @graphics.PathSegment::CurveTo(control1, control2, end_point) => {
          let p1 = svg_graphics_point(
            ctm.transform_point(control1),
            page_height,
          )
          let p2 = svg_graphics_point(
            ctm.transform_point(control2),
            page_height,
          )
          let p3 = svg_graphics_point(
            ctm.transform_point(end_point),
            page_height,
          )
          builder.write_string(" C ")
          builder.write_string(format_svg_number(p1.x))
          builder.write_string(" ")
          builder.write_string(format_svg_number(p1.y))
          builder.write_string(" ")
          builder.write_string(format_svg_number(p2.x))
          builder.write_string(" ")
          builder.write_string(format_svg_number(p2.y))
          builder.write_string(" ")
          builder.write_string(format_svg_number(p3.x))
          builder.write_string(" ")
          builder.write_string(format_svg_number(p3.y))
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
            let (expand_x, expand_y) = svg_image_pixel_expansion(
              state.ctm,
              descriptor,
            )
            write_svg_image(
              builder,
              href,
              state.ctm,
              expand_x,
              expand_y,
              page_height,
            )
          }
        }
        None => ()
      }
    _ => ()
  }
}

///|
fn write_svg_image(
  builder : StringBuilder,
  href : String,
  matrix : @graphics.GraphicsMatrix,
  expand_x : Bool,
  expand_y : Bool,
  page_height : Double,
) -> Unit {
  if !expand_x && !expand_y {
    match svg_axis_aligned_image_rect(matrix, page_height) {
      Some((x, y, width, height)) => {
        builder.write_string("<image x=\"")
        builder.write_string(format_svg_number(x))
        builder.write_string("\" y=\"")
        builder.write_string(format_svg_number(y))
        builder.write_string("\" width=\"")
        builder.write_string(format_svg_number(width))
        builder.write_string("\" height=\"")
        builder.write_string(format_svg_number(height))
        builder.write_string("\" href=\"")
        builder.write_string(href)
        builder.write_string("\"/>")
        return
      }
      None => ()
    }
  }
  builder.write_string(
    "<image x=\"0\" y=\"0\" width=\"1\" height=\"1\" href=\"",
  )
  builder.write_string(href)
  builder.write_string("\" transform=\"matrix(")
  write_svg_image_matrix(builder, matrix, expand_x, expand_y, page_height)
  builder.write_string(")\"/>")
}

///|
fn svg_axis_aligned_image_rect(
  matrix : @graphics.GraphicsMatrix,
  page_height : Double,
) -> (Double, Double, Double, Double)? {
  if abs_double(matrix.b) > 0.001 || abs_double(matrix.c) > 0.001 {
    return None
  }
  if matrix.a <= 0.0 || matrix.d <= 0.0 {
    return None
  }
  Some((matrix.e, page_height - matrix.f - matrix.d, matrix.a, matrix.d))
}

///|
fn write_svg_image_matrix(
  builder : StringBuilder,
  matrix : @graphics.GraphicsMatrix,
  expand_x : Bool,
  expand_y : Bool,
  page_height : Double,
) -> Unit {
  let (x_scale, y_scale) = svg_image_axis_scales(matrix, expand_x, expand_y)
  builder.write_string(format_svg_number(matrix.a * x_scale))
  builder.write_string(" ")
  builder.write_string(format_svg_number((0.0 - matrix.b) * x_scale))
  builder.write_string(" ")
  builder.write_string(format_svg_number((0.0 - matrix.c) * y_scale))
  builder.write_string(" ")
  builder.write_string(format_svg_number(matrix.d * y_scale))
  builder.write_string(" ")
  builder.write_string(format_svg_number(matrix.e + matrix.c))
  builder.write_string(" ")
  builder.write_string(format_svg_number(page_height - matrix.f - matrix.d))
}

///|
fn svg_image_pixel_expansion(
  matrix : @graphics.GraphicsMatrix,
  descriptor : @graphics.ImageDescriptor,
) -> (Bool, Bool) {
  (
    svg_image_axis_length(matrix.a, matrix.b) > descriptor.width.to_double(),
    svg_image_axis_length(matrix.c, matrix.d) > descriptor.height.to_double(),
  )
}

///|
fn svg_image_axis_scales(
  matrix : @graphics.GraphicsMatrix,
  expand_x : Bool,
  expand_y : Bool,
) -> (Double, Double) {
  let x_scale = if expand_x {
    svg_image_axis_scale(matrix.a, matrix.b)
  } else {
    1.0
  }
  let y_scale = if expand_y {
    svg_image_axis_scale(matrix.c, matrix.d)
  } else {
    1.0
  }
  (x_scale, y_scale)
}

///|
fn svg_image_axis_scale(x : Double, y : Double) -> Double {
  let length = svg_image_axis_length(x, y)
  if length > 1.0 {
    (length + 0.5) / length
  } else {
    1.0
  }
}

///|
fn svg_image_axis_length(x : Double, y : Double) -> Double {
  (x * x + y * y).sqrt()
}

///|
fn page_render_texts_svg(
  builder : StringBuilder,
  page : @reader.PdfPage,
  page_height : Double,
) -> Unit {
  let result : Result[@text.TextProgram, @reader.PdfDocumentError] = try? page.text_program(
    @reader.TextPageOptions::default(),
  )
  match result {
    Ok(program) => {
      let glyph_groups = text_program_span_glyphs(program)
      let font_families = page_svg_font_families(page)
      let embedded_fonts = page_svg_embedded_fonts(page)
      for index in 0..<program.spans.length() {
        let span = program.spans[index]
        if span.text.length() > 0 {
          let glyphs = span_glyphs(glyph_groups, index)
          match span_svg_embedded_font(embedded_fonts, span) {
            Some(ttf) => {
              let path_builder = StringBuilder::new()
              if page_render_text_span_as_paths(
                  path_builder, span, glyphs, ttf, page_height,
                ) {
                builder.write_string(path_builder.to_string())
              } else {
                page_render_text_svg(
                  builder,
                  span,
                  glyphs,
                  span_svg_font_family(font_families, span),
                  page_height,
                )
              }
            }
            None =>
              page_render_text_svg(
                builder,
                span,
                glyphs,
                span_svg_font_family(font_families, span),
                page_height,
              )
          }
        }
      }
    }
    Err(_) => ()
  }
}

///|
fn page_render_text_span_as_paths(
  builder : StringBuilder,
  span : @text.TextSpan,
  glyphs : Array[@text.TextGlyphEvent],
  ttf : @font.TTFont,
  page_height : Double,
) -> Bool {
  if span.text.length() == 0 {
    return true
  }
  if glyphs.length() == 0 {
    return false
  }
  let units_per_em = svg_font_units_per_em(ttf)
  for glyph in glyphs {
    if !render_glyph_as_path(builder, glyph, ttf, units_per_em, page_height) {
      return false
    }
  }
  true
}

///|
fn render_glyph_as_path(
  builder : StringBuilder,
  glyph : @text.TextGlyphEvent,
  ttf : @font.TTFont,
  units_per_em : Int,
  page_height : Double,
) -> Bool {
  if glyph.paint.invisible {
    return true
  }
  if !glyph.paint.fill {
    return false
  }
  if svg_glyph_is_zero_width_spacing(glyph) {
    return true
  }
  match ttf.cmap.get(glyph.glyph.source_code) {
    Some(gid) => {
      let outline : Array[@svgpath.PathCommand] = ttf.glyph_outline(gid)
      if outline.length() == 0 {
        return svg_glyph_is_spacing(glyph)
      }
      let d = @font.path_commands_to_svg_d(outline)
      if d.length() == 0 {
        return svg_glyph_is_spacing(glyph)
      }
      builder.write_string("<path d=\"")
      builder.write_string(d)
      builder.write_string("\" transform=\"matrix(")
      write_svg_glyph_path_matrix(
        builder,
        glyph.rendering_matrix.matrix,
        units_per_em,
        page_height,
      )
      builder.write_string(")\" fill=\"#000000\"/>")
      true
    }
    None => false
  }
}

///|
fn svg_font_units_per_em(ttf : @font.TTFont) -> Int {
  if ttf.units_per_em > 0 {
    ttf.units_per_em
  } else {
    1000
  }
}

///|
fn write_svg_glyph_path_matrix(
  builder : StringBuilder,
  matrix : @text.TextMatrix,
  units_per_em : Int,
  page_height : Double,
) -> Unit {
  let scale = 1.0 / units_per_em.to_double()
  builder.write_string(format_svg_number(matrix.a * scale))
  builder.write_string(" ")
  builder.write_string(format_svg_number((0.0 - matrix.b) * scale))
  builder.write_string(" ")
  builder.write_string(format_svg_number((0.0 - matrix.c) * scale))
  builder.write_string(" ")
  builder.write_string(format_svg_number(matrix.d * scale))
  builder.write_string(" ")
  builder.write_string(format_svg_number(matrix.e))
  builder.write_string(" ")
  builder.write_string(format_svg_number(page_height - matrix.f))
}

///|
fn svg_glyph_is_zero_width_spacing(glyph : @text.TextGlyphEvent) -> Bool {
  match glyph.unicode {
    @text.UnicodeMapping::Unicode(value) =>
      value == " " &&
      glyph.glyph.metrics.horizontal_displacement == 0.0 &&
      glyph.glyph.metrics.width_source ==
      @text.GlyphWidthSource::FontDescriptorMissingWidth
    @text.UnicodeMapping::Unknown(_, _, _) => false
  }
}

///|
fn svg_glyph_is_spacing(glyph : @text.TextGlyphEvent) -> Bool {
  match glyph.unicode {
    @text.UnicodeMapping::Unicode(value) => value == " "
    @text.UnicodeMapping::Unknown(_, _, _) => false
  }
}

///|
fn page_render_text_svg(
  builder : StringBuilder,
  span : @text.TextSpan,
  glyphs : Array[@text.TextGlyphEvent],
  font_family : String,
  page_height : Double,
) -> Unit {
  let matrix = span_rendering_matrix(span, glyphs)
  let font_size = svg_extract_font_size(matrix)
  let text_matrix = svg_text_transform_without_fontsize(
    matrix, font_size, page_height,
  )
  let positioned = svg_positioned_text(span, text_matrix, glyphs, page_height)
  builder.write_string("<text transform=\"matrix(")
  write_svg_text_matrix(builder, text_matrix)
  builder.write_string(")\" font-size=\"")
  builder.write_string(format_svg_number(font_size))
  builder.write_string(
    "\" text-rendering=\"geometricPrecision\" font-family=\"",
  )
  write_xml_escaped(builder, font_family)
  builder.write_string("\" fill=\"#000000\"")
  match positioned {
    Some(text) => {
      builder.write_string(">")
      write_svg_positioned_tspans(
        builder,
        text,
        svg_use_position_list_tspan(text_matrix, text),
      )
    }
    None => {
      builder.write_string(">")
      write_xml_escaped(builder, span.text)
    }
  }
  builder.write_string("</text>")
}

///|
fn svg_positioned_text(
  span : @text.TextSpan,
  parent : @text.TextMatrix,
  glyphs : Array[@text.TextGlyphEvent],
  page_height : Double,
) -> SvgPositionedText? {
  if glyphs.length() == 0 {
    return None
  }
  if !svg_matrix_is_invertible(parent) {
    return None
  }
  let x_values : Array[Double] = []
  let y_values : Array[Double] = []
  let mut text = ""
  for glyph in glyphs {
    match svg_glyph_text(glyph) {
      Some(value) => {
        if string_char_count(value) != 1 {
          return None
        }
        let glyph_matrix = svg_text_matrix(
          glyph.rendering_matrix.matrix,
          page_height,
        )
        let (x, y) = svg_matrix_local_point(
          parent,
          glyph_matrix.e,
          glyph_matrix.f,
        )
        x_values.push(x)
        y_values.push(y)
        text = text + value
      }
      None => ()
    }
  }
  if text.length() == 0 || text != span.text {
    None
  } else {
    Some(SvgPositionedText::{ text, x_values, y_values })
  }
}

///|
fn span_rendering_matrix(
  span : @text.TextSpan,
  glyphs : Array[@text.TextGlyphEvent],
) -> @text.TextMatrix {
  if glyphs.length() > 0 {
    glyphs[0].rendering_matrix.matrix
  } else {
    @text.TextRenderingMatrix::from_text_state(
      span.text_matrix,
      span.font_size,
      1.0,
      0.0,
      @text.TextMatrix::identity(),
    ).matrix
  }
}

///|
fn write_svg_text_matrix(
  builder : StringBuilder,
  matrix : @text.TextMatrix,
) -> Unit {
  builder.write_string(format_svg_number(matrix.a))
  builder.write_string(" ")
  builder.write_string(format_svg_number(matrix.b))
  builder.write_string(" ")
  builder.write_string(format_svg_number(matrix.c))
  builder.write_string(" ")
  builder.write_string(format_svg_number(matrix.d))
  builder.write_string(" ")
  builder.write_string(format_svg_number(matrix.e))
  builder.write_string(" ")
  builder.write_string(format_svg_number(matrix.f))
}

///|
fn svg_extract_font_size(matrix : @text.TextMatrix) -> Double {
  if matrix.b == 0.0 && matrix.c == 0.0 {
    abs_double(matrix.d)
  } else {
    (matrix.a * matrix.a + matrix.b * matrix.b).sqrt()
  }
}

///|
fn svg_text_transform_without_fontsize(
  matrix : @text.TextMatrix,
  font_size : Double,
  page_height : Double,
) -> @text.TextMatrix {
  let scale = if font_size == 0.0 { 1.0 } else { font_size }
  @text.TextMatrix::from_six(
    matrix.a / scale,
    (0.0 - matrix.b) / scale,
    (0.0 - matrix.c) / scale,
    matrix.d / scale,
    matrix.e,
    page_height - matrix.f,
  )
}

///|
fn svg_text_matrix(
  matrix : @text.TextMatrix,
  page_height : Double,
) -> @text.TextMatrix {
  @text.TextMatrix::from_six(
    matrix.a,
    0.0 - matrix.b,
    0.0 - matrix.c,
    matrix.d,
    matrix.e,
    page_height - matrix.f,
  )
}

///|
fn svg_matrix_is_invertible(matrix : @text.TextMatrix) -> Bool {
  let det = matrix.a * matrix.d - matrix.b * matrix.c
  det != 0.0
}

///|
fn svg_matrix_local_point(
  matrix : @text.TextMatrix,
  x : Double,
  y : Double,
) -> (Double, Double) {
  let det = matrix.a * matrix.d - matrix.b * matrix.c
  let dx = x - matrix.e
  let dy = y - matrix.f
  ((matrix.d * dx - matrix.c * dy) / det, (matrix.a * dy - matrix.b * dx) / det)
}

///|
fn svg_glyph_text(glyph : @text.TextGlyphEvent) -> String? {
  match glyph.unicode {
    @text.UnicodeMapping::Unicode(value) =>
      if value == " " &&
        glyph.glyph.metrics.horizontal_displacement == 0.0 &&
        glyph.glyph.metrics.width_source ==
        @text.GlyphWidthSource::FontDescriptorMissingWidth {
        None
      } else {
        Some(value)
      }
    @text.UnicodeMapping::Unknown(_, _, _) => None
  }
}

///|
fn string_char_count(value : String) -> Int {
  let mut count = 0
  for _char in value {
    count += 1
  }
  count
}

///|
fn write_svg_positioned_tspans(
  builder : StringBuilder,
  text : SvgPositionedText,
  use_position_list : Bool,
) -> Unit {
  if text.x_values.length() == 0 || text.y_values.length() == 0 {
    return
  }
  if use_position_list {
    write_svg_position_list_tspan(builder, text)
  } else {
    write_svg_single_position_tspans(builder, text)
  }
}

///|
fn svg_use_position_list_tspan(
  matrix : @text.TextMatrix,
  text : SvgPositionedText,
) -> Bool {
  string_char_count(text.text) > 10 &&
  svg_text_translation_is_fractional(matrix)
}

///|
fn svg_text_translation_is_fractional(matrix : @text.TextMatrix) -> Bool {
  svg_number_is_fractional(matrix.e) || svg_number_is_fractional(matrix.f)
}

///|
fn svg_number_is_fractional(value : Double) -> Bool {
  let rounded = @math.floor(value + 0.5)
  abs_double(value - rounded) >= 0.001
}

///|
fn write_svg_single_position_tspans(
  builder : StringBuilder,
  text : SvgPositionedText,
) -> Unit {
  let mut index = 0
  for char in text.text {
    if index < text.x_values.length() && index < text.y_values.length() {
      builder.write_string("<tspan x=\"")
      builder.write_string(format_svg_number(text.x_values[index]))
      builder.write_string("\" y=\"")
      builder.write_string(format_svg_number(text.y_values[index]))
      builder.write_string("\">")
      write_xml_escaped_char(builder, char)
      builder.write_string("</tspan>")
    }
    index += 1
  }
}

///|
fn write_svg_position_list_tspan(
  builder : StringBuilder,
  text : SvgPositionedText,
) -> Unit {
  builder.write_string("<tspan x=\"")
  write_svg_number_list(builder, text.x_values)
  builder.write_string("\" y=\"")
  write_svg_number_list(builder, text.y_values)
  builder.write_string("\" xml:space=\"preserve\">")
  write_xml_escaped(builder, text.text)
  builder.write_string("</tspan>")
}

///|
fn write_svg_number_list(
  builder : StringBuilder,
  values : Array[Double],
) -> Unit {
  for index in 0..<values.length() {
    if index > 0 {
      builder.write_string(" ")
    }
    builder.write_string(format_svg_number(values[index]))
  }
}

///|
fn page_svg_font_families(
  page : @reader.PdfPage,
) -> Map[@objects.PdfName, String] {
  let families : Map[@objects.PdfName, String] = Map::new()
  let result : Result[@text.TextResources, @reader.PdfDocumentError] = try? page.text_resources()
  match result {
    Ok(resources) =>
      for name, summary in resources.fonts {
        match font_object_base_font(summary.font_object) {
          Some(base_font) =>
            families[name] = svg_font_family_for_base_font(base_font)
          None => ()
        }
      }
    Err(_) => ()
  }
  families
}

///|
fn page_svg_embedded_fonts(
  page : @reader.PdfPage,
) -> Map[@objects.PdfName, @font.TTFont] {
  let fonts : Map[@objects.PdfName, @font.TTFont] = Map::new()
  let system_cache = new_system_font_cache()
  let result : Result[@text.TextResources, @reader.PdfDocumentError] = try? page.text_resources()
  match result {
    Ok(resources) =>
      for name, summary in resources.fonts {
        match font_object_embedded_truetype_font(summary.font_object) {
          Some(ttf) => fonts[name] = ttf
          None =>
            match font_object_base_font(summary.font_object) {
              Some(base_font) =>
                match
                  resolve_system_font(
                    strip_subset_font_tag(base_font).to_text(),
                    cache=system_cache,
                  ) {
                  Some(ttf) => fonts[name] = ttf
                  None => ()
                }
              None => ()
            }
        }
      }
    Err(_) => ()
  }
  fonts
}

///|
fn font_object_embedded_truetype_font(
  object : @objects.PdfObject,
) -> @font.TTFont? {
  match object {
    @objects.PdfObject::Dictionary(dict) =>
      font_dict_embedded_truetype_font(dict)
    _ => None
  }
}

///|
fn font_dict_embedded_truetype_font(
  dict : @objects.PdfDictionary,
) -> @font.TTFont? {
  match font_dict_direct_embedded_truetype_font(dict) {
    Some(ttf) => Some(ttf)
    None => font_dict_descendant_embedded_truetype_font(dict)
  }
}

///|
fn font_dict_direct_embedded_truetype_font(
  dict : @objects.PdfDictionary,
) -> @font.TTFont? {
  match dict.get(@objects.PdfName::new(b"FontDescriptor")) {
    Some(@objects.PdfObject::Dictionary(descriptor)) =>
      match descriptor.get(@objects.PdfName::new(b"FontFile2")) {
        Some(@objects.PdfObject::Stream(stream)) =>
          parse_svg_font_file2_stream(stream)
        _ => None
      }
    _ => None
  }
}

///|
fn font_dict_descendant_embedded_truetype_font(
  dict : @objects.PdfDictionary,
) -> @font.TTFont? {
  match dict.get(@objects.PdfName::new(b"DescendantFonts")) {
    Some(@objects.PdfObject::Array(fonts)) => {
      for font_object in fonts {
        match font_object_embedded_truetype_font(font_object) {
          Some(ttf) => return Some(ttf)
          None => ()
        }
      }
      None
    }
    _ => None
  }
}

///|
fn parse_svg_font_file2_stream(stream : @objects.PdfStream) -> @font.TTFont? {
  let decoded : Result[Bytes, @filters.PdfFilterError] = try? @filters.decode_stream(
    stream,
  )
  match decoded {
    Ok(bytes) => @font.parse_ttf(bytes)
    Err(_) => None
  }
}

///|
fn span_svg_embedded_font(
  embedded_fonts : Map[@objects.PdfName, @font.TTFont],
  span : @text.TextSpan,
) -> @font.TTFont? {
  match span.font_name {
    Some(name) => embedded_fonts.get(name)
    None => None
  }
}

///|
fn font_object_base_font(object : @objects.PdfObject) -> @objects.PdfName? {
  match object {
    @objects.PdfObject::Dictionary(dict) => font_dict_base_font(dict)
    _ => None
  }
}

///|
fn font_dict_base_font(dict : @objects.PdfDictionary) -> @objects.PdfName? {
  match dict.get(@objects.PdfName::new(b"BaseFont")) {
    Some(@objects.PdfObject::Name(name)) => Some(name)
    _ =>
      match dict.get(@objects.PdfName::new(b"DescendantFonts")) {
        Some(@objects.PdfObject::Array(fonts)) =>
          if fonts.length() > 0 {
            font_object_base_font(fonts[0])
          } else {
            None
          }
        _ => None
      }
  }
}

///|
fn span_svg_font_family(
  font_families : Map[@objects.PdfName, String],
  span : @text.TextSpan,
) -> String {
  match span.font_name {
    Some(name) =>
      match font_families.get(name) {
        Some(family) => family
        None => "sans-serif"
      }
    None => "sans-serif"
  }
}

///|
fn svg_font_family_for_base_font(base_font : @objects.PdfName) -> String {
  let normalized = strip_subset_font_tag(base_font)
  if normalized == @objects.PdfName::new(b"Times-Roman") ||
    normalized == @objects.PdfName::new(b"Times-Bold") ||
    normalized == @objects.PdfName::new(b"Times-Italic") ||
    normalized == @objects.PdfName::new(b"Times-BoldItalic") {
    "Times New Roman, serif"
  } else if normalized == @objects.PdfName::new(b"Courier") ||
    normalized == @objects.PdfName::new(b"Courier-Bold") ||
    normalized == @objects.PdfName::new(b"Courier-Oblique") ||
    normalized == @objects.PdfName::new(b"Courier-BoldOblique") {
    "Courier New, monospace"
  } else if normalized == @objects.PdfName::new(b"Helvetica") ||
    normalized == @objects.PdfName::new(b"Helvetica-Bold") ||
    normalized == @objects.PdfName::new(b"Helvetica-Oblique") ||
    normalized == @objects.PdfName::new(b"Helvetica-BoldOblique") {
    "Helvetica, Arial, sans-serif"
  } else {
    normalized.to_text() + ", sans-serif"
  }
}

///|
fn strip_subset_font_tag(name : @objects.PdfName) -> @objects.PdfName {
  let bytes = name.bytes
  if bytes.length() > 7 && bytes[6] == b'+' && is_subset_font_tag_prefix(bytes) {
    let out : Array[Byte] = []
    for index in 7..<bytes.length() {
      out.push(bytes[index])
    }
    @objects.PdfName::new(Bytes::from_array(out))
  } else {
    name
  }
}

///|
fn is_subset_font_tag_prefix(bytes : Bytes) -> Bool {
  let mut ok = true
  for index in 0..<6 {
    let byte = bytes[index]
    if byte < b'A' || byte > b'Z' {
      ok = false
    }
  }
  ok
}

///|
fn text_program_span_glyphs(
  program : @text.TextProgram,
) -> Array[Array[@text.TextGlyphEvent]] {
  let groups : Array[Array[@text.TextGlyphEvent]] = []
  let mut current : Array[@text.TextGlyphEvent] = []
  let mut collecting = false
  for event in program.events {
    match event {
      @text.TextEvent::SourceString(_) => {
        if collecting && current.length() > 0 {
          groups.push(current)
        }
        current = []
        collecting = true
      }
      @text.TextEvent::GlyphShown(glyph) =>
        if collecting {
          current.push(glyph)
        }
      @text.TextEvent::EmptyString(_) => {
        current = []
        collecting = false
      }
      _ => ()
    }
  }
  if collecting && current.length() > 0 {
    groups.push(current)
  }
  groups
}

///|
fn span_glyphs(
  glyph_groups : Array[Array[@text.TextGlyphEvent]],
  index : Int,
) -> Array[@text.TextGlyphEvent] {
  if index >= 0 && index < glyph_groups.length() {
    glyph_groups[index]
  } else {
    []
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
  let component = clamp_unit(value)
  if component.is_close(0.5, absolute_tolerance=0.000000000001) {
    128
  } else {
    @math.floor(component * 255.0 + 0.499999999).to_int()
  }
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
  let result : Result[@image.ImageData, @image.DecodeError] = try? @image.decode_png(
    data,
  )
  match result {
    Ok(image) => Some(image)
    Err(_) => None
  }
}

///|
fn decode_bmp_image_bytes(data : Bytes) -> @image.ImageData? {
  let result : Result[@image.ImageData, @image.DecodeError] = try? @image.decode_bmp(
    data,
  )
  match result {
    Ok(image) => Some(image)
    Err(_) => None
  }
}

///|
fn decode_jpeg_image_bytes(data : Bytes) -> @image.ImageData? {
  let result : Result[@image.ImageData, @image.DecodeError] = try? @image.decode_jpeg(
    data,
  )
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
    write_xml_escaped_char(builder, char)
  }
}

///|
fn write_xml_escaped_char(builder : StringBuilder, char : Char) -> Unit {
  match char {
    '&' => builder.write_string("&amp;")
    '<' => builder.write_string("&lt;")
    '>' => builder.write_string("&gt;")
    '"' => builder.write_string("&quot;")
    '\'' => builder.write_string("&apos;")
    _ => builder.write_char(char)
  }
}
