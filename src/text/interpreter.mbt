///|
pub fn interpret_text(
  content : @content.ContentStream,
  resources : TextResources,
  initial : TextInitialState,
) -> TextProgram raise PdfTextError {
  let interpreter = TextInterpreter::new(resources, initial)
  let started = if text_interpret_diagnostics_enabled.val {
    @env.now()
  } else {
    0UL
  }
  interpreter.interpret(content.instructions)
  if text_interpret_diagnostics_enabled.val {
    text_interpret_phase_record(
      "interpret_loop",
      text_interpret_elapsed(started),
    )
  }
  TextProgram::{
    events: interpreter.events.copy(),
    spans: interpreter.spans.copy(),
    final_state: interpreter.state,
  }
}

///|
priv struct TextInterpreter {
  resources : TextResources
  limits : TextInterpretationLimits
  mut state : TextState
  mut ctm : TextMatrix
  mut object_state : TextObjectState?
  stack : TextStateStack
  ctm_stack : Array[TextMatrix]
  font_cache : Map[@objects.PdfName, RuntimeFont]
  events : Array[TextEvent]
  spans : Array[TextSpan]
}

///|
fn TextInterpreter::new(
  resources : TextResources,
  initial : TextInitialState,
) -> TextInterpreter {
  TextInterpreter::{
    resources,
    limits: TextInterpretationLimits::default(),
    state: TextState::initial().with_text_knockout(initial.text_knockout),
    ctm: initial.ctm,
    object_state: None,
    stack: TextStateStack::new(),
    ctm_stack: [],
    font_cache: Map::new(),
    events: [],
    spans: [],
  }
}

///|
fn TextInterpreter::interpret(
  self : TextInterpreter,
  instructions : Array[@content.ContentInstruction],
) -> Unit raise PdfTextError {
  for instruction in instructions {
    match instruction {
      @content.ContentInstruction::Operation(operation) =>
        self.interpret_operation(operation)
      @content.ContentInstruction::InlineImage(_) => ()
    }
  }
}

///|
fn TextInterpreter::interpret_operation(
  self : TextInterpreter,
  operation : @content.ContentOperation,
) -> Unit raise PdfTextError {
  if text_interpret_diagnostics_enabled.val {
    let started = @env.now()
    self.interpret_operation_unmeasured(operation)
    text_interpret_operator_record(
      text_operator_label(operation.operator),
      text_interpret_elapsed(started),
    )
  } else {
    self.interpret_operation_unmeasured(operation)
  }
}

///|
fn TextInterpreter::interpret_operation_unmeasured(
  self : TextInterpreter,
  operation : @content.ContentOperation,
) -> Unit raise PdfTextError {
  match operation.operator {
    SaveGraphicsState => self.save_state(operation)
    RestoreGraphicsState => self.restore_state(operation)
    ConcatMatrix => self.concat_matrix(operation)
    SetCharacterSpacing =>
      self.state = self.state.with_character_spacing(
        single_number_operand(operation, "character spacing"),
      )
    SetWordSpacing =>
      self.state = self.state.with_word_spacing(
        single_number_operand(operation, "word spacing"),
      )
    SetHorizontalScaling =>
      self.state = self.state.with_horizontal_scaling_percent(
        single_number_operand(operation, "horizontal scaling"),
      )
    SetTextLeading =>
      self.state = self.state.with_leading(
        single_number_operand(operation, "text leading"),
      )
    SetTextFont => self.set_font(operation)
    SetTextRenderingMode =>
      self.state = self.state.with_rendering_mode(
        TextRenderingMode::from_int(
          single_int_operand(operation, "text rendering mode"),
          TextErrorContext::at(operation.offset),
        ),
      )
    SetTextRise =>
      self.state = self.state.with_text_rise(
        single_number_operand(operation, "text rise"),
      )
    BeginText => self.begin_text(operation)
    EndText => self.end_text(operation)
    MoveTextPosition => self.move_text_position(operation, set_leading=false)
    MoveTextPositionSetLeading =>
      self.move_text_position(operation, set_leading=true)
    SetTextMatrix => self.set_text_matrix(operation)
    MoveToNextLine => self.move_to_next_line(operation.offset)
    ShowText =>
      self.show_string(
        single_string_operand(operation, "show text string"),
        operation.offset,
        0,
      )
    QuoteShowText => {
      require_operand_count(operation, 1)
      self.move_to_next_line(operation.offset)
      self.show_string(
        string_operand_at(operation, 0, "quote string"),
        operation.offset,
        0,
      )
    }
    DoubleQuoteShowText => {
      require_operand_count(operation, 3)
      self.state = self.state.with_word_spacing(
        number_operand_at(operation, 0, "word spacing"),
      )
      self.state = self.state.with_character_spacing(
        number_operand_at(operation, 1, "character spacing"),
      )
      self.move_to_next_line(operation.offset)
      self.show_string(
        string_operand_at(operation, 2, "double quote string"),
        operation.offset,
        0,
      )
    }
    ShowTextAdjusted => self.show_adjusted(operation)
    _ => ()
  }
}

