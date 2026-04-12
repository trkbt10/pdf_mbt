///|
fn ObjectParser::parse_dictionary(
  self : ObjectParser,
) -> @objects.PdfDictionary raise @objects.PdfParseError {
  self.consume_dictionary_start()
  let dict : @objects.PdfDictionary = Map::new()
  let seen : Map[@objects.PdfName, Bool] = Map::new()
  while true {
    if !self.lexer.has_pushed_tokens() {
      self.lexer.skip_separators()
      if self.is_at_dictionary_end() {
        self.consume_dictionary_end()
        break
      }
      if self.cursor.peek() is None {
        raise @objects.PdfParseError::UnexpectedEof(
          self.cursor.offset(),
          "dictionary",
        )
      }
    }
    let key_offset = self.cursor.offset()
    let key_object = self.parse_object()
    let key = match key_object {
      Name(name) => name
      _ =>
        raise @objects.PdfParseError::InvalidDictionary(
          key_offset, "dictionary key must be a name",
        )
    }
    if seen.get(key) is Some(_) {
      raise @objects.PdfParseError::InvalidDictionary(
        key_offset, "duplicate dictionary key",
      )
    }
    seen[key] = true
    if !self.lexer.has_pushed_tokens() {
      self.lexer.skip_separators()
      if self.is_at_dictionary_end() {
        raise @objects.PdfParseError::InvalidDictionary(
          self.cursor.offset(),
          "dictionary key is missing a value",
        )
      }
      if self.cursor.peek() is None {
        raise @objects.PdfParseError::UnexpectedEof(
          self.cursor.offset(),
          "dictionary",
        )
      }
    }
    let value = self.parse_object()
    if !value.is_null() {
      dict[key] = value
    }
  }
  dict
}

///|
fn ObjectParser::consume_dictionary_start(
  self : ObjectParser,
) -> Unit raise @objects.PdfParseError {
  let offset = self.cursor.offset()
  if self.cursor.peek() == Some(b'<') && self.cursor.peek_n(1) == Some(b'<') {
    self.cursor.read_byte() |> ignore
    self.cursor.read_byte() |> ignore
  } else {
    raise @objects.PdfParseError::InvalidDictionary(
      offset, "dictionary must start with <<",
    )
  }
}

///|
fn ObjectParser::consume_dictionary_end(
  self : ObjectParser,
) -> Unit raise @objects.PdfParseError {
  let offset = self.cursor.offset()
  if self.cursor.peek() == Some(b'>') && self.cursor.peek_n(1) == Some(b'>') {
    self.cursor.read_byte() |> ignore
    self.cursor.read_byte() |> ignore
  } else {
    raise @objects.PdfParseError::UnexpectedEof(offset, "dictionary")
  }
}

///|
fn ObjectParser::is_at_dictionary_end(self : ObjectParser) -> Bool {
  self.cursor.peek() == Some(b'>') && self.cursor.peek_n(1) == Some(b'>')
}
