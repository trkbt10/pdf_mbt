///|
test "recognize_operator maps every required Annex A keyword exactly" {
  assert_operator(b"q", SaveGraphicsState)
  assert_operator(b"Q", RestoreGraphicsState)
  assert_operator(b"cm", ConcatMatrix)
  assert_operator(b"w", SetLineWidth)
  assert_operator(b"J", SetLineCap)
  assert_operator(b"j", SetLineJoin)
  assert_operator(b"M", SetMiterLimit)
  assert_operator(b"d", SetLineDash)
  assert_operator(b"ri", SetRenderingIntent)
  assert_operator(b"i", SetFlatness)
  assert_operator(b"gs", SetExtGState)

  assert_operator(b"m", MoveTo)
  assert_operator(b"l", LineTo)
  assert_operator(b"c", CurveTo)
  assert_operator(b"v", CurveToInitialReplicated)
  assert_operator(b"y", CurveToFinalReplicated)
  assert_operator(b"h", ClosePath)
  assert_operator(b"re", Rectangle)

  assert_operator(b"S", Stroke)
  assert_operator(b"s", CloseAndStroke)
  assert_operator(b"f", FillNonzero)
  assert_operator(b"F", FillNonzeroDeprecated)
  assert_operator(b"f*", FillEvenOdd)
  assert_operator(b"B", FillStrokeNonzero)
  assert_operator(b"B*", FillStrokeEvenOdd)
  assert_operator(b"b", CloseFillStrokeNonzero)
  assert_operator(b"b*", CloseFillStrokeEvenOdd)
  assert_operator(b"n", EndPath)

  assert_operator(b"W", ClipNonzero)
  assert_operator(b"W*", ClipEvenOdd)

  assert_operator(b"BT", BeginText)
  assert_operator(b"ET", EndText)
  assert_operator(b"Tc", SetCharacterSpacing)
  assert_operator(b"Tw", SetWordSpacing)
  assert_operator(b"Tz", SetHorizontalScaling)
  assert_operator(b"TL", SetTextLeading)
  assert_operator(b"Tf", SetTextFont)
  assert_operator(b"Tr", SetTextRenderingMode)
  assert_operator(b"Ts", SetTextRise)
  assert_operator(b"Td", MoveTextPosition)
  assert_operator(b"TD", MoveTextPositionSetLeading)
  assert_operator(b"Tm", SetTextMatrix)
  assert_operator(b"T*", MoveToNextLine)
  assert_operator(b"Tj", ShowText)
  assert_operator(b"TJ", ShowTextAdjusted)
  assert_operator(b"'", QuoteShowText)
  assert_operator(b"\"", DoubleQuoteShowText)
  assert_operator(b"d0", SetGlyphWidth)
  assert_operator(b"d1", SetGlyphWidthAndBoundingBox)

  assert_operator(b"CS", SetStrokingColorSpace)
  assert_operator(b"cs", SetNonstrokingColorSpace)
  assert_operator(b"SC", SetStrokingColor)
  assert_operator(b"SCN", SetStrokingColorSpecial)
  assert_operator(b"sc", SetNonstrokingColor)
  assert_operator(b"scn", SetNonstrokingColorSpecial)
  assert_operator(b"G", SetStrokingGray)
  assert_operator(b"g", SetNonstrokingGray)
  assert_operator(b"RG", SetStrokingRgb)
  assert_operator(b"rg", SetNonstrokingRgb)
  assert_operator(b"K", SetStrokingCmyk)
  assert_operator(b"k", SetNonstrokingCmyk)

  assert_operator(b"Do", InvokeXObject)
  assert_operator(b"BI", BeginInlineImage)
  assert_operator(b"ID", BeginInlineImageData)
  assert_operator(b"EI", EndInlineImage)

  assert_operator(b"MP", BeginMarkedContentPoint)
  assert_operator(b"DP", DefineMarkedContentPoint)
  assert_operator(b"BMC", BeginMarkedContent)
  assert_operator(b"BDC", BeginMarkedContentWithProperties)
  assert_operator(b"EMC", EndMarkedContent)

  assert_operator(b"BX", BeginCompatibility)
  assert_operator(b"EX", EndCompatibility)

  assert_operator(b"sh", PaintShading)
}

///|
test "recognize_operator keeps unknown keywords distinguishable" {
  match recognize_operator(b"ZZ") {
    None => ()
    Some(_) => fail("expected unknown keyword to remain distinguishable")
  }
  match recognize_operator(b"Bi") {
    None => ()
    Some(_) => fail("expected mixed-case keyword to remain distinguishable")
  }
  match recognize_operator(b"I") {
    None => ()
    Some(_) =>
      fail("expected single-letter unknown keyword to remain distinguishable")
  }
}

///|
fn assert_operator(
  keyword : Bytes,
  expected : StandardContentOperator,
) -> Unit raise {
  match recognize_operator(keyword) {
    Some(actual) => assert_eq(actual == expected, true)
    None => fail("expected keyword to be recognized")
  }
}
