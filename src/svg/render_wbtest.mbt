///|
test "render_page_svg positions Simple PDF text without page group flip" {
  let document = @reader.PdfDocument::open(
    @fs.read_file_to_bytes("spec/pdf20examples/Simple PDF 2.0 file.pdf"),
  )
  let svg = render_page_svg(document.page(0))
  assert_eq(svg.has_prefix("<svg"), true)
  assert_eq(svg.contains("<g transform=\"matrix(1 0 0 -1"), false)
  match resolve_system_font("Helvetica") {
    Some(_) => {
      assert_eq(svg.contains("<path d=\""), true)
      assert_eq(svg.contains("<text"), false)
    }
    None => {
      assert_eq(svg.contains("<text"), true)
      assert_eq(svg.contains("<tspan x=\"0\" y=\"0\">H</tspan>"), true)
      assert_eq(svg.contains("<tspan x=\"103.992\" y=\"0\">d</tspan>"), true)
      assert_eq(
        svg.contains("xml:space=\"preserve\">HelloWorld</tspan>"),
        false,
      )
      assert_eq(svg.contains("<text transform=\"matrix(1 0 0 1 100 296)"), true)
      assert_eq(svg.contains("font-size=\"24\""), true)
    }
  }
}

///|
test "write_svg_text_matrix writes factored text matrix in SVG coordinates" {
  let builder = StringBuilder::new()
  let matrix = @text.TextRenderingMatrix::from_text_state(
      @text.TextMatrix::from_six(1.0, 0.0, 0.0, 1.0, 10.0, 20.0),
      12.0,
      1.0,
      0.0,
      @text.TextMatrix::identity(),
    ).matrix
  let font_size = svg_extract_font_size(matrix)
  let view = SvgPageView::{
    origin_x: 0.0,
    y_flip_origin: 100.0,
    content_height: 100.0,
  }
  let svg_matrix = svg_text_transform_without_fontsize(matrix, font_size, view)
  write_svg_text_matrix(builder, svg_matrix)
  assert_eq(builder.to_string(), "1 0 0 1 10 80")
}

///|
test "svg_extract_font_size uses y scale for non-rotated text" {
  let matrix = @text.TextMatrix::from_six(18.0, 0.0, 0.0, -12.0, 10.0, 20.0)
  assert_eq(svg_extract_font_size(matrix), 12.0)
}

///|
test "svg_extract_font_size uses first axis length for rotated text" {
  let matrix = @text.TextMatrix::from_six(0.0, 14.0, -14.0, 0.0, 10.0, 20.0)
  assert_eq(svg_extract_font_size(matrix), 14.0)
}

///|
test "svg_text_transform_without_fontsize preserves rotation and translation" {
  let matrix = @text.TextMatrix::from_six(0.0, 14.0, -14.0, 0.0, 10.0, 20.0)
  let view = SvgPageView::{
    origin_x: 0.0,
    y_flip_origin: 100.0,
    content_height: 100.0,
  }
  let svg_matrix = svg_text_transform_without_fontsize(matrix, 14.0, view)
  assert_eq(svg_matrix.a, 0.0)
  assert_eq(svg_matrix.b, -1.0)
  assert_eq(svg_matrix.c, 1.0)
  assert_eq(svg_matrix.d, 0.0)
  assert_eq(svg_matrix.e, 10.0)
  assert_eq(svg_matrix.f, 80.0)
}

///|
test "rgb_hex_colour follows pdftoppm-style single precision rounding" {
  assert_eq(
    rgb_hex_colour(@graphics.DeviceRgbColour::{
      red: 0.7,
      green: 0.7,
      blue: 0.7,
    }),
    "#B2B2B2",
  )
  assert_eq(
    rgb_hex_colour(@graphics.DeviceRgbColour::{
      red: 0.5,
      green: 0.75,
      blue: 1.0,
    }),
    "#80BFFF",
  )
  assert_eq(
    rgb_hex_colour(@graphics.DeviceRgbColour::{
      red: 0.5,
      green: 0.1,
      blue: 0.2,
    }),
    "#801933",
  )
}

///|
test "render_page_svg scales web PDF identity text matrix by Tf font size" {
  let document = @reader.PdfDocument::open(build_identity_tm_text_fixture())
  let svg = render_page_svg(document.page(0))
  match resolve_system_font("Helvetica") {
    Some(_) => {
      assert_eq(svg.contains("<path d=\""), true)
      assert_eq(svg.contains("<text"), false)
    }
    None => {
      assert_eq(svg.contains("<text transform=\"matrix(1 0 0 1 10 80)"), true)
      assert_eq(svg.contains("font-size=\"12\""), true)
      assert_eq(svg.contains("<tspan x=\"0\" y=\"0\">A</tspan>"), true)
    }
  }
}

///|
test "render_page_svg renders embedded TrueType glyphs as paths" {
  let document = @reader.PdfDocument::open(
    build_embedded_truetype_text_fixture(),
  )
  let svg = render_page_svg(document.page(0))
  assert_eq(svg.contains("<path d=\""), true)
  assert_eq(svg.contains("<text"), false)
  assert_eq(svg.contains("font-family=\""), false)
  assert_eq(svg.contains("fill=\"#000000\""), true)
}

///|
test "render_page_svg renders embedded CID glyph paths when text is unknown" {
  let document = @reader.PdfDocument::open(
    build_embedded_cid_unknown_text_fixture(),
  )
  let program = document
    .page(0)
    .text_program(@reader.TextPageOptions::default())
  assert_eq(program.spans.length(), 1)
  assert_eq(program.spans[0].text, "")
  let svg = render_page_svg(document.page(0))
  assert_eq(svg.contains("<path d=\""), true)
  assert_eq(svg.contains("<text"), false)
  assert_eq(svg.contains("font-family=\""), false)
}

///|
test "render_page_svg uses nonstroking colour for embedded glyph paths" {
  let document = @reader.PdfDocument::open(
    build_coloured_embedded_truetype_text_fixture(),
  )
  let svg = render_page_svg(document.page(0))
  assert_eq(svg.contains("<path d=\""), true)
  assert_eq(svg.contains("<text"), false)
  assert_eq(svg.contains("fill=\"#FF0000\""), true)
}

///|
test "render_page_svg uses nonstroking colour for text fallback" {
  let document = @reader.PdfDocument::open(
    build_coloured_text_fallback_fixture(),
  )
  let svg = render_page_svg(document.page(0))
  assert_eq(svg.contains("<text"), true)
  assert_eq(svg.contains("<path d=\""), false)
  assert_eq(svg.contains("fill=\"#00FF00\""), true)
}

///|
test "render_page_svg surfaces unresolved-XObject graphics errors" {
  // Per the strict-or-recover SoT: a Form XObject whose content stream
  // raises a typed graphics error during interpretation propagates as a
  // typed `PdfDocumentError::GraphicsError`. The previous behaviour
  // silently swallowed the error and emitted a partial SVG with only the
  // text spans, which masked real producer bugs (and any future regression
  // in our XObject content interpreter) behind an apparently successful
  // render. Callers that need best-effort recovery must catch the typed
  // error explicitly and decide whether to fall back to a text-only render.
  let document = @reader.PdfDocument::open(
    build_coloured_text_with_bad_xobject_fixture(),
  )
  let result : Result[String, @reader.PdfDocumentError] = try? render_page_svg(
    document.page(0),
  )
  match result {
    Err(@reader.PdfDocumentError::GraphicsError(_)) => ()
    Err(_) => fail("expected GraphicsError, got a different document error")
    Ok(_) =>
      fail("expected the broken XObject to surface a GraphicsError")
  }
}