///|
fn TextInterpreter::save_state(
  self : TextInterpreter,
  operation : @content.ContentOperation,
) -> Unit raise PdfTextError {
  require_operand_count(operation, 0)
  self.stack.save(self.state, self.object_state)
  self.ctm_stack.push(self.ctm)
}

///|
fn TextInterpreter::restore_state(
  self : TextInterpreter,
  operation : @content.ContentOperation,
) -> Unit raise PdfTextError {
  require_operand_count(operation, 0)
  if self.object_state is Some(_) {
    raise PdfTextError::InvalidTextState(
      TextErrorContext::at(operation.offset),
      "Q cannot restore graphics state inside a text object",
    )
  }
  let snapshot = self.stack.restore(TextErrorContext::at(operation.offset))
  let ctm = match self.ctm_stack.pop() {
    Some(value) => value
    None =>
      raise PdfTextError::InvalidTextState(
        TextErrorContext::at(operation.offset),
        "graphics state stack underflow",
      )
  }
  self.state = snapshot.state
  self.ctm = ctm
  self.object_state = snapshot.object_state
}

///|
fn TextInterpreter::concat_matrix(
  self : TextInterpreter,
  operation : @content.ContentOperation,
) -> Unit raise PdfTextError {
  require_operand_count(operation, 6)
  let matrix = TextMatrix::from_six(
    number_operand_at(operation, 0, "cm a"),
    number_operand_at(operation, 1, "cm b"),
    number_operand_at(operation, 2, "cm c"),
    number_operand_at(operation, 3, "cm d"),
    number_operand_at(operation, 4, "cm e"),
    number_operand_at(operation, 5, "cm f"),
  )
  self.ctm = TextMatrix::concat(matrix, self.ctm)
}

///|
fn TextInterpreter::begin_text(
  self : TextInterpreter,
  operation : @content.ContentOperation,
) -> Unit raise PdfTextError {
  require_operand_count(operation, 0)
  if self.object_state is Some(_) {
    raise PdfTextError::InvalidTextState(
      TextErrorContext::at(operation.offset),
      "BT cannot be nested",
    )
  }
  self.object_state = Some(TextObjectState::initial())
  self.events.push(TextEvent::BeginTextObject(operation.offset))
}

///|
fn TextInterpreter::end_text(
  self : TextInterpreter,
  operation : @content.ContentOperation,
) -> Unit raise PdfTextError {
  require_operand_count(operation, 0)
  self.require_text_object(operation.offset) |> ignore
  self.object_state = None
  self.events.push(TextEvent::EndTextObject(operation.offset))
}

///|
fn TextInterpreter::set_font(
  self : TextInterpreter,
  operation : @content.ContentOperation,
) -> Unit raise PdfTextError {
  require_operand_count(operation, 2)
  let name = match operation.operands[0] {
    @objects.PdfObject::Name(name) => name
    _ =>
      raise PdfTextError::BadOperand(
        TextErrorContext::at(operation.offset),
        "Tf font resource operand must be a name",
      )
  }
  let size = number_operand_at(operation, 1, "font size")
  self.state = self.state.with_font(name, size)
}

///|
fn TextInterpreter::move_text_position(
  self : TextInterpreter,
  operation : @content.ContentOperation,
  set_leading~ : Bool,
) -> Unit raise PdfTextError {
  require_operand_count(operation, 2)
  let tx = number_operand_at(operation, 0, "text x translation")
  let ty = number_operand_at(operation, 1, "text y translation")
  if set_leading {
    self.state = self.state.with_leading(-ty)
  }
  let object_state = self.require_text_object(operation.offset).apply_td(tx, ty)
  self.object_state = Some(object_state)
}

///|
fn TextInterpreter::set_text_matrix(
  self : TextInterpreter,
  operation : @content.ContentOperation,
) -> Unit raise PdfTextError {
  require_operand_count(operation, 6)
  self.object_state = Some(
    self
    .require_text_object(operation.offset)
    .apply_tm(
      number_operand_at(operation, 0, "Tm a"),
      number_operand_at(operation, 1, "Tm b"),
      number_operand_at(operation, 2, "Tm c"),
      number_operand_at(operation, 3, "Tm d"),
      number_operand_at(operation, 4, "Tm e"),
      number_operand_at(operation, 5, "Tm f"),
    ),
  )
}

