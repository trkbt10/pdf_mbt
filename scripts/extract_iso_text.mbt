///|
suberror IsoTextError {
  Message(String)
}

///|
fn main {
  try {
    let matches = iso_text_command().parse()
    run_extract_iso_text(matches)
  } catch {
    IsoTextError::Message(message) => abort("extract_iso_text: " + message)
    err => abort("extract_iso_text: " + err.to_string())
  }
}

///|
fn iso_text_command() -> @argparse.Command {
  @argparse.Command(
    "extract_iso_text",
    about="Extract and clean ISO PDF text.",
    positionals=[
      @argparse.PositionArg(
        "pdf",
        about="Input PDF file.",
        num_args=@argparse.ValueRange::single(),
      ),
      @argparse.PositionArg(
        "start_page",
        about="First page to extract, 1-based.",
        num_args=@argparse.ValueRange::single(),
      ),
      @argparse.PositionArg(
        "end_page",
        about="Last page to extract, 1-based.",
        num_args=@argparse.ValueRange::single(),
      ),
      @argparse.PositionArg("output", about="Output text file."),
    ],
  )
}

///|
fn run_extract_iso_text(matches : @argparse.Matches) -> Unit raise {
  let pdf_path = required_value(matches, "pdf")
  let start_page = parse_positive_int(
    required_value(matches, "start_page"),
    "start_page",
  )
  let end_page = parse_positive_int(
    required_value(matches, "end_page"),
    "end_page",
  )
  let output = extract_pages(pdf_path, start_page, end_page)
  match optional_value(matches, "output") {
    Some(path) => @fs.write_string_to_file(path, output)
    None => println(output)
  }
}

///|
fn required_value(
  matches : @argparse.Matches,
  name : String,
) -> String raise IsoTextError {
  match matches.values.get(name) {
    Some(values) if values.length() > 0 => values[0]
    _ => raise IsoTextError::Message("missing required argument " + name)
  }
}

///|
fn optional_value(matches : @argparse.Matches, name : String) -> String? {
  match matches.values.get(name) {
    Some(values) if values.length() > 0 => Some(values[0])
    _ => None
  }
}

///|
fn parse_positive_int(value : String, label : String) -> Int raise IsoTextError {
  let text = value.trim()
  if text.is_empty() {
    raise IsoTextError::Message(label + " must be an integer")
  }
  let mut parsed = 0
  for char in text {
    if !char.is_ascii_digit() {
      raise IsoTextError::Message(label + " must be an integer")
    }
    parsed = parsed * 10 + char.to_int() - b'0'.to_int()
  }
  if parsed < 1 {
    raise IsoTextError::Message(label + " must be at least 1")
  }
  parsed
}

///|
fn extract_pages(
  pdf_path : String,
  start_page : Int,
  end_page : Int,
) -> String raise {
  let document = @reader.PdfDocument::open(@fs.read_file_to_bytes(pdf_path))
  let page_count = document.page_count()
  if page_count <= 0 {
    return ""
  }
  let first_index = (start_page - 1).clamp(min=0, max=page_count)
  let last_exclusive = end_page.clamp(min=0, max=page_count)
  let raw_lines : Array[String] = []
  if first_index < last_exclusive {
    for page_index in first_index..<last_exclusive {
      let page = document.page(page_index)
      let extracted = page.extracted_text(@reader.TextPageOptions::default())
      append_clean_lines(raw_lines, collect_layout_text(extracted))
    }
  }
  join_split_headings(raw_lines)
}

///|
fn collect_layout_text(extracted : @text.ExtractedText) -> String {
  @layout.layout_text_spans(extracted.spans)
}

///|
fn append_clean_lines(lines : Array[String], text : String) -> Unit {
  for line in text.split("\n") {
    let owned = line.to_string()
    if !is_noise_line(owned) {
      lines.push(owned)
    }
  }
}

///|
fn is_noise_line(line : String) -> Bool {
  let stripped = line.trim()
  is_page_marker(stripped) ||
  has_standard_number_prefix(stripped, "ISO") ||
  has_standard_number_prefix(stripped, "IEC") ||
  starts_with_copyright_standard(stripped) ||
  stripped.contains("All rights reserved") ||
  stripped.has_prefix("Sold by the") ||
  stripped.has_prefix("Single user only") ||
  stripped.contains("copying and networking prohibited") ||
  stripped == "Goto errata" ||
  is_standalone_page_number(stripped)
}