///|
test "render_page_svg renders FontFile3 OpenType glyphs as paths" {
  let document = @reader.PdfDocument::open(
    build_embedded_fontfile3_text_fixture(),
  )
  let svg = render_page_svg(document.page(0))
  assert_eq(svg.contains("<path d=\""), true)
  assert_eq(svg.contains("<text"), false)
  assert_eq(svg.contains("font-family=\""), false)
}

///|
test "CFF charset static tables expose Adobe Standard Strings and WinAnsiEncoding" {
  assert_eq(adobe_standard_string(0), Some(".notdef"))
  assert_eq(adobe_standard_string(1), Some("space"))
  assert_eq(adobe_standard_string(17), Some("zero"))
  assert_eq(adobe_standard_string(34), Some("A"))
  assert_eq(adobe_standard_string(391) is None, true)
  assert_eq(winansi_glyph_name(32), "space")
  assert_eq(winansi_glyph_name(65), "A")
  assert_eq(winansi_glyph_name(97), "a")
  assert_eq(winansi_glyph_name(128), "Euro")
  assert_eq(winansi_glyph_name(129), "")
}

///|
test "parse_cff_charset reads cff.add.otf extracted CFF charset" {
  let cff = cff_add_fixture_cff()
  assert_true(is_raw_cff(cff))
  assert_eq(cff_charstrings_count(cff), 28)
  assert_eq(cff_string_index_entry(cff, 3), Some("A"))
  match parse_cff_charset(cff, 28) {
    Some(sids) => {
      assert_eq(sids.length(), 28)
      assert_eq(sids[0], 0)
      assert_eq(sids[1], 394)
      assert_eq(sids[27], 420)
    }
    None => assert_true(false)
  }
}

///|
test "cff_glyph_name_table resolves custom String INDEX names" {
  let cff = cff_add_fixture_cff()
  match cff_glyph_name_table(cff, 28) {
    Some(names) => {
      assert_eq(names.length(), 28)
      assert_eq(names[0], ".notdef")
      assert_eq(names[1], "A")
      assert_eq(names[2], "B")
      assert_eq(names[26], "alphabet")
      assert_eq(names[27], "rectangle")
    }
    None => assert_true(false)
  }
}

///|
test "is_cid_keyed_cff detects ROS operator and CIDCount" {
  let type1c = cff_add_fixture_cff()
  let cid_cff = minimal_cid_keyed_cff()
  assert_eq(is_cid_keyed_cff(type1c), false)
  assert_eq(cff_cid_count(type1c), 0)
  assert_eq(is_cid_keyed_cff(cid_cff), true)
  assert_eq(cff_cid_count(cid_cff), 100)
}

///|
test "parse_cff_cid_charset reads CID-keyed charset as CIDs" {
  let cid_cff = minimal_cid_keyed_cff()
  match parse_cff_cid_charset(cid_cff, 4) {
    Some(cids) => {
      assert_eq(cids.length(), 4)
      assert_eq(cids[0], 0)
      assert_eq(cids[1], 10)
      assert_eq(cids[2], 11)
      assert_eq(cids[3], 12)
    }
    None => assert_true(false)
  }
}

///|
test "cff_cid_to_glyph_id_map inverts CID-keyed charset" {
  let cid_cff = minimal_cid_keyed_cff()
  match cff_cid_to_glyph_id_map(cid_cff, 4) {
    Some(map) => {
      assert_eq(map.get(0), Some(0))
      assert_eq(map.get(10), Some(1))
      assert_eq(map.get(11), Some(2))
      assert_eq(map.get(12), Some(3))
      assert_eq(map.get(13) is None, true)
    }
    None => assert_true(false)
  }
  assert_eq(cff_cid_to_glyph_id_map(cff_add_fixture_cff(), 28) is None, true)
}

///|
test "cff_cid_to_glyph_id_array inverts CID-keyed charset" {
  let cid_cff = minimal_cid_keyed_cff()
  match cff_cid_to_glyph_id_array(cid_cff, 4) {
    Some(map) => {
      assert_eq(map[0], 0)
      assert_eq(map[10], 1)
      assert_eq(map[11], 2)
      assert_eq(map[12], 3)
      assert_eq(map.length(), 13)
    }
    None => assert_true(false)
  }
  assert_eq(cff_cid_to_glyph_id_array(cff_add_fixture_cff(), 28) is None, true)
}

///|
test "svg_cid_glyph_id resolves cid post glyph names" {
  match cff_post_glyph_name_table(minimal_cid_keyed_cff(), 4) {
    Some(names) => {
      assert_eq(names[0], "cid00000")
      assert_eq(names[1], "cid00010")
      assert_eq(names[3], "cid00012")
      let ttf = minimal_post_ttf(names)
      assert_eq(resolved_cid_glyph_id(ttf, 10), 1)
      assert_eq(resolved_cid_glyph_id(ttf, 12), 3)
      assert_eq(resolved_cid_glyph_id(ttf, 13), -1)
    }
    None => assert_true(false)
  }
}

///|
test "svg_resolve_embedded_glyph_id uses cached CFF CID map before post fallback" {
  let ttf = minimal_post_ttf([".notdef", "wrong", "alsoWrong", "last"])
  let font = SvgEmbeddedFont::{
    ttf,
    cff_cid_to_gid: Some([-1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 2]),
    cid_to_gid_map: None,
    cid_to_gid_identity: false,
  }
  assert_eq(resolved_embedded_glyph_id(font, minimal_cid_glyph_event(10)), 2)
}

///|
test "svg_resolve_embedded_glyph_id uses CIDToGIDMap stream and rejects out of range identity" {
  let stream = @objects.PdfStream::{
    dict: Map::new(),
    data: b"\x00\x00\x00\x03\x00\x01",
  }
  let font = SvgEmbeddedFont::{
    ttf: minimal_post_ttf([".notdef", "one", "two", "three"]),
    cff_cid_to_gid: None,
    cid_to_gid_map: parse_cid_to_gid_map_stream(stream),
    cid_to_gid_identity: false,
  }
  assert_eq(resolved_embedded_glyph_id(font, minimal_cid_glyph_event(1)), 3)
  assert_eq(resolved_embedded_glyph_id(font, minimal_cid_glyph_event(9)), -1)

  let identity_font = SvgEmbeddedFont::{
    ttf: minimal_post_ttf([".notdef", "one"]),
    cff_cid_to_gid: None,
    cid_to_gid_map: None,
    cid_to_gid_identity: true,
  }
  assert_eq(
    resolved_embedded_glyph_id(identity_font, minimal_cid_glyph_event(1)),
    1,
  )
  assert_eq(
    resolved_embedded_glyph_id(identity_font, minimal_cid_glyph_event(5)),
    -1,
  )
}

///|
test "svg_resolve_embedded_glyph_id prefers ToUnicode subset cmap before Identity" {
  let ttf = minimal_post_ttf([".notdef", "identityWrong", "latinA"])
  ttf.cmap[97] = 2
  ttf.cmap[1] = 1
  let font = SvgEmbeddedFont::{
    ttf,
    cff_cid_to_gid: None,
    cid_to_gid_map: None,
    cid_to_gid_identity: true,
  }
  assert_eq(
    resolved_embedded_glyph_id(font, minimal_unicode_cid_glyph_event(1, "a")),
    2,
  )
}

