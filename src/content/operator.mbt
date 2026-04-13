///|
/// Standard Annex A content-stream operator vocabulary.
pub(all) enum StandardContentOperator {
  SaveGraphicsState
  RestoreGraphicsState
  ConcatMatrix
  SetLineWidth
  SetLineCap
  SetLineJoin
  SetMiterLimit
  SetLineDash
  SetRenderingIntent
  SetFlatness
  SetExtGState
  MoveTo
  LineTo
  CurveTo
  CurveToInitialReplicated
  CurveToFinalReplicated
  ClosePath
  Rectangle
  Stroke
  CloseAndStroke
  FillNonzero
  FillNonzeroDeprecated
  FillEvenOdd
  FillStrokeNonzero
  FillStrokeEvenOdd
  CloseFillStrokeNonzero
  CloseFillStrokeEvenOdd
  EndPath
  ClipNonzero
  ClipEvenOdd
  BeginText
  EndText
  SetCharacterSpacing
  SetWordSpacing
  SetHorizontalScaling
  SetTextLeading
  SetTextFont
  SetTextRenderingMode
  SetTextRise
  MoveTextPosition
  MoveTextPositionSetLeading
  SetTextMatrix
  MoveToNextLine
  ShowText
  ShowTextAdjusted
  QuoteShowText
  DoubleQuoteShowText
  SetStrokingColorSpace
  SetNonstrokingColorSpace
  SetStrokingColor
  SetStrokingColorSpecial
  SetNonstrokingColor
  SetNonstrokingColorSpecial
  SetStrokingGray
  SetNonstrokingGray
  SetStrokingRgb
  SetNonstrokingRgb
  SetStrokingCmyk
  SetNonstrokingCmyk
  InvokeXObject
  BeginInlineImage
  BeginInlineImageData
  EndInlineImage
  BeginMarkedContentPoint
  DefineMarkedContentPoint
  BeginMarkedContent
  BeginMarkedContentWithProperties
  EndMarkedContent
  BeginCompatibility
  EndCompatibility
  PaintShading
  SetGlyphWidth
  SetGlyphWidthAndBoundingBox
} derive(Eq, Debug)

