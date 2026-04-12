///|
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
pub fn parse_indirect_object(
  input : Bytes,
) -> @objects.IndirectObject raise @objects.PdfParseError {
  ObjectParser::new(input).parse_indirect_object()
}

///|
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
