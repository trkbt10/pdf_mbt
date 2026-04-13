///|
/// Section 8.2 graphics object context: content stream level, active path
/// object, or active text object.
enum GraphicsObjectLevel {
  ContentStreamLevel
  PathObject
  TextObject
} derive(Eq, Debug)

///|
struct GraphicsObjectContext {
  mut level : GraphicsObjectLevel
} derive(Eq, Debug)

///|
fn GraphicsObjectContext::new() -> GraphicsObjectContext {
  GraphicsObjectContext::{ level: GraphicsObjectLevel::ContentStreamLevel }
}

///|
fn GraphicsObjectContext::accept(
  self : GraphicsObjectContext,
  operator : @content.StandardContentOperator,
  offset : Int64,
) -> Unit raise PdfGraphicsError {
  match self.level {
    ContentStreamLevel => self.accept_content_level(operator, offset)
    PathObject => self.accept_path_object(operator, offset)
    TextObject => self.accept_text_object(operator, offset)
  }
}

///|
fn GraphicsObjectContext::accept_content_level(
  self : GraphicsObjectContext,
  operator : @content.StandardContentOperator,
  offset : Int64,
) -> Unit raise PdfGraphicsError {
  if is_path_construction_operator(operator) {
    self.level = GraphicsObjectLevel::PathObject
  } else if operator == @content.StandardContentOperator::BeginText {
    self.level = GraphicsObjectLevel::TextObject
  } else if operator == @content.StandardContentOperator::EndText {
    raise PdfGraphicsError::InvalidObjectContext(
      offset, "ET cannot appear outside a text object",
    )
  } else {
    ()
  }
}

///|
fn GraphicsObjectContext::accept_path_object(
  self : GraphicsObjectContext,
  operator : @content.StandardContentOperator,
  offset : Int64,
) -> Unit raise PdfGraphicsError {
  if is_path_construction_operator(operator) || is_clipping_operator(operator) {
    ()
  } else if is_path_painting_operator(operator) {
    self.level = GraphicsObjectLevel::ContentStreamLevel
  } else {
    raise PdfGraphicsError::InvalidObjectContext(
      offset, "path object permits path construction, clipping, and path-painting operators only",
    )
  }
}

///|
fn GraphicsObjectContext::accept_text_object(
  self : GraphicsObjectContext,
  operator : @content.StandardContentOperator,
  offset : Int64,
) -> Unit raise PdfGraphicsError {
  if operator == @content.StandardContentOperator::EndText {
    self.level = GraphicsObjectLevel::ContentStreamLevel
  } else if operator == @content.StandardContentOperator::BeginText {
    raise PdfGraphicsError::InvalidObjectContext(
      offset, "BT cannot be nested inside a text object",
    )
  } else if is_path_construction_operator(operator) ||
    is_path_painting_operator(operator) ||
    is_clipping_operator(operator) {
    raise PdfGraphicsError::InvalidObjectContext(
      offset, "path graphics operators cannot appear inside a text object",
    )
  } else {
    ()
  }
}

///|
fn is_graphics_state_operator(
  operator : @content.StandardContentOperator,
) -> Bool {
  match operator {
    SaveGraphicsState
    | RestoreGraphicsState
    | ConcatMatrix
    | SetLineWidth
    | SetLineCap
    | SetLineJoin
    | SetMiterLimit
    | SetLineDash
    | SetRenderingIntent
    | SetFlatness
    | SetExtGState => true
    _ => false
  }
}

///|
fn is_path_construction_operator(
  operator : @content.StandardContentOperator,
) -> Bool {
  match operator {
    MoveTo
    | LineTo
    | CurveTo
    | CurveToInitialReplicated
    | CurveToFinalReplicated
    | ClosePath
    | Rectangle => true
    _ => false
  }
}

///|
fn is_path_painting_operator(
  operator : @content.StandardContentOperator,
) -> Bool {
  match operator {
    Stroke
    | CloseAndStroke
    | FillNonzero
    | FillNonzeroDeprecated
    | FillEvenOdd
    | FillStrokeNonzero
    | FillStrokeEvenOdd
    | CloseFillStrokeNonzero
    | CloseFillStrokeEvenOdd
    | EndPath => true
    _ => false
  }
}

///|
fn is_clipping_operator(operator : @content.StandardContentOperator) -> Bool {
  match operator {
    ClipNonzero | ClipEvenOdd => true
    _ => false
  }
}

///|
fn is_color_operator(operator : @content.StandardContentOperator) -> Bool {
  match operator {
    SetStrokingColorSpace
    | SetNonstrokingColorSpace
    | SetStrokingColor
    | SetStrokingColorSpecial
    | SetNonstrokingColor
    | SetNonstrokingColorSpecial
    | SetStrokingGray
    | SetNonstrokingGray
    | SetStrokingRgb
    | SetNonstrokingRgb
    | SetStrokingCmyk
    | SetNonstrokingCmyk => true
    _ => false
  }
}

///|
fn is_text_domain_operator(operator : @content.StandardContentOperator) -> Bool {
  match operator {
    SetCharacterSpacing
    | SetWordSpacing
    | SetHorizontalScaling
    | SetTextLeading
    | SetTextFont
    | SetTextRenderingMode
    | SetTextRise
    | MoveTextPosition
    | MoveTextPositionSetLeading
    | SetTextMatrix
    | MoveToNextLine
    | ShowText
    | ShowTextAdjusted
    | QuoteShowText
    | DoubleQuoteShowText
    | SetGlyphWidth
    | SetGlyphWidthAndBoundingBox => true
    _ => false
  }
}

///|
fn is_marked_content_operator(
  operator : @content.StandardContentOperator,
) -> Bool {
  match operator {
    BeginMarkedContentPoint
    | DefineMarkedContentPoint
    | BeginMarkedContent
    | BeginMarkedContentWithProperties
    | EndMarkedContent => true
    _ => false
  }
}
