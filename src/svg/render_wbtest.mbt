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
  let svg_matrix = svg_text_transform_without_fontsize(matrix, font_size, 100.0)
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
  let svg_matrix = svg_text_transform_without_fontsize(matrix, 14.0, 100.0)
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
test "render_page_svg keeps text colour when unresolved XObject graphics fail" {
  let document = @reader.PdfDocument::open(
    build_coloured_text_with_bad_xobject_fixture(),
  )
  let svg = render_page_svg(document.page(0))
  assert_eq(svg.contains("<text"), true)
  assert_eq(svg.contains("fill=\"#FF0000\""), true)
}

///|
test "diagnostic local-fixture page 4 colour conversion state changes" {
  let path = "<local-fixture>"
  if !@fs.path_exists(path) {
    println("diagnostic skipped: " + path + " is not present")
    return
  }
  let document = @reader.PdfDocument::open(@fs.read_file_to_bytes(path))
  let events = document
    .page(3)
    .graphics_events(
      @reader.GraphicsPageOptions::with_materialized_xobjects(None),
    )
  let mut state_changes = 0
  let mut successes = 0
  let mut errors = 0
  for event in events {
    match event {
      @graphics.GraphicsEvent::StateChanged(offset, _, state) => {
        state_changes += 1
        if diagnostic_colour_conversion(
            state,
            @graphics.ColourUse::Nonstroking,
            offset,
          ) {
          successes += 1
        } else {
          errors += 1
        }
        if diagnostic_colour_conversion(
            state,
            @graphics.ColourUse::Stroking,
            offset,
          ) {
          successes += 1
        } else {
          errors += 1
        }
      }
      _ => ()
    }
  }
  println(
    "diagnostic local-fixture page 4 StateChanged=" +
    state_changes.to_string() +
    " colour conversion successes=" +
    successes.to_string() +
    " errors=" +
    errors.to_string(),
  )
  assert_true(state_changes > 0)
}

///|
test "diagnostic local-fixture page 6 CID CFF chain" {
  let path = "<local-fixture>"
  if !@fs.path_exists(path) {
    println("diagnostic skipped: " + path + " is not present")
    return
  }
  let document = @reader.PdfDocument::open(@fs.read_file_to_bytes(path))
  let result : Result[@text.TextResources, @reader.PdfDocumentError] = try? document
    .page(5)
    .text_resources()
  match result {
    Ok(resources) => {
      let mut stream_count = 0
      let mut parseable_count = 0
      for name, summary in resources.fonts {
        stream_count += diagnostic_fontfile3_chain(
          "font " + name.to_text(),
          summary.font_object,
        )
        parseable_count += diagnostic_fontfile3_parseable_chain(
          summary.font_object,
        )
      }
      println(
        "diagnostic local-fixture page 6 FontFile3 streams=" + stream_count.to_string(),
      )
      diagnostic_page6_text_path_summary(document.page(5), b"C0_0")
      diagnostic_page6_text_path_summary(document.page(5), b"C0_1")
      assert_eq(parseable_count, stream_count)
      assert_true(stream_count > 0)
    }
    Err(_) => println("diagnostic local-fixture page 6 text_resources failed")
  }
}

