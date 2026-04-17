///|
test "standard14_base_name strips style suffixes" {
  assert_eq(standard14_base_name("Helvetica"), "Helvetica")
  assert_eq(standard14_base_name("Helvetica-Bold"), "Helvetica")
  assert_eq(standard14_base_name("Helvetica-Oblique"), "Helvetica")
  assert_eq(standard14_base_name("Helvetica-BoldOblique"), "Helvetica")
  assert_eq(standard14_base_name("Times-Roman"), "Times")
  assert_eq(standard14_base_name("Times-Bold"), "Times")
  assert_eq(standard14_base_name("Times-Italic"), "Times")
  assert_eq(standard14_base_name("Times-BoldItalic"), "Times")
  assert_eq(standard14_base_name("Courier-Bold"), "Courier")
  assert_eq(standard14_base_name("Symbol"), "Symbol")
  assert_eq(standard14_base_name("ABCDEF+Helvetica-Bold"), "Helvetica")
}

///|
test "standard14_candidate_names returns standard alternatives" {
  assert_eq(standard14_candidate_names("Helvetica"), ["Helvetica", "Arial"])
  assert_eq(standard14_candidate_names("Times"), ["Times", "Times New Roman"])
  assert_eq(standard14_candidate_names("Courier"), ["Courier", "Courier New"])
  assert_eq(standard14_candidate_names("Symbol"), ["Symbol"])
  assert_eq(standard14_candidate_names("ZapfDingbats"), ["ZapfDingbats"])
}

///|
test "system_font_directories returns search roots" {
  let dirs = system_font_directories()
  assert_eq(dirs.length() > 0, true)
  if @fs.path_exists("/System/Library/Fonts/") {
    assert_eq(dirs[0], "/System/Library/Fonts/")
  } else {
    assert_eq(dirs[0], "/usr/share/fonts/")
  }
}

///|
test "resolve_system_font parses Helvetica when available" {
  let font = resolve_system_font("Helvetica")
  if @fs.path_exists("/System/Library/Fonts/Helvetica.ttc") {
    match font {
      Some(ttf) => assert_eq(ttf.units_per_em > 0, true)
      None => fail("expected macOS Helvetica.ttc to resolve")
    }
  } else {
    match font {
      Some(ttf) => assert_eq(ttf.units_per_em > 0, true)
      None => ()
    }
  }
}
