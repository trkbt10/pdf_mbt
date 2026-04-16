///|
let column_alignment_threshold : Double = 2.0

///|
/// Requirement 1 package separation: this layout estimation engine lives in
/// the separate `src/layout/` package, depends on `src/text/` TextSpan types,
/// and does not modify the core text interpreter migrated from
/// `src/text/layout.mbt`.
/// Controls the layout estimation thresholds. Values are expressed relative to
/// estimated text size so callers can tune reconstruction without changing the
/// text interpreter.
pub(all) struct LayoutConfig {
  kerning_threshold_em : Double
  line_tolerance_factor : Double
  paragraph_gap_factor : Double
} derive(Eq, Debug)

///|
/// Requirement 2 kerning collapse: the engine SHALL merge adjacent glyphs into
/// words by collapsing small TJ positioning adjustments (kerning). Adjacent
/// glyph spans whose absolute TJ-positioning-equivalent gap is below
/// `kerning_threshold_em * 1000` in text-space intent, estimated as
/// `kerning_threshold_em * font_size` in positioned output, are concatenated
/// without inserting spaces.
pub(all) struct LayoutWord {
  text : String
  x : Double
  y : Double
  end_x : Double
  font_name : @objects.PdfName?
  source_spans : Array[@text.TextSpan]
  separator_before : String
} derive(Eq, Debug)

///|
/// Requirement 4 line detection: the engine SHALL group words into lines based
/// on vertical position. Words whose Y-coordinates fall within
/// `line_tolerance_factor` of the dominant font size are clustered into the
/// same logical line, then sorted top-to-bottom and left-to-right.
pub(all) struct LayoutLine {
  y : Double
  dominant_font_size : Double
  words : Array[LayoutWord]
  paragraph_break_before : Bool
} derive(Eq, Debug)

///|
/// Full layout reconstruction result returned by the separate `src/layout/`
/// package. It contains lines of words with positional metadata and keeps this
/// estimation layer separate from the `src/text/` interpreter.
pub(all) struct LayoutResult {
  lines : Array[LayoutLine]
  config : LayoutConfig
} derive(Eq, Debug)

///|
/// Requirement 4 line detection support: group words into lines based on
/// vertical position by keeping the original `@text.TextSpan` and comparing
/// X/Y coordinates for top-to-bottom and left-to-right reading order.
priv struct PositionedSpan {
  span : @text.TextSpan
  x : Double
  y : Double
  index : Int
}

///|
/// Requirement 5 paragraph detection: the engine SHALL optionally detect
/// paragraph boundaries by identifying vertical gaps between lines that exceed
/// the normal line spacing. RawLayoutLine preserves Y positions so
/// `paragraph_gap_factor` can insert a blank line separator.
priv struct RawLayoutLine {
  y : Double
  spans : Array[PositionedSpan]
}

///|
/// Mutable reconstruction state for word detection and kerning collapse.
/// Explicit space spans and gaps above the kerning threshold produce a word
/// separator; smaller gaps append the next glyph span to the current word.
priv struct WordBuilder {
  text : String
  x : Double
  y : Double
  end_x : Double
  font_name : @objects.PdfName?
  source_spans : Array[@text.TextSpan]
  separator_before : String
}

///|
/// Requirement 6 configuration defaults: `kerning_threshold_em` defaults to
/// 0.25, `line_tolerance_factor` defaults to 0.5, and
/// `paragraph_gap_factor` defaults to 1.5.
pub fn LayoutConfig::default() -> LayoutConfig {
  LayoutConfig::{
    kerning_threshold_em: 0.25,
    line_tolerance_factor: 0.5,
    paragraph_gap_factor: 1.5,
  }
}

///|
/// Reconstructs words, lines, and paragraph breaks from positioned text spans.
/// Small horizontal displacements are collapsed as intra-word kerning, larger
/// gaps become word separators, and close Y coordinates are clustered into
/// logical lines.
pub fn estimate_layout(
  spans : Array[@text.TextSpan],
  config? : LayoutConfig = LayoutConfig::default(),
) -> LayoutResult {
  let raw_lines = group_text_spans_into_lines(spans, config)
  let lines = build_layout_lines(raw_lines, config)
  LayoutResult::{ lines, config }
}