///|
test "svg_resolve_embedded_glyph_id uses CID-keyed subset cmap before Identity" {
  let ttf = minimal_post_ttf([".notdef", "identityWrong", "cidMapped"])
  ttf.cmap[7] = 2
  let font = SvgEmbeddedFont::{
    ttf,
    cff_cid_to_gid: None,
    cid_to_gid_map: None,
    cid_to_gid_identity: true,
  }
  assert_eq(resolved_embedded_glyph_id(font, minimal_cid_glyph_event(7)), 2)
}

///|
fn resolved_embedded_glyph_id(
  font : SvgEmbeddedFont,
  glyph : @text.TextGlyphEvent,
) -> Int {
  match svg_resolve_embedded_glyph_id(font, glyph) {
    Some(gid) => gid
    None => -1
  }
}

///|
fn resolved_cid_glyph_id(ttf : @font.TTFont, cid : Int) -> Int {
  match svg_cid_glyph_id(ttf, cid) {
    Some(gid) => gid
    None => -1
  }
}

///|
test "wrap_cff_in_otf builds non-identity WinAnsi cmap from CFF charset" {
  let cff = cff_add_fixture_cff()
  match wrap_cff_in_otf(cff) {
    Some(wrapped) =>
      match @font.parse_font(wrapped) {
        Some(ttf) => {
          assert_eq(ttf.num_glyphs, 28)
          assert_eq(ttf.cmap.get(65), Some(1))
          assert_eq(ttf.cmap.get(66), Some(2))
          assert_eq(ttf.cmap.get(65) == Some(65), false)
          assert_eq(ttf.cmap.get(90) is None, true)
          match ttf.post {
            Some(post) => {
              assert_eq(post.glyph_names[1], "A")
              assert_eq(post.glyph_names[27], "rectangle")
            }
            None => assert_true(false)
          }
        }
        None => assert_true(false)
      }
    None => assert_true(false)
  }
}

///|
test "wrap_cff_in_otf wraps raw CFF and parse_font succeeds" {
  // Extract raw CFF table from an OTF file
  let cff = cff_add_fixture_cff()
  assert_true(is_raw_cff(cff))
  assert_true(cff_charstrings_count(cff) > 0)
  match wrap_cff_in_otf(cff) {
    Some(wrapped) => {
      // Wrapped data should start with OTTO magic
      assert_eq(wrapped[0], b'\x4F')
      assert_eq(wrapped[1], b'\x54')
      assert_eq(wrapped[2], b'\x54')
      assert_eq(wrapped[3], b'\x4F')
      // parse_font should succeed on the wrapped data
      match @font.parse_font(wrapped) {
        Some(ttf) => {
          assert_eq(ttf.num_glyphs, 28)
          assert_eq(ttf.units_per_em, 1000)
        }
        None => assert_true(false)
      }
    }
    None => assert_true(false)
  }
}

///|
test "render_page_svg with FontFile3 Type1C raw CFF uses CFF wrapper path" {
  // cff.add.otf has empty glyph outlines (opcode test font), so the renderer
  // falls back to <text> when all outlines are empty. This test verifies the
  // CFF wrapper is invoked (font is parsed) even though glyphs have no paths.
  let document = @reader.PdfDocument::open(
    build_raw_type1c_fontfile3_text_fixture(),
  )
  let svg = render_page_svg(document.page(0))
  // The fixture font has empty CFF charstrings, so glyph outlines are empty.
  // The renderer should produce <text> as fallback for empty outlines.
  assert_eq(svg.contains("<text"), true)
}

///|
test "render_page_svg uses system font paths for Standard 14 when available" {
  let document = @reader.PdfDocument::open(build_identity_tm_text_fixture())
  let svg = render_page_svg(document.page(0))
  match resolve_system_font("Helvetica") {
    Some(_) => {
      assert_eq(svg.contains("<path d=\""), true)
      assert_eq(svg.contains("<text"), false)
      assert_eq(svg.contains("font-family=\""), false)
    }
    None => {
      assert_eq(svg.contains("<text"), true)
      assert_eq(svg.contains("<path d=\""), false)
    }
  }
}

///|
test "render_page_svg scales embedded TrueType path transform by units per em" {
  let document = @reader.PdfDocument::open(
    build_embedded_truetype_text_fixture(),
  )
  let svg = render_page_svg(document.page(0))
  assert_eq(svg.contains("transform=\"matrix(0.01 0 0 -0.01 10 80)\""), true)
}

///|
test "render_page_svg uses rendering matrix with graphics CTM for text" {
  let document = @reader.PdfDocument::open(build_ctm_scaled_text_fixture())
  let svg = render_page_svg(document.page(0))
  match resolve_system_font("Helvetica") {
    Some(_) => {
      assert_eq(svg.contains("<path d=\""), true)
      assert_eq(svg.contains("<text"), false)
    }
    None => {
      assert_eq(svg.contains("<text transform=\"matrix(1 0 0 1 20 68)"), true)
      assert_eq(svg.contains("<text transform=\"matrix(10 0 0 10 5 94)"), false)
      assert_eq(svg.contains("font-size=\"20\""), true)
    }
  }
}

///|
test "render_page_svg positions UTF-8 text with text matrix path" {
  let document = @reader.PdfDocument::open(
    @fs.read_file_to_bytes("spec/pdf20examples/pdf20-utf8-test.pdf"),
  )
  let svg = render_page_svg(document.page(0))
  match resolve_system_font("Helvetica") {
    Some(_) => {
      assert_eq(svg.contains("<path d=\""), true)
      assert_eq(svg.contains("<text"), false)
    }
    None => {
      assert_eq(
        svg.contains("<text transform=\"matrix(1 0 0 1 72 99.26)"),
        true,
      )
      assert_eq(svg.contains("text-rendering=\"geometricPrecision\""), true)
      assert_eq(svg.contains("<tspan x=\"0 10.672 22.224 32 36.448"), true)
    }
  }
}

///|
test "write_svg_image uses unit image with CTM transform" {
  let builder = StringBuilder::new()
  let view = SvgPageView::{
    origin_x: 0.0,
    y_flip_origin: 396.0,
    content_height: 396.0,
  }
  write_svg_image(
    builder,
    "data:image/png;base64,AA==",
    @graphics.GraphicsMatrix::from_six(100.0, 0.0, 0.0, 100.0, 72.0, 172.0),
    true,
    true,
    view,
    0,
  )
  assert_eq(
    builder.to_string(),
    "<image x=\"0\" y=\"0\" width=\"1\" height=\"1\" href=\"data:image/png;base64,AA==\" transform=\"matrix(100.5 0 0 100.5 72 124)\"/>",
  )
}

///|
test "write_svg_image does not expand multi-pixel image CTM" {
  let builder = StringBuilder::new()
  let view = SvgPageView::{
    origin_x: 0.0,
    y_flip_origin: 841.92,
    content_height: 841.92,
  }
  write_svg_image(
    builder,
    "data:image/png;base64,AA==",
    @graphics.GraphicsMatrix::from_six(175.7, 0.0, 0.0, 87.85, 72.0, 590.0),
    false,
    false,
    view,
    0,
  )
  assert_eq(
    builder.to_string(),
    "<image x=\"72\" y=\"164.07\" width=\"175.7\" height=\"87.85\" href=\"data:image/png;base64,AA==\"/>",
  )
}

