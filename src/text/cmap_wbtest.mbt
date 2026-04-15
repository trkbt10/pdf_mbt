///|
test "predefined identity CMaps decode two byte CIDs and writing mode" {
  let cmap = resolve_predefined_cmap(@objects.PdfName::new(b"Identity-V"), 0L)
  let decoded = cmap.decode_next(b"\x12\x34", 0)
  assert_eq(decoded.cid, 0x1234)
  assert_eq(decoded.consumed, 2)
  assert_eq(decoded.writing_mode == WritingMode::Vertical, true)
  assert_eq(decoded.fallback == GlyphFallback::NoFallback, true)
}

///|
test "embedded CMap parser reads metadata codespaces and CID mappings" {
  let cmap = parse_decoded_cmap(
    b"/CIDInit /ProcSet findresource begin\n12 dict begin\nbegincmap\n/CIDSystemInfo << /Registry (Adobe) /Ordering (Japan1) /Supplement 7 >> def\n/CMapName /Test-H def\n/WMode 0 def\n1 begincodespacerange\n<00> <ff>\nendcodespacerange\n2 begincidchar\n<20> 99\n<21> 100\nendcidchar\n1 begincidrange\n<30> <32> 200\nendcidrange\n1 beginnotdefrange\n<40> <41> 5\nendnotdefrange\nendcmap",
    0L,
    TextInterpretationLimits::default(),
  )
  assert_eq(cmap.name == Some(@objects.PdfName::new(b"Test-H")), true)
  match cmap.cid_system_info {
    Some(info) => assert_eq(info.ordering, "Japan1")
    None => fail("expected CIDSystemInfo")
  }
  assert_eq(cmap.codespaces.length(), 1)

  let direct = cmap.decode_next(b"\x20", 0)
  assert_eq(direct.cid, 99)
  assert_eq(direct.fallback == GlyphFallback::NoFallback, true)

  let ranged = cmap.decode_next(b"\x31", 0)
  assert_eq(ranged.cid, 201)

  let notdef = cmap.decode_next(b"\x40", 0)
  assert_eq(notdef.cid, 5)
  assert_eq(notdef.fallback == GlyphFallback::NotdefGlyph, true)

  let missing = cmap.decode_next(b"\x50", 0)
  assert_eq(missing.cid, 0)
  assert_eq(missing.fallback == GlyphFallback::CIDZero, true)
}

///|
test "embedded CMap parser rejects overlapping codespaces" {
  let result : Result[CMap, PdfTextError] = try? parse_decoded_cmap(
    b"2 begincodespacerange\n<00> <7f>\n<20> <ff>\nendcodespacerange",
    0L,
    TextInterpretationLimits::default(),
  )
  match result {
    Err(InvalidCMap(_, reason)) =>
      assert_eq(reason.contains("overlapping"), true)
    _ => fail("expected overlapping CMap error")
  }
}

///|
test "ToUnicode parser maps bfchar bfrange increments and arrays" {
  let cmap = parse_decoded_to_unicode_cmap(
    b"/CMapName /UniTest def\n1 begincodespacerange\n<00> <ff>\nendcodespacerange\n1 beginbfchar\n<01> <0041>\nendbfchar\n1 beginbfrange\n<02> <04> <0042>\nendbfrange\n1 beginbfrange\n<10> <11> [<00660069> <D83DDE00>]\nendbfrange",
    0L,
    TextInterpretationLimits::default(),
  )
  assert_eq(cmap.map_source_code(b"\x01"), Some("A"))
  assert_eq(cmap.map_source_code(b"\x02"), Some("B"))
  assert_eq(cmap.map_source_code(b"\x04"), Some("D"))
  assert_eq(cmap.map_source_code(b"\x10"), Some("fi"))
  assert_eq(cmap.map_source_code(b"\x11"), Some("😀"))
  assert_eq(cmap.map_source_code(b"\x12"), None)
}

///|
test "ToUnicode parser rejects malformed UTF-16BE destinations" {
  let result : Result[ToUnicodeCMap, PdfTextError] = try? parse_decoded_to_unicode_cmap(
    b"1 beginbfchar\n<01> <D83D0041>\nendbfchar",
    0L,
    TextInterpretationLimits::default(),
  )
  match result {
    Err(UnicodeConversion(_, reason)) =>
      assert_eq(reason.contains("low surrogate"), true)
    _ => fail("expected unicode conversion error")
  }
}
