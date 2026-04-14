///|
pub fn PdfDocument::page_label_ranges(
  self : PdfDocument,
) -> Array[PdfPageLabelRange] raise PdfDocumentError {
  let owner = navigation_key(b"PageLabels")
  match self.catalog.entry(owner) {
    Some(root) => {
      let entries = enumerate_number_tree(self.file, root, owner)
      validate_page_label_zero_range(entries, owner)
      let ranges : Array[PdfPageLabelRange] = []
      for entry in entries {
        ranges.push(parse_page_label_range(entry, owner))
      }
      ranges
    }
    None => []
  }
}

///|
pub fn PdfDocument::page_label(
  self : PdfDocument,
  page_index : Int,
) -> PdfPageLabel? raise PdfDocumentError {
  let owner = navigation_key(b"PageLabels")
  require_page_index_bounds(self, page_index, owner)
  match self.catalog.entry(owner) {
    Some(root) =>
      match lookup_number_tree_le(self.file, root, page_index, owner) {
        Some(entry) => {
          if entry.key != 0 {
            validate_page_label_zero_range(
              enumerate_number_tree(self.file, root, owner),
              owner,
            )
          }
          let range = parse_page_label_range(entry, owner)
          Some(PdfPageLabel::{
            page_index,
            label: format_page_label(range, page_index),
            range_start: range.start_index,
          })
        }
        None => raise navigation_error(owner, "PageLabels must include range 0")
      }
    None => None
  }
}

///|
fn validate_page_label_zero_range(
  entries : Array[PdfNumberTreeEntry],
  owner : @objects.PdfName,
) -> Unit raise PdfDocumentError {
  let mut has_zero = false
  for entry in entries {
    if entry.key == 0 {
      has_zero = true
    }
    if entry.key < 0 {
      raise navigation_error(owner, "PageLabels keys must be non-negative")
    }
  }
  if entries.length() > 0 && !has_zero {
    raise navigation_error(owner, "PageLabels must include range 0")
  }
}

///|
fn parse_page_label_range(
  entry : PdfNumberTreeEntry,
  owner : @objects.PdfName,
) -> PdfPageLabelRange raise PdfDocumentError {
  let dict = match entry.value {
    @objects.PdfObject::Dictionary(dict) => dict
    _ =>
      raise navigation_error(
        owner, "page label range value must be a dictionary",
      )
  }
  let style = match dict.get(navigation_key(b"S")) {
    Some(@objects.PdfObject::Name(name)) =>
      page_label_style_from_name(name, owner)
    Some(_) => raise navigation_error(owner, "page label S must be a name")
    None => PdfPageLabelStyle::PrefixOnly
  }
  let start_number = match dict.get(navigation_key(b"St")) {
    Some(value) => navigation_int(value, owner, "page label St")
    None => 1
  }
  if start_number <= 0 {
    raise navigation_error(owner, "page label St must be positive")
  }
  PdfPageLabelRange::{
    start_index: entry.key,
    style,
    prefix: match dict.get(navigation_key(b"P")) {
      Some(value) => navigation_string(value, owner, "page label prefix")
      None => b""
    },
    start_number,
    raw_dict: dict,
  }
}

///|
fn page_label_style_from_name(
  name : @objects.PdfName,
  owner : @objects.PdfName,
) -> PdfPageLabelStyle raise PdfDocumentError {
  if name == navigation_key(b"D") {
    PdfPageLabelStyle::Decimal
  } else if name == navigation_key(b"R") {
    PdfPageLabelStyle::UpperRoman
  } else if name == navigation_key(b"r") {
    PdfPageLabelStyle::LowerRoman
  } else if name == navigation_key(b"A") {
    PdfPageLabelStyle::UpperLetters
  } else if name == navigation_key(b"a") {
    PdfPageLabelStyle::LowerLetters
  } else {
    raise navigation_error(owner, "page label S has an unsupported value")
  }
}

///|
fn format_page_label(range : PdfPageLabelRange, page_index : Int) -> Bytes {
  let value = range.start_number + page_index - range.start_index
  match range.style {
    PdfPageLabelStyle::Decimal => range.prefix + int_to_bytes(value)
    PdfPageLabelStyle::UpperRoman => range.prefix + roman_bytes(value, false)
    PdfPageLabelStyle::LowerRoman => range.prefix + roman_bytes(value, true)
    PdfPageLabelStyle::UpperLetters => range.prefix + alpha_bytes(value, false)
    PdfPageLabelStyle::LowerLetters => range.prefix + alpha_bytes(value, true)
    PdfPageLabelStyle::PrefixOnly => range.prefix
  }
}

///|
fn int_to_bytes(value : Int) -> Bytes {
  if value == 0 {
    return b"0"
  }
  let digits : Array[Byte] = []
  let mut current = value
  while current > 0 {
    digits.push((b'0'.to_int() + current % 10).to_byte())
    current = current / 10
  }
  reverse_bytes(digits)
}

///|
fn roman_bytes(value : Int, lower : Bool) -> Bytes {
  let numbers : Array[Int] = [
    1000, 900, 500, 400, 100, 90, 50, 40, 10, 9, 5, 4, 1,
  ]
  let glyphs : Array[Bytes] = [
    b"M", b"CM", b"D", b"CD", b"C", b"XC", b"L", b"XL", b"X", b"IX", b"V", b"IV",
    b"I",
  ]
  let mut current = value
  let mut out = b""
  let mut index = 0
  while index < numbers.length() {
    let number = numbers[index]
    let glyph = glyphs[index]
    while current >= number {
      out = out + glyph
      current -= number
    }
    index += 1
  }
  if lower {
    lower_ascii(out)
  } else {
    out
  }
}

///|
fn alpha_bytes(value : Int, lower : Bool) -> Bytes {
  let letters : Array[Byte] = []
  let mut current = value
  while current > 0 {
    current -= 1
    let base = if lower { b'a'.to_int() } else { b'A'.to_int() }
    letters.push((base + current % 26).to_byte())
    current = current / 26
  }
  reverse_bytes(letters)
}

///|
fn reverse_bytes(source : Array[Byte]) -> Bytes {
  let out : Array[Byte] = []
  let mut index = source.length() - 1
  while index >= 0 {
    out.push(source[index])
    index -= 1
  }
  Bytes::from_array(out)
}

///|
fn lower_ascii(bytes : Bytes) -> Bytes {
  let out : Array[Byte] = []
  for byte in bytes {
    if byte >= b'A' && byte <= b'Z' {
      out.push((byte.to_int() + 32).to_byte())
    } else {
      out.push(byte)
    }
  }
  Bytes::from_array(out)
}
