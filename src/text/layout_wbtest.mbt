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
fn layout_span(text : String, x : Double, y : Double) -> TextSpan {
  TextSpan::{
    offset: 0L,
    font_name: None,
    text,
    mappings: [],
    source_bytes: b"",
    text_matrix: TextMatrix::translation(x, y),
  }
}