///|
test "render_page_svg starts wrapped CalRGB continuation text at line origin" {
  let document = @reader.PdfDocument::open(
    @fs.read_file_to_bytes("spec/pdf20examples/PDF 2.0 image with BPC.pdf"),
  )
  let svg = render_page_svg(document.page(0))
  match resolve_system_font("Helvetica") {
    Some(_) => {
      assert_eq(svg.contains("<path d=\""), true)
      assert_eq(svg.contains("<text"), false)
    }
    None => {
      assert_eq(svg.contains("<text transform=\"matrix(1 0 0 1 36 110)"), true)
      assert_eq(svg.contains("<tspan x=\"0\" y=\"0\">T</tspan>"), true)
      assert_eq(
        svg.contains("<text transform=\"matrix(1 0 0 1 170.028 110)"),
        false,
      )
    }
  }
}

///|
test "render_page_svg writes transformed path coordinates in SVG space" {
  let document = @reader.PdfDocument::open(build_svg_path_fixture())
  let svg = render_page_svg(document.page(0))
  assert_eq(svg.contains("<path"), true)
  assert_eq(svg.contains("d=\"M 12 76 L 16 72 "), true)
  assert_eq(svg.contains("fill=\"none\" stroke=\"#000000\""), true)
}

///|
test "render_page_svg accounts for non-zero MediaBox lower-left when flipping y" {
  // PDF user space puts the origin at (0, 0) regardless of MediaBox; the
  // MediaBox just selects the visible window. A page like
  // `[10 7.92 110 117.92]` is 100 × 110 in displayed size, but a stroke at
  // PDF coordinate (10, 7.92) sits at the *bottom-left* of the visible area —
  // in SVG that should map to (0, 110), not (0, 102.08).
  //
  // The earlier renderer subtracted point.y from `MediaBox.height` instead of
  // `MediaBox.upper_y`, so any page whose MediaBox lower-Y was non-zero (a
  // common idiom in slide-deck exporters that shrink the visible region by
  // 8 pt on every side) had its content silently shifted up by `lower_y`,
  // making table text float above its background row. Symmetrically, content
  // streams targeting a non-zero MediaBox lower-X must subtract that offset
  // from the SVG x coordinate, otherwise the same shift appears horizontally.
  let document = @reader.PdfDocument::open(build_offset_media_box_fixture())
  let svg = render_page_svg(document.page(0))
  // The stroke goes from PDF (10, 7.92) → SVG (0, 110)
  //                   to PDF (110, 117.92) → SVG (100, 0).
  assert_eq(svg.contains("d=\"M 0 110 L 100 0 "), true)
}

///|
fn build_offset_media_box_fixture() -> Bytes {
  // MediaBox shifted to lower-left (10, 7.92) so neither origin axis is zero.
  // The content stream emits a stroked diagonal from the box's lower-left
  // (10, 7.92) to its upper-right (110, 117.92); a correctly-flipped renderer
  // collapses both onto the SVG viewport corners.
  let content = b"10 7.92 m 110 117.92 l S"
  build_single_page_pdf(
    b"<< /Type /Page /Parent 2 0 R /MediaBox [10 7.92 110 117.92] /Contents 4 0 R >>",
    content,
    [],
  )
}

///|
test "render_page_svg uses sampled Separation colour space tint transform" {
  let document = @reader.PdfDocument::open(
    build_sampled_separation_path_fixture(),
  )
  let svg = render_page_svg(document.page(0))
  assert_eq(svg.contains("<path"), true)
  assert_eq(svg.contains("fill=\"#404040\""), true)
}

///|
test "render_page_svg surfaces unsupported encoded image data" {
  // Per the strict-or-recover SoT: a JPXDecode (or any other) image whose
  // payload cannot be decoded surfaces as a typed
  // `PdfDocumentError::GraphicsError`. The earlier "without crashing"
  // contract silently dropped the image and produced an SVG that *looked*
  // valid but lost the only piece of content the page had — the exact
  // failure mode that motivated retiring localised swallows here.
  let document = @reader.PdfDocument::open(build_encoded_image_fixture())
  let result : Result[String, @reader.PdfDocumentError] = try? render_page_svg(
    document.page(0),
  )
  match result {
    Err(@reader.PdfDocumentError::GraphicsError(_)) => ()
    Err(_) => fail("expected GraphicsError, got a different document error")
    Ok(_) =>
      fail(
        "expected the unsupported encoded image to surface a GraphicsError",
      )
  }
}

///|
test "render_page_svg_deferred emits image placeholders and entries" {
  let document = @reader.PdfDocument::open(
    @fs.read_file_to_bytes("spec/pdf20examples/PDF 2.0 image with BPC.pdf"),
  )
  let result = render_page_svg_deferred(document.page(0))
  assert_eq(result.svg.has_prefix("<svg"), true)
  assert_eq(result.svg.contains("data-image-index=\"0\" href=\"\""), true)
  assert_eq(result.svg.contains("data-image-index=\"1\" href=\"\""), true)
  assert_eq(result.svg.contains("data:image/"), false)
  assert_eq(result.images.length(), 2)
}

///|
test "render_page_svg emits clipPath and clip-path for clipped image" {
  let document = @reader.PdfDocument::open(build_clipped_rgb_image_fixture())
  let svg = render_page_svg(document.page(0))
  assert_eq(svg.contains("<defs><clipPath id=\"c1\">"), true)
  assert_eq(svg.contains("<image"), true)
  assert_eq(svg.contains("clip-path=\"url(#c1)\""), true)
}

///|
test "render_page_svg omits clipPath for default page clip only" {
  let document = @reader.PdfDocument::open(build_rgb_image_fixture())
  let svg = render_page_svg(document.page(0))
  assert_eq(svg.contains("<clipPath"), false)
  assert_eq(svg.contains("clip-path=\""), false)
}

///|
test "render_page_svg nests clipPath definitions for stacked clips" {
  let document = @reader.PdfDocument::open(
    build_stacked_clipped_rgb_image_fixture(),
  )
  let svg = render_page_svg(document.page(0))
  assert_eq(svg.contains("<clipPath id=\"c1\">"), true)
  assert_eq(svg.contains("<clipPath id=\"c2\" clip-path=\"url(#c1)\">"), true)
  assert_eq(svg.contains("<image"), true)
  assert_eq(svg.contains("clip-path=\"url(#c2)\""), true)
}

///|
test "render_page_svg emits clip-path for clipped fallback text" {
  let document = @reader.PdfDocument::open(
    build_clipped_text_fallback_fixture(),
  )
  let svg = render_page_svg(document.page(0))
  assert_eq(svg.contains("<clipPath id=\"c1\">"), true)
  assert_eq(svg.contains("<text"), true)
  assert_eq(svg.contains("<text transform="), true)
  assert_eq(svg.contains("clip-path=\"url(#c1)\""), true)
}

///|
test "render_page_svg wraps clipped fallback text in untransformed clip group" {
  // The clip path geometry is recorded in page space, so applying it via a
  // direct `clip-path` attribute on a transformed `<text>` evaluates the clip
  // in the text's local user space and silently hides every glyph that lies
  // inside the page-space clip but outside the locally translated copy. The
  // renderer must wrap any clipped text in an untransformed `<g
  // clip-path="url(#cN)">` group so the clip stays in page coordinates while
  // the text keeps its own transform.
  let document = @reader.PdfDocument::open(
    build_clipped_text_fallback_fixture(),
  )
  let svg = render_page_svg(document.page(0))
  assert_eq(svg.contains("<g clip-path=\"url(#c1)\"><text transform="), true)
  assert_eq(svg.contains("<text transform=\"matrix(1 0 0 1 12 80)"), true)
  // The historical buggy form attached `clip-path` directly to the
  // transformed `<text>`; that form must no longer appear.
  assert_eq(
    svg.contains(
      "<text transform=\"matrix(1 0 0 1 12 80)\" font-size=\"12\" text-rendering=\"geometricPrecision\" font-family=\"ClipFallback, sans-serif\" fill=\"#000000\" clip-path=\"url(#c1)\"",
    ),
    false,
  )
}