///|
/// Formats an estimated layout as plain text with spaces, newlines, tabs for
/// repeated aligned columns, and blank lines for paragraph detection. A blank
/// line is emitted when vertical gaps exceed `paragraph_gap_factor` times the
/// normal line spacing.
pub fn layout_to_text(result : LayoutResult) -> String {
  let out = StringBuilder::new()
  for line_index in 0..<result.lines.length() {
    if line_index > 0 {
      out.write_string("\n")
      if result.lines[line_index].paragraph_break_before {
        out.write_string("\n")
      }
    }
    write_layout_line(out, result.lines[line_index])
  }
  out.to_string()
}

///|
pub fn layout_text_spans(
  spans : Array[@text.TextSpan],
  config? : LayoutConfig = LayoutConfig::default(),
) -> String {
  layout_to_text(estimate_layout(spans, config~))
}

///|
fn group_text_spans_into_lines(
  spans : Array[@text.TextSpan],
  config : LayoutConfig,
) -> Array[RawLayoutLine] {
  let positioned : Array[PositionedSpan] = []
  for index in 0..<spans.length() {
    let span = spans[index]
    if span.text.length() > 0 {
      positioned.push(PositionedSpan::{
        span,
        x: span.text_matrix.e,
        y: span.text_matrix.f,
        index,
      })
    }
  }
  positioned.sort_by(compare_positioned_top_to_bottom)
  let y_tolerance = dominant_font_size(positioned) *
    config.line_tolerance_factor
  let lines : Array[RawLayoutLine] = []
  for item in positioned {
    let mut placed = false
    for line in lines {
      if !placed && (line.y - item.y).abs() <= y_tolerance {
        line.spans.push(item)
        placed = true
      }
    }
    if !placed {
      lines.push(RawLayoutLine::{ y: item.y, spans: [item] })
    }
  }
  for line in lines {
    line.spans.sort_by(compare_positioned_left_to_right)
  }
  lines.sort_by(compare_raw_lines_top_to_bottom)
  lines
}

///|
fn build_layout_lines(
  raw_lines : Array[RawLayoutLine],
  config : LayoutConfig,
) -> Array[LayoutLine] {
  let lines : Array[LayoutLine] = []
  let normal_spacing = dominant_line_spacing(raw_lines)
  for line_index in 0..<raw_lines.length() {
    let raw_line = raw_lines[line_index]
    let font_size = line_font_size(raw_line)
    lines.push(LayoutLine::{
      y: raw_line.y,
      dominant_font_size: font_size,
      words: build_layout_words(raw_lines, line_index, config, font_size),
      paragraph_break_before: should_start_paragraph(
        raw_lines, line_index, normal_spacing, config,
      ),
    })
  }
  lines
}

///|
fn build_layout_words(
  raw_lines : Array[RawLayoutLine],
  line_index : Int,
  config : LayoutConfig,
  font_size : Double,
) -> Array[LayoutWord] {
  let line = raw_lines[line_index]
  let character_width = line_average_character_width(line, font_size)
  let word_threshold = word_gap_threshold(config, font_size)
  let words : Array[LayoutWord] = []
  let mut current : WordBuilder? = None
  let mut pending_separator = ""
  for span_index in 0..<line.spans.length() {
    let item = line.spans[span_index]
    if is_explicit_space_span(item.span) {
      match current {
        Some(builder) => {
          words.push(builder.finish())
          current = None
        }
        None => ()
      }
      pending_separator = " "
    } else {
      match current {
        None => {
          current = Some(
            WordBuilder::start(item, character_width, pending_separator),
          )
          pending_separator = ""
        }
        Some(builder) => {
          let gap = item.x - builder.end_x
          let separator = separator_for_gap(
            raw_lines,
            line_index,
            item.x,
            gap,
            word_threshold,
            character_width,
          )
          if separator.length() > 0 {
            words.push(builder.finish())
            current = Some(WordBuilder::start(item, character_width, separator))
          } else {
            current = Some(builder.append(item, character_width))
          }
        }
      }
    }
  }
  match current {
    Some(builder) => words.push(builder.finish())
    None => ()
  }
  words
}

///|
fn WordBuilder::start(
  item : PositionedSpan,
  character_width : Double,
  separator_before : String,
) -> WordBuilder {
  WordBuilder::{
    text: item.span.text,
    x: item.x,
    y: item.y,
    end_x: span_end_x(item, character_width),
    font_name: item.span.font_name,
    source_spans: [item.span],
    separator_before,
  }
}

///|
fn WordBuilder::append(
  self : WordBuilder,
  item : PositionedSpan,
  character_width : Double,
) -> WordBuilder {
  let spans = self.source_spans.copy()
  spans.push(item.span)
  WordBuilder::{
    text: self.text + item.span.text,
    x: self.x,
    y: self.y,
    end_x: span_end_x(item, character_width),
    font_name: self.font_name,
    source_spans: spans,
    separator_before: self.separator_before,
  }
}

