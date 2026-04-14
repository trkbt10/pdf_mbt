///|
struct OpenMarkedContentScope {
  tag : @objects.PdfName
  property : MarkedContentProperty?
  begin_offset : Int64
  began_in_text : Bool
} derive(Eq, Debug)

///|
struct MarkedContentAnalyzerState {
  points : Array[MarkedContentScope]
  sequences : Array[MarkedContentScope]
  stack : Array[OpenMarkedContentScope]
  mut in_text : Bool
} derive(Eq, Debug)

///|
/// Analyzes already parsed content stream instructions for marked-content
/// operand shape, property normalization, balanced scopes, and BT/ET crossing.
pub fn analyze_marked_content(
  stream : @content.ContentStream,
) -> MarkedContentReport raise PdfInterchangeError {
  let state = MarkedContentAnalyzerState::{
    points: [],
    sequences: [],
    stack: [],
    in_text: false,
  }
  for instruction in stream.instructions {
    match instruction {
      @content.ContentInstruction::Operation(operation) =>
        state.accept_operation(operation, stream.resources)
      @content.ContentInstruction::InlineImage(_) => ()
    }
  }
  if state.in_text {
    raise PdfInterchangeError::InvalidMarkedContent(
      end_offset(stream),
      "unclosed text object at end of content stream",
    )
  }
  match state.stack.last() {
    Some(scope) =>
      raise PdfInterchangeError::InvalidMarkedContent(
        scope.begin_offset,
        "unclosed marked-content sequence /" + name_text(scope.tag),
      )
    None => ()
  }
  MarkedContentReport::{ points: state.points, sequences: state.sequences }
}

///|
fn MarkedContentAnalyzerState::accept_operation(
  self : MarkedContentAnalyzerState,
  operation : @content.ContentOperation,
  resources : @content.ContentResources,
) -> Unit raise PdfInterchangeError {
  match operation.operator {
    @content.StandardContentOperator::BeginText => self.begin_text(operation)
    @content.StandardContentOperator::EndText => self.end_text(operation)
    @content.StandardContentOperator::BeginMarkedContentPoint =>
      self.marked_point(operation, None)
    @content.StandardContentOperator::DefineMarkedContentPoint =>
      self.marked_point(
        operation,
        Some(normalize_property_operand(operation, resources)),
      )
    @content.StandardContentOperator::BeginMarkedContent =>
      self.begin_marked_sequence(operation, None)
    @content.StandardContentOperator::BeginMarkedContentWithProperties =>
      self.begin_marked_sequence(
        operation,
        Some(normalize_property_operand(operation, resources)),
      )
    @content.StandardContentOperator::EndMarkedContent =>
      self.end_marked_sequence(operation)
    _ => ()
  }
}

///|
fn MarkedContentAnalyzerState::begin_text(
  self : MarkedContentAnalyzerState,
  operation : @content.ContentOperation,
) -> Unit raise PdfInterchangeError {
  require_operand_count(operation, 0)
  if self.in_text {
    raise PdfInterchangeError::InvalidMarkedContent(
      operation.offset,
      "nested BT text object",
    )
  }
  self.in_text = true
}

///|
fn MarkedContentAnalyzerState::end_text(
  self : MarkedContentAnalyzerState,
  operation : @content.ContentOperation,
) -> Unit raise PdfInterchangeError {
  require_operand_count(operation, 0)
  if !self.in_text {
    raise PdfInterchangeError::InvalidMarkedContent(
      operation.offset,
      "ET without matching BT",
    )
  }
  match self.stack.last() {
    Some(scope) if scope.began_in_text =>
      raise PdfInterchangeError::InvalidMarkedContent(
        operation.offset,
        "ET crosses unclosed marked-content sequence /" + name_text(scope.tag),
      )
    _ => ()
  }
  self.in_text = false
}

///|
fn MarkedContentAnalyzerState::marked_point(
  self : MarkedContentAnalyzerState,
  operation : @content.ContentOperation,
  property : MarkedContentProperty?,
) -> Unit raise PdfInterchangeError {
  let tag = require_tag_operand(
    operation,
    expected_count=if property is Some(_) { 2 } else { 1 },
  )
  self.points.push(MarkedContentScope::{
    tag,
    property,
    begin_offset: operation.offset,
    end_offset: Some(operation.offset),
  })
}