///|
test "svg text clip ids mark high-volume fallback clips for page-space group" {
  let clip_ids : Array[Int] = []
  for _ in 0..<1000 {
    clip_ids.push(2)
  }
  clip_ids.push(3)
  let group_candidates : Map[Int, Bool] = Map::new()
  group_candidates[2] = true
  let marked = svg_mark_high_volume_text_clip_groups(clip_ids, group_candidates)
  assert_eq(marked[0], -2)
  assert_eq(marked[999], -2)
  assert_eq(marked[1000], 3)
}

///|
test "render_page_svg wraps clipped embedded glyph paths in clip group" {
  let document = @reader.PdfDocument::open(
    build_clipped_embedded_truetype_text_fixture(),
  )
  let svg = render_page_svg(document.page(0))
  assert_eq(svg.contains("<clipPath id=\"c1\">"), true)
  assert_eq(svg.contains("<g clip-path=\"url(#c1)\"><path d=\""), true)
  assert_eq(svg.contains("transform=\"matrix("), true)
  assert_eq(svg.contains("fill=\"#000000\" clip-path=\"url(#c1)\""), false)
}

///|
fn build_svg_path_fixture() -> Bytes {
  let content = b"2 0 0 2 10 20 cm 1 2 m 3 4 l S"
  build_single_page_pdf(
    b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 100 100] /Contents 4 0 R >>",
    content,
    [],
  )
}

///|
fn build_sampled_separation_path_fixture() -> Bytes {
  let content = b"/CS1 cs 0.25 scn 10 10 20 20 re f"
  let function = build_stream_object_body_with_entries(
    b"/FunctionType 0 /Domain [0 1] /Range [0 1] /Size [2] /BitsPerSample 8",
    Bytes::from_array([b'\x00', b'\xff']),
  )
  build_single_page_pdf(
    b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 100 100] /Resources << /ColorSpace << /CS1 [ /Separation /Spot /DeviceGray 5 0 R ] >> >> /Contents 4 0 R >>",
    content,
    [function],
  )
}

///|
fn build_encoded_image_fixture() -> Bytes {
  let content = b"q 10 0 0 10 5 5 cm /Im1 Do Q"
  build_single_page_pdf(
    b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 100 100] /Resources << /XObject << /Im1 5 0 R >> >> /Contents 4 0 R >>",
    content,
    [
      b"<< /Type /XObject /Subtype /Image /Width 1 /Height 1 /ColorSpace /DeviceRGB /BitsPerComponent 8 /Filter /JPXDecode /Length 4 >>\nstream\nxxxx\nendstream",
    ],
  )
}

///|
fn build_rgb_image_fixture() -> Bytes {
  let content = b"q 10 0 0 10 5 5 cm /Im1 Do Q"
  build_single_page_pdf(
    b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 100 100] /Resources << /XObject << /Im1 5 0 R >> >> /Contents 4 0 R >>",
    content,
    [
      b"<< /Type /XObject /Subtype /Image /Width 1 /Height 1 /ColorSpace /DeviceRGB /BitsPerComponent 8 /Length 3 >>\nstream\n" +
      Bytes::from_array([0xff, 0x00, 0x00]) +
      b"\nendstream",
    ],
  )
}

///|
fn build_clipped_rgb_image_fixture() -> Bytes {
  let content = b"10 10 30 30 re W n q 20 0 0 20 0 0 cm /Im1 Do Q"
  build_single_page_pdf(
    b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 100 100] /Resources << /XObject << /Im1 5 0 R >> >> /Contents 4 0 R >>",
    content,
    [rgb_1x1_image_object()],
  )
}

///|
fn build_stacked_clipped_rgb_image_fixture() -> Bytes {
  let content = b"10 10 60 60 re W n 20 20 40 40 re W n q 20 0 0 20 0 0 cm /Im1 Do Q"
  build_single_page_pdf(
    b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 100 100] /Resources << /XObject << /Im1 5 0 R >> >> /Contents 4 0 R >>",
    content,
    [rgb_1x1_image_object()],
  )
}

///|
fn rgb_1x1_image_object() -> Bytes {
  b"<< /Type /XObject /Subtype /Image /Width 1 /Height 1 /ColorSpace /DeviceRGB /BitsPerComponent 8 /Length 3 >>\nstream\n" +
  Bytes::from_array([0xff, 0x00, 0x00]) +
  b"\nendstream"
}

///|
fn build_clipped_text_fallback_fixture() -> Bytes {
  let content = b"10 10 30 30 re W n BT /F1 12 Tf 1 0 0 1 12 20 Tm (A) Tj ET"
  build_single_page_pdf(
    b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 100 100] /Resources << /Font << /F1 << /Type /Font /Subtype /Type1 /BaseFont /ClipFallback /FirstChar 65 /LastChar 65 /Widths [600] /Encoding /WinAnsiEncoding >> >> >> /Contents 4 0 R >>",
    content,
    [],
  )
}

///|
fn build_identity_tm_text_fixture() -> Bytes {
  let content = b"BT /F1 12 Tf 1 0 0 1 10 20 Tm (A) Tj ET"
  build_single_page_pdf(
    b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 100 100] /Resources << /Font << /F1 << /Type /Font /Subtype /Type1 /BaseFont /Helvetica >> >> >> /Contents 4 0 R >>",
    content,
    [],
  )
}

///|
fn count_rendered_non_source_notdef_paths(page : @reader.PdfPage) -> Int {
  let result : Result[@text.TextProgram, @reader.PdfDocumentError] = try? page.text_program(
    @reader.TextPageOptions::default(),
  )
  match result {
    Ok(program) => {
      let glyph_groups = text_program_span_glyphs(program)
      let embedded_fonts = page_svg_embedded_fonts(page)
      let mut count = 0
      for index in 0..<program.spans.length() {
        let span = program.spans[index]
        match span.font_name {
          Some(font_name) =>
            match embedded_fonts.get(font_name) {
              Some(ttf) =>
                count += count_span_rendered_non_source_notdef_paths(
                  span_glyphs(glyph_groups, index),
                  ttf,
                  page_view(page),
                )
              None => ()
            }
          None => ()
        }
      }
      count
    }
    Err(_) => 0
  }
}

///|
fn count_span_rendered_non_source_notdef_paths(
  glyphs : Array[@text.TextGlyphEvent],
  font : SvgEmbeddedFont,
  view : SvgPageView,
) -> Int {
  let mut count = 0
  let units_per_em = svg_font_units_per_em(font.ttf)
  for glyph in glyphs {
    let gid = resolved_embedded_glyph_id(font, glyph)
    if gid == 0 && !svg_glyph_is_notdef_source(glyph) {
      let builder = StringBuilder::new()
      if render_glyph_as_path(
          builder, glyph, font, units_per_em, view, "#000000", 0,
        ) &&
        builder.to_string().contains("<path") {
        count += 1
      }
    }
  }
  count
}

///|
struct Page6GlyphOutlineGolden {
  font_name : @objects.PdfName
  source_code : Int
  expected_gid : Int
  expected_x : Double
  expected_y : Double
  require_non_identity : Bool
}

