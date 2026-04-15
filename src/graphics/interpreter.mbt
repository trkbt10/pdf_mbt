///|
/// Describes a graphics-state mutation emitted during interpretation.
pub(all) enum GraphicsStateChange {
  CurrentTransformationMatrix(GraphicsMatrix)
  LineWidth(Double)
  LineCap(LineCapStyle)
  LineJoin(LineJoinStyle)
  MiterLimit(Double)
  DashPattern(DashPattern)
  RenderingIntent(RenderingIntent)
  ColourChanged(ColourUse, ColourSpace, ColourValue)
  Flatness(Double)
  ExtGStateApplied(@objects.PdfName)
} derive(Eq, Debug)

///|
/// Path-painting operation that terminates a PDF path object: fill a path with
/// a colour, paint a stroke along it, use it as a clipping boundary, or end it
/// without painting.
pub(all) enum PathPaintOperation {
  StrokePath
  CloseStrokePath
  FillPath(FillRule)
  FillStrokePath(FillRule)
  CloseFillStrokePath(FillRule)
  EndPath
} derive(Eq, Debug)

///|
/// Ordered graphics interpretation events for PDF graphics operators.
/// The events cover clause 8 graphics state, paths, painting, external
/// objects, sampled images, image XObjects, inline images, form XObjects,
/// group XObjects, reference XObject proxy forms, optional content marked by
/// BDC/DP/EMC, and whole-XObject OC visibility. Hidden marked content still
/// applies graphics-state side effects, while hidden image or form XObjects
/// are skipped as encapsulated objects.
pub(all) enum GraphicsEvent {
  StateSaved(Int64, GraphicsState)
  StateRestored(Int64, GraphicsState)
  StateChanged(Int64, GraphicsStateChange, GraphicsState)
  PathPainted(Int64, PathPaintOperation, GraphicsPath, GraphicsState)
  ClipChanged(Int64, ClipState)
  TextObjectBegan(Int64)
  TextObjectEnded(Int64)
  ExternalObjectInvoked(Int64, @objects.PdfName)
  UnresolvedXObjectInvoked(Int64, @objects.PdfName, @objects.ObjectId)
  ImagePainted(Int64, ImageDescriptor, GraphicsState)
  InlineImagePainted(Int64, ImageDescriptor, GraphicsState)
  FormXObjectBegan(Int64, FormXObject, GraphicsState)
  FormXObjectEnded(Int64, FormXObject, GraphicsState)
  XObjectSkipped(Int64, @objects.PdfName, OptionalContentDecision)
  InlineImageSeen(@content.PdfInlineImage)
  PatternColourSelected(
    Int64,
    ColourUse,
    PatternResource,
    ColourValue,
    GraphicsState
  )
  ShadingSeen(Int64, @objects.PdfName)
  ShadingPainted(Int64, ShadingResource, GraphicsState)
  MarkedContentSeen(Int64, @content.StandardContentOperator)
  IgnoredFutureDomainOperator(Int64, @content.StandardContentOperator)
} derive(Eq, Debug)

///|
/// Graphics interpretation options, including the optional content group state
/// used to evaluate OCG, OCMD, VE, marked-content scopes, image XObject OC
/// entries, and form XObject OC entries.
pub(all) struct GraphicsInterpretOptions {
  optional_content_state : OptionalContentState
} derive(Eq, Debug)

///|
/// Creates default graphics interpretation options where optional content is
/// visible unless the document catalog OCProperties state says otherwise.
pub fn GraphicsInterpretOptions::default() -> GraphicsInterpretOptions {
  GraphicsInterpretOptions::{
    optional_content_state: OptionalContentState::visible(),
  }
}

///|
/// Complete device-independent graphics description for a PDF content stream.
/// The ordered graphics events describe PDF colour specification and abstract
/// page appearance for printer and display applications, while the final
/// graphics state snapshot records the global framework left after all content
/// stream instructions are accepted. Colour rendering to an output device,
/// including colour conversion, gamma correction, halftoning, and scan
/// conversion, remains outside this program.
pub(all) struct GraphicsProgram {
  events : Array[GraphicsEvent]
  final_state : GraphicsState
} derive(Eq, Debug)