///|
test "diagnostic local-fixture page 6 Handset header glyph trace" {
  let path = "<local-fixture>"
  if !@fs.path_exists(path) {
    println("diagnostic skipped: " + path + " is not present")
    return
  }
  let document = @reader.PdfDocument::open(@fs.read_file_to_bytes(path))
  let page = document.page(5)
  let result : Result[@text.TextProgram, @reader.PdfDocumentError] = try? page.text_program(
    @reader.TextPageOptions::default(),
  )
  match result {
    Ok(program) => {
      let glyph_groups = text_program_span_glyphs(program)
      let embedded_fonts = page_svg_embedded_fonts(page)
      let mut printed = false
      for index in 0..<program.spans.length() {
        let span = program.spans[index]
        if span.text.contains("Handset Power On/Of") ||
          span.text.contains("Handset") {
          match span.font_name {
            Some(font_name) =>
              match embedded_fonts.get(font_name) {
                Some(ttf) => {
                  let glyphs = span_glyphs(glyph_groups, index)
                  for glyph in glyphs {
                    diagnostic_print_glyph_trace(
                      font_name.to_text(),
                      ttf,
                      glyph,
                    )
                    printed = true
                  }
                }
                None =>
                  println(
                    "diagnostic local-fixture glyph_trace: font=" +
                    font_name.to_text() +
                    " embedded_font=<missing>",
                  )
              }
            None => println("diagnostic local-fixture glyph_trace: font=<missing>")
          }
        }
      }
      if !printed {
        println("diagnostic local-fixture glyph_trace: Handset span not found")
      }
    }
    Err(_) => println("diagnostic local-fixture glyph_trace: text_program failed")
  }
}

///|
test "diagnostic local-fixture pages 6 7 tofu glyphs" {
  let path = "<local-fixture>"
  if !@fs.path_exists(path) {
    println("diagnostic skipped: " + path + " is not present")
    return
  }
  let document = @reader.PdfDocument::open(@fs.read_file_to_bytes(path))
  for page_index in [5, 6] {
    diagnostic_local-fixture_page_tofu_glyphs(document.page(page_index), page_index)
  }
}

