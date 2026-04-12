///|
/// After an indirect object value parses as a Dictionary object, checks for
/// the ISO 32000-2 section 7.3.8 stream keyword and upgrades it to a Stream
/// object only in indirect-object parsing.
fn ObjectParser::maybe_read_stream(
  self : ObjectParser,
  dict : @objects.PdfDictionary,
) -> @objects.PdfObject raise @objects.PdfParseError {
  self.lexer.skip_separators()
  let token = self.lexer.next_token()
  match token {
    Regular(b"stream", _) => self.read_stream_object(dict)
    _ => {
      self.lexer.push_back(token)
      @objects.PdfObject::Dictionary(dict)
    }
  }
}

///|
/// Reads an ISO 32000-2 section 7.3.8 Stream object: validate the Length
/// entry, require stream EOL, read exactly that many bytes, allow the optional
/// EOL before endstream, and then require endstream.
fn ObjectParser::read_stream_object(
  self : ObjectParser,
  dict : @objects.PdfDictionary,
) -> @objects.PdfObject raise @objects.PdfParseError {
  let length = self.read_stream_length(dict)
  self.cursor.require_stream_eol()
  let data = self.cursor.read_bytes(length)
  self.cursor.read_eol() |> ignore
  self.require_endstream()
  @objects.PdfObject::Stream(@objects.PdfStream::{ dict, data })
}

///|
/// Reads the required ISO 32000-2 section 7.3.8 Length entry from the stream
/// dictionary.
fn ObjectParser::read_stream_length(
  self : ObjectParser,
  dict : @objects.PdfDictionary,
) -> Int64 raise @objects.PdfParseError {
  let key = @objects.PdfName::new(b"Length")
  match dict.get(key) {
    Some(Integer(length)) if length >= 0L => length
    Some(Integer(_)) =>
      raise @objects.PdfParseError::InvalidStream(
        self.cursor.offset(),
        "Length must be non-negative",
      )
    Some(_) =>
      raise @objects.PdfParseError::InvalidStream(
        self.cursor.offset(),
        "Length must be an integer",
      )
    None =>
      raise @objects.PdfParseError::InvalidStream(
        self.cursor.offset(),
        "Length entry is required",
      )
  }
}

///|
/// Requires the ISO 32000-2 section 7.3.8 endstream keyword.
fn ObjectParser::require_endstream(
  self : ObjectParser,
) -> Unit raise @objects.PdfParseError {
  let offset = self.cursor.offset()
  if !self.matches_keyword(b"endstream") {
    raise @objects.PdfParseError::InvalidStream(offset, "expected endstream")
  }
  self.consume_bytes(9)
}

///|
/// Matches a keyword only when the following byte is white-space, delimiter,
/// or end of input.
fn ObjectParser::matches_keyword(self : ObjectParser, expected : Bytes) -> Bool {
  let mut matched = true
  for i in 0..<expected.length() {
    if self.cursor.peek_n(i) != Some(expected[i]) {
      matched = false
    }
  }
  if matched {
    match self.cursor.peek_n(expected.length()) {
      Some(byte) if !@lexer.is_white_space(byte) && !@lexer.is_delimiter(byte) =>
        false
      _ => true
    }
  } else {
    false
  }
}

///|
fn ObjectParser::consume_bytes(
  self : ObjectParser,
  count : Int,
) -> Unit raise @objects.PdfParseError {
  for _ in 0..<count {
    self.cursor.read_byte() |> ignore
  }
}
