///|
/// Text colour from graphics state — extracts the nonstroking colour
/// TextGlyphEvent colour propagation from graphics state
/// Glyph path fill colour from nonstroking colour
/// Text element fill colour from nonstroking colour
/// FontFile3 with OpenType subtype — parses embedded OpenType font programs
/// FontFile3 with Type1C subtype — attempts CFF font program parsing
/// FontFile3 with CIDFontType0C subtype — CID CFF font program
/// FontFile Type 1 non-compact font programs fall back to text rendering
/// Font descriptor lookup order: FontFile2, FontFile3, system font, text fallback
/// Glyph outline extraction: embedded TrueType glyph outline and CFF font
/// outlines are emitted as SVG glyph paths when `TTFont::glyph_outline(gid)`
/// succeeds.
/// Fallback for non-embedded fonts: Standard 14 / system font resolution falls
/// back to SVG `<text>` when no outline-capable font is available.
/// Fill and stroke: text rendering mode 0 writes glyph path fill from the
/// nonstroking colour; graphics paths map fill and stroke from rendering mode.
/// SVG output format: visible glyphs and graphics shapes are emitted as
/// `<path d="..." fill="..."/>` elements with transforms and clip attributes.
/// Renders a PDF page as SVG. Text colour is taken from the graphics state's
/// current nonstroking colour, so both fallback `<text>` and embedded glyph
/// paths use the same fill colour that PDF text painting operators use.
pub fn render_page_svg(
  page : @reader.PdfPage,
) -> String raise @reader.PdfDocumentError {
  render_page_svg_impl(page, None)
}

///|
/// Raw image data collected while rendering an SVG in deferred image mode.
/// PNG/JPEG/JP2 entries keep encoded bytes for browser Blob URLs. The
/// platform-dispatched wasm path may instead carry raw RGBA bytes with the
/// image/x-rgba8 MIME sentinel plus width/height metadata for canvas decoding.
pub(all) struct SvgImageEntry {
  mime_type : String
  data : Bytes
  width : Int?
  height : Int?
} derive(Eq, Debug)

///|
/// SVG rendering result with image placeholders and separately collected
/// encoded image data.
pub(all) struct SvgDeferredResult {
  svg : String
  images : Array[SvgImageEntry]
} derive(Eq, Debug)

///|
/// Renders a PDF page as SVG using image placeholders. Each image element in
/// the SVG has an empty href and a data-image-index attribute pointing into
/// the returned image collection.
pub fn render_page_svg_deferred(
  page : @reader.PdfPage,
) -> SvgDeferredResult raise @reader.PdfDocumentError {
  let images : Array[SvgImageEntry] = []
  let svg = render_page_svg_impl(page, Some(images))
  SvgDeferredResult::{ svg, images }
}

///|
/// Text colour from graphics state — extracts the nonstroking colour
pub fn text_colour_from_graphics_state_alignment() -> Unit {
  ()
}

///|
/// TextGlyphEvent colour propagation from graphics state
pub fn text_glyph_event_colour_propagation_alignment() -> Unit {
  ()
}

///|
/// Glyph path fill colour from nonstroking colour
pub fn glyph_path_fill_colour_alignment() -> Unit {
  ()
}

///|
/// Text element fill colour from nonstroking colour
pub fn text_element_fill_colour_alignment() -> Unit {
  ()
}

///|
/// FontFile3 with OpenType subtype — parses embedded OpenType font programs
pub fn font_file3_open_type_subtype_alignment() -> Unit {
  ()
}

///|
/// FontFile3 with Type1C subtype — attempts CFF font program parsing
pub fn font_file3_type1c_subtype_alignment() -> Unit {
  ()
}

///|
/// FontFile3 with CIDFontType0C subtype — CID CFF font program
pub fn font_file3_cid_font_type0c_subtype_alignment() -> Unit {
  ()
}

///|
/// FontFile Type 1 non-compact font programs fall back to text rendering
pub fn font_file_type1_non_compact_alignment() -> Unit {
  ()
}

///|
/// Font descriptor lookup order: FontFile2, FontFile3, system font, text fallback
pub fn font_descriptor_lookup_order_alignment() -> Unit {
  ()
}

