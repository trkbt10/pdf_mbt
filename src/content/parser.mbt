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
/// Iterates decoded content stream bytes, collecting PDF object operands until
/// a recognized operator keyword emits one content operation.
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
/// Reads the next normal content operation. Unknown operators raise outside
/// compatibility sections and are skipped with their accumulated operands
/// while a balanced `BX`/`EX` compatibility section is active.
pub fn ContentStreamParser::parse_next_operation(
  self : ContentStreamParser,
) -> ContentOperation? raise PdfContentError {
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
fn ContentStreamParser::handle_operator(
  self : ContentStreamParser,
  operator : StandardContentOperator,
  offset : Int64,
) -> ContentOperation raise PdfContentError {
  match operator {
    BeginCompatibility => self.compatibility.begin()
    EndCompatibility => self.compatibility.end(offset)
    _ => ()
  }
  let operands = self.take_operands()
  ContentOperation::{ operator, operands, offset }
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