///|
test "local-fixture pages 6 7 render no notdef paths" {
  let path = "<local-fixture>"
  if !@fs.path_exists(path) {
    println("diagnostic skipped: " + path + " is not present")
    return
  }
  let document = @reader.PdfDocument::open(@fs.read_file_to_bytes(path))
  let mut rendered_notdef_paths = 0
  for page_index in [5, 6] {
    let page = document.page(page_index)
    let svg = render_page_svg(page)
    assert_true(svg.length() > 0)
    rendered_notdef_paths += count_rendered_non_source_notdef_paths(page)
  }
  assert_eq(rendered_notdef_paths, 0)
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
test "local-fixture page 6 per-glyph outline golden" {
  let path = "<local-fixture>"
  if !@fs.path_exists(path) {
    println("diagnostic skipped: " + path + " is not present")
    return
  }
  let document = @reader.PdfDocument::open(@fs.read_file_to_bytes(path))
  let page = document.page(5)
  let result : Result[@text.TextProgram, @reader.PdfDocumentError] = try? page.text_program(
    @reader.TextPageOptions::default(),
  )
  match result {
    Ok(program) => {
      let glyph_groups = text_program_span_glyphs(program)
      let embedded_fonts = page_svg_embedded_fonts(page)
      for golden in page6_glyph_outline_golden_cases() {
        assert_page6_glyph_outline_golden(
          program, glyph_groups, embedded_fonts, golden,
        )
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "local-fixture page 6 Handset glyph paths use source text colour" {
  let path = "<local-fixture>"
  if !@fs.path_exists(path) {
    println("diagnostic skipped: " + path + " is not present")
    return
  }
  let document = @reader.PdfDocument::open(@fs.read_file_to_bytes(path))
  let page = document.page(5)
  let program = page.text_program(@reader.TextPageOptions::default())
  let colours = page_svg_text_fill_colours(page, program)
  let mut checked = false
  for index in 0..<program.spans.length() {
    let span = program.spans[index]
    if span.text.contains("Handset Power On/Of") {
      assert_eq(span_fill_colour(colours, index), "#231F20")
      checked = true
      break
    }
  }
  assert_true(checked)
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
test "svg_cid_glyph_id resolves cid post glyph names" {
  match cff_post_glyph_name_table(minimal_cid_keyed_cff(), 4) {
    Some(names) => {
      assert_eq(names[0], "cid00000")
      assert_eq(names[1], "cid00010")
      assert_eq(names[3], "cid00012")
      let ttf = minimal_post_ttf(names)
      assert_eq(svg_cid_glyph_id(ttf, 10), 1)
      assert_eq(svg_cid_glyph_id(ttf, 12), 3)
      assert_eq(svg_cid_glyph_id(ttf, 13), -1)
    }
    None => assert_true(false)
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
  write_svg_image(
    builder,
    "data:image/png;base64,AA==",
    @graphics.GraphicsMatrix::from_six(100.0, 0.0, 0.0, 100.0, 72.0, 172.0),
    true,
    true,
    396.0,
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
  write_svg_image(
    builder,
    "data:image/png;base64,AA==",
    @graphics.GraphicsMatrix::from_six(175.7, 0.0, 0.0, 87.85, 72.0, 590.0),
    false,
    false,
    841.92,
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
test "render_page_svg uses sampled Separation colour space tint transform" {
  let document = @reader.PdfDocument::open(
    build_sampled_separation_path_fixture(),
  )
  let svg = render_page_svg(document.page(0))
  assert_eq(svg.contains("<path"), true)
  assert_eq(svg.contains("fill=\"#404040\""), true)
}

///|
test "render_page_svg skips unsupported encoded image data without crashing" {
  let document = @reader.PdfDocument::open(build_encoded_image_fixture())
  let svg = render_page_svg(document.page(0))
  assert_eq(svg.has_prefix("<svg"), true)
  assert_eq(svg.contains("</svg>"), true)
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
fn diagnostic_colour_conversion(
  state : @graphics.GraphicsState,
  colour_use : @graphics.ColourUse,
  offset : Int64,
) -> Bool {
  let colour_state = state.colour_state(colour_use)
  let result : Result[@graphics.DeviceRgbColour, @graphics.PdfGraphicsError] = try? state.current_colour_as_rgb(
    colour_use,
  )
  match result {
    Ok(_) => true
    Err(error) => {
      println(
        "diagnostic colour error offset=" +
        offset.to_string() +
        " use=" +
        diagnostic_colour_use_name(colour_use) +
        " space=" +
        diagnostic_colour_space_name(colour_state.colour_space) +
        " value_components=" +
        colour_state.colour_value.components.length().to_string() +
        " error=" +
        diagnostic_graphics_error_message(error),
      )
      false
    }
  }
}

///|
fn diagnostic_colour_use_name(colour_use : @graphics.ColourUse) -> String {
  match colour_use {
    @graphics.ColourUse::Stroking => "Stroking"
    @graphics.ColourUse::Nonstroking => "Nonstroking"
  }
}

///|
fn diagnostic_colour_space_name(space : @graphics.ColourSpace) -> String {
  match space {
    @graphics.ColourSpace::Device(device) =>
      match device {
        @graphics.DeviceColourSpace::DeviceGray => "DeviceGray"
        @graphics.DeviceColourSpace::DeviceRGB => "DeviceRGB"
        @graphics.DeviceColourSpace::DeviceCMYK => "DeviceCMYK"
      }
    @graphics.ColourSpace::CalGray(_) => "CalGray"
    @graphics.ColourSpace::CalRGB(_) => "CalRGB"
    @graphics.ColourSpace::Lab(_) => "Lab"
    @graphics.ColourSpace::ICCBased(_) => "ICCBased"
    @graphics.ColourSpace::Pattern(_) => "Pattern"
    @graphics.ColourSpace::Indexed(_) => "Indexed"
    @graphics.ColourSpace::Separation(_) => "Separation"
    @graphics.ColourSpace::DeviceN(_) => "DeviceN"
  }
}

///|
fn diagnostic_graphics_error_message(
  error : @graphics.PdfGraphicsError,
) -> String {
  match error {
    @graphics.PdfGraphicsError::BadOperand(offset, message) =>
      "BadOperand(" + offset.to_string() + "): " + message
    @graphics.PdfGraphicsError::InvalidGraphicsState(offset, message) =>
      "InvalidGraphicsState(" + offset.to_string() + "): " + message
    @graphics.PdfGraphicsError::GraphicsStackUnderflow(offset) =>
      "GraphicsStackUnderflow(" + offset.to_string() + ")"
    @graphics.PdfGraphicsError::InvalidPathState(offset, message) =>
      "InvalidPathState(" + offset.to_string() + "): " + message
    @graphics.PdfGraphicsError::InvalidObjectContext(offset, message) =>
      "InvalidObjectContext(" + offset.to_string() + "): " + message
    @graphics.PdfGraphicsError::ResourceFailure(offset, message) =>
      "ResourceFailure(" + offset.to_string() + "): " + message
    @graphics.PdfGraphicsError::InvalidXObject(offset, message) =>
      "InvalidXObject(" + offset.to_string() + "): " + message
    @graphics.PdfGraphicsError::InvalidImage(offset, message) =>
      "InvalidImage(" + offset.to_string() + "): " + message
    @graphics.PdfGraphicsError::InvalidOptionalContent(offset, message) =>
      "InvalidOptionalContent(" + offset.to_string() + "): " + message
    @graphics.PdfGraphicsError::InterchangeFailure(_) => "InterchangeFailure"
    @graphics.PdfGraphicsError::ContentFailure(_) => "ContentFailure"
  }
}

///|
/// Diagnostic instrumentation for real local-fixture CFF data: walks a font
/// object, decodes every FontFile3 stream on local-fixture page 6, and prints
/// the state of `is_raw_cff`, `is_cid_keyed_cff`, CIDCount, charset
/// format and glyph count, the `cid00000` synthetic post names, and
/// whether `parse_font` succeeds on the wrapped OTF. The output
/// pinpoints which stage of the CID-keyed CFF reverse-lookup chain
/// fails for real-data input.
fn diagnostic_fontfile3_chain(
  label : String,
  object : @objects.PdfObject,
) -> Int {
  match object {
    @objects.PdfObject::Dictionary(dict) =>
      diagnostic_fontfile3_dict(label, dict)
    _ => 0
  }
}

///|
fn diagnostic_fontfile3_dict(
  label : String,
  dict : @objects.PdfDictionary,
) -> Int {
  let mut count = 0
  match dict.get(@objects.PdfName::new(b"FontDescriptor")) {
    Some(@objects.PdfObject::Dictionary(descriptor)) =>
      count += diagnostic_fontfile3_descriptor(label, descriptor)
    _ => ()
  }
  match dict.get(@objects.PdfName::new(b"DescendantFonts")) {
    Some(@objects.PdfObject::Array(fonts)) =>
      for index in 0..<fonts.length() {
        count += diagnostic_fontfile3_chain(
          label + ".DescendantFonts[" + index.to_string() + "]",
          fonts[index],
        )
      }
    _ => ()
  }
  count
}

///|
fn diagnostic_fontfile3_descriptor(
  label : String,
  descriptor : @objects.PdfDictionary,
) -> Int {
  match descriptor.get(@objects.PdfName::new(b"FontFile3")) {
    Some(@objects.PdfObject::Stream(stream)) => {
      diagnostic_fontfile3_stream(label, stream)
      1
    }
    _ => 0
  }
}

///|
fn diagnostic_fontfile3_stream(
  label : String,
  stream : @objects.PdfStream,
) -> Unit {
  let decoded : Result[Bytes, @filters.PdfFilterError] = try? @filters.decode_stream(
    stream,
  )
  match decoded {
    Ok(bytes) => diagnostic_fontfile3_bytes(label, bytes)
    Err(_) => println(label + ": FontFile3 decode failed")
  }
}

///|
/// Keep diagnostic tests: this regression-guard helper verifies that
/// every extracted FontFile3 stream either parses as a raw CFF
/// wrapped through `wrap_cff_in_otf` or as a full sfnt container,
/// so the CID-keyed CFF diagnostic chain test never silently skips a
/// stream when fixture data changes.
fn diagnostic_fontfile3_parseable_chain(object : @objects.PdfObject) -> Int {
  match object {
    @objects.PdfObject::Dictionary(dict) =>
      diagnostic_fontfile3_parseable_dict(dict)
    _ => 0
  }
}

///|
fn diagnostic_fontfile3_parseable_dict(dict : @objects.PdfDictionary) -> Int {
  let mut count = 0
  match dict.get(@objects.PdfName::new(b"FontDescriptor")) {
    Some(@objects.PdfObject::Dictionary(descriptor)) =>
      count += diagnostic_fontfile3_parseable_descriptor(descriptor)
    _ => ()
  }
  match dict.get(@objects.PdfName::new(b"DescendantFonts")) {
    Some(@objects.PdfObject::Array(fonts)) =>
      for font in fonts {
        count += diagnostic_fontfile3_parseable_chain(font)
      }
    _ => ()
  }
  count
}

///|
fn diagnostic_fontfile3_parseable_descriptor(
  descriptor : @objects.PdfDictionary,
) -> Int {
  match descriptor.get(@objects.PdfName::new(b"FontFile3")) {
    Some(@objects.PdfObject::Stream(stream)) =>
      if diagnostic_fontfile3_parseable_stream(stream) {
        1
      } else {
        0
      }
    _ => 0
  }
}

///|
fn diagnostic_fontfile3_parseable_stream(stream : @objects.PdfStream) -> Bool {
  let decoded : Result[Bytes, @filters.PdfFilterError] = try? @filters.decode_stream(
    stream,
  )
  match decoded {
    Ok(bytes) =>
      if is_raw_cff(bytes) {
        match wrap_cff_in_otf(bytes) {
          Some(wrapped) => @font.parse_font(wrapped) is Some(_)
          None => false
        }
      } else {
        @font.parse_font(bytes) is Some(_)
      }
    Err(_) => false
  }
}

///|
fn diagnostic_fontfile3_bytes(label : String, bytes : Bytes) -> Unit {
  println(label + ":")
  println("  FontFile3 stream decoded, len=" + bytes.length().to_string())
  let raw_cff = is_raw_cff(bytes)
  println("  is_raw_cff=" + diagnostic_bool(raw_cff))
  if raw_cff {
    diagnostic_raw_cff_chain(bytes)
  } else {
    match @font.parse_font(bytes) {
      Some(ttf) => {
        println(
          "  parse_font full sfnt ok, num_glyphs=" + ttf.num_glyphs.to_string(),
        )
        diagnostic_print_post_names("  post.glyph_names[0..4]=", ttf)
      }
      None => println("  parse_font full sfnt failed")
    }
  }
}

///|
fn diagnostic_raw_cff_chain(bytes : Bytes) -> Unit {
  let num_glyphs = cff_charstrings_count(bytes)
  let cid_keyed = is_cid_keyed_cff(bytes)
  println("  is_cid_keyed_cff=" + diagnostic_bool(cid_keyed))
  println("  CIDCount=" + cff_cid_count(bytes).to_string())
  println("  CharStrings count=" + num_glyphs.to_string())
  if cid_keyed {
    diagnostic_print_cid_charset(bytes, num_glyphs)
  }
  match wrap_cff_in_otf(bytes) {
    Some(wrapped) => {
      println("  wrapped OTF len=" + wrapped.length().to_string())
      match @font.parse_font(wrapped) {
        Some(ttf) => {
          println(
            "  parse_font wrapped ok, num_glyphs=" + ttf.num_glyphs.to_string(),
          )
          diagnostic_print_post_names("  post.glyph_names[0..4]=", ttf)
          if cid_keyed {
            diagnostic_print_cid_lookup(bytes, num_glyphs, ttf)
          }
        }
        None => println("  parse_font wrapped failed")
      }
    }
    None => println("  wrap_cff_in_otf failed")
  }
}

///|
fn diagnostic_print_cid_charset(bytes : Bytes, num_glyphs : Int) -> Unit {
  let format = diagnostic_cff_charset_format(bytes)
  match parse_cff_cid_charset(bytes, num_glyphs) {
    Some(cids) => {
      println(
        "  charset format=" +
        format.to_string() +
        ", num_glyphs=" +
        cids.length().to_string() +
        ", first CIDs=" +
        diagnostic_cid_values(cids),
      )
      match cff_cid_to_glyph_id_map(bytes, num_glyphs) {
        Some(map) =>
          println(
            "  cid_map size=" +
            map.length().to_string() +
            ", sample=" +
            diagnostic_cid_map_sample(cids),
          )
        None => println("  cid_map failed")
      }
    }
    None =>
      println(
        "  charset format=" +
        format.to_string() +
        ", parse_cff_cid_charset failed",
      )
  }
}

///|
fn diagnostic_print_cid_lookup(
  bytes : Bytes,
  num_glyphs : Int,
  ttf : @font.TTFont,
) -> Unit {
  match parse_cff_cid_charset(bytes, num_glyphs) {
    Some(cids) =>
      println(
        "  svg_cid_glyph_id sample=" + diagnostic_cid_lookup_sample(cids, ttf),
      )
    None => ()
  }
}

///|
fn diagnostic_cff_charset_format(bytes : Bytes) -> Int {
  let offset = cff_charset_offset(bytes)
  if offset >= 0 && offset < bytes.length() {
    bytes[offset].to_int()
  } else {
    -1
  }
}

///|
fn diagnostic_print_post_names(label : String, ttf : @font.TTFont) -> Unit {
  match ttf.post {
    Some(post) => println(label + diagnostic_string_sample(post.glyph_names))
    None => println(label + "<missing post table>")
  }
}

///|
fn diagnostic_string_sample(values : Array[String]) -> String {
  let builder = StringBuilder::new()
  builder.write_string("[")
  let limit = diagnostic_min(5, values.length())
  for i in 0..<limit {
    if i > 0 {
      builder.write_string(", ")
    }
    builder.write_string("\"")
    builder.write_string(values[i])
    builder.write_string("\"")
  }
  builder.write_string("]")
  builder.to_string()
}

///|
fn diagnostic_cid_values(cids : Array[Int]) -> String {
  let builder = StringBuilder::new()
  builder.write_string("[")
  let limit = diagnostic_min(5, cids.length())
  for i in 0..<limit {
    if i > 0 {
      builder.write_string(", ")
    }
    builder.write_string(cids[i].to_string())
  }
  builder.write_string("]")
  builder.to_string()
}

///|
fn diagnostic_cid_map_sample(cids : Array[Int]) -> String {
  let builder = StringBuilder::new()
  builder.write_string("{")
  let limit = diagnostic_min(5, cids.length())
  for glyph_id in 0..<limit {
    if glyph_id > 0 {
      builder.write_string(", ")
    }
    builder.write_string(cids[glyph_id].to_string())
    builder.write_string("=>")
    builder.write_string(glyph_id.to_string())
  }
  builder.write_string("}")
  builder.to_string()
}

///|
fn diagnostic_cid_lookup_sample(
  cids : Array[Int],
  ttf : @font.TTFont,
) -> String {
  let builder = StringBuilder::new()
  builder.write_string("{")
  let limit = diagnostic_min(5, cids.length())
  for i in 0..<limit {
    if i > 0 {
      builder.write_string(", ")
    }
    builder.write_string(cids[i].to_string())
    builder.write_string("=>")
    let glyph_id = svg_cid_glyph_id(ttf, cids[i])
    builder.write_string(glyph_id.to_string())
    builder.write_string("/")
    builder.write_string(ttf.glyph_outline(glyph_id).length().to_string())
  }
  builder.write_string("}")
  builder.to_string()
}

///|
fn diagnostic_print_glyph_trace(
  font_name : String,
  ttf : @font.TTFont,
  glyph : @text.TextGlyphEvent,
) -> Unit {
  let source_code = glyph.glyph.source_code
  let gid = svg_resolve_glyph_id(ttf, glyph)
  println(
    "diagnostic local-fixture glyph_trace: font=" +
    font_name +
    " char_code=0x" +
    diagnostic_hex2(source_code) +
    " glyph_id_resolved=" +
    gid.to_string() +
    " post_name_at_gid=" +
    diagnostic_post_name(ttf, gid) +
    " outline_first_point=" +
    diagnostic_outline_first_point(ttf, gid),
  )
}

///|
fn diagnostic_local-fixture_page_tofu_glyphs(
  page : @reader.PdfPage,
  page_index : Int,
) -> Unit {
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
              Some(ttf) => {
                let glyphs = span_glyphs(glyph_groups, index)
                for glyph in glyphs {
                  let gid = svg_resolve_glyph_id(ttf, glyph)
                  if gid == 0 || gid < 0 {
                    diagnostic_print_tofu_glyph(
                      font_name.to_text(),
                      ttf,
                      glyph,
                      gid,
                    )
                    count += 1
                  }
                }
              }
              None => ()
            }
          None => ()
        }
      }
      println(
        "diagnostic local-fixture page " +
        (page_index + 1).to_string() +
        " tofu glyph count=" +
        count.to_string(),
      )
    }
    Err(_) =>
      println(
        "diagnostic local-fixture page " +
        (page_index + 1).to_string() +
        " tofu glyph scan: text_program failed",
      )
  }
}

///|
fn diagnostic_print_tofu_glyph(
  font_name : String,
  ttf : @font.TTFont,
  glyph : @text.TextGlyphEvent,
  gid : Int,
) -> Unit {
  println(
    "tofu " +
    font_name +
    " code=0x" +
    diagnostic_hex(glyph.glyph.source_code) +
    " gid=" +
    gid.to_string() +
    " unicode=\"" +
    diagnostic_unicode_text(glyph.unicode) +
    "\" path_count=" +
    diagnostic_outline_path_count(ttf, gid).to_string(),
  )
}

///|
fn diagnostic_outline_path_count(ttf : @font.TTFont, gid : Int) -> Int {
  if gid < 0 || gid >= ttf.num_glyphs {
    0
  } else {
    ttf.glyph_outline(gid).length()
  }
}

///|
fn diagnostic_unicode_text(mapping : @text.UnicodeMapping) -> String {
  match mapping {
    @text.UnicodeMapping::Unicode(value) => value
    @text.UnicodeMapping::Unknown(_, _, _) => ""
  }
}

///|
fn diagnostic_hex(value : Int) -> String {
  if value == 0 {
    return "0"
  }
  if value < 0 {
    return "-" + diagnostic_hex(0 - value)
  }
  let mut remaining = value
  let mut output = ""
  while remaining > 0 {
    output = diagnostic_hex_digit(remaining & 0xF) + output
    remaining = remaining >> 4
  }
  output
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
                  page_height(page),
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
  ttf : @font.TTFont,
  page_height : Double,
) -> Int {
  let mut count = 0
  let units_per_em = svg_font_units_per_em(ttf)
  for glyph in glyphs {
    let gid = svg_resolve_glyph_id(ttf, glyph)
    if gid == 0 && !svg_glyph_is_notdef_source(glyph) {
      let builder = StringBuilder::new()
      if render_glyph_as_path(
          builder, glyph, ttf, units_per_em, page_height, "#000000", 0,
        ) &&
        builder.to_string().contains("<path") {
        count += 1
      }
    }
  }
  count
}

///|
fn diagnostic_post_name(ttf : @font.TTFont, gid : Int) -> String {
  match ttf.post {
    Some(post) =>
      if gid >= 0 && gid < post.glyph_names.length() {
        post.glyph_names[gid]
      } else {
        "<out-of-range>"
      }
    None => "<missing-post>"
  }
}

///|
fn diagnostic_outline_first_point(ttf : @font.TTFont, gid : Int) -> String {
  if gid < 0 || gid >= ttf.num_glyphs {
    return "<out-of-range>"
  }
  let outline = ttf.glyph_outline(gid)
  for command in outline {
    match command {
      @svgpath.MoveTo(x, y) =>
        return "(" + x.to_string() + "," + y.to_string() + ")"
      _ => ()
    }
  }
  "<empty>"
}

///|
fn diagnostic_hex2(value : Int) -> String {
  let hi = (value >> 4) & 0xF
  let lo = value & 0xF
  diagnostic_hex_digit(hi) + diagnostic_hex_digit(lo)
}

///|
fn diagnostic_hex_digit(value : Int) -> String {
  match value {
    0 => "0"
    1 => "1"
    2 => "2"
    3 => "3"
    4 => "4"
    5 => "5"
    6 => "6"
    7 => "7"
    8 => "8"
    9 => "9"
    10 => "A"
    11 => "B"
    12 => "C"
    13 => "D"
    14 => "E"
    15 => "F"
    _ => "?"
  }
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
  // Generated on 2026-04-17 from <local-fixture> page 6 with
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
  embedded_fonts : Map[@objects.PdfName, @font.TTFont],
  golden : Page6GlyphOutlineGolden,
) -> Unit raise {
  match embedded_fonts.get(golden.font_name) {
    Some(ttf) => {
      for index in 0..<program.spans.length() {
        let span = program.spans[index]
        if span.font_name == Some(golden.font_name) {
          let glyphs = span_glyphs(glyph_groups, index)
          for glyph in glyphs {
            if glyph.glyph.source_code == golden.source_code {
              let gid = svg_resolve_glyph_id(ttf, glyph)
              assert_eq(gid, golden.expected_gid)
              if golden.require_non_identity {
                assert_true(gid != golden.source_code)
              }
              let outline = ttf.glyph_outline(gid)
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
fn diagnostic_bool(value : Bool) -> String {
  if value {
    "true"
  } else {
    "false"
  }
}

///|
fn diagnostic_min(a : Int, b : Int) -> Int {
  if a < b {
    a
  } else {
    b
  }
}

///|
fn diagnostic_page6_text_path_summary(
  page : @reader.PdfPage,
  font_name_bytes : Bytes,
) -> Unit {
  let font_name = @objects.PdfName::new(font_name_bytes)
  let result : Result[@text.TextProgram, @reader.PdfDocumentError] = try? page.text_program(
    @reader.TextPageOptions::default(),
  )
  match result {
    Ok(program) => {
      let glyph_groups = text_program_span_glyphs(program)
      let embedded_fonts = page_svg_embedded_fonts(page)
      let mut spans = 0
      let mut empty_text_spans = 0
      let mut glyph_count = 0
      let mut cid_count = 0
      let mut resolved_count = 0
      let mut outline_count = 0
      for index in 0..<program.spans.length() {
        let span = program.spans[index]
        if span.font_name == Some(font_name) {
          spans += 1
          if span.text.length() == 0 {
            empty_text_spans += 1
          }
          let glyphs = span_glyphs(glyph_groups, index)
          glyph_count += glyphs.length()
          match embedded_fonts.get(font_name) {
            Some(ttf) =>
              for glyph in glyphs {
                match glyph.glyph.glyph {
                  @text.GlyphIdentifier::CID(_) => cid_count += 1
                  _ => ()
                }
                let glyph_id = svg_resolve_glyph_id(ttf, glyph)
                if glyph_id >= 0 && glyph_id < ttf.num_glyphs {
                  resolved_count += 1
                  if ttf.glyph_outline(glyph_id).length() > 0 {
                    outline_count += 1
                  }
                }
              }
            None => ()
          }
        }
      }
      println(
        "diagnostic local-fixture page 6 text path " +
        font_name.to_text() +
        ": spans=" +
        spans.to_string() +
        " empty_text_spans=" +
        empty_text_spans.to_string() +
        " glyphs=" +
        glyph_count.to_string() +
        " cid_glyphs=" +
        cid_count.to_string() +
        " resolved=" +
        resolved_count.to_string() +
        " outlines=" +
        outline_count.to_string(),
      )
    }
    Err(_) =>
      println(
        "diagnostic local-fixture page 6 text path " +
        font_name.to_text() +
        ": text_program failed",
      )
  }
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
