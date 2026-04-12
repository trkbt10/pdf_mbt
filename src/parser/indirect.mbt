///|
/// Parses an ISO 32000-2 section 7.3.10 indirect object definition in the
/// N G obj ... endobj form, preserving object number, generation number, and
/// byte offsets.
pub fn ObjectParser::parse_indirect_object(
  self : ObjectParser,
) -> @objects.IndirectObject raise @objects.PdfParseError {
  self.lexer.skip_separators()
  let start_offset = self.cursor.offset()
  let object_number = self.read_indirect_object_number(start_offset)
  let generation_number = self.read_indirect_generation_number(start_offset)
  self.require_indirect_keyword(b"obj", "indirect object", start_offset)
  let value = match self.parse_object() {
    Dictionary(dict) => self.maybe_read_stream(dict)
    value => value
  }
  self.lexer.skip_separators()
  let end_offset = self.cursor.offset()
  let end_token = self.lexer.next_token()
  match end_token {
    Regular(b"endobj", _) => ()
    EndOfInput(_) =>
      raise @objects.PdfParseError::UnexpectedEof(end_offset, "indirect object")
    _ =>
      raise @objects.PdfParseError::InvalidIndirectObject(
        token_offset(end_token),
        "expected endobj",
      )
  }
  @objects.IndirectObject::{
    id: @objects.ObjectId::{ object_number, generation_number },
    value,
    start_offset,
    end_offset: self.cursor.offset(),
  }
}

///|
/// Parses a single ISO 32000-2 section 7.3.10 indirect object from bytes.
pub fn parse_indirect_object(
  input : Bytes,
) -> @objects.IndirectObject raise @objects.PdfParseError {
  ObjectParser::new(input).parse_indirect_object()
}

///|
/// Reads and validates the positive object number in an indirect object.
fn ObjectParser::read_indirect_object_number(
  self : ObjectParser,
  start_offset : Int64,
) -> Int raise @objects.PdfParseError {
  let token = self.lexer.next_token()
  match token {
    Regular(lexeme, _) if is_integer_lexeme(lexeme) => {
      let object_number = parse_int64_lexeme(lexeme, token_offset(token))
      if object_number <= 0L {
        raise @objects.PdfParseError::InvalidIndirectObject(
          start_offset, "object number must be positive",
        )
      }
      object_number.to_int()
    }
    EndOfInput(_) =>
      raise @objects.PdfParseError::UnexpectedEof(
        start_offset, "indirect object",
      )
    _ =>
      raise @objects.PdfParseError::InvalidIndirectObject(
        start_offset, "object number must be an integer",
      )
  }
}

///|
/// Reads and validates the non-negative generation number in an indirect
/// object.
fn ObjectParser::read_indirect_generation_number(
  self : ObjectParser,
  start_offset : Int64,
) -> Int raise @objects.PdfParseError {
  let token = self.lexer.next_token()
  match token {
    Regular(lexeme, _) if is_integer_lexeme(lexeme) => {
      let generation_number = parse_int64_lexeme(lexeme, token_offset(token))
      if generation_number < 0L {
        raise @objects.PdfParseError::InvalidIndirectObject(
          start_offset, "generation number must be non-negative",
        )
      }
      generation_number.to_int()
    }
    EndOfInput(_) =>
      raise @objects.PdfParseError::UnexpectedEof(
        start_offset, "indirect object",
      )
    _ =>
      raise @objects.PdfParseError::InvalidIndirectObject(
        start_offset, "generation number must be an integer",
      )
  }
}

///|
/// Requires the obj keyword when parsing N G obj indirect object syntax.
fn ObjectParser::require_indirect_keyword(
  self : ObjectParser,
  expected : Bytes,
  context : String,
  start_offset : Int64,
) -> Unit raise @objects.PdfParseError {
  let token = self.lexer.next_token()
  match token {
    Regular(lexeme, _) if lexeme == expected => ()
    EndOfInput(_) =>
      raise @objects.PdfParseError::UnexpectedEof(start_offset, context)
    _ =>
      raise @objects.PdfParseError::InvalidIndirectObject(
        token_offset(token),
        "expected obj",
      )
  }
}