///|
fn TextInterpreter::move_to_next_line(
  self : TextInterpreter,
  offset : Int64,
) -> Unit raise PdfTextError {
  let object_state = self
    .require_text_object(offset)
    .apply_tstar(self.state.leading)
  self.object_state = Some(object_state)
}

///|
fn TextInterpreter::show_adjusted(
  self : TextInterpreter,
  operation : @content.ContentOperation,
) -> Unit raise PdfTextError {
  require_operand_count(operation, 1)
  let values = match operation.operands[0] {
    @objects.PdfObject::Array(values) => values
    _ =>
      raise PdfTextError::BadOperand(
        TextErrorContext::at(operation.offset),
        "TJ operand must be an array",
      )
  }
  let mut group = 0
  for value in values {
    match value {
      @objects.PdfObject::String(bytes) => {
        self.show_string(bytes, operation.offset, group)
        group += 1
      }
      @objects.PdfObject::Integer(_) | @objects.PdfObject::Real(_) =>
        self.apply_tj_adjustment(
          object_number(value, "TJ adjustment", operation.offset),
          operation.offset,
        )
      _ =>
        raise PdfTextError::BadOperand(
          TextErrorContext::at(operation.offset),
          "TJ entries must be strings or numbers",
        )
    }
  }
}

///|
fn TextInterpreter::show_string(
  self : TextInterpreter,
  bytes : Bytes,
  offset : Int64,
  group_index : Int,
) -> Unit raise PdfTextError {
  let object_state = self.require_text_object(offset)
  let font = self.current_font(offset)
  let span_font_size = self.current_font_size(offset)
  let source = TextSourceString::{ bytes, operator_offset: offset, group_index }
  self.events.push(TextEvent::SourceString(source))
  if bytes.length() == 0 {
    self.events.push(TextEvent::EmptyString(source))
    return
  }
  let decoded = decode_runtime_font_string(font, bytes, offset)
  if text_interpret_diagnostics_enabled.val {
    text_interpret_glyph_decode_record(decoded.length())
    text_interpret_allocation_record(decoded.length() + 1)
  }
  let mappings : Array[UnicodeMapping] = []
  let mut text = ""
  for item in decoded {
    let before = self.require_text_object(offset)
    let rendering_matrix = TextRenderingMatrix::from_text_state(
      before.text_matrix,
      span_font_size,
      self.state.horizontal_scaling,
      self.state.text_rise,
      self.ctm,
    )
    self.events.push(
      TextEvent::GlyphShown(TextGlyphEvent::{
        offset,
        source,
        glyph: item.glyph,
        unicode: item.unicode,
        text_matrix: before.text_matrix,
        rendering_matrix,
        paint: TextPaintIntent::from_rendering_mode(
          self.state.rendering_mode,
          false,
        ),
      }),
    )
    mappings.push(item.unicode)
    match item.unicode {
      Unicode(text_value) =>
        if !is_zero_width_spacing_glyph(item.glyph, text_value) {
          text = text + text_value
        }
      Unknown(_, _, _) => ()
    }
    self.advance_after_glyph(item.glyph, offset)
  }
  self.spans.push(TextSpan::{
    offset,
    font_name: self.state.font_name,
    font_size: span_font_size,
    text,
    mappings,
    source_bytes: bytes,
    text_matrix: object_state.text_matrix,
  })
}

///|
fn is_zero_width_spacing_glyph(glyph : DecodedGlyph, text : String) -> Bool {
  text == " " &&
  glyph.metrics.horizontal_displacement == 0.0 &&
  glyph.metrics.width_source == GlyphWidthSource::FontDescriptorMissingWidth
}

///|
fn TextInterpreter::advance_after_glyph(
  self : TextInterpreter,
  glyph : DecodedGlyph,
  offset : Int64,
) -> Unit raise PdfTextError {
  let font_size = self.current_font_size(offset)
  let mut tx = glyph.metrics.horizontal_displacement / 1000.0 * font_size
  tx += self.state.character_spacing
  if glyph.word_spacing_eligible {
    tx += self.state.word_spacing
  }
  tx *= self.state.horizontal_scaling
  let object_state = self.require_text_object(offset)
  self.object_state = Some(
    object_state.advance_text_matrix(
      object_state.text_matrix.translated(tx, 0.0),
    ),
  )
}