///|
/// Interprets a parsed PDF content stream as ISO 32000-2 clause 8 graphics
/// semantics, where graphics operators describe the appearance of pages to be
/// reproduced on an output device.
///
/// Source excerpt:
/// `spec/extracted/8.1-8.5-graphics-state.spec.txt`.
/// `spec/extracted/8.8-8.11-xobjects-images-optional.spec.txt`.
///
/// This accepts graphics state operators, path construction operators,
/// path-painting operators, clipping, object context validation, text
/// operators for glyphs from fonts, marked-content operators for higher-level
/// logical information, and deferred-domain painting operator classification
/// for sampled images, geometrically defined shadings, and entire content
/// streams. It models device-independent graphics and abstract page appearance;
/// it does not perform device-dependent rendering, load objects, or decode
/// streams.
pub fn interpret_content(
  content : @content.ContentStream,
  initial : GraphicsInitialState,
) -> GraphicsProgram raise PdfGraphicsError {
  interpret_content_with_options(
    content,
    initial,
    GraphicsInterpretOptions::default(),
  )
}

///|
/// Interprets content with caller-provided optional content state so BDC/DP
/// marked-content property lists and XObject `OC` entries can gate visible
/// painting while preserving graphics-state side effects.
pub fn interpret_content_with_options(
  content : @content.ContentStream,
  initial : GraphicsInitialState,
  options : GraphicsInterpretOptions,
) -> GraphicsProgram raise PdfGraphicsError {
  let interpreter = GraphicsInterpreter::new(
    content.resources,
    initial,
    options,
  )
  interpreter.interpret(content.instructions)
}

///|
/// Interprets a validated Form XObject as a nested graphics program using the
/// same form matrix, BBox clipping, resource scoping, group transparency
/// handling, and state restoration rules used by the `Do` operator path.
pub fn interpret_form_xobject(
  form : FormXObject,
  parent_resources : @content.ContentResources,
  parent_state : GraphicsState,
  options : GraphicsInterpretOptions,
  offset : Int64,
) -> GraphicsProgram raise PdfGraphicsError {
  let interpreter = GraphicsInterpreter::new(
    parent_resources,
    GraphicsInitialState::default(),
    options,
  )
  interpreter.state = parent_state.copy()
  interpreter.invoke_form_xobject(form, offset)
  GraphicsProgram::{
    events: interpreter.events.copy(),
    final_state: interpreter.state.copy(),
  }
}

///|
struct GraphicsInterpreter {
  mut state : GraphicsState
  stack : GraphicsStateStack
  current_path : CurrentPath
  context : GraphicsObjectContext
  resources : @content.ContentResources
  optional_content_state : OptionalContentState
  mut visibility : OptionalVisibilityStack
  mut pending_clip : FillRule?
  events : Array[GraphicsEvent]
} derive(Eq, Debug)

///|
fn GraphicsInterpreter::new(
  resources : @content.ContentResources,
  initial : GraphicsInitialState,
  options : GraphicsInterpretOptions,
) -> GraphicsInterpreter {
  GraphicsInterpreter::{
    state: GraphicsState::initial(initial),
    stack: GraphicsStateStack::new(),
    current_path: CurrentPath::new(),
    context: GraphicsObjectContext::new(),
    resources,
    optional_content_state: options.optional_content_state,
    visibility: OptionalVisibilityStack::new(),
    pending_clip: None,
    events: [],
  }
}

///|
fn GraphicsInterpreter::interpret(
  self : GraphicsInterpreter,
  instructions : Array[@content.ContentInstruction],
) -> GraphicsProgram raise PdfGraphicsError {
  for instruction in instructions {
    match instruction {
      @content.ContentInstruction::Operation(operation) =>
        self.accept_operation(operation)
      @content.ContentInstruction::InlineImage(image) =>
        self.accept_inline_image(image)
    }
  }
  GraphicsProgram::{
    events: self.events.copy(),
    final_state: self.state.copy(),
  }
}

