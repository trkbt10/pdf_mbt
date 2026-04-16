///|
test "layout text spans sorts lines and inserts word gaps" {
  let spans = [
    layout_span("lower", 10.0, 80.0),
    layout_span("World", 44.0, 100.0),
    layout_span("Hello", 10.0, 100.0),
  ]
  assert_eq(layout_text_spans(spans), "Hello World\nlower")
}

///|
test "layout text spans groups close y positions into one line" {
  let spans = [
    layout_span("Beta", 44.0, 96.5),
    layout_span("Alpha", 10.0, 100.0),
    layout_span("Gamma", 10.0, 80.0),
  ]
  assert_eq(layout_text_spans(spans), "Alpha Beta\nGamma")
}

///|
test "layout text spans inserts tabs for repeated aligned columns" {
  let spans = [
    layout_span("A", 10.0, 100.0),
    layout_span("B", 120.0, 100.0),
    layout_span("C", 10.0, 80.0),
    layout_span("D", 120.0, 80.0),
  ]
  assert_eq(layout_text_spans(spans), "A\tB\nC\tD")
}

///|
test "layout text spans collapses kerning-sized glyph gaps" {
  let spans = [
    layout_span("I", 10.0, 100.0),
    layout_span("S", 15.0, 100.0),
    layout_span("O", 20.0, 100.0),
    layout_span("3", 31.0, 100.0),
    layout_span("2", 36.0, 100.0),
    layout_span("0", 41.0, 100.0),
    layout_span("0", 46.0, 100.0),
    layout_span("0", 51.0, 100.0),
  ]
  assert_eq(layout_text_spans(spans), "ISO 32000")
}

///|
test "layout text spans collapses dense TJ kerning near character width" {
  let spans = [
    layout_span("n", 10.0, 100.0),
    layout_span("o", 13.0, 100.0),
    layout_span("n", 16.0, 100.0),
    layout_span("l", 19.0, 100.0),
    layout_span("i", 22.0, 100.0),
    layout_span("n", 25.0, 100.0),
    layout_span("e", 31.2, 100.0),
    layout_span("a", 34.2, 100.0),
    layout_span("r", 37.2, 100.0),
  ]
  assert_eq(layout_text_spans(spans), "nonlinear")
}

///|
test "layout text spans keeps one TJ source run together before x sorting" {
  let spans = [
    layout_pdf_span("com", 10.0, 100.0, 7L),
    layout_pdf_span("po", 34.0, 100.0, 7L),
    layout_pdf_span("nents ", 58.0, 100.0, 7L),
    layout_pdf_span("and", 36.0, 100.0, 9L),
  ]
  assert_eq(layout_text_spans(spans), "components and")
}

///|
test "layout text spans does not duplicate separator after trailing space" {
  let spans = [
    layout_pdf_span("foo ", 10.0, 100.0, 7L),
    layout_pdf_span("bar", 100.0, 100.0, 9L),
    layout_pdf_span("baz", 100.0, 80.0, 11L),
  ]
  assert_eq(layout_text_spans(spans), "foo bar\nbaz")
}

///|
test "layout text spans merges source-adjacent word continuations" {
  let spans = [
    layout_pdf_span("com", 10.0, 100.0, 7L),
    layout_pdf_span("bined", 35.0, 100.0, 9L),
  ]
  assert_eq(layout_text_spans(spans), "combined")
}

///|
test "layout text spans keeps single-letter absolute placements separated" {
  let spans = [
    layout_pdf_span("A", 10.0, 100.0, 7L),
    layout_pdf_span("B", 22.0, 100.0, 9L),
  ]
  assert_eq(layout_text_spans(spans), "A B")
}

///|
test "layout text spans keeps larger source-adjacent word gaps separated" {
  let spans = [
    layout_pdf_span("foo", 10.0, 100.0, 7L),
    layout_pdf_span("bar", 44.0, 100.0, 9L),
  ]
  assert_eq(layout_text_spans(spans), "foo bar")
}

///|
test "layout result exposes reconstructed words" {
  let result = estimate_layout([
    layout_span("ISO", 10.0, 100.0),
    layout_span("32000", 44.0, 100.0),
  ])
  assert_eq(result.lines.length(), 1)
  assert_eq(result.lines[0].words.length(), 2)
  assert_eq(result.lines[0].words[0].text, "ISO")
  assert_eq(result.lines[0].words[1].text, "32000")
}

///|
test "layout text spans inserts blank line for paragraph gap" {
  let spans = [
    layout_span("First", 10.0, 100.0),
    layout_span("Second", 10.0, 88.0),
    layout_span("Next", 10.0, 60.0),
  ]
  assert_eq(layout_text_spans(spans), "First\nSecond\n\nNext")
}

///|
fn layout_span(text : String, x : Double, y : Double) -> @text.TextSpan {
  @text.TextSpan::{
    offset: 0L,
    font_name: None,
    font_size: 12.0,
    text,
    mappings: [],
    source_bytes: b"",
    text_matrix: @text.TextMatrix::translation(x, y),
  }
}

///|
fn layout_pdf_span(
  text : String,
  x : Double,
  y : Double,
  offset : Int64,
) -> @text.TextSpan {
  @text.TextSpan::{
    offset,
    font_name: None,
    font_size: 12.0,
    text,
    mappings: [],
    source_bytes: b"x",
    text_matrix: @text.TextMatrix::translation(x, y),
  }
}