///|
fn MarkedContentAnalyzerState::begin_marked_sequence(
  self : MarkedContentAnalyzerState,
  operation : @content.ContentOperation,
  property : MarkedContentProperty?,
) -> Unit raise PdfInterchangeError {
  let tag = require_tag_operand(
    operation,
    expected_count=if property is Some(_) { 2 } else { 1 },
  )
  self.stack.push(OpenMarkedContentScope::{
    tag,
    property,
    begin_offset: operation.offset,
    began_in_text: self.in_text,
  })
}

///|
fn MarkedContentAnalyzerState::end_marked_sequence(
  self : MarkedContentAnalyzerState,
  operation : @content.ContentOperation,
) -> Unit raise PdfInterchangeError {
  require_operand_count(operation, 0)
  let scope = match self.stack.pop() {
    Some(value) => value
    None =>
      raise PdfInterchangeError::InvalidMarkedContent(
        operation.offset,
        "EMC without matching BMC or BDC",
      )
  }
  if scope.began_in_text != self.in_text {
    raise PdfInterchangeError::InvalidMarkedContent(
      operation.offset,
      "EMC crosses BT/ET text object boundary for /" + name_text(scope.tag),
    )
  }
  self.sequences.push(MarkedContentScope::{
    tag: scope.tag,
    property: scope.property,
    begin_offset: scope.begin_offset,
    end_offset: Some(operation.offset),
  })
}

///|
fn require_operand_count(
  operation : @content.ContentOperation,
  count : Int,
) -> Unit raise PdfInterchangeError {
  if operation.operands.length() != count {
    raise PdfInterchangeError::InvalidMarkedContent(
      operation.offset,
      "operator has " +
      operation.operands.length().to_string() +
      " operands but expected " +
      count.to_string(),
    )
  }
}

///|
fn require_tag_operand(
  operation : @content.ContentOperation,
  expected_count~ : Int,
) -> @objects.PdfName raise PdfInterchangeError {
  require_operand_count(operation, expected_count)
  match operation.operands[0] {
    @objects.PdfObject::Name(tag) => tag
    value =>
      raise PdfInterchangeError::InvalidMarkedContent(
        operation.offset,
        "marked-content tag must be a name, not " + object_kind(value),
      )
  }
}

///|
fn normalize_property_operand(
  operation : @content.ContentOperation,
  resources : @content.ContentResources,
) -> MarkedContentProperty raise PdfInterchangeError {
  match operation.operands.length() {
    2 =>
      normalize_property_object(
        operation.operands[1],
        operation.offset,
        resources,
      )
    _ =>
      raise PdfInterchangeError::InvalidMarkedContent(
        operation.offset,
        "property-list marked-content operator must have two operands",
      )
  }
}

///|
fn normalize_property_object(
  object : @objects.PdfObject,
  offset : Int64,
  resources : @content.ContentResources,
) -> MarkedContentProperty raise PdfInterchangeError {
  match object {
    @objects.PdfObject::Dictionary(dict) => {
      for _, value in dict {
        if contains_ref(value) {
          raise PdfInterchangeError::InvalidMarkedContent(
            offset, "inline marked-content property dictionary cannot contain references",
          )
        }
      }
      MarkedContentProperty::Inline(dict)
    }
    @objects.PdfObject::Name(name) => {
      let resolved = try
        resources.lookup_resource(@content.ResourceCategory::Properties, name)
      catch {
        error => raise PdfInterchangeError::ContentError(error)
      } noraise {
        value => value
      }
      match resolved {
        Some(value) => MarkedContentProperty::Named(name, value)
        None =>
          raise PdfInterchangeError::InvalidMarkedContent(
            offset,
            "missing marked-content Properties resource /" + name_text(name),
          )
      }
    }
    @objects.PdfObject::Null => MarkedContentProperty::Null
    _ =>
      raise PdfInterchangeError::InvalidMarkedContent(
        offset,
        "marked-content property must be a dictionary, name, or null, not " +
        object_kind(object),
      )
  }
}

///|
fn end_offset(stream : @content.ContentStream) -> Int64 {
  let mut offset = 0L
  for instruction in stream.instructions {
    match instruction {
      @content.ContentInstruction::Operation(operation) =>
        offset = operation.offset
      @content.ContentInstruction::InlineImage(image) =>
        offset = image.end_offset
    }
  }
  offset
}