///|
fn GraphicsInterpreter::accept_inline_image(
  self : GraphicsInterpreter,
  image : @content.PdfInlineImage,
) -> Unit raise PdfGraphicsError {
  let descriptor = validate_inline_image(image)
  if self.visibility.current() {
    self.events.push(
      GraphicsEvent::InlineImagePainted(
        image.start_offset,
        descriptor,
        self.state.copy(),
      ),
    )
  }
}

///|
fn GraphicsInterpreter::accept_operation(
  self : GraphicsInterpreter,
  operation : @content.ContentOperation,
) -> Unit raise PdfGraphicsError {
  self.context.accept(operation.operator, operation.offset)
  let op = operation.operator
  if is_graphics_state_operator(op) {
    self.apply_graphics_state_operator(operation)
  } else if is_color_operator(op) {
    self.apply_colour_operator(operation)
  } else if is_path_construction_operator(op) {
    self.apply_path_construction_operator(operation)
  } else if is_clipping_operator(op) {
    self.pending_clip = Some(clip_rule_for(op))
  } else if is_path_painting_operator(op) {
    self.apply_path_painting_operator(operation)
  } else {
    self.classify_deferred_operator(operation)
  }
}

///|
fn GraphicsInterpreter::apply_graphics_state_operator(
  self : GraphicsInterpreter,
  operation : @content.ContentOperation,
) -> Unit raise PdfGraphicsError {
  let offset = operation.offset
  match operation.operator {
    SaveGraphicsState => {
      require_operand_count(operation, 0)
      self.stack.save(self.state)
      self.events.push(GraphicsEvent::StateSaved(offset, self.state.copy()))
    }
    RestoreGraphicsState => {
      require_operand_count(operation, 0)
      self.state = self.stack.restore(offset)
      self.events.push(GraphicsEvent::StateRestored(offset, self.state.copy()))
    }
    ConcatMatrix => {
      let matrix = matrix_operand(operation)
      self.state.concat_ctm(matrix)
      self.events.push(
        GraphicsEvent::StateChanged(
          offset,
          GraphicsStateChange::CurrentTransformationMatrix(self.state.ctm),
          self.state.copy(),
        ),
      )
    }
    SetLineWidth => {
      let value = single_number_operand(operation, "line width")
      self.state.set_line_width(value, offset)
      self.events.push(
        GraphicsEvent::StateChanged(
          offset,
          GraphicsStateChange::LineWidth(value),
          self.state.copy(),
        ),
      )
    }
    SetLineCap => {
      let value = LineCapStyle::from_int(
        single_int_operand(operation, "line cap"),
        offset,
      )
      self.state.line_cap = value
      self.events.push(
        GraphicsEvent::StateChanged(
          offset,
          GraphicsStateChange::LineCap(value),
          self.state.copy(),
        ),
      )
    }
    SetLineJoin => {
      let value = LineJoinStyle::from_int(
        single_int_operand(operation, "line join"),
        offset,
      )
      self.state.line_join = value
      self.events.push(
        GraphicsEvent::StateChanged(
          offset,
          GraphicsStateChange::LineJoin(value),
          self.state.copy(),
        ),
      )
    }
    SetMiterLimit => {
      let value = single_number_operand(operation, "miter limit")
      self.state.set_miter_limit(value, offset)
      self.events.push(
        GraphicsEvent::StateChanged(
          offset,
          GraphicsStateChange::MiterLimit(value),
          self.state.copy(),
        ),
      )
    }
    SetLineDash => {
      require_operand_count(operation, 2)
      let values = match operation.operands[0] {
        @objects.PdfObject::Array(items) => numbers_from_array(items, offset)
        _ =>
          raise PdfGraphicsError::BadOperand(
            offset, "dash pattern must start with an array",
          )
      }
      let phase = operand_number(operation.operands[1], offset, "dash phase")
      let dash = DashPattern::from_values(values, phase, offset)
      self.state.dash_pattern = DashPattern::{
        array: dash.array.copy(),
        phase: dash.phase,
      }
      self.events.push(
        GraphicsEvent::StateChanged(
          offset,
          GraphicsStateChange::DashPattern(dash),
          self.state.copy(),
        ),
      )
    }
    SetRenderingIntent => {
      let name = single_name_operand(operation, "rendering intent")
      if self.state.colour_restriction.is_restricted() {
        return
      }
      let value = rendering_intent_from_name(name)
      self.state.rendering_intent = value
      self.events.push(
        GraphicsEvent::StateChanged(
          offset,
          GraphicsStateChange::RenderingIntent(value),
          self.state.copy(),
        ),
      )
    }
    SetFlatness => {
      let value = single_number_operand(operation, "flatness")
      self.state.set_flatness(value, offset)
      self.events.push(
        GraphicsEvent::StateChanged(
          offset,
          GraphicsStateChange::Flatness(value),
          self.state.copy(),
        ),
      )
    }
    SetExtGState => {
      let name = single_name_operand(operation, "ExtGState name")
      let patch = resolve_ext_gstate(self.resources, name, offset)
      if self.state.colour_restriction.is_restricted() {
        self.state.apply_ext_gstate_non_colour(patch, offset)
      } else {
        self.state.apply_ext_gstate(patch, offset)
      }
      self.events.push(
        GraphicsEvent::StateChanged(
          offset,
          GraphicsStateChange::ExtGStateApplied(name),
          self.state.copy(),
        ),
      )
    }
    _ => ()
  }
}