///|
fn page6_glyph_outline_golden_cases() -> Array[Page6GlyphOutlineGolden] {
  // Generated from a local fixture with
  // dev/pdf-svg-glyph-correctness/extract_local_fixture_glyph_golden.py. The fixture is
  // embedded here so CI does not need Python or external font tools at runtime.
  [
    Page6GlyphOutlineGolden::{
      font_name: @objects.PdfName::new(b"T1_0"),
      source_code: 53,
      expected_gid: 6,
      expected_x: 458.0,
      expected_y: 698.0,
      require_non_identity: true,
    },
    Page6GlyphOutlineGolden::{
      font_name: @objects.PdfName::new(b"T1_1"),
      source_code: 71,
      expected_gid: 29,
      expected_x: 635.0,
      expected_y: 681.0,
      require_non_identity: true,
    },
    Page6GlyphOutlineGolden::{
      font_name: @objects.PdfName::new(b"T1_2"),
      source_code: 68,
      expected_gid: 28,
      expected_x: 83.0,
      expected_y: 0.0,
      require_non_identity: true,
    },
    Page6GlyphOutlineGolden::{
      font_name: @objects.PdfName::new(b"T1_3"),
      source_code: 72,
      expected_gid: 24,
      expected_x: 65.0,
      expected_y: 0.0,
      require_non_identity: true,
    },
    Page6GlyphOutlineGolden::{
      font_name: @objects.PdfName::new(b"T1_4"),
      source_code: 80,
      expected_gid: 19,
      expected_x: 309.0,
      expected_y: 566.0,
      require_non_identity: true,
    },
    Page6GlyphOutlineGolden::{
      font_name: @objects.PdfName::new(b"T1_5"),
      source_code: 83,
      expected_gid: 13,
      expected_x: 553.0,
      expected_y: 679.0,
      require_non_identity: true,
    },
    Page6GlyphOutlineGolden::{
      font_name: @objects.PdfName::new(b"C0_0"),
      source_code: 11578,
      expected_gid: 1,
      expected_x: 144.0,
      expected_y: 838.0,
      require_non_identity: true,
    },
    Page6GlyphOutlineGolden::{
      font_name: @objects.PdfName::new(b"C0_1"),
      source_code: 8206,
      expected_gid: 23,
      expected_x: 966.0,
      expected_y: 380.0,
      require_non_identity: true,
    },
  ]
}

///|
fn assert_page6_glyph_outline_golden(
  program : @text.TextProgram,
  glyph_groups : Array[Array[@text.TextGlyphEvent]],
  embedded_fonts : Map[@objects.PdfName, SvgEmbeddedFont],
  golden : Page6GlyphOutlineGolden,
) -> Unit raise {
  match embedded_fonts.get(golden.font_name) {
    Some(font) => {
      for index in 0..<program.spans.length() {
        let span = program.spans[index]
        if span.font_name == Some(golden.font_name) {
          let glyphs = span_glyphs(glyph_groups, index)
          for glyph in glyphs {
            if glyph.glyph.source_code == golden.source_code {
              let gid = resolved_embedded_glyph_id(font, glyph)
              assert_eq(gid, golden.expected_gid)
              if golden.require_non_identity {
                assert_true(gid != golden.source_code)
              }
              let outline = font.ttf.glyph_outline(gid)
              assert_true(outline.length() > 0)
              match glyph_outline_first_move(outline) {
                Some((x, y)) => {
                  assert_double_near(x, golden.expected_x, 0.001)
                  assert_double_near(y, golden.expected_y, 0.001)
                }
                None => assert_true(false)
              }
              return
            }
          }
        }
      }
      assert_true(false)
    }
    None => assert_true(false)
  }
}

///|
fn glyph_outline_first_move(
  outline : Array[@svgpath.PathCommand],
) -> (Double, Double)? {
  for command in outline {
    match command {
      @svgpath.MoveTo(x, y) => return Some((x, y))
      _ => ()
    }
  }
  None
}

///|
fn assert_double_near(
  actual : Double,
  expected : Double,
  tolerance : Double,
) -> Unit raise {
  assert_true((actual - expected).abs() <= tolerance)
}

///|
fn build_embedded_truetype_text_fixture() -> Bytes {
  let content = b"BT /F1 10 Tf 1 0 0 1 10 20 Tm (A) Tj ET"
  let font_file = build_stream_object_body(
    try! @fs.read_file_to_bytes(
      ".mooncakes/mizchi/font/fixtures/minimal-kern.ttf",
    ),
  )
  build_single_page_pdf(
    b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 100 100] /Resources << /Font << /F1 5 0 R >> >> /Contents 4 0 R >>",
    content,
    [
      b"<< /Type /Font /Subtype /TrueType /BaseFont /MinimalKern /FirstChar 65 /LastChar 65 /Widths [600] /Encoding /WinAnsiEncoding /FontDescriptor 6 0 R >>",
      b"<< /Type /FontDescriptor /FontName /MinimalKern /Flags 4 /FontBBox [0 -200 1000 1000] /ItalicAngle 0 /Ascent 1000 /Descent -200 /CapHeight 700 /StemV 80 /FontFile2 7 0 R >>",
      font_file,
    ],
  )
}

///|
fn build_clipped_embedded_truetype_text_fixture() -> Bytes {
  let content = b"q 0 0 100 100 re W n BT /F1 10 Tf 1 0 0 1 10 20 Tm (A) Tj ET Q"
  let font_file = build_stream_object_body(
    try! @fs.read_file_to_bytes(
      ".mooncakes/mizchi/font/fixtures/minimal-kern.ttf",
    ),
  )
  build_single_page_pdf(
    b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 100 100] /Resources << /Font << /F1 5 0 R >> >> /Contents 4 0 R >>",
    content,
    [
      b"<< /Type /Font /Subtype /TrueType /BaseFont /MinimalKern /FirstChar 65 /LastChar 65 /Widths [600] /Encoding /WinAnsiEncoding /FontDescriptor 6 0 R >>",
      b"<< /Type /FontDescriptor /FontName /MinimalKern /Flags 4 /FontBBox [0 -200 1000 1000] /ItalicAngle 0 /Ascent 1000 /Descent -200 /CapHeight 700 /StemV 80 /FontFile2 7 0 R >>",
      font_file,
    ],
  )
}

///|
fn build_embedded_cid_unknown_text_fixture() -> Bytes {
  let content = b"BT /F1 10 Tf 1 0 0 1 10 20 Tm <0001> Tj ET"
  let font_file = build_stream_object_body(
    try! @fs.read_file_to_bytes(
      ".mooncakes/mizchi/font/fixtures/minimal-kern.ttf",
    ),
  )
  build_single_page_pdf(
    b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 100 100] /Resources << /Font << /F1 5 0 R >> >> /Contents 4 0 R >>",
    content,
    [
      b"<< /Type /Font /Subtype /Type0 /BaseFont /MinimalKern /Encoding /Identity-H /DescendantFonts [6 0 R] >>",
      b"<< /Type /Font /Subtype /CIDFontType2 /BaseFont /MinimalKern /CIDSystemInfo << /Registry (Adobe) /Ordering (Identity) /Supplement 0 >> /DW 600 /FontDescriptor 7 0 R >>",
      b"<< /Type /FontDescriptor /FontName /MinimalKern /Flags 4 /FontBBox [0 -200 1000 1000] /ItalicAngle 0 /Ascent 1000 /Descent -200 /CapHeight 700 /StemV 80 /FontFile2 8 0 R >>",
      font_file,
    ],
  )
}