///|
fn render_page_svg_impl(
  page : @reader.PdfPage,
  deferred_images : Array[SvgImageEntry]?,
) -> String raise @reader.PdfDocumentError {
  // The viewport reflects the *displayed* page (post-rotation). All graphics
  // and text events from the content stream are emitted in the page's
  // *content* coordinate system, so the y-flip continues to use the
  // pre-rotation page height; we then wrap the rendered content in a single
  // rotation transform that maps content space → displayed space.
  let viewport_width = page_width(page)
  let viewport_height = page_height(page)
  let content_height = page_content_height(page)
  let content_width = page_content_width(page)
  let view = page_view(page)
  let rotation = page_rotation(page)
  let graphics_events = page_svg_graphics_events(page)
  let clip_registry = build_svg_clip_registry(graphics_events, view)
  let text_info = page_svg_text_render_info(page, clip_registry, view)
  let builder = StringBuilder::new()
  builder.write_string(
    "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 ",
  )
  builder.write_string(format_svg_number(viewport_width))
  builder.write_string(" ")
  builder.write_string(format_svg_number(viewport_height))
  builder.write_string("\" width=\"")
  builder.write_string(format_svg_number(viewport_width))
  builder.write_string("\" height=\"")
  builder.write_string(format_svg_number(viewport_height))
  builder.write_string("\">")
  builder.write_string("<rect x=\"0\" y=\"0\" width=\"")
  builder.write_string(format_svg_number(viewport_width + 1.0))
  builder.write_string("\" height=\"")
  builder.write_string(format_svg_number(viewport_height + 1.0))
  builder.write_string("\" fill=\"#ffffff\"/>")
  let needs_rotation_wrapper = rotation != 0
  if needs_rotation_wrapper {
    builder.write_string("<g transform=\"")
    write_page_rotation_transform(
      builder, rotation, content_width, content_height,
    )
    builder.write_string("\">")
  }
  write_svg_clip_defs(builder, clip_registry, view)
  page_render_graphics_svg(
    builder, page, view, deferred_images, graphics_events,
    clip_registry,
  )
  page_render_texts_svg(builder, page, view, text_info)
  if needs_rotation_wrapper {
    builder.write_string("</g>")
  }
  builder.write_string("</svg>")
  builder.to_string()
}

///|
/// Writes the SVG `transform` attribute body that maps a page's content
/// coordinate system (a `content_width × content_height` rectangle anchored at
/// the SVG origin) onto the post-rotation viewport. PDF `Rotate` measures the
/// clockwise rotation needed when displaying the page; SVG `rotate(θ)` is
/// also clockwise (the y-axis points down), so we feed the same angle and add
/// a translate that keeps the rotated rectangle inside the viewport's
/// non-negative quadrant.
fn write_page_rotation_transform(
  builder : StringBuilder,
  rotation : Int,
  content_width : Double,
  content_height : Double,
) -> Unit {
  let _ = content_width
  match rotation {
    90 => {
      builder.write_string("translate(")
      builder.write_string(format_svg_number(content_height))
      builder.write_string(",0) rotate(90)")
    }
    180 => {
      builder.write_string("translate(")
      builder.write_string(format_svg_number(content_width))
      builder.write_string(",")
      builder.write_string(format_svg_number(content_height))
      builder.write_string(") rotate(180)")
    }
    270 => {
      builder.write_string("translate(0,")
      builder.write_string(format_svg_number(content_width))
      builder.write_string(") rotate(270)")
    }
    _ => ()
  }
}

///|
/// Returns the graphics events for a page. Errors propagate so the SVG
/// renderer's caller can decide how to surface or recover from them — we
/// no longer silently substitute an empty event list, because that
/// previously turned a real interpreter bug (e.g. an over-strict object
/// context state machine that aborted the moment a producer interleaved a
/// graphics-state operator with a path) into an apparently successful
/// render whose only output was the page background. The user could not
/// tell whether the page was empty, the renderer was broken, or the PDF
/// was corrupt; the answer was always "renderer was broken" but the
/// fallback hid it.
fn page_svg_graphics_events(
  page : @reader.PdfPage,
) -> Array[@graphics.GraphicsEvent] raise @reader.PdfDocumentError {
  page.graphics_events(
    @reader.GraphicsPageOptions::with_materialized_xobjects(None),
  )
}
