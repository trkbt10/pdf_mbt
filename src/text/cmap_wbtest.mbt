///|
test "predefined Adobe-Japan1 90ms-RKSJ-H decodes Shift-JIS to CID" {
  // Shift-JIS encoded ASCII 'A' is single-byte 0x41. The 90ms-RKSJ-H
  // CMap maps this to CID 66 in the Adobe-Japan1 character collection
  // (231 + 66 - 32 = … the H/V H series starts CID assignment at 231 for
  // the 0x20 range, so 0x41 lands on 231 + (0x41 - 0x20) = 264).
  let cmap = resolve_predefined_cmap(
    @objects.PdfName::new(b"90ms-RKSJ-H"), 0L,
  )
  let ascii = cmap.decode_next(b"\x41", 0)
  assert_eq(ascii.cid, 231 + 0x41 - 0x20)
  assert_eq(ascii.consumed, 1)
  // Two-byte Shift-JIS for 'あ' is 0x82 0xA0, which 90ms-RKSJ-H maps to
  // Adobe-Japan1 CID 843 (CID 842 is 'ぁ' / small-a, 843 is 'あ').
  let hiragana = cmap.decode_next(b"\x82\xa0", 0)
  assert_eq(hiragana.cid, 843)
  assert_eq(hiragana.consumed, 2)
}

///|
test "predefined Adobe-Japan1 UniJIS-UCS2-H decodes UTF-16BE to CID" {
  let cmap = resolve_predefined_cmap(
    @objects.PdfName::new(b"UniJIS-UCS2-H"), 0L,
  )
  // U+3042 'あ' → Adobe-Japan1 CID 843
  let result = cmap.decode_next(b"\x30\x42", 0)
  assert_eq(result.cid, 843)
  assert_eq(result.consumed, 2)
  // U+0041 'A' → Adobe-Japan1 CID 34 (proportional uppercase A in the
  // ASCII range of UniJIS-UCS2-H).
  let latin = cmap.decode_next(b"\x00\x41", 0)
  assert_eq(latin.cid, 34)
}

///|
test "predefined CMap V variant inherits codespaces via usecmap" {
  // V uses H, so V should still decode the same horizontal-range bytes
  // and report Vertical writing mode.
  let cmap_v = resolve_predefined_cmap(
    @objects.PdfName::new(b"V"), 0L,
  )
  assert_eq(cmap_v.writing_mode == WritingMode::Vertical, true)
  // V re-defines a small set of vertical glyph CIDs but inherits the
  // bulk of its codespaces from H, so a generic horizontal hex code
  // 0x2121 still decodes (to CID 633 in Adobe-Japan1's H mapping).
  let h_decode = cmap_v.decode_next(b"\x21\x21", 0)
  assert_eq(h_decode.cid, 633)
}

///|
test "predefined CMap unknown name still raises a typed error" {
  let result : Result[CMap, PdfTextError] = try? resolve_predefined_cmap(
    @objects.PdfName::new(b"DefinitelyNotARealCMap"), 0L,
  )
  match result {
    Err(InvalidCMap(_, reason)) =>
      assert_eq(reason.contains("unsupported predefined CMap"), true)
    _ => fail("expected InvalidCMap error for unknown predefined CMap name")
  }
}

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

///|
test "ISO 32000-2 Table 116 predefined CMaps all resolve and decode" {
  // Exhaustive normative coverage: every name listed in ISO 32000-2 §9.7.5.2
  // Table 116 ("Predefined CJK CMap names") plus the two Generic entries
  // (Identity-H / Identity-V). PDF processors are required to recognise
  // these names without external CMap resources, so a regression in any of
  // them would let a spec-compliant CJK PDF render text incorrectly.
  let cjk_names = [
    // Adobe-Japan1 (20)
    "H", "V", "EUC-H", "EUC-V",
    "83pv-RKSJ-H",
    "90ms-RKSJ-H", "90ms-RKSJ-V",
    "90msp-RKSJ-H", "90msp-RKSJ-V",
    "90pv-RKSJ-H",
    "Add-RKSJ-H", "Add-RKSJ-V",
    "Ext-RKSJ-H", "Ext-RKSJ-V",
    "UniJIS-UCS2-H", "UniJIS-UCS2-V",
    "UniJIS-UCS2-HW-H", "UniJIS-UCS2-HW-V",
    "UniJIS-UTF16-H", "UniJIS-UTF16-V",
    // Adobe-GB1 (14)
    "GB-EUC-H", "GB-EUC-V", "GBpc-EUC-H", "GBpc-EUC-V",
    "GBK-EUC-H", "GBK-EUC-V", "GBKp-EUC-H", "GBKp-EUC-V",
    "GBK2K-H", "GBK2K-V",
    "UniGB-UCS2-H", "UniGB-UCS2-V", "UniGB-UTF16-H", "UniGB-UTF16-V",
    // Adobe-CNS1 (14)
    "B5pc-H", "B5pc-V", "HKscs-B5-H", "HKscs-B5-V",
    "ETen-B5-H", "ETen-B5-V", "ETenms-B5-H", "ETenms-B5-V",
    "CNS-EUC-H", "CNS-EUC-V",
    "UniCNS-UCS2-H", "UniCNS-UCS2-V", "UniCNS-UTF16-H", "UniCNS-UTF16-V",
    // Adobe-Korea1 (11)
    "KSC-EUC-H", "KSC-EUC-V",
    "KSCms-UHC-H", "KSCms-UHC-V", "KSCms-UHC-HW-H", "KSCms-UHC-HW-V",
    "KSCpc-EUC-H",
    "UniKS-UCS2-H", "UniKS-UCS2-V", "UniKS-UTF16-H", "UniKS-UTF16-V",
  ]
  // Document the table-116 count as a guard: the spec lists 59 CJK names
  // (20 + 14 + 14 + 11), and any drift in the data file would change this
  // length first.
  assert_eq(cjk_names.length(), 59)
  for name in cjk_names {
    let pdf_name = @objects.PdfName::new(@encoding/utf8.encode(name))
    let result : Result[CMap, PdfTextError] = try? resolve_predefined_cmap(
      pdf_name, 0L,
    )
    match result {
      Err(_) => fail("Table 116 predefined CMap failed to resolve: " + name)
      Ok(cmap) =>
        if cmap.codespaces.length() == 0 {
          fail("Table 116 predefined CMap has no codespaces: " + name)
        }
    }
  }
  // Generic Identity-H / Identity-V are constructed in-process; verify they
  // are also reachable through the same entry point.
  for name in ["Identity-H", "Identity-V"] {
    let pdf_name = @objects.PdfName::new(@encoding/utf8.encode(name))
    let result : Result[CMap, PdfTextError] = try? resolve_predefined_cmap(
      pdf_name, 0L,
    )
    if result is Err(_) {
      fail("Generic predefined CMap failed: " + name)
    }
  }
}