///|
fn GraphicsInterpreter::apply_path_construction_operator(
  self : GraphicsInterpreter,
  operation : @content.ContentOperation,
) -> Unit raise PdfGraphicsError {
  let offset = operation.offset
  match operation.operator {
    MoveTo => {
      require_operand_count(operation, 2)
      self.current_path.move_to(
        GraphicsPoint::new(
          operand_number(operation.operands[0], offset, "m x"),
          operand_number(operation.operands[1], offset, "m y"),
        ),
      )
    }
    LineTo => {
      require_operand_count(operation, 2)
      self.current_path.line_to(
        GraphicsPoint::new(
          operand_number(operation.operands[0], offset, "l x"),
          operand_number(operation.operands[1], offset, "l y"),
        ),
        offset,
      )
    }
    CurveTo => {
      require_operand_count(operation, 6)
      self.current_path.curve_to(
        GraphicsPoint::new(
          operand_number(operation.operands[0], offset, "c x1"),
          operand_number(operation.operands[1], offset, "c y1"),
        ),
        GraphicsPoint::new(
          operand_number(operation.operands[2], offset, "c x2"),
          operand_number(operation.operands[3], offset, "c y2"),
        ),
        GraphicsPoint::new(
          operand_number(operation.operands[4], offset, "c x3"),
          operand_number(operation.operands[5], offset, "c y3"),
        ),
        offset,
      )
    }
    CurveToInitialReplicated => {
      require_operand_count(operation, 4)
      let current = self.current_path.require_current_point(offset)
      self.current_path.curve_to(
        current,
        GraphicsPoint::new(
          operand_number(operation.operands[0], offset, "v x2"),
          operand_number(operation.operands[1], offset, "v y2"),
        ),
        GraphicsPoint::new(
          operand_number(operation.operands[2], offset, "v x3"),
          operand_number(operation.operands[3], offset, "v y3"),
        ),
        offset,
      )
    }
    CurveToFinalReplicated => {
      require_operand_count(operation, 4)
      let end_point = GraphicsPoint::new(
        operand_number(operation.operands[2], offset, "y x3"),
        operand_number(operation.operands[3], offset, "y y3"),
      )
      self.current_path.curve_to(
        GraphicsPoint::new(
          operand_number(operation.operands[0], offset, "y x1"),
          operand_number(operation.operands[1], offset, "y y1"),
        ),
        end_point,
        end_point,
        offset,
      )
    }
    ClosePath => {
      require_operand_count(operation, 0)
      self.current_path.close_path(offset)
    }
    Rectangle => {
      require_operand_count(operation, 4)
      let x = operand_number(operation.operands[0], offset, "re x")
      let y = operand_number(operation.operands[1], offset, "re y")
      let width = operand_number(operation.operands[2], offset, "re width")
      let height = operand_number(operation.operands[3], offset, "re height")
      self.current_path.rectangle(
        GraphicsRect::new(x, y, x + width, y + height),
      )
    }
    _ => ()
  }
}