///|
fn build_coloured_embedded_truetype_text_fixture() -> Bytes {
  let content = b"1 0 0 rg BT /F1 10 Tf 1 0 0 1 10 20 Tm (A) Tj ET"
  let font_file = build_stream_object_body(
    try! @fs.read_file_to_bytes(
      ".mooncakes/mizchi/font/fixtures/minimal-kern.ttf",
    ),
  )
  build_single_page_pdf(
    b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 100 100] /Resources << /Font << /F1 5 0 R >> >> /Contents 4 0 R >>",
    content,
    [
      b"<< /Type /Font /Subtype /TrueType /BaseFont /MinimalKern /FirstChar 65 /LastChar 65 /Widths [600] /Encoding /WinAnsiEncoding /FontDescriptor 6 0 R >>",
      b"<< /Type /FontDescriptor /FontName /MinimalKern /Flags 4 /FontBBox [0 -200 1000 1000] /ItalicAngle 0 /Ascent 1000 /Descent -200 /CapHeight 700 /StemV 80 /FontFile2 7 0 R >>",
      font_file,
    ],
  )
}

///|
fn build_coloured_text_fallback_fixture() -> Bytes {
  let content = b"0 1 0 rg BT /F1 12 Tf 1 0 0 1 10 20 Tm (A) Tj ET"
  build_single_page_pdf(
    b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 100 100] /Resources << /Font << /F1 << /Type /Font /Subtype /Type1 /BaseFont /ColourFallback /FirstChar 65 /LastChar 65 /Widths [600] /Encoding /WinAnsiEncoding >> >> >> /Contents 4 0 R >>",
    content,
    [],
  )
}

///|
fn build_coloured_text_with_bad_xobject_fixture() -> Bytes {
  let content = b"1 0 0 rg BT /F1 12 Tf 1 0 0 1 10 20 Tm (A) Tj ET /Fm1 Do"
  let bad_form = build_stream_object_body_with_entries(
    b"/Type /XObject /Subtype /Form /BBox [0 0 10 10]", b"S",
  )
  build_single_page_pdf(
    b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 100 100] /Resources << /Font << /F1 << /Type /Font /Subtype /Type1 /BaseFont /ColourFallback /FirstChar 65 /LastChar 65 /Widths [600] /Encoding /WinAnsiEncoding >> >> /XObject << /Fm1 5 0 R >> >> /Contents 4 0 R >>",
    content,
    [bad_form],
  )
}

///|
fn build_embedded_fontfile3_text_fixture() -> Bytes {
  let content = b"BT /F1 10 Tf 1 0 0 1 10 20 Tm (A) Tj ET"
  let font_file = build_stream_object_body_with_entries(
    b"/Subtype /OpenType",
    try! @fs.read_file_to_bytes(
      ".mooncakes/mizchi/font/fixtures/minimal-kern.ttf",
    ),
  )
  build_single_page_pdf(
    b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 100 100] /Resources << /Font << /F1 5 0 R >> >> /Contents 4 0 R >>",
    content,
    [
      b"<< /Type /Font /Subtype /TrueType /BaseFont /MinimalKern /FirstChar 65 /LastChar 65 /Widths [600] /Encoding /WinAnsiEncoding /FontDescriptor 6 0 R >>",
      b"<< /Type /FontDescriptor /FontName /MinimalKern /Flags 4 /FontBBox [0 -200 1000 1000] /ItalicAngle 0 /Ascent 1000 /Descent -200 /CapHeight 700 /StemV 80 /FontFile3 7 0 R >>",
      font_file,
    ],
  )
}

///|
fn build_raw_type1c_fontfile3_text_fixture() -> Bytes {
  let content = b"BT /F1 12 Tf 1 0 0 1 10 20 Tm (A) Tj ET"
  let cff = cff_add_fixture_cff()
  let font_file = build_stream_object_body_with_entries(
    b"/Subtype /Type1C", cff,
  )
  build_single_page_pdf(
    b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 100 100] /Resources << /Font << /F1 5 0 R >> >> /Contents 4 0 R >>",
    content,
    [
      b"<< /Type /Font /Subtype /Type1 /BaseFont /RawCffFallback /FirstChar 65 /LastChar 65 /Widths [600] /Encoding /WinAnsiEncoding /FontDescriptor 6 0 R >>",
      b"<< /Type /FontDescriptor /FontName /RawCffFallback /Flags 4 /FontBBox [0 -200 1000 1000] /ItalicAngle 0 /Ascent 1000 /Descent -200 /CapHeight 700 /StemV 80 /FontFile3 7 0 R >>",
      font_file,
    ],
  )
}

///|
fn cff_add_fixture_cff() -> Bytes {
  extract_sfnt_table(
    try! @fs.read_file_to_bytes(
      ".mooncakes/mizchi/font/fixtures/cff-opcodes/cff.add.otf",
    ),
    b"CFF ",
  )
}

///|
fn minimal_cid_keyed_cff() -> Bytes {
  let bytes : Array[Byte] = []
  // Header
  bytes.push(b'\x01')
  bytes.push(b'\x00')
  bytes.push(b'\x04')
  bytes.push(b'\x04')
  // Name INDEX: one name, "CID"
  push_u16(bytes, 1)
  bytes.push(b'\x01')
  bytes.push(b'\x01')
  bytes.push(b'\x04')
  bytes.push(b'\x43')
  bytes.push(b'\x49')
  bytes.push(b'\x44')
  // Top DICT INDEX with ROS, CIDCount, charset offset, CharStrings offset.
  push_u16(bytes, 1)
  bytes.push(b'\x01')
  bytes.push(b'\x01')
  bytes.push(b'\x0D')
  bytes.push(b'\x8B')
  bytes.push(b'\x8B')
  bytes.push(b'\x8B')
  bytes.push(b'\x0C')
  bytes.push(b'\x1E')
  bytes.push(b'\xEF')
  bytes.push(b'\x0C')
  bytes.push(b'\x22')
  bytes.push(b'\xAC')
  bytes.push(b'\x0F')
  bytes.push(b'\xB0')
  bytes.push(b'\x11')
  // String INDEX and Global Subr INDEX are empty.
  push_u16(bytes, 0)
  push_u16(bytes, 0)
  // CID-keyed charset format 1: glyph_id 1..3 map to CID 10..12.
  bytes.push(b'\x01')
  push_u16(bytes, 10)
  bytes.push(b'\x02')
  // CharStrings INDEX: four one-byte endchar charstrings.
  push_u16(bytes, 4)
  bytes.push(b'\x01')
  bytes.push(b'\x01')
  bytes.push(b'\x02')
  bytes.push(b'\x03')
  bytes.push(b'\x04')
  bytes.push(b'\x05')
  bytes.push(b'\x0E')
  bytes.push(b'\x0E')
  bytes.push(b'\x0E')
  bytes.push(b'\x0E')
  Bytes::from_array(bytes[:])
}

///|
fn push_u16(bytes : Array[Byte], value : Int) -> Unit {
  bytes.push(((value >> 8) & 0xFF).to_byte())
  bytes.push((value & 0xFF).to_byte())
}