///|
/// Recognizes exact Annex A operator keywords and leaves unknown keywords as
/// `None` so parser-level unknown-operator handling can remain distinct.
pub fn recognize_operator(keyword : Bytes) -> StandardContentOperator? {
  if keyword == b"q" {
    Some(SaveGraphicsState)
  } else if keyword == b"Q" {
    Some(RestoreGraphicsState)
  } else if keyword == b"cm" {
    Some(ConcatMatrix)
  } else if keyword == b"w" {
    Some(SetLineWidth)
  } else if keyword == b"J" {
    Some(SetLineCap)
  } else if keyword == b"j" {
    Some(SetLineJoin)
  } else if keyword == b"M" {
    Some(SetMiterLimit)
  } else if keyword == b"d" {
    Some(SetLineDash)
  } else if keyword == b"ri" {
    Some(SetRenderingIntent)
  } else if keyword == b"i" {
    Some(SetFlatness)
  } else if keyword == b"gs" {
    Some(SetExtGState)
  } else if keyword == b"m" {
    Some(MoveTo)
  } else if keyword == b"l" {
    Some(LineTo)
  } else if keyword == b"c" {
    Some(CurveTo)
  } else if keyword == b"v" {
    Some(CurveToInitialReplicated)
  } else if keyword == b"y" {
    Some(CurveToFinalReplicated)
  } else if keyword == b"h" {
    Some(ClosePath)
  } else if keyword == b"re" {
    Some(Rectangle)
  } else if keyword == b"S" {
    Some(Stroke)
  } else if keyword == b"s" {
    Some(CloseAndStroke)
  } else if keyword == b"f" {
    Some(FillNonzero)
  } else if keyword == b"F" {
    Some(FillNonzeroDeprecated)
  } else if keyword == b"f*" {
    Some(FillEvenOdd)
  } else if keyword == b"B" {
    Some(FillStrokeNonzero)
  } else if keyword == b"B*" {
    Some(FillStrokeEvenOdd)
  } else if keyword == b"b" {
    Some(CloseFillStrokeNonzero)
  } else if keyword == b"b*" {
    Some(CloseFillStrokeEvenOdd)
  } else if keyword == b"n" {
    Some(EndPath)
  } else if keyword == b"W" {
    Some(ClipNonzero)
  } else if keyword == b"W*" {
    Some(ClipEvenOdd)
  } else if keyword == b"BT" {
    Some(BeginText)
  } else if keyword == b"ET" {
    Some(EndText)
  } else if keyword == b"Tc" {
    Some(SetCharacterSpacing)
  } else if keyword == b"Tw" {
    Some(SetWordSpacing)
  } else if keyword == b"Tz" {
    Some(SetHorizontalScaling)
  } else if keyword == b"TL" {
    Some(SetTextLeading)
  } else if keyword == b"Tf" {
    Some(SetTextFont)
  } else if keyword == b"Tr" {
    Some(SetTextRenderingMode)
  } else if keyword == b"Ts" {
    Some(SetTextRise)
  } else if keyword == b"Td" {
    Some(MoveTextPosition)
  } else if keyword == b"TD" {
    Some(MoveTextPositionSetLeading)
  } else if keyword == b"Tm" {
    Some(SetTextMatrix)
  } else if keyword == b"T*" {
    Some(MoveToNextLine)
  } else if keyword == b"Tj" {
    Some(ShowText)
  } else if keyword == b"TJ" {
    Some(ShowTextAdjusted)
  } else if keyword == b"'" {
    Some(QuoteShowText)
  } else if keyword == b"\"" {
    Some(DoubleQuoteShowText)
  } else if keyword == b"d0" {
    Some(SetGlyphWidth)
  } else if keyword == b"d1" {
    Some(SetGlyphWidthAndBoundingBox)
  } else if keyword == b"CS" {
    Some(SetStrokingColorSpace)
  } else if keyword == b"cs" {
    Some(SetNonstrokingColorSpace)
  } else if keyword == b"SC" {
    Some(SetStrokingColor)
  } else if keyword == b"SCN" {
    Some(SetStrokingColorSpecial)
  } else if keyword == b"sc" {
    Some(SetNonstrokingColor)
  } else if keyword == b"scn" {
    Some(SetNonstrokingColorSpecial)
  } else if keyword == b"G" {
    Some(SetStrokingGray)
  } else if keyword == b"g" {
    Some(SetNonstrokingGray)
  } else if keyword == b"RG" {
    Some(SetStrokingRgb)
  } else if keyword == b"rg" {
    Some(SetNonstrokingRgb)
  } else if keyword == b"K" {
    Some(SetStrokingCmyk)
  } else if keyword == b"k" {
    Some(SetNonstrokingCmyk)
  } else if keyword == b"Do" {
    Some(InvokeXObject)
  } else if keyword == b"BI" {
    Some(BeginInlineImage)
  } else if keyword == b"ID" {
    Some(BeginInlineImageData)
  } else if keyword == b"EI" {
    Some(EndInlineImage)
  } else if keyword == b"MP" {
    Some(BeginMarkedContentPoint)
  } else if keyword == b"DP" {
    Some(DefineMarkedContentPoint)
  } else if keyword == b"BMC" {
    Some(BeginMarkedContent)
  } else if keyword == b"BDC" {
    Some(BeginMarkedContentWithProperties)
  } else if keyword == b"EMC" {
    Some(EndMarkedContent)
  } else if keyword == b"BX" {
    Some(BeginCompatibility)
  } else if keyword == b"EX" {
    Some(EndCompatibility)
  } else if keyword == b"sh" {
    Some(PaintShading)
  } else {
    None
  }
}