///|
fn GraphicsInterpreter::apply_path_painting_operator(
  self : GraphicsInterpreter,
  operation : @content.ContentOperation,
) -> Unit raise PdfGraphicsError {
  require_operand_count(operation, 0)
  let offset = operation.offset
  let paint = paint_operation_for(operation.operator)
  match paint {
    CloseStrokePath | CloseFillStrokePath(_) =>
      self.current_path.close_path(offset)
    _ => ()
  }
  let has_path = !self.current_path.is_empty()
  if !has_path && paint != PathPaintOperation::EndPath {
    raise PdfGraphicsError::InvalidPathState(
      offset, "path-painting operator requires a current path",
    )
  }
  if has_path &&
    paint != PathPaintOperation::EndPath &&
    self.visibility.current() {
    self.events.push(
      GraphicsEvent::PathPainted(
        offset,
        paint,
        self.current_path.snapshot(),
        self.state.copy(),
      ),
    )
  }
  if self.pending_clip is Some(rule) {
    if !has_path {
      raise PdfGraphicsError::InvalidPathState(
        offset, "clipping operator requires a current path before path termination",
      )
    }
    self.state.clipping_path = self.state.clipping_path.append_clip(
      self.current_path.snapshot(),
      rule,
    )
    self.events.push(
      GraphicsEvent::ClipChanged(offset, self.state.clipping_path.copy()),
    )
    self.pending_clip = None
  }
  self.current_path.clear()
}

///|
fn GraphicsInterpreter::classify_deferred_operator(
  self : GraphicsInterpreter,
  operation : @content.ContentOperation,
) -> Unit raise PdfGraphicsError {
  match operation.operator {
    BeginText => {
      require_operand_count(operation, 0)
      self.events.push(GraphicsEvent::TextObjectBegan(operation.offset))
    }
    EndText => {
      require_operand_count(operation, 0)
      self.events.push(GraphicsEvent::TextObjectEnded(operation.offset))
    }
    InvokeXObject => {
      let name = single_name_operand(operation, "XObject name")
      self.invoke_xobject(name, operation.offset)
    }
    PaintShading => {
      let name = single_name_operand(operation, "shading name")
      if !self.state.colour_restriction.is_restricted() {
        let resource = resolve_shading_resource(
          self.resources,
          name,
          operation.offset,
        )
        if self.visibility.current() {
          self.events.push(
            GraphicsEvent::ShadingPainted(
              operation.offset,
              resource,
              self.state.copy(),
            ),
          )
        }
      }
    }
    _ if is_marked_content_operator(operation.operator) =>
      self.accept_marked_content_operator(operation)
    _ if is_text_domain_operator(operation.operator) =>
      self.events.push(
        GraphicsEvent::IgnoredFutureDomainOperator(
          operation.offset,
          operation.operator,
        ),
      )
    _ =>
      self.events.push(
        GraphicsEvent::IgnoredFutureDomainOperator(
          operation.offset,
          operation.operator,
        ),
      )
  }
}