///|
fn TextInterpreter::apply_tj_adjustment(
  self : TextInterpreter,
  value : Double,
  offset : Int64,
) -> Unit raise PdfTextError {
  let font_size = self.current_font_size(offset)
  let tx = -value / 1000.0 * font_size * self.state.horizontal_scaling
  let object_state = self.require_text_object(offset)
  self.object_state = Some(
    object_state.advance_text_matrix(
      object_state.text_matrix.translated(tx, 0.0),
    ),
  )
}

///|
fn TextInterpreter::current_font(
  self : TextInterpreter,
  offset : Int64,
) -> RuntimeFont raise PdfTextError {
  match self.state.font_name {
    Some(name) =>
      match self.resources.fonts.get(name) {
        Some(summary) => {
          match self.font_cache.get(name) {
            Some(font) => return font
            None => ()
          }
          let started = if text_interpret_diagnostics_enabled.val {
            @env.now()
          } else {
            0UL
          }
          let font = load_runtime_font(summary, offset, self.limits)
          if text_interpret_diagnostics_enabled.val {
            text_interpret_font_load_record(text_interpret_elapsed(started))
          }
          self.font_cache[name] = font
          font
        }
        None =>
          raise PdfTextError::MissingResource(
            TextErrorContext::with_resource(offset, name.to_text()),
            "current font resource is missing",
          )
      }
    None =>
      raise PdfTextError::InvalidTextState(
        TextErrorContext::at(offset),
        "text showing requires a current font",
      )
  }
}

///|
fn TextInterpreter::current_font_size(
  self : TextInterpreter,
  offset : Int64,
) -> Double raise PdfTextError {
  match self.state.font_size {
    Some(size) => size
    None =>
      raise PdfTextError::InvalidTextState(
        TextErrorContext::at(offset),
        "text showing requires a current font size",
      )
  }
}

///|
fn text_operator_label(
  operator : @content.StandardContentOperator,
) -> String {
  match operator {
    SaveGraphicsState => "q"
    RestoreGraphicsState => "Q"
    ConcatMatrix => "cm"
    SetCharacterSpacing => "Tc"
    SetWordSpacing => "Tw"
    SetHorizontalScaling => "Tz"
    SetTextLeading => "TL"
    SetTextFont => "Tf"
    SetTextRenderingMode => "Tr"
    SetTextRise => "Ts"
    BeginText => "BT"
    EndText => "ET"
    MoveTextPosition => "Td"
    MoveTextPositionSetLeading => "TD"
    SetTextMatrix => "Tm"
    MoveToNextLine => "T*"
    ShowText => "Tj"
    QuoteShowText => "'"
    DoubleQuoteShowText => "\""
    ShowTextAdjusted => "TJ"
    _ => "other"
  }
}

///|
pub let text_interpret_phase_ms : Ref[Array[(String, Double)]] = { val: [] }

///|
let text_interpret_diagnostics_enabled : Ref[Bool] = { val: false }

///|
let text_interpret_operator_ms : Ref[Map[String, Double]] = { val: Map::new() }

///|
let text_interpret_operator_counts : Ref[Map[String, Int]] = { val: Map::new() }

///|
let text_interpret_glyph_decodes : Ref[Int] = { val: 0 }

///|
let text_interpret_allocations : Ref[Int] = { val: 0 }

///|
let text_interpret_font_loads : Ref[Int] = { val: 0 }

///|
let text_interpret_font_load_ms : Ref[Double] = { val: 0.0 }

///|
pub fn text_interpret_phase_reset() -> Unit {
  text_interpret_diagnostics_enabled.val = true
  text_interpret_phase_ms.val = []
  text_interpret_operator_ms.val = Map::new()
  text_interpret_operator_counts.val = Map::new()
  text_interpret_glyph_decodes.val = 0
  text_interpret_allocations.val = 0
  text_interpret_font_loads.val = 0
  text_interpret_font_load_ms.val = 0.0
}

///|
pub fn text_interpret_phase_disable() -> Unit {
  text_interpret_diagnostics_enabled.val = false
}