///|
fn is_page_marker(line : StringView) -> Bool {
  match line.strip_prefix("---") {
    Some(rest) => {
      let rest = rest.trim_start()
      match rest.strip_prefix("Page") {
        Some(rest) => {
          let rest = rest.trim_start()
          let chars = rest.to_array()
          let mut index = 0
          while index < chars.length() && chars[index].is_ascii_digit() {
            index += 1
          }
          if index == 0 {
            false
          } else {
            let suffix = rest.sub(start=index).trim_start()
            suffix == "---"
          }
        }
        None => false
      }
    }
    None => false
  }
}

///|
fn has_standard_number_prefix(line : StringView, prefix : StringView) -> Bool {
  if !line.has_prefix(prefix) {
    return false
  }
  let chars = line.to_array()
  let prefix_len = prefix.char_length()
  if chars.length() <= prefix_len {
    return false
  }
  let separator = chars[prefix_len]
  is_standard_separator(separator) &&
  prefix_len + 1 < chars.length() &&
  chars[prefix_len + 1].is_ascii_digit()
}

///|
fn is_standard_separator(char : Char) -> Bool {
  char.is_ascii_whitespace() ||
  char.to_int() == b'_'.to_int() ||
  char.to_int() == b'/'.to_int() ||
  char.to_int() == b'-'.to_int()
}

///|
fn starts_with_copyright_standard(line : StringView) -> Bool {
  let chars = line.to_array()
  if chars.length() == 0 || chars[0].to_int() != 0x00A9 {
    return false
  }
  let mut index = 1
  while index < chars.length() && chars[index].is_whitespace() {
    index += 1
  }
  has_standard_word_at(chars, index)
}

///|
fn has_standard_word_at(chars : Array[Char], index : Int) -> Bool {
  let is_iso = has_ascii_word(chars, index, b'I', b'S', b'O')
  let is_iec = has_ascii_word(chars, index, b'I', b'E', b'C')
  if !(is_iso || is_iec) {
    return false
  }
  let next = index + 3
  next >= chars.length() || !is_ascii_word_char(chars[next])
}

///|
fn has_ascii_word(
  chars : Array[Char],
  index : Int,
  first : Byte,
  second : Byte,
  third : Byte,
) -> Bool {
  index + 2 < chars.length() &&
  chars[index].to_int() == first.to_int() &&
  chars[index + 1].to_int() == second.to_int() &&
  chars[index + 2].to_int() == third.to_int()
}

///|
fn is_ascii_word_char(char : Char) -> Bool {
  char.is_ascii_alphabetic() ||
  char.is_ascii_digit() ||
  char.to_int() == b'_'.to_int()
}

///|
fn is_standalone_page_number(line : StringView) -> Bool {
  let chars = line.to_array()
  if chars.length() < 1 || chars.length() > 3 {
    return false
  }
  for char in chars {
    if !char.is_ascii_digit() {
      return false
    }
  }
  true
}

///|
fn join_split_headings(raw_lines : Array[String]) -> String {
  let result : Array[String] = []
  let mut index = 0
  while index < raw_lines.length() {
    let stripped = raw_lines[index].trim()
    if is_section_number(stripped) && index + 1 < raw_lines.length() {
      let next_stripped = raw_lines[index + 1].trim()
      if !next_stripped.is_empty() && starts_with_title_char(next_stripped) {
        result.push(stripped.to_string() + " " + raw_lines[index + 1])
        index += 2
        continue
      }
    }
    result.push(raw_lines[index])
    index += 1
  }
  join_lines(result)
}

///|
fn is_section_number(line : StringView) -> Bool {
  let chars = line.to_array()
  if chars.length() == 0 {
    return false
  }
  let mut index = 0
  let mut first_digits = 0
  while index < chars.length() && chars[index].is_ascii_digit() {
    index += 1
    first_digits += 1
  }
  if first_digits < 1 || first_digits > 2 {
    return false
  }
  if index == chars.length() {
    return true
  }
  while index < chars.length() {
    if chars[index].to_int() != b'.'.to_int() {
      return false
    }
    index += 1
    if index == chars.length() {
      return true
    }
    let digit_start = index
    while index < chars.length() && chars[index].is_ascii_digit() {
      index += 1
    }
    if index == digit_start {
      return false
    }
  }
  true
}

///|
fn starts_with_title_char(line : StringView) -> Bool {
  let chars = line.to_array()
  chars.length() > 0 && chars[0].is_ascii_uppercase()
}

///|
fn join_lines(lines : Array[String]) -> String {
  let out = StringBuilder::new()
  for index in 0..<lines.length() {
    if index > 0 {
      out.write_string("\n")
    }
    out.write_string(lines[index])
  }
  out.to_string()
}