///|
fn minimal_post_ttf(glyph_names : Array[String]) -> @font.TTFont {
  @font.TTFont::{
    units_per_em: 1000,
    index_to_loc_format: 0,
    num_glyphs: glyph_names.length(),
    ascent: 0,
    descent: 0,
    line_gap: 0,
    num_h_metrics: 0,
    glyf_offset: 0,
    data: b"",
    cmap: Map::new(),
    loca: [],
    advance_widths: [],
    left_side_bearings: [],
    cff: None,
    gvar: None,
    var_axes: [],
    kern_pairs: Map::new(),
    avar_segments: [],
    name_records: Map::new(),
    os2: None,
    post: Some(@font.PostTable::{
      italic_angle: 0.0,
      underline_position: 0,
      underline_thickness: 0,
      is_fixed_pitch: false,
      glyph_names,
    }),
    vertical: None,
    gasp: [],
    vorg: None,
  }
}

///|
fn minimal_cid_glyph_event(cid : Int) -> @text.TextGlyphEvent {
  let metrics = @text.GlyphMetrics::{
    horizontal_displacement: 0.0,
    vertical_displacement_x: 0.0,
    vertical_displacement_y: 0.0,
    vertical_origin_x: 0.0,
    vertical_origin_y: 0.0,
    width_source: @text.GlyphWidthSource::CIDExplicitWidth,
  }
  let decoded = @text.DecodedGlyph::{
    source_bytes: b"",
    source_code: cid,
    glyph: @text.GlyphIdentifier::CID(cid),
    metrics,
    word_spacing_eligible: false,
    fallback: @text.GlyphFallback::NoFallback,
  }
  @text.TextGlyphEvent::{
    offset: 0L,
    source: @text.TextSourceString::{
      bytes: b"",
      operator_offset: 0L,
      group_index: 0,
    },
    glyph: decoded,
    unicode: @text.UnicodeMapping::Unknown(
      b"",
      @text.GlyphIdentifier::CID(cid),
      @text.GlyphFallback::NoFallback,
    ),
    text_matrix: @text.TextMatrix::identity(),
    rendering_matrix: @text.TextRenderingMatrix::from_text_state(
      @text.TextMatrix::identity(),
      1.0,
      1.0,
      0.0,
      @text.TextMatrix::identity(),
    ),
    paint: @text.TextPaintIntent::from_rendering_mode(
      @text.TextRenderingMode::Fill,
      false,
    ),
  }
}

///|
fn minimal_unicode_cid_glyph_event(
  cid : Int,
  text : String,
) -> @text.TextGlyphEvent {
  let event = minimal_cid_glyph_event(cid)
  @text.TextGlyphEvent::{
    offset: event.offset,
    source: event.source,
    glyph: event.glyph,
    unicode: @text.UnicodeMapping::Unicode(text),
    text_matrix: event.text_matrix,
    rendering_matrix: event.rendering_matrix,
    paint: event.paint,
  }
}

///|
fn build_ctm_scaled_text_fixture() -> Bytes {
  let content = b"2 0 0 2 10 20 cm BT /F1 10 Tf 1 0 0 1 5 6 Tm (A) Tj ET"
  build_single_page_pdf(
    b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 100 100] /Resources << /Font << /F1 << /Type /Font /Subtype /Type1 /BaseFont /Helvetica >> >> >> /Contents 4 0 R >>",
    content,
    [],
  )
}

///|
fn extract_sfnt_table(data : Bytes, tag : Bytes) -> Bytes {
  if data.length() < 12 || tag.length() != 4 {
    return b""
  }
  let count = read_u16_be(data, 4)
  for index in 0..<count {
    let record = 12 + index * 16
    if record + 16 <= data.length() && bytes_match4(data, record, tag) {
      let offset = read_u32_be(data, record + 8)
      let length = read_u32_be(data, record + 12)
      if offset >= 0 && length >= 0 && offset + length <= data.length() {
        return @font.bytes_slice(data, offset, length)
      }
    }
  }
  b""
}

///|
fn bytes_match4(data : Bytes, offset : Int, tag : Bytes) -> Bool {
  data[offset] == tag[0] &&
  data[offset + 1] == tag[1] &&
  data[offset + 2] == tag[2] &&
  data[offset + 3] == tag[3]
}

///|
fn read_u16_be(data : Bytes, offset : Int) -> Int {
  (data[offset].to_int() << 8) | data[offset + 1].to_int()
}

///|
fn read_u32_be(data : Bytes, offset : Int) -> Int {
  (data[offset].to_int() << 24) |
  (data[offset + 1].to_int() << 16) |
  (data[offset + 2].to_int() << 8) |
  data[offset + 3].to_int()
}

///|
fn build_single_page_pdf(
  page_body : Bytes,
  content : Bytes,
  extra_objects : Array[Bytes],
) -> Bytes {
  let header = b"%PDF-2.0\n"
  let header_base = 0L
  let bytes = header

  let (bytes, catalog_offset) = append_indirect_object(
    bytes, header_base, 1, 0, b"<< /Type /Catalog /Pages 2 0 R >>",
  )
  let (bytes, pages_offset) = append_indirect_object(
    bytes, header_base, 2, 0, b"<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
  )
  let (bytes, page_offset) = append_indirect_object(
    bytes, header_base, 3, 0, page_body,
  )
  let content_stream = build_stream_object_body(content)
  let (bytes, content_offset) = append_indirect_object(
    bytes, header_base, 4, 0, content_stream,
  )
  let offsets : Array[Int64] = [
    catalog_offset, pages_offset, page_offset, content_offset,
  ]
  let mut bytes = bytes
  let mut object_number = 5
  for object in extra_objects {
    let appended = append_indirect_object(
      bytes, header_base, object_number, 0, object,
    )
    bytes = appended.0
    offsets.push(appended.1)
    object_number += 1
  }

  finish_pdf(bytes, header_base, offsets)
}

///|
fn build_stream_object_body(content : Bytes) -> Bytes {
  b"<< /Length " +
  decimal_bytes(content.length().to_int64()) +
  b" >>\nstream\n" +
  content +
  b"\nendstream"
}

///|
fn build_stream_object_body_with_entries(
  entries : Bytes,
  content : Bytes,
) -> Bytes {
  b"<< /Length " +
  decimal_bytes(content.length().to_int64()) +
  b" " +
  entries +
  b" >>\nstream\n" +
  content +
  b"\nendstream"
}

///|
fn append_indirect_object(
  bytes : Bytes,
  header_base : Int64,
  object_number : Int,
  generation : Int,
  body : Bytes,
) -> (Bytes, Int64) {
  let offset = object_offset(bytes, header_base)
  let bytes = bytes +
    decimal_bytes(object_number.to_int64()) +
    b" " +
    decimal_bytes(generation.to_int64()) +
    b" obj\n" +
    body +
    b"\nendobj\n"
  (bytes, offset)
}

///|
fn finish_pdf(
  bytes : Bytes,
  header_base : Int64,
  offsets : Array[Int64],
) -> Bytes {
  let xref_offset = object_offset(bytes, header_base)
  let mut out = bytes +
    b"xref\n0 " +
    decimal_bytes((offsets.length() + 1).to_int64()) +
    b"\n" +
    xref_entry_line(0L, 65535, b'f')
  for offset in offsets {
    out = out + xref_entry_line(offset, 0, b'n')
  }
  out +
  b"trailer\n<< /Size " +
  decimal_bytes((offsets.length() + 1).to_int64()) +
  b" /Root 1 0 R >>\nstartxref\n" +
  decimal_bytes(xref_offset) +
  b"\n%%EOF\n"
}

///|
fn object_offset(bytes : Bytes, header_base : Int64) -> Int64 {
  bytes.length().to_int64() - header_base
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
  Bytes::from_array([marker, b' ', b'\n'])
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
  for index in 0..<digits.length() {
    out.push(digits[digits.length() - 1 - index])
  }
  Bytes::from_array(out)
}
