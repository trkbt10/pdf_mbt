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
/// ISO 32000-2 §8.2 says a path object only permits path-construction,
/// clipping, and path-painting operators, but real producers (Canva,
/// Microsoft Office, several scanner exporters and PDF/UA tagging
/// pipelines) routinely interleave the path with graphics-state changes,
/// colour selectors and marked-content tags before the eventual paint —
/// a typical Canva idiom is `re /gs3 gs f` to set an alpha-0 ExtGState
/// between the rectangle and the fill so the rectangle becomes an
/// invisible structure marker. Acrobat, poppler and pdf.js all tolerate
/// this; rejecting strictly aborted the whole graphics walk on the first
/// such operator and returned an empty event list, which the SVG
/// renderer then surfaced as a page where every shape was missing.
///
/// We continue to forbid the genuinely incompatible operations: a text
/// object cannot start (`BT`), nor can `ET` close one that is not open,
/// nor can the special `XObject Do` / `inline image` painters intrude
/// into a half-built path. Everything else is treated as a state
/// modification that does not break the pending path.
fn GraphicsObjectContext::accept_path_object(
  self : GraphicsObjectContext,
  operator : @content.StandardContentOperator,
  offset : Int64,
) -> Unit raise PdfGraphicsError {
  if is_path_construction_operator(operator) || is_clipping_operator(operator) {
    return
  }
  if is_path_painting_operator(operator) {
    self.level = GraphicsObjectLevel::ContentStreamLevel
    return
  }
  match operator {
    BeginText =>
      raise PdfGraphicsError::InvalidObjectContext(
        offset, "BT cannot start a text object inside a pending path",
      )
    EndText =>
      raise PdfGraphicsError::InvalidObjectContext(
        offset, "ET cannot appear inside a pending path",
      )
    InvokeXObject | BeginInlineImage =>
      raise PdfGraphicsError::InvalidObjectContext(
        offset, "XObject Do and inline-image painters cannot intrude on a pending path",
      )
    _ =>
      // graphics state, colour, marked-content, save/restore, deferred —
      // tolerated mid-path to match real-world producer behaviour.
      ()
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
