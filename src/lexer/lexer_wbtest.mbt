///|
fn test_lexer(input : Bytes) -> Lexer {
  Lexer::new(ByteCursor::new(input))
}

///|
test "lexer collapses separators and skips ordinary comments" {
  let lexer = test_lexer(b"  alpha\t% ordinary comment\r\n beta")
  match lexer.next_token() {
    Regular(bytes, offset) => {
      assert_eq(bytes, b"alpha")
      assert_eq(offset, 2L)
    }
    _ => fail("expected alpha token")
  }
  match lexer.next_token() {
    Regular(bytes, offset) => {
      assert_eq(bytes, b"beta")
      assert_eq(offset, 29L)
    }
    _ => fail("expected beta token")
  }
  match lexer.next_token() {
    EndOfInput(offset) => assert_eq(offset, 33L)
    _ => fail("expected end of input")
  }
}

///|
test "lexer terminates regular tokens before delimiters" {
  let lexer = test_lexer(b"Name/Next[42]")
  match lexer.next_token() {
    Regular(bytes, offset) => {
      assert_eq(bytes, b"Name")
      assert_eq(offset, 0L)
    }
    _ => fail("expected regular token")
  }
  match lexer.next_token() {
    Delimiter(byte, offset) => {
      assert_eq(byte, b'/')
      assert_eq(offset, 4L)
    }
    _ => fail("expected slash delimiter")
  }
  match lexer.next_token() {
    Regular(bytes, offset) => {
      assert_eq(bytes, b"Next")
      assert_eq(offset, 5L)
    }
    _ => fail("expected second regular token")
  }
  match lexer.next_token() {
    Delimiter(byte, offset) => {
      assert_eq(byte, b'[')
      assert_eq(offset, 9L)
    }
    _ => fail("expected array-start delimiter")
  }
}

///|
test "lexer emits dictionary and structural marker tokens" {
  let lexer = test_lexer(b"%PDF-2.0\n<< /Type /Catalog >>\n%%EOF")
  match lexer.next_token() {
    HeaderMarker(major, minor, offset) => {
      assert_eq(major, 2)
      assert_eq(minor, 0)
      assert_eq(offset, 0L)
    }
    _ => fail("expected header marker")
  }
  match lexer.next_token() {
    DictStart(offset) => assert_eq(offset, 9L)
    _ => fail("expected dictionary start")
  }
  lexer.next_token() |> ignore
  lexer.next_token() |> ignore
  lexer.next_token() |> ignore
  lexer.next_token() |> ignore
  match lexer.next_token() {
    DictEnd(offset) => assert_eq(offset, 27L)
    _ => fail("expected dictionary end")
  }
  match lexer.next_token() {
    EofMarker(offset) => assert_eq(offset, 30L)
    _ => fail("expected EOF marker")
  }
}

///|
test "lexer supports peek and explicit pushback" {
  let lexer = test_lexer(b"one two")
  let first = lexer.peek_token()
  match first {
    Regular(bytes, offset) => {
      assert_eq(bytes, b"one")
      assert_eq(offset, 0L)
    }
    _ => fail("expected first token from peek")
  }
  assert_eq(lexer.next_token() == first, true)
  let pushed = PdfToken::Regular(b"again", 99L)
  lexer.push_back(pushed)
  assert_eq(lexer.next_token() == pushed, true)
  match lexer.next_token() {
    Regular(bytes, offset) => {
      assert_eq(bytes, b"two")
      assert_eq(offset, 4L)
    }
    _ => fail("expected second token")
  }
}
