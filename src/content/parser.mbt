///|
/// Tracks balanced compatibility operators `BX` and `EX` while the content
/// stream parser tokenizes decoded bytes into operands and operator keywords.
pub(all) struct CompatibilityTracker {
  mut depth : Int
} derive(Eq, Debug)

///|
/// Creates a compatibility section tracker with zero active `BX` depth.
pub fn CompatibilityTracker::new() -> CompatibilityTracker {
  CompatibilityTracker::{ depth: 0 }
}

///|
/// Returns the current nested compatibility section depth.
pub fn CompatibilityTracker::depth(self : CompatibilityTracker) -> Int {
  self.depth
}

///|
/// Reports whether unknown operators shall be ignored because the parser is
/// inside a compatibility section.
pub fn CompatibilityTracker::is_active(self : CompatibilityTracker) -> Bool {
  self.depth > 0
}

///|
/// Enters one `BX` compatibility section.
pub fn CompatibilityTracker::begin(self : CompatibilityTracker) -> Unit {
  self.depth += 1
}

///|
/// Leaves one `EX` compatibility section and rejects unbalanced `EX` markers.
pub fn CompatibilityTracker::end(
  self : CompatibilityTracker,
  offset : Int64,
) -> Unit raise PdfContentError {
  if self.depth == 0 {
    raise MalformedSyntax(offset, "unbalanced EX compatibility operator")
  }
  self.depth -= 1
}

///|
/// A parsed normal content stream instruction containing the recognized
/// operator name, its direct PdfObject operands, and the decoded-byte offset
/// where the operator keyword started.
pub(all) struct ContentOperation {
  operator : StandardContentOperator
  operands : Array[@objects.PdfObject]
  offset : Int64
} derive(Eq, Debug)

///|
/// Public content stream instruction model. Normal operators carry an ordered
/// array of PdfObject operands and an operator name, while inline image data
/// introduced by `BI`, `ID`, and `EI` is returned as a distinct instruction.
pub(all) enum ContentInstruction {
  Operation(ContentOperation)
  InlineImage(PdfInlineImage)
} derive(Eq, Debug)

///|
/// Parsed decoded content stream aggregate preserving source order for every
/// operation and inline image instruction emitted by the iteration API.
pub(all) struct ContentStream {
  instructions : Array[ContentInstruction]
} derive(Eq, Debug)

///|
/// Iterates decoded content stream bytes, collecting PDF object operands until
/// a recognized operator keyword or inline image sequence emits one parsed
/// instruction.
pub(all) struct ContentStreamParser {
  reader : ContentOperandReader
  operands : Array[@objects.PdfObject]
  compatibility : CompatibilityTracker
}

///|
/// Creates a content stream parser over already-decoded bytes.
pub fn ContentStreamParser::new(input : Bytes) -> ContentStreamParser {
  ContentStreamParser::{
    reader: ContentOperandReader::new(input),
    operands: [],
    compatibility: CompatibilityTracker::new(),
  }
}

///|
/// Returns the current compatibility section depth maintained from `BX` and
/// `EX` operator keywords.
pub fn ContentStreamParser::compatibility_depth(
  self : ContentStreamParser,
) -> Int {
  self.compatibility.depth()
}

///|
/// Reads the next content stream instruction one at a time from decoded bytes.
/// Operands are cleared after each emitted instruction, source order and
/// operator offsets are preserved, and inline images are delegated to the
/// inline image reader.
pub fn ContentStreamParser::parse_next(
  self : ContentStreamParser,
) -> ContentInstruction? raise PdfContentError {
  while true {
    match self.reader.read_next() {
      Operand(object) => self.operands.push(object)
      OperatorCandidate(keyword, offset) =>
        match recognize_operator(keyword) {
          Some(operator) => return Some(self.handle_operator(operator, offset))
          None =>
            if self.compatibility.is_active() {
              self.operands.clear()
            } else {
              raise UnknownOperator(offset, bytes_to_text(keyword))
            }
        }
      EndOfInput(offset) => {
        if self.compatibility.is_active() {
          raise MalformedSyntax(
            offset, "unterminated BX compatibility section before end of input",
          )
        }
        if self.operands.length() > 0 {
          raise MalformedSyntax(offset, "operands without operator")
        }
        return None
      }
    }
  } nobreak {
    None
  }
}

///|
/// Parses all decoded content bytes into an ordered content stream aggregate.
pub fn ContentStreamParser::parse_all(
  self : ContentStreamParser,
) -> ContentStream raise PdfContentError {
  let instructions : Array[ContentInstruction] = []
  while self.parse_next() is Some(instruction) {
    instructions.push(instruction)
  }
  ContentStream::{ instructions, }
}

///|
/// Reads the next normal content operation for callers that are not consuming
/// inline image instructions. Inline images are still recognized as special
/// content stream syntax and reported as a typed inline-image failure here.
pub fn ContentStreamParser::parse_next_operation(
  self : ContentStreamParser,
) -> ContentOperation? raise PdfContentError {
  match self.parse_next() {
    Some(Operation(operation)) => Some(operation)
    Some(InlineImage(image)) =>
      raise InlineImageFailure(
        image.start_offset,
        "inline image instruction is not a normal operation",
      )
    None => None
  }
}

///|
fn ContentStreamParser::handle_operator(
  self : ContentStreamParser,
  operator : StandardContentOperator,
  offset : Int64,
) -> ContentInstruction raise PdfContentError {
  match operator {
    BeginInlineImage => {
      self.operands.clear()
      let image = InlineImageReader::{ reader: self.reader }.parse(offset)
      return InlineImage(image)
    }
    BeginInlineImageData | EndInlineImage =>
      raise InlineImageFailure(
        offset, "ID and EI inline image markers must appear inside a BI sequence",
      )
    BeginCompatibility => self.compatibility.begin()
    EndCompatibility => self.compatibility.end(offset)
    _ => ()
  }
  let operands = self.take_operands()
  Operation(ContentOperation::{ operator, operands, offset })
}

///|
fn ContentStreamParser::take_operands(
  self : ContentStreamParser,
) -> Array[@objects.PdfObject] {
  let operands : Array[@objects.PdfObject] = []
  for operand in self.operands {
    operands.push(operand)
  }
  self.operands.clear()
  operands
}