///|
fn GraphicsInterpreter::invoke_xobject(
  self : GraphicsInterpreter,
  name : @objects.PdfName,
  offset : Int64,
) -> Unit raise PdfGraphicsError {
  let resource = resolve_xobject_resource(self.resources, name, offset)
  match resource {
    UnresolvedXObject(_, _) =>
      if self.visibility.current() {
        self.events.push(GraphicsEvent::ExternalObjectInvoked(offset, name))
      }
    ImageResource(descriptor) => {
      let decision = self.optional_content_state.evaluate(
        descriptor.metadata.oc,
        offset,
      )
      if decision == OptionalContentDecision::Hidden ||
        !self.visibility.current() {
        self.events.push(GraphicsEvent::XObjectSkipped(offset, name, decision))
      } else {
        self.events.push(
          GraphicsEvent::ImagePainted(offset, descriptor, self.state.copy()),
        )
      }
    }
    FormResource(form) => {
      let decision = self.optional_content_state.evaluate(form.oc, offset)
      if decision == OptionalContentDecision::Hidden ||
        !self.visibility.current() {
        self.events.push(GraphicsEvent::XObjectSkipped(offset, name, decision))
      } else {
        self.invoke_form_xobject(form, offset)
      }
    }
  }
}

///|
fn GraphicsInterpreter::invoke_form_xobject(
  self : GraphicsInterpreter,
  form : FormXObject,
  offset : Int64,
) -> Unit raise PdfGraphicsError {
  let parent_state = self.state.copy()
  self.state = apply_form_xobject_geometry(form, self.state)
  self.events.push(
    GraphicsEvent::FormXObjectBegan(offset, form, self.state.copy()),
  )
  let decoded = try @filters.decode_stream(form.stream) catch {
    error => raise map_filter_error(offset, "Form XObject", error)
  } noraise {
    bytes => bytes
  }
  let form_resources = match form.resources {
    Some(dictionary) => @content.ContentResources::from_dictionary(dictionary)
    None => self.resources
  }
  let content = try
    @content.parse_decoded_content(decoded, form_resources)
  catch {
    error => raise PdfGraphicsError::ContentFailure(error)
  } noraise {
    parsed => parsed
  }
  let child = GraphicsInterpreter::new(
    form_resources,
    GraphicsInitialState::default(),
    GraphicsInterpretOptions::{
      optional_content_state: self.optional_content_state,
    },
  )
  child.state = self.state.copy()
  if form.group is Some(group) {
    if group.transparency is Some(_) {
      child.state.reset_transparency_parameters()
    }
  }
  child.visibility = self.visibility.copy()
  let program = child.interpret(content.instructions)
  self.events.append(program.events)
  self.state = parent_state
  self.events.push(
    GraphicsEvent::FormXObjectEnded(offset, form, self.state.copy()),
  )
}

///|
fn GraphicsInterpreter::accept_marked_content_operator(
  self : GraphicsInterpreter,
  operation : @content.ContentOperation,
) -> Unit raise PdfGraphicsError {
  match operation.operator {
    BeginMarkedContentPoint => {
      require_operand_count(operation, 1)
      self.events.push(
        GraphicsEvent::MarkedContentSeen(operation.offset, operation.operator),
      )
    }
    BeginMarkedContent => {
      require_operand_count(operation, 1)
      self.visibility.push(true)
      self.events.push(
        GraphicsEvent::MarkedContentSeen(operation.offset, operation.operator),
      )
    }
    DefineMarkedContentPoint => {
      require_operand_count(operation, 2)
      let visible = self.marked_content_property_visible(operation)
      if visible {
        self.events.push(
          GraphicsEvent::MarkedContentSeen(operation.offset, operation.operator),
        )
      }
    }
    BeginMarkedContentWithProperties => {
      require_operand_count(operation, 2)
      let visible = self.marked_content_property_visible(operation)
      self.visibility.push(visible)
      self.events.push(
        GraphicsEvent::MarkedContentSeen(operation.offset, operation.operator),
      )
    }
    EndMarkedContent => {
      require_operand_count(operation, 0)
      self.visibility.pop(operation.offset)
      self.events.push(
        GraphicsEvent::MarkedContentSeen(operation.offset, operation.operator),
      )
    }
    _ => ()
  }
}

