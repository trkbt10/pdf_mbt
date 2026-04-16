///|
let line_y_threshold : Double = 6.0

///|
let default_character_width : Double = 6.0

///|
let column_alignment_threshold : Double = 2.0

///|
/// Internal span position used by spatial text grouping, line ordering, word
/// spacing detection, and table-like column alignment.
priv struct SpatialTextGroupingSpan {
  span : TextSpan
  x : Double
  y : Double
  index : Int
}

///|
/// Internal logical line produced by Y-coordinate grouping for layout mode text
/// extraction and table-like structure detection.
priv struct LayoutLine {
  y : Double
  spans : Array[SpatialTextGroupingSpan]
}

///|
/// Reconstructs spatial text grouping from `TextSpan` coordinates: spans are
/// grouped into logical lines by Y-coordinate, each line is sorted by X, word
/// spacing is inferred from horizontal gaps, and lines are emitted
/// top-to-bottom. When spans form a grid pattern with aligned columns and
/// consistent X-coordinates across multiple lines, tab characters are inserted
/// between table-like columns.
pub fn layout_text_spans(spans : Array[TextSpan]) -> String {
  let lines = group_text_spans_into_lines(spans)
  write_layout_lines(lines)
}

///|
pub fn ExtractedText::layout_text(self : ExtractedText) -> String {
  layout_text_spans(self.spans)
}

///|
/// Groups text spans into lines using their Y-coordinate positions so nearby
/// spans share a logical line before word spacing and line ordering are
/// rendered.
fn group_text_spans_into_lines(spans : Array[TextSpan]) -> Array[LayoutLine] {
  let positioned : Array[SpatialTextGroupingSpan] = []
  for index in 0..<spans.length() {
    let span = spans[index]
    if span.text.length() > 0 {
      positioned.push(SpatialTextGroupingSpan::{
        span,
        x: span.text_matrix.e,
        y: span.text_matrix.f,
        index,
      })
    }
  }
  positioned.sort_by(compare_positioned_top_to_bottom)
  let lines : Array[LayoutLine] = []
  for item in positioned {
    let mut placed = false
    for line in lines {
      if !placed && (line.y - item.y).abs() <= line_y_threshold {
        line.spans.push(item)
        placed = true
      }
    }
    if !placed {
      lines.push(LayoutLine::{ y: item.y, spans: [item] })
    }
  }
  for line in lines {
    line.spans.sort_by(compare_positioned_left_to_right)
  }
  lines.sort_by(compare_lines_top_to_bottom)
  lines
}

///|
fn write_layout_lines(lines : Array[LayoutLine]) -> String {
  let out = StringBuilder::new()
  for line_index in 0..<lines.length() {
    if line_index > 0 {
      out.write_string("\n")
    }
    write_layout_line(out, lines, line_index)
  }
  out.to_string()
}

///|
fn write_layout_line(
  out : StringBuilder,
  lines : Array[LayoutLine],
  line_index : Int,
) -> Unit {
  let line = lines[line_index]
  let character_width = line_average_character_width(line)
  let mut previous_end = 0.0
  for span_index in 0..<line.spans.length() {
    let item = line.spans[span_index]
    if span_index > 0 {
      let gap = item.x - previous_end
      if gap > character_width * 4.0 &&
        detect_table_like_structure(lines, line_index, item.x) {
        out.write_string("\t")
      } else if gap > word_gap_threshold(character_width) {
        out.write_string(" ")
      }
    }
    out.write_string(item.span.text)
    previous_end = item.x +
      span_character_count(item.span).to_double() * character_width
  }
}

///|
fn line_average_character_width(line : LayoutLine) -> Double {
  let mut width = default_character_width
  for index in 1..<line.spans.length() {
    let previous = line.spans[index - 1]
    let current = line.spans[index]
    let delta = current.x - previous.x
    if delta > 0.0 {
      let candidate = delta / span_character_count(previous.span).to_double()
      if candidate > 0.5 && candidate < width {
        width = candidate
      }
    }
  }
  width
}

///|
fn word_gap_threshold(character_width : Double) -> Double {
  (character_width * 0.25).max(1.0)
}

///|
/// Detects table-like structure: when text spans form a grid pattern with
/// aligned columns and consistent X-coordinates across multiple lines, layout
/// mode inserts tab characters between columns.
fn detect_table_like_structure(
  lines : Array[LayoutLine],
  current_line_index : Int,
  x : Double,
) -> Bool {
  for line_index in 0..<lines.length() {
    if line_index != current_line_index {
      for item in lines[line_index].spans {
        if (item.x - x).abs() <= column_alignment_threshold {
          return true
        }
      }
    }
  }
  false
}

///|
fn span_character_count(span : TextSpan) -> Int {
  let count = span.text.iter().count()
  if count > 0 {
    count
  } else {
    1
  }
}

///|
fn compare_positioned_top_to_bottom(
  left : SpatialTextGroupingSpan,
  right : SpatialTextGroupingSpan,
) -> Int {
  let y_order = Double::compare(right.y, left.y)
  if y_order != 0 {
    y_order
  } else {
    compare_positioned_left_to_right(left, right)
  }
}

///|
fn compare_positioned_left_to_right(
  left : SpatialTextGroupingSpan,
  right : SpatialTextGroupingSpan,
) -> Int {
  let x_order = Double::compare(left.x, right.x)
  if x_order != 0 {
    x_order
  } else {
    left.index - right.index
  }
}

///|
fn compare_lines_top_to_bottom(left : LayoutLine, right : LayoutLine) -> Int {
  Double::compare(right.y, left.y)
}