///|
fn WordBuilder::finish(self : WordBuilder) -> LayoutWord {
  LayoutWord::{
    text: self.text,
    x: self.x,
    y: self.y,
    end_x: self.end_x,
    font_name: self.font_name,
    source_spans: self.source_spans.copy(),
    separator_before: self.separator_before,
  }
}

///|
fn separator_for_gap(
  raw_lines : Array[RawLayoutLine],
  current_line_index : Int,
  x : Double,
  gap : Double,
  word_threshold : Double,
  character_width : Double,
) -> String {
  if gap > character_width * 4.0 &&
    detect_table_like_structure(raw_lines, current_line_index, x) {
    "\t"
  } else if gap > word_threshold {
    " "
  } else {
    ""
  }
}

///|
fn write_layout_line(out : StringBuilder, line : LayoutLine) -> Unit {
  for word_index in 0..<line.words.length() {
    let word = line.words[word_index]
    if word_index > 0 {
      out.write_string(word.separator_before)
    }
    out.write_string(word.text)
  }
}

///|
fn span_end_x(item : PositionedSpan, character_width : Double) -> Double {
  item.x + span_character_count(item.span).to_double() * character_width
}

///|
fn is_explicit_space_span(span : @text.TextSpan) -> Bool {
  span.text.trim().length() == 0
}

///|
fn dominant_font_size(positioned : Array[PositionedSpan]) -> Double {
  let mut value = 12.0
  for item in positioned {
    let candidate = matrix_font_size(item.span.text_matrix)
    if candidate > 1.0 {
      value = candidate
      return value
    }
  }
  value
}

///|
fn line_font_size(line : RawLayoutLine) -> Double {
  let mut value = 12.0
  for item in line.spans {
    let candidate = matrix_font_size(item.span.text_matrix)
    if candidate > 1.0 {
      value = candidate
      return value
    }
  }
  value
}

///|
fn matrix_font_size(matrix : @text.TextMatrix) -> Double {
  matrix.a.abs().max(matrix.d.abs())
}

///|
fn line_average_character_width(
  line : RawLayoutLine,
  font_size : Double,
) -> Double {
  let fallback = font_size * 0.5
  let samples : Array[Double] = []
  for index in 1..<line.spans.length() {
    let previous = line.spans[index - 1]
    let current = line.spans[index]
    let delta = current.x - previous.x
    if delta > 0.5 && delta <= fallback * 1.5 {
      samples.push(delta / span_character_count(previous.span).to_double())
    }
  }
  if samples.length() == 0 {
    fallback
  } else {
    samples.sort()
    samples[samples.length() / 2].max(1.0).min(fallback)
  }
}

///|
fn word_gap_threshold(config : LayoutConfig, font_size : Double) -> Double {
  (font_size * config.kerning_threshold_em).max(1.0)
}

///|
fn dominant_line_spacing(lines : Array[RawLayoutLine]) -> Double {
  let samples : Array[Double] = []
  for index in 1..<lines.length() {
    let gap = lines[index - 1].y - lines[index].y
    if gap > 0.5 {
      samples.push(gap)
    }
  }
  if samples.length() == 0 {
    12.0
  } else {
    samples.sort()
    samples[0]
  }
}

///|
fn should_start_paragraph(
  lines : Array[RawLayoutLine],
  line_index : Int,
  normal_spacing : Double,
  config : LayoutConfig,
) -> Bool {
  if line_index == 0 {
    false
  } else {
    let gap = lines[line_index - 1].y - lines[line_index].y
    gap > normal_spacing * config.paragraph_gap_factor
  }
}

///|
fn detect_table_like_structure(
  lines : Array[RawLayoutLine],
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
fn span_character_count(span : @text.TextSpan) -> Int {
  let count = span.text.iter().count()
  if count > 0 {
    count
  } else {
    1
  }
}

///|
fn compare_positioned_top_to_bottom(
  left : PositionedSpan,
  right : PositionedSpan,
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
  left : PositionedSpan,
  right : PositionedSpan,
) -> Int {
  let x_order = Double::compare(left.x, right.x)
  if x_order != 0 {
    x_order
  } else {
    left.index - right.index
  }
}

///|
fn compare_raw_lines_top_to_bottom(
  left : RawLayoutLine,
  right : RawLayoutLine,
) -> Int {
  Double::compare(right.y, left.y)
}