///|
pub fn text_interpret_diagnostic_report() -> String {
  let builder = StringBuilder::new()
  builder.write_string("text_interpret phases:")
  for entry in text_interpret_phase_ms.val {
    let (name, ms) = entry
    builder.write_string(" ")
    builder.write_string(name)
    builder.write_string("=")
    builder.write_string(ms.to_string())
    builder.write_string("ms")
  }
  builder.write_string("\ntext_interpret glyph_decodes=")
  builder.write_string(text_interpret_glyph_decodes.val.to_string())
  builder.write_string(" allocation_count=")
  builder.write_string(text_interpret_allocations.val.to_string())
  builder.write_string(" font_loads=")
  builder.write_string(text_interpret_font_loads.val.to_string())
  builder.write_string(" font_load_ms=")
  builder.write_string(text_interpret_font_load_ms.val.to_string())
  builder.write_string("\ntext_interpret operators:")
  for label in ["q", "Q", "cm", "Tc", "Tw", "Tz", "TL", "Tf", "Tr", "Ts", "BT", "ET", "Td", "TD", "Tm", "T*", "Tj", "'", "\"", "TJ", "other"] {
    let count = text_interpret_operator_counts.val.get(label).unwrap_or(0)
    if count > 0 {
      builder.write_string(" ")
      builder.write_string(label)
      builder.write_string("[count=")
      builder.write_string(count.to_string())
      builder.write_string(",ms=")
      builder.write_string(
        text_interpret_operator_ms.val.get(label).unwrap_or(0.0).to_string(),
      )
      builder.write_string("]")
    }
  }
  builder.to_string()
}

///|
fn text_interpret_elapsed(started : UInt64) -> Double {
  let ended = @env.now()
  if ended >= started {
    (ended - started).to_double()
  } else {
    0.0
  }
}

///|
fn text_interpret_phase_record(name : String, ms : Double) -> Unit {
  text_interpret_phase_ms.val.push((name, ms))
}

///|
fn text_interpret_operator_record(name : String, ms : Double) -> Unit {
  text_interpret_operator_counts.val[name] = text_interpret_operator_counts.val
    .get(name)
    .unwrap_or(0) +
    1
  text_interpret_operator_ms.val[name] = text_interpret_operator_ms.val
    .get(name)
    .unwrap_or(0.0) +
    ms
}

///|
fn text_interpret_glyph_decode_record(count : Int) -> Unit {
  text_interpret_glyph_decodes.val += count
}

///|
fn text_interpret_allocation_record(count : Int) -> Unit {
  text_interpret_allocations.val += count
}

///|
fn text_interpret_font_load_record(ms : Double) -> Unit {
  text_interpret_font_loads.val += 1
  text_interpret_font_load_ms.val += ms
}

///|
fn TextInterpreter::require_text_object(
  self : TextInterpreter,
  offset : Int64,
) -> TextObjectState raise PdfTextError {
  match self.object_state {
    Some(state) => state
    None =>
      raise PdfTextError::InvalidTextState(
        TextErrorContext::at(offset),
        "operator requires an active text object",
      )
  }
}

///|
fn require_operand_count(
  operation : @content.ContentOperation,
  expected : Int,
) -> Unit raise PdfTextError {
  if operation.operands.length() != expected {
    raise PdfTextError::BadOperand(
      TextErrorContext::at(operation.offset),
      "operator operand count mismatch",
    )
  }
}

///|
fn single_number_operand(
  operation : @content.ContentOperation,
  label : String,
) -> Double raise PdfTextError {
  require_operand_count(operation, 1)
  number_operand_at(operation, 0, label)
}

///|
fn single_int_operand(
  operation : @content.ContentOperation,
  label : String,
) -> Int64 raise PdfTextError {
  require_operand_count(operation, 1)
  match operation.operands[0] {
    @objects.PdfObject::Integer(value) => value
    _ =>
      raise PdfTextError::BadOperand(
        TextErrorContext::at(operation.offset),
        label + " must be an integer",
      )
  }
}

///|
fn single_string_operand(
  operation : @content.ContentOperation,
  label : String,
) -> Bytes raise PdfTextError {
  require_operand_count(operation, 1)
  string_operand_at(operation, 0, label)
}

///|
fn number_operand_at(
  operation : @content.ContentOperation,
  index : Int,
  label : String,
) -> Double raise PdfTextError {
  match operation.operands[index] {
    @objects.PdfObject::Integer(value) => value.to_double()
    @objects.PdfObject::Real(value) => value
    _ =>
      raise PdfTextError::BadOperand(
        TextErrorContext::at(operation.offset),
        label + " must be numeric",
      )
  }
}

///|
fn string_operand_at(
  operation : @content.ContentOperation,
  index : Int,
  label : String,
) -> Bytes raise PdfTextError {
  match operation.operands[index] {
    @objects.PdfObject::String(bytes) => bytes
    _ =>
      raise PdfTextError::BadOperand(
        TextErrorContext::at(operation.offset),
        label + " must be a string",
      )
  }
}