///|
fn GraphicsInterpreter::marked_content_property_visible(
  self : GraphicsInterpreter,
  operation : @content.ContentOperation,
) -> Bool raise PdfGraphicsError {
  let property = resolve_optional_content_property(
    self.resources,
    operation.operands[1],
    operation.offset,
  )
  self.optional_content_state.is_visible_bool(property, operation.offset)
}

///|
fn paint_operation_for(
  operator : @content.StandardContentOperator,
) -> PathPaintOperation {
  match operator {
    Stroke => PathPaintOperation::StrokePath
    CloseAndStroke => PathPaintOperation::CloseStrokePath
    FillNonzero | FillNonzeroDeprecated =>
      PathPaintOperation::FillPath(FillRule::NonZero)
    FillEvenOdd => PathPaintOperation::FillPath(FillRule::EvenOdd)
    FillStrokeNonzero => PathPaintOperation::FillStrokePath(FillRule::NonZero)
    FillStrokeEvenOdd => PathPaintOperation::FillStrokePath(FillRule::EvenOdd)
    CloseFillStrokeNonzero =>
      PathPaintOperation::CloseFillStrokePath(FillRule::NonZero)
    CloseFillStrokeEvenOdd =>
      PathPaintOperation::CloseFillStrokePath(FillRule::EvenOdd)
    _ => PathPaintOperation::EndPath
  }
}

///|
fn clip_rule_for(operator : @content.StandardContentOperator) -> FillRule {
  match operator {
    ClipEvenOdd => FillRule::EvenOdd
    _ => FillRule::NonZero
  }
}

///|
fn matrix_operand(
  operation : @content.ContentOperation,
) -> GraphicsMatrix raise PdfGraphicsError {
  require_operand_count(operation, 6)
  GraphicsMatrix::from_six(
    operand_number(operation.operands[0], operation.offset, "cm a"),
    operand_number(operation.operands[1], operation.offset, "cm b"),
    operand_number(operation.operands[2], operation.offset, "cm c"),
    operand_number(operation.operands[3], operation.offset, "cm d"),
    operand_number(operation.operands[4], operation.offset, "cm e"),
    operand_number(operation.operands[5], operation.offset, "cm f"),
  )
}

///|
fn require_operand_count(
  operation : @content.ContentOperation,
  expected : Int,
) -> Unit raise PdfGraphicsError {
  if operation.operands.length() != expected {
    raise PdfGraphicsError::BadOperand(
      operation.offset,
      "operator operand count mismatch",
    )
  }
}

///|
fn single_number_operand(
  operation : @content.ContentOperation,
  label : String,
) -> Double raise PdfGraphicsError {
  require_operand_count(operation, 1)
  operand_number(operation.operands[0], operation.offset, label)
}

///|
fn single_int_operand(
  operation : @content.ContentOperation,
  label : String,
) -> Int64 raise PdfGraphicsError {
  require_operand_count(operation, 1)
  match operation.operands[0] {
    @objects.PdfObject::Integer(value) => value
    _ =>
      raise PdfGraphicsError::BadOperand(
        operation.offset,
        label + " must be an integer",
      )
  }
}

///|
fn single_name_operand(
  operation : @content.ContentOperation,
  label : String,
) -> @objects.PdfName raise PdfGraphicsError {
  require_operand_count(operation, 1)
  match operation.operands[0] {
    @objects.PdfObject::Name(value) => value
    _ =>
      raise PdfGraphicsError::BadOperand(
        operation.offset,
        label + " must be a name",
      )
  }
}

///|
fn operand_number(
  value : @objects.PdfObject,
  offset : Int64,
  label : String,
) -> Double raise PdfGraphicsError {
  match value {
    @objects.PdfObject::Integer(number) => number.to_double()
    @objects.PdfObject::Real(number) => number
    _ => raise PdfGraphicsError::BadOperand(offset, label + " must be a number")
  }
}
