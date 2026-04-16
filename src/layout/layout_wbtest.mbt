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
    text,
    mappings: [],
    source_bytes: b"",
    text_matrix: @text.TextMatrix::translation(x, y),
  }
}
